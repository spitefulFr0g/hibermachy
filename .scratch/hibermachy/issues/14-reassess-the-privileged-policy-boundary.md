# Reassess the privileged policy boundary

Type: grilling
Status: resolved
Blocked by:

## Question

Should Hibermachy retain its narrowly privileged, authenticated one-shot helper
for changing systemd's machine-wide suspend-then-hibernate policy, or remove that
component by accepting a smaller settings feature set or a different
administrator-managed configuration workflow?

## Answer

Retain the privileged policy helper, with a stricter security and release
boundary. systemd/logind remains solely responsible for suspend and hibernation;
the helper may only apply or reset Hibermachy's requested system policy and must
exit immediately afterward. It never initiates sleep, bypasses inhibitors,
accepts caller-selected paths, executes commands, or processes free-form
configuration.

The settings panel keeps separate commit domains. User-only automatic-policy
enablement and idle delay require no authentication. Every Apply or Reset of the
machine-wide hibernate delay and AC-power behavior requires fresh, non-retained
Polkit administrator authentication. The review must label the values as system
policy and explain that they affect every user and every caller of systemd's
suspend-then-hibernate operation. We accept the bounded residual risk that a
compromised plugin could, after the user approves a genuine prompt, select any
valid pair of those two policy values; it must not gain a general root-execution
primitive. Do not enlarge the privileged surface with a root graphical settings
interface merely to display the arguments independently.

Implement the helper as a small Rust binary with minimal dependencies. Forbid
unsafe code except within one isolated, reviewed low-level filesystem module.
Retain the previously specified fixed command vocabulary, fixed target,
canonical validation, safe descriptor-relative path handling, suspicious-file
refusal, serialization, atomic replacement, and bounded diagnostics. A missing,
incompatible, unexpectedly owned or permissioned, or otherwise suspicious
helper/policy state fails closed: disable privileged mutations and automatic
staged sleep, explain the fault, and never fall back to a shell, `sudo`, or direct
file write. A safe manual suspend fallback through systemd may remain available.

Keep the root package independent from the user-owned plugin. Installing the
package installs only the helper and Polkit declaration and never changes sleep
policy. The running plugin cannot install, replace, or automatically update the
helper. Build it locally from an immutable, cryptographically signed release,
verify both signature and source checksum, and install through the normal package
manager; never distribute an unsigned root binary or recommend a pipe-to-root
installer.

Guided full uninstall authenticates and resets recognized requested policy before
removing the package and plugin. Package removal repeats recognized-policy reset
as defense in depth. Plugin-only removal may leave machine-wide policy in place,
so the interface and documentation must disclose that consequence. The helper
never fights later administrator overrides and refuses to replace or delete an
unfamiliar object at its fixed path; diagnostics show requested and effective
policy separately and direct the administrator to manual inspection when needed.

Treat the helper as experimental and keep it off daily-use machines until the
complete adversarial security test suite passes and an independent,
security-aware human reviews the privileged code and packaging. Do not call the
component audited or secure without corresponding evidence.

## Comments

Resolved with the user through five live grilling rounds and a final
shared-understanding confirmation. The user accepted every recommendation,
including the bounded residual risk and the added Rust, signed-release,
fail-closed, and independent-review requirements.
