# Ticket 25 — AC3/AC4 gate evidence (hostile privileged tests, lifecycle journeys)

Scope: only AC3 ("Disposable privileged tests exercise hostile arguments,
environment, filesystem substitution, concurrency, interruption, forged
protocol, denied/cancelled/inactive authorization, package behavior, menu
conflicts, destructive lifecycle paths, and purge-path escape attempts.") and
AC4 ("Clean setup, declined activation, applicable previous-release update,
cancellation/failure after every cross-scope step, disablement, plugin
removal, uninstall, purge, and incomplete-removal recovery journeys finish
with exact before/after scope inventories."). The other six acceptance
criteria on issue #25 are out of scope here and are recorded elsewhere.

Candidate identity: commit `2bb7cb344e2330799ddb6713d58b735eb5a6de4c` (the
current `HEAD` of this working tree, confirmed with `git log -1`). This is the
merged, signed candidate recorded in `handoff/TONIGHT-PAUSE.md`.

Date: 2026-09-20, all commands below.

## Environment (disposable substitute, not clean-room)

The owner has no VM or spare machine; sudo, Docker, and systemd-nspawn are
unavailable to this agent. Per the task's explicit approval, this evidence
substitutes a **rootless disposable environment** on the owner's existing
Omarchy dev machine (`omarchy 4.0.4-1`, `quickshell 0.3.1-1`, `systemd
261.2-1`, kernel `6.19.8-arch1-3-surface`), using unprivileged Linux user
namespaces (`unshare`, `bwrap 0.12.0`, `fakeroot`, `newuidmap`, subuid/subgid
`100000:65536` for `spitfulfr0g`) to obtain genuine `geteuid()==0` execution
of the production helper binary inside a private mount namespace, without
touching the real host filesystem. This is **not** a clean-room environment
and does not substitute for the clean-room candidate gates tracked elsewhere
on this issue. No sudo was run, no real suspend/hibernate was initiated, no
pacman install/remove ran, and nothing outside `/tmp` and this repository's
`verification/` directory was written. The real `/etc/systemd/sleep.conf.d`
was checked empty before and after every privileged test batch below and
never appeared in a sandbox bind mount.

`tests/quattro-hosted-plugin.sh` and `tests/native_probes.sh` were **not run**
in this session (constraint: never run either concurrently with anything
else, and native/hosted product journeys are out of this ticket's lane).

---

## AC3 — hostile privileged tests

### Ordinary fixture-root Rust suite (rerun as a baseline)

```
cd /home/spitfulfr0g/Work/hibermachy
cargo test --locked --features test-support --test helper_merge_gate --test apply_process --test packaging_contract
cargo fmt --all -- --check
```

Result: 33/33 tests passed (24 in `apply_process.rs`, 4 in
`helper_merge_gate.rs`, 5 in `packaging_contract.rs`); formatting clean.
This exercises hostile arguments, hostile environment, filesystem
substitution (symlink/hardlink/wrong-permission targets and directories),
concurrency (concurrent apply/apply and apply/reset), interruption (deterministic
fault injection at write/sync/readback/contradictory/final-sync/remove
stages), and forged protocol tokens — but under the `test-support` feature,
where `has_effective_root()` always returns `true` (simulated root, not a real
`geteuid()==0` process) and the target directory is a compiled fixture path,
not `/etc/systemd/sleep.conf.d`. Below, each applicable item is re-exercised
against the **production** binary (`cargo build --release`, no `test-support`
feature — `has_effective_root()` checks the real `geteuid()`, and
`POLICY_DIRECTORY` is the literal compiled `/etc/systemd/sleep.conf.d`) with
genuine root inside a disposable namespace, closing the gap between simulated
and real privilege.

### Genuine-root battery against the production binary

Built with:
```
cargo build --release --locked
```

Sandbox construction (`/tmp/hbr-ac3/run_sandboxed.sh` and a matching one-off
per case): a throwaway directory this user owns is bound as the sandbox's `/`
(`bwrap --bind $FAKEROOT / --ro-bind /usr /usr ... --uid 0 --gid 0
--unshare-user --unshare-pid --unshare-net`), so `/etc/systemd/sleep.conf.d`
inside the sandbox is a real root-owned path the helper's own `validate_directory`
accepts, while the real host `/` (owned by the real root, unmapped in this
namespace) is never reachable for a mutating operation. Full battery script:
`/tmp/hbr-ac3/battery.sh` (disposable, not part of the repository).

| # | Item | Command (representative) | Result | Date |
| - | - | - | - | - |
| 1 | Hostile arguments | `bwrap ... hibermachy-policy-helper apply <malformed-args>` over the same 11-case corpus as `helper_merge_gate.rs` plus a 4097-byte oversized delay | All rejected, no target created, real root | 2026-09-20 |
| 2 | Valid boundary sanity check | `apply 900 no`, `apply 604800 yes` | Both accepted and written correctly, real root | 2026-09-20 |
| 3 | Hostile environment (PATH/HOME/IFS/HIBERMACHY_TEST_ROOT) | `env -i PATH=/hostile/path HOME=/hostile/home IFS=$'\n\t ' HIBERMACHY_TEST_ROOT=/hostile/root ... apply 900 no` | Accepted at the compiled target; hostile values had no effect, real root | 2026-09-20 |
| 4 | Hostile environment (`LD_PRELOAD`) | `env -i LD_PRELOAD=/preload/preload_canary.so ... probe` | **Finding, not a pass/fail of the helper's own logic** — see "LD_PRELOAD observation" below | 2026-09-20 |
| 5 | Filesystem substitution: symlinked policy directory | `ln -s outside-dir sleep.conf.d; apply 900 no` | Refused (`unsafe filesystem state`); nothing written under `outside-dir`, real root | 2026-09-20 |
| 6 | Filesystem substitution: symlinked target file | `ln -s outside-target 90-hibermachy.conf; apply 900 no` | Refused; `outside-target` content unchanged, real root | 2026-09-20 |
| 7 | Filesystem substitution: existing target owned by a different uid | `unshare --user --mount --pid --map-users 0:1000:1 --map-users 1:100000:65535 ...; chown 5:5 90-hibermachy.conf; chroot $FAKEROOT ... apply 901 yes` | Refused (`unsafe filesystem state`); original 900s/no content unchanged byte-for-byte | 2026-09-20 |
| 8 | Concurrency | `apply 900 no & apply 901 yes & wait`, both real-root processes racing the real `flock` | Final file is exactly one complete recognized policy (900/no or 901/yes), never mixed/partial | 2026-09-20 |
| 9 | Interruption | 25× `apply 900 no & kill -KILL $!; wait $!` real-root SIGKILL race | 0/25 runs left a partial/malformed target or a leftover `.tmp` object (best-effort empirical; not a substitute for the deterministic fault-injected coverage in `apply_process.rs`, which already passed above) | 2026-09-20 |
| 10 | Forged protocol / extra tokens | `probe extra`, `probe --protocol-max=999`, `reset extra` | All rejected | 2026-09-20 |
| — | Non-root invocation | `hibermachy-policy-helper apply 900 no` as real uid 1000, no sandbox | Refused: `effective root required`, no filesystem interaction attempted | 2026-09-20 |
| — | Package behavior (`pre_remove()` hook) | `hibermachy-policy-helper reset \|\| :` real root, with target present, then absent, then unrecognized content present | Present→removed cleanly; absent→idempotent success; unrecognized content→helper itself refuses (nonzero) but the packaging scriptlet's `\|\| :` guard (verified present in `packaging/hibermachy-helper.install`, `tests/packaging_contract.rs`, rerun below) keeps the pacman scriptlet from reporting removal as aborted | 2026-09-20 |

Battery summary line: `13 passed, 1 failed (out of 14 checks)` on the first
pass; the 1 failure was a test-harness defect in my own case 7 (a plain
single-uid-mapped namespace cannot produce a file with an owner distinct from
its own mapped uid — Linux stores one real global uid regardless of namespace,
so `chown` to an unmapped uid fails and the file silently stays owned by the
real host uid, which the fake-root sandbox always sees as its own uid 0).
Case 7 was corrected using the granted subuid range
(`--map-users 1:100000:65535`) to obtain a second, genuinely distinct mapped
identity, and rerun successfully (see table row 7). This was a mistake in the
adversarial-test construction, not a finding about the helper.

#### `LD_PRELOAD` observation (item 4)

`LD_PRELOAD=/preload/preload_canary.so ... probe` executed the preloaded
library's constructor (verified via a canary file the constructor writes)
**before** the helper's own `initialize_process()`/`clearenv()` ran, both as
an unprivileged user and as genuine root inside the sandbox. This is expected
ELF dynamic-loader behavior for any non-setuid binary: `LD_PRELOAD` is
resolved by `ld.so` at `exec()` time, strictly before `main()`, so no amount
of in-process environment hygiene can prevent it. The helper is not setuid
(glibc's `AT_SECURE` hardening, which ignores `LD_PRELOAD`, applies only to
setuid/setgid/file-capability binaries) and is invoked only via `pkexec`
under `org.hibermachy.policy-helper` in the real deployment. Whether an
attacker-controlled `LD_PRELOAD` ever reaches the helper's real `exec()`
therefore depends entirely on `pkexec`'s own environment sanitization
(`pkexec` clears the environment and passes only a small allowlist that does
not normally include `LD_PRELOAD`), which is **outside the helper's own code
and was not exercised here** — real `pkexec` authentication was not run (see
below). This is recorded as an observation about the boundary of the
in-process hygiene comment in `secure_fs.rs` ("public process ignores its
inherited environment"), not a confirmed exploitable defect in the shipped
deployment path.

### Denied / cancelled / inactive authorization — NOT RUN

`packaging/org.hibermachy.policy-helper.policy` declares
`allow_any=no`, `allow_inactive=no`, `allow_active=auth_admin` (confirmed
again by `tests/packaging_contract.rs::polkit_requires_fresh_administrator_authentication_for_the_helper`,
rerun above). Authentication itself is entirely mediated by `pkexec`/Polkit,
outside the Rust helper. This machine has an active `polkit` service, a
working session D-Bus bus, and `pkexec` installed — real authentication is
*technically* reachable here — but it was deliberately **not attempted**:
doing so would exercise the real installed helper package against the real
`/etc/systemd/sleep.conf.d` and prompt for the operator's real credentials,
which the task's hard safety constraints explicitly forbid ("NEVER run sudo",
"NEVER mutate real system sleep policy"). This is a safety-driven refusal to
run, not a technical inability.

Per `handoff/TONIGHT-PAUSE.md` and the issue #25 body's "Corrected native
candidate — 2026-09-14" note, the owner already obtained, on the real dev
machine, a real approved apply, a real explicit cancellation, and a real
reset against an earlier corrected build. Those are native-machine results
for a prior commit in this candidate's lineage, not clean-room or hostile
evidence, and are not re-claimed here. **Not exercised in this session**:
denied authorization, and authorization while the session is inactive
(`allow_inactive=no`). Both require a real Polkit authority decision this
agent must not trigger.

### Package behavior — partially run, pacman install/remove NOT RUN

- Static contract (`tests/packaging_contract.rs`, `tests/packaging_merge_gate.sh`)
  rerun today, both pass, including `.SRCINFO`/`makepkg --printsrcinfo`
  consistency (makepkg is installed here).
- `pre_remove()` hook behavior exercised directly under genuine root (see
  table above).
- Real `pacman -U`/`-S`/`-R` package install/remove: **NOT RUN** — the hard
  constraint explicitly forbids running pacman install/remove. The owner's
  native-machine record already shows an authenticated real package install
  with `pacman -Qkk` reporting zero altered files (see
  `verification/native-machine-qualification.md`); that is native-machine,
  not clean-room, evidence and is not re-claimed here.

### Menu conflicts — rerun of existing coverage, no gap found

```
bash tests/lifecycle_menu.sh
bash tests/lifecycle_install.sh
bash tests/lifecycle_update.sh
```
All pass today. Coverage includes JSONC lexical preservation, a managed-row
edited by a third party (`HBR-MENU-MANAGED-MODIFIED`), a hard-linked menu file
(`HBR-MENU-INACCESSIBLE`), a symlinked parent directory, and a managed-id
collision (`HBR-MENU-ID-COLLISION`) in both `setup` and `update`. No new
adversarial menu case was found that these do not already cover.

### Destructive lifecycle paths — rerun of existing coverage plus first-person journeys

```
bash tests/lifecycle_remove.sh
bash tests/lifecycle_uninstall.sh
bash tests/lifecycle_recovery.sh
bash tests/lifecycle_production.sh
```
All pass today. See the AC4 journey matrix below for first-person before/after
inventories driven directly against `lifecycle/install` and `lifecycle/remove`
(disable, plugin-removal, uninstall, purge, incomplete-removal recovery), plus
one inventory-accuracy defect found along the way (see "Defect found," below).

### Purge-path escape attempts — first-person adversarial tests

In addition to rerunning `tests/lifecycle_production.sh`
(`HBR-CHK-LIFECYCLE-PRODUCTION-002`, which already covers a symlinked
`~/.config/hibermachy` parent directory), two new escape attempts were run
directly against `lifecycle/install purge --confirm-purge --root <fixture>`:

1. `user/config.json` replaced with a symlink to
   `/tmp/hbr-ac3/purge-victim/secret` (a file outside the fixture root).
   Result: refused with `HBR-PURGE-UNSAFE-PATH`; the victim file's content was
   unchanged and the symlink itself was left in place (not followed, not
   deleted).
2. `user/` itself replaced with a symlink to
   `/tmp/hbr-ac3/purge-victim2/` (a directory outside the fixture root,
   containing `config.json` and `state.json`).
   Result: refused with `HBR-PURGE-UNSAFE-PATH`; both victim files were
   untouched.

Both refusals came from `validatePurgePath()` in `lifecycle/install`, which
`lstat`s the fixture root, `user/`, and each purge-scope target and rejects
any symlink or wrong-owner object in that chain before ever calling
`fs.unlinkSync`. Commands and dates: 2026-09-20, ad hoc fixtures under
`/tmp/hbr-ac3/purge-escape-*`.

---

## AC4 — lifecycle journeys with exact before/after scope inventories

All journeys below were driven directly against `lifecycle/install
<command> --root <fixture>` / `lifecycle/remove <command> --root <fixture>` /
`lifecycle/status status --root <fixture>` — the existing `--root` fixture
seam (see `tests/lifecycle_uninstall.sh` for the same seam already in the
repository). This is the harness's supported way to exercise the real
lifecycle logic against a disposable, fully isolated profile without XDG
redirection (XDG redirection is the separate `HIBERMACHY_LIFECYCLE_HOME` seam
used by `production.mjs`/`tests/lifecycle_production.sh`, which was also
rerun and passed — see above). Fixtures and outputs live under
`/tmp/hbr-ac4/journey-*` (disposable, not part of the repository). Every
`scopes` inventory below is the literal `state` field of each of the nine
independently-reported scopes from `lifecycle/status`
(`checkout, activation, menu_contribution, helper_package, helper_protocol,
automatic_policy_enablement, user_configuration_state, requested_system_policy,
owned_target`).

### J1 — Clean setup

Fresh fixture root: checkout present (native-reviewed), no activation, no
helper, no menu, no user data, no policy.

| Scope | Before | After `install setup` |
| - | - | - |
| checkout | compatible | compatible |
| activation | missing | compatible (disabled) |
| menu_contribution | missing | compatible |
| helper_package | missing | compatible |
| helper_protocol | missing | compatible |
| automatic_policy_enablement | missing | missing |
| user_configuration_state | missing | missing |
| requested_system_policy | missing | missing |
| owned_target | missing | missing |

Result: `{"kind":"accepted","activation":"disabled","menu":"reconciled","policyMutation":false}`.
Confirms HBR-REQ-003 (first activation leaves automation disabled) and
HBR-REQ-061 (installation never applies system policy — `automatic_policy_enablement`,
`user_configuration_state`, `requested_system_policy`, and `owned_target`
stayed `missing` throughout). 2026-09-20.

### J2 — Declined activation

Same root, immediately after J1.

`install activate --root <fixture>` (no `--confirm`) →
`{"kind":"declined","operation":"activation","activation":"disabled","policyMutation":false}`,
exit 1. Every scope's `state` was byte-for-byte identical before and after
(`checkout/activation/menu_contribution/helper_package/helper_protocol`: all
`compatible`; the rest: `missing`); `activation.json` remained
`{"enabled":false}`. A true no-op. 2026-09-20.

### J3 — Applicable previous-release update

Same root; `install activate --confirm` first (activation → `compatible`,
`enabled:true`), then seeded a 0.2.0 manifest and update fixtures, then
`install update --root <fixture>`.

| | Before update | After update |
| - | - | - |
| `plugin/manifest.json` version | 0.1.0 | 0.2.0 |
| `activation.json` | `{"enabled":true}` | `{"enabled":true}` (unchanged) |
| all 9 scope states | identical (`checkout/activation/menu_contribution/helper_package/helper_protocol` compatible; rest missing) | identical to before |

Result: `{"kind":"accepted","activation":"enabled","priorActivation":"enabled","helper":"upgraded","menu":"reconciled","probes":"rerun","policyMutation":false}`.
Confirms activation survives an update unchanged and no scope regresses.
2026-09-20.

### J4 — Cancellation/failure after cross-scope steps (uninstall)

Driven by rerunning `tests/lifecycle_uninstall.sh` today (pass, see above),
which enumerates, in one script, a refusal after every cross-scope uninstall
step with an exact filesystem assertion at each: auth-cancelled and
auth-denied policy-reset (helper/checkout/policy all still present),
reset-refused (unrecognized existing policy — policy untouched), reset-refused
(ownership metadata mismatch), package-remove-failed (policy already reset,
helper/checkout retained), interrupted-after-package-removal (policy and
helper gone, checkout retained), interrupted-after-disable
(`activation.json` flipped to disabled, everything else retained), and a
menu-managed-modified refusal (policy/helper removed, checkout retained,
menu untouched). Three of these were independently reproduced first-person
with full `lifecycle/status` snapshots, to satisfy "exact... inventories"
literally rather than only the script's targeted assertions:

- **Cancelled policy-reset authorization**: before — `requested_system_policy`
  and `helper_package`/`helper_protocol` all `compatible`; after refusal
  (`HBR-SYSTEM-POLICY-AUTH-CANCELLED`) — identical, nothing changed except
  `activation` moving to `compatible`/disabled (the one step that had already
  committed).
- **Package-removal failure**: before — policy already verified absent,
  helper/checkout still `compatible`; after refusal
  (`HBR-PACKAGE-REMOVE-FAILED`) — `requested_system_policy`/`owned_target` now
  `missing` (policy reset had committed), `helper_package`/`checkout` still
  `compatible` (removal never happened).
- **Interrupted after menu**: before — policy/helper already removed, menu
  still `compatible`; after refusal (`HBR-LIFECYCLE-INTERRUPTED`) — menu
  scope unchanged (`compatible`), checkout still `compatible` (the interrupt
  fires strictly before `checkout-removed`).

2026-09-20.

### J5 — Disablement

`lifecycle/remove disable --root <fixture>` on a fully-seeded profile
(checkout/activation-enabled/helper/user-data/policy/menu all present).

Before: all 9 scopes `compatible`, `actionable:false`.
After: identical scope states (all still `compatible`), `actionable:false`,
only `activation.json` flips to `{"enabled":false}` and
`lifecycle-state.json` records `{"operation":"disable","phase":"disabled"}`.
Result: `{"kind":"accepted","operation":"disable","activation":"disabled","policyMutation":false}`.
2026-09-20.

### J6 — Plugin removal

`lifecycle/remove remove --root <fixture>` on the same seed shape (fresh
root, disable+remove native fixtures both accepted).

Before: all 9 scopes `compatible`, `actionable:false`.
After: `checkout` → `missing`; `helper_protocol` → `mismatched` (see
"Defect found" below); everything else (`activation, menu_contribution,
helper_package, automatic_policy_enablement, user_configuration_state,
requested_system_policy, owned_target`) stays `compatible`; `actionable`
flips to `true`. Result:
`{"kind":"accepted","operation":"plugin-removal","activation":"disabled","policyMutation":false}`.
Confirms plugin removal is strictly narrower than uninstall: helper package
and requested system policy both survive on disk (`helper/package` and
`etc/systemd/sleep.conf.d/90-hibermachy.conf` both still present), matching
HBR-REQ-065. 2026-09-20.

### J7 — Uninstall (clean)

`install uninstall --root <fixture>` on the same full seed shape.

Before: all 9 scopes `compatible`, `actionable:false`.
After: `checkout` → `missing`; `menu_contribution` → `missing`;
`helper_package` → `missing`; `helper_protocol` → `missing`;
`requested_system_policy` → `missing`; `owned_target` → `missing`;
`activation` stays `compatible` (now disabled); `automatic_policy_enablement`
and `user_configuration_state` stay `compatible` (retained by design).
Result:
`{"kind":"accepted","operation":"uninstall","policyReset":"verified-absent","helper":"removed","checkout":"removed","menu":"removed","retained":{"userConfiguration":true,"outcomeHistory":true}}`.
`user/config.json` and `user/state.json` confirmed still present on disk.
2026-09-20.

### J8 — Purge

Same full seed shape. First `install purge --root <fixture> --cancel-purge`:
result `{"kind":"accepted","operation":"uninstall","purge":"retained"}`,
`user/config.json`/`user/state.json` confirmed still present (uninstall
proceeded, purge itself was cancelled — inventory identical to J7's after
state). Then `install purge --root <fixture> --confirm-purge` on the same
root: result
`{"kind":"accepted","operation":"purge","purge":"removed","finalInventory":{"userConfiguration":"absent","outcomeHistory":"absent"}}`;
`automatic_policy_enablement` and `user_configuration_state` both drop from
`compatible` to `missing`, the only two scopes purge additionally touches
beyond a plain uninstall; `user/config.json` and `user/state.json` confirmed
absent from disk. 2026-09-20.

### J9 — Incomplete-removal recovery

Reused the J6 root immediately after plugin removal (checkout `missing`,
helper/policy/menu still present — a genuine "the checkout is gone but the
machine-wide state is not" incomplete-removal shape). `install uninstall
--root <fixture>` **without** `--recover` and without recovery fixtures
seeded yet failed at `HBR-SYSTEM-POLICY-RESET-AUTH-UNAVAILABLE` (a
policy-reset fixture simply hadn't been seeded at that point in the script —
this shows uninstall can still make partial progress without `--recover` when
checkout is absent but helper/policy remain internally consistent; it is not
a demonstration of the recovery gate itself). After seeding
`native-plugin-add`/`recovered-plugin-manifest.json`/policy-reset/package-remove
fixtures and rerunning with `--recover`:

Before (`--recover` run): `checkout: missing`, `helper_protocol: mismatched`,
everything else `compatible`.
After: `checkout: missing` (removed again, this time via the completed
uninstall, not left over from J6), `menu_contribution/helper_package/helper_protocol/requested_system_policy/owned_target`
all `missing`, `activation`/`automatic_policy_enablement`/`user_configuration_state`
stay `compatible`. Result:
`{"kind":"accepted","operation":"uninstall","recovery":{"checkout":"re-added","helper":"present"},"policyReset":"verified-absent","helper":"removed","checkout":"removed","menu":"removed"}`.
Confirms the checkout is transiently re-added (via the native-review fixture)
so a stale machine-wide policy and helper package can be properly reset and
removed, then the checkout is removed again cleanly. 2026-09-20.

---

## Defect found (reported, not fixed)

**`lifecycle/status`'s `helper_protocol` scope reports `mismatched` instead of
a "no checkout to compare" state once the checkout is removed but the helper
package survives** (observed first-person in J6 and J9 above; both reruns
reproduce it deterministically). `protocol_state()` in `lifecycle/status`
(around line 126) reads `plugin/manifest.json` for the checkout's protocol
range; when that file is absent, `checkout_min`/`checkout_max` end up empty,
the compatibility `awk` check is false, and the function falls into the
`else` branch, reporting `state: mismatched`,
`reasonCode: HBR-LIFECYCLE-MISMATCHED`, with guidance text "Install a helper
whose declared protocol range overlaps this checkout." This is misleading
after a legitimate plugin-removal (a distinct, supported lifecycle scope per
HBR-REQ-065, not an error state): there is no checkout at all to overlap
with, so "mismatched" and "install a helper whose ... range overlaps this
checkout" both imply a real protocol incompatibility that does not exist.
This is a real inventory-accuracy defect in the lifecycle status reporting,
not touched or fixed here — it is the owner's call whether it blocks
qualification or is deferred.

## Summary

- All ordinary/lifecycle/packaging test suites relevant to this ticket's lane
  were rerun today and pass (33 Rust tests + formatting; 8 `lifecycle_*.sh`
  scripts; `lifecycle_production.sh`; `packaging_merge_gate.sh`).
- A genuine-root (real `geteuid()==0`, unprivileged-namespace) hostile battery
  against the production helper binary passed 13/13 checks after correcting
  one self-inflicted test-harness mistake (see "item 7" above); the real host
  filesystem was confirmed untouched before and after.
- Two new first-person purge-path-escape adversarial cases (symlinked scope
  target, symlinked `user/` directory) were refused correctly with
  `HBR-PURGE-UNSAFE-PATH`.
- Nine AC4 journeys were driven directly with exact before/after
  `lifecycle/status` inventories captured for each.
- **NOT RUN**: real Polkit denied/cancelled/inactive authorization and real
  `pacman` package install/remove — both are explicitly forbidden by this
  session's hard safety constraints (no sudo, no real system-policy
  mutation), not technically unreachable in this environment. The owner's
  prior native-machine record already includes a real approved apply, a real
  cancellation, and a real reset for an earlier commit in this candidate's
  lineage (`verification/native-machine-qualification.md`,
  `handoff/TONIGHT-PAUSE.md`); that is native-machine evidence and is not
  re-claimed as clean-room or hostile-privileged evidence here.
- **One defect found and reported, not fixed**: `lifecycle/status` mislabels
  the helper-protocol scope as `mismatched` after a legitimate plugin removal
  that leaves the helper package installed.
