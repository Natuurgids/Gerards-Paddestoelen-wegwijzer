#!/usr/bin/env python3
"""Collect licensed GBIF reference images without using iNaturalist records."""
from __future__ import annotations

import argparse
import io
import json
import re
import socket
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from PIL import Image, UnidentifiedImageError

MATCH_API = "https://api.gbif.org/v2/species/match"
OCCURRENCE_API = "https://api.gbif.org/v1/occurrence/search"
USER_AGENT = "Gerards-Paddestoelen-Wegwijzer/1.0 GBIF-reference-image-curation"
MAX_IMAGE_PIXELS = 600
JPEG_QUALITY = 80
STRATEGY_VERSION = 1


def _get_json(url: str) -> dict[str, Any]:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=45) as response:
        return json.load(response)


def _get_bytes(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=60) as response:
        return response.read()


def _canonical_name(name: str) -> str:
    parts = re.sub(r"\s+", " ", name.strip()).split(" ")
    return " ".join(parts[:2]) if len(parts) >= 2 else name.strip()


def _species_rows(catalog: dict[str, Any], batch_index: int, batch_count: int) -> list[tuple[int, str]]:
    taxa = {
        int(t["id"]): str(t["scientific_name"]).strip()
        for t in catalog.get("taxa", [])
        if t.get("rank") == "species" and t.get("scientific_name")
    }
    rows = []
    for species in catalog.get("species", []):
        name = taxa.get(int(species["taxon_id"]))
        if name:
            rows.append((int(species["id"]), name))
    rows.sort()
    return [row for i, row in enumerate(rows) if i % batch_count == batch_index]


def _resolve(name: str) -> dict[str, Any] | None:
    params = urllib.parse.urlencode({"scientificName": _canonical_name(name), "kingdom": "Fungi"})
    payload = _get_json(f"{MATCH_API}?{params}")
    usage = payload.get("usage") or {}
    if str(usage.get("rank") or "").upper() != "SPECIES" or not usage.get("key"):
        return None
    return usage


def _is_inaturalist(record: dict[str, Any], media: dict[str, Any]) -> bool:
    fields = [
        record.get("datasetTitle"), record.get("institutionCode"), record.get("publishingOrgKey"),
        media.get("identifier"), media.get("references"), media.get("title"), media.get("description"),
    ]
    return "inaturalist" in " ".join(str(v or "") for v in fields).casefold()


def _license(media: dict[str, Any]) -> tuple[str, str] | None:
    raw = str(media.get("license") or media.get("rights") or "").strip()
    low = raw.casefold()
    if "by-nc" in low or "by_nc" in low or "noncommercial" in low:
        return None
    if "creativecommons.org/publicdomain/zero" in low or "cc0" in low:
        return "CC0", "https://creativecommons.org/publicdomain/zero/1.0/"
    if "creativecommons.org/licenses/by-sa" in low or "cc by-sa" in low or "cc_by_sa" in low:
        return "CC BY-SA", raw or "https://creativecommons.org/licenses/by-sa/4.0/"
    if "creativecommons.org/licenses/by/" in low or "cc by" in low or "cc_by" in low:
        return "CC BY", raw or "https://creativecommons.org/licenses/by/4.0/"
    return None


def _candidate(taxon_key: str) -> tuple[dict[str, Any], dict[str, Any], tuple[str, str]] | None:
    params = urllib.parse.urlencode({"taxon_key": taxon_key, "media_type": "StillImage", "limit": 100})
    payload = _get_json(f"{OCCURRENCE_API}?{params}")
    for record in payload.get("results", []):
        for media in record.get("media") or []:
            if str(media.get("type") or "").casefold() != "stillimage":
                continue
            if _is_inaturalist(record, media):
                continue
            identifier = str(media.get("identifier") or "").strip()
            lic = _license(media)
            if identifier and lic:
                return record, media, lic
    return None


def _sanitize(raw: bytes, output: Path) -> tuple[int, int]:
    with Image.open(io.BytesIO(raw)) as image:
        image.load()
        image = image.convert("RGB")
        image.thumbnail((MAX_IMAGE_PIXELS, MAX_IMAGE_PIXELS), Image.Resampling.LANCZOS)
        output.parent.mkdir(parents=True, exist_ok=True)
        image.save(output, "JPEG", quality=JPEG_QUALITY, optimize=True, progressive=True)
        return image.size


def _load_report(path: Path) -> tuple[dict[int, dict[str, Any]], dict[int, dict[str, Any]]]:
    if not path.exists():
        return {}, {}
    data = json.loads(path.read_text(encoding="utf-8"))
    return (
        {int(x["species_id"]): x for x in data.get("images", [])},
        {int(x["species_id"]): x for x in data.get("missing", [])},
    )


def _write(path: Path, rows: list[tuple[int, str]], images: list[dict[str, Any]], missing: list[dict[str, Any]], batch_index: int, batch_count: int) -> None:
    retryable = sum(1 for x in missing if x.get("retryable"))
    data = {
        "version": 1,
        "source": "GBIF (excluding iNaturalist-derived records)",
        "batch": {"index": batch_index, "count": batch_count},
        "catalog_species_considered": len(rows),
        "images_collected": len(images),
        "species_with_eligible_image": len(images),
        "species_unavailable_usable_image": len(missing) - retryable,
        "retryable_errors": retryable,
        "species_missing_usable_image": len(missing),
        "images": images,
        "missing": missing,
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def collect(catalog_path: Path, output_dir: Path, report_path: Path, batch_index: int, batch_count: int, delay: float, resume: bool) -> None:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    rows = _species_rows(catalog, batch_index, batch_count)
    old_images, old_missing = _load_report(report_path) if resume else ({}, {})
    images: list[dict[str, Any]] = []
    missing: list[dict[str, Any]] = []

    for index, (species_id, scientific_name) in enumerate(rows, 1):
        previous = old_images.get(species_id)
        if previous and Path(str(previous.get("asset_path") or "")).is_file():
            images.append(previous)
            print(f"[{index}/{len(rows)}] {scientific_name}: resumed_collected", flush=True)
            continue
        prior_missing = old_missing.get(species_id)
        if prior_missing and not prior_missing.get("retryable", False):
            missing.append(prior_missing)
            print(f"[{index}/{len(rows)}] {scientific_name}: resumed_unavailable", flush=True)
            continue

        canonical = _canonical_name(scientific_name)
        try:
            usage = _resolve(scientific_name)
            if not usage:
                missing.append({"species_id": species_id, "scientific_name": scientific_name, "search_name": canonical, "status": "no_gbif_species_match", "retryable": False, "strategy_version": STRATEGY_VERSION})
                status = "no_gbif_species_match"
            else:
                found = _candidate(str(usage["key"]))
                if not found:
                    missing.append({"species_id": species_id, "scientific_name": scientific_name, "search_name": canonical, "matched_taxon_key": usage["key"], "matched_taxon_name": usage.get("name"), "status": "no_eligible_non_inaturalist_gbif_image", "retryable": False, "strategy_version": STRATEGY_VERSION})
                    status = "no_eligible_non_inaturalist_gbif_image"
                else:
                    occurrence, media, lic = found
                    output = output_dir / f"species_{species_id}" / "1.jpg"
                    width, height = _sanitize(_get_bytes(str(media["identifier"])), output)
                    record = {
                        "species_id": species_id,
                        "scientific_name": scientific_name,
                        "search_name": canonical,
                        "matched_taxon_key": usage["key"],
                        "matched_taxon_name": usage.get("name"),
                        "source": "GBIF",
                        "source_occurrence_id": occurrence.get("key"),
                        "source_occurrence_url": f"https://www.gbif.org/occurrence/{occurrence.get('key')}",
                        "source_photo_url": media.get("identifier"),
                        "creator_attribution": media.get("creator") or media.get("rightsHolder") or occurrence.get("recordedBy") or "",
                        "license": lic[0],
                        "license_url": lic[1],
                        "publisher_dataset": occurrence.get("datasetTitle") or "",
                        "retrieved_at": datetime.now(timezone.utc).date().isoformat(),
                        "review_status": "needs_human_review",
                        "asset_path": str(output).replace("\\", "/"),
                        "pixel_width": width,
                        "pixel_height": height,
                    }
                    images.append(record)
                    status = "collected_gbif_image"
        except Exception as exc:
            retryable = isinstance(exc, (urllib.error.URLError, TimeoutError, socket.timeout)) or (isinstance(exc, urllib.error.HTTPError) and (exc.code == 429 or exc.code >= 500)) or isinstance(exc, (UnidentifiedImageError, OSError))
            missing.append({"species_id": species_id, "scientific_name": scientific_name, "search_name": canonical, "status": "transient_error" if retryable else "error", "retryable": retryable, "error_type": type(exc).__name__, "strategy_version": STRATEGY_VERSION})
            status = "transient_error" if retryable else "error"

        print(f"[{index}/{len(rows)}] {scientific_name} -> {canonical}: {status}", flush=True)
        _write(report_path, rows, images, missing, batch_index, batch_count)
        if delay and index < len(rows):
            time.sleep(delay)

    _write(report_path, rows, images, missing, batch_index, batch_count)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--catalog", default="assets/data/species_catalog.json")
    p.add_argument("--output-dir", default="build/gbif-reference-images")
    p.add_argument("--report", default="build/gbif-reference-report.json")
    p.add_argument("--batch-index", type=int, default=0)
    p.add_argument("--batch-count", type=int, default=1)
    p.add_argument("--delay", type=float, default=0.6)
    p.add_argument("--resume", action="store_true")
    a = p.parse_args()
    collect(Path(a.catalog), Path(a.output_dir), Path(a.report), a.batch_index, a.batch_count, a.delay, a.resume)


if __name__ == "__main__":
    main()
