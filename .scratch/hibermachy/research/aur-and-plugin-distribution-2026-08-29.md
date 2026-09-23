# Omarchy plugin hosting and AUR helper distribution

Date checked: 2026-08-29

## Bottom line

Publish the Quickshell plugin itself as a public GitHub repository and list it in the community directory. Publish the separately root-owned helper as a conventional, stable-release **AUR source package**. Document the two installs as separate trust decisions and make plugin removal explicitly leave the helper package installed unless the user separately removes it.

This follows the public Omarchy ecosystem's actual distribution seam while avoiding a project-operated binary repository before there is enough demand to justify its signing, hosting, and key-management burden. A project-hosted `PKGBUILD` plus release tarball is a reasonable pre-AUR/test route, but it gives up discoverability and automatic update checks.

## 1. Where public shell plugins are hosted

Omarchy's own Quattro manual defines a third-party plugin as a git repository with a root `manifest.json`, shows `omarchy plugin add` with a GitHub URL, and says a public git repository is the distribution mechanism. It directs authors to the independent `omarchyplugins.com` directory for discovery. The same manual says updates fast-forward the installed git checkout; this is plugin source/update distribution, not privileged package distribution. [Omarchy Quattro shell-plugin manual](https://github.com/omacom/omarchy/blob/quattro/manual/32-shell-plugins.md#adding-a-plugin-from-git)

The community directory currently requires a public **GitHub** repository for submission. It also warns that Omarchy's install/update commands follow mutable upstream HEAD and are not bound to the commit the directory reviewed. [Marketplace README](https://github.com/HANCORE-linux/omarchy-plugin-marketplace#submit-a-plugin) [Marketplace submission guide](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/blob/main/SUBMISSION.md)

### Reproducible catalog enumeration

I downloaded the directory's raw `registry.json` on 2026-08-29. SHA-256: `d3b9a7092c222edbb77fb586e3d82f82b2dba0b67865274c55f3a31c3636ff45`.

Commands used:

```sh
jq '.sources | length' registry.json
jq -r '.sources[].repo' registry.json \
  | sed -E 's#https?://([^/]+)/.*#\1#' \
  | sort | uniq -c | sort -nr
jq -r '.sources[].type // "(missing)"' registry.json | sort | uniq -c
```

Result: **1,699 of 1,699 source entries use `github.com`**; 1,697 are labeled `plugin-source` and two are suites. This is a full enumeration of that directory at that time, not a random sample and not proof that no unlisted plugin exists elsewhere. [Raw marketplace registry](https://raw.githubusercontent.com/HANCORE-linux/omarchy-plugin-marketplace/main/registry.json)

Inference: the overwhelming publicly discoverable norm is GitHub-hosted plugin source installed as a user-owned git checkout. Neither the Omarchy plugin protocol nor the directory is a package channel for a root-owned companion. A privileged companion should therefore have a separate distribution and lifecycle.

## 2. Publishing a new AUR source package

### Submission and ownership

- Create an AUR account, add an SSH public key to the account, and use the package base's SSH git repository. For a new package base, the documented flow is `git -c init.defaultBranch=master clone ssh://aur@aur.archlinux.org/pkgbase.git`, followed by commits and a push to `master`. SSH authenticates the submitting account; it does not authenticate upstream release contents. [AUR submission guidelines](https://wiki.archlinux.org/title/AUR_submission_guidelines)
- Search the official repositories and AUR first; do not duplicate an existing package. Choose a unique package base/name that follows Arch naming rules. The normal stable source build uses the unsuffixed name; `-git` denotes a VCS/development build and `-bin` conventionally denotes repackaging prebuilt upstream binaries. The first accepted submission establishes the package and its maintainer; co-maintainers can be added, and disowned/orphaned packages can be adopted. Package requests govern orphaning, deletion, and merges. [AUR submission guidelines](https://wiki.archlinux.org/title/AUR_submission_guidelines)

### Repository contents and release work

- Commit at least `PKGBUILD` and generated `.SRCINFO`, plus only needed auxiliary files such as an install script, service/polkit files, or patches. Do not commit the built `.pkg.tar.zst`. Generate metadata with `makepkg --printsrcinfo > .SRCINFO`; regenerate it whenever relevant `PKGBUILD` metadata changes. The AUR accepts pushes only on `master`. [AUR submission guidelines](https://wiki.archlinux.org/title/AUR_submission_guidelines)
- A source package is a build recipe, not an Arch-vetted binary. Users obtain the build files, review them, run `makepkg` as an unprivileged user, and install the result with pacman. AUR content is unofficial and users are explicitly told to inspect `PKGBUILD`, `.install`, and auxiliary files because they execute code. [Arch User Repository](https://wiki.archlinux.org/title/Arch_User_Repository)
- For every stable helper release, the maintainer must update `pkgver` (and reset/increment `pkgrel` as appropriate), source URLs and dependencies, refresh integrity data, regenerate `.SRCINFO`, test the build (preferably in a clean chroot), commit, and push. Maintainers must also respond to breakage/out-of-date reports and rebuild-sensitive dependency changes. AUR packages remain the user's and maintainer's responsibility rather than Arch's supported repository set. [AUR submission guidelines](https://wiki.archlinux.org/title/AUR_submission_guidelines) [Arch User Repository](https://wiki.archlinux.org/title/Arch_User_Repository)

### Trust, checksums, and signatures

- A `PKGBUILD` checksum verifies that the downloaded source bytes match the recipe; it is not author authentication. Arch recommends the strongest upstream-provided checksum and, when upstream provides detached signatures, including the signature in `source` and pinning the signer fingerprint in `validpgpkeys`. `SKIP` disables integrity checking and is inappropriate for a stable release artifact. [PKGBUILD integrity](https://wiki.archlinux.org/title/PKGBUILD#Integrity)
- AUR SSH proves who pushed the recipe. Users must still review the executable recipe and trust its source URLs. A locally built package is not automatically vouched for by the Arch Linux package-signing web of trust. [Arch User Repository](https://wiki.archlinux.org/title/Arch_User_Repository#Verify_the_PKGBUILD) [Pacman package signing](https://wiki.archlinux.org/title/Pacman/Package_signing)
- For this helper, prefer immutable versioned source archives with a pinned checksum and signed upstream tag/archive if the project can maintain a signing key. Avoid a `-git` package as the primary channel: VCS sources follow moving history and cannot use the same fixed source checksum model. [Arch User Repository FAQ](https://wiki.archlinux.org/title/Arch_User_Repository#What_is_the_difference_between_foo_and_foo-git_packages?)

## 3. Does Omarchy update AUR packages reliably?

Omarchy 4.0.1 does deliberately attempt AUR updates after the native `pacman -Syu` and migrations:

- `/usr/share/omarchy/bin/omarchy-update`, lines 41–52, invokes `omarchy-update-aur-pkgs` late in the update sequence.
- `/usr/share/omarchy/bin/omarchy-update-aur-pkgs`, lines 5–13, checks for foreign packages with `pacman -Qem`, tests AUR reachability, then runs `yay -Sua --noconfirm --cleanafter --ignore gcc14,gcc14-libs`.
- `/usr/share/omarchy/bin/omarchy-update-system-pkgs`, lines 17–26, updates configured pacman repositories with `pacman -Syu`.

Therefore an installed AUR helper is on Omarchy's normal best-effort update path, but **not on a reliable guaranteed path**: the script explicitly skips AUR updates when the AUR is unreachable; an update exists only after its AUR maintainer publishes new metadata; and `yay` still has to fetch and successfully build the recipe against the current system. Arch itself says pacman does not update AUR packages and that users remain responsible. This distinction should be stated in installation docs.

A binary package in a properly configured project pacman repository instead participates in the native `pacman -Syu` phase. A one-off `pacman -U` package with no configured repository has no equivalent update source and should not be described as auto-updating.

## 4. Existing-plugin evidence and its limit

The 2026-08-29 marketplace registry contains no `aur.archlinux.org` URL and no package-distribution record; all 1,699 source repository URLs are GitHub. Its automated security metadata does flag many plugins for package-manager/privilege/installer behavior, but that metadata does not identify a separately maintained AUR package. Thus **I found no registry-level evidence of an existing Omarchy plugin paired with an AUR helper package**.

That is a bounded negative finding, not proof of absence. The registry catalogs plugin source, not companion packages, and this pass did not clone and audit all 1,699 repositories. One current submission illustrates the ecosystem's looser pattern instead: the Pacman plugin documents `yay` as an optional dependency and uses `pkexec` for repository operations, rather than presenting evidence of its own separately packaged helper. [Marketplace issue #1374](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/1374)

## Decision comparison

| Route | Update behavior on Omarchy | Trust and operations | Fit |
|---|---|---|---|
| **AUR stable source package** | Omarchy 4.0.1 attempts it through `yay -Sua`; best effort, not guaranteed | Public executable recipe; local build; pinned checksums/signatures; ongoing AUR maintenance | **Recommended now** for the separate helper |
| Project-hosted signed binary pacman repository | Native `pacman -Syu` when users configure the repository | Project must securely build/sign packages, publish/sign repository databases, distribute/trust/rotate a key, host old/current artifacts, and recover from compromise | Best only after demand justifies repository operations |
| Project-hosted source release + `PKGBUILD`, installed with `makepkg -si` | No automatic discovery/update unless extra tooling is added | Smallest publishing surface; users review/build locally; maintainer still publishes checksums and updates recipe | Good preview/fallback before AUR acceptance, weak long-term lifecycle |

The AUR recommendation is for the **root-owned helper only**. Keep the Quickshell plugin in its GitHub-native channel; do not make plugin add/update/remove silently install, upgrade, or remove the root package.
