#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)

node - "$root" <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = process.argv[2];
const source = fs.readFileSync(path.join(root, "plugin/Service.qml"), "utf8");
function qmlBody(marker, offset = 0) {
  const start = source.indexOf(marker, offset);
  assert.notEqual(start, -1, marker + " must remain available");
  const open = source.indexOf("{", start);
  let depth = 0;
  let close = -1;
  for (let index = open; index < source.length; index += 1) {
    if (source[index] === "{") depth += 1;
    if (source[index] === "}" && --depth === 0) { close = index; break; }
  }
  assert.notEqual(close, -1, marker + " body must be balanced");
  return source.slice(open + 1, close);
}
const apply = new Function("context", `with (context) { ${qmlBody("function applySystemPolicy(): string {")} }`);
const reset = new Function("context", `with (context) { ${qmlBody("function resetSystemPolicy(): string {")} }`);
const helperStart = source.indexOf("id: helperProcess");
assert.notEqual(helperStart, -1, "helper process must remain available");
const helperExited = new Function("root", "exitCode", qmlBody("onExited: function(exitCode) {", helperStart));

function context(testMode) {
  return {
    testMode,
    systemPolicyFixture: { authorization: "unavailable" },
    systemPolicyBusy: false,
    lastSystemPolicyMutationResult: "",
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
assert.equal(fixture.lastSystemPolicyMutationResult, "");

const resetFixture = context(true);
resetFixture.systemPolicyFixture = { authorization: "cancelled" };
resetFixture.requestedSystemPolicy = { hibernateDelaySeconds: 7200, hibernateOnAcPower: false };
resetFixture.effectiveSystemPolicy = { hibernateDelaySeconds: 7200, hibernateOnAcPower: false };
const beforeReset = JSON.stringify([resetFixture.requestedSystemPolicy, resetFixture.effectiveSystemPolicy]);
assert.deepEqual(reset(resetFixture), { accepted: false, reasonCode: "HBR-SYSTEM-POLICY-AUTH-CANCELLED" });
assert.equal(resetFixture.lastSystemPolicyMutationResult, "HBR-SYSTEM-POLICY-AUTH-CANCELLED");
assert.equal(JSON.stringify([resetFixture.requestedSystemPolicy, resetFixture.effectiveSystemPolicy]), beforeReset);

const resetSuccess = context(true);
resetSuccess.systemPolicyFixture = {};
resetSuccess.requestedSystemPolicy = { hibernateDelaySeconds: 7200, hibernateOnAcPower: false };
resetSuccess.effectiveSystemPolicy = { hibernateDelaySeconds: 7200, hibernateOnAcPower: false };
assert.deepEqual(reset(resetSuccess), { accepted: true, reasonCode: "HBR-SYSTEM-POLICY-RESET" });
assert.equal(resetSuccess.lastSystemPolicyMutationResult, "HBR-SYSTEM-POLICY-RESET");

function mutationContext() {
  return {
    testMode: false,
    systemPolicyBusy: true,
    systemPolicyMutation: "apply",
    lastSystemPolicyMutationResult: "HBR-SYSTEM-POLICY-SUBMITTED",
    systemPolicyReasonCode: "HBR-SYSTEM-POLICY-APPLIED",
    requestedSystemPolicy: { hibernateDelaySeconds: 7200, hibernateOnAcPower: false },
    effectiveSystemPolicy: { hibernateDelaySeconds: 7200, hibernateOnAcPower: false }
  };
}
for (const [exitCode, expected] of [[126, "HBR-SYSTEM-POLICY-AUTH-CANCELLED"], [127, "HBR-SYSTEM-POLICY-UNAVAILABLE"], [1, "HBR-SYSTEM-POLICY-WRITE-FAILED"]]) {
  const mutation = mutationContext();
  const policy = JSON.stringify([mutation.requestedSystemPolicy, mutation.effectiveSystemPolicy]);
  helperExited(mutation, exitCode);
  assert.equal(mutation.lastSystemPolicyMutationResult, expected);
  assert.equal(mutation.systemPolicyReasonCode, "HBR-SYSTEM-POLICY-APPLIED");
  assert.equal(mutation.systemPolicyBusy, false);
  assert.equal(mutation.systemPolicyMutation, "");
  assert.equal(JSON.stringify([mutation.requestedSystemPolicy, mutation.effectiveSystemPolicy]), policy);
}

const panel = fs.readFileSync(path.join(root, "plugin/Panel.qml"), "utf8");
assert.match(panel, /Latest system policy request result:/);
assert.match(panel, /statusSnapshot\.lastSystemPolicyMutationResult/);
assert.match(panel, /Cancelled\. No system policy was changed\./);
assert.doesNotMatch(panel, /Latest system policy request result: " \+ \(root\.statusSnapshot\.lastSystemPolicyMutationResult/);
NODE

printf '%s\n' 'HBR-CHK-SYSTEM-POLICY-DISPATCH-001 production ignores fixtures, reports authentication cancellation, and preserves live policy readiness'
