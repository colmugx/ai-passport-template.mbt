# AI Passport application template

This repository is a runnable AI Passport application and GitHub template. It
depends on the co-versioned `colmugx/ai-passport@0.1.0` SDK, CLI, and Host
assets. Forest Walk is the default starter application; no SDK or Host
implementation is copied into this repository.

## Application and resource contracts

The normal MoonBit source root is `src`. `src/app` implements the SDK
`Application` contract and exposes `pub fn passport_main()`. The same
application runs on the Web and FoloToy Hosts.

`passport.toml` declares the application and its preprocessed sound:

```toml
entry = "app"

[[sounds]]
name = "forest_walk"
source = "assets/forest_walk.pcm"
```

`src/sounds/moon.pkg` owns a Moon `rule` / `dev_build`. Before checks, tests,
or builds, it invokes the pinned passport CLI with `$input` and `$output` to
generate the ignored `src/sounds/generated.mbt`. Application code therefore
uses `@sounds.ForestWalk`; it never uses a numeric Sound ID or hand-authored
generated file.

The PCM file is prepared outside the SDK and follows its fixed input contract:
headerless signed PCM16 little-endian, mono, 16000 Hz. The CLI validates the
file and compiles it into `sounds.bank`. Looping is playback behavior, not
resource metadata.

On the first Host-driven application update, Forest Walk calls:

```mbt nocheck
@audio.play(@sounds.ForestWalk, looping=true)
```

The returned `Playback` is retained by the application. Fairy animation reads
`@audio.position(playback)` and applies the Host-provided
`presentation_lead_us`; there is no frame-global playback clock. If playback
is unavailable, the existing visual beat clock remains the preview fallback.

Host entry adapters under `src/passport-generated/` and Host workspaces under
`.passport/` are ignored build output owned by the CLI.

## Web development

Build or serve with the published 0.1.0 CLI:

```sh
moonx colmugx/ai-passport/cmd/passport@0.1.0 build --host web
moonx colmugx/ai-passport/cmd/passport@0.1.0 dev
```

The Web bundle contains `app.wasm`, `sounds.bank`, `index.html`,
`passport-host.js`, and `sound-worklet.js`. Its normal URL is
`http://127.0.0.1:8000/index.html`; Sound configuration is never passed through
query parameters. Click or press a key once if the browser requires a user
gesture to resume its AudioContext.

ArrowUp/ArrowDown adjust application master volume and Enter toggles mute.
Those are the same semantic controls used by the physical buttons.

## FoloToy device build

The SDK owns the ESP-IDF Host glue. This project provides the pinned external
FoloToy checkout at `external/folotoy-ai-passport`, declared through
`passport.toml`. A device build additionally requires ESP-IDF 5.5.3 and the
pinned MoonBit toolchain:

```sh
moonx colmugx/ai-passport/cmd/passport@0.1.0 doctor --host folotoy-ai-passport
moonx colmugx/ai-passport/cmd/passport@0.1.0 build --host folotoy-ai-passport
```

The build writes `.passport/folotoy-ai-passport/` and never flashes. With a
board connected:

```sh
.passport/folotoy-ai-passport/flash.sh -p PORT
.passport/folotoy-ai-passport/monitor.sh -p PORT
```

The device embeds the same `sounds.bank`, plays Forest Walk through one of its
independent playback slots, and reports that Playback's position. The SDK Host
supplies the hardware-measured 100 ms presentation lead; application code does
not test Host IDs or hard-code device timing.

## Forest Walk

Forest Walk simulates at 30 Hz and scrolls at 16.875 logical pixels per second.
Its six-pose walk cycle spans one 4/4 bar at 114 quarter BPM (76 dotted-quarter
BPM), with pose 0 on the downbeat. Pose is derived statelessly from the looping
Playback position.

Committed runtime assets:

| File | Role |
| --- | --- |
| `src/forest_walk/generated.mbt` | Six-frame fairy sprites, three parallax layers, palette/index data, and canonical duration/tempo constants. |
| `assets/forest_walk.pcm` | 2,444,800-byte Forest Walk PCM resource: 76.4 seconds at PCM16 LE mono 16000 Hz. |

The template contains no codec, resampler, DAW integration, synthesis,
sequencer, public mixer graph, or audio-authoring tooling.

## Develop

```sh
moon update
moon check --output-json
moon test --output-json
moon info
moon fmt
git diff --exit-code
```

If you create a project from this template, rename the MoonBit module in
`moon.mod` and choose the application-owned package that should expose your
generated Sound mapping.
