use std::{fs, process::Command, sync::{Mutex, OnceLock}};

fn test_lock() -> std::sync::MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    LOCK.get_or_init(|| Mutex::new(())).lock().unwrap()
}

fn helper() -> Command {
    Command::new(env!("CARGO_BIN_EXE_hibermachy-policy-helper"))
}

fn policy_path() -> std::path::PathBuf {
    std::path::PathBuf::from(env!("HIBERMACHY_COMPILED_ROOT"))
        .join("etc/systemd/sleep.conf.d/90-hibermachy.conf")
}

fn prepare_policy_directory() -> std::path::PathBuf {
    let target = policy_path();
    fs::remove_dir_all(target.parent().unwrap().ancestors().nth(3).unwrap()).ok();
    fs::create_dir_all(target.parent().unwrap()).unwrap();
    target
}

#[test]
fn apply_writes_the_recognized_requested_policy_at_the_owned_target() {
    let _guard = test_lock();
    let target = prepare_policy_directory();

    let result = helper().args(["apply", "900", "no"]).env_clear().output().unwrap();

    assert!(result.status.success(), "stderr: {}", String::from_utf8_lossy(&result.stderr));
    assert_eq!(fs::read_to_string(target).unwrap(), "# Managed by Hibermachy. Do not edit.\n[Sleep]\nHibernateDelaySec=900s\nHibernateOnACPower=no\n");
}

#[test]
fn malformed_or_out_of_range_apply_is_rejected_without_creating_a_policy() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    for arguments in [["apply", "899", "no"], ["apply", "604801", "no"], ["apply", "+900", "no"], ["apply", "900.0", "no"], ["apply", "９００", "no"], ["apply", "9999999", "no"], ["apply", "900", "true"], ["apply", "900", "no", "extra"]] {
        let result = helper().args(arguments).env_clear().output().unwrap();
        assert!(!result.status.success());
        assert!(!target.exists());
    }
}

#[test]
fn apply_refuses_a_hostile_existing_target_without_changing_it() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    fs::write(&target, "administrator-owned content\n").unwrap();

    let result = helper().args(["apply", "900", "yes"]).env_clear().output().unwrap();

    assert!(!result.status.success());
    assert_eq!(fs::read_to_string(target).unwrap(), "administrator-owned content\n");
}

#[test]
fn concurrent_apply_operations_leave_one_complete_recognized_policy() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    let first = helper().args(["apply", "900", "no"]).env_clear().spawn().unwrap();
    let second = helper().args(["apply", "901", "yes"]).env_clear().spawn().unwrap();

    assert!(first.wait_with_output().unwrap().status.success());
    assert!(second.wait_with_output().unwrap().status.success());
    let policy = fs::read_to_string(target).unwrap();
    assert!(policy == "# Managed by Hibermachy. Do not edit.\n[Sleep]\nHibernateDelaySec=900s\nHibernateOnACPower=no\n" || policy == "# Managed by Hibermachy. Do not edit.\n[Sleep]\nHibernateDelaySec=901s\nHibernateOnACPower=yes\n");
}

#[cfg(unix)]
#[test]
fn apply_refuses_a_symlinked_target_without_touching_its_destination() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    let outside = target.parent().unwrap().join("outside");
    fs::write(&outside, "do not change\n").unwrap();
    std::os::unix::fs::symlink(&outside, &target).unwrap();

    let result = helper().args(["apply", "900", "no"]).env_clear().output().unwrap();

    assert!(!result.status.success());
    assert_eq!(fs::read_to_string(outside).unwrap(), "do not change\n");
}
