#!/usr/bin/env python3
"""Verify that every manifest species image is physically packaged in Windows."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


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


def verify(release_dir: Path, manifest_path: Path) -> int:
    expected = _manifest_paths(manifest_path)
    flutter_assets = release_dir / "data" / "flutter_assets"
    if not flutter_assets.is_dir():
        raise SystemExit(f"Windows Flutter asset directory not found: {flutter_assets}")

    missing = [path for path in expected if not (flutter_assets / Path(path)).is_file()]
    species_root = flutter_assets / "assets" / "images" / "species"
    packaged = [] if not species_root.is_dir() else [
        path for path in species_root.rglob("*")
        if path.is_file() and path.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
    ]

    if missing:
        sample = "\n".join(missing[:10])
        raise SystemExit(
            f"Windows release is missing {len(missing)} of {len(expected)} manifest species images; "
            f"first entries:\n{sample}"
        )
    if len(packaged) < len(expected):
        raise SystemExit(
            f"Windows release contains only {len(packaged)} species image assets; "
            f"expected at least {len(expected)}"
        )

    print(
        f"Windows verification passed: {len(expected)} manifest species images are packaged "
        f"({len(packaged)} species image assets total)"
    )
    return len(expected)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--release-dir", default="build/windows/x64/runner/Release")
    parser.add_argument("--manifest", default="assets/data/species_images.json")
    args = parser.parse_args()
    verify(Path(args.release_dir), Path(args.manifest))


if __name__ == "__main__":
    main()
