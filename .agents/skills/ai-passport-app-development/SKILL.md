---

name: ai-passport-app-development
description: Build, modify, debug, test, and validate portable MoonBit applications for AI Passport. Use when creating a downstream AI Passport app, adapting an existing app, working from ai-passport-template.mbt, debugging Web or FoloToy builds, adding graphics/input/audio, or validating firmware on real hardware.
---

# AI Passport App Development

The application owns product behavior. The AI Passport SDK and its Hosts own platform integration.

Do not put application semantics into the SDK, Host, generated adapters, ESP-IDF glue, browser glue, GPIO code, or device-specific branches.

## Start by discovering the project contract

Before editing code, inspect:

* `moon.mod`
* `passport.toml`
* `src/app/`
* the declared `colmugx/ai-passport` version
* any sound package and `[[sounds]]` entries
* `.gitignore`
* existing tests

Do not assume an old AI Passport API shape. Match the SDK version declared by the project.

For a new application, prefer a minimal project first:

```text
moon.mod
passport.toml
app/
  app.mbt
  application.mbt
  app_wbtest.mbt
  moon.pkg
```

Add assets, sounds, generated sound bindings, or Host dependency overrides only when the product actually needs them.

## Architectural boundary

AI Passport has one backend abstraction: **Host**.

Application code may depend on semantic SDK packages such as:

```text
colmugx/ai-passport/application
colmugx/ai-passport/core
colmugx/ai-passport/graphics
colmugx/ai-passport/input
colmugx/ai-passport/audio
```

Web and physical devices must execute the same application semantics.

Never introduce product logic such as:

```moonbit
if host == "folotoy" {
  ...
}
```

If Web and hardware differ, first determine whether the difference is a legitimate Host fact already exposed by the SDK.

## Application entry

The package declared by `passport.toml` must implement the SDK `Application` contract and expose:

```moonbit
pub fn passport_main() -> &@application.Application
```

The current v0.1 contract contains:

```moonbit
update(Self, FrameContext) -> Unit
button(Self, Button, Bool) -> Unit
render(Self, Int?) -> FrameView
audio_output(Self) -> AudioOutput?
```

Keep the application's concrete state type private unless downstream packages genuinely need it.

A small app should normally expose only the integration surface it needs.

## Time correctly

`FrameContext.now_us` is monotonic Host time.

Never treat its absolute value as application elapsed time.

Latch the first timestamp and advance using deltas:

```text
delta = max(now - previous, 0)
```

The first frame should normally establish the baseline rather than simulate all time elapsed since the Host started.

This matters on both browsers and physical hardware because the Host clock may have been running before application initialization.

If simulation requires a fixed rate, keep the fixed-step logic inside the application. The Host does not define the application's simulation rate.

## Input correctly

Applications see only semantic buttons:

```text
Up
Down
Ok
```

Do not model GPIO pins or physical switch numbers.

Treat `button(button, pressed)` as an input transition, not necessarily as the place where all game/application logic must execute.

For non-trivial applications, `InputState` is useful for latching edges and applying them on the next application update.

Decide explicitly whether the product responds to:

* press
* release
* click
* long press
* held state

Avoid accidental auto-repeat.

## Render separately from simulation

Rendering should describe current state, not advance it.

A useful separation is:

```text
update -> mutate application state
button -> record semantic input
render -> draw current state
```

The logical display is 120×160 RGB565.

Use the public graphics API and logical coordinates. Do not write LCD-driver code.

For simple applications, primitives such as:

* `clear`
* `pixel`
* `line`
* `rect`
* `fill_rect`
* `sprite`
* bitmap text

are sufficient.

When a primitive is missing, implement it at the application graphics level rather than bypassing the SDK. Pocket Breather, for example, implemented its breathing orb from pixels instead of introducing device-specific circle drawing.

Design for the actual 120×160 screen. Large desktop-style layouts usually translate poorly.

## Battery

`render` receives:

```moonbit
battery_percent : Int?
```

`None` means unavailable.

Do not invent a fake battery percentage. Render a neutral unavailable state if needed.

## No-audio applications

If the application does not use sound:

```moonbit
fn audio_output(...) -> @application.AudioOutput? {
  None
}
```

Do not create fake volume or mute state merely to satisfy the interface.

A no-audio app is a first-class AI Passport application.

Pocket Breather deliberately started this way. It made the first downstream validation substantially easier because graphics, input, timing, Web, and physical-device behavior could be proven independently of the audio pipeline.

## Sound applications

For current v0.1 projects, declare sound resources in `passport.toml`:

```toml
[[sounds]]
name = "jump"
source = "assets/jump.pcm"
```

Sound source files are externally prepared:

```text
PCM16 little-endian
signed
mono
16000 Hz
headerless
```

Do not implement codecs, resampling, synthesis, or media decoding inside the application merely to load assets.

Use an application-owned Moon package with `rule` / `dev_build` and the co-versioned CLI's `generate-sounds` command.

Application code uses typed generated Sound values, never numeric resource IDs.

Playback behavior belongs to code:

```moonbit
@audio.play(@sounds.Jump, looping=true)
```

A `Sound` resource and a `Playback` are different things.

Store a `Playback` when the application needs to:

* pause it
* resume it
* stop it
* query its position

Use `@audio.position(playback)` for that specific playback.

Do not use a global music clock.

`FrameContext.presentation_lead_us` is a generic Host calibration fact. If presentation must follow playback position, apply the provided lead rather than checking which Host is running.

## `passport.toml`

A minimal application is:

```toml
entry = "app"
```

Ordinary bundle assets use `[[assets]]`.

Audio resources use `[[sounds]]`.

A project may optionally provide a Host dependency checkout:

```toml
[hostDependencies."folotoy-ai-passport"]
path = "external/folotoy-ai-passport"
```

Treat that as a dependency-resolution override, not application architecture.

Do not put playback settings such as looping or volume into sound resource metadata.

## Tests

Test product semantics before testing Hosts.

For a private application state type, prefer a white-box test file:

```text
app_wbtest.mbt
```

MoonBit `*_test.mbt` is black-box. It cannot access private helpers.

Pocket Breather exposed this mistake immediately: tests were originally black-box while attempting to exercise private state. Renaming them to white-box tests allowed the application state to remain private instead of widening the public API just for tests.

Useful unit tests include:

* initial state
* first-frame time baseline
* paused time does not advance
* state-machine transitions
* button-edge behavior
* wraparound behavior
* animation boundaries
* unavailable battery/audio states
* sound playback failure or unavailable position fallbacks

Do not make internal helpers public only to make tests compile.

## Development gates

Run normal MoonBit gates first:

```sh
moon update
moon check
moon test
moon info
moon fmt
git diff --exit-code
```

Then validate AI Passport Hosts.

For Web:

```sh
moonx colmugx/ai-passport/cmd/passport@VERSION doctor --host web
moonx colmugx/ai-passport/cmd/passport@VERSION build --host web # or
moonx colmugx/ai-passport/cmd/passport@VERSION dev # direct
```

For FoloToy AI Passport:

```sh
moonx colmugx/ai-passport/cmd/passport@VERSION doctor --host folotoy-ai-passport
moonx colmugx/ai-passport/cmd/passport@VERSION build --host folotoy-ai-passport
```

Use the same version as the project's SDK dependency.

The CLI build does not flash the device.

## Generated files

Do not hand-edit or commit generated Host adapters or build workspaces.

Typical generated/resolved paths include:

```text
src/passport-generated/
.passport/
```

Generated sound bindings are also generator-owned.

If generated code appears wrong, fix:

* project metadata
* application source
* generator
* SDK/CLI

Do not patch generated output as the source of truth.

## Validation evidence

Keep evidence categories separate.

### Source validation

The code obeys the portable application contract.

### Compiler/test validation

MoonBit check and tests pass.

### Web build/runtime validation

The Web Host bundle builds and application behavior executes correctly.

### Device build validation

ESP-IDF produces firmware and reports partition usage.

### Physical hardware validation

The firmware is flashed to an actual AI Passport and product behavior is exercised.

Never claim physical-device validation from a successful firmware build alone.

## Firmware size

Always state which binary is being measured.

These are not interchangeable:

```text
application partition binary
merged Full Flash image from 0x0
sound/resource bank
```

Do not compare an application-partition `.bin` directly with an 8 MiB merged flash image and call the ratio an application-size comparison.

Record exact byte counts when possible.

For the Pocket Breather validation, the application partition binary was small because the product used:

* no audio
* no image assets
* no font pack
* no network content
* simple MoonBit state and graphics

This demonstrated that AI Passport itself does not require a multi-megabyte application payload.

## Product-development strategy

When building a new AI Passport application:

1. Start with the product interaction, not the hardware.
2. Build the smallest complete vertical slice.
3. Prefer no assets and no audio for the first Host proof if the product permits it.
4. Make it work in Web.
5. Build the physical Host.
6. Flash real hardware.
7. Only then add optional complexity such as audio or large assets.
8. Re-test both Hosts after capability additions.

This sequence isolates failures and prevents Host/build problems from being confused with product logic.

## Pocket Breather lessons

Pocket Breather was useful because it was intentionally independent of the template and SDK repository.

It proved the downstream contract with a real product-shaped app:

* its own MoonBit module
* its own application state
* semantic Up / Down / Ok controls
* Host monotonic time
* Host battery reading
* animated rendering
* no audio
* Web execution
* FoloToy firmware build
* physical-device validation

The most important lessons were:

* an AI Passport app should look like a normal MoonBit project
* app state should remain private when possible
* tests should match MoonBit's black-box/white-box model
* Host-specific behavior does not belong in application code
* simple applications should not need assets or generated complexity
* Web validation and hardware validation are separate evidence
* generated adapters are implementation plumbing, not authored application code
* firmware-size comparisons need identical binary scope

## Completion checklist

Before calling an application complete, verify:

* [ ] application is an independent downstream project
* [ ] SDK version is explicitly declared
* [ ] `passport.toml` has one application entry
* [ ] application implements the public `Application` contract
* [ ] `passport_main()` exists
* [ ] application imports no Host implementation packages
* [ ] input is semantic
* [ ] time uses monotonic deltas
* [ ] render does not advance simulation
* [ ] no-audio apps return `None`
* [ ] sound apps use generated typed Sounds and Playback handles
* [ ] unit tests cover state boundaries
* [ ] MoonBit checks/tests pass
* [ ] Web Host builds
* [ ] FoloToy Host builds when required
* [ ] generated files are not treated as authored source
* [ ] physical validation is claimed only after actual flashing/testing
* [ ] firmware size reports identify the measured binary type
