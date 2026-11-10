import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";

function objectAt(source, marker) {
  const markerIndex = source.indexOf(marker);
  assert.notEqual(markerIndex, -1, `Missing object marker: ${marker}`);
  const start = source.indexOf("{", markerIndex);
  assert.notEqual(start, -1, `Missing object body: ${marker}`);
  let depth = 0, quote = null, escaped = false;
  for (let i = start; i < source.length; i++) {
    const c = source[i];
    if (quote) {
      if (escaped) escaped = false;
      else if (c === "\\") escaped = true;
      else if (c === quote) quote = null;
      continue;
    }
    if (c === '"' || c === "'" || c === "`") { quote = c; continue; }
    if (c === "{") depth++;
    if (c === "}" && --depth === 0) return source.slice(start, i + 1);
  }
  throw new Error(`Unclosed object: ${marker}`);
}

function propertyObject(source, property) {
  const match = new RegExp(`(?:^|[,\\s])${property}\\s*:`).exec(source);
  assert.ok(match, `Missing locale property: ${property}`);
  return objectAt(source.slice(match.index), property);
}

function topLevelKeys(objectSource) {
  const body = objectSource.slice(1, -1);
  const keys = [];
  let depth = 0, quote = null, escaped = false;
  for (let i = 0; i < body.length; i++) {
    const c = body[i];
    if (quote) {
      if (escaped) escaped = false;
      else if (c === "\\") escaped = true;
      else if (c === quote) quote = null;
      continue;
    }
    if (c === '"' || c === "'" || c === "`") { quote = c; continue; }
    if (c === "{") { depth++; continue; }
    if (c === "}") { depth--; continue; }
    if (depth !== 0 || !/[A-Za-z_$]/.test(c)) continue;
    const candidate = /^[A-Za-z_$][\w$]*/.exec(body.slice(i));
    if (!candidate) continue;
    let j = i + candidate[0].length;
    while (/\s/.test(body[j] ?? "")) j++;
    if (body[j] === ":") keys.push(candidate[0]);
    i = j - 1;
  }
  return [...new Set(keys)].sort();
}

async function assertLocaleParity(path, marker, properties) {
  const source = await readFile(new URL(path, import.meta.url), "utf8");
  const root = objectAt(source, marker);
  const locales = Object.fromEntries(["fr", "en", "ar"].map(locale => [locale, topLevelKeys(propertyObject(root, locale))]));
  const expected = locales.fr;
  for (const locale of ["en", "ar"]) {
    assert.deepEqual(locales[locale], expected, `${path}: ${locale} keys differ from French`);
  }
  if (properties) {
    for (const [locale, keys] of Object.entries(locales)) {
      for (const key of properties) assert.ok(keys.includes(key), `${path}: missing ${locale}.${key}`);
    }
  }
  return Object.fromEntries(Object.entries(locales).map(([locale, keys]) => [locale, keys.length]));
}

test("core application messages have identical FR/EN/AR key coverage", async () => {
  const counts = await assertLocaleParity("../src/lib/i18n.ts", "const messages =", ["signIn", "requestAppointment", "consultation", "agentDisclaimer"]);
  assert.ok(counts.fr >= 150, "Unexpectedly small core translation catalogue");
});

test("landing and patient/professional portal copy have identical FR/EN/AR coverage", async () => {
  const source = await readFile(new URL("../src/lib/data.ts", import.meta.url), "utf8");
  for (const marker of ["export const copy=", "export const portalCopy ="]) {
    const root = objectAt(source, marker);
    const locales = Object.fromEntries(["fr", "en", "ar"].map(locale => [locale, topLevelKeys(propertyObject(root, locale))]));
    assert.deepEqual(locales.en, locales.fr, `${marker}: EN differs from FR`);
    assert.deepEqual(locales.ar, locales.fr, `${marker}: AR differs from FR`);
  }
});

test("authentication form has identical FR/EN/AR key coverage", async () => {
  await assertLocaleParity("../src/components/auth-form.tsx", "const messages =", ["patientTitle", "doctorTitle", "submitLogin"]);
});

test("professional feature components have identical FR/EN/AR key coverage", async () => {
  const cases = [
    ["../src/components/professional-availability.tsx", "const copy=", ["title", "error"]],
    ["../src/components/clinic-management.tsx", "const copy=", ["title", "invite", "error"]],
    ["../src/components/doctor-booking.tsx", "const labels=", ["date", "slot", "failed"]],
    ["../src/components/refund-management.tsx", "const labels=", ["title", "error"]],
  ];
  for (const [path, marker, required] of cases) await assertLocaleParity(path, marker, required);
});
