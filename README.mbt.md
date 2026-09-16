# AI Passport application template


`moon.mod` depends on the published Mooncakes package `colmugx/ai-passport@0.0.3` (plus `moonbitlang/async@0.22.1`). The thin native device entry compiles against SDK surfaces no published release ships yet, so a dev overlay is used until the next SDK release (the pin bumps to that release when it ships): `tools/sync-dev-sdk.sh` copies a local SDK checkout into the ignored `.mooncakes/colmugx/ai-passport/` (generated state — re-run it after changing the SDK checkout, and after any `moon update`, which re-materializes the published package over it). CI checks out the SDK at `main` and runs the same script.

```text
Forest Walk application logic (src/forest_walk + src/app, shared)
         |
         v
colmugx/ai-passport SDK
      /             \
 runtime_wasm    runtime_native
 (wasm -> SDK    (generic device ABI ->
  Web Host)       SDK ESP-IDF/BSP backend)
```

Browser execution is the shared MoonBit App compiled to `app.wasm` and run by the SDK Web Host: the bundle's only page is the SDK's own `index.html`, whose DOM auto-boot in `passport-host.js` instantiates the wasm app and is configured generically through URL parameters (`?pcm=...&pcmLoop=1`). The template owns no browser bootstrap JavaScript of its own. The ESP32-C3 foundation has already shown the MoonBit probe and RGB smoke screen on a physical FoloToy board. The T4.0-B firmware builds the same root Forest Walk application for device presentation, T4.1-A adds the real CW2017 battery HUD and flash-resident looping music (audio playback confirmed on the board), and T4.1-B adds the physical volume buttons through the official BSP ADC button driver (UP volume+, DOWN volume−, OK mute; startup volume 80%). Application code stays independent of browser and device APIs; runtimes own those integrations and audio playback.

## ESP32-C3 Forest Walk firmware

The device backend (the ESP-IDF 5.5.3 project, the vendored FoloToy BSP, and all C bridges: display DMA, buttons, battery, music, clock) lives in the SDK repository under `hosts/folotoy-ai-passport/` and is not part of this template. The template's `src/runtime_native` is thin glue: it builds the shared `@app.App` and exports the eight generic ABI symbols the SDK's C `app_main` calls (`ai_passport_mbt_{probe,app_init,app_update,app_draw,app_present,input_press,audio_volume,audio_muted}`); it owns no C code, no FFI externs, and no bridge logic. The device fairy pose clock leads the reported playback position by a hardware-measured 100 ms (`FAIRY_POSE_LEAD_US`), the app-owned host calibration fact that keeps displayed steps on the audible beat.

Toolchain preconditions (the SDK `passport doctor --host folotoy-ai-passport` verifies all of them): ESP-IDF v5.5.3 with `idf.py` on PATH (`source $IDF_PATH/export.sh`), the MoonBit toolchain `moon 0.1.20260915`, and `$MOON_HOME` pointing at the MoonBit installation whose runtime hash the SDK host manifest pins.

```sh
moon run tools/passport.mbtx build device    # assets, capture, ESP-IDF build; never flashes
```

The dispatcher delegates to the SDK `passport` CLI: it normalizes assets exactly once, captures MoonBit-generated C from the thin entry, materializes the host project into the ignored `.passport/hosts/folotoy-ai-passport/` workspace (including `passport_music.pcm`, a byte-for-byte copy of the contract's `pcmLoop` asset), connects the pinned FoloToy BSP (`external/folotoy-ai-passport`, the template's submodule, declared via `hostDependencies`; the SDK never carries or downloads third-party hardware code beyond that pinned revision), and runs `idf.py reconfigure` followed by `idf.py build`. With a board connected, flash and monitor from the materialized workspace:

```sh
.passport/hosts/folotoy-ai-passport/flash.sh -p PORT
.passport/hosts/folotoy-ai-passport/monitor.sh -p PORT
```

## Web development and build

The supported web build command assembles `.passport/web/` (app.wasm, the SDK Web Host files copied byte-for-byte from the resolved published SDK package, and the canonical PCM under `assets/`):

```sh
moon run tools/passport.mbtx build web
```

The supported web development command builds that bundle, serves it over localhost, and prints the URL:

```sh
moon run tools/passport.mbtx dev
# http://127.0.0.1:8000/index.html?pcm=./assets/forest_walk.pcm&pcmLoop=1
# (PORT=9000 moon run tools/passport.mbtx dev to change the port; Ctrl-C stops)
```

Requires the MoonBit toolchain and `python3` (used only as the static file server); no npm dependencies. The dev tool contains no browser runtime logic — the SDK Web Host boots the application from `index.html` with the PCM asset configured through URL parameters. ArrowUp/ArrowDown adjust volume and Enter toggles mute (handled by the MoonBit app inside `app.wasm`, same semantics as the device buttons); click or press a key once to unlock the browser AudioContext.

How a frame reaches the screen (the SDK rasterizer stays authoritative; the browser never redraws SDK content with Canvas2D primitives):

```text
shared MoonBit App (src/app + src/forest_walk)
  -> compiled to app.wasm (src/runtime_wasm, ABI v0 exports)
  -> SDK Web Host (passport-host.js DOM auto-boot)
  -> app.wasm presents the logical frame into linear memory
  -> host reads the RGB565 framebuffer view (Canvas::frame_view)
  -> RGB565 -> RGBA conversion     (exact bit replication, alpha 255)
  -> persistent ImageData + putImageData (1:1 onto the 120x160 canvas)
  -> CSS integer scaling with image-rendering: pixelated
```

The application updates at a fixed 30 Hz simulation rate. The scene is ambient: 16.875 logical scroll pixels per second, with no speed or pause controls. The fairy pose is beat-locked to the music: the six-pose walk cycle spans exactly one 4/4 bar of eight eighth notes at the application tempo (114 quarter BPM, i.e. 76 dotted-quarter BPM — one pose per 4/3 eighths, pose 0 on the downbeat). Music is the canonical normalized PCM asset (`assets/forest_walk.pcm`, PCM16 LE mono 16 kHz): the Web Host fetches it, plays it through an AudioWorklet, and loops it at the exact PCM sample boundary; the fairy pose derives statelessly from the audible playback head. Before audio unlocks, the host still runs frames and the app falls back to its monotonic beat clock. Hiding the tab suspends WebAudio so the audible timeline stays frozen.

## Forest Walk assets

The committed source art lives in `assets/forest_walk/`:

| File | Role |
| --- | --- |
| `fairy_walk_right.png` | six horizontal 28×32 fairy walk frames |
| `forest_far.png` | far mist and distant forest silhouettes (1/8 world speed) |
| `forest_world.png` | forest and the walking road the fairy stands on (world speed) |
| `forest_foreground.png` | dark foreground foliage that occludes the fairy (3/2 world speed) |

To regenerate the compact MoonBit sources after editing any PNG, run:

```sh
./tools/compile_assets.sh
```

The compilers use Python 3's standard library only. Each scenery source receives a deterministic 3:2 cover crop before nearest-neighbour resize to 240×160; the world crop is anchored to the bottom to preserve the road. Sources already at 3:2 keep their full frame. Alpha is thresholded at build time (below 128 becomes fully transparent), and opaque colors are reduced to at most 128 with a deterministic median-cut quantizer. The runtime never loads a PNG: browser and device builds compile the generated sources under `src/forest_walk/generated/`, which carry one small palette plus one-byte indices per layer. Scenery scrolls with ping-pong tiling (`A | mirror(A) | ...`), so no mirrored copy is stored and no seamless authoring is required. Running the compiler twice without changing the assets produces byte-identical output, which CI verifies with `git diff --exit-code`.

## Forest Walk music

Music is authored as one exported audio file, not as note data. Place exactly one of:

| File | Authoring format |
| --- | --- |
| `assets/audio/forest_walk.wav` | WAV export from a DAW |
| `assets/audio/forest_walk.mp3` | MP3 export from a DAW |

Keeping both is an error unless you explicitly pass `--source` to the
converter. `tools/compile_audio.py` (requires `ffmpeg`) converts the selected
file into the playback format — signed PCM16 little-endian, mono,
16000 Hz — as the canonical artifact `.passport/assets/forest_walk.pcm`,
reporting source and generated durations and sizes, refusing tracks over the
`0x280000`-byte device flash budget (the PCM shares the factory app
partition with the firmware; the budget is pinned against the SDK device
Host's `partitions.csv`), and failing on any conversion error. The
authored file is committed; the generated PCM is not. Both Hosts play the
same bytes: the web bundle serves a byte-identical copy and the device
workspace embeds one (`passport_music.pcm`);
`tools/verify_pcm_identity.py` proves the copies match the canonical
artifact. CI installs ffmpeg and runs the same conversion.

## Develop

Install the MoonBit toolchain, then run:

```sh
moon update
./tools/sync-dev-sdk.sh
./tools/compile_assets.sh
moon check --target native --output-json
moon test --target native --output-json
moon info
moon fmt
git diff --exit-code
```

The last command checks that generated asset sources, API information, and formatting are committed. If you create your own application from this GitHub Template, you may rename the MoonBit module in `moon.mod` before publishing it under your own name.
