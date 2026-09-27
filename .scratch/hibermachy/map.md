# Architect Hibermachy for Omarchy Quattro

Label: wayfinder:map

## Destination

An implementation-ready specification for a public, independently installable Hibermachy plugin targeting Omarchy 4.0.1 Quattro. The resolved tickets must leave an implementer with no unanswered product, runtime, privilege, installation, interface, failure-handling, compatibility, or verification decisions.

## Notes

- This map plans the plugin; implementing and publishing it are outside this effort.
- Consult `omarchy` for current Quattro behavior, `codebase-design` for module seams, `domain-modeling` for project language, `research` for external facts, `prototype` for UI decisions, and `grilling` for human decisions.
- Prefer documented Quattro contracts and primary Omarchy, systemd, Polkit, and kernel sources.
- Treat real suspend and hibernate operations as destructive during planning; inspect and simulate unless a later ticket explicitly agrees on a controlled hardware test.
- Preserve Quattro's Stay Awake behavior and existing sleep inhibitors.
- Use ticket names, not bare numbers, in human-facing narration.

## Decisions so far

- [Define Hibermachy's product boundary](issues/01-define-product-boundary.md): Specify a standalone Quattro 4.0.1 plugin for idle-triggered staged sleep, with safe suspend-only fallback and an explicit manual action.
- [Constrain privileged configuration](issues/02-constrain-privileged-configuration.md): Isolate system-wide sleep-policy writes behind an authenticated, one-shot, root-owned helper with a fixed command vocabulary.
- [Place Hibermachy in Super+Space](issues/03-place-hibermachy-in-super-space.md): Put configuration under Setup and the immediate staged-sleep action under System, without adding a root-menu destination.
- [Map Quattro integration seams](issues/04-map-quattro-integration-seams.md): Build on a public service/panel, independent inhibitor-aware idle monitor, public Stay Awake check, shell IPC, and explicit menu extension; avoid idle clones and private shell objects.
- [Establish helper security and packaging constraints](issues/05-establish-helper-security-and-packaging-constraints.md): Package a compiled one-shot helper separately, authenticate every fixed `apply`/`reset`, and atomically own only Hibermachy's systemd drop-in.
- [Establish the compatibility envelope](issues/06-establish-compatibility-envelope.md): Test 4.0.1 explicitly, feature-probe later 4.x, gate sleep through logind capabilities, fail closed on contract mismatches, and degrade to suspend when hibernation is unavailable.
- [Choose the plugin runtime architecture](issues/07-choose-plugin-runtime-architecture.md): Coordinate through an independent inhibitor-aware service, funnel automatic and manual requests through one private execution gate, and expose only a manual request plus read-only status.
- [Choose configuration and state ownership](issues/08-choose-configuration-and-state-ownership.md): Split activation, user intent, requested system policy, effective system policy, and live state among explicit owners with fail-closed reload, re-arm, and serialized mutation invariants.
- [Choose configuration defaults and validation rules](issues/13-choose-configuration-defaults-and-validation-rules.md): Use a strict fail-closed v1 user policy, safe disabled first-run defaults, bounded whole-second delays, authenticated canonical system policy, and explicit one-way migrations.
- [Prototype the native settings panel](issues/10-prototype-native-settings-panel.md): Use a native single-sheet panel with separate user and authenticated system-policy commits, explicit live status and fallbacks, and confirmation for immediate or destructive actions.
- [Choose the installation and lifecycle model](issues/09-choose-installation-and-lifecycle-model.md): Use a GitHub-only, native-first, rerunnable lifecycle with explicit trust and authority seams, protocol-gated updates, conflict-safe menu ownership, and reset-before-removal cleanup.
- [Define failure handling and observability](issues/11-define-failure-handling-and-observability.md): Use evidence-based outcomes, operation-scoped readiness, non-replaying recovery, bounded structured history, and privacy-minimized diagnostics across sleep and policy failures.
- [Define verification and release gates](issues/12-define-verification-and-release-gates.md): Promote one immutable candidate only after traceable automated, clean-room, security, lifecycle, accessibility, and controlled-hardware evidence passes without product-failure waivers or version-support promises.
- [Reassess the privileged policy boundary](issues/14-reassess-the-privileged-policy-boundary.md): Retain the authenticated one-shot helper, while adding Rust isolation, signed-source packaging, strict fail-closed behavior, and independent review before daily use.

## Not yet specified

## Out of scope

- Implementing, packaging, publishing, or submitting Hibermachy upstream; this map ends at an implementation-ready specification.
- Supporting pre-Quattro Omarchy or promising compatibility with a future Omarchy 5.
- Compatibility or migration decisions caused only by future Omarchy, Quickshell, or systemd changes; each release records its verified environment without promising other versions, so future contract changes require a new effort.
- Replacing normal Suspend or laptop-lid behavior; staged sleep is an idle policy plus a separate manual action.
- Reimplementing Omarchy's swap, initramfs, bootloader, or hibernation provisioning.
- Solving kernel, firmware, GPU, or device-specific hibernation defects.
- Hardware-family coverage beyond the designated verified machine; controlled cycles provide release evidence without creating a general hardware-compatibility claim.
