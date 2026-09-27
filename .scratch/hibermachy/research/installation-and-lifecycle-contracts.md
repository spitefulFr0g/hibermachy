# Installation and lifecycle contracts for Hibermachy

Research date: 2026-08-28  
Installed baseline: Omarchy `4.0.1-1` (Quattro), Quickshell `0.3.1-1`,
systemd `261.2-1`, Polkit `127-3`, pacman `7.1.0.r9.g54d9411-2`

## Question

What factual platform contracts constrain installation, authorization, update,
disablement, and removal of an independently installed Hibermachy Quickshell
plugin, its explicit Omarchy-menu extension, its in-shell runtime service, and
its separately packaged root-owned one-shot helper?

## Short answer

Quattro exposes a lifecycle only for the plugin checkout and its activation.
`omarchy plugin add` clones and validates a Git repository into the current
user's plugin directory, warns that enabled plugins are unsandboxed, and leaves
the plugin disabled unless enablement is requested. It does not run install
hooks or `sudo`. Its updater fast-forwards that checkout, and its remover
deactivates the plugin before deleting or backing up only that checkout. It does
not own a menu contribution, Hibermachy user data, a system package, a Polkit
policy, or a system-wide sleep-policy drop-in. [Installed Omarchy README,
lines 94-125](</usr/share/omarchy/shell/README.md>) [add implementation,
lines 96-175](</usr/share/omarchy/bin/omarchy-plugin-add>) [remove
implementation, lines 71-122](</usr/share/omarchy/bin/omarchy-plugin-remove>)

The Omarchy menu has one shared per-user JSONC extension file, not a fragment
directory or per-plugin registration API. It is live-watched and merged over
the shipped defaults by item id. Therefore installing, changing, or removing
Hibermachy's two menu rows is a separate, preservation-sensitive edit to shared
user state. [Extension-file contract](</usr/share/omarchy/config/omarchy/extensions/omarchy-menu.jsonc>)
[merge implementation](</usr/share/omarchy/shell/plugins/menu/MenuModel.js>)
[watch implementation, lines 919-938](</usr/share/omarchy/shell/plugins/menu/Menu.qml>)

An enabled third-party `service` entry point is a singleton object inside the
long-running `omarchy-shell`, not a separately enabled systemd service. Disable,
removal, source change, or global plugin rescan destroys it; source change then
recreates it if still enabled. [service host, lines
263-359](</usr/share/omarchy/shell/shell.qml>) [reload path, lines
739-778](</usr/share/omarchy/shell/shell.qml>)

The root helper belongs to a separate Arch package because the Omarchy plugin
installer is deliberately user-scoped and non-privileged. That package can own
the compiled helper and its Polkit action. Per-use elevation uses `pkexec` with
an action bound to the helper's absolute path. `pkexec` supplies a minimal
environment but does not validate helper arguments; the helper retains that
responsibility. The selected ticket's already-fixed `auth_admin` defaults mean
every invocation challenges for an administrator without the retained-approval
semantics of `auth_admin_keep`. [official `pkexec(1)`](https://polkit.pages.freedesktop.org/polkit/pkexec.1.html)
[official `polkit(8)`](https://polkit.pages.freedesktop.org/polkit/polkit.8.html)

There is no platform-provided atomic transaction spanning these four scopes.
Any complete installer/updater/uninstaller is necessarily an orchestrator over
separate operations with observable partial-failure states. This is an
inference from the ownership and command boundaries documented below, not an
extra Omarchy API.

## 1. Quattro's plugin lifecycle

### Install and trust boundary

- A third-party plugin is a Git repository with `manifest.json` at its root.
  `omarchy plugin add <url>` clones to a hidden staging directory, validates it,
  rejects a duplicate id, moves it to
  `~/.config/omarchy/plugins/<manifest-id>/`, and asks the running shell to
  rescan. The default end state is installed but disabled; `--enable` or a
  later `omarchy plugin enable <id>` creates activation state. [README,
  lines 94-125](</usr/share/omarchy/shell/README.md>) [implementation,
  lines 116-175](</usr/share/omarchy/bin/omarchy-plugin-add>)
- Before cloning, Omarchy states that plugin code runs unsandboxed inside the
  long-lived shell and asks for confirmation. In a noninteractive context it
  refuses to continue without `--yes`; `--yes` suppresses the trust prompt.
  Install does not inspect the QML or establish code provenance beyond cloning
  the supplied Git URL and validating the manifest/filesystem shape. [add
  implementation, lines 22-34 and 96-127](</usr/share/omarchy/bin/omarchy-plugin-add>)
- Validation requires schema number `1`; `id`, `name`, `version`, `kinds`, and
  `entryPoints`; a restricted plugin id; an entry point for each known kind;
  relative existing entry-point files; and no symlinks outside `.git`. It does
  not define dependency, minimum-Omarchy, helper-package, signature, or install
  hook metadata. [validator, lines
  19-116](</usr/share/omarchy/bin/omarchy-plugin-validate>)
- The installer explicitly does not execute plugin code, install hooks, or
  `sudo`. Thus a repository accepted through the normal plugin path cannot
  install a root helper or its Polkit policy, and cannot use an install hook to
  modify the separate menu extension. [README, lines
  107-125](</usr/share/omarchy/shell/README.md>)

### Activation and runtime service

- For a third-party plugin with `service` and `panel` kinds, one entry in
  `shell.json`'s `plugins[]` is its enabled bit. The registry adds that entry on
  enable and removes it on disable. [registry, lines 110-139 and
  449-540](</usr/share/omarchy/shell/services/PluginRegistry.qml>)
- The shell instantiates an enabled `entryPoints.service` as a hidden singleton
  in its own process, injects the host/manifest/registries, and gives a matching
  panel the service object. It drops and destroys the service when the plugin is
  disabled or no longer discovered. No systemd user unit, enable symlink, or
  background daemon is involved in this Quickshell service lifecycle. [service
  loader, lines 263-359](</usr/share/omarchy/shell/shell.qml>) [panel injection,
  lines 581-651](</usr/share/omarchy/shell/shell.qml>)
- The user plugin tree is recursively watched for writes, creates, deletes, and
  moves, excluding `.git` internals. A change triggers a global plugin reload:
  panels, all plugin services, and all plugin widgets are destroyed, component
  caches are cleared, the registry is rescanned, and enabled objects are
  recreated. [watcher, lines
  636-713](</usr/share/omarchy/shell/services/PluginRegistry.qml>) [reload,
  lines 739-778](</usr/share/omarchy/shell/shell.qml>)
- Consequence: “runtime service” has no separately manageable installed/running
  state. Its installed state is the plugin checkout; its running state follows
  shell availability plus plugin activation. Durable Hibermachy state and any
  in-progress systemd suspend-then-hibernate interval must remain outside its
  object lifetime, as earlier tickets already require.

### Update

- `omarchy plugin update [id]` updates only Git-managed plugin directories. It
  fetches `origin HEAD`, reports “up to date” if unchanged, displays a source
  diff and asks for confirmation unless `--yes` was supplied, and accepts only
  a fast-forward merge. Local divergence prevents the update. [updater, lines
  39-75 and 105-132](</usr/share/omarchy/bin/omarchy-plugin-update>)
- Validation happens after the live checkout is fast-forwarded; a validation
  failure resets the checkout to `ORIG_HEAD`. Because the user plugin directory
  is live-watched, an enabled plugin update also causes shell object reloads as
  files change. The validator is a shape/path validator, not a code-safety or
  signature verifier. [updater, lines
  67-75](</usr/share/omarchy/bin/omarchy-plugin-update>) [watch/reload sources
  cited above]
- `omarchy update` does not call `omarchy plugin update`. It updates native
  system packages, runs Omarchy migrations, and later updates installed AUR
  packages; plugin checkouts remain on their independent update path. [Omarchy
  update, lines 41-52](</usr/share/omarchy/bin/omarchy-update>) [AUR step,
  lines 1-13](</usr/share/omarchy/bin/omarchy-update-aur-pkgs>)
- No plugin command reads the manifest `version` to negotiate with another
  component. A helper/plugin compatibility protocol must therefore be a
  Hibermachy runtime contract if the two can update independently. This is an
  inference from the validator and updater implementations.

### Disable and remove

- `omarchy plugin disable <id>` only sends
  `setPluginEnabled <id> false`. For this service/panel shape that removes the
  plugin's entry from `shell.json` and destroys its service/panel objects. It
  leaves the checkout installed. [disable command](</usr/share/omarchy/bin/omarchy-plugin-disable>)
  [registry disable path, lines
  449-540](</usr/share/omarchy/shell/services/PluginRegistry.qml>)
- `omarchy plugin remove <id>` checks the current shell state, disables an
  enabled plugin, deletes a Git checkout (or unlinks/backs up other install
  forms), and rescans. Its target is only
  `~/.config/omarchy/plugins/<id>`. [remove command, lines
  59-122](</usr/share/omarchy/bin/omarchy-plugin-remove>)
- Neither operation edits `~/.config/omarchy/extensions/omarchy-menu.jsonc`,
  `$XDG_CONFIG_HOME/hibermachy/`, `$XDG_STATE_HOME/hibermachy/`, the helper
  package, its Polkit policy, or
  `/etc/systemd/sleep.conf.d/90-hibermachy.conf`. This follows from the fixed
  targets in the disable/remove implementations and the distinct menu/helper
  ownership described below.

## 2. The explicit Omarchy-menu extension is shared user state

### File and merge contract

- Quattro reads shipped defaults from
  `$OMARCHY_PATH/default/omarchy/omarchy-menu.jsonc` and exactly one user file at
  `~/.config/omarchy/extensions/omarchy-menu.jsonc`. There is no discovered
  extension-fragment directory in 4.0.1. [menu paths, lines
  47-53](</usr/share/omarchy/shell/plugins/menu/Menu.qml>)
- IDs are object keys. Dotted ids infer hierarchy; `action` makes an action row;
  `target` makes a link; and otherwise an entry is a submenu. `aliases` and
  `description` participate in search, while `when` and `checked` are shell
  conditions. [shipped extension template, lines
  1-29](</usr/share/omarchy/config/omarchy/extensions/omarchy-menu.jsonc>)
- Defaults are merged first and the user source second. A repeated id is merged
  per field over the prior row; a new id is appended. Hibermachy's chosen
  `setup.*` and `system.*` rows can therefore attach to existing default
  submenus without replacing them. [parser and merge, lines
  13-94](</usr/share/omarchy/shell/plugins/menu/MenuModel.js>) [default Setup and
  System ids](</usr/share/omarchy/default/omarchy/omarchy-menu.jsonc>)
- Both files are live-watched. A changed user file is reloaded immediately; a
  missing/unreadable file produces no user entries. Invalid JSONC parsing also
  yields no user entries. [watch path, lines
  919-938](</usr/share/omarchy/shell/plugins/menu/Menu.qml>) [parse failure,
  lines 41-63](</usr/share/omarchy/shell/plugins/menu/MenuModel.js>)
- Menu `action` is passed to Omarchy's detached command executor. `when` and
  `checked` expressions are batched into a Bash subprocess. Menu contributions
  are therefore executable user configuration and have their own trust surface
  apart from whether a plugin is enabled. [action execution, lines
  137-142](</usr/share/omarchy/shell/plugins/menu/Menu.qml>) [guard construction,
  lines 462-477](</usr/share/omarchy/shell/plugins/menu/MenuModel.js>)

### Lifecycle consequences

- Quattro provides no command that installs/removes a named contribution or
  records which project owns particular menu ids. Any Hibermachy lifecycle tool
  must read-modify-write the one shared file, preserve unrelated fields/order as
  required by its chosen policy, detect id conflicts, and remove only the ids it
  owns. This is an inference from the single-file merge contract and absence of
  an extension-management command in `/usr/share/omarchy/bin/`.
- Plugin disablement/removal does not disable menu rows. Without a `when`
  condition tied to an actually available Hibermachy command/service, stale
  rows remain visible and their detached actions can fail after activation or
  files disappear. Conversely, deleting the menu rows does not stop an enabled
  service.
- Because edits hot-reload, no shell restart is required after a successful
  menu merge or unmerge. An atomic replacement is still needed so the watcher
  cannot observe a partial shared JSONC file; Quattro's `FileView` here reads the
  file but does not expose a project-specific write transaction.

## 3. Privileged helper and authorization lifecycle

### Package and execution boundary

- The normal plugin installer is incapable by contract of installing privileged
  files. A separate Arch package can own a fixed-path compiled helper and a
  matching policy XML in `/usr/share/polkit-1/actions/`. Polkit documents that
  applications declare actions there and that action ids/file names are
  namespaced. [official `polkit(8)`, “Declaring Actions”](https://polkit.pages.freedesktop.org/polkit/polkit.8.html)
- `pkexec` runs the named absolute program as root by default after obtaining
  authorization. The custom action is selected with
  `org.freedesktop.policykit.exec.path`; without a matching custom action,
  `pkexec` uses the generic `org.freedesktop.policykit.exec` action. The dialog
  presents the full path. [official `pkexec(1)`, “Action and Authorizations”](https://polkit.pages.freedesktop.org/polkit/pkexec.1.html)
- `pkexec` gives the child a minimal known environment but does not validate its
  arguments. That reinforces the already-decided fixed helper vocabulary and
  environment/path independence; the policy file cannot replace helper-side
  argument and filesystem validation. [official `pkexec(1)`, “Security Notes”](https://polkit.pages.freedesktop.org/polkit/pkexec.1.html)
- `auth_admin` requires administrator authentication. `auth_admin_keep` is a
  different mode that retains authorization briefly, and retained checks may
  later succeed even when action variables differ. The prior ticket's choice of
  plain `auth_admin` on every call avoids that retained state. [official
  `polkit(8)`, authorization defaults](https://polkit.pages.freedesktop.org/polkit/polkit.8.html)
- `pkexec` returns the helper's status after successful launch, `126` when the
  user dismisses authentication, and `127` when authorization cannot be obtained
  or another authorization/execution error occurs. A lifecycle/UI caller can
  distinguish explicit cancellation from a helper result only by preserving
  those semantics in its own result model. [official `pkexec(1)`, “Return
  Value”](https://polkit.pages.freedesktop.org/polkit/pkexec.1.html)
- Quattro ships `omarchy.polkit` as an implicitly enabled first-party service.
  Its `PolkitAgent` registers inside the long-lived shell and handles success,
  cancellation, and failure flows. A graphical Hibermachy `pkexec` call can use
  that session agent; `pkexec` also has a textual fallback when no session agent
  is available. [manifest](</usr/share/omarchy/shell/plugins/polkit/manifest.json>)
  [agent registration, lines
  176-218](</usr/share/omarchy/shell/plugins/polkit/PolkitAgent.qml>) [official
  `pkexec(1)`, “Authentication Agent”](https://polkit.pages.freedesktop.org/polkit/pkexec.1.html)

### Arch install, update, and removal hooks

- An Arch package may include package-specific `pre_install`, `post_install`,
  `pre_upgrade`, `post_upgrade`, `pre_remove`, and `post_remove` functions.
  `pre_remove` runs before package files are removed, so the packaged helper is
  still present at that point and can perform its validated reset directly in
  the already-privileged package transaction. During an upgrade, install/remove
  callbacks are not run; only upgrade callbacks run. [official
  `PKGBUILD(5)`, “Install/Upgrade/Remove Scripting”](https://man.archlinux.org/man/PKGBUILD.5.en.html)
- Therefore a helper package can preserve the owned sleep drop-in across normal
  upgrades while making reset-before-binary-removal part of normal package
  removal. The reset must not be in `post_remove`, when the helper file has
  already gone. This is a direct consequence of the documented callback order.
- Pacman supports `--noscriptlet`, and package database operations can also be
  performed with `--dbonly`. An administrator can thus bypass any package
  cleanup callback. Package hooks provide the normal lifecycle, not an absolute
  guarantee against deliberate low-level package-manager overrides. [installed
  `pacman(8)`, transaction options](</usr/share/man/man8/pacman.8.gz>)
- Files listed in a PKGBUILD's `backup=()` receive configuration-preservation
  handling and may remain as `.pacsave` on removal. The helper-generated
  `/etc/systemd/sleep.conf.d/90-hibermachy.conf` is runtime policy, not a static
  helper-package payload, so making it a package backup file would introduce a
  second, pacman-owned persistence behavior. [official `PKGBUILD(5)`, `backup`](https://man.archlinux.org/man/PKGBUILD.5.en.html)
  [installed `pacman(8)`, “Handling Config Files”](</usr/share/man/man8/pacman.8.gz>)
- If the helper is published as a normal repository package, the native
  `pacman -Syu` phase of `omarchy update` updates it. If it is an installed AUR
  package, Quattro separately runs `yay -Sua` when the AUR is reachable. Neither
  path updates the Git plugin checkout or shared menu file. [native update,
  lines 16-29](</usr/share/omarchy/bin/omarchy-update-system-pkgs>) [AUR update,
  lines 1-13](</usr/share/omarchy/bin/omarchy-update-aur-pkgs>) [overall order,
  lines 41-52](</usr/share/omarchy/bin/omarchy-update>)

## 4. Lifecycle matrix

| Component | Install/activate contract | Update contract | Disable contract | Remove contract |
|---|---|---|---|---|
| Plugin checkout | `omarchy plugin add <url>` clones, validates, rescans; disabled by default | Explicit `omarchy plugin update`; reviewed fast-forward unless `--yes` | Checkout remains; activation entry is removed | `omarchy plugin remove` disables then removes/backs up only checkout |
| QML service + panel | Instantiated in `omarchy-shell` when third-party id is enabled | Enabled source changes destroy/recreate plugin objects | Destroyed immediately with plugin deactivation | Gone when checkout is undiscovered; no separate daemon state |
| Menu contribution | Separate merge into one shared user JSONC file; hot-reloads | Separate preservation-sensitive merge; no plugin updater coverage | Unchanged unless rows self-hide via `when` or are explicitly removed | Explicitly remove only owned ids; plugin remove does nothing here |
| User config/state | Created by Hibermachy service under its XDG paths under prior decisions | Hibermachy's own schema/migration contract | Persists unless product policy says otherwise | No Omarchy ownership; retain/purge is a product choice |
| Helper binary + Polkit action | Separate root package; per-use `pkexec` action binds absolute binary path | Native/AUR package update channel, independent of plugin | No platform coupling to plugin disablement | Normal package `pre_remove` can reset while helper still exists, then package files disappear |
| Owned sleep drop-in | Created only by authenticated helper `apply`, not by plugin enable/install | Preserved until authenticated apply changes it | Remains effective when plugin is disabled | Must be explicitly reset before helper removal; plugin removal cannot touch it |

## 5. Constraints and still-human choices for “Choose the installation and lifecycle model”

These are consequences of the sources, not answers to the HITL ticket:

1. **One repository cannot exercise the whole lifecycle through `omarchy plugin
   add`.** That command intentionally has neither install hooks nor privilege.
   A complete workflow needs at least the normal plugin command plus a separate
   user-space menu operation and a privileged package operation.
2. **Installation and enablement are distinct safety decisions.** The normal
   plugin path supports code review while disabled. Enabling mounts the
   unsandboxed service immediately; installing the helper or menu rows does not
   by itself enable plugin code.
3. **There is no cross-scope rollback primitive.** A lifecycle orchestrator can
   compensate for completed steps, but compensation can itself fail or be
   cancelled. It must report the surviving component/state rather than claim
   atomic success.
4. **Disable is reversible runtime deactivation, not cleanup.** It unloads the
   service/panel while leaving the checkout, menu rows, user intent, helper
   package, and effective system policy unless Hibermachy explicitly performs
   additional steps.
5. **Plugin removal and helper removal have different authority.** Plugin
   removal is user-scoped and cannot silently erase system policy. Helper-package
   removal is the last normal point where an already-privileged `pre_remove`
   callback can call the validated reset before deleting the helper.
6. **Update channels can skew.** Omarchy's Git updater and native/AUR package
   updaters are independent, while menu JSONC has no updater at all. Compatible
   protocol/version probing and fail-closed behavior are needed whether updates
   are orchestrated together or allowed independently.
7. **The menu file cannot be treated as Hibermachy's file.** It is shared user
   state. Install/update/removal must define conflict, preservation, malformed
   file, and ownership-marker behavior. A bad whole-file edit temporarily drops
   every user menu entry, not just Hibermachy's rows.
8. **Residual user data is not settled by any platform contract.** Whether
   uninstall retains configuration/state for reinstall or offers an explicit
   purge remains a HITL product choice. Omarchy plugin removal does neither.
9. **Administrative bypass remains possible.** Pacman can skip scriptlets and a
   root administrator can alter/remove any component. The supported lifecycle
   can be safe and recoverable, but cannot promise cleanup against deliberate
   low-level override.

## Primary sources consulted

- Installed Omarchy 4.0.1 source and documentation:
  `/usr/share/omarchy/shell/README.md`,
  `/usr/share/omarchy/shell/services/PluginRegistry.qml`,
  `/usr/share/omarchy/shell/shell.qml`,
  `/usr/share/omarchy/shell/plugins/menu/Menu.qml`,
  `/usr/share/omarchy/shell/plugins/menu/MenuModel.js`,
  `/usr/share/omarchy/config/omarchy/extensions/omarchy-menu.jsonc`, and the
  relevant `/usr/share/omarchy/bin/omarchy-plugin-*` and update scripts.
- Installed Arch/pacman manuals: `/usr/share/man/man5/PKGBUILD.5.gz`,
  `/usr/share/man/man5/alpm-hooks.5.gz`, and
  `/usr/share/man/man8/pacman.8.gz`.
- [Official Arch `PKGBUILD(5)`](https://man.archlinux.org/man/PKGBUILD.5.en.html)
- [Official Polkit `pkexec(1)`](https://polkit.pages.freedesktop.org/polkit/pkexec.1.html)
- [Official Polkit `polkit(8)`](https://polkit.pages.freedesktop.org/polkit/polkit.8.html)

## Prior project decisions consulted for scope only

- “Place Hibermachy in Super+Space”
- “Map Quattro integration seams”
- “Establish helper security and packaging constraints”
- “Establish the compatibility envelope”
- “Choose the plugin runtime architecture”
- “Choose configuration and state ownership”
- “Choose configuration defaults and validation rules”

Those tracker decisions determine the component shape and already-fixed helper
security rules. They are not used as primary evidence for the platform facts in
this note.
