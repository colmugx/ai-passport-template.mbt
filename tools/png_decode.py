#!/usr/bin/env python3
"""Shared minimal PNG reader for the Forest Walk asset compilers.

Only Python's standard library is required. The supported source format is
8-bit, non-interlaced PNG in color types 2 (truecolor RGB), 3 (indexed with
PLTE and optional tRNS), or 6 (truecolor RGBA); anything else fails
explicitly. Decoded pixels are always returned as row-major RGBA bytes.
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
SUPPORTED_COLOR_TYPES = {2: 3, 3: 1, 6: 4}  # color type -> bytes per pixel


def paeth(left: int, above: int, upper_left: int) -> int:
    estimate = left + above - upper_left
    distances = (
        abs(estimate - left),
        abs(estimate - above),
        abs(estimate - upper_left),
    )
    return (left, above, upper_left)[distances.index(min(distances))]


def read_rgba_png(path: Path) -> tuple[int, int, bytes]:
    """Decodes `path` into (width, height, row-major RGBA bytes)."""
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError(f"{path}: invalid PNG signature")

    offset = len(PNG_SIGNATURE)
    dimensions: tuple[int, int] | None = None
    bytes_per_pixel = 0
    color_type = -1
    palette: list[tuple[int, int, int]] | None = None
    palette_alpha: bytes | None = None
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
            if depth != 8 or compression != 0 or filtering != 0 or interlace != 0:
                raise ValueError(
                    f"{path}: expected 8-bit non-interlaced PNG with default "
                    f"compression and filtering; got depth={depth}, "
                    f"color_type={color_type}, compression={compression}, "
                    f"filter={filtering}, interlace={interlace}"
                )
            if color_type not in SUPPORTED_COLOR_TYPES:
                raise ValueError(
                    f"{path}: expected RGB (2), indexed (3), or RGBA (6) PNG; got "
                    f"color_type={color_type}"
                )
            bytes_per_pixel = SUPPORTED_COLOR_TYPES[color_type]
            dimensions = (width, height)
        elif kind == b"PLTE":
            if dimensions is None or idat or palette is not None:
                raise ValueError(f"{path}: PLTE must occur once before IDAT")
            if length == 0 or length % 3 != 0 or length > 256 * 3:
                raise ValueError(f"{path}: invalid PLTE length {length}")
            palette = [tuple(payload[i : i + 3]) for i in range(0, length, 3)]
        elif kind == b"tRNS" and color_type == 3:
            if palette is None or idat or palette_alpha is not None:
                raise ValueError(
                    f"{path}: indexed tRNS must occur once after PLTE and before IDAT"
                )
            if length == 0 or length > len(palette):
                raise ValueError(f"{path}: invalid indexed tRNS length {length}")
            palette_alpha = payload
        elif kind == b"tRNS":
            raise ValueError(f"{path}: tRNS is supported only for indexed PNGs")
        elif kind == b"IDAT":
            if dimensions is None:
                raise ValueError(f"{path}: IDAT precedes IHDR")
            if color_type == 3 and palette is None:
                raise ValueError(f"{path}: indexed PNG has no PLTE before IDAT")
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
    row_bytes = width * bytes_per_pixel
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
            left = row[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
            above = previous[i]
            upper_left = previous[i - bytes_per_pixel] if i >= bytes_per_pixel else 0
            predictor = (
                0,
                left,
                above,
                (left + above) // 2,
                paeth(left, above, upper_left),
            )[filter_type]
            row[i] = (value + predictor) & 0xFF
        destination = y * width * 4
        if bytes_per_pixel == 4:
            rgba[destination : destination + row_bytes] = row
        elif bytes_per_pixel == 3:
            for x in range(width):
                source = x * 3
                target = destination + x * 4
                rgba[target] = row[source]
                rgba[target + 1] = row[source + 1]
                rgba[target + 2] = row[source + 2]
                rgba[target + 3] = 255
        else:
            if palette is None:
                raise ValueError(f"{path}: indexed PNG has no PLTE")
            for x, index in enumerate(row):
                if index >= len(palette):
                    raise ValueError(
                        f"{path}: invalid palette index {index} at x={x}, y={y}"
                    )
                target = destination + x * 4
                rgba[target : target + 3] = bytes(palette[index])
                rgba[target + 3] = (
                    palette_alpha[index]
                    if palette_alpha is not None and index < len(palette_alpha)
                    else 255
                )
        previous = row
    return width, height, bytes(rgba)
