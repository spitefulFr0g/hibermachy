# 08: Manage requested and effective system policy from the panel

**Parent spec:** [Architect Hibermachy for Omarchy Quattro](../spec.md)

**What to build:** The panel's separate system-policy commit domain reviews, authenticates, applies, resets, and reconciles requested system policy without conflating it with user policy or administrator-effective policy.

**Blocked by:** 04: Package and authenticate the privileged policy helper; 05: Save and recover strict user policy.

**Status:** complete (impl/08-system-policy-panel; commits 59eed6c, a581d8f; base 2fd4720e30e423c931c15d726c8b4af7dcae24f9)

**Evidence:** Added independent machine-wide system-policy draft/review/apply/reset IPC and panel seams. Production invokes `pkexec /usr/libexec/hibermachy-policy-helper` with the complete validated pair, consumes bounded requested readback, and separately reads effective policy/provenance through `systemd-analyze cat-config systemd/sleep.conf`; hosted tests override only those external commands with disposable fixtures. `tests/quattro-hosted-plugin.sh` passes all plugin, user-policy, system-policy, failure, override, concurrency, reset, and no-replay checks. Elevated disposable Rust validation passes all 20 helper process tests and 4 packaging tests. `cargo fmt --all -- --check`, `bash -n tests/quattro-hosted-plugin.sh`, and `git diff --check` pass. Two-axis review against base `2fd4720e30e423c931c15d726c8b4af7dcae24f9` found no documented standards source or remaining spec finding.

- [x] The system-policy draft proposes a 7,200-second hibernate delay with hibernation on AC disabled, labels both values as machine-wide, and persists nothing until explicit authenticated apply.
- [x] Apply reviews and submits the complete validated pair; reset explains its narrow effect; each invocation requires fresh authorization and only one privileged mutation may be in flight.
- [x] Authentication cancellation, denial, busy state, helper rejection, write failure, contradictory readback, unavailable readback, and success are returned with their specified refusal, failure, or indeterminate meanings.
- [x] Requested and effective policy are read separately after mutation, including ordered override provenance when available; administrator precedence produces Policy differs rather than write failure or automatic reapplication.
- [x] Missing, malformed, incomplete, unreadable, or incompatible helper/policy state disarms automatic staged sleep while preserving user intent and safe manual fallback.
- [x] User-policy and system-policy drafts, commits, errors, and successes remain visibly independent, and partial success is never described as one atomic save.
- [x] Public panel, IPC, helper-process, Polkit-cancellation, readback, administrator-override, concurrency, and no-replay tests verify the complete user-to-system-policy journey.
