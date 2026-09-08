#!/usr/bin/env python3
"""Merge sharded offline reference-image collection outputs.

Each shard contains sanitized small JPEGs plus a provenance report with the original
source photo URL, creator attribution and licence. The merged output preserves only
one local image per species and keeps missing/retryable status for follow-up runs.

The distributable app policy is deliberately narrower than the collectors may be:
only CC0 and CC BY images are copied into the offline pack. Other or unknown rights
are reported as missing/incompatible and are never bundled.
"""
from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path

ALLOWED_OFFLINE_LICENSES = {"CC0", "CC BY"}


def merge(input_dir: Path, output_dir: Path, report_path: Path) -> dict:
    reports = sorted(input_dir.glob("**/batch-*.json"))
    if not reports:
        raise ValueError(f"No batch reports found under {input_dir}")

    images: dict[int, dict] = {}
    missing: dict[int, dict] = {}
    considered = 0
    batch_count = None

    for path in reports:
        payload = json.loads(path.read_text(encoding="utf-8"))
        considered += int(payload.get("catalog_species_considered") or 0)
        current_batch_count = int((payload.get("batch") or {}).get("count") or 0)
        if batch_count is None:
            batch_count = current_batch_count
        elif current_batch_count != batch_count:
            raise ValueError("Batch reports disagree on batch count")

        for item in payload.get("images", []):
            species_id = int(item["species_id"])
            if species_id in images:
                raise ValueError(f"Duplicate collected image for species {species_id}")
            record = dict(item)
            licence = str(record.get("license") or "").strip()
            if licence not in ALLOWED_OFFLINE_LICENSES:
                missing[species_id] = {
                    "species_id": species_id,
                    "scientific_name": record.get("scientific_name"),
                    "search_name": record.get("search_name"),
                    "status": "image_available_but_incompatible_or_unknown_license",
                    "observed_license": licence or "unknown",
                    "source": record.get("source") or payload.get("source"),
                    "source_observation_url": record.get("source_observation_url"),
                    "source_occurrence_url": record.get("source_occurrence_url"),
                    "retryable": False,
                }
                continue

            local = input_dir / str(record["asset_path"])
            if not local.is_file():
                candidates = list(input_dir.glob(f"**/species_{species_id}/1.jpg"))
                if len(candidates) != 1:
                    raise ValueError(f"Expected exactly one JPEG for species {species_id}")
                local = candidates[0]
            destination = output_dir / f"species_{species_id}" / "1.jpg"
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(local, destination)
            record["asset_path"] = str(destination).replace("\\", "/")
            images[species_id] = record
            missing.pop(species_id, None)

        for item in payload.get("missing", []):
            species_id = int(item["species_id"])
            if species_id not in images and species_id not in missing:
                missing[species_id] = dict(item)

    incompatible_count = sum(
        1
        for item in missing.values()
        if item.get("status") == "image_available_but_incompatible_or_unknown_license"
    )
    merged = {
        "version": 2,
        "source": "reference image collection",
        "mode": "collect",
        "allowed_image_licenses": sorted(ALLOWED_OFFLINE_LICENSES),
        "catalog_species_considered": considered,
        "species_with_offline_image": len(images),
        "species_missing_usable_image": len(missing),
        "species_with_incompatible_or_unknown_image_license": incompatible_count,
        "retryable_errors": sum(1 for item in missing.values() if item.get("retryable")),
        "policy": {
            "offline_first": True,
            "small_local_jpeg": True,
            "original_source_link_retained": True,
            "creator_and_license_retained": True,
            "location_metadata_stored": False,
            "redistributable_licenses": ["CC0", "CC BY"],
        },
        "images": [images[key] for key in sorted(images)],
        "missing": [missing[key] for key in sorted(missing)],
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(merged, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return merged


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-dir", default="build/reference-image-shards")
    parser.add_argument("--output-dir", default="build/offline-reference-images")
    parser.add_argument("--report", default="build/full-catalogue-reference-images.json")
    args = parser.parse_args()
    report = merge(Path(args.input_dir), Path(args.output_dir), Path(args.report))
    print(json.dumps({
        "catalog_species_considered": report["catalog_species_considered"],
        "species_with_offline_image": report["species_with_offline_image"],
        "species_missing_usable_image": report["species_missing_usable_image"],
        "species_with_incompatible_or_unknown_image_license": report["species_with_incompatible_or_unknown_image_license"],
        "retryable_errors": report["retryable_errors"],
    }), flush=True)


if __name__ == "__main__":
    main()
