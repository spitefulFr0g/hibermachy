#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"; fixture_home="$(mktemp -d)"; bin="$(mktemp -d)"; recipe="$(mktemp -d)"
trap 'rm -rf "${fixture_home}" "${bin:?}" "${recipe:?}"' EXIT
mkdir -p "${fixture_home}/.config/omarchy/extensions"; printf '{}\n' > "${fixture_home}/.config/omarchy/extensions/omarchy-menu.jsonc"; printf 'sha512sums=(x)\nvalidpgpkeys=(x)\n' > "$recipe/PKGBUILD"
cat > "$bin/omarchy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$HIBERMACHY_LIFECYCLE_HOME/commands"; mkdir -p "$HIBERMACHY_LIFECYCLE_HOME/.config/omarchy/plugins/dev.hibermachy"
case "$2" in
 enable) printf '{"plugins":[{"id":"dev.hibermachy"}]}\n' > "$HIBERMACHY_LIFECYCLE_HOME/.config/omarchy/shell.json";;
 disable) printf '{"plugins":[]}\n' > "$HIBERMACHY_LIFECYCLE_HOME/.config/omarchy/shell.json";;
 add) mkdir -p "$HIBERMACHY_LIFECYCLE_HOME/.config/omarchy/plugins/dev.hibermachy/plugin"
 touch "$HIBERMACHY_LIFECYCLE_HOME/.config/omarchy/plugins/dev.hibermachy/plugin/Service.qml" "$HIBERMACHY_LIFECYCLE_HOME/.config/omarchy/plugins/dev.hibermachy/plugin/Panel.qml"
 cp "$HBR_LIFECYCLE_MANIFEST" "$HIBERMACHY_LIFECYCLE_HOME/.config/omarchy/plugins/dev.hibermachy/manifest.json";; update) [[ ${HBR_FAIL_UPDATE:-0} != 1 ]] || exit 1;; remove) rm -rf "$HIBERMACHY_LIFECYCLE_HOME/.config/omarchy/plugins/dev.hibermachy";; esac
EOF
cat > "$bin/makepkg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'makepkg %s\n' "$*" >> "$HIBERMACHY_LIFECYCLE_HOME/commands"
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
envbase=(HBR_LIFECYCLE_TEST_MODE=1 HIBERMACHY_LIFECYCLE_HOME="${fixture_home}" HIBERMACHY_LIFECYCLE_COMMAND_DIR="$bin" HIBERMACHY_LIFECYCLE_RECIPE_DIR="$recipe" HBR_LIFECYCLE_MANIFEST="$root/manifest.json")
setup=$(env "${envbase[@]}" "$root/lifecycle/install" setup); jq -e '.kind == "accepted" and .activation == "disabled"' <<<"$setup" >/dev/null; grep -qx 'plugin add https://github.com/spitefulFr0g/hibermachy.git' "${fixture_home}/commands"
env "${envbase[@]}" "$root/lifecycle/install" activate --confirm >/dev/null; update=$(env "${envbase[@]}" "$root/lifecycle/install" update); jq -e '.activation == "enabled"' <<<"$update" >/dev/null
set +e; failed=$(env HBR_FAIL_UPDATE=1 "${envbase[@]}" "$root/lifecycle/install" update 2>&1); code=$?; set -e; [[ $code -ne 0 ]]; grep -q HBR-LIFECYCLE-OMARCHY-FAILED <<<"$failed"
jq -e '.plugins | length == 0' "$fixture_home/.config/omarchy/shell.json" > /dev/null
jq -e '.previousActivation == true' "$fixture_home/.local/state/hibermachy/lifecycle-update.json" > /dev/null
recovered=$(env "${envbase[@]}" "$root/lifecycle/install" update)
jq -e '.activation == "enabled"' <<< "$recovered" > /dev/null
[[ ! -e "$fixture_home/.local/state/hibermachy/lifecycle-update.json" ]]
mkdir -p "${fixture_home}/.config/hibermachy" "${fixture_home}/.local/state/hibermachy"; touch "${fixture_home}/.config/hibermachy/user-policy.json" "${fixture_home}/.local/state/hibermachy/outcomes.json"
set +e; declined=$(env "${envbase[@]}" "$root/lifecycle/install" purge 2>&1); code=$?; set -e; [[ $code -eq 0 ]]; grep -q HBR-PURGE-CONFIRMATION-REQUIRED <<<"$declined"; [[ -e "${fixture_home}/.config/hibermachy/user-policy.json" ]]
printf '%s\n' 'HBR-CHK-LIFECYCLE-PRODUCTION-001 same production adapter setup/update failure/activation/purge confirmation'
# Purge refuses a substituted directory and leaves the referenced data intact.
mv "$fixture_home/.config/hibermachy" "$fixture_home/retained"
ln -s "$fixture_home/retained" "$fixture_home/.config/hibermachy"
if env "${envbase[@]}" "$root/lifecycle/install" purge --confirm-purge > "$fixture_home/purge-result" 2>&1; then
  printf '%s\n' 'unsafe purge unexpectedly succeeded' >&2
  exit 1
fi
rg -q 'HBR-PURGE-UNSAFE-PATH' "$fixture_home/purge-result"
[[ -e "$fixture_home/retained/user-policy.json" ]]
unlink "$fixture_home/.config/hibermachy"
mv "$fixture_home/retained" "$fixture_home/.config/hibermachy"
env "${envbase[@]}" "$root/lifecycle/install" purge --confirm-purge > /dev/null
[[ ! -e "$fixture_home/.config/hibermachy" && ! -e "$fixture_home/.local/state/hibermachy" ]]
printf '%s\n' 'HBR-CHK-LIFECYCLE-PRODUCTION-002 purge refuses symlinks and removes confirmed owned data last'

# Package removal is conditional on a read-only installed-state query, and
# uninstall remains successful after its checkout/helper/package are absent.
env "${envbase[@]}" "$root/lifecycle/install" setup >/dev/null
touch "$fixture_home/package-installed"
cat > "$bin/hibermachy-policy-helper" <<'EOF'
#!/usr/bin/env bash
[[ $1 == probe ]] && printf '%s\n' 'release=0.1.0 protocol-min=1 protocol-max=1'
EOF
chmod +x "$bin/hibermachy-policy-helper"
first_uninstall=$(env "${envbase[@]}" "$root/lifecycle/install" uninstall)
jq -e '.kind == "accepted" and .operation == "uninstall"' <<<"$first_uninstall" >/dev/null
[[ ! -e "$fixture_home/package-installed" && ! -e "$bin/hibermachy-policy-helper" ]]
rerun_uninstall=$(env "${envbase[@]}" "$root/lifecycle/install" uninstall)
jq -e '.kind == "accepted" and .operation == "uninstall"' <<<"$rerun_uninstall" >/dev/null

# A leftover executable or an indeterminate package query blocks menu/checkout
# removal, preserving the remaining scopes for explicit recovery.
env "${envbase[@]}" "$root/lifecycle/install" setup >/dev/null
touch "$fixture_home/package-installed"
cp "$root/plugin/bin/hibermachy-contract-probe" "$bin/hibermachy-policy-helper"
chmod +x "$bin/hibermachy-policy-helper"
set +e
leftover=$(env HBR_LEAVE_HELPER=1 "${envbase[@]}" "$root/lifecycle/install" uninstall 2>&1); code=$?
set -e
[[ $code -ne 0 && $leftover == *HBR-HELPER-ABSENCE-INDETERMINATE* ]]
[[ -d "$fixture_home/.config/omarchy/plugins/dev.hibermachy" && -e "$bin/hibermachy-policy-helper" ]]
touch "$fixture_home/package-query-fail"
set +e
query_failure=$(env "${envbase[@]}" "$root/lifecycle/install" uninstall 2>&1); code=$?
set -e
[[ $code -ne 0 && $query_failure == *HBR-PACKAGE-QUERY-FAILED* ]]
[[ -d "$fixture_home/.config/omarchy/plugins/dev.hibermachy" ]]
printf '%s\n' 'HBR-CHK-LIFECYCLE-PRODUCTION-003 package query/removal absence proof and rerunnable uninstall'
