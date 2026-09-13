# ai-passport-template.mbt

Starter application template for the [FoloToy AI Passport](https://github.com/FoloToy/ai-passport) wearable, built on the `colmugx/ai-passport` Mooncakes SDK.

This repository owns everything that is **not** the reusable SDK:

- **Forest Walk** (`src/forest_walk`) — the reference application: walker loop, layered parallax forest, battery HUD, and the four-voice 6/8 showcase soundtrack. It is the API design test for the SDK and the starting point for a new Passport app.
- **docs/SHOWCASE.md** — Forest Walk's art direction and composition notes.
- Future: browser development preview (Canvas + keyboard + WebAudio), ESP-IDF integration, FoloToy BSP adapter, flashing/provisioning tooling.

The SDK (graphics, input, music, audio, battery, driver contracts) lives in [`colmugx/ai-passport`](https://github.com/colmugx/ai-passport.mbt); app code here imports only its public packages (`@core`, `@input`, `@graphics`, `@music`, `@audio`) and never touches device APIs directly.

## Dependencies

`moon.mod` imports `colmugx/ai-passport@0.1.0`. From mooncakes.io this resolves normally. For local development against an unpublished SDK checkout, a gitignored `moon.work` workspace overrides the resolution — see the comment inside `moon.work.example` and https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html (workspace members).

## Commands

```bash
moon check --target native   # typecheck
moon test  --target native   # run the test suite
moon test  --target js       # the app logic is target-independent
moon fmt                     # canonical formatting
```
