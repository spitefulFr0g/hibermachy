#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)

node - "$root" <<'NODE'
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = process.argv[2];
const source = fs.readFileSync(path.join(root, "plugin/Service.qml"), "utf8");
function qmlBody(sourceText, marker, offset = 0) {
  const start = sourceText.indexOf(marker, offset);
  assert.notEqual(start, -1, marker + " must remain available");
  const open = sourceText.indexOf("{", start);
  let depth = 0;
  let close = -1;
  for (let index = open; index < sourceText.length; index += 1) {
    if (sourceText[index] === "{") depth += 1;
    if (sourceText[index] === "}" && --depth === 0) { close = index; break; }
  }
  assert.notEqual(close, -1, marker + " body must be balanced");
  return sourceText.slice(open + 1, close);
}
const apply = new Function("context", `with (context) { ${qmlBody(source, "function applySystemPolicy(): string {")} }`);
const reset = new Function("context", `with (context) { ${qmlBody(source, "function resetSystemPolicy(): string {")} }`);
const helperStart = source.indexOf("id: helperProcess");
assert.notEqual(helperStart, -1, "helper process must remain available");
const helperExited = new Function("root", "exitCode", qmlBody(source, "onExited: function(exitCode) {", helperStart));
const loadReadback = new Function("context", "text", "exitCode", `with (context) { ${qmlBody(source, "function loadSystemPolicyReadback(text, exitCode) {")} }`);

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
const panelMutationMessage = new Function("reasonCode", qmlBody(panel, "function systemPolicyMutationMessage(reasonCode) {"));
const panelActionMessage = new Function("receiptText", "systemPolicyMutationMessage", qmlBody(panel, "function systemPolicyActionMessage(receiptText) {"));
assert.equal(panelActionMessage(JSON.stringify({ reasonCode: "HBR-SYSTEM-POLICY-AUTH-CANCELLED" }), panelMutationMessage), "Cancelled. No system policy was changed.");
assert.equal(panelActionMessage("not json", panelMutationMessage), "Could not read the system policy request result.");
assert.doesNotMatch(panelActionMessage(JSON.stringify({ reasonCode: "HBR-SYSTEM-POLICY-AUTH-CANCELLED" }), panelMutationMessage), /HBR-/);

const poll = {
  requestedSystemPolicy: { hibernateDelaySeconds: 7200, hibernateOnAcPower: false },
  effectiveSystemPolicy: { hibernateDelaySeconds: 7200, hibernateOnAcPower: false },
  systemPolicyProvenance: [],
  systemPolicyReasonCode: "HBR-SYSTEM-POLICY-APPLIED",
  systemPolicyMutation: "",
  lastSystemPolicyMutationResult: "HBR-SYSTEM-POLICY-AUTH-CANCELLED",
  validSystemPolicy: () => true,
  systemPolicyMatches: () => true,
  requireFreshActivity: () => {}
};
loadReadback(poll, JSON.stringify({ requested: poll.requestedSystemPolicy, effective: poll.effectiveSystemPolicy, provenance: [] }), 0);
assert.equal(poll.systemPolicyReasonCode, "HBR-SYSTEM-POLICY-APPLIED");
assert.equal(poll.lastSystemPolicyMutationResult, "HBR-SYSTEM-POLICY-AUTH-CANCELLED");
assert.match(source, /id: initialPolicyProbe[\s\S]*onExited: function\(exitCode\) \{ root\.loadSystemPolicyReadback\(initialPolicyStdout\.text, exitCode\) \}/);
NODE

printf '%s\n' 'HBR-CHK-SYSTEM-POLICY-DISPATCH-001 reports safe policy-request feedback while preserving live readiness and prior cancellation'
