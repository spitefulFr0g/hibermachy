use std::{
    fs,
    process::{Command, Output, Stdio},
    sync::{Mutex, OnceLock},
};

#[cfg(unix)]
use std::os::unix::fs::PermissionsExt;

fn test_lock() -> std::sync::MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    LOCK.get_or_init(|| Mutex::new(())).lock().unwrap()
}

fn helper() -> Command {
    Command::new(env!("CARGO_BIN_EXE_hibermachy-policy-helper"))
}

fn target() -> std::path::PathBuf {
    std::path::PathBuf::from(env!("HIBERMACHY_COMPILED_ROOT"))
        .join("etc/systemd/sleep.conf.d/90-hibermachy.conf")
}

fn reset_fixture() -> std::path::PathBuf {
    let target = target();
    fs::remove_dir_all(target.parent().unwrap().ancestors().nth(3).unwrap()).ok();
    fs::create_dir_all(target.parent().unwrap()).unwrap();
    target
}

fn run(arguments: &[&str]) -> Output {
    helper().args(arguments).env_clear().output().unwrap()
}

fn run_with_untrusted_environment(arguments: &[&str]) -> Output {
    helper()
        .args(arguments)
        .env_clear()
        .env("PATH", "/fixture/untrusted-path")
        .env("HOME", "/fixture/untrusted-home")
        .env("HIBERMACHY_TEST_ROOT", "/fixture/untrusted-root")
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .unwrap()
}

fn canonical(delay: &str, ac: &str) -> String {
    format!(
        "# Managed by Hibermachy. Do not edit.\n[Sleep]\nHibernateDelaySec={delay}s\nHibernateOnACPower={ac}\n"
    )
}

#[test]
fn hbr_chk_helper_001_input_gate_rejects_the_complete_bounded_adversarial_corpus() {
    let _guard = test_lock();
    let target = reset_fixture();
    let cases: &[&[&str]] = &[
        &[],
        &["apply"],
        &["apply", "899", "no"],
        &["apply", "604801", "no"],
        &["apply", "-900", "no"],
        &["apply", "+900", "no"],
        &["apply", "900.0", "no"],
        &["apply", "９００", "no"],
        &["apply", "4294967296", "no"],
        &["apply", "900", "maybe"],
        &["apply", "900", "no", "extra"],
        &["probe", "forged-protocol=1"],
        &["apply", "900", "no", "protocol-max=999"],
    ];
    for arguments in cases {
        let result = run(arguments);
        assert!(!result.status.success());
        assert!(!target.exists());
    }

    let oversized = "7".repeat(4097);
    let result = run(&["apply", &oversized, "no"]);
    assert!(!result.status.success());
    assert!(!target.exists());
}

#[test]
fn hbr_chk_helper_002_input_gate_accepts_only_protocol_probe_and_policy_boundaries() {
    let _guard = test_lock();
    let target = reset_fixture();

    let probe = run(&["probe"]);
    assert!(probe.status.success());
    assert_eq!(
        String::from_utf8(probe.stdout).unwrap(),
        "release=0.1.0 protocol-min=1 protocol-max=1\n"
    );
    assert!(!target.exists());

    for (delay, ac) in [("900", "no"), ("604800", "yes")] {
        let result = run(&["apply", delay, ac]);
        assert!(result.status.success());
        assert_eq!(fs::read_to_string(&target).unwrap(), canonical(delay, ac));
        fs::remove_file(&target).unwrap();
    }
}

#[test]
fn hbr_chk_helper_003_public_process_ignores_untrusted_environment_and_descriptors() {
    let _guard = test_lock();
    let target = reset_fixture();

    let result = run_with_untrusted_environment(&["apply", "900", "no"]);
    assert!(result.status.success());
    assert_eq!(fs::read_to_string(target).unwrap(), canonical("900", "no"));
}

#[cfg(unix)]
#[test]
fn hbr_chk_helper_004_owned_target_rejects_unexpected_metadata_without_escape() {
    let _guard = test_lock();
    let target = reset_fixture();
    let directory = target.parent().unwrap();
    let outside = directory.parent().unwrap().join("outside-sentinel");
    fs::write(&outside, "outside remains unchanged\n").unwrap();

    fs::create_dir(&target).unwrap();
    assert!(!run(&["reset"]).status.success());
    fs::remove_dir(&target).unwrap();

    fs::write(&target, canonical("900", "no")).unwrap();
    fs::set_permissions(&target, fs::Permissions::from_mode(0o644)).unwrap();
    assert!(!run(&["reset"]).status.success());
    assert_eq!(fs::read_to_string(&outside).unwrap(), "outside remains unchanged\n");
}
