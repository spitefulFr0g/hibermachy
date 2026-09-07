#![allow(unsafe_code)]
//! The sole unsafe boundary. It wraps Linux descriptor-relative operations so the
//! policy layer can neither select paths nor follow attacker-controlled links.

use std::{
    ffi::CString,
    fs::{File, Metadata},
    io::{Read, Write},
    os::{
        fd::{AsRawFd, FromRawFd},
        unix::fs::MetadataExt,
    },
};

use std::os::raw::{c_char, c_int, c_uint};

const O_RDONLY: c_int = 0;
const O_WRONLY: c_int = 1;
const O_CREAT: c_int = 0o100;
const O_EXCL: c_int = 0o200;
const O_DIRECTORY: c_int = 0o200_000;
const O_NOFOLLOW: c_int = 0o400_000;
const O_CLOEXEC: c_int = 0o2_000_000;
const O_PATH: c_int = 0o10_000_000;
const O_NONBLOCK: c_int = 0o4_000;
const LOCK_EX: c_int = 2;
const RENAME_NOREPLACE: c_uint = 1;
const RENAME_EXCHANGE: c_uint = 2;

unsafe extern "C" {
    fn geteuid() -> c_uint;
    fn open(path: *const c_char, flags: c_int) -> c_int;
    fn openat(directory: c_int, path: *const c_char, flags: c_int, mode: c_uint) -> c_int;
    fn renameat2(
        old_directory: c_int,
        old: *const c_char,
        new_directory: c_int,
        new: *const c_char,
        flags: c_uint,
    ) -> c_int;
    fn unlinkat(directory: c_int, path: *const c_char, flags: c_int) -> c_int;
    fn fsync(fd: c_int) -> c_int;
    fn flock(fd: c_int, operation: c_int) -> c_int;
}

fn c_name(name: &str) -> Result<CString, &'static str> {
    CString::new(name).map_err(|_| "invalid fixed location")
}

fn call_open(path: &CString, flags: c_int) -> Result<File, &'static str> {
    // SAFETY: CString is NUL terminated and File assumes ownership only of a checked fd.
    let fd = unsafe { open(path.as_ptr(), flags) };
    if fd < 0 {
        return Err("unsafe filesystem state");
    }
    Ok(unsafe { File::from_raw_fd(fd) })
}

fn call_openat(
    directory: &File,
    name: &CString,
    flags: c_int,
    mode: c_uint,
) -> Result<File, &'static str> {
    // SAFETY: both descriptors and the CString are valid for this syscall.
    let fd = unsafe { openat(directory.as_raw_fd(), name.as_ptr(), flags, mode) };
    if fd < 0 {
        return Err("unsafe filesystem state");
    }
    Ok(unsafe { File::from_raw_fd(fd) })
}

fn expected_owner() -> u32 {
    // SAFETY: geteuid has no preconditions and no side effects.
    unsafe { geteuid() }
}

pub fn has_effective_root() -> bool {
    #[cfg(feature = "test-support")]
    {
        true
    }
    #[cfg(not(feature = "test-support"))]
    {
        expected_owner() == 0
    }
}

fn validate_directory(metadata: &Metadata) -> Result<(), &'static str> {
    let owner_ok = metadata.uid() == expected_owner()
        || (cfg!(feature = "test-support") && matches!(metadata.uid(), 0 | 65_534));
    let mode_ok = metadata.mode() & 0o022 == 0
        || (cfg!(feature = "test-support") && metadata.uid() == 0 && metadata.mode() & 0o002 != 0);
    if !metadata.is_dir() || !owner_ok || metadata.nlink() == 0 || !mode_ok {
        return Err("unsafe filesystem state");
    }
    Ok(())
}

fn validate_regular_file(metadata: &Metadata) -> Result<(), &'static str> {
    if !metadata.is_file()
        || metadata.uid() != expected_owner()
        || metadata.nlink() != 1
        || metadata.mode() & 0o077 != 0
    {
        return Err("unsafe filesystem state");
    }
    Ok(())
}

fn policy_directory(path: &str) -> Result<File, &'static str> {
    let root = c_name("/")?;
    let mut directory = call_open(&root, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)?;
    validate_directory(
        &directory
            .metadata()
            .map_err(|_| "unsafe filesystem state")?,
    )?;
    for component in path.split('/').filter(|component| !component.is_empty()) {
        let name = c_name(component)?;
        let next = call_openat(
            &directory,
            &name,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC,
            0,
        )?;
        validate_directory(&next.metadata().map_err(|_| "unsafe filesystem state")?)?;
        directory = next;
    }
    Ok(directory)
}

fn synchronize(file: &File) -> Result<(), &'static str> {
    // SAFETY: the File descriptor is live for the syscall.
    if unsafe { fsync(file.as_raw_fd()) } != 0 {
        return Err("synchronization failed");
    }
    Ok(())
}

fn recognized_policy(bytes: &[u8]) -> bool {
    let Ok(text) = std::str::from_utf8(bytes) else {
        return false;
    };
    let Some(delay) =
        text.strip_prefix("# Managed by Hibermachy. Do not edit.\n[Sleep]\nHibernateDelaySec=")
    else {
        return false;
    };
    let Some((delay, ac)) = delay.split_once("s\nHibernateOnACPower=") else {
        return false;
    };
    if delay.is_empty()
        || delay.starts_with('0')
        || !delay.bytes().all(|byte| byte.is_ascii_digit())
    {
        return false;
    }
    let Ok(delay) = delay.parse::<u32>() else {
        return false;
    };
    if !(900..=604_800).contains(&delay) {
        return false;
    }
    matches!(ac, "yes\n" | "no\n")
}

fn recognized_existing_target(
    directory: &File,
    target: &CString,
) -> Result<Option<Vec<u8>>, &'static str> {
    let mut existing = match call_openat(
        directory,
        target,
        O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK,
        0,
    ) {
        Ok(existing) => existing,
        Err(_) => {
            let first_error = std::io::Error::last_os_error().raw_os_error();
            match call_openat(directory, target, O_PATH | O_NOFOLLOW | O_CLOEXEC, 0) {
                Ok(existing) => {
                    validate_regular_file(
                        &existing.metadata().map_err(|_| "unsafe filesystem state")?,
                    )?;
                    return Err("unsafe existing target");
                }
                Err(_)
                    if first_error == Some(2)
                        && std::io::Error::last_os_error().raw_os_error() == Some(2) =>
                {
                    return Ok(None);
                }
                Err(_) => return Err("unsafe existing target"),
            }
        }
    };
    validate_regular_file(&existing.metadata().map_err(|_| "unsafe filesystem state")?)?;
    let mut bytes = Vec::new();
    existing
        .read_to_end(&mut bytes)
        .map_err(|_| "unsafe filesystem state")?;
    if !recognized_policy(&bytes) {
        return Err("unrecognized existing policy");
    }
    Ok(Some(bytes))
}

#[cfg(feature = "test-support")]
fn inject_fault(stage: &str) -> Result<(), &'static str> {
    if std::env::var_os("HIBERMACHY_TEST_FAULT").as_deref() == Some(stage.as_ref()) {
        return Err(match stage {
            "write" => "write interrupted",
            "remove" => "removal interrupted",
            "sync" => "synchronization failed",
            "readback" => "readback indeterminate",
            "contradictory" => "readback contradictory",
            "final-sync" => "synchronization failed",
            _ => "injected failure",
        });
    }
    Ok(())
}

#[cfg(not(feature = "test-support"))]
fn inject_fault(_stage: &str) -> Result<(), &'static str> {
    Ok(())
}

pub fn remove_and_verify(directory_path: &str, target_name: &str) -> Result<(), &'static str> {
    let directory = policy_directory(directory_path)?;
    // SAFETY: the descriptor is live for the syscall.
    if unsafe { flock(directory.as_raw_fd(), LOCK_EX) } != 0 {
        return Err("lock failed");
    }
    let target = c_name(target_name)?;
    let Some(previous_policy) = recognized_existing_target(&directory, &target)? else {
        return Ok(());
    };
    #[cfg(feature = "test-support")]
    let temporary_suffix = std::env::var("HIBERMACHY_TEST_RESET_TEMP")
        .unwrap_or_else(|_| std::process::id().to_string());
    #[cfg(not(feature = "test-support"))]
    let temporary_suffix = std::process::id().to_string();
    let temporary = c_name(&format!(".{target_name}.{temporary_suffix}.reset.tmp"))?;
    let mut moved = false;
    let mut removed = false;
    let result = (|| {
        // SAFETY: both names are fixed invocation-local names within the validated directory.
        if unsafe {
            renameat2(
                directory.as_raw_fd(),
                target.as_ptr(),
                directory.as_raw_fd(),
                temporary.as_ptr(),
                RENAME_NOREPLACE,
            )
        } != 0
        {
            return Err("remove failed");
        }
        moved = true;
        inject_fault("remove")?;
        synchronize(&directory)?;
        inject_fault("sync")?;
        if recognized_existing_target(&directory, &target)?.is_some() {
            return Err("readback contradictory");
        }
        inject_fault("readback")?;
        inject_fault("contradictory")?;
        // The directory state was synchronized and absence was read back before cleanup.
        // SAFETY: only the temporary object created by this invocation is removed.
        if unsafe { unlinkat(directory.as_raw_fd(), temporary.as_ptr(), 0) } != 0 {
            return Err("remove failed");
        }
        removed = true;
        synchronize(&directory)?;
        inject_fault("final-sync")?;
        Ok(())
    })();
    if result.is_err() && moved {
        let restored = if removed {
            restore_removed_policy(&directory, &target, &previous_policy, &temporary_suffix)
        } else {
            // SAFETY: restore the complete recognized policy to its original fixed name.
            (unsafe {
                renameat2(
                    directory.as_raw_fd(),
                    temporary.as_ptr(),
                    directory.as_raw_fd(),
                    target.as_ptr(),
                    RENAME_NOREPLACE,
                )
            } == 0)
                && synchronize(&directory).is_ok()
        };
        if !restored {
            return Err("rollback failed");
        }
    }
    result
}

fn restore_removed_policy(directory: &File, target: &CString, bytes: &[u8], suffix: &str) -> bool {
    let Ok(temporary) = c_name(&format!(".restore-{suffix}.tmp")) else {
        return false;
    };
    let Ok(mut file) = call_openat(
        directory,
        &temporary,
        O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
        0o600,
    ) else {
        return false;
    };
    if file.write_all(bytes).is_err() || synchronize(&file).is_err() {
        // SAFETY: only this invocation's exclusive temporary name is removed.
        unsafe { unlinkat(directory.as_raw_fd(), temporary.as_ptr(), 0) };
        return false;
    }
    drop(file);
    // SAFETY: never overwrite a target that appeared while reset was in progress.
    if unsafe {
        renameat2(
            directory.as_raw_fd(),
            temporary.as_ptr(),
            directory.as_raw_fd(),
            target.as_ptr(),
            RENAME_NOREPLACE,
        )
    } != 0
    {
        // SAFETY: only this invocation's exclusive temporary name is removed.
        unsafe { unlinkat(directory.as_raw_fd(), temporary.as_ptr(), 0) };
        return false;
    }
    synchronize(directory).is_ok()
}

pub fn replace_and_verify(
    directory_path: &str,
    target_name: &str,
    bytes: &[u8],
) -> Result<(), &'static str> {
    let directory = policy_directory(directory_path)?;
    // A directory lock serializes cooperating helper instances without a second policy object.
    // SAFETY: the descriptor is live for the syscall.
    if unsafe { flock(directory.as_raw_fd(), LOCK_EX) } != 0 {
        return Err("lock failed");
    }
    let target = c_name(target_name)?;
    let previous_policy = recognized_existing_target(&directory, &target)?;
    let had_previous_policy = previous_policy.is_some();
    let temporary = c_name(&format!(".{target_name}.{}.tmp", std::process::id()))?;
    let mut temp = call_openat(
        &directory,
        &temporary,
        O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
        0o600,
    )?;
    validate_regular_file(&temp.metadata().map_err(|_| "unsafe filesystem state")?)?;
    let mut replaced = false;
    let result = (|| {
        temp.write_all(bytes).map_err(|_| "write failed")?;
        inject_fault("write")?;
        synchronize(&temp)?;
        inject_fault("sync")?;
        if recognized_existing_target(&directory, &target)? != previous_policy {
            return Err("target changed");
        }
        drop(temp);
        // SAFETY: names are fixed C strings and both operations stay within the validated directory.
        let replacement_status = if had_previous_policy {
            unsafe {
                renameat2(
                    directory.as_raw_fd(),
                    temporary.as_ptr(),
                    directory.as_raw_fd(),
                    target.as_ptr(),
                    RENAME_EXCHANGE,
                )
            }
        } else {
            unsafe {
                renameat2(
                    directory.as_raw_fd(),
                    temporary.as_ptr(),
                    directory.as_raw_fd(),
                    target.as_ptr(),
                    RENAME_NOREPLACE,
                )
            }
        };
        if replacement_status != 0 {
            return Err("replace failed");
        }
        replaced = true;
        synchronize(&directory)?;
        inject_fault("readback")?;
        let mut policy = call_openat(&directory, &target, O_RDONLY | O_NOFOLLOW | O_CLOEXEC, 0)?;
        validate_regular_file(&policy.metadata().map_err(|_| "unsafe filesystem state")?)?;
        let mut actual = Vec::new();
        policy
            .read_to_end(&mut actual)
            .map_err(|_| "readback indeterminate")?;
        inject_fault("contradictory")?;
        if actual != bytes {
            return Err("readback contradictory");
        }
        Ok(())
    })();
    if result.is_err() && replaced && had_previous_policy {
        // SAFETY: swap back only the two names we created/validated, preserving the prior policy.
        unsafe {
            renameat2(
                directory.as_raw_fd(),
                temporary.as_ptr(),
                directory.as_raw_fd(),
                target.as_ptr(),
                RENAME_EXCHANGE,
            )
        };
        let _ = synchronize(&directory);
    } else if result.is_err() && replaced {
        // SAFETY: this target was created by this invocation and there was no prior policy.
        unsafe { unlinkat(directory.as_raw_fd(), target.as_ptr(), 0) };
        let _ = synchronize(&directory);
    }
    if had_previous_policy || result.is_err() {
        // SAFETY: cleanup is limited to this invocation's unique temporary name.
        unsafe { unlinkat(directory.as_raw_fd(), temporary.as_ptr(), 0) };
    }
    result
}
