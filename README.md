# Hibermachy

Hibermachy adds automatic staged sleep to Omarchy: suspend after an idle delay,
then hibernate after a hibernate delay. Manual staged sleep is also available.
It preserves Omarchy's existing idle, locking, and power behavior.

The current release, **v0.1.2**, is an experimental release published on the
[releases page](https://github.com/spitefulFr0g/hibermachy/releases). It changes
installation and updates only; staged-sleep behavior is unchanged from
[v0.1.1](verification/v0.1.1-release.md).

**Physical hibernation is unverified.** The attended hardware qualification is
incomplete: the owner waived the remaining attended cases and all observed
hibernation and same-session resume cycles (0 of 3 ran). Automated checks
simulate sleep and prove nothing about your hardware. Read the
[v0.1.1 verification record](verification/v0.1.1-release.md) before enabling
automatic staged sleep, and keep your work saved. The
[v0.1.0 record](verification/v0.1.0-release.md) covers the first release.

A [retrospective public exposure audit](verification/2026-09-27-public-exposure-audit.md)
found local account and machine metadata in already-public Git history and
release source archives. No credential or private-key exposure was confirmed.
The published v0.1.0 assets have not been replaced. The owner accepted the
remaining public metadata exposure after this limited audit and is not planning
further checks or artifact remediation at this time. Read the audit before
redistributing or installing the release.

Automatic staged sleep honors Stay Awake and idle inhibitors. Manual staged
sleep bypasses those two controls while still honoring system sleep inhibitors.
The panel separates requested system policy, effective system policy, and
operational readiness, and reports the observed lid-close action. Hibermachy
does not configure the laptop lid action or repair platform hibernation support.

System-policy changes require a separately installed, root-owned privileged
policy helper and interactive administrator authorization. The helper cannot
initiate sleep. See the [helper package contract](packaging/README.md).

## Requirements

- Omarchy with the Quattro shell plugin host (`omarchy plugin`) and Quickshell.
  Hibermachy was exercised on Omarchy 4.0.4-1, Quickshell 0.3.1-1 and
  systemd 261.2-1 on one machine; no general compatibility is claimed.
- An x86_64 Arch system whose platform can already hibernate (swap large
  enough for memory, a configured resume device). Hibermachy does not set this
  up.
- `pacman -S --needed base-devel git gnupg rust nodejs python python-gobject polkit`.
  `rust` is only needed to build the helper; `nodejs`, `python` and
  `python-gobject` are runtime dependencies of the plugin.

## Install

Install only from a signed release. Do **not** use the one-line
`omarchy plugin add … --enable` command or `omarchy plugin update`: they
follow the moving default branch, skip signature verification and do not
install the helper. Nothing below pipes a download into a shell or into root.

1. Download and check the release assets:

   ```sh
   version=0.1.2
   mkdir -p ~/hibermachy-release && cd ~/hibermachy-release
   base=https://github.com/spitefulFr0g/hibermachy/releases/download/v$version
   for asset in hibermachy-helper-$version.tar.gz hibermachy-helper-$version.tar.gz.sig \
       hibermachy-helper-$version-recipe.tar.gz hibermachy-release-key.asc SHA256SUMS; do
     curl -fLO "$base/$asset"
   done
   sha256sum --check --ignore-missing SHA256SUMS
   ```

2. Check the signing key. `gpg --show-keys` must print exactly this fingerprint:
   `0B1C 5414 F8D1 8F8B 6AA7  8957 335F EBC8 2DB2 47EC`. Compare it against this
   README on GitHub, not only against the downloaded files. Then import it and
   verify the source signature, which must report a good signature from that key:

   ```sh
   gpg --show-keys --with-fingerprint hibermachy-release-key.asc
   gpg --import hibermachy-release-key.asc
   gpg --verify hibermachy-helper-$version.tar.gz.sig hibermachy-helper-$version.tar.gz
   ```

   `SHA256SUMS` is not signed; the OpenPGP signature is the authoritative check.

3. Extract the signed source and the release recipe, then run setup from the
   extracted source:

   ```sh
   tar -xzf hibermachy-helper-$version.tar.gz
   mkdir recipe && tar -xzf hibermachy-helper-$version-recipe.tar.gz -C recipe
   ./hibermachy-helper-$version/lifecycle/install setup --recipe "$PWD/recipe"
   ```

Setup refuses unless the recipe names the pinned signing key and this version,
and `makepkg` verifies the archive's SHA-512 and signature again. It then
requires that the extracted source you ran and the plugin checkout are the
same files as the signed archive:

- It adds the plugin checkout with `omarchy plugin add --yes`, which never
  enables it.
- It fetches the `v0.1.2` tag, requires its content to match the signed archive,
  and pins the checkout to that tag rather than to the default branch.
- It builds the helper in `~/.cache/hibermachy` and installs it through pacman,
  which asks for your password. The build directory is deleted afterwards.
- It adds the Hibermachy entry to the Omarchy menu.

Setup ends with the plugin **disabled**. It reports every component as JSON;
run `status` any time for the same inventory:

```sh
~/.config/omarchy/plugins/dev.hibermachy/lifecycle/install status
```

You can delete `~/hibermachy-release` after setup.

## Activate

```sh
~/.config/omarchy/plugins/dev.hibermachy/lifecycle/install activate --confirm
```

Activation loads the plugin. Automatic staged sleep stays **off** until you
turn it on in the Hibermachy panel, and a system hibernate delay is applied
only after you confirm it and authorize the helper. Without `--confirm`,
activation is declined and nothing changes.

## Update

Repeat the download, verification and extraction steps for the new version,
then run `update` from the new extracted source:

```sh
./hibermachy-helper-$version/lifecycle/install update --recipe "$PWD/recipe"
```

Update disables the plugin, pins the checkout to the new verified tag, rebuilds
and reinstalls the helper, and re-enables the plugin only if it was enabled
before. If a step fails, the plugin stays disabled and the saved activation is
kept; rerun the same `update` once the cause is fixed and it is restored.

**Updating from v0.1.1:** do not run the `update` command installed with
v0.1.1. It runs `omarchy plugin update`, which moves the checkout to the
default branch, and then refuses with `HBR-UPDATE-RELEASE-BOOTSTRAP-REQUIRED`.
If you already did, run the verified v0.1.2 `update` above; it keeps your saved
activation and re-pins the checkout.

## Disable, remove, uninstall, purge

Run these from `~/.config/omarchy/plugins/dev.hibermachy/lifecycle/install`,
or from an extracted release if the checkout is gone:

| Command | Effect |
| --- | --- |
| `disable` | Unloads the plugin. Everything stays installed. |
| `remove` | Disables and removes the plugin checkout. The helper, system policy and your settings stay. |
| `uninstall` | Disables the plugin, resets the system hibernate policy through the helper, removes the helper package with `pacman -Rns`, removes the Hibermachy menu entry and the checkout. Settings and history in `~/.config/hibermachy` and `~/.local/state/hibermachy` are kept. |
| `purge --confirm-purge` | Uninstall, then delete those settings and history. Without `--confirm-purge` it stops after uninstall. |

Uninstall refuses to reset a system policy file it does not recognize
(`HBR-SYSTEM-POLICY-RESET-REFUSED`) and stops if it cannot confirm that the
policy or package is gone. Rerunning it after a partial failure is safe.

## Recovery

Every command prints JSON. A refusal has `"kind": "refused"` and a
`reasonCode`:

| Reason code | Meaning and fix |
| --- | --- |
| `HBR-RELEASE-RECIPE-REQUIRED`, `HBR-RELEASE-RECIPE-INVALID` | Pass `--recipe` with the absolute path of the extracted release recipe. |
| `HBR-HELPER-IMMUTABLE-RELEASE-REQUIRED` | The recipe still has development placeholders. Use the recipe attached to the release. |
| `HBR-RELEASE-SIGNING-KEY-MISMATCH`, `HBR-RELEASE-VERSION-MISMATCH` | The recipe does not belong to this source or key. Download both from the same release. |
| `HBR-RELEASE-ARCHIVE-UNVERIFIED`, `HBR-RELEASE-BOOTSTRAP-MISMATCH` | The archive or the source you ran differs from the signed release. Download and verify it again. |
| `HBR-CHECKOUT-RELEASE-MISMATCH` | The release tag in the repository does not match the signed archive. Do not install; report it. |
| `HBR-CHECKOUT-DIRTY` | The plugin checkout has local changes. Inspect `git -C ~/.config/omarchy/plugins/dev.hibermachy status`. If nothing there is yours, run `remove` and then `setup` from the verified release, and activate again. |
| `HBR-SETUP-PLUGIN-ACTIVE` | Hibermachy is enabled, or `~/.config/omarchy/shell.json` cannot be read. Use `update` for an enabled plugin; otherwise repair that file. |
| `HBR-CHECKOUT-MISSING` | `update` needs an existing checkout. Run `setup` instead. |
| `HBR-RUNTIME-DEPENDENCIES-NOT-READY` | Install `nodejs`, `python` and `python-gobject`. |
| `HBR-UPDATE-RELEASE-BOOTSTRAP-REQUIRED` | Run `update` from a verified release, as described above. |

The `status` inventory names each component's state and the next step for
anything that is not ready.

## License

[MIT](LICENSE).

Optional hardware workarounds are documented separately:

- [IPTS staged-sleep guard](hardware/iptsd/README.md)
- [Marvell Wi-Fi staged-sleep guard](hardware/mwifiex/README.md)

## Development

`npm run test:candidate` runs the ordinary candidate checks. `npm test` also
runs the hosted Quattro matrix and activity/hardware regressions. The hosted
checks require a usable graphical environment and simulate sleep; physical
hibernation verification is a separate attended procedure. The repository's
`packaging/PKGBUILD` deliberately contains checksum and signing-key
placeholders; release recipes are attached to each release.
