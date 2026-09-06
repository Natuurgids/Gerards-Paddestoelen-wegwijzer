#!/usr/bin/env python3
"""Validate committed launcher icon and splash image assets."""
from __future__ import annotations

import struct
from pathlib import Path

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if len(data) < 24 or data[:8] != PNG_SIGNATURE or data[12:16] != b"IHDR":
        raise SystemExit(f"{path} is not a valid PNG")
    return struct.unpack(">II", data[16:24])


icon = Path("assets/app_icon.png")
splash = Path("assets/splash.png")

if not icon.is_file():
    raise SystemExit(f"Missing {icon}")
if not splash.is_file():
    raise SystemExit(f"Missing {splash}")

icon_width, icon_height = png_size(icon)
if icon_width != icon_height or icon_width < 512:
    raise SystemExit(
        f"Launcher icon must be square and at least 512px; got {icon_width}x{icon_height}"
    )

splash_width, splash_height = png_size(splash)
if splash_height <= splash_width or splash_width < 360 or splash_height < 640:
    raise SystemExit(
        f"Splash image must be portrait and at least 360x640; got {splash_width}x{splash_height}"
    )

print(
    f"Validated {icon} ({icon_width}x{icon_height}) and "
    f"{splash} ({splash_width}x{splash_height})"
)
