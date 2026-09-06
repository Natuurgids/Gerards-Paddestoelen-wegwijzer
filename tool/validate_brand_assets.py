#!/usr/bin/env python3
"""Validate supplied brand PNGs and normalize indexed PNGs for build tooling."""
from __future__ import annotations

import struct
import zlib
from pathlib import Path

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _chunks(data: bytes):
    pos = 8
    while pos + 12 <= len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + length]
        yield kind, payload
        pos += 12 + length


def png_info(path: Path) -> tuple[int, int, int, int]:
    data = path.read_bytes()
    if len(data) < 33 or data[:8] != PNG_SIGNATURE or data[12:16] != b"IHDR":
        raise SystemExit(f"{path} is not a valid PNG")
    width, height, bit_depth, color_type, _, _, interlace = struct.unpack(
        ">IIBBBBB", data[16:29]
    )
    if interlace != 0:
        raise SystemExit(f"{path} uses unsupported interlacing")
    return width, height, bit_depth, color_type


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def normalize_indexed_png(path: Path) -> None:
    data = path.read_bytes()
    width, height, bit_depth, color_type = png_info(path)
    if color_type != 3:
        return
    if bit_depth not in (1, 2, 4, 8):
        raise SystemExit(f"{path} uses unsupported indexed bit depth {bit_depth}")

    palette = b""
    compressed = bytearray()
    for kind, payload in _chunks(data):
        if kind == b"PLTE":
            palette = payload
        elif kind == b"IDAT":
            compressed.extend(payload)

    if not palette or len(palette) % 3:
        raise SystemExit(f"{path} has an invalid PNG palette")

    packed_row_bytes = (width * bit_depth + 7) // 8
    raw = zlib.decompress(bytes(compressed))
    expected = height * (packed_row_bytes + 1)
    if len(raw) != expected:
        raise SystemExit(f"{path} has unexpected decompressed PNG size")

    rows: list[bytearray] = []
    offset = 0
    previous = bytearray(packed_row_bytes)
    for _ in range(height):
        filter_type = raw[offset]
        offset += 1
        current = bytearray(raw[offset:offset + packed_row_bytes])
        offset += packed_row_bytes
        for i in range(packed_row_bytes):
            left = current[i - 1] if i else 0
            up = previous[i]
            up_left = previous[i - 1] if i else 0
            if filter_type == 1:
                current[i] = (current[i] + left) & 0xFF
            elif filter_type == 2:
                current[i] = (current[i] + up) & 0xFF
            elif filter_type == 3:
                current[i] = (current[i] + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                current[i] = (current[i] + _paeth(left, up, up_left)) & 0xFF
            elif filter_type != 0:
                raise SystemExit(f"{path} uses unknown PNG filter {filter_type}")
        rows.append(current)
        previous = current

    rgb = bytearray()
    mask = (1 << bit_depth) - 1
    pixels_per_byte = 8 // bit_depth
    palette_entries = len(palette) // 3
    for row in rows:
        rgb.append(0)
        emitted = 0
        for value in row:
            for slot in range(pixels_per_byte):
                if emitted >= width:
                    break
                shift = 8 - bit_depth * (slot + 1)
                index = (value >> shift) & mask
                if index >= palette_entries:
                    raise SystemExit(f"{path} references palette index {index}")
                start = index * 3
                rgb.extend(palette[start:start + 3])
                emitted += 1

    def chunk(kind: bytes, payload: bytes) -> bytes:
        crc = zlib.crc32(kind + payload) & 0xFFFFFFFF
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", crc)

    out = bytearray(PNG_SIGNATURE)
    out.extend(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
    out.extend(chunk(b"IDAT", zlib.compress(bytes(rgb), 9)))
    out.extend(chunk(b"IEND", b""))
    path.write_bytes(out)
    print(f"Normalized indexed PNG for build tooling: {path}")


icon = Path("assets/app_icon.png")
splash = Path("assets/splash.png")

if not icon.is_file():
    raise SystemExit(f"Missing {icon}")
if not splash.is_file():
    raise SystemExit(f"Missing {splash}")

icon_width, icon_height, _, _ = png_info(icon)
if icon_width != icon_height or icon_width < 512:
    raise SystemExit(
        f"Launcher icon must be square and at least 512px; got {icon_width}x{icon_height}"
    )

splash_width, splash_height, _, _ = png_info(splash)
if splash_height <= splash_width or splash_width < 360 or splash_height < 640:
    raise SystemExit(
        f"Splash image must be portrait and at least 360x640; got {splash_width}x{splash_height}"
    )

normalize_indexed_png(icon)
normalize_indexed_png(splash)

print(
    f"Validated {icon} ({icon_width}x{icon_height}) and "
    f"{splash} ({splash_width}x{splash_height})"
)
