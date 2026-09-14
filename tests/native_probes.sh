#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)

node - "$root" <<'NODE'
const assert = require("assert");
const path = require("path");
const root = process.argv[2];
const probe = require(path.join(root, "plugin/bin/native-probe-lib.cjs"));

const files = {
  [path.join(root, "plugin/manifest.json")]: JSON.stringify({ schemaVersion: 1, id: "dev.hibermachy", protocol: {min:1,max:1}, kinds: ["service", "panel"], entryPoints: { service: "Service.qml", panel: "Panel.qml" } }),
  [path.join(root, "plugin/Service.qml")]: "import Quickshell.Io\nimport Quickshell.Wayland\nIpcHandler\nProcess\npolicyPath\nFileView\nloadUserPolicy\nhelperPath\neffectivePolicyReaderPath\nsystemPolicyMatches\n",
  [path.join(root, "plugin/Panel.qml")]: "Item {}",
  "/usr/share/omarchy/shell/services/PluginRegistry.qml": "scan_thirdparty manifest.json registry.pluginsDir function setEnabled function rescan installedPlugins",
  "/usr/share/omarchy/shell/plugins/services/idle/manifest.json": JSON.stringify({ id: "omarchy.idle", entryPoints: { service: "Service.qml" } }),
  "/usr/share/omarchy/shell/plugins/services/idle/Service.qml": "IdleMonitor respectInhibitors",
  "/proc/sys/kernel/random/boot_id": "01234567-89ab-cdef-0123-456789abcdef\n"
};

function read(file) {
  if (!(file in files)) throw new Error("missing " + file);
  return files[file];
}

function response(stdout, status = 0) { return { status, stdout, stderr: "" }; }
function run(command, args) {
  const tail = args.join(" ");
  if (command === probe.QUICKSHELL && tail.endsWith("shell ping")) return response("ok\n");
  if (command === probe.QUICKSHELL && tail.endsWith("shell listPlugins")) return response(JSON.stringify([{ id: "dev.hibermachy", enabled: true, active: true }]));
  if (command === probe.HELPER) return response("release=0.1.0 protocol-min=1 protocol-max=1\n");
  if (command === probe.PACMAN && args.join(" ") === "-Q omarchy") return response("omarchy 4.0.3-1\n");
  if (command === probe.BUSCTL && args.includes("CanSuspend")) return response('{"type":"s","data":["yes"]}');
  if (command === probe.BUSCTL && args.includes("CanHibernate")) return response('{"type":"s","data":["no"]}');
  if (command === probe.BUSCTL && args.includes("CanSuspendThenHibernate")) return response('{"type":"s","data":["yes"]}');
  if (command === probe.BUSCTL && args.includes("BlockInhibited")) return response('{"type":"s","data":"sleep:shutdown"}');
  throw new Error(command + " " + tail);
}

const adapter = { run, read, pluginRoot: path.join(root, "plugin") };
const contract = probe.evaluateContract(adapter);
assert.equal(contract.compatible, true);
assert.equal(contract.majorVersion, 4);
assert.equal(contract.omarchyVersion, "4.0.3-1");
for (const key of probe.REQUIRED_CONTRACTS) assert.equal(contract[key], true, key);

const missingHelper = probe.evaluateContract({ ...adapter, run(command, args) {
  return command === probe.HELPER ? response("", 1) : run(command, args);
} });
assert.equal(missingHelper.helperProtocol, false);
assert.equal(missingHelper.systemPolicy, false);
assert.equal(missingHelper.compatible, false);

for (const version of ["3.9.9", "5.0.0"]) {
  const result = probe.evaluateContract({ ...adapter, run(command, args) {
    return command === probe.PACMAN ? response(`omarchy ${version}\n`) : run(command, args);
  } });
  assert.notEqual(result.majorVersion, 4);
}

for (const [range, compatible] of [["1 protocol-max=2", true], ["2 protocol-max=3", false], ["2 protocol-max=1", false]]) {
  const result = probe.evaluateContract({ ...adapter, run(command, args) {
    return command === probe.HELPER ? response(`release=0.1.0 protocol-min=${range}\n`) : run(command, args);
  } });
  assert.equal(result.helperProtocol, compatible);
}

const capability = probe.evaluateCapability(adapter);
assert.deepEqual(capability, {
  CanSuspend: "yes", CanHibernate: "no", CanSuspendThenHibernate: "yes",
  BlockInhibited: "sleep:shutdown", BootId: "01234567-89ab-cdef-0123-456789abcdef"
});

const malformedCapability = probe.evaluateCapability({ ...adapter, run(command, args) {
  return command === probe.BUSCTL && args.includes("CanSuspend") ? response('{"type":"s","data":["challenge"]}') : run(command, args);
} });
assert.equal(malformedCapability, null);
NODE

printf '%s\n' 'HBR-CHK-NATIVE-PROBES-001 injected native transport rejects malformed results and fails closed'
