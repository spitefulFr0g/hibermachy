import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const ownedIds = ["setup.hibermachy", "system.hibermachy-staged-sleep"];
const entries = {
  "setup.hibermachy": { managedBy: "hibermachy", label: "Sleep & Hibernation", aliases: ["sleep", "hibernate", "Hibermachy"], description: "Configure Hibermachy sleep and hibernation.", action: "omarchy-shell shell summon dev.hibermachy '{}'", when: "omarchy-shell dev.hibermachy status >/dev/null 2>&1" },
  "system.hibermachy-staged-sleep": { managedBy: "hibermachy", label: "Suspend then Hibernate", aliases: ["sleep", "hibernate", "Hibermachy"], description: "Request Hibermachy staged sleep.", action: "omarchy-shell shell summon dev.hibermachy '{\"action\":\"confirm-staged-sleep\"}'", when: "omarchy-shell dev.hibermachy status >/dev/null 2>&1" }
};

function refuse(code) { throw new Error(code); }
function lstat(file) { try { return fs.lstatSync(file); } catch { return null; } }
function skipTrivia(source, start) {
  let index = start;
  while (index < source.length) {
    if (/\s/.test(source[index])) { index += 1; continue; }
    if (source[index] === "/" && source[index + 1] === "/") { index = source.indexOf("\n", index + 2); if (index < 0) return source.length; continue; }
    if (source[index] === "/" && source[index + 1] === "*") { const end = source.indexOf("*/", index + 2); if (end < 0) refuse("HBR-MENU-MALFORMED"); index = end + 2; continue; }
    break;
  }
  return index;
}
function stringEnd(source, start) {
  if (source[start] !== '"') refuse("HBR-MENU-MALFORMED");
  for (let index = start + 1, escaped = false; index < source.length; index += 1) {
    if (escaped) { escaped = false; continue; }
    if (source[index] === "\\") { escaped = true; continue; }
    if (source[index] === '"') return index + 1;
  }
  refuse("HBR-MENU-MALFORMED");
}
function compoundEnd(source, start) {
  const closer = source[start] === "{" ? "}" : source[start] === "[" ? "]" : null;
  if (!closer) refuse("HBR-MENU-MALFORMED");
  const stack = [closer];
  for (let index = start + 1; index < source.length; index += 1) {
    const character = source[index];
    if (character === '"') { index = stringEnd(source, index) - 1; continue; }
    if (character === "/" && source[index + 1] === "/") { index = source.indexOf("\n", index + 2); if (index < 0) refuse("HBR-MENU-MALFORMED"); continue; }
    if (character === "/" && source[index + 1] === "*") { const end = source.indexOf("*/", index + 2); if (end < 0) refuse("HBR-MENU-MALFORMED"); index = end + 1; continue; }
    if (character === "{") stack.push("}");
    else if (character === "[") stack.push("]");
    else if (character === "}" || character === "]") { if (character !== stack.pop()) refuse("HBR-MENU-MALFORMED"); if (!stack.length) return index + 1; }
  }
  refuse("HBR-MENU-MALFORMED");
}
function valueEnd(source, start) {
  if (source[start] === '"') return stringEnd(source, start);
  if (source[start] === "{" || source[start] === "[") return compoundEnd(source, start);
  let index = start;
  while (index < source.length && !/\s/.test(source[index]) && source[index] !== "," && source[index] !== "}" && source[index] !== "]" && source[index] !== "/") index += 1;
  if (index === start) refuse("HBR-MENU-MALFORMED");
  return index;
}
function topLevelProperties(source) {
  let index = skipTrivia(source, 0);
  if (source[index] !== "{") refuse("HBR-MENU-MALFORMED");
  index = skipTrivia(source, index + 1);
  const properties = [];
  let previousComma = null;
  while (source[index] !== "}") {
    const start = index, keyEnd = stringEnd(source, index);
    let key; try { key = JSON.parse(source.slice(index, keyEnd)); } catch { refuse("HBR-MENU-MALFORMED"); }
    index = skipTrivia(source, keyEnd);
    if (source[index] !== ":") refuse("HBR-MENU-MALFORMED");
    index = skipTrivia(source, index + 1);
    const end = valueEnd(source, index);
    index = skipTrivia(source, end);
    const delimiter = source[index];
    if (delimiter !== "," && delimiter !== "}") refuse("HBR-MENU-MALFORMED");
    properties.push({ key, start, end, commaBefore: previousComma, commaAfter: delimiter === "," ? index : null });
    if (delimiter === "}") break;
    previousComma = index;
    index = skipTrivia(source, index + 1);
  }
  const close = index;
  if (skipTrivia(source, close + 1) !== source.length) refuse("HBR-MENU-MALFORMED");
  return { properties, close };
}
function parseJsonc(source) {
  let stripped = "";
  for (let index = 0; index < source.length; index += 1) {
    if (source[index] === '"') { const end = stringEnd(source, index); stripped += source.slice(index, end); index = end - 1; continue; }
    if (source[index] === "/" && source[index + 1] === "/") { const end = source.indexOf("\n", index + 2); const finish = end < 0 ? source.length : end; stripped += source.slice(index, finish).replace(/[^\n]/g, " "); index = finish - 1; continue; }
    if (source[index] === "/" && source[index + 1] === "*") { const end = source.indexOf("*/", index + 2); if (end < 0) refuse("HBR-MENU-MALFORMED"); stripped += source.slice(index, end + 2).replace(/[^\n]/g, " "); index = end + 1; continue; }
    stripped += source[index];
  }
  let normalized = "";
  for (let index = 0; index < stripped.length; index += 1) {
    if (stripped[index] === '"') { const end = stringEnd(stripped, index); normalized += stripped.slice(index, end); index = end - 1; continue; }
    if (stripped[index] === ",") { let next = index + 1; while (/\s/.test(stripped[next] || "")) next += 1; if (stripped[next] === "}" || stripped[next] === "]") continue; }
    normalized += stripped[index];
  }
  try { return JSON.parse(normalized); } catch { refuse("HBR-MENU-MALFORMED"); }
}
function validateParents(directory) {
  let current = path.resolve(directory);
  for (;;) {
    const stat = lstat(current);
    if (!stat || !stat.isDirectory() || stat.isSymbolicLink()
        || ![0, process.getuid()].includes(stat.uid)
        || ((stat.mode & 0o022) && !(stat.uid === 0 && (stat.mode & 0o1000)))) refuse("HBR-MENU-INACCESSIBLE");
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
}
function ensureParents(directory) {
  if (!lstat(directory)) {
    ensureParents(path.dirname(directory));
    fs.mkdirSync(directory, { mode: 0o700 });
  }
  validateParents(directory);
}
function validateMenuPath(menu) {
  validateParents(path.dirname(menu));
  const target = lstat(menu);
  if (!target || !target.isFile() || target.isSymbolicLink() || target.uid !== process.getuid() || target.nlink !== 1 || (target.mode & 0o022)) refuse("HBR-MENU-INACCESSIBLE");
  return target;
}
function writeAtomically(menu, text, expected) {
  const directory = path.dirname(menu);
  const temporary = path.join(directory, `.${path.basename(menu)}.hibermachy-${process.pid}-${crypto.randomBytes(16).toString("hex")}.tmp`);
  let descriptor;
  try {
    descriptor = fs.openSync(temporary, "wx", expected.mode & 0o777);
    fs.writeFileSync(descriptor, text, "utf8"); fs.fsyncSync(descriptor); fs.closeSync(descriptor); descriptor = undefined;
    const temp = lstat(temporary);
    if (!temp || !temp.isFile() || temp.isSymbolicLink() || temp.uid !== process.getuid() || temp.nlink !== 1) refuse("HBR-MENU-INACCESSIBLE");
    validateParents(directory);
    if (expected.ino === undefined) {
      // link is an atomic no-replace publication; a concurrently created menu
      // is never overwritten. The temporary name is removed immediately.
      fs.linkSync(temporary, menu);
      fs.unlinkSync(temporary);
    } else {
      const current = validateMenuPath(menu);
      if (current.dev !== expected.dev || current.ino !== expected.ino || current.mtimeMs !== expected.mtimeMs || current.size !== expected.size) refuse("HBR-MENU-INACCESSIBLE");
      fs.renameSync(temporary, menu);
    }
    const directoryFd = fs.openSync(directory, "r"); try { fs.fsyncSync(directoryFd); } finally { fs.closeSync(directoryFd); }
  } catch (error) {
    if (descriptor !== undefined) fs.closeSync(descriptor);
    try { fs.unlinkSync(temporary); } catch {}
    throw error;
  }
}
function checkedDocument(source) {
  const document = parseJsonc(source);
  if (!document || Array.isArray(document) || typeof document !== "object") refuse("HBR-MENU-MALFORMED");
  const lexical = topLevelProperties(source);
  for (const id of ownedIds) {
    const matches = lexical.properties.filter((property) => property.key === id);
    if (matches.length > 1) refuse("HBR-MENU-MANAGED-MODIFIED");
    if (matches.length === 1 && JSON.stringify(document[id]) !== JSON.stringify(entries[id])) refuse("HBR-MENU-MANAGED-MODIFIED");
  }
  return { document, lexical };
}
export function inspectMenu(menu) {
  if (!lstat(menu)) return { state: "missing" };
  try {
    const stat = validateMenuPath(menu), source = fs.readFileSync(menu, "utf8");
    const { document } = checkedDocument(source);
    const count = ownedIds.filter((id) => Object.hasOwn(document, id)).length;
    return { state: count === ownedIds.length ? "compatible" : count ? "incomplete" : "missing", stat };
  } catch (error) {
    return { state: error.message === "HBR-MENU-INACCESSIBLE" ? "inaccessible" : "modified" };
  }
}
export function reconcileMenu(menu) {
  if (!lstat(menu)) {
    ensureParents(path.dirname(menu));
    const source = JSON.stringify(entries, null, 2) + "\n";
    checkedDocument(source);
    writeAtomically(menu, source, { mode: 0o600 });
    return "reconciled";
  }
  const stat = validateMenuPath(menu), source = fs.readFileSync(menu, "utf8");
  const { document, lexical } = checkedDocument(source);
  const missing = ownedIds.filter((id) => !Object.hasOwn(document, id));
  if (!missing.length) return "unchanged";
  const trailingComma = lexical.properties.at(-1)?.commaAfter !== null;
  const prefix = lexical.properties.length && !trailingComma ? "," : "";
  const addition = `${prefix}\n${missing.map((id) => `  ${JSON.stringify(id)}: ${JSON.stringify(entries[id])}`).join(",\n")}\n`;
  const next = source.slice(0, lexical.close) + addition + source.slice(lexical.close);
  checkedDocument(next); writeAtomically(menu, next, stat); return "reconciled";
}
export function removeOwnedMenu(menu) {
  if (!lstat(menu)) return "unchanged";
  const stat = validateMenuPath(menu), source = fs.readFileSync(menu, "utf8");
  const { lexical } = checkedDocument(source);
  const targets = lexical.properties.filter((property) => ownedIds.includes(property.key));
  if (!targets.length) return "unchanged";
  const cuts = targets.flatMap((property) => [[property.start, property.end], property.commaAfter !== null ? [property.commaAfter, property.commaAfter + 1] : property.commaBefore !== null ? [property.commaBefore, property.commaBefore + 1] : []]).filter((cut) => cut.length).sort((left, right) => right[0] - left[0]);
  let next = source;
  const uniqueCuts = [...new Map(cuts.map(cut => [cut.join(":"), cut])).values()];
  for (const [start, end] of uniqueCuts) next = next.slice(0, start) + next.slice(end);
  checkedDocument(next); writeAtomically(menu, next, stat); return "removed";
}
