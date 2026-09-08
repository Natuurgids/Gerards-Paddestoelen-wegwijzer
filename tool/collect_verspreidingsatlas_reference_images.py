#!/usr/bin/env python3
"""Collect explicitly redistributable Verspreidingsatlas reference photos.

The species queue is joined against Verspreidingsatlas' official paddenstoelen taxon
webservice. Species pages are then inspected for photo blocks. A photo is downloaded
only when the individual photo context explicitly states CC0 or CC BY. Generic
"Creative Commons", copyright-marked, CC BY-SA/NC/ND, or unknown-rights media are
never bundled and are retained only as audit records.

This collector intentionally does not copy maps, phenology graphics or other page
artwork. It stores no observation/location metadata in the offline image pack.
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
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from bs4 import BeautifulSoup, Tag
from PIL import Image, UnidentifiedImageError

USER_AGENT = "Gerards-Paddestoelen-Wegwijzer/1.0 Verspreidingsatlas-image-curation"
SEARCH_STRATEGY_VERSION = 2
ALLOWED_LICENSES = {"CC0", "CC BY"}
MAX_IMAGE_PIXELS = 600
JPEG_QUALITY = 80


def _get_bytes(url: str, timeout: int = 60) -> tuple[bytes, str]:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/xhtml+xml,image/avif,image/webp,image/*,*/*;q=0.8",
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read(), str(response.headers.get("Content-Type") or "")


def _normal(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip()).casefold()


def _canonical_species_name(scientific_name: str) -> str:
    cleaned = re.sub(r"\s+", " ", scientific_name.strip())
    parts = cleaned.split(" ")
    if len(parts) < 2:
        return cleaned
    return f"{parts[0]} {parts[1]}"


def _catalog_rows(catalog: dict[str, Any]) -> list[tuple[int, str]]:
    taxa = {
        int(t["id"]): str(t["scientific_name"]).strip()
        for t in catalog.get("taxa", [])
        if t.get("rank") == "species" and t.get("scientific_name")
    }
    rows: list[tuple[int, str]] = []
    for species in catalog.get("species", []):
        species_id = int(species["id"])
        scientific_name = taxa.get(int(species["taxon_id"]))
        if scientific_name:
            rows.append((species_id, scientific_name))
    rows.sort(key=lambda item: item[0])
    return rows


def _local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1].casefold()


def _extract_page_url(values: list[str]) -> str | None:
    for value in values:
        match = re.search(r"https?://(?:www\.)?verspreidingsatlas\.nl/(\d{4,8})(?:\b|/|\?|$)", value, re.I)
        if match:
            return f"https://www.verspreidingsatlas.nl/{match.group(1)}"
    return None


def _extract_code(values: list[str]) -> str | None:
    page_url = _extract_page_url(values)
    if page_url:
        return page_url.rsplit("/", 1)[-1]
    for value in values:
        if re.fullmatch(r"0*\d{4,8}", value.strip()):
            return value.strip()
    return None


def _taxa_index(xml_path: Path) -> dict[str, dict[str, str]]:
    root = ET.parse(xml_path).getroot()
    records: list[dict[str, str]] = []
    for elem in root.iter():
        children = list(elem)
        if not children:
            continue
        fields: dict[str, str] = {}
        values: list[str] = []
        for child in children:
            text = " ".join(part.strip() for part in child.itertext() if part.strip()).strip()
            if not text:
                continue
            fields[_local_name(child.tag)] = text
            values.append(text)
        sci = ""
        for key, value in fields.items():
            if key in {"scientificname", "scientific_name", "wetenschappelijkenaam", "scientific"}:
                sci = value
                break
        if not sci:
            continue
        page_url = _extract_page_url(values)
        code = _extract_code(values)
        if not page_url and code:
            page_url = f"https://www.verspreidingsatlas.nl/{code}"
        if not page_url:
            continue
        records.append({"scientific_name": sci, "page_url": page_url, "code": code or ""})

    exact: dict[str, dict[str, str]] = {}
    binomial_candidates: dict[str, list[dict[str, str]]] = {}
    for record in records:
        exact[_normal(record["scientific_name"])] = record
        key = _normal(_canonical_species_name(record["scientific_name"]))
        binomial_candidates.setdefault(key, []).append(record)

    index = dict(exact)
    for key, candidates in binomial_candidates.items():
        if key not in index and len(candidates) == 1:
            index[key] = candidates[0]
    return index


def _match_taxon(index: dict[str, dict[str, str]], scientific_name: str) -> dict[str, str] | None:
    exact = index.get(_normal(scientific_name))
    if exact:
        return exact
    return index.get(_normal(_canonical_species_name(scientific_name)))


def _absolute_url(base: str, value: str) -> str:
    return urllib.parse.urljoin(base, value)


def _looks_like_photo_url(url: str) -> bool:
    lowered = url.casefold()
    blocked = (
        "map_", "/maps/", "kaart", "phenolog", "fenolog", "logo", "icon", "sprite",
        "spacer", "favicon", "calendar", "marker", "legend", "grafiek", "chart",
    )
    return bool(url) and not any(token in lowered for token in blocked)


def _license_from_text(text: str) -> str | None:
    normalized = re.sub(r"\s+", " ", text).upper()
    if re.search(r"\bCC\s*0\b", normalized):
        return "CC0"
    if re.search(r"\bCC\s*BY\b", normalized) and not re.search(
        r"\bCC\s*BY(?:\s*|-)(?:SA|NC|ND)\b", normalized
    ):
        return "CC BY"
    return None


def _contains_rights_marker(text: str) -> bool:
    """Return whether text visibly carries copyright or Creative Commons rights."""
    return "©" in text or bool(re.search(r"\bCC(?:\s*0|\s+BY|\b)", text, re.I))


def _photo_imgs(context: Tag, page_url: str) -> list[Tag]:
    photos: list[Tag] = []
    for candidate in context.find_all("img"):
        if not isinstance(candidate, Tag):
            continue
        src = str(candidate.get("src") or "").strip()
        if src and _looks_like_photo_url(_absolute_url(page_url, src)):
            photos.append(candidate)
    return photos


def _is_image_specific_context(context: Tag) -> bool:
    """Return whether markup explicitly identifies this block as image-specific."""
    if context.name == "figure":
        return True
    markers: list[str] = []
    element_id = context.get("id")
    if element_id:
        markers.append(str(element_id))
    classes = context.get("class") or []
    if isinstance(classes, str):
        markers.append(classes)
    else:
        markers.extend(str(value) for value in classes)
    marker_text = " ".join(markers)
    return bool(re.search(r"(?:^|[-_\s])(photo|foto|image|afbeelding|media)(?:[-_\s]|$)", marker_text, re.I))


def _individual_photo_context(img: Tag, page_url: str) -> Tag | None:
    """Return the smallest demonstrably image-specific rights context.

    A candidate must contain exactly this one photo-like image, contain explicit
    rights text, and be structurally marked as an image/photo block. Broad page,
    section, gallery, or content wrappers are therefore never used to borrow a
    licence from neighbouring or generic page text.
    """
    node: Tag | None = img
    for _ in range(5):
        parent = node.parent if isinstance(node, Tag) else None
        if not isinstance(parent, Tag) or parent.name in {"body", "html"}:
            break
        photos = _photo_imgs(parent, page_url)
        if len(photos) > 1:
            break
        if len(photos) == 1 and photos[0] is img and _is_image_specific_context(parent):
            text = parent.get_text(" ", strip=True)
            if _contains_rights_marker(text):
                return parent
        node = parent
    return None


def _photo_candidate(page_url: str, html: bytes) -> tuple[str, dict[str, str] | None, dict[str, str] | None]:
    soup = BeautifulSoup(html, "html.parser")
    page_text = soup.get_text(" ", strip=True)
    if re.search(r"Geen foto beschikbaar", page_text, re.I):
        return "no_photo_available", None, None

    incompatible: dict[str, str] | None = None
    saw_photo = False
    for img in soup.find_all("img"):
        if not isinstance(img, Tag):
            continue
        src = str(img.get("src") or "").strip()
        if not src:
            continue
        img_url = _absolute_url(page_url, src)
        if not _looks_like_photo_url(img_url):
            continue
        saw_photo = True

        context = _individual_photo_context(img, page_url)
        if context is None:
            continue
        evidence_text = context.get_text(" ", strip=True)
        licence = _license_from_text(evidence_text)

        if licence:
            source_url = img_url
            link = img.find_parent("a")
            if isinstance(link, Tag) and (link is context or link in context.descendants):
                href = str(link.get("href") or "").strip()
                if href:
                    linked = _absolute_url(page_url, href)
                    if _looks_like_photo_url(linked):
                        source_url = linked
            return (
                "eligible_photo",
                {
                    "source_photo_url": source_url,
                    "license": licence,
                    "creator_attribution": evidence_text[:500],
                    "license_evidence_text": evidence_text[:1000],
                    "license_evidence_html": str(context)[:4000],
                },
                incompatible,
            )

        if incompatible is None and _contains_rights_marker(evidence_text):
            incompatible = {
                "source_photo_url": img_url,
                "observed_rights": evidence_text[:500] or "unknown",
                "license_evidence_html": str(context)[:4000],
            }

    if incompatible:
        return "photo_available_but_incompatible_or_unknown_license", None, incompatible
    if saw_photo and re.search(r"\bCC\s*(?:0|BY)\b", page_text, re.I):
        return "eligible_license_visible_but_not_bound_to_individual_photo", None, None
    return "no_usable_photo_detected", None, None


def _sanitize_jpeg(raw: bytes, output: Path) -> tuple[int, int]:
    with Image.open(io.BytesIO(raw)) as image:
        image.load()
        image = image.convert("RGB")
        image.thumbnail((MAX_IMAGE_PIXELS, MAX_IMAGE_PIXELS), Image.Resampling.LANCZOS)
        width, height = image.size
        output.parent.mkdir(parents=True, exist_ok=True)
        image.save(output, format="JPEG", quality=JPEG_QUALITY, optimize=True, progressive=True)
        return width, height


def _load_resume(report_path: Path) -> tuple[dict[int, dict[str, Any]], dict[int, dict[str, Any]]]:
    if not report_path.exists():
        return {}, {}
    payload = json.loads(report_path.read_text(encoding="utf-8"))
    images = {int(item["species_id"]): item for item in payload.get("images", [])}
    missing = {int(item["species_id"]): item for item in payload.get("missing", [])}
    return images, missing


def _error_record(species_id: int, scientific_name: str, exc: Exception) -> dict[str, Any]:
    base = {
        "species_id": species_id,
        "scientific_name": scientific_name,
        "source": "NDFF Verspreidingsatlas",
        "strategy_version": SEARCH_STRATEGY_VERSION,
    }
    if isinstance(exc, urllib.error.HTTPError):
        retryable = exc.code == 429 or 500 <= exc.code <= 599
        return {**base, "status": "transient_http_error" if retryable else "http_error", "retryable": retryable, "http_status": exc.code}
    if isinstance(exc, (urllib.error.URLError, TimeoutError, socket.timeout)):
        return {**base, "status": "transient_request_error", "retryable": True, "error_type": type(exc).__name__}
    if isinstance(exc, (UnidentifiedImageError, OSError)):
        return {**base, "status": "image_decode_or_write_error", "retryable": True, "error_type": type(exc).__name__}
    return {**base, "status": "unexpected_error", "retryable": True, "error_type": type(exc).__name__}


def _write_report(
    report_path: Path,
    rows: list[tuple[int, str]],
    images: dict[int, dict[str, Any]],
    missing: dict[int, dict[str, Any]],
    batch_index: int,
    batch_count: int,
) -> None:
    statuses: dict[str, int] = {}
    for item in missing.values():
        status = str(item.get("status") or "unknown")
        statuses[status] = statuses.get(status, 0) + 1
    payload = {
        "version": 2,
        "source": "NDFF Verspreidingsatlas",
        "batch": {"index": batch_index, "count": batch_count},
        "catalog_species_considered": len(rows),
        "species_with_offline_image": len(images),
        "species_missing_usable_image": len(missing),
        "retryable_errors": sum(1 for item in missing.values() if item.get("retryable")),
        "allowed_image_licenses": sorted(ALLOWED_LICENSES),
        "status_counts": statuses,
        "policy": {
            "taxon_queue_source": "https://www.verspreidingsatlas.nl/taxa/paddenstoelen",
            "individual_photo_license_required": True,
            "license_must_be_bound_to_single_photo_context": True,
            "allowed_photo_licenses": ["CC0", "CC BY"],
            "copyright_or_generic_cc_photos_bundled": False,
            "maps_and_page_artwork_bundled": False,
            "location_metadata_stored": False,
            "max_image_pixels": MAX_IMAGE_PIXELS,
            "jpeg_quality": JPEG_QUALITY,
        },
        "images": [images[key] for key in sorted(images)],
        "missing": [missing[key] for key in sorted(missing)],
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", required=True)
    parser.add_argument("--taxa", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--batch-index", type=int, required=True)
    parser.add_argument("--batch-count", type=int, required=True)
    parser.add_argument("--delay", type=float, default=2.0)
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()

    catalog = json.loads(Path(args.catalog).read_text(encoding="utf-8"))
    index = _taxa_index(Path(args.taxa))
    all_rows = _catalog_rows(catalog)
    rows = [row for position, row in enumerate(all_rows) if position % args.batch_count == args.batch_index]

    output_dir = Path(args.output_dir)
    report_path = Path(args.report)
    images, missing = _load_resume(report_path) if args.resume else ({}, {})

    for species_id, scientific_name in rows:
        local_path = output_dir / f"species_{species_id}" / "1.jpg"
        previous_image = images.get(species_id)
        if previous_image and local_path.is_file() and previous_image.get("license") in ALLOWED_LICENSES:
            continue
        previous_missing = missing.get(species_id)
        if previous_missing and not previous_missing.get("retryable"):
            continue

        try:
            taxon = _match_taxon(index, scientific_name)
            if taxon is None:
                missing[species_id] = {
                    "species_id": species_id,
                    "scientific_name": scientific_name,
                    "source": "NDFF Verspreidingsatlas",
                    "status": "not_in_verspreidingsatlas_taxon_service",
                    "retryable": False,
                    "strategy_version": SEARCH_STRATEGY_VERSION,
                }
                continue

            page_url = taxon["page_url"]
            page_html, _ = _get_bytes(page_url, timeout=45)
            status, candidate, incompatible = _photo_candidate(page_url, page_html)
            if candidate is None:
                record = {
                    "species_id": species_id,
                    "scientific_name": scientific_name,
                    "source": "NDFF Verspreidingsatlas",
                    "source_taxon_code": taxon.get("code"),
                    "source_species_url": page_url,
                    "status": status,
                    "retryable": status == "eligible_license_visible_but_not_bound_to_individual_photo",
                    "strategy_version": SEARCH_STRATEGY_VERSION,
                }
                if incompatible:
                    record.update(incompatible)
                missing[species_id] = record
                images.pop(species_id, None)
            else:
                raw, content_type = _get_bytes(candidate["source_photo_url"], timeout=60)
                if content_type and not content_type.casefold().startswith("image/"):
                    raise UnidentifiedImageError(f"unexpected content type: {content_type}")
                width, height = _sanitize_jpeg(raw, local_path)
                images[species_id] = {
                    "species_id": species_id,
                    "scientific_name": scientific_name,
                    "search_name": _canonical_species_name(scientific_name),
                    "source": "NDFF Verspreidingsatlas",
                    "source_taxon_code": taxon.get("code"),
                    "source_species_url": page_url,
                    "source_observation_url": page_url,
                    "source_photo_url": candidate["source_photo_url"],
                    "creator_attribution": candidate["creator_attribution"],
                    "license": candidate["license"],
                    "license_evidence_text": candidate["license_evidence_text"],
                    "license_evidence_html": candidate["license_evidence_html"],
                    "retrieved_at": datetime.now(timezone.utc).date().isoformat(),
                    "strategy_version": SEARCH_STRATEGY_VERSION,
                    "asset_path": f"images/species_{species_id}/1.jpg",
                    "width": width,
                    "height": height,
                    "review_status": "needs_human_review",
                    "intended_role": "primary_reference",
                }
                missing.pop(species_id, None)
        except Exception as exc:  # keep sharded runs resumable
            missing[species_id] = _error_record(species_id, scientific_name, exc)
            images.pop(species_id, None)
        finally:
            _write_report(report_path, rows, images, missing, args.batch_index, args.batch_count)
            time.sleep(max(0.0, args.delay))

    _write_report(report_path, rows, images, missing, args.batch_index, args.batch_count)
    print(json.dumps({
        "batch": args.batch_index,
        "considered": len(rows),
        "images": len(images),
        "missing": len(missing),
        "retryable_errors": sum(1 for item in missing.values() if item.get("retryable")),
    }), flush=True)


if __name__ == "__main__":
    main()
