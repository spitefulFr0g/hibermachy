"use strict";
const fs = require("node:fs");
const { spawnSync } = require("node:child_process");
const OWNED = "/etc/systemd/sleep.conf.d/90-hibermachy.conf";
function seconds(value, run) {
  if (/^[0-9]+s?$/.test(value)) return Number(value.replace(/s$/, ""));
  const result = run(["timespan", value]);
  const match = result.status === 0 && result.stdout.match(/μs:\s*([0-9]+)/);
  return match ? Number(match[1]) / 1e6 : null;
}
// cat-config reports files in precedence order. Section boundaries and source
// boundaries both matter; an administrator's last assignment remains authoritative.
function reconcile(source, run) {
  let file = "", section = "";
  const effective = {}, requested = {}, provenance = {};
  for (const line of source.split(/\r?\n/)) {
    const origin = line.match(/^# (\/[^\r\n]+)$/);
    if (origin) { file = origin[1]; section = ""; continue; }
    const header = line.trim().match(/^\[([^\]]+)\]$/);
    if (header) { section = header[1]; continue; }
    if (section !== "Sleep") continue;
    const field = line.match(/^\s*(HibernateDelaySec|HibernateOnACPower)\s*=\s*(.*?)\s*$/);
    if (!field) continue;
    const key = field[1] === "HibernateDelaySec" ? "hibernateDelaySeconds" : "hibernateOnAcPower";
    let value = key === "hibernateDelaySeconds" ? seconds(field[2], run)
      : /^(yes|true|on|1)$/i.test(field[2]) ? true : /^(no|false|off|0)$/i.test(field[2]) ? false : null;
    if (typeof value === "number" && (!Number.isFinite(value) || value < 0)) value = null;
    effective[key] = value;
    provenance[key] = file;
    if (file === OWNED) requested[key] = value;
  }
  const complete = p => typeof p.hibernateDelaySeconds === "number" && typeof p.hibernateOnAcPower === "boolean";
  return { requested: complete(requested) ? { ...requested, scope: "machine-wide" } : null,
    effective: complete(effective) ? effective : null,
    provenance: [...new Set(Object.values(provenance))].filter(Boolean) };
}
function nativeRun(args) {
  return spawnSync("/usr/bin/systemd-analyze", args, { encoding: "utf8", timeout: 5000,
    maxBuffer: 1048576, env: { PATH: "/usr/bin", LC_ALL: "C" } });
}
function main() {
  const result = nativeRun(["cat-config", "systemd/sleep.conf"]);
  if (result.error || result.status !== 0) {
    process.stdout.write(JSON.stringify({ requested: null, effective: null, provenance: [], indeterminate: true }) + "\n");
    process.exitCode = 1;
  } else {
    const observed = reconcile(result.stdout, nativeRun);
    try {
      const stat = fs.lstatSync(OWNED);
      const content = fs.readFileSync(OWNED, "utf8");
      if (!stat.isFile() || stat.isSymbolicLink() || stat.uid !== 0 || stat.nlink !== 1
          || ![0o600, 0o644].includes(stat.mode & 0o777)
          || !/^# Managed by Hibermachy\. Do not edit\.\n\[Sleep\]\nHibernateDelaySec=[0-9]+s\nHibernateOnACPower=(yes|no)\n$/.test(content))
        throw new Error("unrecognized owned policy");
      if (!observed.requested) observed.indeterminate = true;
    } catch (error) {
      if (error.code !== "ENOENT") { observed.requested = null; observed.indeterminate = true; }
    }
    process.stdout.write(JSON.stringify(observed) + "\n");
  }
}
module.exports = { reconcile, main };
