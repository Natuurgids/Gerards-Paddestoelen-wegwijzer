#!/usr/bin/env python3
"""Collect a deterministic, reviewable pilot set of iNaturalist reference images.

This tool is for curation, not runtime identification. It queries research-grade
observations by exact scientific name, accepts only CC0/CC BY media, downloads one
photo per species, removes source metadata by decoding/re-encoding the pixels, and
writes a provenance report without observation coordinates or location fields.

The generated files are review artifacts. They are not silently treated as verified
identifications of user observations and are not committed automatically.
"""

from __future__ import annotations

import argparse
import io
import json
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from PIL import Image

API = "https://api.inaturalist.org/v1/observations"
USER_AGENT = "Gerards-Paddestoelen-Wegwijzer/1.0 reference-image-curation"
ALLOWED_LICENSES = {"cc0": "CC0", "cc-by": "CC BY"}


def _get_json(url: str) -> dict[str, Any]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=45) as response:
        return json.load(response)


def _get_bytes(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def _large_url(photo: dict[str, Any]) -> str:
    url = str(photo.get("url") or "")
    if not url:
        raise ValueError("photo has no URL")
    for size in ("square", "small", "medium"):
        marker = f"/{size}."
        if marker in url:
            return url.replace(marker, "/large.", 1)
    return url


def _species_rows(catalog: dict[str, Any], limit: int | None) -> list[tuple[int, str]]:
    taxa = {
        int(t["id"]): str(t["scientific_name"]).strip()
        for t in catalog.get("taxa", [])
        if t.get("rank") == "species" and t.get("scientific_name")
    }
    rows = []
    for species in catalog.get("species", []):
        species_id = int(species["id"])
        scientific = taxa.get(int(species["taxon_id"]))
        if scientific:
            rows.append((species_id, scientific))
    rows.sort(key=lambda item: item[0])
    return rows[:limit] if limit is not None else rows


def _candidate(scientific_name: str) -> tuple[dict[str, Any], dict[str, Any]] | None:
    params = urllib.parse.urlencode({
        "taxon_name": scientific_name,
        "quality_grade": "research",
        "photos": "true",
        "photo_license": "cc0,cc-by",
        "per_page": 20,
        "order_by": "votes",
        "order": "desc",
    })
    payload = _get_json(f"{API}?{params}")
    for observation in payload.get("results", []):
        taxon = observation.get("taxon") or {}
        if str(taxon.get("name") or "").casefold() != scientific_name.casefold():
            continue
        for photo in observation.get("photos") or []:
            license_code = str(photo.get("license_code") or "").lower()
            if license_code in ALLOWED_LICENSES and photo.get("url"):
                return observation, photo
    return None


def _sanitize_jpeg(raw: bytes, output: Path) -> tuple[int, int]:
    with Image.open(io.BytesIO(raw)) as image:
        image.load()
        image = image.convert("RGB")
        image.thumbnail((1600, 1600), Image.Resampling.LANCZOS)
        width, height = image.size
        output.parent.mkdir(parents=True, exist_ok=True)
        # Re-encoding pixels without EXIF/ICC/comment parameters deliberately drops
        # location and other source metadata from the distributable review asset.
        image.save(output, format="JPEG", quality=88, optimize=True, progressive=True)
        return width, height


def collect(catalog_path: Path, output_dir: Path, report_path: Path, limit: int | None, delay: float) -> dict[str, Any]:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    species_rows = _species_rows(catalog, limit)
    collected: list[dict[str, Any]] = []
    missing: list[dict[str, Any]] = []

    for index, (species_id, scientific_name) in enumerate(species_rows, start=1):
        try:
            found = _candidate(scientific_name)
            if found is None:
                missing.append({"species_id": species_id, "scientific_name": scientific_name, "reason": "no_cc0_or_cc_by_research_grade_photo"})
            else:
                observation, photo = found
                image_url = _large_url(photo)
                output = output_dir / f"species_{species_id}" / "1.jpg"
                width, height = _sanitize_jpeg(_get_bytes(image_url), output)
                license_code = str(photo["license_code"]).lower()
                photo_id = int(photo["id"])
                collected.append({
                    "species_id": species_id,
                    "scientific_name": scientific_name,
                    "source": "iNaturalist",
                    "source_photo_id": photo_id,
                    "source_photo_url": f"https://www.inaturalist.org/photos/{photo_id}",
                    "creator_attribution": str(photo.get("attribution") or "").strip(),
                    "license": ALLOWED_LICENSES[license_code],
                    "license_code": license_code,
                    "retrieved_at": datetime.now(timezone.utc).date().isoformat(),
                    "review_status": "needs_human_review",
                    "intended_role": "primary_reference",
                    "asset_path": str(output).replace("\\", "/"),
                    "pixel_width": width,
                    "pixel_height": height,
                    "alt_text": {
                        "nl": f"Referentiefoto van {scientific_name} voor vergelijking van zichtbare kenmerken.",
                        "en": f"Reference photo of {scientific_name} for comparing visible characteristics.",
                        "de": f"Referenzfoto von {scientific_name} zum Vergleich sichtbarer Merkmale.",
                    },
                })
        except Exception as exc:  # report per-species failures without losing the batch
            missing.append({"species_id": species_id, "scientific_name": scientific_name, "reason": f"request_or_decode_error:{type(exc).__name__}"})
        print(f"[{index}/{len(species_rows)}] {scientific_name}: {'collected' if collected and collected[-1]['species_id'] == species_id else 'missing'}", flush=True)
        if delay > 0 and index < len(species_rows):
            time.sleep(delay)

    report = {
        "version": 1,
        "source": "iNaturalist",
        "policy": {
            "quality_grade": "research",
            "allowed_photo_licenses": ["cc0", "cc-by"],
            "exact_scientific_name_match": True,
            "location_metadata_stored": False,
            "source_metadata_stripped_from_jpeg": True,
            "human_review_required_before_commit": True,
            "identification_note": "Reference imagery supports educational comparison only; it does not verify a user's observation or imply edibility/safety.",
        },
        "catalog_species_considered": len(species_rows),
        "images_collected": len(collected),
        "species_missing_usable_image": len(missing),
        "images": collected,
        "missing": missing,
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: report[k] for k in ("catalog_species_considered", "images_collected", "species_missing_usable_image")}), flush=True)
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="assets/data/species_catalog.json")
    parser.add_argument("--output-dir", default="build/inaturalist-reference-images")
    parser.add_argument("--report", default="build/inaturalist-reference-report.json")
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--delay", type=float, default=0.35, help="Polite delay between species API requests")
    args = parser.parse_args()
    collect(Path(args.catalog), Path(args.output_dir), Path(args.report), args.limit, args.delay)


if __name__ == "__main__":
    main()
