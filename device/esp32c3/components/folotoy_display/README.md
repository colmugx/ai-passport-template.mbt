# FoloToy AI Passport display BSP subset

The files `src/bsp_display.c`, `include/bsp_display.h`, and
`include/bsp_pins.h` are unmodified copies from the official
[FoloToy/ai-passport](https://github.com/FoloToy/ai-passport) repository at
commit [`c21a015d44f2bcc02b4d859532d74cd7aefe69be`](https://github.com/FoloToy/ai-passport/commit/c21a015d44f2bcc02b4d859532d74cd7aefe69be).
`LICENSE` is the repository's MIT license from the same commit.

Upstream paths:

- `components/bsp/src/bsp_display.c`
- `components/bsp/include/bsp_display.h`
- `components/bsp/include/bsp_pins.h`
- `LICENSE`

The upstream BSP component also compiles button, audio, battery, and LVGL
sources and declares their dependencies. T4.0 uses only the display, so this
component registers the original display source without LVGL or those other
subsystems. The board facts and ST7789P3 initialization remain upstream's.
