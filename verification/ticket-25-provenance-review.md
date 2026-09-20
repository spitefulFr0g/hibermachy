# Ticket #25 provenance review — candidate identity, supply chain, helper security, accessibility precursor

Date: 2026-09-20.
Scope: AC1 (candidate identity binding), AC6 (supply-chain evidence), AC7
(independent review of the privileged helper), and the static precursor to
AC5 (accessibility). AC3/AC4 (disposable privileged tests and journey
inventories) are owned by a concurrent agent and are out of scope here; this
record makes no claim about them. `verification/ticket-25-evidence.md`
belongs to a different, older local ticket numbering and was not read or used
as input to this record.

Candidate under review: `2bb7cb344e2330799ddb6713d58b735eb5a6de4c` (merge of
PR #28, `fix/native-service-activation`), recorded in
`handoff/candidate-2bb7cb3/candidate.json` and `handoff/TONIGHT-PAUSE.md`.

## AC1 — Candidate identity binding

Claim under test: candidate identity binds one commit, one signed source
archive and checksum, and one helper-package build and checksum.

Commands run today, from the repository root unless noted:

```
git log -1 2bb7cb344e2330799ddb6713d58b735eb5a6de4c --format="%H %s"
# 2bb7cb344e2330799ddb6713d58b735eb5a6de4c Merge pull request #28 from spitefulFr0g/fix/native-service-activation
git rev-parse 2bb7cb344e2330799ddb6713d58b735eb5a6de4c^{tree}
# 7b034b105f44238f914ed2d7c758248121f8c739  (matches candidate.json sourceTree)

cd handoff/candidate-2bb7cb3
sha256sum hibermachy-helper-0.1.0.tar.gz
# 09180240e9b038dfb77048895d752b6fc7dbda32548ed6a48c9fe7d5fdb74264  — MATCHES the value given in the ticket brief
sha256sum package-build/hibermachy-helper-0.1.0-1-x86_64.pkg.tar.zst
# b25a35a31f81e1cbc461d9bb6c32782988ad1234773954dabefba50b0ecf589a  — MATCHES the value given in the ticket brief

gpg --list-keys 0B1C5414F8D18F8B6AA78957335FEBC82DB247EC
# pub rsa3072 2026-09-08 [SC]  0B1C5414F8D18F8B6AA78957335FEBC82DB247EC
#     uid  spitefulFr0g <81829935+spitefulFr0g@users.noreply.github.com>

gpg --verify hibermachy-helper-0.1.0.tar.gz.sig hibermachy-helper-0.1.0.tar.gz
# gpg: Signature made Mon 14 Sep 2026 12:10:23 AM MDT using RSA key 0B1C5414F8D18F8B6AA78957335FEBC82DB247EC
# gpg: Good signature from "spitefulFr0g <...>"
```

Tree-content binding (archive contents vs. the actual commit tree, not just
the recorded tree hash):

```
tar -xzf handoff/candidate-2bb7cb3/hibermachy-helper-0.1.0.tar.gz -C /tmp/candidate-check
git archive 2bb7cb344e2330799ddb6713d58b735eb5a6de4c | tar -x -C /tmp/candidate-git
diff -rq /tmp/candidate-git /tmp/candidate-check/hibermachy-helper-0.1.0
# (no output — byte-identical)
```

Result: **AC1 confirmed.** The archive SHA-256, package SHA-256, and detached
GPG signature (fingerprint `0B1C5414F8D18F8B6AA78957335FEBC82DB247EC`) all
independently re-verify against the values in the ticket brief and
`candidate.json`. The archive's file contents are byte-for-byte identical to
`git archive` of commit `2bb7cb3` — the archive is not just labeled with the
right tree hash, its extracted contents actually match. No private key
material was exported, backed up, or used for anything beyond `gpg --verify`
and `gpg --list-keys`.

## AC6 — Supply-chain evidence

### Source verification

Covered above (SHA-256 + GPG signature + tree-content diff, all passing).

### Unprivileged build and recipe substitution

```
diff handoff/candidate-2bb7cb3/package-build/PKGBUILD packaging/PKGBUILD
# only differs in the three sentinels (__RELEASE_SHA512__, __RELEASE_SIGNATURE_SHA512__,
# __RELEASE_SIGNING_KEY__), which are filled with real values in the candidate copy
diff handoff/candidate-2bb7cb3/package-build/hibermachy-helper.install packaging/hibermachy-helper.install
# (no output — identical)
sha512sum handoff/candidate-2bb7cb3/package-build/hibermachy-helper-0.1.0.tar.gz{,.sig}
# acf9c677c57f3989d8d86734f68087065ffb4d37ea03ac7ccfdd0410a43454f50cc66b10bdd9a3587772da2ff65fcc29a5785d6fa127392ed899930ed8850b53  hibermachy-helper-0.1.0.tar.gz
# a2ab99b0730a77e461ac24ad00506794ca427b1f8ef3fb55447f5befda6125d01093c61cd6de7fe04d50dd51a56d1644f30ced738c444842dfe2ad23bd71d2b2  hibermachy-helper-0.1.0.tar.gz.sig
```

Both sha512sums exactly match the PKGBUILD's substituted `sha512sums=()`
array — the recipe used to build this package is the repository's real
`packaging/PKGBUILD` with placeholders resolved to the actual verified
archive, not a hand-edited stand-in. `makepkg --verifysource` /
`--printsrcinfo` / `--noconfirm --cleanbuild` were already run for this
candidate per `handoff/candidate-fb55239/PACKAGING-CHECKPOINT.md` (build was
unprivileged, as `fakeroot`); this review did not repeat that build (per the
task's no-package-build-from-scratch scope) and instead inspected the
already-built artifact below.

### Package contents, ownership, modes

```
tar --numeric-owner -tvf <(zstd -dc package-build/hibermachy-helper-0.1.0-1-x86_64.pkg.tar.zst)
```

```
-rw-r--r-- 0/0   42979  .BUILDINFO
-rw-r--r-- 0/0     304  .INSTALL
-rw-r--r-- 0/0     458  .MTREE
-rw-r--r-- 0/0     424  .PKGINFO
drwxr-xr-x 0/0       0  usr/
drwxr-xr-x 0/0       0  usr/libexec/
-rwxr-xr-x 0/0  379400  usr/libexec/hibermachy-policy-helper
drwxr-xr-x 0/0       0  usr/share/
drwxr-xr-x 0/0       0  usr/share/polkit-1/
drwxr-xr-x 0/0       0  usr/share/polkit-1/actions/
-rw-r--r-- 0/0     723  usr/share/polkit-1/actions/org.hibermachy.policy-helper.policy
```

Every entry is `root:root` (uid/gid 0/0). Directories are 0755, the Polkit
action file is 0644, and the helper binary is 0755 (not setuid — privilege
comes entirely from Polkit/`pkexec`, matching `packaging/PKGBUILD`'s `install
-Dm755` / `-Dm644` and the intended non-setuid design). No unexpected files
are packaged (exactly one binary, one Polkit action, standard pacman
metadata).

Extracted and inspected the packaged binary directly (never installed):

```
file usr/libexec/hibermachy-policy-helper
# ELF 64-bit LSB pie executable, x86-64, dynamically linked, stripped
sha256sum usr/libexec/hibermachy-policy-helper
# be889db04d2d4f7730d329e38c7886bddb967d1866293ba304a0e0a90568c22a
```

This matches the installed-binary hash recorded for candidate `40f2577` in
the issue's "Corrected native candidate" note. That is expected, not a
discrepancy: `git diff --stat 40f2577..2bb7cb3 -- src/` shows the helper
source (`src/main.rs`, `src/secure_fs.rs`, `Cargo.toml`, `build.rs`) is
byte-identical between the two candidates — only `plugin/Panel.qml` and
`tests/system_policy_dispatch.sh` changed — so an identical compiled binary
is exactly what should follow.

Binary hardening (readelf), confirming the toolchain's default hardening was
not weakened by build flags:

```
readelf -d ... | grep -i "flags\|bind_now"
#  FLAGS      BIND_NOW
#  FLAGS_1    Flags: NOW PIE
readelf -l ... | grep -i "GNU_RELRO\|GNU_STACK"
#  GNU_RELRO  ...
#  GNU_STACK  0x0 0x0 0x0   (RW, not RWX — non-executable stack)
readelf -h ... | grep Type
#  Type: DYN (Position-Independent Executable file)
```

Full RELRO + PIE + NX stack, all present.

### `test-support` feature not present in the shipped binary

`Cargo.toml` gates the test-only relaxations (`has_effective_root()` always
`true`, loosened uid/mode checks, `HIBERMACHY_TEST_FAULT` /
`HIBERMACHY_TEST_RESET_TEMP` / `HIBERMACHY_TEST_ROOT` env hooks) behind a
`test-support` feature with **no `default = [...]` entry**, and
`packaging/PKGBUILD`'s `build()` calls plain `cargo build --release --locked`
(no `--features`). Verified this actually held for the shipped binary rather
than trusting the Cargo.toml alone:

```
strings usr/libexec/hibermachy-policy-helper | grep -iE "HIBERMACHY_TEST_FAULT|HIBERMACHY_TEST_RESET_TEMP|HIBERMACHY_TEST_ROOT|test-support"
# (no matches, exit code 1)
```

None of the test-only environment-variable names or the feature string
appear in the stripped release binary. The privilege-relaxation backdoor
that exists for testing is not compiled into what ships.

### Dependencies

```
cat Cargo.lock
# version = 4
# [[package]]
# name = "hibermachy-policy-helper"
# version = "0.1.0"
cargo tree
# hibermachy-policy-helper v0.1.0 (/home/spitfulfr0g/Work/hibermachy)
```

The helper crate has **zero external dependencies** — `Cargo.lock` lists only
the crate itself. All privileged-boundary syscalls in `src/secure_fs.rs` are
declared directly via `unsafe extern "C"` against libc symbols rather than
through a crate (e.g. `libc`, `nix`, `rustix`). This substantially narrows
the supply-chain surface for the privileged binary: there is no third-party
Rust dependency to have a vulnerable release, a compromised maintainer
account, or a typosquat risk.

### Toolchain

```
cargo --version   # cargo 1.98.1 (797e8a9bc 2026-08-05)
rustc --version   # rustc 1.98.1 (48a229cea 2026-09-01)
rustup show       # active toolchain: stable-x86_64-unknown-linux-gnu
makepkg --version # makepkg (pacman) 7.1.0
fakeroot --version # fakeroot 1.37.2
gpg --version      # gpg (GnuPG) 2.4.9 / libgcrypt 1.12.3
zstd --version      # Zstandard CLI 1.5.7
pacman -Si rust     # extra/rust 1:1.98.1-1 (matches the rustup-built toolchain version)
```

No `rust-toolchain.toml` pin exists in the repository; the build floats on
whatever `rustup`-selected stable toolchain is active. `packaging/PKGBUILD`
declares `makedepends=('rust')` (the pacman package), but the actual
candidate build in `handoff/candidate-2bb7cb3/package-build/.BUILDINFO`'s
`installed = ...` list does not include a pacman `rust` package — only
`rustup-1.29.1-1-x86_64` — meaning this host build used the rustup-managed
toolchain rather than the pacman `rust` package the recipe declares as its
build dependency. The version happens to match exactly (`1.98.1` both ways),
so this build is not evidence of a version mismatch, but it is evidence that
the makepkg dependency graph was not exercised as literally declared on this
host. This is a **toolchain-provenance gap worth recording**, not a blocker:
a true clean-room `makepkg` run in a container/chroot with only declared
`makedepends` installed would close it. Flagging rather than papering over it,
per the reporting-discipline instruction.

### Current advisories (cargo-audit)

cargo-audit was not present (`which cargo-audit` → not found) and was
installed user-locally, no root required:

```
cargo install --locked cargo-audit
# installed to ~/.cargo/bin/cargo-audit
```

Advisory scan against this crate's actual lockfile:

```
cd /home/spitfulfr0g/Work/hibermachy
cargo audit
```

```
$ export PATH="$HOME/.cargo/bin:$PATH"
$ cargo audit --version
cargo-audit-audit 0.22.2
$ cargo audit
    Fetching advisory database from `https://github.com/RustSec/advisory-db.git`
      Loaded 1251 security advisories (from /home/spitfulfr0g/.cargo/advisory-db)
    Updating crates.io index
    Scanning Cargo.lock for vulnerabilities (1 crate dependencies)
$ echo $?
0
```

Advisory database snapshot used: RustSec `advisory-db` commit
`d5c17953a895cf19e8d3ce66eaa42b6fcfe1fb16`, dated 2026-09-19 10:42:27 +0200
(one day old as of this scan). 1251 advisories loaded.

**Result: zero advisories reported, exit code 0.** This is a direct
consequence of the dependency finding above — `Cargo.lock` contains exactly
one package (`hibermachy-policy-helper` itself), so there is nothing in the
dependency graph for `cargo-audit` to match against RustSec's database.
There is no applicable high- or critical-severity finding to evaluate for
blocking, and therefore no non-applicability determination is needed: the
"applicable exploitable high/critical blocks qualification" clause in AC6
is vacuously satisfied, not overridden or waived. This does not evaluate the
Rust standard library, `rustc`/`cargo` toolchain, `glibc`, `polkit`, or any
other runtime/build dependency outside the Cargo dependency graph — those
are tracked as plain package versions above, not as advisory-scanned
dependencies, since `cargo audit` only covers the Cargo ecosystem.

## AC7 — Independent review of the privileged helper

**This is agent review, not human review.** Per the owner-approved standing
policy recorded in the issue and `handoff/PAUSED.md`
("no human review is being claimed"), this section is an independent
security-aware *agent* review of `src/main.rs`, `src/secure_fs.rs`,
`packaging/PKGBUILD`, `packaging/hibermachy-helper.install`, and
`packaging/org.hibermachy.policy-helper.policy`. **The criterion's "human"
wording remains unmet by this record and by every record this repository
currently holds.** A prior lighter agent pass exists at
`handoff/review-results.md` (2026-09-08, against an earlier branch); this is
a fresh, independent pass against the frozen `2bb7cb3` tree, not a copy of
that one.

### Privilege boundary

- The binary is not setuid (mode 0755, `root:root`). Privilege is obtained
  only via Polkit/`pkexec`, which is itself the standard setuid trust
  boundary. `org.hibermachy.policy-helper.policy` sets `allow_any=no`,
  `allow_inactive=no`, `allow_active=auth_admin` (no `auth_admin_keep`, so
  there is no cached-authorization window across invocations) and binds
  `org.freedesktop.policykit.exec.path` to the exact absolute path
  `/usr/libexec/hibermachy-policy-helper`. This is the correct, minimal
  Polkit shape: only an active local session can authorize, only as admin,
  every time, only for this exact binary.
- `initialize_process()` runs before any argument parsing or privileged work:
  `chdir("/")`, `umask(0o077)`, `close_range(3, u32::MAX, 0)` (drops every
  inherited fd beyond stdio), `clearenv()`. This closes the exact gap the
  2026-09-08 review flagged as missing versus the spec ("changes to a safe
  working directory, sets a restrictive umask, closes unexpected
  descriptors, distrusts environment") — that gap is now closed in this
  candidate.
- `has_effective_root()` gates every privileged command (`apply`/`reset`)
  behind `geteuid() == 0` in production builds; only the unprivileged `probe`
  command (release/protocol string only) runs without it.

### Fixed command vocabulary / protocol parser

- `run()` accepts exactly three top-level forms: `probe` (no args, no
  privilege), `apply <delay> <yes|no>` (privileged), `reset` (no args,
  privileged). Anything else (`Err("invalid command")`) is rejected without
  side effects.
- `parse_apply` validates `delay` byte-by-byte (`is_ascii_digit()` on raw
  bytes, so multi-byte Unicode digit lookalikes such as fullwidth `９００`
  fail closed rather than being coerced), rejects leading zero, caps length
  at 6 digits (blocking `u32` overflow inputs before `parse::<u32>()` is even
  reached), and range-checks to `900..=604_800`. `ac` must be exactly `"yes"`
  or `"no"`. `tests/apply_process.rs` exercises this with fullwidth digits,
  a `u32`-overflowing literal, signed literals, and a decimal literal, all
  asserted rejected without creating a policy file — this static review's
  read of the parser logic agrees with what those tests assert.
- Diagnostics on any failure path are a fixed short string
  (`eprintln!("hibermachy-policy-helper: {reason}")`) — never the caller's
  raw arguments, environment, or OS error text — bounding what a hostile
  caller can learn from a failed invocation. `assert_bounded_diagnostic` in
  the test suite (≤128 bytes, no `/`) matches this design.

### TOCTOU in `secure_fs.rs`

This is the most safety-critical code in the candidate, so it received the
closest reading:

- Path resolution to the policy directory (`policy_directory`) opens `/`
  once with `O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC`, then walks each path
  component with `openat` relative to the *already-open* parent descriptor,
  re-validating ownership/mode via `.metadata()` (an `fstat` on the live fd,
  not a `stat`-by-path) at every step. Because validation always operates on
  an already-open descriptor rather than a path string, there is no window
  between "check a path" and "use that path" where a symlink swap or
  directory replacement could substitute a different target — this is the
  textbook-correct way to avoid TOCTOU in privileged path resolution, and it
  is what `O_NOFOLLOW` + per-component `openat` + fd-based `fstat` is for.
- `recognized_existing_target` similarly never trusts a path string: it opens
  the target by name once, and if that open fails, re-probes with `O_PATH`
  strictly to explain *why* (symlink vs. genuinely absent) without ever
  reading through a symlink — and if the `O_PATH` probe reveals anything
  other than "genuinely does not exist," the function unconditionally
  returns an error rather than proceeding. This closes the naive TOCTOU
  pattern of "stat, then decide, then act" that would otherwise be
  exploitable in a directory an attacker can influence between calls.
- `replace_and_verify` and `remove_and_verify` both: create their working
  file/temp-name in the *same validated directory descriptor*, `fsync`, use
  `renameat2` with `RENAME_EXCHANGE` (when a prior file exists) or
  `RENAME_NOREPLACE` (when none exists) so the rename atomically fails rather
  than silently clobbering something an admin or a concurrent invocation
  created in between, `fsync` the directory, then read back and byte-compare
  the result before declaring success. Every failure branch attempts a
  matching rollback using the same atomicity primitives. `tests/apply_process.rs`
  independently exercises concurrent `apply`+`reset` and concurrent
  `apply`+`apply` and asserts the on-disk result is always either absent or
  one complete, uncorrupted policy — never a torn write — which matches this
  reading of the rename/fsync/readback sequence.
- One residual, non-blocking observation: `flock(LOCK_EX)` on the policy
  directory is advisory and only serializes *cooperating* helper instances;
  it provides no protection against an uncooperative writer with independent
  access to that directory. In this design that is fine — the directory is
  root-owned, mode-validated non-world-writable on every invocation, and the
  only other writer contemplated is systemd/administrator edits, which the
  `recognized_policy`/ownership/mode checks are specifically built to detect
  and refuse to overwrite rather than to serialize against. Recording this
  rather than treating the advisory lock as a real mutex, since a less
  careful reviewer could over-credit it.
- Directory creation (`mkdirat`) for a missing *final* policy-directory
  component correctly compensates for the earlier `umask(0o077)`: it
  explicitly `set_permissions(0o755)` after creation rather than relying on
  `mkdirat`'s requested mode surviving the process umask (it would not — the
  requested `0o755` would otherwise be masked down to `0o700`). This is
  exactly the kind of interaction bug this style of review is meant to
  catch, and it is already handled correctly in the code as written.

### Atomic drop-in ownership

- The systemd drop-in (`/etc/systemd/sleep.conf.d/90-hibermachy.conf`) is
  always written new-then-renamed into place (never edited in place), is
  root-owned, and is deliberately mode `0644` (world-readable, root-only
  writable) — the code comment explains this is intentional so the
  unprivileged desktop process can read the winning policy. `recognized_policy`
  is a strict byte-level parser of Hibermachy's own exact format (fixed
  header, `HibernateDelaySec=<900-604800>s`, `HibernateOnACPower=yes|no`);
  anything else — administrator hand-edits, a different tool's drop-in, a
  directory, a symlink, a hard link (`nlink != 1`), wrong mode — is refused
  rather than silently adopted or overwritten.  `lifecycle/install`'s
  separate menu-file drop-in uses the same temp-write + `renameSync` pattern
  with an explicit `lstatSync(...).isSymbolicLink()` refusal beforehand,
  which is consistent with the helper's approach.

### What this review did not and could not establish

- No dynamic testing was performed (per the task's explicit prohibition on
  running `cargo test` / the shell test suites) — every finding above is
  from static reading of `src/main.rs`, `src/secure_fs.rs`, the packaging
  files, and cross-referencing (not re-running) the existing test files
  `tests/apply_process.rs`, `tests/helper_merge_gate.rs`,
  `tests/packaging_contract.rs` to see whether their assertions matched this
  reading of the code. They did, everywhere checked.
- No fuzzing, no formal verification, no disposable hostile-filesystem VM run
  was performed here — that is explicitly AC3's territory, owned by the
  concurrent agent.
- **No human security engineer has reviewed this candidate.** This review,
  however careful, is an AI agent reading source code once. The acceptance
  criterion asks for "an independent security-aware human," and that
  condition is not satisfied by this document or by any other evidence file
  in this repository as of this date.

### Most serious finding

No exploitable vulnerability was found in the privileged helper or its
packaging. The most serious *residual* item is the toolchain-provenance gap
recorded under AC6 (the build used the rustup-managed toolchain rather than
the pacman `rust` package the PKGBUILD declares as a `makedepends`, though
versions match) — this is a provenance/reproducibility gap, not a security
hole. Absent that, the design (non-setuid binary behind Polkit
`auth_admin`/no-keep, closed-fd/cleared-env/fixed-cwd startup, fd-relative
TOCTOU-safe path resolution, atomic rename+fsync+readback with rollback,
zero external Rust dependencies, no `test-support` code in the shipped
binary, full RELRO/PIE/NX) reads as materially stronger than the 2026-09-08
review found, because every gap that review raised against `src/*.rs`
(missing chdir/umask/fd-close/env-scrub; the PATH-relative
`systemctl`/`loginctl`/`omarchy-toggle-idle` calls and unconditionally
honored `HBR_*` override env vars in `plugin/Service.qml`) has since been
closed:

```
grep -n "systemctl\|omarchy-toggle-idle" plugin/Service.qml
# 829:  sleepRequestProcess.command = ["/usr/bin/systemctl", ...]
# 1276: command: ["/usr/bin/omarchy-toggle-idle", "status"]
grep -n "HBR_POLICY_HELPER_PATH\|HBR_POLICY_HELPER_LAUNCHER\|HBR_EFFECTIVE_POLICY_READER\|HBR_CONTRACT_PROBE" plugin/Service.qml
# every one of these is now `(testMode && Quickshell.env(...)) || <fixed production value>`,
# i.e. only honored when HBR_TEST_MODE=1; production always uses the fixed absolute path
```

The one `/bin/sh -c` usage the 2026-09-08 review flagged
(`policyPermissionProbe`) no longer exists; the directory-mode probe is now
`["/usr/bin/stat", "-c", "%a", root.policyDirectory]`, a direct argv array
with no shell involved. `helperProcess.command` (the `pkexec` invocation
itself) is likewise always an argv array of fixed launcher/helper paths and
either a validated numeric string plus a fixed `"yes"`/`"no"` token (`apply`)
or no arguments at all (`reset`) — there is no string concatenation into a
shell command anywhere on the privileged-invocation path.

## AC5 precursor — accessibility statics only

**This is a static-analysis precursor, not accessibility sign-off.** Real
keyboard-only and assistive-technology verification needs the owner at a
physical keyboard/screen reader and is explicitly out of scope for this
review. Source inspected: `plugin/Panel.qml`, `plugin/AccessibleConfirmDialog.qml`,
and the installed shell's `/usr/share/omarchy/shell/Commons/Color.qml` /
`Style.qml` for the token values the panel inherits.

### Focus chain and tab order

- `Component.onCompleted` builds `focusTargets` in exactly the same order the
  controls appear top-to-bottom in the QML layout: automatic toggle → idle
  presets (5/30/60 min) → idle number field → save → hibernate presets
  (15/60/120 min) → hibernate number field → AC toggle → apply → reset
  system → manual action → reset invalid policy → reset history → copy
  diagnostics. Visual and programmatic order match.
- `PanelKeyCatcher` routes Tab/arrow navigation to `moveFocus`, which wraps
  modulo `focusTargets.length` (no dead end at either edge) and is
  explicitly disabled while a confirmation dialog is open
  (`if (confirmationKind !== "" ...) return`), so background controls cannot
  receive stray focus while a modal confirmation is up.
- Opening `AccessibleConfirmDialog` moves focus to its Confirm button
  (`Qt.callLater(() => confirmButton.forceActiveFocus())`); arrow keys move
  between Cancel/Confirm via `moveSelection`; `activateSelected()` fires
  the selected action. Both buttons carry `Accessible.name`/`Accessible.description`.
- `ask()`/`restoreFocus()` capture the focused control (by index and item
  reference) before opening a confirmation and restore it afterward via
  `Qt.callLater(() => target.forceActiveFocus())`, for both the Cancel path
  and every Confirm-action path.

### Color-only state distinctions

- The panel's own QML only references four color tokens across both files:
  `Color.foreground` (all body text), `Color.background` (backdrop/card
  fill), `Color.accent` (the confirmation card's border), and `Color.muted`
  (referenced only inside the panel's own internal self-test comparison,
  never bound to anything the user sees).
- No control's enabled/disabled, dirty/clean, or readiness state is
  expressed by color alone anywhere in these two files: every stateful
  button carries an explicit `Accessible.description: enabled ? "Enabled" :
  "Disabled"` (or an equivalent explicit string) alongside whatever visual
  styling the shared `Button`/`Toggle` components apply. Toggle state is
  exposed via `Accessible.checked`, not just a visual switch. **Caveat**:
  this review read only `Panel.qml`/`AccessibleConfirmDialog.qml`; whether
  the *shared* `Button`/`Toggle`/`NumberField` components (defined in the
  installed Omarchy shell, outside this repository) add any color-only
  affordance on top of this was not checked and should be part of the
  owner's attended pass.

### Computed contrast ratios (WCAG relative-luminance formula, default theme tokens)

Using the fallback token values in `/usr/share/omarchy/shell/Commons/Color.qml`
(`foreground #cacccc`, `background #101315`, `accent #cacccc`, `muted #707880`):

| Pair | Ratio | WCAG AA (normal text, 4.5:1) |
| --- | --- | --- |
| foreground vs background | 11.56:1 | pass (also passes AAA 7:1) |
| accent vs background | 11.56:1 | pass (border/decorative use only; UI-component minimum is 3:1) |
| muted vs background | 4.16:1 | fails 4.5:1 for normal text — **but `Color.muted` is not used for any displayed text in this panel**, only inside the internal self-test's own contrast assertion |

All visible panel text uses `Color.foreground` at 11.56:1, comfortably above
AA. **Caveat, stated plainly**: this is computed against the *fallback*
palette baked into the shell singleton, not necessarily the operator's
actually-active theme — `Color.qml` documents that a theme's `shell.toml`
can override these per-surface. The owner's attended session should re-check
contrast under whatever theme is actually active, especially if it's a
light theme or a user-customized palette; this precursor cannot rule that
in or out.

### Text scaling

`Panel.qml` uses `Style.font.body`/`Style.font.title`/`Style.font.bodySmall`
and `Style.space(px)` throughout rather than hardcoded pixel literals;
`Style.qml` derives `Style.space()` from a configurable `[font] base-size`
rem root with an explicit `scale-with-font` theme key. The panel does not
hardcode sizes that would ignore the shell's font-scale setting, as far as
static reading can establish — actual rendering at a large scale factor is
an attended check.

### Requested-vs-effective policy comparison: announced non-visually?

**Partial — a real gap found.** Two adjacent `Text` blocks in the "Current
status" section behave differently:

- `statusSummary` (readiness/blocker text) has
  `onTextChanged: function(value) { if (visible && Accessible.announce) Accessible.announce(value, Accessible.Polite) }`
  — changes are actively announced.
- `actionResult` (latest action result) has the same `onTextChanged` →
  `Accessible.announce` pattern.
- The **Requested/Effective/Provenance/latest-mutation-result** block
  (`Panel.qml` lines ~437–449 — "Requested: … \nEffective: … \nProvenance:
  … \nLatest system policy request result: …") has an `Accessible.name` but
  **no matching `onTextChanged` → `Accessible.announce` handler**. A screen
  reader user who applies a system policy and has focus elsewhere will hear
  the generic action-result announcement ("Policy applied.") but will not be
  proactively told that the Requested/Effective comparison text changed —
  they would have to navigate to that element manually to discover whether
  effective policy actually matches what was requested (e.g. an
  administrator override producing `HBR-SYSTEM-POLICY-DIFFERS`).

This is a concrete, static, reproducible-from-source finding, not a guess —
recorded here rather than glossed over, per the reporting-discipline
instruction that this evidence standard makes no unsupported claim (in
either direction).

### Owner checklist — one short attended session (precursor only, not sign-off)

Label: **this is a checklist to walk, not an accessibility sign-off.** None
of the following has been performed; every line needs the owner physically
present with a keyboard (and ideally a screen reader) in front of the real
panel.

1. Open the panel using only the keyboard (no mouse) from a closed state.
2. Tab/Shift-Tab (or the panel's arrow-key equivalent) through all 17 focus
   targets in the order listed above; confirm focus is always visible and
   never gets stuck or skips a control.
3. Trigger each of the five confirmation-gated actions (manual staged sleep,
   apply system policy, reset system policy, reset invalid user policy,
   reset outcome history) and confirm: focus lands on Confirm by default,
   arrow keys move between Cancel/Confirm, Escape cancels, focus returns to
   the exact control that opened the dialog.
4. Confirm the "Press Escape or choose Cancel to leave it unchanged" message
   is read by the screen reader when a confirmation opens.
5. Trigger "Review and apply system policy" while running a screen reader;
   confirm the pkexec authentication dialog is announced and reachable, and
   that focus returns to a sensible panel control after the dialog closes
   (cancelled and authorized both).
6. Change idle delay and hibernate delay via the exact-seconds `NumberField`
   controls using only the keyboard; confirm the new value and "(unsaved
   draft)" state are both announced.
7. With a screen reader running, apply a system policy that an administrator
   override will make differ from what was requested (or simulate via test
   fixture) and confirm whether the Requested/Effective/Provenance text
   change is actually heard — this static review found it is **not** wired
   to `Accessible.announce` (see gap above); the owner should confirm this
   in practice and decide whether it blocks daily use.
8. Repeat the whole panel at 150–200% text scale (via the shell's font-scale
   setting) and confirm no text is clipped or overlapping.
9. Re-run the contrast check above against whatever theme is actually active
   on the release machine, not just the fallback tokens.
10. Trigger "Copy sanitized diagnostics" and confirm both the "Copying…" and
    final "Diagnostics copied."/"Could not copy diagnostics." states are
    announced (code review found both go through the same `actionResult`
    announce path as other action results — worth a live confirmation).

Ten items; each is independently attendable in well under the planned
four-stage attended session's accessibility stage.

## Summary

| AC | Result |
| --- | --- |
| AC1 | Confirmed — identity, checksums, signature, and archive-content-vs-tree binding all independently re-verified today. |
| AC6 | Source verification, unprivileged-build recipe substitution, contents/ownership/modes, dependencies (zero), toolchain versions, and the advisory scan (0 advisories against `cargo-audit` 0.22.2 / advisory-db `d5c1795`, 2026-09-20) all recorded above. Nothing blocks qualification on this criterion; one non-blocking toolchain-provenance gap noted (rustup toolchain vs. declared pacman `makedepends`, versions match). |
| AC7 | Independent **agent** review completed; no exploitable vulnerability found; the "human" wording of the criterion remains explicitly unmet. |
| AC5 (precursor) | Static checklist produced (10 items) with one concrete non-visual-announcement gap found; explicitly not sign-off. |

No claim is made here about hardware, human review, or accessibility
sign-off beyond what is stated above.
