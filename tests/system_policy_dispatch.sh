#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)

node - "$root" <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const source = fs.readFileSync(path.join(process.argv[2], "plugin/Service.qml"), "utf8");
const marker = "function applySystemPolicy(): string {";
const start = source.indexOf(marker);
assert.notEqual(start, -1, "applySystemPolicy must remain available");
const open = source.indexOf("{", start);
let depth = 0;
let close = -1;
for (let index = open; index < source.length; index += 1) {
  if (source[index] === "{") depth += 1;
  if (source[index] === "}" && --depth === 0) { close = index; break; }
}
assert.notEqual(close, -1, "applySystemPolicy body must be balanced");
const apply = new Function("context", `with (context) { ${source.slice(open + 1, close)} }`);

function context(testMode) {
  return {
    testMode,
    systemPolicyFixture: { authorization: "unavailable" },
    systemPolicyBusy: false,
    systemPolicyDraft: { hibernateDelaySeconds: 7200, hibernateOnAcPower: false, scope: "machine-wide" },
    helperLauncherPath: "/fixture/authenticator",
    helperPath: "/fixture/policy-helper",
    helperProcess: { command: [], running: false },
    contractReadiness: () => "ready",
    contractReasonCode: () => "HBR-CONTRACT-INCOMPATIBLE-SYSTEM-POLICY",
    validSystemPolicy: () => true,
    policyReceipt: (accepted, reasonCode, details = {}) => ({ accepted, reasonCode, ...details })
  };
}

const production = context(false);
assert.deepEqual(apply(production), {
  accepted: true,
  reasonCode: "HBR-SYSTEM-POLICY-SUBMITTED",
  pair: { hibernateDelaySeconds: 7200, hibernateOnAcPower: false, scope: "machine-wide" }
});
assert.equal(production.helperProcess.running, true);
assert.deepEqual(production.helperProcess.command, [
  "/fixture/authenticator", "/fixture/policy-helper", "apply", "7200", "no"
]);

const fixture = context(true);
assert.deepEqual(apply(fixture), { accepted: false, reasonCode: "HBR-SYSTEM-POLICY-UNAVAILABLE" });
assert.equal(fixture.helperProcess.running, false);
assert.deepEqual(fixture.helperProcess.command, []);
NODE

printf '%s\n' 'HBR-CHK-SYSTEM-POLICY-DISPATCH-001 production ignores fixture outcomes and submits only the authenticated helper request'
