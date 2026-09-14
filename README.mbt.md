# AI Passport application template


`moon.mod` depends on the published Mooncakes package `colmugx/ai-passport@0.0.1`. Run `moon update` to resolve it. No local SDK workspace is needed to build or test this template, including in CI.

```text
Forest Walk application logic
         |
         v
colmugx/ai-passport SDK
      /          \
 Web runtime   Device runtime
```

The browser preview (`src/web` + `web/`) presents the SDK's rasterized 120×160 RGB565 frame through `FrameView` onto an HTML Canvas at 4x scale and plays the authored music file through WebAudio. It is a development preview, not a hardware emulator. The ESP32-C3 foundation has already shown the MoonBit probe and RGB smoke screen on a physical FoloToy board. The T4.0-B firmware builds the same root Forest Walk application for device presentation, and T4.1-A adds the real CW2017 battery HUD and flash-resident looping music; live T4.1 device behavior still needs hardware measurement. Device buttons remain future work. Application code stays independent of browser and device APIs; runtimes own those integrations and audio playback.

## ESP32-C3 Forest Walk firmware

The device project uses ESP-IDF 5.5.3 and the official FoloToy BSP, referenced (never copied) through the pinned git submodule at `external/folotoy-ai-passport`: display, shared I2C, CW2017 battery gauge and ES8311 audio. The root module's `src/device` entry imports the authoritative `src/forest_walk` package, with no copied scene or scenery source under `device/`. At boot it initializes the MoonBit runtime, checks the `0xA17E` probe, builds Forest Walk state and presents its SDK `Canvas::logical()` frame. The 120×160 RGB565 frame is copied through an SDK `DisplaySink` into a 240×16 RGB565 DMA strip and presented at exact 2× scale. Backlight starts at 60%. The firmware logs internal heap before and after scene construction, before and after audio initialization, after the first frame and during continuous operation; five-second aggregates include update, draw, present and frame times, achieved FPS, and missed deadlines. The battery HUD reads the real CW2017 gauge once per second and shows `--%` while it is unavailable.

After installing the pinned MoonBit toolchain and sourcing ESP-IDF 5.5.3's `export.sh`:

```sh
./device/build.sh
./device/flash.sh -p PORT    # only with the board connected
./device/monitor.sh -p PORT
```

`device/build.sh` verifies the MoonBit runtime source hashes, runs `moon build src/device --target native --release` with the device package's `options.link.native.cc` temporarily pointed at `tools/moon_cc_capture.py` for that invocation only (the committed `moon.pkg` carries no override, so ordinary host native builds use the standard Moon toolchain), converts the authored music into `generated/forest_walk.pcm`, and then runs ESP-IDF. The wrapper captures Moon-generated C under the ignored `device/esp32c3/generated/` directory. ESP-IDF compiles that C, the matching MoonBit runtime source, and the flash-embedded music PCM with `riscv32-esp-elf-gcc`; no host MoonBit object or manually built archive enters the firmware. See [device/esp32c3/README.md](device/esp32c3/README.md) for the toolchain pins and build contract.

## Browser preview

One command builds the MoonBit JS target and serves the preview:

```sh
./dev.sh          # serves http://localhost:8000/  (PORT=9000 ./dev.sh to change)
```

Requires the MoonBit toolchain and `python3` (used only as the static file server); no npm dependencies. The script builds `src/web` for the JS target, assembles the bundle into `web/dist/`, and serves the `web/` directory. Open the printed URL in a browser.

The ambient scene starts walking and scrolling immediately at 22.5 logical pixels per second. There are no speed or pause controls; ArrowUp, ArrowDown, Space and Enter are unused. Click **Enable sound** to unlock WebAudio: the preview fetches the authored music file, decodes it natively in the browser and loops it; the nearby status shows whether sound is active. Browsers require this user gesture before audio can play. Before sound is enabled, the preview still animates using a temporary visual beat clock. The battery HUD shows a fixed `82%` fixture supplied by the browser runtime.

How a frame reaches the screen (the SDK rasterizer stays authoritative; the browser never redraws SDK content with Canvas2D primitives):

```text
Forest Walk State::draw
  -> SDK @graphics.Canvas (logical 120x160)
  -> Canvas::frame_view()          (RGB565 framebuffer view)
  -> FrameView::copy_rgb565_row    (row by row, reused scratch buffers)
  -> RGB565 -> RGBA conversion     (exact bit replication, alpha 255)
  -> persistent ImageData + putImageData (1:1 onto the 120x160 canvas)
  -> CSS integer scaling to 480x640 with image-rendering: pixelated
```

The application updates at a fixed 30 Hz simulation rate driven by `requestAnimationFrame` (elapsed time is accumulated and capped after tab suspension); drawing happens every animation frame. The fairy pose is beat-locked to the music: one pose per eighth note, completing one full walk cycle per 6/8 bar (about 1.58 seconds at the 76 dotted-quarter-BPM tempo, i.e. quarter-note 114). Music is file-based: `dev.sh` copies the single authored WAV or MP3 into the preview bundle and the browser decodes and loops it natively — no PCM synthesis runs in the preview. Once sound starts, the runtime supplies the musical position from the audible WebAudio playback head (loop position wrapped at the track duration) against the application's music tempo, and the fairy pose follows it directly; before sound is enabled, a temporary visual clock supplies the same eighths. Hiding the tab suspends WebAudio so the audible timeline stays frozen.

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
authored file is committed; the generated PCM is not. The browser preview
plays the authored file directly with native decoding. CI installs ffmpeg
and runs the same conversion.

## Develop

Install the MoonBit toolchain, then run:

```sh
moon update
./tools/compile_assets.sh
moon check --target native --output-json
moon test --target native --output-json
moon check --target js --output-json
moon test --target js --output-json
moon info
moon fmt
moon build --target js
git diff --exit-code
```

The last command checks that generated asset sources, API information, and formatting are committed. If you create your own application from this GitHub Template, you may rename the MoonBit module in `moon.mod` before publishing it under your own name.
