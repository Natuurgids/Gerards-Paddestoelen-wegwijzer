#!/usr/bin/env python3
"""Validate curated species reference-image provenance without ingesting location data."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "assets" / "data" / "species_reference_sources.json"
CATALOG = ROOT / "assets" / "data" / "species_catalog.json"
REQUIRED_LANGUAGES = {"nl", "en", "de"}
FORBIDDEN_LOCATION_KEYS = {
    "gps",
    "latitude",
    "longitude",
    "lat",
    "lon",
    "lng",
    "location",
    "coordinates",
    "camera_location",
    "observation_location",
}


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def catalogue_species_names(catalogue: dict) -> dict[int, str]:
    taxa = {taxon["id"]: taxon["scientific_name"] for taxon in catalogue["taxa"]}
    return {species["id"]: taxa[species["taxon_id"]] for species in catalogue["species"]}


def reject_location_keys(value: object, path: str = "root") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            normalised = key.lower().replace("-", "_")
            if normalised in FORBIDDEN_LOCATION_KEYS:
                raise ValueError(f"location-sensitive key is forbidden at {path}.{key}")
            reject_location_keys(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_location_keys(child, f"{path}[{index}]")


def validate() -> None:
    manifest = load_json(MANIFEST)
    catalogue = load_json(CATALOG)
    species_names = catalogue_species_names(catalogue)

    if manifest.get("version") != 2:
        raise ValueError("species reference manifest version must be 2")

    policy = manifest.get("policy") or {}
    allowed_licenses = set(policy.get("allowed_licenses") or [])
    if not allowed_licenses:
        raise ValueError("allowed license policy must not be empty")
    if set(policy.get("text_languages") or []) != REQUIRED_LANGUAGES:
        raise ValueError("text_languages must contain exactly nl, en and de")

    reject_location_keys(manifest)

    seen_pages: set[str] = set()
    seen_files: set[str] = set()
    seen_species: set[int] = set()
    images = manifest.get("images") or []
    if not images:
        raise ValueError("at least one vetted reference image is required")

    for index, image in enumerate(images):
        label = f"images[{index}]"
        species_id = image.get("species_id")
        scientific_name = image.get("scientific_name")
        if species_id not in species_names:
            raise ValueError(f"{label}: unknown catalogue species_id {species_id!r}")
        expected_name = species_names[species_id]
        if scientific_name != expected_name:
            raise ValueError(
                f"{label}: scientific_name {scientific_name!r} does not match "
                f"catalogue {expected_name!r}"
            )
        if species_id in seen_species:
            raise ValueError(f"{label}: duplicate primary reference for species_id {species_id}")
        seen_species.add(species_id)

        if image.get("source") != "Wikimedia Commons":
            raise ValueError(f"{label}: source must be Wikimedia Commons for this curated set")
        source_page = image.get("source_page") or ""
        if not source_page.startswith("https://commons.wikimedia.org/wiki/File:"):
            raise ValueError(f"{label}: source_page must be a Wikimedia Commons File page")
        if source_page in seen_pages:
            raise ValueError(f"{label}: duplicate source_page")
        seen_pages.add(source_page)

        source_file_name = image.get("source_file_name") or ""
        if not source_file_name:
            raise ValueError(f"{label}: source_file_name is required")
        if source_file_name in seen_files:
            raise ValueError(f"{label}: duplicate source_file_name")
        seen_files.add(source_file_name)

        if not (image.get("creator") or "").strip():
            raise ValueError(f"{label}: creator attribution is required")
        if image.get("license") not in allowed_licenses:
            raise ValueError(f"{label}: license is not allowlisted")
        license_url = image.get("license_url") or ""
        if not license_url.startswith("https://creativecommons.org/"):
            raise ValueError(f"{label}: canonical Creative Commons license_url is required")
        if image.get("review_status") != "vetted":
            raise ValueError(f"{label}: review_status must be vetted")
        if image.get("intended_role") != "primary_reference":
            raise ValueError(f"{label}: intended_role must be primary_reference")

        alt_text = image.get("alt_text") or {}
        if set(alt_text) != REQUIRED_LANGUAGES:
            raise ValueError(f"{label}: alt_text must contain exactly nl, en and de")
        for language in sorted(REQUIRED_LANGUAGES):
            if not isinstance(alt_text[language], str) or not alt_text[language].strip():
                raise ValueError(f"{label}: non-empty {language} alt_text is required")

    print(f"Validated {len(images)} vetted species reference image sources.")


if __name__ == "__main__":
    validate()
