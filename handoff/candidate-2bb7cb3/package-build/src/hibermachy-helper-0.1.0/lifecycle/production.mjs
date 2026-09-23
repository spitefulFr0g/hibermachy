#!/usr/bin/env node
// The fixture implementation remains in the sibling commands behind --root.
// This module is the checkout-local operator path.  Tests inject HOME and a
// command directory, but execute these same calls and filesystem checks.
import fs from "node:fs";
import crypto from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { inspectMenu, reconcileMenu, removeOwnedMenu } from "./menu.mjs";

const command = process.argv[2];
const args = process.argv.slice(3);
const here = path.dirname(fileURLToPath(import.meta.url));
const checkout = path.resolve(here, "..");
const testAdapter = process.env.HBR_LIFECYCLE_TEST_MODE === "1";
if (!testAdapter && (process.env.HIBERMACHY_LIFECYCLE_HOME || process.env.HIBERMACHY_LIFECYCLE_COMMAND_DIR)) throw new Error("HBR-LIFECYCLE-TEST-ADAPTER-DISALLOWED");
const home = (testAdapter && process.env.HIBERMACHY_LIFECYCLE_HOME) || process.env.HOME;
const config = path.join(home, ".config");
const plugin = path.join(config, "omarchy", "plugins", "dev.hibermachy");
const menu = path.join(config, "omarchy", "extensions", "omarchy-menu.jsonc");
const policy = (testAdapter && process.env.HIBERMACHY_LIFECYCLE_POLICY) || "/etc/systemd/sleep.conf.d/90-hibermachy.conf";
const helper = "/usr/libexec/hibermachy-policy-helper";
const bin = (testAdapter && process.env.HIBERMACHY_LIFECYCLE_COMMAND_DIR) || "/usr/bin";
const recipeDirectory = (testAdapter && process.env.HIBERMACHY_LIFECYCLE_RECIPE_DIR) || path.join(checkout, "packaging");
const exe = (name) => path.join(bin, name);
const nodeRuntime = testAdapter ? exe("node") : "/usr/bin/node";
const pythonRuntime = testAdapter ? exe("python3") : "/usr/bin/python3";
const run = (name, argv, cwd) => {
  const result = spawnSync(exe(name), argv, { encoding: "utf8", stdio: "inherit", cwd });
  if (result.error || result.status !== 0) throw new Error(`HBR-LIFECYCLE-${name.toUpperCase()}-FAILED`);
};
const exists = (p) => { try { return fs.lstatSync(p); } catch { return null; } };
const scope = (state, ownership, recovery) => ({ state, ownership, reasonCode: `HBR-LIFECYCLE-${state.toUpperCase()}`, recovery: [recovery] });
function manifestAt(p) {
  try {
    const stat = fs.lstatSync(p);
    if (!stat.isFile() || stat.isSymbolicLink()) return null;
    const manifest = JSON.parse(fs.readFileSync(p, "utf8"));
    const root = path.dirname(p);
    const entries = manifest?.entryPoints;
    if (manifest.id !== "dev.hibermachy" || manifest.schemaVersion !== 1 || !/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(String(manifest.version || "")) || !Array.isArray(manifest.kinds)
      || manifest.kinds.length !== 2 || !manifest.kinds.includes("service") || !manifest.kinds.includes("panel")
      || !entries || Object.keys(entries).length !== 2 || entries.service !== "plugin/Service.qml" || entries.panel !== "plugin/Panel.qml"
      || !manifest.protocol || !Number.isSafeInteger(manifest.protocol.min) || !Number.isSafeInteger(manifest.protocol.max)
      || manifest.protocol.min < 1 || manifest.protocol.max < manifest.protocol.min) return null;
    for (const entry of Object.values(entries)) {
      if (typeof entry !== "string" || path.isAbsolute(entry)) return null;
      const target = path.resolve(root, entry);
      if (!target.startsWith(root + path.sep)) return null;
      const entryStat = fs.lstatSync(target);
      if (!entryStat.isFile() || entryStat.isSymbolicLink()) return null;
    }
    return manifest;
  } catch { return null; }
}
function readOnly(program, argv = []) {
  const runtimeDirectory = `/run/user/${process.getuid()}`;
  const sessionBus = process.env.DBUS_SESSION_BUS_ADDRESS;
  const sessionEnvironment = process.env.XDG_RUNTIME_DIR === runtimeDirectory
    && sessionBus === `unix:path=${runtimeDirectory}/bus`
    ? { XDG_RUNTIME_DIR: runtimeDirectory, DBUS_SESSION_BUS_ADDRESS: sessionBus } : {};
  const result = spawnSync(program, argv, { encoding: "utf8", timeout: 2000, maxBuffer: 65536,
    env: { PATH: "/usr/bin", LC_ALL: "C", ...sessionEnvironment } });
  return { ok: !result.error && result.status === 0, status: result.status,
    stdout: String(result.stdout || ""), error: result.error };
}
function helperPackageStatus() {
  const program = testAdapter ? exe("pacman") : "/usr/bin/pacman";
  const result = readOnly(program, ["-Q", "hibermachy-helper"]);
  if (result.ok) return "installed";
  // pacman uses status 1 only for a package which is not installed.  Every
  // other transport or package-database failure is unsafe to treat as absence.
  if (!result.error && result.status === 1) return "missing";
  return "indeterminate";
}
function installedHelperPath() { return testAdapter ? exe("hibermachy-policy-helper") : helper; }
function helperProtocol(requiredProtocol) {
  const stat = exists(testAdapter ? exe("hibermachy-policy-helper") : helper);
  const program = testAdapter ? exe("hibermachy-policy-helper") : helper;
  if (!stat) return { state: "missing" };
  if (stat.mode & 0o022) return { state: "modified" };
  if (!stat.isFile() || stat.isSymbolicLink() || !(stat.mode & 0o111) || (!testAdapter && (stat.uid !== 0 || stat.nlink !== 1))) return { state: "inaccessible" };
  const result = readOnly(program, ["probe"]);
  const match = result.ok && result.stdout.match(/^release=([0-9]+\.[0-9]+\.[0-9]+) protocol-min=([0-9]+) protocol-max=([0-9]+)\n$/);
  const minimum = match && Number(match[2]), maximum = match && Number(match[3]);
  if (!match || minimum < 1 || maximum < minimum || !requiredProtocol
    || Math.max(minimum, requiredProtocol.min) > Math.min(maximum, requiredProtocol.max)) return { state: "modified" };
  return { state: "compatible", release: match[1], protocolMin: Number(match[2]), protocolMax: Number(match[3]) };
}
function runtimeStat(file) { try { return fs.statSync(file); } catch { return null; } }
function runtimeDependencies() {
  const node = runtimeStat(nodeRuntime), python = runtimeStat(pythonRuntime);
  if (!node || !node.isFile() || !(node.mode & 0o111)
    || !python || !python.isFile() || !(python.mode & 0o111)) return { state: "missing" };
  const nodeVersion = readOnly(nodeRuntime, ["--version"]);
  const pythonVersion = readOnly(pythonRuntime, ["--version"]);
  if (!nodeVersion.ok || !/^v\d+\.\d+\.\d+/.test(nodeVersion.stdout) || !pythonVersion.ok || !/^Python \d+\.\d+\.\d+/.test(pythonVersion.stdout)) return { state: "modified" };
  const gio = readOnly(pythonRuntime, ["-c", "import gi; gi.require_version('Gio', '2.0'); from gi.repository import Gio, GLib"]);
  return gio.ok ? { state: "compatible" } : { state: "incomplete" };
}
function probeJson(program) {
  const result = readOnly(program);
  try { return result.ok ? JSON.parse(result.stdout) : null; } catch { return null; }
}
function validPair(value) {
  return !!value && Number.isSafeInteger(value.hibernateDelaySeconds) && value.hibernateDelaySeconds >= 900
    && value.hibernateDelaySeconds <= 604800 && typeof value.hibernateOnAcPower === "boolean";
}
function validEffectivePair(value) {
  return !!value && Number.isSafeInteger(value.hibernateDelaySeconds) && value.hibernateDelaySeconds >= 0
    && typeof value.hibernateOnAcPower === "boolean";
}
function probeKeyValues(program) {
  const result = readOnly(program);
  const values = {};
  if (!result.ok) return null;
  for (const line of result.stdout.split("\n")) {
    if (!line) continue;
    const match = line.match(/^([A-Za-z][A-Za-z0-9]*)=(.*)$/);
    if (!match || Object.hasOwn(values, match[1])) return null;
    values[match[1]] = match[2];
  }
  return values;
}
function inventory() {
  const checkout = exists(plugin);
  const manifestPath = path.join(plugin, "manifest.json");
  const manifestFile = exists(manifestPath);
  const manifest = manifestAt(manifestPath);
  const shell = path.join(config, "omarchy", "shell.json");
  let enabled = null; try {
    const document = JSON.parse(fs.readFileSync(shell, "utf8"));
    if (!document || typeof document !== "object" || (document.plugins !== undefined && !Array.isArray(document.plugins))) throw new Error("invalid shell config");
    enabled = !!(document.plugins || []).find((entry) => entry && entry.id === "dev.hibermachy");
  } catch {}
  const menuInfo = inspectMenu(menu);
  const owned = recognizedPolicy();
  const helperInfo = helperProtocol(manifest?.protocol);
  const dependencies = runtimeDependencies();
  const probeDirectory = path.join(plugin, "plugin", "bin");
  const readback = dependencies.state === "compatible" ? probeJson(path.join(probeDirectory, "hibermachy-policy-readback")) : null;
  const contract = dependencies.state === "compatible" ? probeJson(path.join(probeDirectory, "hibermachy-contract-probe")) : null;
  const capability = dependencies.state === "compatible" ? probeKeyValues(path.join(probeDirectory, "hibermachy-sleep-capability-probe")) : null;
  const effectiveState = !readback || readback.indeterminate === true ? "incomplete"
    : !readback.requested && !readback.effective ? "missing"
    : !readback.requested && validEffectivePair(readback.effective) ? "compatible"
    : validPair(readback.requested) && validEffectivePair(readback.effective)
      ? (readback.requested.hibernateDelaySeconds === readback.effective.hibernateDelaySeconds
        && readback.requested.hibernateOnAcPower === readback.effective.hibernateOnAcPower ? "compatible" : "modified") : "incomplete";
  const capabilityValid = capability && ["yes", "no"].includes(capability.CanSuspend)
    && ["yes", "no"].includes(capability.CanHibernate) && ["yes", "no"].includes(capability.CanSuspendThenHibernate)
    && typeof capability.BlockInhibited === "string" && /^[0-9a-f-]{36}$/i.test(capability.BootId || "");
  const contractVersion = typeof contract?.omarchyVersion === "string" && /^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/.test(contract.omarchyVersion)
    && Number.isInteger(contract.majorVersion) && contract.majorVersion === 4;
  const readinessCompatible = contract?.compatible === true && contractVersion && capabilityValid && helperInfo.state === "compatible";
  const checkoutScope = !checkout ? scope("missing", "user-owned", "Add through Quattro and review source.")
    : checkout.isSymbolicLink() || !checkout.isDirectory() ? scope("inaccessible", "user-owned", "Resolve the checkout filesystem object before lifecycle changes.")
    : !manifestFile ? scope("incomplete", "user-owned", "Complete the checkout manifest and declared entry points through Quattro.")
    : manifest ? scope("compatible", "user-owned", "Checkout manifest and nested entry points are present.")
    : scope("modified", "user-owned", "Inspect or replace the checkout through the Quattro review boundary.");
  return { schemaVersion: 1, installationOwner: { state: home ? "identified" : "unrecognized", artifacts: "user-owned" }, scopes: {
    checkout: checkoutScope,
    activation: enabled === null ? scope("incomplete", "user-owned", "Query Quattro after rescan.") : { ...scope("compatible", "user-owned", "Activation is separate from automatic policy."), enabled },
    menu_contribution: scope(menuInfo.state, "user-owned", menuInfo.state === "compatible" ? "Managed menu rows are present." : "Reconcile the shared JSONC menu without overwriting modified entries."),
    helper_package: helperInfo.state === "compatible" ? { ...scope("compatible", "machine-wide", "Helper metadata and protocol overlap are valid."), release: helperInfo.release, protocolMin: helperInfo.protocolMin, protocolMax: helperInfo.protocolMax } : scope(helperInfo.state, "machine-wide", helperInfo.state === "missing" ? "Build the signed release recipe through pacman; plugin activation remains available." : "Preserve the helper and resolve its ownership or protocol before policy mutation."),
    requested_system_policy: owned ? scope("compatible", "machine-wide", "Reset through authenticated helper before uninstall.") : exists(policy) ? scope("modified", "machine-wide", "Unrecognized policy is preserved.") : scope("missing", "machine-wide", "No requested policy is present."),
    effective_system_policy: scope(effectiveState, "machine-wide", effectiveState === "modified" ? "Administrator precedence differs from the requested policy." : effectiveState === "compatible" ? (readback?.requested ? "Requested and effective policy agree." : "An effective policy is observed without a Hibermachy requested policy.") : "Read the bundled policy probe before changing policy."),
    runtime_dependencies: scope(dependencies.state, "machine-wide", dependencies.state === "missing" ? "Install system node and python3 plus python-gobject." : dependencies.state === "incomplete" ? "Repair python-gobject Gio availability before staged-sleep observation." : "Node, python3, and Gio are available for bundled probes."),
    live_readiness: readinessCompatible ? scope("compatible", "machine-wide", "Bundled contract and typed capability probes succeeded.") : scope("incomplete", "machine-wide", "Refresh bundled probes; incompatible helper affects policy mutation and automatic staged sleep, not plugin activation."),
    user_configuration: scope(exists(path.join(config, "hibermachy")) ? "compatible" : "missing", "user-owned", "Retained until purge."),
    outcome_history: scope(exists(path.join(home, ".local/state", "hibermachy")) ? "compatible" : "missing", "user-owned", "Retained until purge.")
  }};
}
function signedRecipeReady() { return !fs.readFileSync(path.join(recipeDirectory, "PKGBUILD"), "utf8").includes("__RELEASE_"); }
function recognizedPolicy() {
  try {
    const stat = fs.lstatSync(policy);
    if (!stat.isFile() || stat.isSymbolicLink() || stat.nlink !== 1 || (!testAdapter && (stat.uid !== 0 || ![0o600, 0o644].includes(stat.mode & 0o777)))) return false;
    const match = fs.readFileSync(policy, "utf8").match(/^# Managed by Hibermachy\. Do not edit\.\n\[Sleep\]\nHibernateDelaySec=([0-9]+)s\nHibernateOnACPower=(yes|no)\n$/);
    return !!match && Number.isSafeInteger(Number(match[1])) && Number(match[1]) >= 900 && Number(match[1]) <= 604800;
  } catch { return false; }
}
function checkInstalledComponents(requireHelper) {
  if (!manifestAt(path.join(plugin, "manifest.json"))) throw new Error("HBR-CHECKOUT-VERIFICATION-FAILED");
  if (runtimeDependencies().state !== "compatible") throw new Error("HBR-RUNTIME-DEPENDENCIES-NOT-READY");
  if (requireHelper && helperProtocol(manifestAt(path.join(plugin, "manifest.json")).protocol).state !== "compatible") throw new Error("HBR-HELPER-VERIFICATION-FAILED");
}
function setup() {
  if (!signedRecipeReady()) throw new Error("HBR-HELPER-IMMUTABLE-RELEASE-REQUIRED");
  if (!manifestAt(path.join(plugin, "manifest.json"))) run("omarchy", ["plugin", "add", "https://github.com/spitefulFr0g/hibermachy.git"]);
  run("makepkg", ["--syncdeps", "--install", "--cleanbuild"], recipeDirectory);
  checkInstalledComponents(true);
  const menuResult = reconcileMenu(menu);
  return { kind: "accepted", operation: "setup", activation: "disabled", menu: menuResult, policyMutation: false, inventory: inventory() };
}
function updateIntentPath() { return path.join(home, ".local/state/hibermachy/lifecycle-update.json"); }
function readUpdateIntent() {
  const file = updateIntentPath();
  validatePurgeTree(path.dirname(file));
  const stat = exists(file);
  if (!stat) return null;
  if (!stat.isFile() || stat.isSymbolicLink() || stat.uid !== process.getuid() || stat.nlink !== 1 || (stat.mode & 0o077)) throw new Error("HBR-UPDATE-STATE-UNSAFE");
  let value;
  try { value = JSON.parse(fs.readFileSync(file, "utf8")); } catch { throw new Error("HBR-UPDATE-STATE-INVALID"); }
  if (value?.schemaVersion !== 1 || typeof value.previousActivation !== "boolean" || Object.keys(value).length !== 2) throw new Error("HBR-UPDATE-STATE-INVALID");
  return value;
}
function saveUpdateIntent(previousActivation) {
  const file = updateIntentPath(), directory = path.dirname(file);
  validatePurgeTree(directory);
  fs.mkdirSync(directory, { recursive: true, mode: 0o700 });
  const temporary = `${file}.${crypto.randomBytes(16).toString("hex")}.tmp`;
  const descriptor = fs.openSync(temporary, "wx", 0o600);
  try {
    fs.writeFileSync(descriptor, JSON.stringify({ schemaVersion: 1, previousActivation }) + "\n");
    fs.fsyncSync(descriptor);
  } finally { fs.closeSync(descriptor); }
  try { fs.linkSync(temporary, file); } finally { fs.unlinkSync(temporary); }
  const directoryFd = fs.openSync(directory, "r");
  try { fs.fsyncSync(directoryFd); } finally { fs.closeSync(directoryFd); }
}
function update() {
  const currentActivation = inventory().scopes.activation.enabled;
  const pending = readUpdateIntent();
  if (!pending && typeof currentActivation !== "boolean") throw new Error("HBR-UPDATE-ACTIVATION-INDETERMINATE");
  const before = pending ? pending.previousActivation : currentActivation;
  if (!pending) saveUpdateIntent(before);
  if (currentActivation) run("omarchy", ["plugin", "disable", "dev.hibermachy"]);
  run("omarchy", ["plugin", "update", "dev.hibermachy"]);
  const updated = path.join(plugin, "lifecycle", "production.mjs");
  const stat = exists(updated);
  if (!stat || !stat.isFile() || stat.isSymbolicLink()) throw new Error("HBR-UPDATE-INTERFACE-MISSING");
  // Reload the reviewed code from the installed checkout. The old process may
  // have been launched from a separate bootstrap clone and must not build it.
  const childEnvironment = { ...process.env };
  delete childEnvironment.HIBERMACHY_LIFECYCLE_RECIPE_DIR;
  const next = spawnSync(process.execPath, [updated, "complete-update"], { stdio: "inherit", env: childEnvironment });
  if (next.error) throw new Error("HBR-UPDATE-TRANSFER-FAILED");
  process.exit(next.status ?? 1);
}
function completeUpdate() {
  if (path.resolve(checkout) !== path.resolve(plugin)) throw new Error("HBR-UPDATE-CHECKOUT-MISMATCH");
  const pending = readUpdateIntent();
  if (!pending) throw new Error("HBR-UPDATE-STATE-MISSING");
  const before = pending.previousActivation;
  if (!signedRecipeReady()) throw new Error("HBR-HELPER-IMMUTABLE-RELEASE-REQUIRED");
  run("makepkg", ["--syncdeps", "--install", "--cleanbuild"], recipeDirectory);
  checkInstalledComponents(true);
  reconcileMenu(menu);
  if (before) run("omarchy", ["plugin", "enable", "dev.hibermachy"]);
  fs.unlinkSync(updateIntentPath());
  return { kind: "accepted", operation: "update", activation: before ? "enabled" : "disabled", policyMutation: false, inventory: inventory() };
}
function activate() { if (!args.includes("--confirm")) return { kind: "declined", operation: "activation", activation: "disabled", policyMutation: false }; checkInstalledComponents(false); run("omarchy", ["plugin", "enable", "dev.hibermachy"]); return { kind: "accepted", operation: "activation", activation: "enabled", policyMutation: false, inventory: inventory() }; }
function disable(remove) {
  // A completed removal has no checkout to delegate to.  Treat that durable
  // state as already disabled so uninstall and purge can be safely rerun.
  if (exists(plugin)) run("omarchy", ["plugin", "disable", "dev.hibermachy"]);
  if (remove && exists(plugin)) run("omarchy", ["plugin", "remove", "dev.hibermachy"]);
  return { kind: "accepted", operation: remove ? "plugin-removal" : "disable", policyMutation: false, inventory: inventory() };
}
function validatePurgeTree(target) {
  const relative = path.relative(home, target);
  if (relative.startsWith("..") || path.isAbsolute(relative)) throw new Error("HBR-PURGE-UNSAFE-PATH");
  let current = home;
  for (const part of ["", ...relative.split(path.sep)]) {
    current = part ? path.join(current, part) : current;
    const stat = exists(current);
    if (!stat) return;
    if (!stat.isDirectory() || stat.isSymbolicLink() || stat.uid !== process.getuid() || (stat.mode & 0o022))
      throw new Error("HBR-PURGE-UNSAFE-PATH");
  }
  function visit(entry) {
    const stat = fs.lstatSync(entry);
    if (stat.uid !== process.getuid() || stat.isSymbolicLink() || (stat.mode & 0o022)
        || (!stat.isDirectory() && (!stat.isFile() || stat.nlink !== 1))) throw new Error("HBR-PURGE-UNSAFE-PATH");
    if (stat.isDirectory()) for (const name of fs.readdirSync(entry)) visit(path.join(entry, name));
  }
  visit(target);
}
function uninstall(purge) {
  disable(false);
  if (exists(policy) && !recognizedPolicy()) throw new Error("HBR-SYSTEM-POLICY-RESET-REFUSED");
  if (exists(policy)) run("pkexec", [helper, "reset"]);
  if (exists(policy)) throw new Error("HBR-SYSTEM-POLICY-ABSENCE-INDETERMINATE");
  const packageState = helperPackageStatus();
  if (packageState === "indeterminate") throw new Error("HBR-PACKAGE-QUERY-FAILED");
  if (packageState === "installed") {
    run("sudo", ["/usr/bin/pacman", "-Rns", "hibermachy-helper"]);
    if (helperPackageStatus() !== "missing") throw new Error("HBR-PACKAGE-ABSENCE-INDETERMINATE");
  }
  if (exists(policy)) throw new Error("HBR-SYSTEM-POLICY-ABSENCE-INDETERMINATE");
  if (exists(installedHelperPath())) throw new Error("HBR-HELPER-ABSENCE-INDETERMINATE");
  removeOwnedMenu(menu);
  if (exists(plugin)) run("omarchy", ["plugin", "remove", "dev.hibermachy"]);
  if (purge) {
    if (!args.includes("--confirm-purge")) return { kind: "declined", operation: "purge", reasonCode: "HBR-PURGE-CONFIRMATION-REQUIRED", inventory: inventory() };
    const targets = [path.join(config, "hibermachy"), path.join(home, ".local/state/hibermachy")];
    targets.forEach(validatePurgeTree);
    for (const target of targets) fs.rmSync(target, { recursive: true, force: true });
  }
  return { kind: "accepted", operation: purge ? "purge" : "uninstall", inventory: inventory() };
}
try {
  const result = command === "status" ? inventory() : command === "setup" ? setup() : command === "activate" ? activate() : command === "update" ? update() : command === "complete-update" ? completeUpdate() : command === "disable" ? disable(false) : command === "remove" ? disable(true) : command === "uninstall" ? uninstall(false) : command === "purge" ? uninstall(true) : (() => { throw new Error("HBR-LIFECYCLE-COMMAND-UNKNOWN"); })();
  process.stdout.write(JSON.stringify(result) + "\n");
} catch (error) { process.stderr.write(JSON.stringify({ kind: "refused", operation: command, reasonCode: error.message, inventory: inventory() }) + "\n"); process.exitCode = 1; }
