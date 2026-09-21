# AI Passport application template

A runnable MoonBit starter project for building applications that run on AI Passport Hosts.

The template currently includes **Forest Walk** as a complete example with graphics, input, battery state, looping audio, and synchronized animation. Replace its application behavior with your own product while keeping the same portable application boundary.

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
moonx colmugx/ai-passport/cmd/passport@0.1.2 dev
```

Then open:

```text
http://127.0.0.1:8000/index.html
```

The same MoonBit application can be built for the physical FoloToy AI Passport Host:

```sh
moonx colmugx/ai-passport/cmd/passport@0.1.2 doctor --host folotoy-ai-passport
moonx colmugx/ai-passport/cmd/passport@0.1.2 build --host folotoy-ai-passport
```

The build creates the device workspace under:

```text
.passport/folotoy-ai-passport/
```

It does not flash the device.

With a board connected:

```sh
.passport/folotoy-ai-passport/flash.sh -p PORT
.passport/folotoy-ai-passport/monitor.sh -p PORT
```

## Project structure

The important authored files are:

```text
moon.mod
passport.toml

src/
  app/
    app.mbt
    application.mbt
    moon.pkg
  sounds/
    moon.pkg

assets/
  forest_walk.pcm
```

Generated Host adapters are written under:

```text
src/passport-generated/
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

With `source = "src"` in `moon.mod`, this means the application lives at:

```text
src/app
```

That package implements:

```text
colmugx/ai-passport/application.Application
```

and exports:

```moonbit
pub fn passport_main() -> &@application.Application
```

The portable application receives:

* monotonic Host time
* Host presentation calibration
* semantic `Up`, `Down`, and `Ok` button transitions
* best-effort battery percentage

and returns a logical 120×160 RGB565 frame.

The application should not contain browser APIs, ESP-IDF code, GPIO numbers, display-controller code, or other Host implementation details.

The Web and FoloToy Hosts run the same application semantics.

## Applications without audio

Audio is optional.

A normal AI Passport application can contain no sound resources and return:

```moonbit
None
```

from `audio_output()`.

You do not need to keep Forest Walk's audio setup when your product does not use audio.

## Sounds

Forest Walk demonstrates the v0.1 typed Sound workflow.

`passport.toml` declares the source resource:

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

`src/sounds/moon.pkg` runs the pinned CLI generator:

```moonbit
rule(
  name: "passport-sounds",
  command: "moonx colmugx/ai-passport/cmd/passport@0.1.2 generate-sounds $input $output",
)

dev_build(
  rule: "passport-sounds",
  input: "../../passport.toml",
  output: "generated.mbt",
)
```

Application code then uses the generated typed value:

```moonbit
@audio.play(@sounds.ForestWalk, looping=true)
```

The returned `Playback` identifies that playback instance. Operations such as position, pause, resume, and stop target the `Playback`, not the Sound resource globally.

Looping is playback behavior and is therefore selected by `play`, not stored in `passport.toml`.

## Forest Walk example

The included Forest Walk application demonstrates:

* a portable MoonBit application state
* 120×160 rendering
* parallax sprite animation
* semantic button input
* Host battery display
* fixed-step simulation
* looping typed Sound playback
* animation synchronized to a particular Playback position
* fallback visual timing when playback position is unavailable
* Host-provided presentation lead without checking Host identity

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

# [hostDependencies."folotoy-ai-passport"]
# path = "external/folotoy-ai-passport"
```

The `hostDependencies` entry points the device build at the project-owned FoloToy checkout.

If a project does not provide that override, the Passport CLI can resolve its pinned Host dependency under `.passport/deps/`.

## Web build

To create a Web bundle without starting the development server:

```sh
moonx colmugx/ai-passport/cmd/passport@0.1.2 doctor --host web
moonx colmugx/ai-passport/cmd/passport@0.1.2 build --host web
```

The generated Web workspace contains the application Wasm, Host files, sound bank, and declared assets.

Sound configuration does not travel through URL parameters.

A browser may require one user gesture before audio playback can begin.

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

When application behavior changes, also exercise it through the Web Host.

When device behavior matters, build the FoloToy Host and test the resulting firmware on physical hardware. A successful firmware build alone is not physical-device validation.

## Creating your own app from the template

A practical sequence is:

1. Rename the module in `moon.mod`.
2. Keep `passport.toml` with `entry = "app"`.
3. Replace Forest Walk state and rendering with your own application.
4. Remap `Up`, `Down`, and `Ok` to your product controls.
5. Delete Forest Walk sound configuration if your application does not use audio.
6. Keep application logic independent of Web and FoloToy implementation details.
7. Add tests for product state before adding Host-specific complexity.
8. Validate Web.
9. Build and test physical hardware.

For a very small application, the final authored project may need little more than:

```text
moon.mod
passport.toml
src/app/
```

Additional packages and resources should exist because the product needs them, not because the template happens to demonstrate them.
