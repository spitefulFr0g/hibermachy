# 02: Apply requested system policy through the one-shot helper

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** A small one-shot Rust helper whose public apply operation accepts one bounded hibernate-delay and AC-power pair, atomically owns only Hibermachy's requested system policy, verifies the result, and exits.

**Blocked by:** None (can start immediately).

**Status:** complete

**Ticket commit:** `17d6e3f` (on top of `c03beaa`)

**Validation evidence:** Temporary user-scoped Rust toolchain provisioned under `/tmp/hibermachy-rustup.GmWRPd`; `cargo fmt --check`, production `cargo check`, `cargo test --features test-support` (10 passed), production `cargo build`, and `git diff --check` passed. No helper installation or live host policy mutation was performed.

**Code-review evidence:** Review against original base `8842099`: Standards reported 0 documented violations and only judgement-call smells (validation duplication, fixture path message chains, and secure-filesystem module breadth). Spec review found no scope creep; the final implementation includes deterministic write/readback fault paths, directory and target substitution fixtures, hostile-environment and bounded-diagnostic assertions, exact recognized-policy readback, rollback preservation, and atomic no-replace creation.

**Blocker:** None. Rust validation and the missing public process-boundary evidence are complete.

- [x] Apply accepts only canonical whole-second delays from 900 through 604,800 and exactly the two allowed AC values; malformed, missing, extra, oversized, fractional, signed, Unicode, or overflowing arguments fail closed.
- [x] Mutation requires effective root, uses fixed compile-time locations, distrusts the environment and working directory, invokes no shell or external command, and never initiates or configures sleep beyond the owned requested policy.
- [x] Descriptor-relative traversal validates every directory and target for type, ownership, mode, link count, and symlink escape before mutation.
- [x] A cooperating lock and unique same-directory temporary object provide atomic replacement, file and directory synchronization, restrictive permissions, and cleanup limited to that invocation's temporary object.
- [x] Success requires recognized owned-policy readback; contradictory readback fails verification and unavailable readback is reported as indeterminate without changing the previous complete policy.
- [x] Unsafe Rust is absent except, if unavoidable, inside one isolated low-level filesystem module whose boundary is documented for independent review.
- [x] Public process-boundary tests cover valid application, boundaries, concurrency, interrupted writes, hostile filesystem substitution, hostile environment, bounded diagnostics, and proof that rejection changes nothing outside the owned target.
