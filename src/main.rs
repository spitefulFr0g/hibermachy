#![deny(unsafe_code)]

mod secure_fs;

use std::{env, process::ExitCode};

const TARGET_NAME: &str = "90-hibermachy.conf";
const POLICY_PREFIX: &str = "# Managed by Hibermachy. Do not edit.\n[Sleep]\n";

#[cfg(hibermachy_test_root)]
const POLICY_DIRECTORY: &str = concat!(env!("HIBERMACHY_COMPILED_ROOT"), "/etc/systemd/sleep.conf.d");
#[cfg(not(hibermachy_test_root))]
const POLICY_DIRECTORY: &str = "/etc/systemd/sleep.conf.d";

#[derive(Clone, Copy)]
struct RequestedSystemPolicy {
    hibernate_delay_seconds: u32,
    hibernate_on_ac_power: bool,
}

impl RequestedSystemPolicy {
    fn recognized_bytes(self) -> String {
        let ac = if self.hibernate_on_ac_power { "yes" } else { "no" };
        format!("{POLICY_PREFIX}HibernateDelaySec={}s\nHibernateOnACPower={ac}\n", self.hibernate_delay_seconds)
    }
}

fn parse_apply(arguments: &[String]) -> Result<RequestedSystemPolicy, &'static str> {
    let [delay, ac] = arguments else { return Err("invalid command"); };
    if delay.is_empty() || delay.len() > 6 || !delay.bytes().all(|byte| byte.is_ascii_digit()) || delay.starts_with('0') {
        return Err("invalid delay");
    }
    let hibernate_delay_seconds = delay.parse::<u32>().map_err(|_| "invalid delay")?;
    if !(900..=604_800).contains(&hibernate_delay_seconds) {
        return Err("invalid delay");
    }
    let hibernate_on_ac_power = match ac.as_str() {
        "yes" => true,
        "no" => false,
        _ => return Err("invalid AC setting"),
    };
    Ok(RequestedSystemPolicy { hibernate_delay_seconds, hibernate_on_ac_power })
}

fn run() -> Result<(), &'static str> {
    if !secure_fs::has_effective_root() {
        return Err("effective root required");
    }
    let arguments: Vec<String> = env::args().skip(1).collect();
    let (command, values) = arguments.split_first().ok_or("invalid command")?;
    if command != "apply" {
        return Err("invalid command");
    }
    let policy = parse_apply(values)?;
    let bytes = policy.recognized_bytes();
    secure_fs::replace_and_verify(POLICY_DIRECTORY, TARGET_NAME, bytes.as_bytes())
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(reason) => {
            // This is intentionally bounded: privileged diagnostics never include caller paths,
            // environment values, or operating-system error text.
            eprintln!("hibermachy-policy-helper: {reason}");
            ExitCode::from(1)
        }
    }
}
