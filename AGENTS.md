# AGENTS.md

## Ensure the MoonBit toolchain exists

Do not assume the user's machine already has MoonBit installed.

Before running any `moon`, `moonx`, Web Host, or firmware build command, first check whether the MoonBit toolchain is available.

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

If `moon` is already available, do not reinstall the toolchain.

If it is missing, install the official toolchain.

Linux and macOS:

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
```

Windows PowerShell:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
```

If the user is in mainland China, the environment is known to use CN network access, or the `.com` installer endpoint fails because of regional access, replace `cli.moonbitlang.com` with `cli.moonbitlang.cn`.

Linux and macOS CN endpoint:

```sh
curl -fsSL https://cli.moonbitlang.cn/install/unix.sh | bash
```

Windows PowerShell CN endpoint:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; irm https://cli.moonbitlang.cn/install/powershell.ps1 | iex
```

After installation, verify:

```sh
moon version --all
```

If installation succeeds but the current shell cannot find `moon`, refresh the shell environment or update `PATH` as instructed by the installer. Do not repeatedly reinstall MoonBit to solve a stale `PATH`.

Do not continue to `moon update`, `moon check`, `moon test`, `moonx`, Web builds, or FoloToy firmware builds until `moon` is available.

## Repository purpose

This repository is a downstream **AI Passport application template** and runnable reference application.

It is not the AI Passport SDK and it is not a Host implementation.

Application behavior belongs here. Reusable SDK contracts, CLI behavior, Host runtimes, browser integration, ESP-IDF integration, BSP integration, and device bridges belong in `colmugx/ai-passport`.

The current SDK/CLI version is declared in `moon.mod`. Every Passport CLI invocation and generated rule must use that same co-versioned release. Do not assume a separately installed moving `passport` version.

Forest Walk is the current example application. It demonstrates capabilities; it does not define what downstream AI Passport products are allowed to be.

## Architectural boundary

1. **Host is the only backend abstraction.**
2. Web and FoloToy execute the same portable MoonBit application semantics.
3. Application packages must not import Host implementation packages or platform APIs.
4. Do not add GPIO, ADC, SPI, I2C, I2S, ESP-IDF, BSP, LCD-controller, DOM, WebAudio, or other Host-specific logic to application code.
5. Do not branch product behavior on Host identity.
6. Use public semantic capabilities such as display information, button events, audio capture/playback, battery, and power instead of recreating Host behavior.
7. Generated Host adapters and Host workspaces are build output, not authored application source.
8. Physical-device evidence and software-build evidence are different claims.

## Current project layout

This template currently uses MoonBit's module root as its source root; `moon.mod` does not declare `source = "src"`.

The authored packages are therefore at the repository root:

```text
app/
forest_walk/
sounds/
```

The project contract is:

```text
moon.mod
passport.toml
```

`passport.toml` declares:

```toml
entry = "app"
```

so the application package is:

```text
app/
```

Do not move it to `src/app` unless the project intentionally changes its MoonBit source root in the same change.

Generated Host adapters belong at:

```text
passport-generated/
```

Host workspaces and CLI-managed external dependencies belong under:

```text
.passport/
```

Generated sound bindings are produced beside `sounds/moon.pkg`. Do not hand-edit them.

## Application contract

The entry package implements:

```text
colmugx/ai-passport/application.Application
```

and exports:

```moonbit
pub fn passport_main() -> &@application.Application
```

AI Passport 0.2 defines:

```text
update(Self, FrameContext) -> Unit
button(Self, Button, Bool) -> Unit
button_event(Self, Button, ButtonEvent) -> Unit
render(Self, Int?) -> FrameView
audio_output(Self) -> AudioOutput?
```

`button_event` has a default implementation so older applications can remain source-compatible, but new product work should use it when semantic gestures are required.

Do not create platform-specific application entry points.

## Application responsibilities

Application code owns:

- product state
- simulation
- semantic input behavior
- drawing
- application-level backlight policy
- optional sound playback ownership
- optional microphone capture behavior
- optional sleep/wake product behavior
- product-level volume/mute state when needed

Host code owns:

- physical input transport and gesture recognition
- browser input transport
- display transport
- physical panel implementation
- backlight transport
- battery transport
- microphone/audio device transport
- sleep implementation
- ESP-IDF/BSP/browser integration
- firmware/build/flashing plumbing

Keep that dependency direction intact.

## Time

`FrameContext.now_us` is monotonic Host time.

Use frame-to-frame deltas, not absolute timestamps.

The first application update should normally establish a time baseline without simulating Host uptime that occurred before application startup.

Safely handle equal or earlier timestamps.

The application owns fixed-step simulation policy and catch-up limits.

`FrameContext.presentation_lead_us` is a generic Host calibration fact for playback-position-driven presentation. Use it without checking Host identity.

## Display and rendering

Rendering should not advance simulation state.

Prefer:

```text
update       -> advances product state
button       -> consumes low-level compatibility edges when needed
button_event -> consumes semantic gestures
render       -> draws current state
```

AI Passport 0.2 exposes display capabilities through:

```moonbit
@graphics.display_info()
@graphics.Canvas::for_display()
```

The current Web and FoloToy Hosts expose a **240×320** drawing surface. Do not preserve the old 120×160 contract in new code or documentation.

The Web reference page keeps its canvas at the native 240×320 CSS size. A
positive `?scale=N` URL parameter is an explicit enlarged debug preview, not a
different application resolution.

Prefer `Canvas::for_display()` when the product should use the full active Host surface. Do not hard-code Host-specific dimensions when `display_info()` can supply them.

`DisplayInfo` contains:

```text
width
height
monochrome
has_backlight
```

Backlight is optional:

```moonbit
@graphics.backlight_level()
@graphics.set_backlight(level)
```

`set_backlight` accepts `0..100` and returns `false` when the Host has no light. A Host without a backlight is valid; application code must not assume one exists.

Use the public graphics API. Do not access framebuffer ownership or physical display APIs from the application.

Forest Walk's source PNGs are 1536×1024 authoring art, converted with a deterministic 3:4 cover crop into 240×320 runtime layers. The local PNGs and converter helpers are ignored authoring inputs; the generated runtime data is example-specific, not the SDK display contract.

## Input

Application-visible buttons remain semantic:

```text
Up
Down
Ok
```

Do not encode physical switch numbers.

AI Passport 0.2 supplies recognized events:

```text
Press
Click
DoubleClick
LongPress
```

through `Application::button_event`.

Use `button_event` when the product needs click, double-click, or long-press behavior.

Use `button` / `InputState` when the product specifically needs lower-level press/release or held state.

Do not reimplement click, double-click, or long-press recognition with application timers when the Host already supplies those semantics.

The Web Host recognizes gestures per button with a 300 ms double-click window and a 1500 ms long-press threshold. The FoloToy Host forwards recognized events from its pinned BSP.

Do not design portable physical button chords for FoloToy. Its three buttons share one ADC ladder and simultaneous physical keys cannot be identified reliably.

## Battery

Battery percentage passed to `render` is optional.

`Some(0..100)` is a Host reading. `None` means unavailable.

Do not replace unavailable Host data with invented values except in explicit tests/fixtures.

## Audio playback

Audio playback is optional.

A no-audio application should return `None` from `audio_output()`.

Sound resources are declared in `passport.toml` and externally prepared as:

```text
headerless
signed PCM16 little-endian
mono
16000 Hz
```

Generated sound bindings must come from the co-versioned Passport CLI. Never hand-author Sound IDs.

A generated `Sound` identifies a resource. A returned `Playback` identifies one live playback instance.

Looping and playback control belong in application code, not resource metadata.

Use `@audio.position(playback)` when presentation depends on that particular playback.

Do not add codecs, resampling, synthesis, sequencing, or exposed mixer graphs merely to consume fixed application assets; the current public SDK does not provide those facilities.

## Microphone capture

AI Passport 0.2 exposes portable microphone capture:

```moonbit
@audio.capture_start()
@audio.capture_status()
@audio.capture_read(buffer)
@audio.capture_stop()
@audio.capture_dropped_samples()
```

Samples are signed PCM16 mono at 16000 Hz.

Capture status is one of:

```text
Unavailable
Idle
Requesting
Recording
Denied
Failed
```

On Web, permission may leave capture in `Requesting` temporarily. Read samples only while status is `Recording`.

When product correctness depends on continuous samples, observe `capture_dropped_samples()`.

Microphone capture is not persistent storage. Do not claim that the SDK can save recordings across sessions; there is no portable filesystem or key-value storage API.

## Power

AI Passport 0.2 exposes:

```moonbit
@power.request_sleep()
@power.request_timed_sleep(ms)
@power.wake_reason()
```

Wake causes are:

```text
Button
Timer
Other
```

Sleep takes effect after the current presented frame.

On FoloToy, the Host implements light sleep, preserves MoonBit application state and playback positions, suspends the backlight/audio transport as required, and stops microphone capture. If the product still needs capture after wake, request it again.

Do not call ESP-IDF sleep APIs from application code.

## Unsupported portable capabilities

Do not invent public application APIs for capabilities the current SDK does not expose, including:

```text
Wi-Fi / HTTP / Internet
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

Physical hardware capability does not automatically mean portable SDK capability.

If an unsupported capability is central to a requested product, identify the missing SDK capability rather than bypassing the Host boundary.

## Forest Walk

Forest Walk is a reference application, not SDK semantics.

Its code may be replaced completely in a downstream product.

When modifying Forest Walk itself:

- keep simulation deterministic
- keep drawing separate from simulation
- retain playback-instance ownership
- preserve the monotonic visual fallback when playback position is unavailable
- use `presentation_lead_us` rather than Host checks
- keep product input semantics explicit
- distinguish Forest Walk's 1536×1024 source art and 240×320 generated scenery from the SDK's current 240×320 display surface

Do not preserve Forest Walk complexity in unrelated downstream products.

## Public API discipline

This is an application repository, not a reusable library API.

Prefer private application state and helpers.

Do not make internals public solely to support tests.

MoonBit test visibility:

```text
*_test.mbt    black-box
*_wbtest.mbt  white-box
```

Use white-box tests when private product state needs direct testing.

Keep `passport_main()` as the essential public integration entry.

## Generated files

Do not hand-edit or commit generated Host output:

```text
passport-generated/
.passport/
```

The sound binding generated by `sounds/moon.pkg` is generator-owned as well.

If generated output is wrong, fix the project contract, input metadata, application source, or generator. Do not patch generated files as the long-term source of truth.

## FoloToy dependency resolution

This template does **not** currently vendor an `external/folotoy-ai-passport` checkout or declare a `hostDependencies` override.

By default, the Passport CLI resolves its pinned FoloToy dependency under:

```text
.passport/deps/
```

Only add:

```toml
[hostDependencies."folotoy-ai-passport"]
path = "external/folotoy-ai-passport"
```

when a project intentionally owns such a checkout.

Do not import BSP code from MoonBit application packages.

## Commands

Read the exact SDK version from `moon.mod` and use it for the CLI.

Current template version:

```text
0.2.6
```

Project checks:

```sh
moon update
moon check --output-json
moon test --output-json
moon info
moon fmt
git diff --exit-code
```

Web:

```sh
moonx colmugx/ai-passport/cmd/passport@0.2.6 doctor --host web
moonx colmugx/ai-passport/cmd/passport@0.2.6 build --host web
moonx colmugx/ai-passport/cmd/passport@0.2.6 dev --host web
```

FoloToy:

```sh
moonx colmugx/ai-passport/cmd/passport@0.2.6 doctor --host folotoy-ai-passport
moonx colmugx/ai-passport/cmd/passport@0.2.6 build --host folotoy-ai-passport
```

The build command does not constitute a successful flash or physical-device test.

## Validation expectations

Distinguish:

```text
source reviewed
MoonBit check/test passed
Web Host built
Web application executed
FoloToy firmware built
physical device flashed
physical behavior validated
```

Do not collapse these into a generic "works".

When reporting firmware size, identify whether the number is:

- the application partition binary
- a sound/resource bank
- a merged Full Flash image

Do not compare different binary scopes as if they were equivalent.

When an application uses 0.2 capabilities, exercise the relevant paths:

- click/double-click/long-press
- full display geometry
- optional backlight
- microphone permission/capture status
- sleep and button/timer wake

## Template changes

Optimize this repository for a developer or coding agent starting a new product, not for showcasing Forest Walk sophistication.

A new developer should quickly identify:

1. where application code lives
2. which file selects the entry
3. which input events exist
4. which display/audio/microphone/power capabilities exist
5. how to run Web
6. how to build the device
7. which files are generated
8. which Forest Walk-specific pieces may be deleted

Do not make audio, microphone, backlight, power, ordinary assets, or Forest Walk-specific packages look mandatory when a product does not need them.

## README and Skill consistency

When the project contract or SDK capabilities change, update `README.mbt.md`, `AGENTS.md`, and the AI Passport firmware-development Skill in the same change.

Check especially:

- SDK/CLI version
- actual MoonBit source-root layout
- `passport.toml`
- Application trait methods
- display dimensions and capability query
- input gesture semantics
- sound declarations
- microphone capture
- sleep/wake behavior
- generated output paths
- dependency resolution
- Host build commands
- flash instructions

Do not document old `passport.json`, removed sound metadata, old 120×160 display behavior, obsolete global playback-position models, or nonexistent external checkouts as current behavior.

## Completion gate

Before finishing a template change:

- [ ] application code remains Host-independent
- [ ] documentation matches the actual repository layout
- [ ] documentation matches the SDK version in `moon.mod`
- [ ] `moon check --output-json` passes
- [ ] `moon test --output-json` passes
- [ ] `moon info` has no unintended public interface change
- [ ] `moon fmt` has been run
- [ ] generated files are not accidentally committed
- [ ] README and Skill remain consistent with the project contract
- [ ] Web behavior is exercised when product behavior changes
- [ ] FoloToy build is exercised when device integration is affected
- [ ] physical-device claims are made only from physical-device evidence
