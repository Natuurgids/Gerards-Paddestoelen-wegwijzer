#!/usr/bin/env python3
"""Declare every nested species image directory as a Flutter asset.

Flutter directory asset declarations are not recursive. The collected reference
images live at assets/images/species/species_<id>/1.jpg, so declaring only
assets/images/species/ does not package those files. This script expands the
pubspec in the CI workspace from the authoritative image manifest.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

BASE_DECLARATION = "    - assets/images/species/"
START_MARKER = "    # BEGIN GENERATED NESTED SPECIES ASSETS"
END_MARKER = "    # END GENERATED NESTED SPECIES ASSETS"


def _manifest_paths(manifest_path: Path) -> list[str]:
    payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    paths: list[str] = []
    for species in payload.get("species", []):
        for image in species.get("images", []):
            path = str(image.get("path") or "").strip()
            if not path.startswith("assets/images/species/"):
                raise SystemExit(f"Invalid species image path in manifest: {path!r}")
            paths.append(path)

    if not paths:
        raise SystemExit("Species image manifest contains no image paths")
    if len(paths) != len(set(paths)):
        raise SystemExit("Species image manifest contains duplicate image paths")
    return paths


def prepare(pubspec_path: Path, manifest_path: Path) -> int:
    paths = _manifest_paths(manifest_path)
    missing = [path for path in paths if not Path(path).is_file()]
    if missing:
        sample = "\n".join(missing[:10])
        raise SystemExit(
            f"{len(missing)} manifest species images are missing from checkout; first entries:\n{sample}"
        )

    directories = sorted({str(Path(path).parent).replace("\\", "/") + "/" for path in paths})
    text = pubspec_path.read_text(encoding="utf-8")
    if BASE_DECLARATION not in text:
        raise SystemExit(f"Could not find Flutter species asset declaration in {pubspec_path}")
    if START_MARKER in text or END_MARKER in text:
        raise SystemExit("Generated nested species asset block already exists")

    generated = "\n".join(
        [START_MARKER, *(f"    - {directory}" for directory in directories), END_MARKER]
    )
    text = text.replace(BASE_DECLARATION, f"{BASE_DECLARATION}\n{generated}", 1)
    pubspec_path.write_text(text, encoding="utf-8")

    print(
        f"Declared {len(directories)} nested species asset directories "
        f"covering {len(paths)} manifest images"
    )
    return len(paths)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pubspec", default="pubspec.yaml")
    parser.add_argument("--manifest", default="assets/data/species_images.json")
    args = parser.parse_args()
    prepare(Path(args.pubspec), Path(args.manifest))


if __name__ == "__main__":
    main()
