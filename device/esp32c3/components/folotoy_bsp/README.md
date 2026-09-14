# FoloToy AI Passport BSP (submodule reference)

This component compiles the official
[FoloToy/ai-passport](https://github.com/FoloToy/ai-passport) BSP **from the
pinned git submodule** at [`external/folotoy-ai-passport`](../../../external/folotoy-ai-passport)
(gitlink at commit
[`c21a015d44f2bcc02b4d859532d74cd7aefe69be`](https://github.com/FoloToy/ai-passport/commit/c21a015d44f2bcc02b4d859532d74cd7aefe69be)).
No BSP source file, header, or license text is copied into this repository;
after cloning, run `git submodule update --init` to fetch it.

Compiled from the submodule (upstream `components/bsp`):

- `src/bsp_display.c`, `src/bsp_i2c.c`, `src/bsp_battery.c`, `src/bsp_audio.c`
- everything under `include/` (exposed verbatim through this component's
  public include path)

Upstream's own component registration is intentionally not used as-is: it
also compiles the button and LVGL display sources and `REQUIRES`
`esp_lvgl_port` plus the managed `button` component, which would link all of
LVGL into this firmware (ESP-IDF whole-archive component linking) and spend
the flash budget this product reserves for music PCM. The selection list in
`CMakeLists.txt` is therefore explicit and auditable; broaden it only
deliberately.

`idf_component.yml` pins `espressif/esp_codec_dev` at upstream's version
(1.6.2) for `bsp_audio.c`, and the upstream IDF range `>=5.5.3,<5.6.0`.
`bsp_i2c.c` remains the single owner of the shared I2C0 bus that the CW2017
battery gauge and ES8311 audio codec share. The board facts (pins, ST7789P3
initialization, I2C addresses) are upstream's alone; bump the submodule
gitlink — nothing here — to change them.
