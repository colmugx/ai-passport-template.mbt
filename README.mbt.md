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

The browser preview (`src/web` + `web/`) presents the SDK's rasterized 120×160 RGB565 frame through `FrameView` onto an HTML Canvas at 4x scale and plays the showcase song through WebAudio. It is a development preview, not a hardware emulator. A separate ESP32-C3 display smoke-test firmware now builds under `device/esp32c3/`; physical panel behavior has not yet been verified. Device input, audio, and battery work remains future work. Application code stays independent of browser and device APIs; runtimes own those integrations and audio playback.

## ESP32-C3 display smoke firmware

The device project uses ESP-IDF 5.5.3 and a pinned subset of the official FoloToy display BSP. It builds a MoonBit probe and an SDK `Canvas::logical()` color test; it does not run Forest Walk. The 120×160 RGB565 frame is copied through an SDK `DisplaySink` into a 240×16 RGB565 DMA strip and presented at exact 2× scale. Backlight starts at 60%. The firmware logs the probe result and full-frame `present_us` with an approximate present-FPS ceiling. Physical colors, orientation, and actual latency still require a board test.

After installing the pinned MoonBit toolchain and sourcing ESP-IDF 5.5.3's `export.sh`:

```sh
./device/build.sh
./device/flash.sh -p PORT    # only with the board connected
./device/monitor.sh -p PORT
```

`device/build.sh` verifies the MoonBit runtime source hashes, runs a native Moon build with the device package's `options.link.native.cc` pointing to `tools/moon_cc_capture.py`, and then runs ESP-IDF. The wrapper captures Moon-generated C under the ignored `device/esp32c3/generated/` directory. ESP-IDF compiles that C and the matching MoonBit runtime source with `riscv32-esp-elf-gcc`; no host MoonBit object or manually built archive enters the firmware. See [device/esp32c3/README.md](device/esp32c3/README.md) for the toolchain pins and build contract.

## Browser preview

One command builds the MoonBit JS target and serves the preview:

```sh
./dev.sh          # serves http://localhost:8000/  (PORT=9000 ./dev.sh to change)
```

Requires the MoonBit toolchain and `python3` (used only as the static file server); no npm dependencies. The script builds `src/web` for the JS target, assembles the bundle into `web/dist/`, and serves the `web/` directory. Open the printed URL in a browser.

Controls:

| Key | Action |
| --- | --- |
| ArrowUp | Increase walking speed (0–3) |
| ArrowDown | Decrease walking speed |
| Space / Enter | Pause / resume animation and sound |

The scene starts walking immediately at speed 1. Click **Enable sound** to unlock WebAudio and start the song from its beginning; the nearby status shows whether sound is active. Browsers require this user gesture before audio can play. Space or Enter pauses both animation and sound; pressing either again resumes them. Before sound is enabled, the preview still animates using a temporary visual beat clock, and pausing does not start sound. The battery HUD shows a fixed `82%` fixture supplied by the browser runtime.

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

The application updates at a fixed 30 Hz simulation rate driven by `requestAnimationFrame` (elapsed time is accumulated and capped after tab suspension); drawing happens every animation frame. Keyboard events map `ArrowUp`/`ArrowDown`/`Space`/`Enter` to SDK `@input` buttons with press/release edges; `InputState::advance` is called exactly once per simulation step. The fairy advances one of its six poses every four active simulation frames, completing a walk cycle in about 0.8 seconds. An independent WebAudio scheduler renders 512-sample, 16 kHz mono PCM blocks from the SDK `Player` and keeps a short playback queue. Once sound starts, the runtime supplies the beat at the WebAudio playback head, derived from elapsed audio-context sample time and the song tempo; it does not use the Player's render-ahead beat. Pausing or hiding the tab suspends WebAudio so the audible timeline stays frozen.

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
