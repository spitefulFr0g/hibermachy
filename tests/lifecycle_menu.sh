#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
node --input-type=module - "$root/lifecycle/menu.mjs" <<'EOF'
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
const { reconcileMenu, removeOwnedMenu, inspectMenu } = await import(process.argv.at(-1));
const fixture = fs.mkdtempSync(path.join(os.tmpdir(), "hibermachy-menu-"));
const menu = path.join(fixture, ".config", "omarchy", "extensions", "omarchy-menu.jsonc");
fs.mkdirSync(path.dirname(menu), { recursive: true });
assert.equal(reconcileMenu(menu), "reconciled");
// Capture current entries, then exercise each exact previous candidate variant.
const current = JSON.parse(fs.readFileSync(menu, "utf8"));
for (const guard of ["quickshell ipc call dev.hibermachy status >/dev/null 2>&1", "omarchy-shell dev.hibermachy status >/dev/null 2>&1"]) {
  const previous = Object.fromEntries(Object.entries(current).map(([id, value]) => {
    const { icon, ...entry } = value;
    return [id, { ...entry, label: id === "system.hibermachy-staged-sleep" ? "Suspend then Hibernate" : entry.label, when: guard }];
  }));
  const source = '// retained comment\n' + JSON.stringify({ unrelated: { label: "Keep" }, ...previous });
  fs.writeFileSync(menu, source);
  assert.equal(inspectMenu(menu).state, "compatible");
  assert.equal(reconcileMenu(menu), "reconciled");
  assert.ok(fs.readFileSync(menu, "utf8").startsWith('// retained comment\n'));
  assert.deepEqual(JSON.parse(fs.readFileSync(menu, "utf8").split('\n').slice(1).join('\n')), { unrelated: { label: "Keep" }, ...current });
  assert.equal(reconcileMenu(menu), "unchanged");
  fs.writeFileSync(menu, source);
  assert.equal(removeOwnedMenu(menu), "removed");
  assert.equal(inspectMenu(menu).state, "missing");
  previous["setup.hibermachy"].action = "custom-command";
  fs.writeFileSync(menu, JSON.stringify(previous));
  assert.throws(() => reconcileMenu(menu), /HBR-MENU-MANAGED-MODIFIED/);
  assert.throws(() => removeOwnedMenu(menu), /HBR-MENU-MANAGED-MODIFIED/);
  assert.equal(fs.readFileSync(menu, "utf8"), JSON.stringify(previous));
}
const previousIcons = structuredClone(current);
previousIcons["system.hibermachy-staged-sleep"].label = "Suspend then Hibernate";
fs.writeFileSync(menu, JSON.stringify(previousIcons));
assert.equal(reconcileMenu(menu), "reconciled");
assert.deepEqual(JSON.parse(fs.readFileSync(menu, "utf8")), current);
assert.equal(current["system.hibermachy-staged-sleep"].label, "Staged Sleep");
fs.writeFileSync(menu, JSON.stringify(current));
assert.equal(removeOwnedMenu(menu), "removed");
fs.unlinkSync(menu);
fs.rmdirSync(path.dirname(menu));
assert.equal(reconcileMenu(menu), "reconciled");
assert.equal(removeOwnedMenu(menu), "removed");
const unrelated = `  "unrelated.before": {\n    "label": "Before // literal", /* keep inline */\n    "action": "printf '{\\"nested\\":true}'"\n  },\n  // Keep this multiline unrelated row exactly where it is.\n  "unrelated.after": {"label":"After","when":"test"}`;
fs.writeFileSync(menu, `// The surrounding comments must survive.\n{\n${unrelated}\n}\n`);
assert.equal(reconcileMenu(menu), "reconciled");
let rendered = fs.readFileSync(menu, "utf8");
assert.ok(rendered.includes(unrelated));
assert.ok(rendered.includes("// The surrounding comments must survive."));
assert.equal(reconcileMenu(menu), "unchanged");
assert.equal(removeOwnedMenu(menu), "removed");
rendered = fs.readFileSync(menu, "utf8");
assert.ok(rendered.includes(unrelated));
assert.ok(!rendered.includes("setup.hibermachy"));
assert.ok(!rendered.includes("system.hibermachy-staged-sleep"));

fs.writeFileSync(menu, '{"setup.hibermachy":{"managedBy":"hibermachy","label":"Edited"}}\n');
assert.throws(() => reconcileMenu(menu), /HBR-MENU-MANAGED-MODIFIED/);
assert.throws(() => removeOwnedMenu(menu), /HBR-MENU-MANAGED-MODIFIED/);

fs.writeFileSync(menu, '{"unrelated":{"label":"safe"}}\n');
const peer = path.join(fixture, "menu-hardlink");
fs.linkSync(menu, peer);
assert.throws(() => reconcileMenu(menu), /HBR-MENU-INACCESSIBLE/);
fs.unlinkSync(peer);

fs.rmSync(path.join(fixture, ".config"), { recursive: true });
const external = path.join(fixture, "external");
fs.mkdirSync(path.join(external, "omarchy", "extensions"), { recursive: true });
fs.writeFileSync(path.join(external, "omarchy", "extensions", "omarchy-menu.jsonc"), '{"unrelated":{}}\n');
fs.symlinkSync(external, path.join(fixture, ".config"));
assert.throws(() => reconcileMenu(menu), /HBR-MENU-INACCESSIBLE/);
fs.rmSync(fixture, { recursive: true, force: true });
EOF
printf '%s\n' 'HBR-CHK-LIFECYCLE-MENU-001 JSONC lexical preservation, managed-row refusal, parent symlink, and hard-link-safe atomic writes'
