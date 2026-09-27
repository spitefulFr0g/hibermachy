# Establish helper security and packaging constraints

Type: research
Status: resolved
Blocked by:

## Question

What exact systemd, Polkit, filesystem, packaging, and lifecycle constraints must a one-shot Hibermachy helper satisfy to edit only its sleep-policy drop-in safely on current Omarchy 4.0.1?

## Answer

systemd 261 has no per-request hibernate-delay API, so Hibermachy needs a system-wide drop-in. Ship the privileged integration as a separate Arch package containing a non-setuid, compiled, root-owned one-shot helper and an application Polkit policy. The only mutating commands are `apply <delay-seconds> <yes|no>` and `reset`; every invocation uses active-session `auth_admin` without retained authorization.

The helper atomically owns only `/etc/systemd/sleep.conf.d/90-hibermachy.conf`, validates fixed arguments and filesystem metadata after elevation, rejects path/environment/symlink influence, and never invokes a shell, sleeps the machine, bypasses inhibitors, or provisions hibernation. No daemon reload is necessary. Package removal uses the validated reset path before removing the helper; plugin removal alone cannot silently remove system-wide policy.

Research context: branch `research/helper-security-packaging`, commit `65c3dc8`, report `docs/research/helper-security-packaging.md`.
