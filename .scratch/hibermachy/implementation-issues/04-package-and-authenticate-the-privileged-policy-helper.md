# 04: Package and authenticate the privileged policy helper

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** A separately owned Arch package and matching Polkit integration install the one-shot helper through an explicit trust path and require fresh administrator authorization for every mutation.

**Blocked by:** 03: Reset only recognized requested system policy.

**Status:** complete

**Claimed:** 2026-09-07 by impl/04-helper-packaging

**Ticket commits:** `7d2a654` (package, Polkit policy, probe, fixtures),
`fdcd4bd` (restrict Polkit to active sessions).

**Validation evidence:** Scoped Rust tooling under
`/tmp/hibermachy-rustup.GmWRPd` (`CARGO_HOME` and `RUSTUP_HOME` pointed there).
`cargo fmt --check`, `cargo clippy --all-targets --features test-support -- -D warnings`,
`cargo test --features test-support` (23 passed), `cargo check`, `cargo build
--release`, and `git diff --check` passed. Tests exercise the public helper
process probe and isolated package/Polkit fixtures. No helper installation,
live Polkit authentication, host policy mutation, system journal access,
publication, or hardware gate was performed.

**Code-review evidence:** Final two-axis review against `8a95a73` over
`7d2a654` and `fdcd4bd`: Standards reported 0 documented violations and 0
baseline-smell findings. Spec review reported no scope creep. It recorded
protocol-consumer negotiation, end-to-end package/live-Polkit/journal evidence,
and lifecycle caller integration as later lifecycle/release-gate work; signed
release metadata remains intentionally placeholder-only because this ticket
must not invent a signing identity or publish. The review's actionable finding
that inactive/non-session Polkit callers were allowed was fixed in `fdcd4bd`.

**Blocker:** None for this implementation gate. Real signing identity and
publication, lifecycle protocol enforcement, live Polkit/package ownership,
bounded journal, disposable-system, and attended hardware evidence belong to
later gates as directed.

- [x] The package recipe verifies immutable release checksum/signature metadata before an unprivileged build and installs a non-setuid, root-owned helper plus only its required Polkit declaration. Release checksum/key sentinels remain for the later signed-publication gate.
- [x] The matching Polkit contract requires fresh active-session administrator authentication (`no`, `no`, `auth_admin`) without retained or passwordless authorization, GUI environment allowance, file capabilities, setuid, sudo fallback, or a root graphical process.
- [x] The package recipe has no installation/upgrade policy mutation, and this helper-only branch exposes no plugin package-management interface; lifecycle caller enforcement remains a later integration seam.
- [x] A read-only unprivileged protocol probe reports helper release and protocol compatibility; lifecycle-side overlap enforcement remains a later integration seam.
- [x] The package removal hook repeats the recognized-policy reset and deliberately masks scriptlet failure so package removal is not reported as aborted; lifecycle caller behavior remains a later integration seam.
- [x] Package content, install paths/modes, toolchain/dependency declarations, source signature/checksum contract, and protocol fixture are verifiable at the public package/process boundaries; live ownership, Polkit, and bounded-journal evidence remain later disposable/release gates.
