#!/usr/bin/env python3
"""Verify that every manifest species image is physically packaged in an APK."""

from __future__ import annotations

import argparse
import json
import zipfile
from pathlib import Path

APK_PREFIX = "assets/flutter_assets/"


def _manifest_paths(manifest_path: Path) -> list[str]:
    payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    paths = [
        str(image.get("path") or "").strip()
        for species in payload.get("species", [])
        for image in species.get("images", [])
    ]
    paths = [path for path in paths if path]
    if not paths:
        raise SystemExit("Species image manifest contains no image paths")
    if len(paths) != len(set(paths)):
        raise SystemExit("Species image manifest contains duplicate image paths")
    return paths


def verify(apk_path: Path, manifest_path: Path) -> int:
    expected = _manifest_paths(manifest_path)
    with zipfile.ZipFile(apk_path) as apk:
        names = set(apk.namelist())

    missing = [path for path in expected if APK_PREFIX + path not in names]
    packaged_species_images = [
        name
        for name in names
        if name.startswith(APK_PREFIX + "assets/images/species/")
        and name.lower().endswith((".jpg", ".jpeg", ".png", ".webp"))
    ]

    if missing:
        sample = "\n".join(missing[:10])
        raise SystemExit(
            f"APK is missing {len(missing)} of {len(expected)} manifest species images; "
            f"first entries:\n{sample}"
        )

    if len(packaged_species_images) < len(expected):
        raise SystemExit(
            f"APK contains only {len(packaged_species_images)} species image assets; "
            f"expected at least {len(expected)}"
        )

    print(
        f"APK verification passed: {len(expected)} manifest species images are packaged "
        f"({len(packaged_species_images)} species image assets total)"
    )
    return len(expected)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", default="build/app/outputs/flutter-apk/app-release.apk")
    parser.add_argument("--manifest", default="assets/data/species_images.json")
    args = parser.parse_args()
    verify(Path(args.apk), Path(args.manifest))


if __name__ == "__main__":
    main()
