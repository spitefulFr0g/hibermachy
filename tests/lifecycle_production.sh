#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "${fixture:?}"' EXIT
fixture_home="$fixture/home"; bin="$fixture/bin"; remote="$fixture/remote"; recipe="$fixture/recipe"; release="$fixture/release"
plugin="$fixture_home/.config/omarchy/plugins/dev.hibermachy"
mkdir -p "$fixture_home/.config/omarchy/extensions" "$bin" "$remote" "$recipe" "$release"
printf '{}\n' > "$fixture_home/.config/omarchy/extensions/omarchy-menu.jsonc"
printf '{"plugins":[]}\n' > "$fixture_home/.config/omarchy/shell.json"
gitc() { git -c user.name=fixture -c user.email=fixture@example.invalid -c init.defaultBranch=main "$@"; }

# The release is the working tree's tracked files, published the same way as a
# real release: a tag, a deterministic archive, and a recipe with its checksums.
version=$(jq -r .version "$root/manifest.json")
(cd "$root" && git ls-files -z --cached --others --exclude-standard | while IFS= read -r -d '' file; do
  [[ -e $file || -L $file ]] && printf '%s\0' "$file"
done | tar --null -T - -cf -) | tar -xf - -C "$remote"
gitc -C "$remote" init -q && gitc -C "$remote" add -A && gitc -C "$remote" commit -qm release && gitc -C "$remote" tag "v$version"
archive="$release/hibermachy-helper-$version.tar.gz"
git -C "$remote" archive --format=tar --prefix="hibermachy-helper-$version/" "v$version" | gzip -n -9 > "$archive"
tar -xzf "$archive" -C "$fixture"
bootstrap="$fixture/hibermachy-helper-$version"
release_tree=$(git -C "$remote" rev-parse "v$version^{tree}")
key=0B1C5414F8D18F8B6AA78957335FEBC82DB247EC
write_recipe() { # directory archive key
  mkdir -p "$1"; cp "$root/packaging/hibermachy-helper.install" "$1/"
  sed -e "s/__RELEASE_SHA512__/$(sha512sum "$2" | cut -d' ' -f1)/" -e "s/__RELEASE_SIGNATURE_SHA512__/$(printf sig | sha512sum | cut -d' ' -f1)/" \
    -e "s/__RELEASE_SIGNING_KEY__/$3/" "$root/packaging/PKGBUILD" > "$1/PKGBUILD"
}
write_recipe "$recipe" "$archive" "$key"

cat > "$bin/omarchy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$HIBERMACHY_LIFECYCLE_HOME/commands"
plugins="$HIBERMACHY_LIFECYCLE_HOME/.config/omarchy/plugins"
case "$2" in
 enable) printf '{"plugins":[{"id":"dev.hibermachy"}]}\n' > "$HIBERMACHY_LIFECYCLE_HOME/.config/omarchy/shell.json";;
 disable) printf '{"plugins":[]}\n' > "$HIBERMACHY_LIFECYCLE_HOME/.config/omarchy/shell.json";;
 add) [[ $3 == https://github.com/spitefulFr0g/hibermachy.git && $4 == --yes ]]; mkdir -p "$plugins"; git clone -q "$HBR_FIXTURE_REMOTE" "$plugins/dev.hibermachy";;
 remove) rm -rf "$plugins/dev.hibermachy";;
esac
EOF
cat > "$bin/makepkg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'build-cwd %s\n' "$PWD" >> "$HIBERMACHY_LIFECYCLE_HOME/commands"
printf 'makepkg %s\n' "$*" >> "$HIBERMACHY_LIFECYCLE_HOME/commands"
[[ $SRCDEST == "$PWD" && -f PKGBUILD && -f hibermachy-helper.install ]]
if [[ $1 == --verifysource ]]; then cp "$HBR_RELEASE_ARCHIVE" "$SRCDEST/"; exit 0; fi
# Like makepkg, a failed build() leaves pkg/ without read or write permission.
if [[ ${HBR_FAIL_MAKEPKG:-0} == 1 ]]; then mkdir -p pkg/hibermachy-helper; chmod 111 pkg; exit 1; fi
cat > "$HIBERMACHY_LIFECYCLE_COMMAND_DIR/hibermachy-policy-helper" <<'HELPER'
#!/usr/bin/env bash
printf 'release=0.1.0 protocol-min=1 protocol-max=1\n'
HELPER
chmod 755 "$HIBERMACHY_LIFECYCLE_COMMAND_DIR/hibermachy-policy-helper"
touch "$HIBERMACHY_LIFECYCLE_HOME/package-installed"
EOF
chmod +x "$bin/omarchy" "$bin/makepkg"
ln -s /usr/bin/node "$bin/node"
ln -s /usr/bin/python3 "$bin/python3"
ln -s "$(command -v git)" "$bin/git"
ln -s "$(command -v tar)" "$bin/tar"
# Generated script expands these variables when invoked.
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\nprintf "auth-launch %%s\\n" "$*" >> "$HIBERMACHY_LIFECYCLE_HOME/commands"\nif [[ $1 == "/usr/bin/pacman" && $2 == -Rns && $3 == hibermachy-helper ]]; then\n  [[ ${HBR_PACKAGE_REMOVE_FAIL:-0} != 1 ]] || exit 1\n  rm -f "'"$fixture_home"'/package-installed"\n  [[ ${HBR_LEAVE_HELPER:-0} == 1 ]] || rm -f "'"$bin"'/hibermachy-policy-helper"\nfi\n' > "$bin/sudo"
cat > "$bin/pacman" <<EOF
#!/usr/bin/env bash
if [[ \$1 == -Q && \$2 == hibermachy-helper ]]; then
  [[ ! -e "$fixture_home/package-query-fail" ]] || exit 2
  [[ -e "$fixture_home/package-installed" ]] && exit 0
  exit 1
fi
exit 2
EOF
chmod +x "$bin/sudo" "$bin/pacman"
envbase=(HBR_LIFECYCLE_TEST_MODE=1 HIBERMACHY_LIFECYCLE_HOME="${fixture_home}" HIBERMACHY_LIFECYCLE_POLICY="$fixture_home/absent-system-policy.conf" HIBERMACHY_LIFECYCLE_COMMAND_DIR="$bin" HBR_FIXTURE_REMOTE="$remote" HBR_RELEASE_ARCHIVE="$archive")
lifecycle() { env "${envbase[@]}" "$bootstrap/lifecycle/install" "$@"; }
refused() { # expected-reason command...
  local expected=$1 output code; shift
  set +e; output=$("$@" 2>&1); code=$?; set -e
  [[ $code -ne 0 ]] && jq -se --arg reason "$expected" 'map(select(.kind == "refused")) | .[-1].reasonCode == $reason' <<<"$output" >/dev/null || {
    printf 'expected %s, got:\n%s\n' "$expected" "$output" >&2; exit 1; }
}
cached_builds() { find "$fixture_home/.cache/hibermachy" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l; }

# Setup refuses anything but a signed, version-matched release recipe before it
# clones, fetches, or builds anything.
refused HBR-RELEASE-RECIPE-REQUIRED lifecycle setup
refused HBR-RELEASE-RECIPE-REQUIRED lifecycle setup --recipe recipe
refused HBR-HELPER-IMMUTABLE-RELEASE-REQUIRED lifecycle setup --recipe "$root/packaging"
write_recipe "$fixture/wrong-key" "$archive" 0000000000000000000000000000000000000000
refused HBR-RELEASE-SIGNING-KEY-MISMATCH lifecycle setup --recipe "$fixture/wrong-key"
sed "s/^pkgver=.*/pkgver=9.9.9/" "$recipe/PKGBUILD" > "$fixture/PKGBUILD.other"; mkdir -p "$fixture/other-version"
cp "$fixture/PKGBUILD.other" "$fixture/other-version/PKGBUILD"; cp "$recipe/hibermachy-helper.install" "$fixture/other-version/"
refused HBR-RELEASE-VERSION-MISMATCH lifecycle setup --recipe "$fixture/other-version"
[[ ! -e "$fixture_home/commands" && ! -e "$plugin" ]]
# rustup can provide cargo without a default toolchain; refuse before adding anything.
printf '#!/usr/bin/env bash\nexit 1\n' > "$bin/cargo"; chmod +x "$bin/cargo"
refused HBR-BUILD-TOOLCHAIN-NOT-READY lifecycle setup --recipe "$recipe"
[[ ! -e "$fixture_home/commands" && ! -e "$plugin" ]]
rm "$bin/cargo"

# A substituted archive, or a bootstrap which differs from the signed archive,
# stops before the checkout is added or anything is installed.
mkdir -p "$fixture/tampered"; printf 'tampered' | gzip -n > "$fixture/tampered/hibermachy-helper-$version.tar.gz"
refused HBR-RELEASE-ARCHIVE-UNVERIFIED env "${envbase[@]}" HBR_RELEASE_ARCHIVE="$fixture/tampered/hibermachy-helper-$version.tar.gz" "$bootstrap/lifecycle/install" setup --recipe "$recipe"
cp -a "$bootstrap" "$fixture/modified-bootstrap"; printf 'modified\n' >> "$fixture/modified-bootstrap/README.md"
refused HBR-RELEASE-BOOTSTRAP-MISMATCH env "${envbase[@]}" "$fixture/modified-bootstrap/lifecycle/install" setup --recipe "$recipe"
[[ ! -e "$plugin" && ! -e "$fixture_home/package-installed" && $(cached_builds) -eq 0 ]]
if grep -q -- '--install' "$fixture_home/commands"; then exit 1; fi

# A release tag whose tree differs from the signed archive is never checked out.
git clone -q "$remote" "$fixture/moved-remote"; printf 'moved\n' > "$fixture/moved-remote/moved"
gitc -C "$fixture/moved-remote" add moved && gitc -C "$fixture/moved-remote" commit -qm moved && gitc -C "$fixture/moved-remote" tag -f "v$version" >/dev/null
refused HBR-CHECKOUT-RELEASE-MISMATCH env "${envbase[@]}" HBR_FIXTURE_REMOTE="$fixture/moved-remote" "$bootstrap/lifecycle/install" setup --recipe "$recipe"
git -C "$plugin" symbolic-ref -q HEAD >/dev/null
[[ ! -e "$fixture_home/package-installed" ]]
rm -rf "$plugin"; : > "$fixture_home/commands"

# The default branch moves past the release; setup still installs the tag.
printf 'unreleased\n' > "$remote/unreleased"; gitc -C "$remote" add unreleased && gitc -C "$remote" commit -qm unreleased
setup=$(lifecycle setup --recipe "$recipe")
jq -e --arg tag "v$version" '.kind == "accepted" and .activation == "disabled" and .release == $tag' <<<"$setup" >/dev/null
grep -qx 'plugin add https://github.com/spitefulFr0g/hibermachy.git --yes' "$fixture_home/commands"
if grep -q '^plugin enable' "$fixture_home/commands"; then exit 1; fi
[[ $(git -C "$plugin" rev-parse 'HEAD^{tree}') == "$release_tree" && ! -e "$plugin/unreleased" && -z $(git -C "$plugin" status --porcelain) ]]
if git -C "$plugin" symbolic-ref -q HEAD >/dev/null; then exit 1; fi
grep -q "^build-cwd $fixture_home/.cache/hibermachy/release-" "$fixture_home/commands"
grep -qx 'makepkg --verifysource' "$fixture_home/commands"; grep -qx 'makepkg --syncdeps --install --cleanbuild' "$fixture_home/commands"
[[ $(cached_builds) -eq 0 ]]
# Without a user shell.json Quattro enables no community plugin, so setup can be
# retried over the existing checkout (for example after a failed package build).
rm "$fixture_home/.config/omarchy/shell.json"
jq -e '.kind == "accepted" and .activation == "disabled"' <<<"$(lifecycle setup --recipe "$recipe")" >/dev/null
[[ $(git -C "$plugin" rev-parse 'HEAD^{tree}') == "$release_tree" && ! -e "$fixture_home/.config/omarchy/shell.json" ]]
lifecycle activate --confirm >/dev/null
refused HBR-SETUP-PLUGIN-ACTIVE lifecycle setup --recipe "$recipe"
printf '%s\n' 'HBR-CHK-LIFECYCLE-PRODUCTION-004 setup installs only a signed, tag-pinned release and builds outside the checkout'

update=$(lifecycle update --recipe "$recipe"); jq -e '.activation == "enabled"' <<<"$update" >/dev/null
[[ $(git -C "$plugin" rev-parse 'HEAD^{tree}') == "$release_tree" ]]
set +e; failed=$(env HBR_FAIL_MAKEPKG=1 "${envbase[@]}" "$bootstrap/lifecycle/install" update --recipe "$recipe" 2>&1); code=$?; set -e; [[ $code -ne 0 ]]; grep -q HBR-LIFECYCLE-MAKEPKG-FAILED <<<"$failed"
jq -e '.plugins | length == 0' "$fixture_home/.config/omarchy/shell.json" > /dev/null
jq -e '.previousActivation == true' "$fixture_home/.local/state/hibermachy/lifecycle-update.json" > /dev/null
[[ $(cached_builds) -eq 0 ]]
touch "$plugin/local-change"
refused HBR-CHECKOUT-DIRTY lifecycle update --recipe "$recipe"
refused HBR-UPDATE-RELEASE-BOOTSTRAP-REQUIRED lifecycle complete-update
rm "$plugin/local-change"
recovered=$(lifecycle update --recipe "$recipe")
jq -e '.activation == "enabled"' <<< "$recovered" > /dev/null
[[ ! -e "$fixture_home/.local/state/hibermachy/lifecycle-update.json" ]]
mkdir -p "${fixture_home}/.config/hibermachy" "${fixture_home}/.local/state/hibermachy"; touch "${fixture_home}/.config/hibermachy/user-policy.json" "${fixture_home}/.local/state/hibermachy/outcomes.json"
set +e; declined=$(lifecycle purge 2>&1); code=$?; set -e; [[ $code -eq 0 ]]; grep -q HBR-PURGE-CONFIRMATION-REQUIRED <<<"$declined"; [[ -e "${fixture_home}/.config/hibermachy/user-policy.json" ]]
printf '%s\n' 'HBR-CHK-LIFECYCLE-PRODUCTION-001 same production adapter setup/update failure/activation/purge confirmation'
# Purge refuses a substituted directory and leaves the referenced data intact.
mv "$fixture_home/.config/hibermachy" "$fixture_home/retained"
ln -s "$fixture_home/retained" "$fixture_home/.config/hibermachy"
if env "${envbase[@]}" "$bootstrap/lifecycle/install" purge --confirm-purge > "$fixture_home/purge-result" 2>&1; then
  printf '%s\n' 'unsafe purge unexpectedly succeeded' >&2
  exit 1
fi
rg -q 'HBR-PURGE-UNSAFE-PATH' "$fixture_home/purge-result"
[[ -e "$fixture_home/retained/user-policy.json" ]]
unlink "$fixture_home/.config/hibermachy"
mv "$fixture_home/retained" "$fixture_home/.config/hibermachy"
env "${envbase[@]}" "$bootstrap/lifecycle/install" purge --confirm-purge > /dev/null
[[ ! -e "$fixture_home/.config/hibermachy" && ! -e "$fixture_home/.local/state/hibermachy" ]]
printf '%s\n' 'HBR-CHK-LIFECYCLE-PRODUCTION-002 purge refuses symlinks and removes confirmed owned data last'

# Package removal is conditional on a read-only installed-state query, and
# uninstall remains successful after its checkout/helper/package are absent.
lifecycle setup --recipe "$recipe" >/dev/null
touch "$fixture_home/package-installed"
cat > "$bin/hibermachy-policy-helper" <<'EOF'
#!/usr/bin/env bash
[[ $1 == probe ]] && printf '%s\n' 'release=0.1.0 protocol-min=1 protocol-max=1'
EOF
chmod +x "$bin/hibermachy-policy-helper"
first_uninstall=$(env "${envbase[@]}" "$bootstrap/lifecycle/install" uninstall)
jq -e '.kind == "accepted" and .operation == "uninstall"' <<<"$first_uninstall" >/dev/null
[[ ! -e "$fixture_home/package-installed" && ! -e "$bin/hibermachy-policy-helper" ]]
rerun_uninstall=$(env "${envbase[@]}" "$bootstrap/lifecycle/install" uninstall)
jq -e '.kind == "accepted" and .operation == "uninstall"' <<<"$rerun_uninstall" >/dev/null

# A leftover executable or an indeterminate package query blocks menu/checkout
# removal, preserving the remaining scopes for explicit recovery.
lifecycle setup --recipe "$recipe" >/dev/null
touch "$fixture_home/package-installed"
cp "$root/plugin/bin/hibermachy-contract-probe" "$bin/hibermachy-policy-helper"
chmod +x "$bin/hibermachy-policy-helper"
set +e
leftover=$(env HBR_LEAVE_HELPER=1 "${envbase[@]}" "$bootstrap/lifecycle/install" uninstall 2>&1); code=$?
set -e
[[ $code -ne 0 && $leftover == *HBR-HELPER-ABSENCE-INDETERMINATE* ]]
[[ -d "$fixture_home/.config/omarchy/plugins/dev.hibermachy" && -e "$bin/hibermachy-policy-helper" ]]
touch "$fixture_home/package-query-fail"
set +e
query_failure=$(env "${envbase[@]}" "$bootstrap/lifecycle/install" uninstall 2>&1); code=$?
set -e
[[ $code -ne 0 && $query_failure == *HBR-PACKAGE-QUERY-FAILED* ]]
[[ -d "$fixture_home/.config/omarchy/plugins/dev.hibermachy" ]]
printf '%s\n' 'HBR-CHK-LIFECYCLE-PRODUCTION-003 package query/removal absence proof and rerunnable uninstall'
