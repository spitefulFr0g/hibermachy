# 03: Reset only recognized requested system policy

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** The helper's reset operation removes only absent or recognized Hibermachy requested system policy and refuses any object that requires administrator inspection.

**Blocked by:** 02: Apply requested system policy through the one-shot helper.

**Status:** complete

**Claimed by:** impl/03-reset-policy

- [x] Reset is idempotently successful when the owned target is absent and removes a canonical recognized target through the same serialized, descriptor-relative safety boundary as apply.
- [x] Modified content, unfamiliar format, symlinks, hard links, unexpected types, wrong ownership, wrong permissions, and parent substitution are refused without deletion or repair.
- [x] Success requires confirmed absence through recognized-policy readback; contradictory readback fails verification and unavailable readback is indeterminate.
- [x] Reset never removes administrator configuration, reloads systemd or logind, invokes sleep, or uses wildcard cleanup.
- [x] Concurrent apply/reset and interrupted-removal tests prove deterministic results, preservation of the prior complete policy on failure, and no changes outside the owned target.

**Scope interpretation resolved:** Parent spec line 170 requires the helper to “serialize cooperating mutations,” and line 171 requires failure preservation within that mutation boundary; it does not define an arbitrary concurrently hostile root actor. The resolved privileged-boundary decision accepts bounded residual risk after genuine administrator authentication, while forbidding a general root primitive (issue 14, lines 23–42), and requires suspicious existing state to fail closed rather than be repaired (issue 14, lines 52–58). An unprivileged caller cannot reach the reported pathname race: production mutation first requires effective root, and every fixed `/etc/systemd/sleep.conf.d` component is opened descriptor-relatively with `O_NOFOLLOW` and must be owner-safe and non-writable by group/other. Pre-existing malicious or unfamiliar objects are refused; independent privileged replacement is outside the explicit cooperating-mutation acceptance scope. No blocker remains.

**Implementation evidence:** Final branch `impl/03-reset-policy`, HEAD `8a95a73`, based on apply helper `17d6e3f`. Commits: `73c0712 Add safe requested policy reset`, `0852c1c Harden reset rollback`, `4621a08 Make reset rollback non-destructive`, `d9b9363 Share helper fault injection`, `2ddd47a Restore policy after final reset sync failure`, `e9d6e8b Require canonical policy file permissions`, `071c4be Preserve recovery copy on target collision`, `8a95a73 Verify moved policy before reset cleanup`.

**Validation evidence:** Scoped toolchain under `/tmp/hibermachy-rustup.GmWRPd` with `CARGO_HOME` and `RUSTUP_HOME` pointed there. `cargo fmt --check`, `cargo check`, `cargo clippy --all-targets --features test-support -- -D warnings`, `cargo test --features test-support` (18 passed), `cargo build`, and `git diff --check` passed. Tests use the public helper process and isolated compiled filesystem fixtures; they cover absent/canonical reset, modified content, symlink, hard link, unexpected type, wrong ownership, exact permissions, parent substitution, pre-existing temporary collision, readback contradictions/unavailability, final-sync recovery, hostile environment, apply/reset concurrency, and no sleep/systemd/logind/helper installation. No live host policy was changed and no helper was installed.

**Code-review evidence:** Final two-axis review against `git diff 17d6e3f...HEAD`: Standards found 0 documented violations and 1 judgement-call duplicated canonical fixture setup in `tests/apply_process.rs`; Spec found no scope creep. Its reported pathname-substitution concern was reassessed against parent spec line 170 and the resolved privileged-boundary decision and is outside the cooperating-mutation threat model, not an in-scope acceptance failure. Review agents made no changes.
