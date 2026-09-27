#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
node --input-type=module - "$root/lifecycle/menu.mjs" <<'EOF'
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
const { reconcileMenu, removeOwnedMenu } = await import(process.argv.at(-1));
const fixture = fs.mkdtempSync(path.join(os.tmpdir(), "hibermachy-menu-"));
const menu = path.join(fixture, ".config", "omarchy", "extensions", "omarchy-menu.jsonc");
fs.mkdirSync(path.dirname(menu), { recursive: true });
assert.equal(reconcileMenu(menu), "reconciled");
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
