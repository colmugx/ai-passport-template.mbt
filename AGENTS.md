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

If `moon` is already available, do not reinstall the toolchain. Continue with the project.

## Install MoonBit when missing

Detect the user's operating system and use the appropriate official installer.

### Linux and macOS

```sh
curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash
```

### Windows PowerShell

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
```

Do not ask the user to install MoonBit manually when the environment allows the installer command to be executed directly.

After installation, verify:

```sh
moon version --all
```

If installation succeeds but the current shell still cannot find `moon`, refresh the shell environment or update `PATH` as instructed by the installer, then verify again. Do not repeatedly reinstall MoonBit to solve a stale `PATH`.

### China network fallback

If the user is in mainland China, the execution environment is known to use CN network access, or the `.com` installer endpoint fails because of regional network access, replace:

```text
cli.moonbitlang.com
```

with:

```text
cli.moonbitlang.cn
```

Linux and macOS:

```sh
curl -fsSL https://cli.moonbitlang.cn/install/unix.sh | bash
```

Windows PowerShell:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; irm https://cli.moonbitlang.cn/install/powershell.ps1 | iex
```

After installing through either endpoint, verify the actual installed toolchain rather than assuming installation succeeded:

```sh
moon version --all
```

Do not continue to `moon update`, `moon check`, `moon test`, `moonx`, Web builds, or FoloToy firmware builds until the `moon` command is available.

## Repository purpose

This repository is a downstream **AI Passport application template** and runnable reference application.

It is not the AI Passport SDK and it is not a Host implementation.

The application may be replaced with another product, but the repository must continue to demonstrate the normal downstream project contract cleanly.

The current SDK/CLI dependency is declared in `moon.mod`. Commands and generated rules must use the co-versioned CLI rather than assuming a separately installed moving version.

## Architectural boundary

1. Application behavior belongs in this repository.
2. SDK and Host implementation behavior belongs in `colmugx/ai-passport`.
3. **Host is the only backend abstraction.**
4. Web and FoloToy must execute the same application semantics.
5. Application packages must not import Host implementation packages or platform APIs.
6. Do not add GPIO, ADC, SPI, I2C, I2S, ESP-IDF, BSP, LCD-controller, DOM, WebAudio, or other Host-specific logic to application code.
7. Do not branch application behavior on Host identity.
8. The v0.1 logical display is 120×160 RGB565.
9. Application-visible buttons are semantic `Up`, `Down`, and `Ok`.
10. Generated Host adapters and Host workspaces are build output, not authored application source.

## Project contract

The MoonBit module root contains:

```text
moon.mod
passport.toml
```

`passport.toml` declares one application entry:

```toml
entry = "app"
```

With the normal:

```text
source = "src"
```

layout, that entry resolves to:

```text
src/app
```

The application package implements:

```text
colmugx/ai-passport/application.Application
```

and exports:

```moonbit
pub fn passport_main() -> &@application.Application
```

Do not create additional platform-specific application entry points.

## Application responsibilities

Application code owns:

* product state
* simulation
* semantic input behavior
* rendering
* optional playback ownership
* product-level volume/mute state when needed

Host code owns:

* physical controls
* browser input
* display transport
* hardware presentation
* ESP-IDF integration
* BSP integration
* Web runtime
* audio device/backend integration
* flashing/build plumbing

Keep that dependency direction intact.

## Time

`FrameContext.now_us` is monotonic Host time.

Use frame-to-frame deltas, not absolute timestamp values.

The first application update should normally establish a time baseline without simulating pre-application Host uptime.

Clamp or otherwise safely handle equal/backward timestamps.

The application owns any fixed-step simulation policy and catch-up limits.

`FrameContext.presentation_lead_us` is a generic Host fact for position-driven presentation. Use it when appropriate without identifying the Host.

## Input

`button(button, pressed)` receives semantic button transitions.

Use only:

```text
Up
Down
Ok
```

Do not encode physical switch numbers.

For stateful edge handling, prefer the SDK `InputState` rather than inventing Host-specific debounce semantics.

Be explicit about whether an action occurs on press, release, click, long press, or held state.

## Rendering

Rendering should not advance simulation state.

Prefer a structure where:

```text
update -> advances state
button -> records input
render -> draws state
```

Use the public graphics API and logical coordinates.

Do not access framebuffer implementation details or physical display APIs from the application.

## Battery

Battery percentage passed to `render` is optional.

Treat `None` as unavailable.

Do not replace unavailable Host data with invented values except inside explicit tests/fixtures.

## Audio

Audio is optional.

A no-audio application should return:

```moonbit
None
```

from `audio_output()`.

Do not create fake audio state simply because Forest Walk has audio.

### Sound resources

Sound resources are declared in `passport.toml`.

Current sound inputs are externally prepared:

```text
headerless
signed PCM16 little-endian
mono
16000 Hz
```

Do not add codecs, resamplers, synthesis engines, sequencers, or DAW-style abstractions unless the application product itself explicitly requires new functionality and the SDK contract supports it.

Generated sound bindings must come from the co-versioned Passport CLI.

Never hand-author Sound IDs.

Looping, autoplay-like behavior, and playback control belong in application code, not resource metadata.

A generated `Sound` identifies a resource.

A returned `Playback` identifies one playback instance.

Use `@audio.position(playback)` when presentation depends on that instance's position.

## Forest Walk

Forest Walk is the current reference application.

It demonstrates application behavior; it does not define SDK semantics.

Its concepts may be removed when a downstream user creates another application.

Do not preserve Forest Walk code merely because it existed in the template.

When modifying Forest Walk itself:

* maintain deterministic simulation
* keep drawing separate from simulation
* retain playback-instance ownership
* keep the monotonic visual fallback when playback position is unavailable
* use Host `presentation_lead_us` rather than Host checks
* preserve one semantic action per intended input edge

## Public API discipline

This is an application repository, not a library API surface.

Prefer private application state and helpers.

Do not make application internals public solely to support tests.

MoonBit test visibility rules matter:

```text
*_test.mbt    black-box tests
*_wbtest.mbt  white-box tests
```

Use white-box tests when private product state needs direct testing.

Keep `passport_main()` as the important public integration entry.

## Generated files

Do not hand-edit:

```text
src/passport-generated/
.passport/
```

Do not commit generated Host workspaces.

Generated sound binding files are generator-owned outputs as declared by their package's `rule` / `dev_build`.

If generated output is wrong, fix the project contract, source input, or generator. Do not patch the generated result as the long-term solution.

## External FoloToy checkout

The template currently supplies:

```text
external/folotoy-ai-passport
```

through the `hostDependencies` override in `passport.toml`.

Treat this checkout as a Host dependency, not an application package.

Do not import it from MoonBit application code.

Do not copy BSP or hardware source into `src/app`.

A downstream project may remove the override and let the Passport CLI use its pinned dependency resolution instead.

## Commands

Use the SDK version declared by `moon.mod`.

For the current template:

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
moonx colmugx/ai-passport/cmd/passport@0.2.0 doctor --host web
moonx colmugx/ai-passport/cmd/passport@0.2.0 build --host web
moonx colmugx/ai-passport/cmd/passport@0.2.0 dev --host web
```

FoloToy:

```sh
moonx colmugx/ai-passport/cmd/passport@0.2.0 doctor --host folotoy-ai-passport
moonx colmugx/ai-passport/cmd/passport@0.2.0 build --host folotoy-ai-passport
```

The build command does not constitute a successful flash or physical-device test.

## Validation expectations

Distinguish these claims:

```text
source reviewed
MoonBit check/test passed
Web Host built
Web application executed
FoloToy firmware built
physical device flashed
physical behavior validated
```

Do not collapse them into a generic "works".

When reporting firmware size, identify whether the number refers to:

* the application partition binary
* a resource/sound bank
* a merged Full Flash image

Do not compare different binary scopes as if they were equivalent.

## Template changes

When changing the template itself, optimize for a new developer rather than for showcasing implementation sophistication.

A new developer should be able to identify quickly:

1. where application code lives
2. which file selects the entry
3. which controls are available
4. how to run Web
5. how to build the device
6. which files are generated
7. which example-specific pieces may be deleted

Do not make optional product capabilities look mandatory.

In particular, audio, assets, external Host overrides, and Forest Walk-specific packages are examples, not requirements of every AI Passport application.

## README consistency

When the project contract changes, update README examples in the same change.

Check especially:

* SDK/CLI version
* `passport.toml`
* sound declarations
* generated sound rule
* supported Host names
* build commands
* generated output paths
* flash instructions

Do not document old `passport.json`, removed sound metadata, old global playback-position models, or deprecated Host layout as current behavior.

## Completion gate

Before finishing a change:

* [ ] application code remains Host-independent
* [ ] `moon check --output-json` passes
* [ ] `moon test --output-json` passes
* [ ] `moon info` has no unintended public interface change
* [ ] `moon fmt` has been run
* [ ] generated files are not accidentally committed
* [ ] README remains consistent with the project contract
* [ ] Web behavior is exercised when product behavior changes
* [ ] FoloToy build is exercised when device integration is affected
* [ ] physical-device claims are made only from physical-device evidence
