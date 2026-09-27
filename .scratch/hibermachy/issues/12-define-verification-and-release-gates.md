# Define verification and release gates

Type: grilling
Status: resolved
Blocked by: 06, 07, 08, 09, 10, 11, 13

## Question

What automated, simulated, integration, security, upgrade, accessibility, and controlled hardware checks must pass before Hibermachy's implementation can be considered faithful to the specification and safe to release?

## Answer

Hibermachy uses traceable, layered verification of one immutable release
candidate. A candidate is one frozen commit, exact source archive and checksum,
and helper-package build and checksum. Every applicable gate certifies those
same bits. A shipped-source or generated-artifact change creates a new
candidate; other relevant changes invalidate evidence according to the
component-to-gate mapping below.

Verification makes no version-support, maintenance, hardware-compatibility,
security-certification, or accessibility-certification promise. Every public
code release names at least one **verified environment**: the exact Omarchy,
Quickshell, and systemd versions on which its applicable release gates passed.
That is factual test evidence only. An **unverified environment** may operate
when all required runtime contracts pass; an observed **contract
incompatibility** fails its affected operations closed. Runtime feature and
capability probes therefore remain safety controls without becoming support
claims.

### Traceability and applicability

The implementation specification has a version-controlled verification matrix.
Every normative requirement maps to a stable check identifier, gate layer,
applicability rule, required environment, and expected evidence. A requirement
without a check blocks release unless the specification explicitly classifies
it as observational and explains why it cannot be asserted.

A version-controlled component-to-gate table maps changed paths and artifacts
to required gates. Only non-shipped prose can take a documentation-only
exemption. Installation, security, compatibility, and recovery instructions
remain release-relevant. Uncertain impact selects the broader gate set. No
arbitrary line-coverage percentage substitutes for traceable behavioral
coverage: named safety invariants and state transitions must be asserted,
coverage reports expose gaps, and an unexplained coverage regression blocks
release.

Every applicable blocking check needs a clean final result. Product failures
and intermittent product behavior have no release waiver. A suspected
infrastructure failure may be rerun only after its failed evidence and cause
are recorded. Inapplicability comes only from the predefined mapping, never an
ad hoc release exception. If a required environment, tool, maintainer action,
or physical machine is unavailable, stable promotion waits; the artifact may
remain a clearly marked development build or prerelease.

### Merge gate

The deterministic merge gate runs without real privileged host writes or sleep
submission. It requires:

- clean candidate-only builds; formatting and lint checks; QML and shell
  validation; compiled-helper warnings and available static analysis;
  package-recipe validation; generated-file consistency; and fixture
  validation;
- narrow, justified, version-controlled tool suppressions established before
  release sign-off, with project-controlled warnings otherwise treated as
  failures;
- exhaustive tests for safety-critical branches and state transitions, using
  controlled time, activity, Stay Awake, inhibitors, logind capabilities and
  signals, external power, helper outcomes, filesystem failures, reloads, boot
  changes, and concurrency;
- representative pairwise coverage rather than a full Cartesian product for
  combinations that cannot change safety;
- assertion of every outcome, phase, readiness projection, stable reason code,
  notification fingerprint, re-arm invariant, retry rule, history bound, and
  diagnostics-redaction rule;
- user-policy creation, canonicalization, validation, revision, conflict,
  exhaustion, reset, and migration tests, including permanent fixtures for
  every shipped schema and rejection fixtures for malformed, unknown, and
  newer schemas;
- permanent protocol-overlap fixtures for every still-declared plugin/helper
  pairing;
- automatic/manual request distinctions; capability selection; suspend
  fallback; Stay Awake; compositor and system inhibitors; execution-gate
  serialization; policy apply/reset and readback; administrator precedence;
  separate commit domains; reload, generation, boot-ID, incomplete-evidence,
  persistence, and retry behavior;
- property or fuzz testing of configuration parsers and privileged-helper
  input handling; deterministic fault injection at concurrency, filesystem,
  persistence, and evidence boundaries; and
- a time-bounded accelerated soak across thousands of activity, idle, reload,
  mutation, and failure transitions, checking for duplicate sleep submission,
  stuck busy state, unbounded history or notification growth, retry storms,
  stale state, and resource growth.

### Release-candidate gate

Native release-candidate testing starts in a fresh user profile on a clean
verified environment and installs only from the immutable candidate artifact.
It inherits no development checkout, configuration, state, menu contribution,
helper policy, or package artifact. Each scenario begins and ends with an exact
scope inventory; upgrade scenarios deliberately begin at the immediately
preceding public release.

The native integration matrix covers plugin discovery; disabled-first
installation; activation, disablement, and reload; service and panel creation;
namespaced menu integration and row self-hiding; shell IPC; Stay Awake and idle
inhibition; user-policy persistence; helper protocol probing; real Polkit
cancellation and authorization; apply/reset readback; administrator-override
presentation; structured journals; sanitized diagnostics export; and teardown.

The privileged-helper and lifecycle security matrix covers malformed, missing,
extra, oversized, Unicode, negative, fractional, overflow, and boundary
arguments; hostile environment and working directory; symlink, hard-link,
ownership, mode, and file-type substitution; target-parent replacement;
concurrent apply/reset; interrupted atomic writes; forged or incompatible
protocol data; inactive-session, denied, and cancelled Polkit requests;
modified managed-menu entries; and purge-path symlink escape attempts. Every
rejection must leave everything outside Hibermachy's owned target unchanged.

Lifecycle journeys cover:

1. clean native add, setup, and activation;
2. declined activation followed by later activation;
3. active and disabled upgrades from the preceding release;
4. cancellation or failure after every cross-scope step, inventory, and safe
   rerun;
5. protocol mismatch and helper-absent recovery;
6. menu collision and modified managed-entry refusal;
7. disablement and plugin-only removal with retained policy reported;
8. full uninstall with reset before package removal;
9. purge with retained-data summary and separate deletion confirmation; and
10. re-add-disabled, reinstall-helper, and reset recovery after incomplete
    native removal.

The first public release substitutes install, uninstall, and reinstall for an
upgrade from a preceding release. Later candidates require a real clean-machine
upgrade only from the immediately preceding public release; permanent schema
and protocol fixtures carry older compatibility cases without installing every
historical release.

Accessibility sign-off may be performed by the sole maintainer. Every panel and
confirmation journey is completed by keyboard alone and checked for forward
and reverse focus order, focus restoration, escape and cancellation, disabled
and dirty states, authentication return, error and fallback announcements,
normal and enlarged scaling, high- and low-contrast themes, non-color status
distinctions, readable requested/effective comparisons, and accessible names
and states. The journey also receives an assistive-technology smoke test through
the verified stack's available accessibility surface. Lack of automation makes
a check manual, not optional.

Supply-chain checks verify every fetched source checksum, build the helper as
an unprivileged user, inspect final package contents, ownership, and modes, and
record dependency and toolchain versions. Current available advisory data is
checked. A known applicable, exploitable high- or critical-severity issue in
shipped code blocks release; an irrelevant or disputed finding needs a written,
version-controlled applicability determination, not an informal waiver. This
does not claim the absence of vulnerabilities.

Ordinary and untrusted-contribution CI may not perform real sleep, privileged
host writes, or destructive lifecycle changes. Such operations are intercepted
or redirected to isolated fixtures. Real root-helper, package, Polkit, hostile-
filesystem, and destructive lifecycle cases run only in a disposable VM or
equivalent disposable system environment. Untrusted pull requests cannot
trigger privileged or hardware jobs or access reusable root, Polkit, or
publication credentials; a maintainer must explicitly authorize them against a
reviewed immutable candidate.

### Public-release hardware gate

Every applicable public code release runs an attended controlled procedure on
one designated battery-equipped machine with known-working suspend and
hibernation. Its exact environment and a non-identifying hardware description
are evidence, not a general hardware-compatibility claim. The procedure must be
explicitly armed, warn the operator to save work, identify its target, record
initial policy, and verify restoration of policy and configuration afterward.
Capability detection alone must never trigger sleep, and no unattended
physical sleep soak is required.

The gate requires three consecutive successful full staged-sleep,
hibernate, and resumed-session cycles. Together they include at least one
automatic request, one manual request, and one AC-policy deferral that proceeds
to hibernation after AC is disconnected. It also runs once each: early/manual
wake before hibernation, Stay Awake suppression, compositor-idle inhibition,
system-inhibitor refusal, fresh-activity re-arm, reload while latched, and an
intentionally capability-disabled suspend fallback. An unexplained anomaly is
a product failure and restarts the consecutive-cycle count only after
investigation.

Because Hibermachy's observable `Completed` outcome deliberately cannot prove
hibernation, the hardware procedure establishes a pre-sleep session checkpoint,
externally observes the machine reach a hibernated or powered-down state rather
than merely waking from suspend, resumes the same checkpoint, and retains
sanitized corroborating system evidence. Hibermachy's status and free-form
journal text cannot independently certify hibernation or alter product state.

### Promotion and evidence

Release promotion is:

1. freeze the candidate commit;
2. produce the exact source archive and checksum;
3. pass automated gates;
4. publish the immutable candidate as a clearly marked GitHub prerelease;
5. build the helper package from that public candidate source;
6. run clean install, upgrade, native integration, accessibility, security, and
   hardware gates against those public artifacts;
7. publish the verification record and promote the unchanged candidate to
   stable; and
8. smoke-check public metadata, downloads, checksums, and lifecycle discovery.

Published artifacts are never replaced under the same version. A failed
candidate receives a new candidate identity. A defect found after promotion is
documented and fixed in a new release rather than silently replacing bits.

The sole maintainer may sign the verification record and promote the release;
no second reviewer is required. The sanitized, version-controlled record names
the candidate commit, source and package checksums, exact verified environment,
non-identifying hardware, applicable check identifiers and final results,
manual-check dates, maintainer sign-off, prerequisite infrastructure-failure
investigations, and known non-blocking observations. It excludes usernames,
serial numbers, arbitrary paths, raw configuration, unrestricted logs, and any
claim of version support or certification.

Evidence is invalidated when its affected shipped source, generated artifacts,
package recipe, dependency resolution, build toolchain, test harness, gate
definition, verified-environment versions, relevant machine firmware or
configuration, or candidate metadata changes. The component-to-gate table
selects the required reruns; uncertainty selects the broader set. Pure
corrections to evidence prose may be amended without rerunning when artifacts
and results are unchanged.

## Comments

Resolved with the user through six numbered grilling rounds and an explicit
shared-understanding confirmation. The user chose factual verified-environment
evidence with no promise to support specific versions, then accepted the
recommended traceability, automated, integration, security, lifecycle,
accessibility, hardware, evidence, and promotion gates. Domain vocabulary was
updated inline in `CONTEXT.md`.
