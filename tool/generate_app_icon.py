#!/usr/bin/env python3
"""Generate a deterministic launcher icon without binary source assets."""
from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

SIZE = 512
BG = (24, 70, 42)
BG_DARK = (12, 48, 27)
MOSS = (78, 112, 54)
CAP = (151, 82, 37)
CAP_LIGHT = (188, 113, 53)
STEM = (232, 218, 177)
STEM_SHADOW = (197, 180, 139)

pixels = [list(BG) for _ in range(SIZE * SIZE)]


def set_px(x: int, y: int, color: tuple[int, int, int]) -> None:
    if 0 <= x < SIZE and 0 <= y < SIZE:
        pixels[y * SIZE + x] = list(color)


def blend_px(x: int, y: int, color: tuple[int, int, int], alpha: float) -> None:
    if 0 <= x < SIZE and 0 <= y < SIZE:
        old = pixels[y * SIZE + x]
        pixels[y * SIZE + x] = [
            round(old[i] * (1 - alpha) + color[i] * alpha) for i in range(3)
        ]


def ellipse(cx: float, cy: float, rx: float, ry: float, color: tuple[int, int, int], alpha: float = 1.0) -> None:
    x0, x1 = max(0, int(cx - rx) - 1), min(SIZE - 1, int(cx + rx) + 1)
    y0, y1 = max(0, int(cy - ry) - 1), min(SIZE - 1, int(cy + ry) + 1)
    for y in range(y0, y1 + 1):
        dy = (y - cy) / ry
        for x in range(x0, x1 + 1):
            dx = (x - cx) / rx
            if dx * dx + dy * dy <= 1:
                if alpha >= 1:
                    set_px(x, y, color)
                else:
                    blend_px(x, y, color, alpha)


def polygon(points: list[tuple[float, float]], color: tuple[int, int, int]) -> None:
    min_y = max(0, int(min(y for _, y in points)))
    max_y = min(SIZE - 1, int(max(y for _, y in points)))
    for y in range(min_y, max_y + 1):
        xs = []
        for i, (x1, y1) in enumerate(points):
            x2, y2 = points[(i + 1) % len(points)]
            if (y1 <= y < y2) or (y2 <= y < y1):
                if y2 != y1:
                    xs.append(x1 + (y - y1) * (x2 - x1) / (y2 - y1))
        xs.sort()
        for i in range(0, len(xs) - 1, 2):
            for x in range(max(0, int(xs[i])), min(SIZE - 1, int(xs[i + 1])) + 1):
                set_px(x, y, color)


# Soft vignette and forest-floor shapes.
for y in range(SIZE):
    for x in range(SIZE):
        d = math.hypot(x - SIZE / 2, y - SIZE / 2) / (SIZE * 0.71)
        if d > 0.66:
            blend_px(x, y, BG_DARK, min(0.45, (d - 0.66) * 1.3))

for x, y, r in [(92, 398, 38), (140, 420, 26), (370, 410, 34), (416, 388, 25), (77, 345, 18), (439, 342, 19)]:
    ellipse(x, y, r * 1.4, r * 0.55, MOSS, 0.9)

# Stylized fern fronds.
for side in (-1, 1):
    base_x = 256 + side * 132
    for j in range(7):
        cy = 304 - j * 28
        ellipse(base_x + side * (j * 4), cy, 10, 24, MOSS, 0.95)
        ellipse(base_x + side * (28 + j * 2), cy + 8, 22, 8, MOSS, 0.9)
        ellipse(base_x - side * (28 + j * 2), cy + 8, 22, 8, MOSS, 0.9)

# Mushroom stem: broad, slightly tapered, with a shaded base.
polygon([(210, 202), (302, 202), (322, 390), (190, 390)], STEM)
ellipse(256, 388, 70, 35, STEM, 1.0)
polygon([(288, 210), (302, 202), (322, 390), (285, 390)], STEM_SHADOW)
ellipse(282, 382, 32, 25, STEM_SHADOW, 0.55)

# Cap underside and cap.
ellipse(256, 218, 155, 46, (214, 185, 135), 1.0)
ellipse(256, 198, 164, 98, CAP, 1.0)
ellipse(236, 170, 110, 48, CAP_LIGHT, 0.55)
# Crop lower cap into a flatter mushroom silhouette.
for y in range(220, 270):
    for x in range(SIZE):
        if ((x - 256) / 164) ** 2 + ((y - 198) / 98) ** 2 <= 1:
            if y > 225 + 0.08 * abs(x - 256):
                set_px(x, y, (214, 185, 135))

# Subtle inner border to keep contrast across launcher masks.
for y in range(SIZE):
    for x in range(SIZE):
        edge = min(x, y, SIZE - 1 - x, SIZE - 1 - y)
        if edge < 18:
            blend_px(x, y, BG_DARK, (18 - edge) / 18 * 0.65)

raw = bytearray()
for y in range(SIZE):
    raw.append(0)
    for x in range(SIZE):
        raw.extend(pixels[y * SIZE + x])

def chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)

png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
png += chunk(b"IEND", b"")

out = Path("assets/app_icon.png")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_bytes(png)
print(f"Generated {out} ({len(png)} bytes)")
