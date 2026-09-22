# AI Passport application template

A runnable MoonBit starter project for building applications that run on AI Passport Hosts.

The template currently includes **Forest Walk** as a complete example with graphics, semantic input, battery state, looping audio, and synchronized animation. Replace its application behavior with your own product while keeping the same portable application boundary.

The current SDK/CLI dependency is:

```text
colmugx/ai-passport@0.2.2
```

## Start here

Create a repository from this template, then update the module metadata in `moon.mod`.

Install dependencies and verify the MoonBit project:

```sh
moon update
moon check
moon test
```

Run the application in the Web Host:

```sh
moonx colmugx/ai-passport/cmd/passport@0.2.2 dev
```

Then open:

```text
http://127.0.0.1:8000/index.html
```

Build the same MoonBit application for the physical FoloToy AI Passport Host:

```sh
moonx colmugx/ai-passport/cmd/passport@0.2.2 doctor --host folotoy-ai-passport
moonx colmugx/ai-passport/cmd/passport@0.2.2 build --host folotoy-ai-passport
```

The build creates:

```text
.passport/folotoy-ai-passport/
```

and does not flash automatically.

With a board connected:

```sh
.passport/folotoy-ai-passport/flash.sh -p PORT
.passport/folotoy-ai-passport/monitor.sh -p PORT
```

## Project structure

This template currently uses the MoonBit module root as its source root:

```text
moon.mod
passport.toml

app/
  app.mbt
  application.mbt
  moon.pkg

forest_walk/
  ...

sounds/
  moon.pkg

assets/
  forest_walk.pcm
```

Generated Host adapters are written under:

```text
passport-generated/
```

Host workspaces and resolved build dependencies are written under:

```text
.passport/
```

Those are build output and should not be hand-edited.

## Application contract

`passport.toml` selects the application package:

```toml
entry = "app"
```

With this template's current source-root layout, that means the application lives at:

```text
app/
```

The package implements:

```text
colmugx/ai-passport/application.Application
```

and exports:

```moonbit
pub fn passport_main() -> &@application.Application
```

AI Passport 0.2 applications receive:

- monotonic Host time
- Host presentation calibration
- semantic `Up`, `Down`, and `Ok` input
- recognized `Press`, `Click`, `DoubleClick`, and `LongPress` events
- best-effort battery percentage

and can use portable display, backlight, sound playback, microphone capture, and sleep/wake capabilities.

Application code should not contain browser APIs, ESP-IDF code, GPIO numbers, display-controller code, or other Host implementation details.

The Web and FoloToy Hosts run the same application semantics.

## Display and input

AI Passport 0.2 exposes the active display through:

```moonbit
let info = @graphics.display_info()
let canvas = @graphics.Canvas::for_display()
```

The current Web and FoloToy Hosts provide **240×320** pixels.

Backlight is optional:

```moonbit
@graphics.backlight_level()
@graphics.set_backlight(50)
```

Input remains semantic:

```text
Up
Down
Ok
```

For gesture-oriented products, implement `button_event` and handle:

```text
Press
Click
DoubleClick
LongPress
```

Use the lower-level `button(button, pressed)` / `InputState` path when the product specifically needs press/release or held state.

The FoloToy buttons share one ADC ladder, so portable products should not depend on physical button chords.

## Applications without audio

Audio is optional.

A normal AI Passport application can contain no sound resources and return:

```moonbit
None
```

from `audio_output()`.

You do not need to keep Forest Walk's audio setup when your product does not use audio.

## Sounds

Forest Walk demonstrates the typed Sound workflow.

`passport.toml` declares:

```toml
[[sounds]]
name = "forest_walk"
source = "assets/forest_walk.pcm"
```

Sound input is prepared outside the SDK as:

```text
signed PCM16 little-endian
mono
16000 Hz
headerless
```

`sounds/moon.pkg` runs the co-versioned generator:

```moonbit
rule(
  name: "passport-sounds",
  command: "moonx colmugx/ai-passport/cmd/passport@0.2.2 generate-sounds $input $output",
)

dev_build(
  rule: "passport-sounds",
  input: "../passport.toml",
  output: "generated.mbt",
)
```

Application code then uses the generated typed value:

```moonbit
@audio.play(@sounds.ForestWalk, looping=true)
```

The returned `Playback` identifies that playback instance. Pause, resume, stop, and position operations target the `Playback`, not the Sound resource globally.

Looping is playback behavior and is selected by `play`, not stored in `passport.toml`.

## Microphone capture

AI Passport 0.2 also exposes microphone capture:

```moonbit
@audio.capture_start()
@audio.capture_status()
@audio.capture_read(buffer)
@audio.capture_stop()
@audio.capture_dropped_samples()
```

Capture is signed PCM16 mono at 16000 Hz.

On Web, microphone permission may temporarily leave capture in `Requesting`. Read only while status is `Recording`.

This supports live audio-reactive products. It does not provide persistent recording storage.

## Power

Applications may request sleep with:

```moonbit
@power.request_sleep()
@power.request_timed_sleep(ms)
@power.wake_reason()
```

On FoloToy, this maps to light sleep. Application state and playback position survive; microphone capture stops and should be restarted after wake if the product still needs it.

## Forest Walk example

The included Forest Walk application demonstrates:

- portable MoonBit application state
- semantic input
- Host battery display
- fixed-step simulation
- looping typed Sound playback
- animation synchronized to a particular Playback position
- fallback visual timing when playback position is unavailable
- Host-provided presentation lead without checking Host identity

Its committed scenery targets the full **240×320** Host surface, but the three large parallax layers are stored as **120×160 indexed samples** and presented at **2× nearest-neighbour scale** into the 240×320 Canvas. This keeps the SDK/Host coordinate system full-resolution while reducing retained scenery-index RAM from 230.4 KB to 57.6 KB on the no-PSRAM ESP32-C3. The fairy sprite, HUD and final Canvas remain full-resolution.

The source PNGs and repeatable converters live under `assets/forest_walk/` and
`tools/compile_*.py`. They are local authoring inputs and are intentionally
ignored by Git; the generated runtime data remains in `forest_walk/generated.mbt`.
When that local authoring kit is present, run `tools/compile_assets.sh` after
changing the art.

Its committed audio resource is:

```text
assets/forest_walk.pcm
```

with a size of 2,444,800 bytes and duration of approximately 76.4 seconds at PCM16 LE mono 16000 Hz.

Forest Walk is an example application, not part of the AI Passport SDK contract. You can replace it completely.

## `passport.toml`

The template currently contains:

```toml
entry = "app"

[[sounds]]
name = "forest_walk"
source = "assets/forest_walk.pcm"
```

The template does not currently vendor a project-owned FoloToy checkout.

Without a `hostDependencies` override, the Passport CLI resolves its pinned FoloToy dependency under:

```text
.passport/deps/
```

## Web build

To create a Web bundle without starting the development server:

```sh
moonx colmugx/ai-passport/cmd/passport@0.2.2 doctor --host web
moonx colmugx/ai-passport/cmd/passport@0.2.2 build --host web
```

The generated Web workspace contains the application Wasm, Host files, sound bank, and declared assets.

The reference page opens at the native **240×320** CSS size so the portrait preview
matches the physical Host. Add `?scale=2` (or another positive integer) to the
URL only when an enlarged pixel preview is useful during development.

A browser may require permission or a user gesture for audio output or microphone capture.

## Development checks

Before committing changes:

```sh
moon update
moon check
moon test
moon info
moon fmt
git diff --exit-code
```

When application behavior changes, exercise it through the Web Host.

When device behavior matters, build the FoloToy Host and test the resulting firmware on physical hardware. A successful firmware build alone is not physical-device validation.

## Creating your own app from the template

A practical sequence is:

1. Rename the module in `moon.mod`.
2. Keep `passport.toml` with `entry = "app"`.
3. Replace Forest Walk state and rendering with your own application.
4. Map `Up`, `Down`, `Ok` and gesture events to your product.
5. Use `Canvas::for_display()` and query display capabilities when creating new UI.
6. Delete Forest Walk sound configuration if your application does not use audio.
7. Add microphone, backlight, or sleep behavior only when the product needs it.
8. Keep application logic independent of Web and FoloToy implementation details.
9. Add tests for product state.
10. Validate Web.
11. Build and test physical hardware.

Additional packages and resources should exist because the product needs them, not because the template happens to demonstrate them.
