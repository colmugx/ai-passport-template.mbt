"use strict";

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
const PAGE = "index.html?pcm=./assets/forest_walk.pcm&pcmLoop=1";
const PINNED_PLAYWRIGHT = "1.63.0";

function die(code, message) {
  console.error(message);
  process.exit(code);
}

for (const rel of REQUIRED) {
  if (!fs.existsSync(path.join(BUNDLE, rel))) {
    die(2, `missing ${path.join(BUNDLE, rel)}; build the Web bundle first`);
  }
}
if (fs.existsSync(path.join(BUNDLE, "app.html"))) {
  die(1, "app.html must not exist; SDK index.html is the only Web entry");
}

{
  const mod = new WebAssembly.Module(fs.readFileSync(path.join(BUNDLE, "app.wasm")));
  const imports = WebAssembly.Module.imports(mod).map((item) => item.name);
  if (imports.includes("host_pcm_write")) {
    die(1, "app.wasm imports forbidden host_pcm_write in PCM asset mode");
  }
  for (const required of [
    "host_battery_percent",
    "host_set_volume",
    "host_set_muted",
    "host_playback_pos_us",
  ]) {
    if (!imports.includes(required)) die(1, `missing wasm import ${required}`);
  }
  const exports = WebAssembly.Module.exports(mod).map((item) => item.name);
  for (const required of [
    "memory",
    "passport_frame",
    "passport_input",
    "passport_fb_ptr",
    "passport_fb_len",
    "passport_frame_dirty",
    "passport_frame_consume",
  ]) {
    if (!exports.includes(required)) die(1, `missing wasm export ${required}`);
  }
}

async function loadPlaywright() {
  try {
    const module = await import("playwright");
    return module.default ?? module;
  } catch {}

  const root = path.join(os.homedir(), ".npm", "_npx");
  let entries;
  try {
    entries = fs.readdirSync(root);
  } catch {
    return null;
  }
  for (const entry of entries) {
    const packageJson = path.join(
      root,
      entry,
      "node_modules",
      "playwright",
      "package.json",
    );
    if (!fs.existsSync(packageJson)) continue;
    let version;
    try {
      version = JSON.parse(fs.readFileSync(packageJson, "utf8")).version;
    } catch {
      continue;
    }
    if (version !== PINNED_PLAYWRIGHT) continue;
    const index = path.join(root, entry, "node_modules", "playwright", "index.js");
    try {
      const module = await import(pathToFileURL(index));
      return module.default ?? module;
    } catch {}
  }
  return null;
}

const playwright = await loadPlaywright();
if (!playwright) {
  die(2, `playwright@${PINNED_PLAYWRIGHT} is not installed`);
}

const bundleReal = fs.realpathSync(BUNDLE);
function requestPath(pathname) {
  let decoded;
  try {
    decoded = decodeURIComponent(pathname);
  } catch {
    return null;
  }
  const relative = decoded.endsWith("/") ? `${decoded}index.html` : decoded;
  const candidate = path.resolve(BUNDLE, `.${relative}`);
  if (candidate !== BUNDLE && !candidate.startsWith(`${BUNDLE}${path.sep}`)) {
    return null;
  }
  return candidate;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url ?? "/", "http://127.0.0.1");
  const candidate = requestPath(url.pathname);
  if (candidate === null) {
    res.writeHead(400);
    res.end("bad request");
    return;
  }
  fs.realpath(candidate, (realpathError, real) => {
    if (
      realpathError ||
      (real !== bundleReal && !real.startsWith(`${bundleReal}${path.sep}`))
    ) {
      res.writeHead(realpathError ? 404 : 403);
      res.end(realpathError ? "not found" : "forbidden");
      return;
    }
    fs.readFile(real, (readError, data) => {
      if (readError) {
        res.writeHead(404);
        res.end("not found");
        return;
      }
      const types = {
        ".html": "text/html",
        ".js": "text/javascript",
        ".wasm": "application/wasm",
        ".pcm": "application/octet-stream",
      };
      res.writeHead(200, {
        "content-type": types[path.extname(real)] ?? "application/octet-stream",
        "content-length": data.length,
        "x-content-type-options": "nosniff",
      });
      res.end(data);
    });
  });
});
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const port = server.address().port;
const origin = `http://127.0.0.1:${port}`;

function fail(message) {
  throw new Error(message);
}

let browser;
const requested = [];
try {
  browser = await playwright.chromium.launch();
  const page = await browser.newPage();
  page.on("request", (request) => requested.push(request.url()));

  await page.goto(`${origin}/${PAGE}`);
  await page.waitForFunction(() => globalThis.__passportHost !== undefined, null, {
    timeout: 15000,
  });
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

  await page.locator("canvas").first().click();
  await page.waitForFunction(() => globalThis.__passportHost.frameCount >= 30, null, {
    timeout: 15000,
  });
  const frames = await page.evaluate(
    () =>
      new Promise((resolve) => {
        const host = globalThis.__passportHost;
        const first = Array.from(host.getFramebufferView());
        const firstFrame = host.frameCount;
        setTimeout(() => {
          resolve({
            firstFrame,
            framesNow: host.frameCount,
            first,
            second: Array.from(host.getFramebufferView()),
          });
        }, 1200);
      }),
  );
  if (frames.framesNow <= frames.firstFrame) fail("frames did not advance");
  const differing = frames.first.reduce(
    (count, value, index) => count + (value !== frames.second[index] ? 1 : 0),
    0,
  );
  if (differing < 16) fail(`framebuffer barely changed (${differing} pixels)`);
  const lit = frames.second.reduce((count, value) => count + (value !== 0 ? 1 : 0), 0);
  if (lit < (120 * 160) / 2) fail(`framebuffer looks empty (${lit} pixels)`);

  const asset = await page.evaluate(async () => {
    const host = globalThis.__passportHost;
    await host.waitForAudioAsset().catch(() => {});
    return host.audioAsset;
  });
  if (!asset.configured || asset.source !== "url") {
    fail(`host not in PCM asset mode: ${JSON.stringify(asset)}`);
  }
  if (asset.url !== "./assets/forest_walk.pcm") {
    fail(`unexpected PCM URL: ${JSON.stringify(asset)}`);
  }
  if (asset.error || !asset.loaded) fail(`audio asset failed: ${asset.error ?? "not loaded"}`);
  if (asset.samples !== 2444800 / 2 || asset.byteLength !== 2444800) {
    fail(`audio asset size mismatch: ${JSON.stringify(asset)}`);
  }
  if (!asset.looping) fail("audio asset is not looping");
  await page.waitForFunction(() => globalThis.__passportHost.playbackPosUs() > 0n, null, {
    timeout: 20000,
  });

  const initialVolume = await page.evaluate(() => globalThis.__passportHost.volume);
  if (initialVolume !== 80) fail(`startup volume expected 80, got ${initialVolume}`);
  await page.keyboard.press("ArrowUp");
  await page.waitForFunction(() => globalThis.__passportHost.volume === 90, null, {
    timeout: 5000,
  });
  for (let i = 0; i < 3; i += 1) await page.keyboard.press("ArrowUp");
  await page.waitForFunction(() => globalThis.__passportHost.volume === 100, null, {
    timeout: 5000,
  });
  await page.keyboard.press("ArrowDown");
  await page.waitForFunction(() => globalThis.__passportHost.volume === 90, null, {
    timeout: 5000,
  });

  await page.keyboard.press("Enter");
  await page.waitForFunction(() => globalThis.__passportHost.muted === true, null, {
    timeout: 5000,
  });
  const muted = await page.evaluate(
    () =>
      new Promise((resolve) => {
        const host = globalThis.__passportHost;
        const position = host.playbackPosUs();
        const frameCount = host.frameCount;
        setTimeout(
          () =>
            resolve({
              position,
              positionNow: host.playbackPosUs(),
              frameCount,
              frameCountNow: host.frameCount,
            }),
          1000,
        );
      }),
  );
  if (muted.frameCountNow <= muted.frameCount) fail("frames froze while muted");
  if (muted.positionNow <= muted.position) fail("playback froze while muted");
  await page.keyboard.press("Enter");
  await page.waitForFunction(() => globalThis.__passportHost.muted === false, null, {
    timeout: 5000,
  });
  const restored = await page.evaluate(() => globalThis.__passportHost.volume);
  if (restored !== 90) fail(`unmute lost remembered volume: ${restored}`);

  const authored = requested.filter((url) => /\.(mp3|wav)(\?|$)/i.test(url));
  if (authored.length > 0) fail(`authored audio was requested: ${authored.join(", ")}`);
  if (!requested.some((url) => url.includes("forest_walk.pcm"))) {
    fail("canonical PCM was never requested");
  }

  console.log("ALL WEB INTEGRATION CHECKS PASSED");
} catch (error) {
  die(1, `web integration test failed: ${error?.stack ?? error}`);
} finally {
  if (browser) await browser.close().catch(() => {});
  server.close();
}
