use std::{
    fs,
    process::Command,
    sync::{Mutex, OnceLock},
};

#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;

fn test_lock() -> std::sync::MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    LOCK.get_or_init(|| Mutex::new(()))
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner())
}

fn helper() -> Command {
    Command::new(env!("CARGO_BIN_EXE_hibermachy-policy-helper"))
}

fn policy_path() -> std::path::PathBuf {
    std::path::PathBuf::from(env!("HIBERMACHY_COMPILED_ROOT"))
        .join("etc/systemd/sleep.conf.d/90-hibermachy.conf")
}

fn run(arguments: &[&str]) -> std::process::Output {
    helper().args(arguments).env_clear().output().unwrap()
}

fn run_fault(arguments: &[&str], fault: &str) -> std::process::Output {
    helper()
        .args(arguments)
        .env_clear()
        .env("HIBERMACHY_TEST_FAULT", fault)
        .env("PATH", "/hostile/path")
        .env("HOME", "/hostile/home")
        .env("HIBERMACHY_TEST_ROOT", "/hostile/root")
        .output()
        .unwrap()
}

fn run_hostile_environment(arguments: &[&str]) -> std::process::Output {
    helper()
        .args(arguments)
        .env_clear()
        .env("PATH", "/hostile/path")
        .env("HOME", "/hostile/home")
        .env("HIBERMACHY_TEST_ROOT", "/hostile/root")
        .output()
        .unwrap()
}

fn assert_bounded_diagnostic(result: &std::process::Output) {
    let diagnostic = String::from_utf8_lossy(&result.stderr);
    assert!(
        diagnostic.len() <= 128,
        "diagnostic was too long: {diagnostic:?}"
    );
    assert!(
        !diagnostic.contains('/'),
        "diagnostic leaked a path: {diagnostic:?}"
    );
}

fn prepare_policy_directory() -> std::path::PathBuf {
    let target = policy_path();
    fs::remove_dir_all(target.parent().unwrap().ancestors().nth(3).unwrap()).ok();
    fs::create_dir_all(target.parent().unwrap()).unwrap();
    target
}

fn recognized_policy(delay: &str, ac: &str) -> String {
    format!(
        "# Managed by Hibermachy. Do not edit.\n[Sleep]\nHibernateDelaySec={delay}s\nHibernateOnACPower={ac}\n"
    )
}

#[test]
fn apply_writes_the_recognized_requested_policy_at_the_owned_target() {
    let _guard = test_lock();
    let target = prepare_policy_directory();

    let result = run(&["apply", "900", "no"]);

    assert!(
        result.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&result.stderr)
    );
    assert_eq!(
        fs::read_to_string(target).unwrap(),
        "# Managed by Hibermachy. Do not edit.\n[Sleep]\nHibernateDelaySec=900s\nHibernateOnACPower=no\n"
    );
}

#[test]
fn apply_reports_the_canonical_requested_policy_for_the_panel_to_reconcile() {
    let _guard = test_lock();
    prepare_policy_directory();

    let result = run(&["apply", "7200", "no"]);

    assert!(result.status.success());
    assert_eq!(
        String::from_utf8(result.stdout).unwrap(),
        "requested-delay-seconds=7200 requested-hibernate-on-ac=no\n"
    );
}

#[test]
fn read_only_protocol_probe_reports_release_and_supported_range_without_root() {
    let _guard = test_lock();
    let target = prepare_policy_directory();

    let result = run(&["probe"]);

    assert!(
        result.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&result.stderr)
    );
    assert_eq!(
        String::from_utf8(result.stdout).unwrap(),
        "release=0.1.0 protocol-min=1 protocol-max=1\n"
    );
    assert!(!target.exists());
}

#[test]
fn reset_is_idempotent_for_absent_target_and_removes_a_canonical_policy() {
    let _guard = test_lock();
    let target = prepare_policy_directory();

    let absent = run(&["reset"]);
    assert!(
        absent.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&absent.stderr)
    );
    fs::write(&target, recognized_policy("900", "no")).unwrap();
    fs::set_permissions(&target, fs::Permissions::from_mode(0o600)).unwrap();

    let removed = run(&["reset"]);
    assert!(
        removed.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&removed.stderr)
    );
    assert!(!target.exists());
    assert_eq!(fs::read_dir(target.parent().unwrap()).unwrap().count(), 0);
    assert!(run(&["reset"]).status.success());
}

#[test]
fn reset_rejects_unrecognized_content_without_deleting_it() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    fs::write(&target, "administrator-owned content\n").unwrap();

    let result = run(&["reset"]);

    assert!(!result.status.success());
    assert_eq!(
        fs::read_to_string(target).unwrap(),
        "administrator-owned content\n"
    );
}

#[cfg(unix)]
#[test]
fn reset_rejects_symlinks_hard_links_and_wrong_permissions_without_touching_outside() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    let outside = target.parent().unwrap().join("outside");
    fs::write(&outside, recognized_policy("900", "no")).unwrap();
    std::os::unix::fs::symlink(&outside, &target).unwrap();

    let symlink_result = run(&["reset"]);
    assert!(!symlink_result.status.success());
    assert_eq!(
        fs::read_to_string(&outside).unwrap(),
        recognized_policy("900", "no")
    );

    fs::remove_file(&target).unwrap();
    fs::write(&target, recognized_policy("901", "yes")).unwrap();
    fs::hard_link(&target, target.parent().unwrap().join("hard-link")).unwrap();
    let hard_link_result = run(&["reset"]);
    assert!(!hard_link_result.status.success());
    assert!(target.exists());

    fs::remove_file(target.parent().unwrap().join("hard-link")).unwrap();
    fs::set_permissions(&target, fs::Permissions::from_mode(0o644)).unwrap();
    let permissions_result = run(&["reset"]);
    assert!(!permissions_result.status.success());
    assert!(target.exists());
}

#[test]
fn reset_readback_faults_restore_the_complete_previous_policy() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    let previous = recognized_policy("900", "no");
    fs::write(&target, &previous).unwrap();
    fs::set_permissions(&target, fs::Permissions::from_mode(0o600)).unwrap();

    for fault in ["remove", "sync", "readback", "contradictory", "final-sync"] {
        let result = run_fault(&["reset"], fault);
        assert!(
            !result.status.success(),
            "fault {fault} unexpectedly succeeded"
        );
        assert_eq!(fs::read_to_string(&target).unwrap(), previous);
        assert_eq!(fs::read_dir(target.parent().unwrap()).unwrap().count(), 1);
    }
}

#[test]
fn reset_rejects_invalid_commands_without_mutating_a_policy() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    let previous = recognized_policy("900", "no");
    fs::write(&target, &previous).unwrap();
    fs::set_permissions(&target, fs::Permissions::from_mode(0o600)).unwrap();

    for arguments in [vec![], vec!["reset", "extra"], vec!["unknown"]] {
        let result = run(&arguments);
        assert!(!result.status.success());
        assert_bounded_diagnostic(&result);
        assert_eq!(fs::read_to_string(&target).unwrap(), previous);
    }
}

#[cfg(unix)]
#[test]
fn reset_rejects_unexpected_types_wrong_ownership_and_parent_substitution() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    fs::create_dir(&target).unwrap();
    assert!(!run(&["reset"]).status.success());
    fs::remove_dir(&target).unwrap();

    fs::write(&target, recognized_policy("900", "no")).unwrap();
    if std::process::Command::new("chown")
        .args(["65534:65534", target.to_str().unwrap()])
        .stderr(std::process::Stdio::null())
        .status()
        .unwrap()
        .success()
    {
        assert!(!run(&["reset"]).status.success());
        assert!(target.exists());
    }
    fs::remove_file(&target).unwrap();

    let root = target
        .parent()
        .unwrap()
        .ancestors()
        .nth(2)
        .unwrap()
        .to_path_buf();
    let policy_directory = target.parent().unwrap().to_path_buf();
    let outside = root.join("outside-reset-policy");
    fs::create_dir_all(&outside).unwrap();
    fs::remove_dir(&policy_directory).unwrap();
    std::os::unix::fs::symlink(&outside, &policy_directory).unwrap();
    let result = run(&["reset"]);
    assert!(!result.status.success());
    assert_eq!(fs::read_dir(&outside).unwrap().count(), 0);
}

#[test]
fn reset_refuses_a_preexisting_invocation_temporary_without_changing_either_object() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    let temporary = target.parent().unwrap().join(format!(
        ".{}.{}.reset.tmp",
        target.file_name().unwrap().to_string_lossy(),
        "collision"
    ));
    let previous = recognized_policy("900", "no");
    fs::write(&target, &previous).unwrap();
    fs::set_permissions(&target, fs::Permissions::from_mode(0o600)).unwrap();
    fs::write(&temporary, "administrator temporary\n").unwrap();

    let result = helper()
        .args(["reset"])
        .env_clear()
        .env("HIBERMACHY_TEST_RESET_TEMP", "collision")
        .output()
        .unwrap();

    assert!(!result.status.success());
    assert_eq!(fs::read_to_string(&target).unwrap(), previous);
    assert_eq!(
        fs::read_to_string(temporary).unwrap(),
        "administrator temporary\n"
    );
}

#[test]
fn concurrent_apply_and_reset_leave_absent_or_one_complete_policy() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    let first = helper()
        .args(["apply", "900", "no"])
        .env_clear()
        .spawn()
        .unwrap();
    let second = helper().args(["reset"]).env_clear().spawn().unwrap();
    assert!(first.wait_with_output().unwrap().status.success());
    assert!(second.wait_with_output().unwrap().status.success());

    if target.exists() {
        assert_eq!(
            fs::read_to_string(target).unwrap(),
            recognized_policy("900", "no")
        );
    }
}

#[test]
fn malformed_or_out_of_range_apply_is_rejected_without_creating_a_policy() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    for arguments in [
        vec![],
        vec!["apply"],
        vec!["apply", "899", "no"],
        vec!["apply", "604801", "no"],
        vec!["apply", "-900", "no"],
        vec!["apply", "+900", "no"],
        vec!["apply", "900.0", "no"],
        vec!["apply", "９００", "no"],
        vec!["apply", "9999999", "no"],
        vec!["apply", "4294967296", "no"],
        vec!["apply", "900", "true"],
        vec!["apply", "900", "no", "extra"],
    ] {
        let result = run(&arguments);
        assert!(!result.status.success());
        assert_bounded_diagnostic(&result);
        assert!(!target.exists());
    }
}

#[test]
fn apply_accepts_both_delay_boundaries_and_both_ac_values() {
    let _guard = test_lock();
    for arguments in [["apply", "900", "no"], ["apply", "604800", "yes"]] {
        let target = prepare_policy_directory();
        let result = run(&arguments);
        assert!(
            result.status.success(),
            "stderr: {}",
            String::from_utf8_lossy(&result.stderr)
        );
        assert!(fs::read_to_string(target).unwrap().contains(arguments[1]));
        assert!(
            fs::read_to_string(policy_path())
                .unwrap()
                .contains(arguments[2])
        );
    }
}

#[test]
fn apply_ignores_hostile_environment_and_uses_the_compiled_fixture_root() {
    let _guard = test_lock();
    let target = prepare_policy_directory();

    let result = run_hostile_environment(&["apply", "900", "no"]);

    assert!(
        result.status.success(),
        "stderr: {}",
        String::from_utf8_lossy(&result.stderr)
    );
    assert!(target.exists());
    assert_bounded_diagnostic(&result);
}

#[test]
fn apply_refuses_a_hostile_existing_target_without_changing_it() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    fs::write(&target, "administrator-owned content\n").unwrap();

    let result = run(&["apply", "900", "yes"]);

    assert!(!result.status.success());
    assert_eq!(
        fs::read_to_string(target).unwrap(),
        "administrator-owned content\n"
    );
}

#[test]
fn concurrent_apply_operations_leave_one_complete_recognized_policy() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    let first = helper()
        .args(["apply", "900", "no"])
        .env_clear()
        .spawn()
        .unwrap();
    let second = helper()
        .args(["apply", "901", "yes"])
        .env_clear()
        .spawn()
        .unwrap();

    assert!(first.wait_with_output().unwrap().status.success());
    assert!(second.wait_with_output().unwrap().status.success());
    let policy = fs::read_to_string(target).unwrap();
    assert!(
        policy
            == "# Managed by Hibermachy. Do not edit.\n[Sleep]\nHibernateDelaySec=900s\nHibernateOnACPower=no\n"
            || policy
                == "# Managed by Hibermachy. Do not edit.\n[Sleep]\nHibernateDelaySec=901s\nHibernateOnACPower=yes\n"
    );
}

#[cfg(unix)]
#[test]
fn apply_refuses_a_symlinked_target_without_touching_its_destination() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    let outside = target.parent().unwrap().join("outside");
    fs::write(&outside, "do not change\n").unwrap();
    std::os::unix::fs::symlink(&outside, &target).unwrap();

    let result = run(&["apply", "900", "no"]);

    assert!(!result.status.success());
    assert_eq!(fs::read_to_string(outside).unwrap(), "do not change\n");
}

#[test]
fn interrupted_write_leaves_no_target_or_invocation_temporary() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    let result = run_fault(&["apply", "900", "no"], "write");

    assert!(!result.status.success());
    assert_bounded_diagnostic(&result);
    assert!(!target.exists());
    assert_eq!(fs::read_dir(target.parent().unwrap()).unwrap().count(), 0);
}

#[test]
fn readback_faults_restore_the_complete_previous_policy() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    let previous = "# Managed by Hibermachy. Do not edit.\n[Sleep]\nHibernateDelaySec=900s\nHibernateOnACPower=no\n";
    fs::write(&target, previous).unwrap();
    fs::set_permissions(&target, fs::Permissions::from_mode(0o600)).unwrap();

    for fault in ["sync", "readback", "contradictory"] {
        let result = run_fault(&["apply", "901", "yes"], fault);
        assert!(
            !result.status.success(),
            "fault {fault} unexpectedly succeeded"
        );
        assert_bounded_diagnostic(&result);
        if fault == "readback" {
            assert!(
                String::from_utf8_lossy(&result.stderr).contains("readback indeterminate"),
                "stderr: {}",
                String::from_utf8_lossy(&result.stderr)
            );
        }
        assert_eq!(fs::read_to_string(&target).unwrap(), previous);
        assert_eq!(fs::read_dir(target.parent().unwrap()).unwrap().count(), 1);
    }
}

#[cfg(unix)]
#[test]
fn apply_refuses_a_symlinked_policy_directory_without_touching_outside() {
    let _guard = test_lock();
    let target = prepare_policy_directory();
    let root = target
        .parent()
        .unwrap()
        .ancestors()
        .nth(2)
        .unwrap()
        .to_path_buf();
    let policy_directory = target.parent().unwrap().to_path_buf();
    let outside = root.join("outside-policy");
    fs::create_dir_all(&outside).unwrap();
    fs::remove_dir(&policy_directory).unwrap();
    std::os::unix::fs::symlink(&outside, &policy_directory).unwrap();

    let result = run(&["apply", "900", "no"]);

    assert!(!result.status.success());
    assert_bounded_diagnostic(&result);
    assert!(!outside.join("90-hibermachy.conf").exists());
}
