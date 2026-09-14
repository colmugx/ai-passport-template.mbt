#!/usr/bin/env python3
"""Compile the Forest Walk scenery PNGs into indexed MoonBit layer builders.

PNG files are authoring assets only: browser and future device builds consume
the generated MoonBit source, never the PNG at runtime. For each scenery
layer this script

1. decodes the authoring PNG (truecolor RGB or RGBA, see png_decode),
2. resizes it to the fixed 240x160 layer size with nearest-neighbour
   sampling,
3. thresholds alpha at 128 for layers that support transparency
   (alpha < 128 -> transparent, alpha >= 128 -> opaque),
4. reduces the opaque colors to at most 128 with a deterministic median-cut
   quantizer (skipped when the source already has few enough colors),
5. emits one self-contained MoonBit builder under
   src/forest_walk/generated/ with a compact palette + one-byte hex-encoded
   indices, and prints a per-layer report.

Running the compiler twice without changing the assets produces byte-identical
output.
"""

from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

from png_decode import read_rgba_png

ROOT = Path(__file__).resolve().parents[1]
GENERATED = ROOT / "src/forest_walk/generated"
LAYER_WIDTH = 240
LAYER_HEIGHT = 160
MAX_OPAQUE_COLORS = 128
ALPHA_THRESHOLD = 128  # alpha < threshold -> transparent, else opaque
HEX_LINE_CHARS = 84  # proven moon-fmt-stable line width for encoded indices


@dataclass(frozen=True)
class LayerSpec:
    name: str
    source: Path
    description: str
    transparent: bool


LAYERS = [
    LayerSpec(
        name="forest_far",
        source=ROOT / "assets/forest_walk/forest_far.png",
        description=(
            "Far depth: pale mist and distant forest silhouettes, "
            "scrolled at 1/8 world speed"
        ),
        transparent=False,
    ),
    LayerSpec(
        name="forest_world",
        source=ROOT / "assets/forest_walk/forest_world.png",
        description=(
            "World depth: forest and the walking road the fairy stands on, "
            "scrolled at world speed; its transparent gaps reveal the far layer"
        ),
        transparent=True,
    ),
    LayerSpec(
        name="forest_foreground",
        source=ROOT / "assets/forest_walk/forest_foreground.png",
        description=(
            "Foreground depth: dark foliage occluding the fairy, "
            "scrolled at 3/2 world speed"
        ),
        transparent=True,
    ),
]


def resize_nearest(
    rgba: bytes, source_width: int, source_height: int
) -> tuple[bytes, int, int]:
    """Nearest-neighbour resize to LAYER_WIDTH x LAYER_HEIGHT."""
    out = bytearray(LAYER_WIDTH * LAYER_HEIGHT * 4)
    for y in range(LAYER_HEIGHT):
        source_y = ((2 * y + 1) * source_height) // (2 * LAYER_HEIGHT)
        source_row = source_y * source_width
        out_row = y * LAYER_WIDTH
        for x in range(LAYER_WIDTH):
            source_x = ((2 * x + 1) * source_width) // (2 * LAYER_WIDTH)
            offset = (source_row + source_x) * 4
            destination = (out_row + x) * 4
            out[destination : destination + 4] = rgba[offset : offset + 4]
    return bytes(out), LAYER_WIDTH, LAYER_HEIGHT


def median_cut_palette(
    color_counts: dict[tuple[int, int, int], int], max_colors: int
) -> list[tuple[int, int, int]]:
    """Deterministic median-cut reduction to at most `max_colors` colors.

    Boxes are chosen by largest population (ties by the longest channel
    range, then by insertion order) and split at the weighted median of
    their longest channel. Palette colors are count-weighted box averages,
    rounded half-up.
    """
    if len(color_counts) <= max_colors:
        return sorted(color_counts)

    boxes: list[list[tuple[tuple[int, int, int], int]]] = [
        sorted(color_counts.items())
    ]
    while len(boxes) < max_colors:
        best_key: tuple[int, int] | None = None
        best_index = -1
        best_axis = -1
        for index, box in enumerate(boxes):
            if len(box) < 2:
                continue
            population = sum(count for _, count in box)
            ranges = [
                max(color[channel] for color, _ in box)
                - min(color[channel] for color, _ in box)
                for channel in range(3)
            ]
            longest = max(ranges)
            key = (population, longest)
            if best_key is None or key > best_key:
                best_key = key
                best_index = index
                best_axis = ranges.index(longest)
        if best_index < 0:
            break
        box = sorted(
            boxes[best_index], key=lambda item: (item[0][best_axis], item[0])
        )
        total = sum(count for _, count in box)
        accumulated = 0
        split = len(box) - 1
        for position, (_, count) in enumerate(box):
            accumulated += count
            if accumulated * 2 >= total:
                split = position + 1
                break
        split = min(max(split, 1), len(box) - 1)
        boxes[best_index] = box[:split]
        boxes.insert(best_index + 1, box[split:])

    palette: list[tuple[int, int, int]] = []
    seen: dict[tuple[int, int, int], int] = {}
    for box in boxes:
        total = sum(count for _, count in box)
        average = tuple(
            (2 * sum(color[channel] * count for color, count in box) + total)
            // (2 * total)
            for channel in range(3)
        )
        if average not in seen:
            seen[average] = len(palette)
            palette.append(average)  # type: ignore[arg-type]
    return palette


def nearest_index(
    palette: list[tuple[int, int, int]], color: tuple[int, int, int]
) -> int:
    """Index of the palette color nearest to `color`; ties keep the lowest index."""
    red, green, blue = color
    best_index = 0
    best_distance: int | None = None
    for index, (pr, pg, pb) in enumerate(palette):
        distance = (red - pr) ** 2 + (green - pg) ** 2 + (blue - pb) ** 2
        if best_distance is None or distance < best_distance:
            best_distance = distance
            best_index = index
    return best_index


def compile_indices(
    rgba: bytes, palette: list[tuple[int, int, int]], transparent: bool
) -> tuple[bytes, int, int]:
    """Maps resized RGBA pixels to palette indices.

    Returns (indices bytes, opaque pixel count, transparent pixel count).
    Transparent layers reserve index 0, so opaque colors start at index 1.
    """
    cache: dict[tuple[int, int, int], int] = {}
    indices = bytearray(LAYER_WIDTH * LAYER_HEIGHT)
    opaque = 0
    transparent_count = 0
    for pixel in range(LAYER_WIDTH * LAYER_HEIGHT):
        offset = pixel * 4
        if rgba[offset + 3] < ALPHA_THRESHOLD:
            transparent_count += 1
            continue
        opaque += 1
        color = (rgba[offset], rgba[offset + 1], rgba[offset + 2])
        index = cache.get(color)
        if index is None:
            index = nearest_index(palette, color)
            cache[color] = index
        indices[pixel] = index + 1 if transparent else index
    return bytes(indices), opaque, transparent_count


def render_moonbit(
    spec: LayerSpec,
    source_size: tuple[int, int],
    palette: list[tuple[int, int, int]],
    indices: bytes,
    quantizer: str,
) -> str:
    """Renders one fmt-stable generated MoonBit builder file."""
    transparent_index = "Some(0)" if spec.transparent else "None"
    encoded = "".join(f"{index:02X}" for index in indices)
    encoded_lines = [
        f'    "{encoded[start : start + HEX_LINE_CHARS]}",'
        for start in range(0, len(encoded), HEX_LINE_CHARS)
    ]
    lines = [
        f"// Generated from {spec.source.relative_to(ROOT)}",
        "// Do not edit manually.",
        "//",
        f"// {spec.description}.",
        "// "
        f"{LAYER_WIDTH}x{LAYER_HEIGHT} output, nearest-neighbour resized "
        f"from {source_size[0]}x{source_size[1]}.",
        f"// {len(palette)} opaque colors ({quantizer}, max {MAX_OPAQUE_COLORS}).",
    ]
    if spec.transparent:
        lines.append(
            f"// Alpha below {ALPHA_THRESHOLD} maps to the reserved "
            "transparent index 0."
        )
    else:
        lines.append("// The layer is fully opaque and has no transparent index.")
    lines += [
        "",
        "///|",
        f"pub fn build_{spec.name}_layer() -> IndexedLayer {{",
        "  let palette : Array[@core.Color] = [",
    ]
    if spec.transparent:
        lines += [
            "    // Index 0 is the reserved transparent slot and is never sampled.",
            "    @core.Color::rgb(r=255, g=0, b=255),",
        ]
    for red, green, blue in palette:
        lines.append(f"    @core.Color::rgb(r={red}, g={green}, b={blue}),")
    lines += [
        "  ]",
        "  // Hex palette indices: row-major over "
        f"{LAYER_WIDTH}x{LAYER_HEIGHT}, two hex digits per pixel.",
        "  let encoded : Array[String] = [",
        *encoded_lines,
        "  ]",
        "  indexed_layer(",
        f"    width={LAYER_WIDTH},",
        f"    height={LAYER_HEIGHT},",
        "    palette~,",
        "    encoded~,",
        f"    transparent_index={transparent_index},",
        "  )",
        "}",
        "",
    ]
    return "\n".join(lines)


def compile_layer(spec: LayerSpec) -> str:
    source_width, source_height, rgba = read_rgba_png(spec.source)
    resized, _, _ = resize_nearest(rgba, source_width, source_height)

    color_counts: dict[tuple[int, int, int], int] = {}
    for pixel in range(LAYER_WIDTH * LAYER_HEIGHT):
        offset = pixel * 4
        if resized[offset + 3] < ALPHA_THRESHOLD:
            continue
        color = (resized[offset], resized[offset + 1], resized[offset + 2])
        color_counts[color] = color_counts.get(color, 0) + 1
    if not color_counts:
        raise ValueError(f"{spec.source}: layer has no opaque pixels")

    palette = median_cut_palette(color_counts, MAX_OPAQUE_COLORS)
    quantizer = "exact" if len(color_counts) <= MAX_OPAQUE_COLORS else "median cut"

    indices, opaque, transparent_count = compile_indices(
        resized, palette, spec.transparent
    )
    if not spec.transparent and transparent_count > 0:
        raise ValueError(
            f"{spec.source}: layer is declared fully opaque but has "
            f"{transparent_count} pixels with alpha below {ALPHA_THRESHOLD}"
        )
    generated = render_moonbit(
        spec, (source_width, source_height), palette, indices, quantizer
    )

    output = GENERATED / f"{spec.name}.mbt"
    output.parent.mkdir(parents=True, exist_ok=True)
    if not output.exists() or output.read_text(encoding="utf-8") != generated:
        output.write_text(generated, encoding="utf-8", newline="\n")
    print(
        f"{spec.name}: source {source_width}x{source_height} -> "
        f"{LAYER_WIDTH}x{LAYER_HEIGHT}, opaque {opaque}, "
        f"transparent {transparent_count}, palette {len(palette)} "
        f"({quantizer}), generated {output.relative_to(ROOT)} "
        f"({len(generated.encode('utf-8'))} bytes)"
    )
    return generated


def main() -> int:
    try:
        for spec in LAYERS:
            compile_layer(spec)
        return 0
    except (OSError, ValueError) as error:
        print(f"layer compilation failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
