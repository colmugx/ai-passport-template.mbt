#!/usr/bin/env python3
"""Compile the Forest Walk PNG into a frame-major MoonBit SpriteSheet.

Only Python's standard library is required. The shared decoder accepts 8-bit,
non-interlaced RGB, indexed, and RGBA PNG; partial alpha fails explicitly.
"""

from __future__ import annotations

import sys
from pathlib import Path

from png_decode import read_rgba_png

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/forest_walk/fairy_walk_right.png"
OUTPUT = ROOT / "src/forest_walk/generated/fairy_walk_right.mbt"
SHEET_WIDTH = 168
SHEET_HEIGHT = 32
FRAME_WIDTH = 28
FRAME_HEIGHT = 32
FRAME_COUNT = 6


def compile_pixels(rgba: bytes) -> tuple[list[tuple[int, int, int]], list[int], int]:
    if len(rgba) != SHEET_WIDTH * SHEET_HEIGHT * 4:
        raise ValueError("decoded RGBA byte count does not match 168x32")
    # Validate every source pixel before reordering frames, so diagnostics use
    # coordinates in the authoring PNG rather than compiled frame coordinates.
    transparent = 0
    for y in range(SHEET_HEIGHT):
        for x in range(SHEET_WIDTH):
            alpha = rgba[(y * SHEET_WIDTH + x) * 4 + 3]
            if alpha == 0:
                transparent += 1
            elif alpha != 255:
                raise ValueError(
                    f"{SOURCE}: partial alpha {alpha} at x={x}, y={y}; "
                    "SpriteSheet supports only alpha 0 or 255"
                )

    palette: list[tuple[int, int, int]] = []
    color_to_index: dict[tuple[int, int, int], int] = {}
    indices: list[int] = []
    for frame in range(FRAME_COUNT):
        for y in range(FRAME_HEIGHT):
            for local_x in range(FRAME_WIDTH):
                x = frame * FRAME_WIDTH + local_x
                offset = (y * SHEET_WIDTH + x) * 4
                if rgba[offset + 3] == 0:
                    indices.append(0)
                    continue
                rgb = tuple(rgba[offset : offset + 3])
                if rgb not in color_to_index:
                    color_to_index[rgb] = len(palette) + 1
                    palette.append(rgb)
                indices.append(color_to_index[rgb])
    assert len(indices) == FRAME_COUNT * FRAME_WIDTH * FRAME_HEIGHT
    return palette, indices, transparent


def render_moonbit(
    palette: list[tuple[int, int, int]], indices: list[int]
) -> str:
    if len(palette) > 255:
        raise ValueError("sprite has more than 255 opaque colors; palette indices need a wider encoding")
    digits_per_index = 1 if len(palette) <= 15 else 2
    encoded = "".join(f"{index:0{digits_per_index}X}" for index in indices)
    lines = [
        "// Generated from assets/forest_walk/fairy_walk_right.png",
        "// Do not edit manually.",
        "",
        "///|",
        "pub fn build_fairy_walk_right_sheet() -> @graphics.SpriteSheet {",
        "  let palette : Array[@core.Color?] = [",
        "    None,",
    ]
    for red, green, blue in palette:
        lines.append(
            f"    Some(@core.Color::rgb(r={red}, g={green}, b={blue})),"
        )
    lines.extend(
        [
            "  ]",
            "  // Hex palette indices: frame-major, then row-major per 28x32 frame.",
            "  let encoded : Array[String] = [",
        ]
    )
    for i in range(0, len(encoded), 84):
        lines.append(f'    "{encoded[i : i + 84]}",')
    lines.extend(["  ]", "  let pixels : Array[@core.Color?] = []"])
    if digits_per_index == 2:
        lines.append("  let mut first_nibble = -1")
    lines.extend(
        [
            "  for block in encoded {",
            "    for digit in block {",
            "      let code = digit.to_int()",
            "      let nibble = if code >= 48 && code <= 57 {",
            "        code - 48",
            "      } else if code >= 65 && code <= 70 {",
            "        code - 55",
            "      } else {",
            '        abort("invalid compiled fairy palette index")',
            "      }",
        ]
    )
    if digits_per_index == 1:
        lines.extend(["      pixels.push(palette[nibble])"])
    else:
        lines.extend(
            [
                "      if first_nibble < 0 {",
                "        first_nibble = nibble",
                "      } else {",
                "        pixels.push(palette[first_nibble * 16 + nibble])",
                "        first_nibble = -1",
                "      }",
            ]
        )
    lines.extend(
        [
            "    }",
            "  }",
        ]
    )
    if digits_per_index == 2:
        lines.append("  if first_nibble >= 0 {")
        lines.append('    abort("compiled fairy sprite has an invalid pixel count")')
        lines.append("  }")
    lines.extend(
        [
            "  if pixels.length() != 6 * 28 * 32 {",
            '    abort("compiled fairy sprite has an invalid pixel count")',
            "  }",
            "  @graphics.SpriteSheet::from_colors(frame_width=28, frame_height=32, pixels~)",
            "}",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    try:
        width, height, rgba = read_rgba_png(SOURCE)
        if (width, height) != (SHEET_WIDTH, SHEET_HEIGHT):
            raise ValueError(
                f"{SOURCE}: expected exactly {SHEET_WIDTH}x{SHEET_HEIGHT}, "
                f"got {width}x{height}"
            )
        palette, indices, transparent = compile_pixels(rgba)
        generated = render_moonbit(palette, indices)
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != generated:
            OUTPUT.write_text(generated, encoding="utf-8", newline="\n")
        print(
            f"Compiled {SOURCE.relative_to(ROOT)}: {width}x{height}, "
            f"{FRAME_COUNT} frames of {FRAME_WIDTH}x{FRAME_HEIGHT}, "
            f"{len(palette)} unique opaque RGB colors, "
            f"{transparent} transparent pixels, alpha 0/255 only; "
            f"generated {OUTPUT.relative_to(ROOT)} ({len(generated.encode('utf-8'))} bytes)"
        )
        return 0
    except (OSError, ValueError) as error:
        print(f"sprite compilation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
