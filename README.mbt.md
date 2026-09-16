# AI Passport application template


`moon.mod` depends on the published Mooncakes package `colmugx/ai-passport@0.0.3`. Run `moon update` to resolve it. No local SDK workspace is needed to build or test this template, including in CI.

```text
Forest Walk application logic (src/forest_walk + src/app, shared)
         |
         v
colmugx/ai-passport SDK
      /          \
 runtime_wasm  src/device
 (wasm -> SDK   (ESP-IDF/BSP)
  Web Host)
```

Browser execution is the shared MoonBit App compiled to `app.wasm` and run by the SDK Web Host: the bundle's only page is the SDK's own `index.html`, whose DOM auto-boot in `passport-host.js` instantiates the wasm app and is configured generically through URL parameters (`?pcm=...&pcmLoop=1`). The template owns no browser bootstrap JavaScript of its own. The ESP32-C3 foundation has already shown the MoonBit probe and RGB smoke screen on a physical FoloToy board. The T4.0-B firmware builds the same root Forest Walk application for device presentation, T4.1-A adds the real CW2017 battery HUD and flash-resident looping music (audio playback confirmed on the board), and T4.1-B adds the physical volume buttons through the official BSP ADC button driver (UP volume+, DOWN volume−, OK mute; startup volume 80%). Application code stays independent of browser and device APIs; runtimes own those integrations and audio playback.

## ESP32-C3 Forest Walk firmware

The device project uses ESP-IDF 5.5.3 and the official FoloToy BSP, referenced (never copied) through the pinned git submodule at `external/folotoy-ai-passport`: display, shared I2C, CW2017 battery gauge and ES8311 audio. The root module's `src/device` entry imports the authoritative `src/forest_walk` package, with no copied scene or scenery source under `device/`. At boot it initializes the MoonBit runtime, checks the `0xA17E` probe, builds Forest Walk state and presents its SDK `Canvas::logical()` frame. The 120×160 RGB565 frame is copied through an SDK `DisplaySink` into a 240×16 RGB565 DMA strip and presented at exact 2× scale. Backlight starts at 60%. The firmware logs internal heap before and after scene construction, before and after audio initialization, after the first frame and during continuous operation; five-second aggregates include update, draw, present and frame times, achieved FPS, and missed deadlines. The battery HUD reads the real CW2017 gauge once per second and shows `--%` while it is unavailable.

After installing the pinned MoonBit toolchain and sourcing ESP-IDF 5.5.3's `export.sh`:

```sh
./device/build.sh
./device/flash.sh -p PORT    # only with the board connected
./device/monitor.sh -p PORT
```

`device/build.sh` verifies the MoonBit runtime source hashes, runs `moon build src/device --target native --release` with the device package's `options.link.native.cc` temporarily pointed at `tools/moon_cc_capture.py` for that invocation only (the committed `moon.pkg` carries no override, so ordinary host native builds use the standard Moon toolchain), converts the authored music into `generated/forest_walk.pcm`, and then runs ESP-IDF. The wrapper captures Moon-generated C under the ignored `device/esp32c3/generated/` directory. ESP-IDF compiles that C, the matching MoonBit runtime source, and the flash-embedded music PCM with `riscv32-esp-elf-gcc`; no host MoonBit object or manually built archive enters the firmware. See [device/esp32c3/README.md](device/esp32c3/README.md) for the toolchain pins and build contract.

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

The compilers use Python 3's standard library only. Each scenery source receives a deterministic 3:2 cover crop before nearest-neighbour resize to 240×160; the world crop is anchored to the bottom to preserve the road. Sources already at 3:2 keep their full frame. Alpha is thresholded at build time (below 128 becomes fully transparent), and opaque colors are reduced to at most 128 with a deterministic median-cut quantizer. The runtime never loads a PNG: browser and future device builds compile the generated sources under `src/forest_walk/generated/`, which carry one small palette plus one-byte indices per layer. Scenery scrolls with ping-pong tiling (`A | mirror(A) | ...`), so no mirrored copy is stored and no seamless authoring is required. Running the compiler twice without changing the assets produces byte-identical output, which CI verifies with `git diff --exit-code`.

## Forest Walk music

Music is authored as one exported audio file, not as note data. Place exactly one of:

| File | Authoring format |
| --- | --- |
| `assets/audio/forest_walk.wav` | WAV export from a DAW |
| `assets/audio/forest_walk.mp3` | MP3 export from a DAW |

Keeping both is an error unless you explicitly pass `--source` to the
converter. `tools/compile_audio.py` (requires `ffmpeg`) converts the selected
file into the device playback format — signed PCM16 little-endian, mono,
16000 Hz — under the ignored `device/esp32c3/generated/forest_walk.pcm`,
reporting source and generated durations and sizes, refusing tracks over the
`0x280000`-byte device flash budget (the PCM shares the factory app
partition with the firmware), and failing on any conversion error. The
authored file is committed; the generated PCM is not. Both runtimes play
the normalized artifact: the device embeds it, the web bundle serves a
byte-identical copy (`tools/verify_pcm_identity.py` proves all three
copies match). CI installs ffmpeg and runs the same conversion.

## Develop

Install the MoonBit toolchain, then run:

```sh
moon update
./tools/compile_assets.sh
moon check --target native --output-json
moon test --target native --output-json
moon info
moon fmt
git diff --exit-code
```

The last command checks that generated asset sources, API information, and formatting are committed. If you create your own application from this GitHub Template, you may rename the MoonBit module in `moon.mod` before publishing it under your own name.
