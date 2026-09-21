---

name: ai-passport-firmware-development
description: Turn product ideas into portable MoonBit applications and FoloToy AI Passport firmware using colmugx/ai-passport. Use when a user asks to create, implement, modify, debug, build, or flash an AI Passport app, game, toy, utility, interactive experience, animation, or sound-based experience.
---

# AI Passport Firmware Development

Use `colmugx/ai-passport` to turn a user's product idea into a working AI Passport application.

The user is describing a **product**, not an SDK implementation.

They may say:

* "Make a virtual pet."
* "Make a meditation timer."
* "Make Snake."
* "Make something weird that reacts to the buttons."
* "Make a music toy."
* "Make a pocket oracle."
* "Make a game where I raise a mushroom."
* "I have no idea, surprise me."

Translate that intent into the AI Passport SDK yourself.

Do not require the user to understand MoonBit, Hosts, `Application`, frame timing, RGB565, PCM, ESP-IDF, or firmware structure.

## Goal

When the required SDK capabilities exist, finish with a real downstream application that can be built for:

```text id="tgt1"
web
folotoy-ai-passport
```

using the same MoonBit application semantics.

Prefer completing the application over asking implementation questions.

Choose reasonable product defaults when details are unspecified.

Ask the user only when missing information fundamentally changes the product or when required external content cannot reasonably be invented.

---

# 1. First understand the idea

Convert the user's request internally into an application specification.

Do not make the user fill this form.

Derive:

```text id="spec1"
product name
product purpose / fantasy
main interaction loop
screens or states
UP behavior
DOWN behavior
OK behavior
time-based behavior
visual style
animation needs
sound needs
battery relevance
persistent-data needs
network needs
Bluetooth needs
microphone needs
external assets
```

For example:

```text id="spec2"
User:
"Make me a tiny aquarium where I take care of a jellyfish."

Derived:
- one main aquarium screen
- jellyfish has mood / hunger state
- UP changes food
- DOWN changes aquarium decoration
- OK feeds jellyfish
- idle animation driven by monotonic time
- pixel-art jellyfish rendered with sprites/primitives
- optional feeding sound
- battery shown subtly
- session-only state unless persistence becomes available
```

The application architecture comes **after** the product model.

---

# 2. Know what AI Passport v0.1 can actually do

Before implementing an idea, map it onto the public SDK.

The portable application surface currently provides these capabilities.

## Display

Logical display:

```text id="cap-display"
120 × 160
RGB565
```

Use:

```moonbit id="api-display"
@graphics.Canvas::logical()

canvas.clear(...)
canvas.pixel(...)
canvas.line(...)
canvas.rect(...)
canvas.fill_rect(...)
canvas.sprite(...)
canvas.text(...)

canvas.frame_view()
```

Colors:

```moonbit id="api-color"
@core.Color::rgb(r=..., g=..., b=...)
```

### Built-in text

The built-in font is intentionally tiny.

Supported glyphs:

```text id="glyphs"
A-Z
0-9
space
-
:
%
.
!
```

Lowercase renders as uppercase.

Do not assume Chinese, Japanese, emoji, Unicode, arbitrary fonts, or rich typography work through `Canvas::text`.

If the product requires other glyphs, render custom bitmap glyphs as application graphics/sprites.

## Sprites

Use:

```moonbit id="api-sprite"
@graphics.SpriteSheet::from_colors(...)
canvas.sprite(...)
```

Sprite pixels are:

```text id="spritepix"
Color? 
Some(color) = visible pixel
None        = transparent pixel
```

For substantial pixel art, prefer generating MoonBit sprite data rather than manually writing thousands of pixels.

Generated art remains application data, not Host code.

## Buttons

Portable applications receive exactly:

```text id="buttons"
Up
Down
Ok
```

They are semantic buttons.

Use:

```moonbit id="api-input"
@input.InputState::new()
press(...)
release(...)
pressed(...)
just_pressed(...)
just_released(...)
advance()
```

Never use GPIO numbers in application code.

Design the product around three controls.

Useful mappings include:

```text id="patterns-input"
UP / DOWN = selection or adjustment
OK        = confirm / action

UP        = move
DOWN      = move
OK        = jump / fire

UP / DOWN = previous / next
OK        = enter / toggle

UP        = primary action
DOWN      = secondary action
OK        = mode switch
```

The product decides the semantics.

## Time

Each update receives:

```moonbit id="api-time"
FrameContext {
  now_us
  presentation_lead_us
}
```

`now_us` is monotonic Host time in microseconds.

Use differences between timestamps.

Never use the absolute value as elapsed application time.

Typical rule:

```text id="time-rule"
first update:
    remember now_us
    elapsed = 0

later:
    delta = max(now_us - previous_now_us, 0)
```

Use this for:

* animation
* timers
* games
* cooldowns
* blinking
* breathing
* idle behavior
* physics
* state transitions

The application decides its own simulation rate.

It does not need to update game logic exactly once per Host frame.

## Battery

`Application.render` receives:

```moonbit id="api-battery"
battery_percent : Int?
```

Meaning:

```text id="battery-meaning"
Some(0..100) = Host reading
None         = unavailable
```

Use it directly when battery matters to the product.

Do not invent device-specific battery code.

## Sound

AI Passport supports prebuilt sound resources.

Public runtime API:

```moonbit id="api-audio"
@audio.play(sound, looping=...)
@audio.pause(playback)
@audio.resume(playback)
@audio.stop(playback)
@audio.position(playback)
```

`play` returns:

```text id="playback"
Playback?
```

A `Sound` is a resource.

A `Playback` is one live playback instance.

These are not the same object.

### Portable playback budget

The physical FoloToy Host provides four independent playback slots.

The Web Host currently provides eight.

For portable applications, design around **at most four simultaneous playbacks**.

Never assume Web's eight-slot capacity on hardware.

### Sound format

Sound source files must already be:

```text id="pcm"
signed PCM16
little-endian
mono
16000 Hz
headerless
```

The SDK does not provide:

* MP3 decoding
* WAV decoding
* Ogg decoding
* MIDI playback
* synthesis
* oscillators
* resampling
* sequencing
* streaming audio

Prepare media outside the SDK.

### Master audio output

Applications optionally return:

```moonbit id="audiooutput"
Some({
  volume: 0..100,
  muted: Bool,
})
```

or:

```moonbit id="noaudio"
None
```

A product with no sound should simply return `None`.

Do not invent fake audio state.

---

# 3. Know what is NOT currently a portable application capability

Do not invent APIs that do not exist.

The current public application SDK does not expose portable APIs for:

```text id="unsupported"
Wi-Fi / HTTP / Internet access
Bluetooth / BLE
microphone input
recording
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

The FoloToy Host currently leaves Wi-Fi and BLE uninitialized.

Therefore:

### Supported idea

```text id="idea-supported"
"Make a Tamagotchi-like pet."
```

Yes.

Use state, time, buttons, graphics and optional bundled sounds.

### Supported with limitation

```text id="idea-session"
"Make a todo list."
```

Possible as an in-session experience.

Persistent todos are not currently supported by the portable application API.

### Not currently implementable as requested

```text id="idea-weather"
"Show live weather."
```

Live network data requires a portable networking capability that does not currently exist.

### Not currently implementable as requested

```text id="idea-ble"
"Make a Bluetooth radar."
```

BLE is not exposed to portable applications.

### Not currently implementable as requested

```text id="idea-voice"
"Make a voice recorder."
```

Microphone/recording is not exposed to portable applications.

Do not bypass these limitations by placing product logic directly into the FoloToy Host.

That would stop being a portable AI Passport application.

If an unsupported capability is peripheral to the idea, implement the useful supported product without it and clearly report the limitation.

If it is the core product, identify the missing SDK capability instead of fabricating an implementation.

---

# 4. Do not start inside the SDK repository

A normal product is an independent downstream MoonBit project.

Do not put the app into:

```text id="not-in"
ai-passport.mbt
```

and do not require:

```text id="not-required"
ai-passport-template.mbt
```

The template is optional reference material.

A normal application should depend on the published SDK.

For the current v0.1 baseline:

```moonbit id="moonmod"
name = "OWNER/APP"

version = "0.0.1"

source = "src"

import {
  "colmugx/ai-passport@0.1.0",
}
```

When working in an existing project, use the SDK version already declared by that project unless the user explicitly requests an upgrade.

Keep the SDK and CLI co-versioned.

---

# 5. Minimal project

For most applications start here:

```text id="tree-min"
my-app/
├── .gitignore
├── moon.mod
├── passport.toml
└── src/
    └── app/
        ├── app.mbt
        ├── app_wbtest.mbt
        └── moon.pkg
```

`passport.toml`:

```toml id="passport-min"
entry = "app"
```

`src/app/moon.pkg`:

```moonbit id="pkg-min"
import {
  "colmugx/ai-passport/application",
  "colmugx/ai-passport/core",
  "colmugx/ai-passport/graphics",
  "colmugx/ai-passport/input",
}
```

Recommended `.gitignore`:

```gitignore id="gitignore-min"
_build/
.mooncakes/
.passport/
src/passport-generated/
```

Do not add audio, assets, external Host dependencies, generated packages, or extra build machinery unless the product requires them.

---

# 6. Minimal Application wiring

Every application implements:

```moonbit id="contract"
@application.Application
```

with:

```text id="contract-methods"
update
button
render
audio_output
```

and exposes:

```moonbit id="entryfn"
pub fn passport_main() -> &@application.Application
```

A typical application shape is:

```moonbit id="app-shape"
priv struct App {
  canvas : @graphics.Canvas
  input : @input.InputState
  mut last_now_us : Int64?
  // product state...
}
```

Keep the concrete product state private unless another package genuinely needs it.

The public integration surface usually only needs:

```moonbit id="public-surface"
passport_main()
```

### update

Use `update` for:

* elapsed time
* simulation
* state machines
* animation
* timers
* applying latched input

### button

Use `button` to receive semantic transitions:

```moonbit id="button-wiring"
if pressed {
  self.input.press(button)
} else {
  self.input.release(button)
}
```

### render

Use `render` to draw current state.

Rendering should normally not change simulation state.

Return:

```moonbit id="frame"
self.canvas.frame_view()
```

### audio_output

No sound:

```moonbit id="audio-none"
None
```

Sound-enabled product:

```moonbit id="audio-some"
Some({
  volume: self.volume,
  muted: self.muted,
})
```

---

# 7. Translate product concepts into SDK primitives

Codex should perform this translation automatically.

## Menus

Use:

```text id="recipe-menu"
state:
  selected item

UP:
  previous item

DOWN:
  next item

OK:
  activate

graphics:
  text + rect + fill_rect
```

## Animated toy

Use:

```text id="recipe-toy"
state:
  mood
  animation phase
  interaction counters

time:
  FrameContext.now_us deltas

graphics:
  SpriteSheet or primitives

buttons:
  interactions

optional:
  PCM sound effects
```

## Timer

Use:

```text id="recipe-timer"
state:
  running
  accumulated_us
  duration

update:
  accumulate monotonic delta while running

OK:
  start/pause

UP/DOWN:
  adjust duration
```

## Game

Keep game simulation in MoonBit.

Typical state:

```text id="recipe-game"
player
enemies
score
mode
elapsed time
random/game state if needed
```

Use a fixed-step accumulator when gameplay should not depend on Host frame rate.

Do not put game mechanics into Web JavaScript or ESP-IDF code.

## Pixel-art application

Prefer:

```text id="recipe-art"
small generated SpriteSheet data
limited palette
clear visual hierarchy
large interactive targets
few simultaneous text labels
```

Remember the display is only 120×160.

## Sound toy

Declare several Sound resources and use independent Playback handles.

Never encode Sound IDs manually.

---

# 8. Static art and application assets

`passport.toml` supports ordinary bundled assets:

```toml id="assets"
[[assets]]
source = "assets/data.bin"
bundlePath = "assets/data.bin"
```

But this is a bundle contract, **not a generic MoonBit filesystem API**.

Do not assume application code can call something like:

```text id="bad-assets"
open("assets/foo.png")
```

No such portable application API exists.

For art needed directly by MoonBit rendering, prefer converting it at build/development time into application-owned MoonBit data and creating `SpriteSheet` values.

Examples:

```text id="asset-convert"
PNG pixel art
    ↓ conversion tool
MoonBit Color?/palette data
    ↓
SpriteSheet
```

Do not add image decoding to the firmware merely to display fixed art.

---

# 9. Adding sound

Only add this machinery when the product needs audio.

Example:

```text id="audio-tree"
assets/
  click.pcm
  music.pcm

src/
  sounds/
    moon.pkg
```

`passport.toml`:

```toml id="audio-manifest"
entry = "app"

[[sounds]]
name = "click"
source = "assets/click.pcm"

[[sounds]]
name = "music"
source = "assets/music.pcm"
```

`src/sounds/moon.pkg`:

```moonbit id="audio-rule"
import {
  "colmugx/ai-passport/audio",
}

rule(
  name: "passport-sounds",
  command: "moonx colmugx/ai-passport/cmd/passport@0.1.0 generate-sounds $input $output",
)

dev_build(
  rule: "passport-sounds",
  input: "../../passport.toml",
  output: "generated.mbt",
)
```

Import that package from the application:

```moonbit id="audio-import"
"OWNER/APP/sounds" @sounds
```

Then:

```moonbit id="audio-use"
let playback = @audio.play(@sounds.Click)

let music = @audio.play(
  @sounds.Music,
  looping=true,
)
```

Never use:

```text id="bad-sound"
sound id = 0
sound id = 1
```

The generated typed Sound mapping owns resource IDs.

---

# 10. Playback-driven animation

Only use playback position when the product actually needs audio synchronization.

Store the particular playback:

```text id="sync1"
Playback
```

Query:

```moonbit id="sync2"
@audio.position(playback)
```

If presentation should compensate for physical output latency, use:

```text id="sync3"
ctx.presentation_lead_us
```

Do not detect:

```text id="sync-bad"
web
folotoy
browser
hardware
```

inside product logic.

If playback position is unavailable, decide a product-appropriate fallback.

---

# 11. Test product behavior, not Host internals

Use ordinary MoonBit tests for product semantics.

Use:

```text id="tests"
*_test.mbt
```

for black-box package tests.

Use:

```text id="wbtests"
*_wbtest.mbt
```

when tests need private application state or helpers.

Do not make application internals public solely so tests can access them.

Good tests depend on the product.

Examples:

```text id="test-examples"
button navigation wraps correctly
pause stops elapsed time
timer reaches zero once
player cannot leave bounds
game-over transition is deterministic
animation phase changes at boundaries
volume remains in 0..100
missing playback does not crash app
None battery renders safely
```

Do not write tests for GPIO or browser keyboard codes in the application package.

Those belong to Hosts.

---

# 12. Build workflow

After implementation:

```sh id="moon-gates"
moon update
moon check --output-json
moon test --output-json
moon info
moon fmt
```

Fix all errors before Host builds.

Do not stop at "the code looks right".

---

# 13. Web Host

Validate the portable application first through Web.

Use the same CLI version as the SDK dependency.

For v0.1.0:

```sh id="web-build"
moonx colmugx/ai-passport/cmd/passport@0.1.0 doctor --host web
moonx colmugx/ai-passport/cmd/passport@0.1.0 build --host web
```

Generated Web output:

```text id="web-output"
.passport/web/
```

It contains the compiled MoonBit application and SDK-owned Host runtime.

For interactive development:

```sh id="web-dev"
moonx colmugx/ai-passport/cmd/passport@0.1.0 dev --host web
```

Exercise:

```text id="web-check"
startup
UP
DOWN
OK
timers
animations
screen transitions
sound when applicable
battery unavailable/fixture states where relevant
```

Do not edit `passport-host.js` to fix application behavior.

---

# 14. FoloToy firmware

Before building:

```sh id="device-doctor"
moonx colmugx/ai-passport/cmd/passport@0.1.0 doctor --host folotoy-ai-passport
```

Treat `doctor` as authoritative for missing toolchain/project requirements.

Current v0.1 FoloToy Host uses:

```text id="device-facts"
ESP32-C3
8 MB flash
no PSRAM

ESP-IDF 5.5.3

factory app partition:
0x380000
3,670,016 bytes
```

Build:

```sh id="device-build"
moonx colmugx/ai-passport/cmd/passport@0.1.0 build --host folotoy-ai-passport
```

The CLI creates:

```text id="device-workspace"
.passport/folotoy-ai-passport/
```

The CLI owns:

```text id="device-owned"
ESP-IDF Host glue
MoonBit native capture
display bridge
button bridge
battery bridge
audio backend
FoloToy BSP integration
generated application adapter
firmware build
```

The application should own none of these things.

---

# 15. Host dependency resolution

A normal app does not need to vendor the FoloToy repository.

If no override exists, the CLI resolves its pinned FoloToy dependency under:

```text id="dep-path"
.passport/deps/
```

Only add:

```toml id="dep-override"
[hostDependencies."folotoy-ai-passport"]
path = "external/folotoy-ai-passport"
```

when the project intentionally owns that checkout.

Do not add a submodule just because a reference template happens to contain one.

---

# 16. Flashing

Building firmware and flashing firmware are separate actions.

The CLI build does not flash.

After a successful device build, the generated workspace provides:

```sh id="flash"
.passport/folotoy-ai-passport/flash.sh -p PORT
```

and:

```sh id="monitor"
.passport/folotoy-ai-passport/monitor.sh -p PORT
```

Do not claim physical success until the firmware has actually been flashed and exercised on hardware.

---

# 17. Firmware-size discipline

Device build output reports values such as:

```text id="size-report"
passport: size: ... bytes
passport: app partition margin: ... bytes
```

Record them.

The app partition is:

```text id="partition"
0x380000
= 3,670,016 bytes
```

Keep these binary concepts distinct:

```text id="binary-types"
application partition binary
sound bank
full flash / merged image
```

Never compare an app binary directly against an 8 MB Full Flash image and conclude one application is 20× smaller.

When a product includes large PCM resources, expect sound data to dominate firmware size.

Code complexity and firmware size are not the same thing.

---

# 18. Optimize for the user's product, not the template

Do not copy architectural complexity from another application unless this product requires it.

A simple product may need only:

```text id="simple-app"
one App struct
one Canvas
three buttons
monotonic time
a few drawing primitives
```

A complex product may legitimately need:

```text id="complex-app"
multiple product-state modules
sprite data
fixed-step simulation
several screens
multiple Sound resources
several Playback handles
custom bitmap glyphs
large state machines
```

Both are normal.

The SDK should not dictate product imagination.

---

# 19. One-shot implementation behavior for Codex

When a user gives an idea, do not respond by asking:

```text id="bad-questions"
What should UP do?
What color should it be?
Should it animate at 20 or 30 FPS?
What should the folder structure be?
Should I use InputState?
```

Those are implementation choices.

Choose coherent defaults and build the product.

Prefer questions only for things like:

```text id="reasonable-questions"
Which supplied audio file should be used?
Which of these two fundamentally different product meanings did you intend?
Do you want me to overwrite an existing repository?
```

Even then, if a safe and useful default exists, prefer making progress.

---

# 20. Work in this order

For a new product:

```text id="order"
1. Understand the product fantasy.
2. Check required capabilities against the SDK.
3. Identify genuine unsupported requirements.
4. Design state/screens/input internally.
5. Create a minimal downstream MoonBit project.
6. Implement pure product state.
7. Implement semantic buttons.
8. Implement time behavior.
9. Implement rendering.
10. Add sounds only if required.
11. Add tests.
12. Run MoonBit checks/tests.
13. Build Web.
14. Exercise Web behavior.
15. Run FoloToy doctor.
16. Build firmware.
17. Record firmware size and partition margin.
18. Flash only when requested/available.
19. Report exactly what was validated.
```

Do not start from ESP-IDF.

Do not start from Host glue.

Do not start from an existing reference application's architecture.

Start from the user's product.

---

# 21. What "done" means

A successful supported request should ideally leave the user with:

```text id="deliverables"
a standalone MoonBit repository
passport.toml
application source
tests
Web build
FoloToy firmware build
firmware size
partition margin
flash command
short usage instructions
```

Report validation separately:

```text id="evidence"
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

---

# 22. Public API quick reference

## Core

```moonbit id="ref-core"
@core.LOGICAL_WIDTH   // 120
@core.LOGICAL_HEIGHT  // 160

@core.Color::rgb(...)
Color::to_rgb565(...)

Point
Size
Rect
```

## Graphics

```moonbit id="ref-graphics"
Canvas::logical()
Canvas::new(...)

clear
pixel
line
rect
fill_rect
sprite
text

frame_view

SpriteSheet::from_colors(...)

text_width(...)
text_height(...)
```

## Input

```moonbit id="ref-input"
Button::Up
Button::Down
Button::Ok

InputState::new()
press
release
pressed
just_pressed
just_released
advance
```

## Application

```moonbit id="ref-app"
FrameContext {
  now_us : Int64
  presentation_lead_us : Int64
}

Application {
  update
  button
  render
  audio_output
}

AudioOutput {
  volume : Int
  muted : Bool
}
```

## Audio

```moonbit id="ref-audio"
Sound

Playback

play
pause
resume
stop
position
```

---

# 23. Final rule

The user's idea is the application.

`ai-passport.mbt` is merely the portable hardware/software capability layer used to realize it.

Do not constrain the idea to the examples that already exist.

Do not teach the user to build Forest Walk, Pocket Breather, or any other previous application.

Use the SDK primitives to build **their** product.
