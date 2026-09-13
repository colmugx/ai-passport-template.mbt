#!/usr/bin/env python3
"""Compile the Forest Walk RGBA PNG into a frame-major MoonBit SpriteSheet.

Only Python's standard library is required. The supported source format is
8-bit, non-interlaced RGBA PNG; unsupported PNG formats fail explicitly.
"""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/forest_walk/fairy_walk_right.png"
OUTPUT = ROOT / "src/forest_walk/generated/fairy_walk_right.mbt"
SHEET_WIDTH = 168
SHEET_HEIGHT = 32
FRAME_WIDTH = 28
FRAME_HEIGHT = 32
FRAME_COUNT = 6
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    distances = (
        abs(estimate - left),
        abs(estimate - above),
        abs(estimate - upper_left),
    )
    return (left, above, upper_left)[distances.index(min(distances))]


def read_rgba_png(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"{path}: invalid PNG signature")

    offset = len(PNG_SIGNATURE)
    dimensions: tuple[int, int] | None = None
    idat = bytearray()
    saw_end = False
    while offset < len(data):
        if offset + 12 > len(data):
            raise ValueError(f"{path}: truncated PNG chunk header")
        length = struct.unpack_from(">I", data, offset)[0]
        kind = data[offset + 4 : offset + 8]
        end = offset + 12 + length
        if end > len(data):
            raise ValueError(f"{path}: truncated {kind!r} chunk")
        payload = data[offset + 8 : offset + 8 + length]
        expected_crc = struct.unpack_from(">I", data, offset + 8 + length)[0]
        actual_crc = zlib.crc32(kind + payload) & 0xFFFFFFFF
        if actual_crc != expected_crc:
            raise ValueError(f"{path}: CRC mismatch in {kind!r} chunk")
        offset = end

        if kind == b"IHDR":
            if dimensions is not None or length != 13:
                raise ValueError(f"{path}: malformed or duplicate IHDR")
            width, height, depth, color_type, compression, filtering, interlace = (
                struct.unpack(">IIBBBBB", payload)
            )
            if (depth, color_type, compression, filtering, interlace) != (
                8,
                6,
                0,
                0,
                0,
            ):
                raise ValueError(
                    f"{path}: expected 8-bit non-interlaced RGBA PNG; got "
                    f"depth={depth}, color_type={color_type}, compression={compression}, "
                    f"filter={filtering}, interlace={interlace}"
                )
            dimensions = (width, height)
            if dimensions != (SHEET_WIDTH, SHEET_HEIGHT):
                raise ValueError(
                    f"{path}: expected exactly {SHEET_WIDTH}x{SHEET_HEIGHT}, "
                    f"got {width}x{height}"
                )
        elif kind == b"IDAT":
            if dimensions is None:
                raise ValueError(f"{path}: IDAT precedes IHDR")
            idat.extend(payload)
        elif kind == b"IEND":
            if length != 0 or offset != len(data):
                raise ValueError(f"{path}: malformed IEND or trailing data")
            saw_end = True
            break
        elif kind[0] & 0x20 == 0:
            raise ValueError(f"{path}: unsupported critical PNG chunk {kind!r}")

    if dimensions is None or not idat or not saw_end:
        raise ValueError(f"{path}: missing IHDR, IDAT, or IEND")
    width, height = dimensions
    row_bytes = width * 4
    try:
        compressed_rows = zlib.decompress(idat)
    except zlib.error as error:
        raise ValueError(f"{path}: invalid compressed image data: {error}") from error
    expected_length = height * (row_bytes + 1)
    if len(compressed_rows) != expected_length:
        raise ValueError(
            f"{path}: expected {expected_length} decompressed bytes, "
            f"got {len(compressed_rows)}"
        )

    rgba = bytearray(width * height * 4)
    previous = bytearray(row_bytes)
    for y in range(height):
        start = y * (row_bytes + 1)
        filter_type = compressed_rows[start]
        raw = compressed_rows[start + 1 : start + 1 + row_bytes]
        row = bytearray(row_bytes)
        if filter_type > 4:
            raise ValueError(f"{path}: unsupported PNG filter {filter_type} at row {y}")
        for i, value in enumerate(raw):
            left = row[i - 4] if i >= 4 else 0
            above = previous[i]
            upper_left = previous[i - 4] if i >= 4 else 0
            predictor = (
                0,
                left,
                above,
                (left + above) // 2,
                paeth(left, above, upper_left),
            )[filter_type]
            row[i] = (value + predictor) & 0xFF
        rgba[y * row_bytes : (y + 1) * row_bytes] = row
        previous = row
    return width, height, bytes(rgba)


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
