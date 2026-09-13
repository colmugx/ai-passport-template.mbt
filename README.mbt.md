# AI Passport application template

This repository is a GitHub Template for AI Passport applications. Forest Walk (`src/forest_walk`) is the starter and reference application: a 120×160 logical scene with a scrolling forest, a four-frame walker, button-controlled speed and pause, a battery percentage HUD, and a four-voice showcase song. The scene uses the reusable [AI Passport SDK](https://github.com/colmugx/ai-passport.mbt) through its public MoonBit APIs.

`moon.mod` depends on the published Mooncakes package `colmugx/ai-passport@0.0.1`. Run `moon update` to resolve it. No local SDK workspace is needed to build or test this template, including in CI.

```text
Forest Walk application logic
         |
         v
colmugx/ai-passport SDK
      /          \
 Web runtime   Device runtime
```

The browser preview (`src/web` + `web/`) presents the SDK's rasterized 120×160 RGB565 frame through `FrameView` onto an HTML Canvas at 4x scale and plays the showcase song through WebAudio. It is a development preview, not a hardware emulator. ESP-IDF/FoloToy BSP integration and device audio remain future work. Application code stays independent of browser and device APIs; runtimes own those integrations and audio playback.

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

The application updates at a fixed 30 Hz simulation rate driven by `requestAnimationFrame` (elapsed time is accumulated and capped after tab suspension); drawing happens every animation frame. Keyboard events map `ArrowUp`/`ArrowDown`/`Space`/`Enter` to SDK `@input` buttons with press/release edges; `InputState::advance` is called exactly once per simulation step. An independent WebAudio scheduler renders 512-sample, 16 kHz mono PCM blocks from the SDK `Player` and keeps a short playback queue. Once sound starts, the walk cycle uses the beat at the WebAudio playback head, derived from elapsed audio-context sample time and the song tempo. It does not use the Player's render-ahead beat. Pausing or hiding the tab suspends WebAudio so the audible timeline stays frozen.

## Develop

Install the MoonBit toolchain, then run:

```sh
moon update
moon check --target native --output-json
moon test --target native --output-json
moon check --target js --output-json
moon test --target js --output-json
moon info
moon fmt
moon build --target js
git diff --exit-code
```

The last command checks that generated API information and formatting are committed. If you create your own application from this GitHub Template, you may rename the MoonBit module in `moon.mod` before publishing it under your own name.
