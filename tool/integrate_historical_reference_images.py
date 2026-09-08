#!/usr/bin/env python3
"""Compare a historical full-catalogue image artifact with the current manifest.

Only species that do not already have a manifest entry are integrated, and only
when the historical record is explicitly CC0 or plain CC BY. Existing species
are classified as byte-identical duplicates or alternate photos but are never
replaced or appended by this tool.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path

ALLOWED = {"CC0", "CC BY"}
SPECIES_IMAGE_RE = re.compile(r"species_(\d+)[/\\]1\.jpg$", re.I)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def historical_image_index(root: Path) -> dict[int, Path]:
    index: dict[int, Path] = {}
    for path in root.rglob("1.jpg"):
        match = SPECIES_IMAGE_RE.search(path.as_posix())
        if not match:
            continue
        species_id = int(match.group(1))
        if species_id in index:
            raise SystemExit(f"Duplicate historical image for species {species_id}")
        index[species_id] = path
    return index


def manifest_image_path(entry: dict) -> Path | None:
    images = entry.get("images") or []
    if not images:
        return None
    path = str(images[0].get("path") or "").strip()
    return Path(path) if path else None


def integrate(artifact_root: Path, manifest_path: Path, report_path: Path) -> dict:
    reports = list(artifact_root.rglob("full-catalogue-reference-images.json"))
    if len(reports) != 1:
        raise SystemExit(f"Expected one merged historical report; found {len(reports)}")
    historical = json.loads(reports[0].read_text(encoding="utf-8"))
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    historical_images = historical_image_index(artifact_root)

    manifest_species = manifest.setdefault("species", [])
    current = {int(item["speciesId"]): item for item in manifest_species}
    candidates = {int(item["species_id"]): item for item in historical.get("images", [])}
    missing_files = sorted(set(candidates) - set(historical_images))
    if missing_files:
        raise SystemExit(
            f"Historical artifact lacks image files for {len(missing_files)} report entries; "
            f"first IDs: {missing_files[:10]}"
        )

    overlap = sorted(set(current) & set(candidates))
    new_ids = sorted(set(candidates) - set(current))
    identical: list[int] = []
    alternates: list[int] = []
    overlap_unverifiable: list[int] = []

    for species_id in overlap:
        current_image = manifest_image_path(current[species_id])
        if current_image is None or not current_image.is_file():
            overlap_unverifiable.append(species_id)
            continue
        if sha256(historical_images[species_id]) == sha256(current_image):
            identical.append(species_id)
        else:
            alternates.append(species_id)

    integrated: list[int] = []
    rejected_license: list[int] = []
    for species_id in new_ids:
        record = candidates[species_id]
        licence = str(record.get("license") or "").strip()
        if licence not in ALLOWED:
            rejected_license.append(species_id)
            continue

        source_image = historical_images[species_id]
        destination = Path("assets/images/species") / f"species_{species_id}" / "1.jpg"
        if destination.exists():
            raise SystemExit(
                f"Species {species_id} is absent from manifest but destination already exists: {destination}"
            )
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_image, destination)

        manifest_species.append(
            {
                "speciesId": species_id,
                "images": [
                    {
                        "path": destination.as_posix(),
                        "angle": "reference",
                        "order": 0,
                        "primary": True,
                        "photographer": str(record.get("creator_attribution") or ""),
                        "license": licence,
                        "source": "GBIF",
                        "sourceUrl": str(record.get("source_occurrence_url") or ""),
                        "originalPhotoUrl": str(record.get("source_photo_url") or ""),
                        "retrievedAt": str(record.get("retrieved_at") or ""),
                        "reviewStatus": str(record.get("review_status") or "needs_human_review"),
                    }
                ],
            }
        )
        integrated.append(species_id)

    manifest_species.sort(key=lambda item: int(item["speciesId"]))
    if integrated:
        manifest_path.write_text(
            json.dumps(manifest, ensure_ascii=False, separators=(",", ":")) + "\n",
            encoding="utf-8",
        )

    summary = {
        "historical_images": len(candidates),
        "current_manifest_species_with_images_before": len(current),
        "overlap_species": len(overlap),
        "byte_identical_overlap": len(identical),
        "different_photo_overlap": len(alternates),
        "overlap_unverifiable": len(overlap_unverifiable),
        "new_species_candidates": len(new_ids),
        "new_rejected_for_license": len(rejected_license),
        "new_integrated": len(integrated),
        "current_manifest_species_with_images_after": len(current) + len(integrated),
        "integrated_species_ids": integrated,
        "different_photo_species_ids": alternates,
        "rejected_license_species_ids": rejected_license,
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False))
    return summary


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--artifact-root", required=True)
    parser.add_argument("--manifest", default="assets/data/species_images.json")
    parser.add_argument("--report", default="build/historical-image-integration-report.json")
    args = parser.parse_args()
    integrate(Path(args.artifact_root), Path(args.manifest), Path(args.report))


if __name__ == "__main__":
    main()
