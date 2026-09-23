# Choose the installation and lifecycle model

Type: grilling
Status: resolved
Blocked by: 05, 06, 07, 08, 13

## Question

How should users install, authorize, update, disable, and remove the Quickshell plugin, menu extension, and root-owned helper without leaving stale policy or weakening Quattro's plugin safety model?

## Answer

Hibermachy uses a native-first, state-aware lifecycle that preserves the
separate authority and ownership of its plugin checkout, menu contribution,
user data, helper package, and system policy. These scopes do not form an
atomic transaction. Every lifecycle operation inventories them separately,
retains completed valid work after partial failure, reports the resulting
state, and is safe to rerun.

V1 supports one **installation owner** per machine. The plugin, menu
contribution, and user data belong to that Omarchy desktop user; the helper and
requested system policy are machine-wide. Guided operations must state that
scope before a privileged change or full uninstall. Independent Hibermachy
installations for multiple Omarchy users on one machine are unsupported in v1.

The public GitHub repository is the sole v1 publication source. It contains the
Quickshell plugin, helper source, lifecycle tooling, and an Arch packaging
recipe. The recipe builds a separately owned `hibermachy-helper` package from
immutable, checksummed GitHub release source. V1 neither publishes to AUR nor
ships an unsigned prebuilt root helper. The package name and recipe remain
AUR-ready so a later release can add that channel without changing installed
package identity. GitHub hosts the plugin checkout; pacman continues to own the
installed helper and Polkit files.

Installation is deliberately staged:

1. The user runs Quattro's native `omarchy plugin add` against the public
   repository. Quattro's unsandboxed-code warning and review opportunity remain
   intact, and the checkout initially remains disabled.
2. A checkout-local lifecycle interface inventories all scopes, checks the
   supported Quattro environment, builds the helper package as the unprivileged
   user with `makepkg`, and installs it through pacman's normal interactive
   terminal authorization.
3. The lifecycle interface atomically merges the menu contribution, performs
   compatibility and integration probes, and reports any incomplete scope.
4. It offers a final explicit confirmation that delegates activation to
   Quattro's native enable operation. Declining leaves the plugin disabled.

Installation never applies requested system policy. Activation is allowed when
the helper is absent or incompatible so the panel and manual suspend fallback
remain available, but privileged policy mutation and automatic staged sleep
stay disarmed until a compatible helper and valid requested/effective policy
are ready.

The running plugin may invoke only the already-defined authenticated helper
operations, `apply` and `reset`, through Polkit. Every invocation uses
non-retained `auth_admin`; cancellation remains distinct from helper failure.
The running plugin never installs, updates, or removes a system package. Those
operations occur only in the terminal lifecycle workflow through native Arch
tools. Menu actions remain unprivileged shell-IPC adapters, and lifecycle
tooling never suppresses Quattro's source-review prompt or the package manager's
authorization prompt.

The helper exposes an unprivileged, read-only protocol probe. Plugin and helper
release versions may differ when their protocol ranges overlap. A protocol
mismatch disables helper-backed mutations and automatic staged sleep, reports
both versions, and preserves manual suspend fallback. Runtime checks repeat
before privileged use so an independently changed package fails closed.

The shared menu extension uses the exact namespaced ids `setup.hibermachy` and
`system.hibermachy-staged-sleep`. Lifecycle tooling performs an atomic,
structure-aware edit that preserves unrelated JSONC entries, ordering, and
comments. It updates or removes only recognized Hibermachy-generated entries.
An id collision, malformed shared file, or user-modified managed entry stops
the operation without overwriting or deleting it. Both rows self-hide whenever
a compatible live Hibermachy service is unavailable, so native disablement or
plugin-only removal cannot leave an actionable stale row.

Guided update records prior activation, disables an active plugin, invokes
Quattro's reviewed fast-forward update without `--yes`, hands control to the
updated lifecycle tooling, rebuilds and upgrades `hibermachy-helper` from the
new immutable GitHub release source, reconciles recognized menu entries, and
reruns compatibility probes. It restores the prior active state only after all
required checks pass. A previously disabled plugin stays disabled. V1 does not
claim that `omarchy update` updates the GitHub-only helper; lifecycle status and
the guided updater own update detection. There is no automatic downgrade or
cross-scope rollback after cancellation or failure.

Lifecycle operations have these distinct meanings:

- **Disable** delegates to Quattro and unloads the service and panel while
  retaining the checkout, menu contribution, user data, helper package, and
  effective system policy.
- **Plugin removal** delegates to `omarchy plugin remove` and removes only the
  user checkout after disablement. It is not a Hibermachy uninstall.
- **Hibermachy uninstall** disables the plugin, explicitly invokes the helper's
  authenticated `reset`, and stops before package removal if authentication is
  cancelled or reset fails. It then removes `hibermachy-helper` through pacman,
  verifies that the package and owned drop-in are absent, removes recognized
  menu entries, and removes the checkout last. The package's `pre_remove`
  script repeats the validated reset as defense-in-depth only; scriptlet
  failure is not trusted to abort pacman's transaction. User configuration and
  state are retained for reinstall.
- **Hibermachy purge** performs uninstall, summarizes the exact XDG-owned user
  paths, asks for an additional destructive confirmation, and deletes them
  last. It validates path ownership and never follows a symlink outside the
  owned paths.

A read-only lifecycle status reports checkout, activation, menu, helper,
protocol, user-data, requested-policy, and owned-drop-in state independently.
If native plugin removal deleted the lifecycle tool, supported recovery re-adds
a compatible checkout disabled before rerunning uninstall or purge. If the
helper is absent while its owned policy remains, recovery reinstalls a
compatible helper before using its validated reset/removal path. Unrecognized
or modified shared-menu content is left for explicit user resolution. Root
bypasses such as pacman `--noscriptlet` or `--dbonly` are outside the cleanup
guarantee, but diagnostics and the documented reinstall-then-reset recovery
remain available.

Research assets:

- [`Installation and lifecycle contracts for Hibermachy`](../research/installation-and-lifecycle-contracts.md)
- [`Omarchy plugin hosting and AUR helper distribution`](../research/aur-and-plugin-distribution-2026-08-29.md)

## Comments

Resolved with the user through multiple live grilling rounds and a final
shared-understanding confirmation. The user accepted the native-first,
fail-closed lifecycle recommendations, requested current ecosystem and AUR
research, chose a GitHub-only v1 after reviewing it, accepted the strengthened
explicit-reset-before-package-removal rule, and confirmed the consolidated
model.
