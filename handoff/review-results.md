# Security review results — Hibermachy (light, quick)

Date: 2026-09-08
Scope: read-only review, no code changes made.
Reviewed: `impl/21-helper-lifecycle-merge-gates` (most complete branch: Rust helper + QML plugin + lifecycle/packaging), with spot-checks of earlier `impl/*` branches via `git show` only.
Note: `main` (`0f89e69`) contains only spec/docs; all implementation lives on unmerged `impl/*` branches.

Verdict: no showstopper / obvious root-execution primitive found. The privileged design is narrow and mostly careful. Findings below are worries to track, roughly ordered.

## 1. Privileged helper (`src/main.rs`, `src/secure_fs.rs`) — good, with gaps vs. its own spec

What looks right:
- Fixed vocabulary only (`apply <delay> <yes|no>`, `reset`, unprivileged `probe`). Strict apply validation: ASCII digits, no leading zero, len ≤ 6, range 900–604800, exact `yes`/`no`.
- Fixed target, descriptor-relative traversal with `O_NOFOLLOW`, per-component dir validation (owner, non-world-writable, `nlink != 0`), file validation (regular, owner = euid, `nlink == 1`, mode exactly `0600`).
- Atomic replace via same-dir temp + `RENAME_EXCHANGE`/`RENAME_NOREPLACE` + fsync + readback verification; refuses unrecognized/symlinked/oddly-owned targets; rollback uses `RENAME_NOREPLACE` so it won't clobber an admin-recreated file.
- No shell, no external commands, no network; bounded stderr without paths/OS errors (there is a test asserting this).
- `test-support` backdoors (`has_effective_root() == true`, relaxed uid/mode checks, `HIBERMACHY_TEST_FAULT`, custom test root) are `#[cfg(feature = "test-support")]`-gated, and `packaging/PKGBUILD` builds with plain `cargo build --release --locked` (feature off). Never enable that feature in the real package.

Gaps / to close before daily use (the spec already demands most of this):
- Spec says the helper "changes to a safe working directory, sets a restrictive umask, closes unexpected descriptors, distrusts environment" — none of that was visible in `main.rs`/`secure_fs.rs`. Temp mode is explicitly `0600` so umask is less critical, but the missing chdir/fd-closing/env-scrubbing is a spec-vs-code delta.
- Temp names are pid-predictable (`.90-hibermachy.<pid>.tmp`). Safe today only because the parent dir is root-owned/non-writable and creation uses `O_EXCL|O_NOFOLLOW`. Still fragile if that directory invariant ever weakens; a random suffix would be cheaper.
- Rollback path (`remove_and_verify` / `restore_removed_policy`) is the most complex code here and the hardest to eyeball. No flaw found, but this is exactly what the planned "disposable-VM hostile-filesystem + independent security-aware human review" gate is for — don't call it audited yet (the spec already says this).

## 2. Polkit + packaging — sound

- `packaging/org.hibermachy.policy-helper.policy`: `allow_any=no`, `allow_inactive=no`, `allow_active=auth_admin`, bound to `/usr/libexec/hibermachy-policy-helper`. No `auth_admin_keep`, no passwordless rule, no shipped rules file, non-setuid. Matches spec.
- `PKGBUILD` keeps `__RELEASE_SHA512__` / `__RELEASE_SIGNING_KEY__` sentinels so an unsigned package can't be published accidentally. Correct placeholder behavior.
- `hibermachy-helper.install` `pre_remove()` runs `reset || :` — deliberately masks failure so pacman isn't reported aborted. Documented, but a failed reset can leave policy behind; lifecycle callers must (and per code, do) verify absence afterward rather than trusting the scriptlet.

## 3. QML service (`plugin/Service.qml`) — two fixable hardening issues

- **PATH-relative executables.** `sleepRequestProcess` runs `["systemctl", …]`, capability probe runs bare `loginctl`, Stay-Awake probe runs bare `omarchy-toggle-idle`. A poisoned `PATH` for the user session could redirect these. Prefer absolute paths (`/usr/bin/systemctl`, etc.).
- **Env-overridable security-relevant paths.** `HBR_POLICY_HELPER_PATH`, `HBR_POLICY_HELPER_LAUNCHER` (default `pkexec`), `HBR_EFFECTIVE_POLICY_READER`, `HBR_CONTRACT_PROBE`, plus `XDG_CONFIG_HOME`/`HOME` for the policy path, are honored unconditionally. Fine for tests, but in production any process sharing the user's env can redirect the helper/launcher/policy reader and spoof readiness or (via pkexec) change which action gets authorized. Gate these overrides behind `HBR_TEST_MODE=1` or an allowlist.
- One `/bin/sh -c` usage (`policyPermissionProbe`) passes the directory as `$1` (quoted, not interpolated) — not injectable as written, but it's the only shell in the plugin; replacing it with a direct `stat` probe would remove the question entirely.
- IPC (`IpcHandler target dev.hibermachy`) exposes `requestStagedSleep()` with no confirmation — any same-user process can suspend the machine. Same-user code can already run `systemctl suspend`, so severity is low, but confirm this is intentional and document it.

## 4. Lifecycle scripts (`lifecycle/install|status|uninstall`, `lifecycle/remove`) — careful, test-fixture-bound

- Good symlink hygiene where checked: `lstat` checks on `plugin/`, `menu.jsonc`, `helper/package`, `activation.json`; refuses to follow/replace suspicious objects; menu edit only touches lines with `managedBy: hibermachy` and refuses modified managed entries.
- Purge/uninstall ordering (reset recognized policy → remove package → menu → checkout last; purge deletes user data last with separate confirmation) matches spec.
- Caveat: these scripts are heavily fixture-driven (`--root`, `helper-build`, `package-install` fixture files). Real-world safety (ownership checks without symlink escape on true `/`, pacman auth, real menu JSONC) is only proven in the later disposable-system gates, not in ordinary CI. Don't treat fixture tests as proof.

## Suggested next steps (no code touched)

1. Absolute-path the `systemctl`/`loginctl`/`omarchy-toggle-idle` invocations; gate `HBR_*` path overrides behind test mode.
2. Add the missing helper hardening from the spec (safe chdir, restrictive umask, fd closing, env scrub) or remove those claims from the spec.
3. Keep the planned independent security-aware review + hostile-filesystem disposable-VM gate as a blocker before daily use — the rollback logic is where a bug would hide.
