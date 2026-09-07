#!/usr/bin/env python3
"""Collect or audit reviewable iNaturalist reference images in resumable batches.

This tool is for curation, not runtime identification. It normalizes catalogue
scientific names by removing taxonomic authorship before querying iNaturalist,
then prefers research-grade observations and falls back to other verifiable
observations for the same exact normalized taxon. Only redistributable CC0,
CC BY, and CC BY-SA media are accepted.

Collection mode downloads one photo per species and removes source metadata by
re-encoding the pixels. Audit mode records eligible coverage/provenance without
downloading media.

Large catalogue runs can be split deterministically with --batch-index/--batch-count
and resumed with --resume. Retryable request/download failures are distinguished
from genuine unavailable outcomes so temporary source outages are never counted as
confirmed missing coverage. Reports never store observation coordinates or locations.
"""

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

API = "https://api.inaturalist.org/v1/observations"
USER_AGENT = "Gerards-Paddestoelen-Wegwijzer/1.0 reference-image-curation"
SEARCH_STRATEGY_VERSION = 2
ALLOWED_LICENSES = {
    "cc0": "CC0",
    "cc-by": "CC BY",
    "cc-by-sa": "CC BY-SA",
}
LICENSE_URLS = {
    "cc0": "https://creativecommons.org/publicdomain/zero/1.0/",
    "cc-by": "https://creativecommons.org/licenses/by/4.0/",
    "cc-by-sa": "https://creativecommons.org/licenses/by-sa/4.0/",
}
MAX_IMAGE_PIXELS = 600
JPEG_QUALITY = 80


def _get_json(url: str) -> dict[str, Any]:
    request = urllib.request.Request(
        url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"}
    )
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


def _canonical_scientific_name(scientific_name: str) -> str:
    """Return the taxon name without author/year text.

    NSR catalogue names commonly include authorship, while iNaturalist taxon names
    normally do not. Keep genus + species, and retain an infraspecific epithet when
    an explicit rank marker is present.
    """
    cleaned = re.sub(r"\s+", " ", scientific_name.strip())
    parts = cleaned.split(" ")
    if len(parts) < 2:
        return cleaned

    canonical = parts[:2]
    rank_markers = {"subsp.", "ssp.", "var.", "f.", "forma"}
    if len(parts) >= 4 and parts[2].casefold() in rank_markers:
        canonical.extend(parts[2:4])
    return " ".join(canonical)


def _species_rows(
    catalog: dict[str, Any],
    limit: int | None,
    batch_index: int,
    batch_count: int,
) -> list[tuple[int, str]]:
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
    if limit is not None:
        rows = rows[:limit]
    if batch_count < 1:
        raise ValueError("batch_count must be at least 1")
    if batch_index < 0 or batch_index >= batch_count:
        raise ValueError("batch_index must be in the range 0..batch_count-1")
    return [row for position, row in enumerate(rows) if position % batch_count == batch_index]


def _query_candidates(
    canonical_name: str,
    *,
    quality_grade: str | None = None,
    verifiable: bool = False,
) -> list[dict[str, Any]]:
    query: dict[str, str] = {
        "taxon_name": canonical_name,
        "photos": "true",
        "photo_license": "cc0,cc-by,cc-by-sa",
        "per_page": "50",
        "order_by": "votes",
        "order": "desc",
    }
    if quality_grade:
        query["quality_grade"] = quality_grade
    if verifiable:
        query["verifiable"] = "true"
    params = urllib.parse.urlencode(query)
    payload = _get_json(f"{API}?{params}")
    return list(payload.get("results", []))


def _pick_exact_photo(
    results: list[dict[str, Any]], canonical_name: str
) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
    wanted = canonical_name.casefold()
    for observation in results:
        taxon = observation.get("taxon") or {}
        observed_name = _canonical_scientific_name(str(taxon.get("name") or ""))
        if observed_name.casefold() != wanted:
            continue
        for photo in observation.get("photos") or []:
            license_code = str(photo.get("license_code") or "").lower()
            if license_code in ALLOWED_LICENSES and photo.get("url"):
                return observation, photo
    return None, None


def _candidate(
    scientific_name: str,
) -> tuple[str, dict[str, Any] | None, dict[str, Any] | None, str]:
    canonical_name = _canonical_scientific_name(scientific_name)

    research = _query_candidates(canonical_name, quality_grade="research")
    observation, photo = _pick_exact_photo(research, canonical_name)
    if observation is not None and photo is not None:
        return "eligible_research_photo", observation, photo, canonical_name

    verifiable = _query_candidates(canonical_name, verifiable=True)
    observation, photo = _pick_exact_photo(verifiable, canonical_name)
    if observation is not None and photo is not None:
        return "eligible_verifiable_photo", observation, photo, canonical_name

    if research or verifiable:
        return "no_exact_licensed_taxon_photo", None, None, canonical_name
    return "no_verifiable_observations", None, None, canonical_name


def _sanitize_jpeg(raw: bytes, output: Path) -> tuple[int, int]:
    with Image.open(io.BytesIO(raw)) as image:
        image.load()
        image = image.convert("RGB")
        image.thumbnail((MAX_IMAGE_PIXELS, MAX_IMAGE_PIXELS), Image.Resampling.LANCZOS)
        width, height = image.size
        output.parent.mkdir(parents=True, exist_ok=True)
        image.save(
            output,
            format="JPEG",
            quality=JPEG_QUALITY,
            optimize=True,
            progressive=True,
        )
        return width, height


def _load_resume_state(
    report_path: Path,
) -> tuple[dict[int, dict[str, Any]], dict[int, dict[str, Any]]]:
    if not report_path.exists():
        return {}, {}
    payload = json.loads(report_path.read_text(encoding="utf-8"))
    images = {int(item["species_id"]): item for item in payload.get("images", [])}
    unsuccessful = {int(item["species_id"]): item for item in payload.get("missing", [])}
    return images, unsuccessful


def _error_record(
    species_id: int, scientific_name: str, exc: Exception
) -> dict[str, Any]:
    base = {
        "species_id": species_id,
        "scientific_name": scientific_name,
        "search_name": _canonical_scientific_name(scientific_name),
        "strategy_version": SEARCH_STRATEGY_VERSION,
    }
    if isinstance(exc, urllib.error.HTTPError):
        retryable = exc.code == 429 or 500 <= exc.code <= 599
        return {
            **base,
            "status": "transient_http_error" if retryable else "http_error",
            "retryable": retryable,
            "http_status": exc.code,
        }
    if isinstance(exc, (urllib.error.URLError, TimeoutError, socket.timeout)):
        return {
            **base,
            "status": "transient_request_error",
            "retryable": True,
            "error_type": type(exc).__name__,
        }
    if isinstance(exc, (UnidentifiedImageError, OSError)):
        return {
            **base,
            "status": "image_decode_or_write_error",
            "retryable": True,
            "error_type": type(exc).__name__,
        }
    return {
        **base,
        "status": "unexpected_error",
        "retryable": True,
        "error_type": type(exc).__name__,
    }


def _provenance_record(
    species_id: int,
    scientific_name: str,
    canonical_name: str,
    observation: dict[str, Any],
    photo: dict[str, Any],
    match_status: str,
    audit_only: bool,
) -> dict[str, Any]:
    license_code = str(photo["license_code"]).lower()
    photo_id = int(photo["id"])
    observation_id = int(observation["id"])
    observed_taxon = observation.get("taxon") or {}
    return {
        "species_id": species_id,
        "scientific_name": scientific_name,
        "search_name": canonical_name,
        "matched_taxon_name": str(observed_taxon.get("name") or canonical_name),
        "match_status": match_status,
        "observation_quality_grade": str(observation.get("quality_grade") or ""),
        "strategy_version": SEARCH_STRATEGY_VERSION,
        "source": "iNaturalist",
        "source_observation_id": observation_id,
        "source_observation_url": f"https://www.inaturalist.org/observations/{observation_id}",
        "source_photo_id": photo_id,
        "source_photo_url": f"https://www.inaturalist.org/photos/{photo_id}",
        "creator_attribution": str(photo.get("attribution") or "").strip(),
        "license": ALLOWED_LICENSES[license_code],
        "license_code": license_code,
        "license_url": LICENSE_URLS[license_code],
        "retrieved_at": datetime.now(timezone.utc).date().isoformat(),
        "review_status": "needs_human_review",
        "intended_role": "primary_reference",
        "audit_only": audit_only,
        "alt_text": {
            "nl": f"Referentiefoto van {scientific_name} voor vergelijking van zichtbare kenmerken.",
            "en": f"Reference photo of {scientific_name} for comparing visible characteristics.",
            "de": f"Referenzfoto von {scientific_name} zum Vergleich sichtbarer Merkmale.",
        },
    }


def _report(
    species_rows: list[tuple[int, str]],
    collected: list[dict[str, Any]],
    missing: list[dict[str, Any]],
    batch_index: int,
    batch_count: int,
    audit_only: bool,
) -> dict[str, Any]:
    retryable_errors = sum(1 for item in missing if item.get("retryable"))
    unavailable = len(missing) - retryable_errors
    status_counts: dict[str, int] = {}
    for item in collected:
        status = str(item.get("match_status") or ("eligible_photo" if item.get("audit_only") else "collected"))
        status_counts[status] = status_counts.get(status, 0) + 1
    for item in missing:
        status = str(item.get("status") or "unknown")
        status_counts[status] = status_counts.get(status, 0) + 1
    return {
        "version": 4,
        "source": "iNaturalist",
        "mode": "audit" if audit_only else "collect",
        "batch": {"index": batch_index, "count": batch_count},
        "policy": {
            "search_strategy_version": SEARCH_STRATEGY_VERSION,
            "preferred_quality_grade": "research",
            "fallback": "verifiable exact normalized taxon",
            "allowed_photo_licenses": ["cc0", "cc-by", "cc-by-sa"],
            "catalog_authorship_removed_for_search": True,
            "exact_normalized_scientific_name_match": True,
            "max_image_pixels": MAX_IMAGE_PIXELS,
            "jpeg_quality": JPEG_QUALITY,
            "location_metadata_stored": False,
            "source_metadata_stripped_from_jpeg": not audit_only,
            "media_downloaded": not audit_only,
            "human_review_required_before_commit": True,
            "identification_note": (
                "Reference imagery supports educational comparison only; it does not "
                "verify a user's observation or imply edibility/safety."
            ),
        },
        "catalog_species_considered": len(species_rows),
        "images_collected": 0 if audit_only else len(collected),
        "species_with_eligible_image": len(collected),
        "species_unavailable_usable_image": unavailable,
        "retryable_errors": retryable_errors,
        "species_missing_usable_image": len(missing),
        "status_counts": status_counts,
        "images": collected,
        "missing": missing,
    }


def _write_report(report_path: Path, report: dict[str, Any]) -> None:
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def collect(
    catalog_path: Path,
    output_dir: Path,
    report_path: Path,
    limit: int | None,
    delay: float,
    batch_index: int = 0,
    batch_count: int = 1,
    resume: bool = False,
    audit_only: bool = False,
) -> dict[str, Any]:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    species_rows = _species_rows(catalog, limit, batch_index, batch_count)
    selected_ids = {species_id for species_id, _ in species_rows}

    previous_images, previous_missing = (
        _load_resume_state(report_path) if resume else ({}, {})
    )
    collected: list[dict[str, Any]] = []
    missing: list[dict[str, Any]] = []

    for index, (species_id, scientific_name) in enumerate(species_rows, start=1):
        previous_image = previous_images.get(species_id)
        if previous_image:
            if audit_only and previous_image.get("source_photo_id"):
                resumed_record = dict(previous_image)
                resumed_record["audit_only"] = True
                resumed_record.pop("asset_path", None)
                resumed_record.pop("pixel_width", None)
                resumed_record.pop("pixel_height", None)
                collected.append(resumed_record)
                print(
                    f"[{index}/{len(species_rows)}] {scientific_name}: resumed_eligible",
                    flush=True,
                )
                continue
            previous_asset_path = str(previous_image.get("asset_path") or "").strip()
            if (
                not previous_image.get("audit_only", False)
                and previous_asset_path
                and Path(previous_asset_path).is_file()
            ):
                collected.append(previous_image)
                print(
                    f"[{index}/{len(species_rows)}] {scientific_name}: resumed_collected",
                    flush=True,
                )
                continue

        previous_failure = previous_missing.get(species_id)
        if (
            previous_failure
            and not previous_failure.get("retryable", False)
            and int(previous_failure.get("strategy_version") or 0) == SEARCH_STRATEGY_VERSION
        ):
            missing.append(previous_failure)
            print(
                f"[{index}/{len(species_rows)}] {scientific_name}: resumed_unavailable",
                flush=True,
            )
            continue

        try:
            status, observation, photo, canonical_name = _candidate(scientific_name)
            if not status.startswith("eligible_") or observation is None or photo is None:
                missing.append(
                    {
                        "species_id": species_id,
                        "scientific_name": scientific_name,
                        "search_name": canonical_name,
                        "strategy_version": SEARCH_STRATEGY_VERSION,
                        "status": status,
                        "retryable": False,
                    }
                )
                result_status = status
            else:
                record = _provenance_record(
                    species_id,
                    scientific_name,
                    canonical_name,
                    observation,
                    photo,
                    status,
                    audit_only,
                )
                if audit_only:
                    collected.append(record)
                    result_status = status
                else:
                    image_url = _large_url(photo)
                    output = output_dir / f"species_{species_id}" / "1.jpg"
                    width, height = _sanitize_jpeg(_get_bytes(image_url), output)
                    record.update(
                        {
                            "asset_path": str(output).replace("\\", "/"),
                            "pixel_width": width,
                            "pixel_height": height,
                        }
                    )
                    collected.append(record)
                    result_status = f"collected_{status.removeprefix('eligible_')}"
        except Exception as exc:
            failure = _error_record(species_id, scientific_name, exc)
            missing.append(failure)
            result_status = str(failure["status"])

        print(
            f"[{index}/{len(species_rows)}] {scientific_name}: {result_status}",
            flush=True,
        )
        _write_report(
            report_path,
            _report(
                species_rows,
                collected,
                missing,
                batch_index,
                batch_count,
                audit_only,
            ),
        )
        if delay > 0 and index < len(species_rows):
            time.sleep(delay)

    collected = [
        item for item in collected if int(item["species_id"]) in selected_ids
    ]
    missing = [item for item in missing if int(item["species_id"]) in selected_ids]
    report = _report(
        species_rows, collected, missing, batch_index, batch_count, audit_only
    )
    _write_report(report_path, report)
    print(
        json.dumps(
            {
                key: report[key]
                for key in (
                    "catalog_species_considered",
                    "species_with_eligible_image",
                    "species_unavailable_usable_image",
                    "retryable_errors",
                )
            }
        ),
        flush=True,
    )
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="assets/data/species_catalog.json")
    parser.add_argument("--output-dir", default="build/inaturalist-reference-images")
    parser.add_argument("--report", default="build/inaturalist-reference-report.json")
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument(
        "--delay", type=float, default=0.35, help="Polite delay between species API requests"
    )
    parser.add_argument(
        "--batch-index", type=int, default=0, help="Zero-based deterministic batch index"
    )
    parser.add_argument(
        "--batch-count", type=int, default=1, help="Number of deterministic batches"
    )
    parser.add_argument(
        "--resume",
        action="store_true",
        help="Reuse completed records from the existing report/output; old-strategy misses are retried",
    )
    parser.add_argument(
        "--audit-only",
        action="store_true",
        help="Measure eligible coverage/provenance without downloading image bytes",
    )
    args = parser.parse_args()
    collect(
        Path(args.catalog),
        Path(args.output_dir),
        Path(args.report),
        args.limit,
        args.delay,
        args.batch_index,
        args.batch_count,
        args.resume,
        args.audit_only,
    )


if __name__ == "__main__":
    main()
