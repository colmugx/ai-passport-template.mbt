---
name: ai-passport-firmware-development
description: Turn product ideas into portable MoonBit applications and FoloToy AI Passport firmware using colmugx/ai-passport. Use when a user asks to create, implement, modify, debug, build, or flash an AI Passport app, game, toy, utility, interactive experience, animation, audio experience, microphone-reactive experience, or low-power experience.
---

# AI Passport Firmware Development

Use `colmugx/ai-passport` to turn a user's product idea into a working AI Passport application.

The user is describing a product, not an SDK implementation. Translate the idea into SDK capabilities yourself. Do not require the user to understand MoonBit, Hosts, `Application`, RGB565, PCM, ESP-IDF, or firmware structure.

Prefer completing a coherent product over asking implementation questions. Choose sensible defaults when details such as colors, frame rate, menu layout, or exact button mapping are unspecified.

## 1. Inspect the project before coding

For an existing project, inspect at least:

- `moon.mod`
- `passport.toml`
- the package named by `entry`
- `.gitignore`
- existing tests
- sound declarations and the generated-sound package, if present

Read the exact `colmugx/ai-passport@VERSION` from `moon.mod` and use the same version for every `moonx colmugx/ai-passport/cmd/passport@VERSION` command.

Do not assume an old SDK shape. The current template uses AI Passport 0.2.3, but an existing downstream project may intentionally use another version.

## 2. Ensure the MoonBit toolchain exists

Do not assume `moon` or `moonx` is installed.

On Linux or macOS:

```sh
command -v moon
moon version --all
```

On Windows PowerShell:

```powershell
Get-Command moon -ErrorAction SilentlyContinue
moon version --all
```

If `moon` already exists, do not reinstall it.

If it is missing, install the official toolchain.

Linux and macOS:

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
```

Windows PowerShell:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
```

If the user is in mainland China, the environment is known to use CN network access, or the `.com` endpoint fails because of regional access, replace `cli.moonbitlang.com` with `cli.moonbitlang.cn`.

Linux and macOS CN endpoint:

```sh
curl -fsSL https://cli.moonbitlang.cn/install/unix.sh | bash
```

Windows PowerShell CN endpoint:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; irm https://cli.moonbitlang.cn/install/powershell.ps1 | iex
```

After installation, verify again:

```sh
moon version --all
```

If installation succeeded but the current shell cannot find `moon`, refresh the shell environment or PATH as instructed by the installer. Do not repeatedly reinstall the toolchain to solve a stale PATH.

Do not continue to project checks or Host builds until `moon` is available.

## 3. Translate the product idea into capabilities

Internally derive:

```text
product purpose
main interaction loop
screens / states
Up behavior
Down behavior
Ok behavior
click / double-click / long-press behavior
time-based behavior
visual style
sound playback needs
microphone input needs
battery relevance
backlight behavior
sleep / wake behavior
persistent-data needs
network / BLE needs
external assets
```

Do not make the user fill out this checklist.

Start from the user's product fantasy and map it to the SDK. Do not start from Forest Walk, Pocket Breather, or another example application.

## 4. AI Passport 0.2 capability map

### Display and graphics

Applications can query the active display:

```moonbit
let info = @graphics.display_info()
let canvas = @graphics.Canvas::for_display()
```

`DisplayInfo` contains:

```text
width
height
monochrome
has_backlight
```

The current Web and FoloToy Hosts expose a 240×320 drawing surface. Do not hard-code that as a universal future Host assumption when `display_info()` can supply the dimensions.

Prefer `Canvas::for_display()` for product applications. `Canvas::logical()` currently uses the SDK default 240×320 dimensions, while `Canvas::new(width~, height~)` creates an explicitly sized canvas.

Drawing primitives include:

```text
clear
pixel
line
rect
fill_rect
sprite
text
```

Colors are authored with:

```moonbit
@core.Color::rgb(r=..., g=..., b=...)
```

and are presented as RGB565 on the current color Hosts.

The built-in bitmap font supports:

```text
A-Z
0-9
space
-
:
%
.
!
```

Lowercase renders as uppercase. Unknown glyphs consume advance width but draw nothing. Do not assume Chinese, Japanese, emoji, arbitrary Unicode, or arbitrary fonts work through `Canvas::text`. For unsupported glyphs, provide application-owned bitmap/sprite art.

For pixel art, convert source art into MoonBit sprite data outside the runtime rather than adding image decoders to firmware.

### Backlight

Backlight is an optional display capability:

```moonbit
let current = @graphics.backlight_level()
let changed = @graphics.set_backlight(50)
```

`backlight_level()` returns `None` for a display without a light.

`set_backlight(level)` accepts `0..100` and returns `false` when the Host has no backlight.

Prefer checking `display_info().has_backlight` when backlight behavior is part of the product. Lack of a backlight is a valid Host capability combination, not an error.

### Buttons and gestures

Portable buttons are exactly:

```text
Up
Down
Ok
```

Never use GPIO or ADC identities in application code.

AI Passport 0.2 exposes both the compatibility edge callback and semantic gesture events:

```moonbit
button(Self, @input.Button, Bool) -> Unit

button_event(
  Self,
  @input.Button,
  @input.ButtonEvent,
) -> Unit
```

`ButtonEvent` values are:

```text
Press
Click
DoubleClick
LongPress
```

Use `button_event` when the product asks for click, double-click, or long-press semantics.

Use `button` and `InputState` when the product specifically needs lower-level press/release state such as held movement.

Do not reconstruct click, double-click, or long-press recognition with application timers when the Host already supplies semantic events.

On the Web Host, gesture recognition uses independent per-button state with:

```text
double-click window: 300 ms
long-press threshold: 1500 ms
```

The FoloToy Host forwards the recognized button events produced by its pinned BSP.

Do not design portable physical button chords for the FoloToy AI Passport. Its three buttons share one ADC ladder and simultaneous button combinations cannot be identified reliably.

### Time

Each update receives:

```moonbit
FrameContext {
  now_us : Int64
  presentation_lead_us : Int64
}
```

`now_us` is monotonic Host time in microseconds.

Use deltas:

```text
first update:
  remember now_us
  elapsed = 0

later:
  delta = max(now_us - previous_now_us, 0)
```

Use this for animation, timers, cooldowns, games, physics, blinking, breathing, and state transitions.

The application owns its simulation policy. Use a fixed-step accumulator when gameplay or simulation must not depend on Host frame rate.

`presentation_lead_us` is a Host calibration fact for playback-position-driven presentation. Use it when needed without checking Host identity.

### Battery

`render` receives:

```moonbit
battery_percent : Int?
```

`Some(0..100)` is a Host reading and `None` means unavailable.

Do not invent device battery APIs or fake readings in product code.

### Sound playback

Packaged sound resources use typed `Sound` values and independent `Playback` handles:

```moonbit
@audio.play(sound, looping=...)
@audio.pause(playback)
@audio.resume(playback)
@audio.stop(playback)
@audio.position(playback)
```

A `Sound` is a resource. A `Playback` is one live playback instance.

The FoloToy Host provides four playback slots. The Web Host currently provides eight. Design portable applications around at most four simultaneous playbacks.

Sound source files must already be:

```text
signed PCM16
little-endian
mono
16000 Hz
headerless
```

The SDK does not decode MP3, WAV, Ogg, or MIDI and does not provide synthesis, resampling, sequencing, or streaming sound sources.

A no-audio application should return `None` from `audio_output()`. Do not create fake volume or mute state.

### Microphone capture

AI Passport 0.2 exposes portable microphone capture:

```moonbit
@audio.capture_start()
@audio.capture_status()
@audio.capture_read(buffer)
@audio.capture_stop()
@audio.capture_dropped_samples()
```

Capture samples are signed PCM16 mono at:

```moonbit
@audio.CAPTURE_SAMPLE_RATE_HZ // 16000
```

`CaptureStatus` is:

```text
Unavailable
Idle
Requesting
Recording
Denied
Failed
```

On Web, `capture_start()` may return `Requesting` while browser permission is pending. Poll `capture_status()` before reading.

Call `capture_read` only while status is `Recording` and provide a non-empty `FixedArray[Int]`.

Use `capture_dropped_samples()` when sample loss matters to the product.

Microphone capture enables products such as audio meters, clap/sound-reactive toys, simple audio analysis, and microphone-driven game mechanics.

Microphone capture does not imply persistent recording storage. The portable SDK still has no filesystem or persistent key-value storage API.

### Power and wake

AI Passport 0.2 exposes application-requested sleep:

```moonbit
@power.request_sleep()
@power.request_timed_sleep(ms)
@power.wake_reason()
```

`WakeReason` values are:

```text
Button
Timer
Other
```

`request_timed_sleep(ms)` accepts 1 through 86,400,000 milliseconds.

Sleep takes effect after the current presented frame.

On FoloToy this maps to ESP32-C3 light sleep. Application state and playback positions survive. The Host turns the backlight off while asleep and restores the previous light level after wake. Microphone capture stops and must be requested again if the product still needs it.

The Web Host simulates the same portable application lifecycle; it does not claim to control computer hardware power.

### Capabilities not currently exposed to portable applications

Do not invent public APIs for:

```text
Wi-Fi / HTTP / Internet access
Bluetooth / BLE
persistent key-value storage
filesystem access
RTC / wall-clock date and time
touch input
accelerometer / IMU
arbitrary GPIO
camera
dynamic downloadable content
generic application file loading
```

The FoloToy hardware may physically contain capabilities that are not exposed through the portable SDK. Do not bypass the SDK by moving product behavior into Host or ESP-IDF code.

If an unsupported capability is peripheral, implement the useful supported product and report the limitation. If it is the core requirement, identify the missing SDK capability instead of fabricating an implementation.

## 5. Create a downstream project, not an SDK patch

A normal product is an independent MoonBit module that depends on the published SDK.

Do not put application semantics into `ai-passport.mbt`.

Do not require `ai-passport-template.mbt`; it is reference material.

For a new standalone project, a conventional layout is:

```text
moon.mod
passport.toml
src/
  app/
    app.mbt
    app_wbtest.mbt
    moon.pkg
```

For an existing project or a project created from the template, preserve its existing MoonBit source-root layout instead of moving packages gratuitously.

A new `moon.mod` can use:

```moonbit
name = "OWNER/APP"
version = "0.0.1"
source = "src"

import {
  "colmugx/ai-passport@0.2.3",
}
```

`passport.toml`:

```toml
entry = "app"
```

The entry is relative to the module source root.

Generated Host adapters belong at:

```text
<source-root>/passport-generated/
```

Host build workspaces belong at:

```text
.passport/
```

Do not hand-edit either.

## 6. Implement the Application contract

The entry package implements:

```moonbit
@application.Application
```

and exports:

```moonbit
pub fn passport_main() -> &@application.Application
```

The current contract is:

```text
update(Self, FrameContext) -> Unit
button(Self, Button, Bool) -> Unit
button_event(Self, Button, ButtonEvent) -> Unit   // default implementation exists
render(Self, Int?) -> FrameView
audio_output(Self) -> AudioOutput?
```

Keep concrete product state private unless another package genuinely needs it.

A typical app owns:

```moonbit
priv struct App {
  canvas : @graphics.Canvas
  mut last_now_us : Int64?
  // product state...
}
```

Construct the display canvas after Host boot, normally with:

```moonbit
canvas: @graphics.Canvas::for_display()
```

Use `update` for time and simulation, `button` / `button_event` for input, and `render` only to draw current state.

Do not advance simulation from `render`.

## 7. Add sounds only when needed

Declare sounds in `passport.toml`:

```toml
[[sounds]]
name = "click"
source = "assets/click.pcm"
```

Create an application-owned package for generated typed Sound values. With packages under `src/`:

```moonbit
import {
  "colmugx/ai-passport/audio",
}

rule(
  name: "passport-sounds",
  command: "moonx colmugx/ai-passport/cmd/passport@0.2.3 generate-sounds $input $output",
)

dev_build(
  rule: "passport-sounds",
  input: "../../passport.toml",
  output: "generated.mbt",
)
```

Adjust the relative input path when the package layout differs.

Import the generated package as `@sounds` and use typed constructors:

```moonbit
let click = @audio.play(@sounds.Click)
let music = @audio.play(@sounds.Music, looping=true)
```

Never hand-author numeric Sound IDs.

Looping and playback control belong in application code, not `passport.toml` resource metadata.

## 8. Static art and ordinary assets

`passport.toml` can bundle ordinary files with `[[assets]]`, but that does not create a generic MoonBit filesystem API.

Do not assume the application can call `open("assets/foo.png")`.

For fixed art used by rendering, prefer converting source images during development into application-owned MoonBit sprite/palette data.

## 9. Test product behavior

Use MoonBit tests for product semantics.

`*_test.mbt` is black-box.

`*_wbtest.mbt` is white-box and can test private application state/helpers.

Do not make internals public only to satisfy tests.

Test the requirements that matter for the product, for example:

- screen/state transitions
- button gestures
- held-button behavior
- fixed-step timing boundaries
- pause/resume behavior
- animation wraparound
- backlight level policy
- microphone status and empty-read behavior
- sleep request and wake-state logic
- audio slot/playback failure fallback
- unavailable battery behavior

Do not test raw GPIO or browser key codes inside the application package.

## 10. Build and validate

After implementation:

```sh
moon update
moon check --output-json
moon test --output-json
moon info
moon fmt
```

Fix errors before Host builds.

### Web

Use the SDK version from `moon.mod`:

```sh
moonx colmugx/ai-passport/cmd/passport@VERSION doctor --host web
moonx colmugx/ai-passport/cmd/passport@VERSION build --host web
```

For interactive development:

```sh
moonx colmugx/ai-passport/cmd/passport@VERSION dev --host web
```

Exercise relevant product behavior, including gestures, audio, microphone permission states, backlight, and sleep/wake when the application uses them.

Do not edit SDK-owned Web Host files to repair product logic.

### FoloToy firmware

```sh
moonx colmugx/ai-passport/cmd/passport@VERSION doctor --host folotoy-ai-passport
moonx colmugx/ai-passport/cmd/passport@VERSION build --host folotoy-ai-passport
```

Current FoloToy Host facts include:

```text
ESP32-C3
8 MB flash
no PSRAM
240×320 ST7789P3 display
adjustable backlight
Up / Down / Ok semantic buttons
press / click / double-click / long-press events
battery gauge
PCM16 playback
PCM16 microphone capture
application-requested light sleep
ESP-IDF 5.5.3
factory app partition: 0x380000 = 3,670,016 bytes
```

The CLI owns ESP-IDF glue, device bridges, BSP integration, generated adapters, and firmware assembly. Application code owns none of these.

The build command does not flash.

After a successful build, the generated workspace provides:

```sh
.passport/folotoy-ai-passport/flash.sh -p PORT
.passport/folotoy-ai-passport/monitor.sh -p PORT
```

Only claim physical validation after actual flashing and on-device exercise.

## 11. Host dependency resolution

A normal application does not need to vendor the FoloToy repository.

Without an override, the CLI resolves its pinned dependency under:

```text
.passport/deps/
```

Only add:

```toml
[hostDependencies."folotoy-ai-passport"]
path = "external/folotoy-ai-passport"
```

when the project intentionally owns that checkout.

Do not add a submodule merely because an older template or reference project had one.

## 12. Firmware-size discipline

Device build output reports values such as:

```text
passport: size: ... bytes
passport: app partition margin: ... bytes
```

Record exact byte counts.

Keep these scopes distinct:

```text
application partition binary
sound/resource bank
merged Full Flash image from 0x0
```

Do not compare different binary scopes as if they were the same thing.

Large PCM resources often dominate firmware size; product logic complexity and firmware bytes are not linearly related.

## 13. One-shot behavior for Codex

When the user gives a supported product idea, do not ask implementation-detail questions such as:

```text
What should Up do?
Which frame rate should I use?
Should I use InputState?
Should I use Canvas::logical or Canvas::for_display?
What folder structure should I choose?
```

Those are implementation decisions.

Choose coherent defaults and build the product.

Ask only when missing information fundamentally changes the product, when required external content is unavailable, or before a destructive/repository-overwriting action that requires user intent.

## 14. Work in this order

```text
1. Understand the product idea.
2. Inspect the project and SDK version.
3. Ensure MoonBit is installed.
4. Map requirements to current SDK capabilities.
5. Identify genuine unsupported requirements.
6. Design product state, screens, gestures, timing, audio/mic, and power behavior.
7. Implement the portable MoonBit application.
8. Add assets/sounds only when required.
9. Add tests.
10. Run MoonBit checks and tests.
11. Build and exercise Web.
12. Run FoloToy doctor.
13. Build firmware.
14. Record firmware size and partition margin.
15. Flash only when requested/available.
16. Report exactly what was validated.
```

Do not start from ESP-IDF, Host glue, or an existing example application's architecture.

## 15. Completion evidence

Report validation categories separately:

```text
MoonBit check: PASS / FAIL
MoonBit tests: PASS / FAIL

Web build: PASS / FAIL
Web runtime exercised: YES / NO

FoloToy doctor: PASS / FAIL
FoloToy firmware build: PASS / FAIL

Firmware app size: N bytes
Partition margin: N bytes

Physical flash: YES / NO
Physical behavior tested: YES / NO
```

Never replace a missing evidence category with another one.

## 16. Public API quick reference

### Graphics

```text
display_info()
backlight_level()
set_backlight()

Canvas::for_display()
Canvas::logical()
Canvas::new()

clear
pixel
line
rect
fill_rect
sprite
text
frame_view

SpriteSheet::from_colors()
text_width()
text_height()
```

### Input

```text
Button::Up
Button::Down
Button::Ok

ButtonEvent::Press
ButtonEvent::Click
ButtonEvent::DoubleClick
ButtonEvent::LongPress

InputState::new()
press
release
pressed
just_pressed
just_released
advance
```

### Application

```text
FrameContext {
  now_us
  presentation_lead_us
}

Application {
  update
  button
  button_event
  render
  audio_output
}
```

### Audio

```text
play
pause
resume
stop
position

capture_start
capture_status
capture_read
capture_stop
capture_dropped_samples
CAPTURE_SAMPLE_RATE_HZ
```

### Power

```text
request_sleep
request_timed_sleep
wake_reason
```

## Final rule

The user's idea is the application.

`ai-passport.mbt` is the portable capability layer used to realize it.

Do not constrain the idea to examples that already exist. Use the SDK primitives to build the user's product.
