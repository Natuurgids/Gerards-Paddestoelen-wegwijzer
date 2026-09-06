#!/usr/bin/env python3
"""Validate supplied brand PNGs and normalize them for launcher tooling."""
from __future__ import annotations

from pathlib import Path

from PIL import Image


def load_png(path: Path) -> Image.Image:
    if not path.is_file():
        raise SystemExit(f"Missing {path}")
    try:
        image = Image.open(path)
        image.load()
    except Exception as exc:
        raise SystemExit(f"{path} is not a decodable image: {exc}") from exc
    if image.format != "PNG":
        raise SystemExit(f"{path} must be a PNG")
    return image


icon = Path("assets/app_icon.png")
splash = Path("assets/splash.png")

icon_image = load_png(icon)
icon_width, icon_height = icon_image.size
if icon_width != icon_height or icon_width < 512:
    raise SystemExit(
        f"Launcher icon must be square and at least 512px; got {icon_width}x{icon_height}"
    )

splash_image = load_png(splash)
splash_width, splash_height = splash_image.size
if splash_height <= splash_width or splash_width < 360 or splash_height < 640:
    raise SystemExit(
        f"Splash image must be portrait and at least 360x640; got {splash_width}x{splash_height}"
    )

# flutter_launcher_icons does not reliably decode indexed/palette PNGs.
# Normalize the committed supplied artwork to ordinary RGBA in the CI workspace.
if icon_image.mode not in ("RGB", "RGBA"):
    icon_image.convert("RGBA").save(icon, format="PNG", optimize=True)
    print(f"Normalized {icon} from {icon_image.mode} to RGBA")
if splash_image.mode not in ("RGB", "RGBA"):
    splash_image.convert("RGBA").save(splash, format="PNG", optimize=True)
    print(f"Normalized {splash} from {splash_image.mode} to RGBA")

print(
    f"Validated {icon} ({icon_width}x{icon_height}) and "
    f"{splash} ({splash_width}x{splash_height})"
)
