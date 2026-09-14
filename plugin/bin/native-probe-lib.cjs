"use strict";

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const TIMEOUT_MS = 2000;
const BUSCTL = "/usr/bin/busctl";
const QUICKSHELL = "/usr/bin/quickshell";
const HELPER = "/usr/libexec/hibermachy-policy-helper";
const OMARCHY_SHELL = "/usr/share/omarchy/shell";
const PACMAN = "/usr/bin/pacman";
const LOGIN1_DESTINATION = "org.freedesktop.login1";
const LOGIN1_PATH = "/org/freedesktop/login1";
const LOGIN1_INTERFACE = "org.freedesktop.login1.Manager";
const BOOT_ID_PATH = "/proc/sys/kernel/random/boot_id";
const REQUIRED_CONTRACTS = [
  "shellReady", "pluginDiscovery", "pluginActivation", "manifestSchema",
  "ipcFeatures", "qmlFeatures", "idleMonitor", "helperProtocol",
  "userPolicy", "systemPolicy", "logind"
];

function nativeRun(command, args) {
  const child = spawnSync(command, args, {
    encoding: "utf8",
    timeout: TIMEOUT_MS,
    maxBuffer: 65536,
    windowsHide: true
  });
  return {
    status: child.error || child.signal ? 1 : child.status,
    stdout: String(child.stdout || ""),
    stderr: String(child.stderr || "")
  };
}

function nativeRead(file) {
  return fs.readFileSync(file, "utf8");
}

function ok(result) {
  return !!result && result.status === 0;
}

function text(result) {
  return ok(result) ? String(result.stdout || "").trim() : "";
}

function parseJson(textValue) {
  try {
    const value = JSON.parse(String(textValue || ""));
    return value && typeof value === "object" ? value : null;
  } catch (_) {
    return null;
  }
}

function safeRead(read, file) {
  try {
    return String(read(file));
  } catch (_) {
    return "";
  }
}

function validBootId(value) {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(value || "").trim());
}

function validManifest(manifest, pluginRoot, read) {
  if (!manifest || manifest.schemaVersion !== 1 || manifest.id !== "dev.hibermachy") return false;
  if (!Array.isArray(manifest.kinds) || !manifest.kinds.includes("service") || !manifest.kinds.includes("panel")) return false;
  if (!manifest.entryPoints || manifest.entryPoints.service !== "Service.qml" || manifest.entryPoints.panel !== "Panel.qml") return false;
  return safeRead(read, path.join(pluginRoot, "Service.qml")).length > 0
    && safeRead(read, path.join(pluginRoot, "Panel.qml")).length > 0;
}

function includesAll(value, fragments) {
  return fragments.every((fragment) => value.includes(fragment));
}

function helperHasProtocol(result, protocol) {
  if (!ok(result) || !protocol || !Number.isSafeInteger(protocol.min) || !Number.isSafeInteger(protocol.max)
      || protocol.min < 1 || protocol.max < protocol.min) return false;
  const match = text(result).match(/^release=([0-9]+\.[0-9]+\.[0-9]+) protocol-min=([0-9]+) protocol-max=([0-9]+)$/);
  if (!match) return false;
  const minimum = Number(match[2]), maximum = Number(match[3]);
  return Number.isSafeInteger(minimum) && Number.isSafeInteger(maximum) && minimum >= 1 && maximum >= minimum
    && Math.max(minimum, protocol.min) <= Math.min(maximum, protocol.max);
}

function omarchyVersion(result) {
  const match = text(result).match(/^(?:omarchy\s+)?((\d+)\.(\d+)\.(\d+)(?:[-+].*)?)$/);
  return match ? { raw: match[1], major: Number(match[2]) } : null;
}

function evaluateContract(adapter) {
  const run = adapter.run;
  const read = adapter.read;
  const pluginRoot = adapter.pluginRoot || path.resolve(__dirname, "..");
  const manifest = parseJson(safeRead(read, path.join(pluginRoot, "manifest.json")));
  const registry = safeRead(read, path.join(OMARCHY_SHELL, "services", "PluginRegistry.qml"));
  const idleManifest = parseJson(safeRead(read, path.join(OMARCHY_SHELL, "plugins", "services", "idle", "manifest.json")));
  const idleService = safeRead(read, path.join(OMARCHY_SHELL, "plugins", "services", "idle", "Service.qml"));
  const service = safeRead(read, path.join(pluginRoot, "Service.qml"));
  const ping = run(QUICKSHELL, ["ipc", "-p", OMARCHY_SHELL, "call", "shell", "ping"]);
  const listed = run(QUICKSHELL, ["ipc", "-p", OMARCHY_SHELL, "call", "shell", "listPlugins"]);
  const plugins = parseJson(text(listed));
  const ownPlugin = Array.isArray(plugins) ? plugins.find((entry) => entry && entry.id === "dev.hibermachy") : null;
  const helper = run(HELPER, ["probe"]);
  const version = omarchyVersion(run(PACMAN, ["-Q", "omarchy"]));
  // `probe` is the helper's only unprivileged verb. If the package is absent
  // or its protocol is incompatible, both helperProtocol and systemPolicy stay false.
  const helperProtocol = helperHasProtocol(helper, manifest && manifest.protocol);
  const logind = evaluateCapability({ run, read }) !== null;

  const observations = {
    shellReady: text(ping) === "ok",
    pluginDiscovery: includesAll(registry, ["scan_thirdparty", "manifest.json", "registry.pluginsDir"]),
    pluginActivation: !!ownPlugin && ownPlugin.enabled === true && ownPlugin.active === true,
    manifestSchema: validManifest(manifest, pluginRoot, read),
    ipcFeatures: includesAll(registry, ["function setEnabled", "function rescan", "installedPlugins"]),
    qmlFeatures: includesAll(service, ["import Quickshell.Io", "import Quickshell.Wayland", "IpcHandler", "Process"]),
    idleMonitor: !!idleManifest && idleManifest.id === "omarchy.idle" && idleManifest.entryPoints && idleManifest.entryPoints.service === "Service.qml" && includesAll(idleService, ["IdleMonitor", "respectInhibitors"]),
    helperProtocol,
    userPolicy: includesAll(service, ["policyPath", "FileView", "loadUserPolicy"]),
    systemPolicy: helperProtocol && includesAll(service, ["helperPath", "effectivePolicyReaderPath", "systemPolicyMatches"]),
    logind,
    omarchyVersion: !!version
  };
  return {
    compatible: REQUIRED_CONTRACTS.every((key) => observations[key] === true),
    ...observations,
    majorVersion: version ? version.major : null,
    omarchyVersion: version ? version.raw : null,
  };
}

function busctlJson(run, args) {
  const result = run(BUSCTL, ["--json=short", ...args]);
  return ok(result) ? parseJson(result.stdout) : null;
}

function callCan(run, method) {
  const value = busctlJson(run, ["call", LOGIN1_DESTINATION, LOGIN1_PATH, LOGIN1_INTERFACE, method]);
  return value && value.type === "s" && Array.isArray(value.data) && value.data.length === 1
    && (value.data[0] === "yes" || value.data[0] === "no") ? value.data[0] : null;
}

function blockInhibited(run) {
  const value = busctlJson(run, ["get-property", LOGIN1_DESTINATION, LOGIN1_PATH, LOGIN1_INTERFACE, "BlockInhibited"]);
  return value && value.type === "s" && typeof value.data === "string" && /^[A-Za-z0-9:_-]*$/.test(value.data)
    ? value.data : null;
}

function evaluateCapability(adapter) {
  const run = adapter.run;
  const bootId = safeRead(adapter.read, BOOT_ID_PATH).trim();
  const values = {
    CanSuspend: callCan(run, "CanSuspend"),
    CanHibernate: callCan(run, "CanHibernate"),
    CanSuspendThenHibernate: callCan(run, "CanSuspendThenHibernate"),
    BlockInhibited: blockInhibited(run),
    BootId: validBootId(bootId) ? bootId : null
  };
  return Object.values(values).every((value) => value !== null) ? values : null;
}

module.exports = {
  BOOT_ID_PATH,
  BUSCTL,
  HELPER,
  LOGIN1_DESTINATION,
  LOGIN1_INTERFACE,
  LOGIN1_PATH,
  OMARCHY_SHELL,
  PACMAN,
  QUICKSHELL,
  REQUIRED_CONTRACTS,
  evaluateCapability,
  evaluateContract,
  nativeRead,
  nativeRun
};
