#!/usr/bin/env python3
"""Fail release builds when live source enrichment drifts from the reviewed snapshot."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def _count_species_with_source(species: list[dict], source_id: str) -> int:
    return sum(1 for item in species if item.get("source_id") == source_id)


def _count_localized_names(species: list[dict], locale: str, source_id: str) -> int:
    count = 0
    for item in species:
        texts = item.get("texts") or {}
        localized = texts.get(locale) or {}
        if localized.get("common_name_source_id") == source_id:
            count += 1
    return count


def _count_conservation(species: list[dict], source_id: str) -> int:
    return sum(1 for item in species if item.get("conservation_source_id") == source_id)


def verify(catalog_path: Path, lock_path: Path) -> None:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    lock = json.loads(lock_path.read_text(encoding="utf-8"))
    species = list(catalog.get("species") or [])
    expected = lock["catalogue"]

    actual = {
        "total_species": len(species),
        "nsr_species": _count_species_with_source(species, "nsr-dutch-species-register"),
        "dgfm_german_names": _count_localized_names(species, "de", "dgfm-german-fungi"),
        "uksi_english_names": _count_localized_names(
            species, "en", "uksi-natural-history-museum"
        ),
        "iucn_statuses": _count_conservation(species, "iucn-red-list"),
    }

    source_ids = {str(item.get("id")) for item in catalog.get("sources") or []}
    missing_sources = sorted(set(lock.get("required_sources") or []) - source_ids)
    mismatches = {
        key: {"expected": expected[key], "actual": value}
        for key, value in actual.items()
        if value != expected.get(key)
    }
    if missing_sources or mismatches:
        details = []
        if missing_sources:
            details.append(f"missing sources: {', '.join(missing_sources)}")
        if mismatches:
            details.append(f"count drift: {json.dumps(mismatches, sort_keys=True)}")
        raise ValueError(
            "Source snapshot drift detected; review upstream changes and update "
            f"{lock_path} deliberately. " + "; ".join(details)
        )

    print(
        "Source snapshot lock verified: "
        + ", ".join(f"{key}={value}" for key, value in actual.items())
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="assets/data/species_catalog.json")
    parser.add_argument("--lock", default="tool/source_snapshot_lock.json")
    args = parser.parse_args()
    verify(Path(args.catalog), Path(args.lock))


if __name__ == "__main__":
    main()
