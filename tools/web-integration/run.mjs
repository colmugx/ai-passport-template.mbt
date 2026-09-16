// Real-browser integration test for the NEW template wasm bundle (R2A).
//
//   node tools/web-integration/run.mjs
//
// Requires the assembled bundle (.passport/web) — build it first with
//   moon run tools/passport.mbtx build web
// Exit 2 = missing prerequisites (never silently skipped), 1 = failure.
//
// Uses the pinned playwright (1.63.0) exactly like the SDK CI: bare import
// first, then the npx cache. The page under test is the bundle's configured
// entry (app.html: the unmodified SDK Web Host — passport-host.js +
// pcm-worklet.js from the published dependency — booted through its public
// createHost API in PCM asset mode, because the published 0.0.2 index.html
// auto-boot is broken upstream) running this project's app.wasm against the
// canonical .passport/web/assets/forest_walk.pcm.

"use strict";

import { spawn } from "node:child_process";
import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { pathToFileURL } from "node:url";

const BUNDLE = path.resolve(".passport/web");
const REQUIRED = [
  "app.wasm",
  "passport-host.js",
  "pcm-worklet.js",
  "index.html",
  "assets/forest_walk.pcm",
];
const PAGE = "app.html";
const PINNED_PLAYWRIGHT = "1.63.0";

function die(code, message) {
  console.error(message);
  process.exit(code);
}

// ---- prerequisites -------------------------------------------------------

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(BUNDLE, rel))) {
    die(
      2,
      `missing ${path.join(BUNDLE, rel)}; run: moon run tools/passport.mbtx build web`,
    );
  }
}

// Static import-surface assertion (CI mirrors this independently).
{
  const mod = new WebAssembly.Module(fs.readFileSync(path.join(BUNDLE, "app.wasm")));
  const names = WebAssembly.Module.imports(mod).map((i) => i.name);
  if (names.includes("host_pcm_write")) {
    die(1, "app.wasm imports passport.host_pcm_write — forbidden in PCM asset mode");
  }
  for (const required of [
    "host_battery_percent",
    "host_set_volume",
    "host_set_muted",
    "host_playback_pos_us",
  ]) {
    if (!names.includes(required)) {
      die(1, `app.wasm is missing the required import ${required}`);
    }
  }
  const exports = WebAssembly.Module.exports(mod).map((e) => e.name);
  for (const required of [
    "memory",
    "passport_frame",
    "passport_input",
    "passport_fb_ptr",
    "passport_fb_len",
    "passport_frame_dirty",
    "passport_frame_consume",
  ]) {
    if (!exports.includes(required)) {
      die(1, `app.wasm is missing the required export ${required}`);
    }
  }
  console.log("ok: wasm import/export surface (no host_pcm_write)");
}

// ---- playwright (pinned), resolved like the SDK CI -----------------------

async function loadPlaywright() {
  try {
    const m = await import("playwright");
    return { mod: m.default ?? m, via: "bare import" };
  } catch {
    // fall through to the npx cache
  }
  const roots = [path.join(os.homedir(), ".npm", "_npx")];
  for (const root of roots) {
    let entries = [];
    try {
      entries = fs.readdirSync(root);
    } catch {
      continue;
    }
    for (const entry of entries) {
      const pkg = path.join(root, entry, "node_modules", "playwright", "package.json");
      if (!fs.existsSync(pkg)) continue;
      let version = "?";
      try {
        version = JSON.parse(fs.readFileSync(pkg, "utf8")).version;
      } catch {}
      if (version !== PINNED_PLAYWRIGHT) continue;
      const index = path.join(root, entry, "node_modules", "playwright", "index.js");
      try {
        const m = await import(pathToFileURL(index));
        return { mod: m.default ?? m, via: `npx cache (${version})` };
      } catch {}
    }
  }
  return null;
}

const pw = await loadPlaywright();
if (!pw) {
  die(
    2,
    `playwright@${PINNED_PLAYWRIGHT} not found; install with: npx -y playwright@${PINNED_PLAYWRIGHT} install chromium --with-deps`,
  );
}
console.log(`ok: playwright resolved via ${pw.via}`);

// ---- http server over the bundle (http(s) only; file:// cannot work) -----

const server = http.createServer((req, res) => {
  const url = new URL(req.url, "http://127.0.0.1");
  let file = path.join(BUNDLE, decodeURIComponent(url.pathname));
  if (url.pathname.endsWith("/")) file = path.join(file, "index.html");
  const types = {
    ".html": "text/html",
    ".js": "text/javascript",
    ".wasm": "application/wasm",
    ".pcm": "application/octet-stream",
  };
  fs.readFile(file, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end("not found");
      return;
    }
    res.writeHead(200, {
      "content-type": types[path.extname(file)] ?? "application/octet-stream",
      "content-length": data.length,
    });
    res.end(data);
  });
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const port = server.address().port;
const origin = `http://127.0.0.1:${port}`;
console.log(`ok: serving ${BUNDLE} at ${origin}`);

// ---- the test ------------------------------------------------------------

function fail(msg) {
  throw new Error(msg);
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

let browser;
const requested = [];
try {
  browser = await pw.mod.chromium.launch();
  const page = await browser.newPage();
  page.on("request", (req) => requested.push(req.url()));

  // 1. app.wasm instantiates and the host boots.
  await page.goto(`${origin}/${PAGE}`);
  await page.waitForFunction(
    () => globalThis.__passportHost !== undefined,
    null,
    { timeout: 15000 },
  );
  const booted = await page.evaluate(() => {
    const host = globalThis.__passportHost;
    return {
      frameCount: host.frameCount,
      fbPtr: host.exports.passport_fb_ptr(),
      fbLen: host.exports.passport_fb_len(),
    };
  });
  if (booted.fbPtr !== 4096 || booted.fbLen !== 38400) {
    fail(`bad ABI surface: ${JSON.stringify(booted)}`);
  }
  console.log("ok: app.wasm instantiated through the SDK Web Host");

  // A click both unlocks the AudioContext (autoplay policy) and mirrors a
  // real user gesture; semantic buttons come from the keyboard below.
  await page.locator("canvas").first().click();

  // 2/3. Forest Walk frames advance and the RGB565 framebuffer changes.
  await page.waitForFunction(
    () => globalThis.__passportHost.frameCount >= 30,
    null,
    { timeout: 15000 },
  );
  const framesProbe = await page.evaluate(
    () =>
      new Promise((resolve) => {
        const host = globalThis.__passportHost;
        const first = Array.from(host.getFramebufferView());
        const firstFrame = host.frameCount;
        setTimeout(() => {
          const second = Array.from(host.getFramebufferView());
          resolve({
            firstFrame,
            framesNow: host.frameCount,
            first,
            second,
          });
        }, 1200);
      }),
  );
  if (framesProbe.framesNow <= framesProbe.firstFrame) {
    fail("frames did not advance");
  }
  const differing = framesProbe.first.reduce(
    (n, v, i) => (v !== framesProbe.second[i] ? n + 1 : n),
    0,
  );
  if (differing < 16) {
    fail(`framebuffer barely changed over time (${differing} pixels)`);
  }
  const lit = framesProbe.second.reduce((n, v) => (v !== 0 ? n + 1 : n), 0);
  if (lit < 120 * 160 / 2) {
    fail(`framebuffer looks empty (${lit} non-zero pixels)`);
  }
  console.log(
    `ok: frames advance (${framesProbe.firstFrame} -> ${framesProbe.framesNow}), framebuffer changed (${differing} px, ${lit} non-zero)`,
  );

  // 4/5/6. Normalized PCM asset mode: configured, loaded, consumed.
  const asset = await page.evaluate(async () => {
    const host = globalThis.__passportHost;
    await host.waitForAudioAsset().catch(() => {});
    return host.audioAsset;
  });
  if (!asset.configured || asset.source !== "url") {
    fail(`host not in PCM asset mode: ${JSON.stringify(asset)}`);
  }
  if (asset.error) {
    fail(`audio asset failed to load: ${asset.error}`);
  }
  if (!asset.loaded) {
    fail("audio asset did not load");
  }
  if (asset.samples !== 2444800 / 2 || asset.byteLength !== 2444800) {
    fail(`audio asset size mismatch: ${JSON.stringify(asset)}`);
  }
  if (!asset.looping) {
    fail("audio asset not looping");
  }
  await page.waitForFunction(
    () => globalThis.__passportHost.playbackPosUs() > 0n,
    null,
    { timeout: 20000 },
  );
  const pos1 = await page.evaluate(() => globalThis.__passportHost.playbackPosUs());
  console.log(
    `ok: PCM asset mode (url, ${asset.samples} samples, loop), consumed (pos ${pos1} us)`,
  );

  // 7/8. Semantic UP/DOWN/OK enter the Wasm app; volume/mute change through
  // MoonBit app semantics only (the host has no Forest Walk logic).
  // Startup volume is 80 (app constant).
  const v0 = await page.evaluate(() => globalThis.__passportHost.volume);
  if (v0 !== 80) fail(`startup volume expected 80, got ${v0}`);
  await page.keyboard.press("ArrowUp"); // UP: +10
  await page.waitForFunction(
    () => globalThis.__passportHost.volume === 90,
    null,
    { timeout: 5000 },
  );
  for (let i = 0; i < 3; i += 1) await page.keyboard.press("ArrowUp"); // clamp at 100
  await page.waitForFunction(
    () => globalThis.__passportHost.volume === 100,
    null,
    { timeout: 5000 },
  );
  await page.keyboard.press("ArrowDown"); // DOWN: -10
  await page.waitForFunction(
    () => globalThis.__passportHost.volume === 90,
    null,
    { timeout: 5000 },
  );
  console.log("ok: keyboard UP/DOWN reach the MoonBit app (80 -> 90 -> 100 -> 90)");

  // 9. OK mutes; audio keeps its position clock and frames never freeze;
  // unmute restores the remembered volume.
  await page.keyboard.press("Enter"); // OK: toggle mute
  await page.waitForFunction(() => globalThis.__passportHost.muted === true, null, {
    timeout: 5000,
  });
  const mutedProbe = await page.evaluate(
    () =>
      new Promise((resolve) => {
        const host = globalThis.__passportHost;
        const pos = host.playbackPosUs();
        const frames = host.frameCount;
        setTimeout(
          () =>
            resolve({
              posNow: host.playbackPosUs(),
              framesNow: host.frameCount,
              pos,
              frames,
            }),
          1000,
        );
      }),
  );
  if (mutedProbe.framesNow <= mutedProbe.frames) {
    fail("frames froze while muted");
  }
  if (mutedProbe.posNow <= mutedProbe.pos) {
    fail("playback position froze while muted");
  }
  await page.keyboard.press("Enter"); // OK again: unmute
  await page.waitForFunction(
    () => globalThis.__passportHost.muted === false,
    null,
    { timeout: 5000 },
  );
  const vRestored = await page.evaluate(() => globalThis.__passportHost.volume);
  if (vRestored !== 90) fail(`unmute lost remembered volume: ${vRestored}`);
  console.log(
    "ok: OK mutes/unmutes, frames and playback position keep running while muted, volume remembered",
  );

  // 10. No authored MP3/WAV was ever requested.
  const authored = requested.filter((u) => /\.(mp3|wav)(\?|$)/i.test(u));
  if (authored.length > 0) {
    fail(`authored audio was requested: ${authored.join(", ")}`);
  }
  if (!requested.some((u) => u.includes("forest_walk.pcm"))) {
    fail("the normalized PCM asset was never requested");
  }
  console.log("ok: no authored .mp3/.wav request; canonical .pcm served");

  console.log("ALL WEB INTEGRATION CHECKS PASSED");
} catch (err) {
  die(1, `web integration test failed: ${err && err.stack ? err.stack : err}`);
} finally {
  if (browser) await browser.close().catch(() => {});
  server.close();
}
