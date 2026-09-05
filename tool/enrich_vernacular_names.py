#!/usr/bin/env python3
"""Enrich generated species catalogue names from licensed checklists.

Matches only exact scientific names. Existing non-scientific localized names always
win. This deliberately imports vernacular names only, never descriptive biology.
German names are read from GBIF's indexed DGfM checklist. English names are read
from the NBN Atlas species API backed by the UK Species Inventory.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import urllib.parse
import urllib.request
from pathlib import Path

SOURCES = {
    "de": {
        "id": "dgfm-german-fungi",
        "title": "Taxon list of fungi and fungal-like organisms from Germany compiled by the DGfM",
        "dataset_key": "155b33d2-84b1-4a31-9287-9d9e900bc6c8",
        "source_url": "https://www.gbif.org/dataset/155b33d2-84b1-4a31-9287-9d9e900bc6c8",
        "license": "CC BY 4.0",
        "citation": "Dämmrich F. Taxon list of fungi and fungal-like organisms from Germany compiled by the DGfM. Staatliche Naturwissenschaftliche Sammlungen Bayerns. doi:10.15468/gtvmjw",
        "languages": {"de", "deu", "ger", "german", "de-de"},
    },
    "en": {
        "id": "uksi-natural-history-museum",
        "title": "United Kingdom Species Inventory (UKSI)",
        "source_url": "https://www.gbif.org/dataset/dbaa27eb-29e7-4cbb-8eab-3f689cfce116",
        "license": "CC BY 4.0",
        "citation": "Raper C. United Kingdom Species Inventory (UKSI). Natural History Museum. doi:10.15468/rm6pm4",
    },
}

_CACHE_DIR: Path | None = None


def _cache_path(url: str) -> Path | None:
    if _CACHE_DIR is None:
        return None
    digest = hashlib.sha256(url.encode("utf-8")).hexdigest()
    return _CACHE_DIR / f"{digest}.json"


def _request_json(url: str) -> dict:
    cache_path = _cache_path(url)
    if cache_path is not None and cache_path.exists():
        return json.loads(cache_path.read_text(encoding="utf-8"))

    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Gerards-Paddestoelen-Wegwijzer/1.0",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        payload = json.load(response)

    if cache_path is not None:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        temporary = cache_path.with_suffix(".tmp")
        temporary.write_text(
            json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n",
            encoding="utf-8",
        )
        temporary.replace(cache_path)
    return payload


def _gbif_page(dataset_key: str, offset: int, limit: int) -> dict:
    query = urllib.parse.urlencode(
        {
            "datasetKey": dataset_key,
            "origin": "SOURCE",
            "limit": limit,
            "offset": offset,
        }
    )
    return _request_json(f"https://api.gbif.org/v1/species/search?{query}")


def _gbif_is_target(row: dict) -> bool:
    kingdom = str(row.get("kingdom") or "").strip().casefold()
    rank = str(row.get("rank") or "").strip().upper()
    status = str(row.get("taxonomicStatus") or row.get("status") or "").strip().upper()
    return kingdom == "fungi" and rank == "SPECIES" and status == "ACCEPTED"


def _collect_gbif_names(payload: dict, result: dict[str, str]) -> None:
    for row in payload.get("results", []):
        if not _gbif_is_target(row):
            continue
        scientific = str(row.get("scientificName") or "").strip()
        if not scientific:
            continue
        for item in row.get("vernacularNames") or []:
            language = str(item.get("language") or "").strip().casefold()
            name = str(item.get("vernacularName") or "").strip()
            if name and language in SOURCES["de"]["languages"]:
                result.setdefault(scientific.casefold(), name)
                break


def _german_names() -> dict[str, str]:
    dataset_key = SOURCES["de"]["dataset_key"]
    limit = 1000
    first = _gbif_page(dataset_key, 0, limit)
    result: dict[str, str] = {}
    _collect_gbif_names(first, result)
    count = int(first.get("count") or len(first.get("results", [])))
    if count > 75_000:
        raise ValueError(f"DGfM GBIF source checklist unexpectedly large: {count}")
    offsets = list(range(limit, count, limit))
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        futures = [executor.submit(_gbif_page, dataset_key, offset, limit) for offset in offsets]
        for future in concurrent.futures.as_completed(futures):
            _collect_gbif_names(future.result(), result)
    print(f"DGfM via GBIF: usages={count}; German fungal names={len(result)}")
    return result


def _nbn_page(start: int, page_size: int) -> dict:
    params = [
        ("q", "*:*") ,
        ("fq", "idxtype:TAXON"),
        ("fq", 'taxonomicStatus:"accepted"'),
        ("fq", 'rank:"species"'),
        ("fq", "rk_kingdom:Fungi"),
        ("pageSize", str(page_size)),
        ("start", str(start)),
    ]
    query = urllib.parse.urlencode(params)
    return _request_json(f"https://species-ws.nbnatlas.org/search?{query}")


def _nbn_results(payload: dict) -> tuple[list[dict], int]:
    search = payload.get("searchResults") or payload
    rows = search.get("results") or []
    total = (
        search.get("totalRecords")
        or search.get("totalResults")
        or payload.get("totalRecords")
        or len(rows)
    )
    return list(rows), int(total)


def _collect_nbn_names(rows: list[dict], result: dict[str, str]) -> None:
    for row in rows:
        scientific = str(
            row.get("scientificName") or row.get("name") or ""
        ).strip()
        common = str(
            row.get("commonName") or row.get("preferredCommonName") or ""
        ).strip()
        if scientific and common:
            result.setdefault(scientific.casefold(), common)


def _english_names() -> dict[str, str]:
    page_size = 1000
    first_payload = _nbn_page(0, page_size)
    first_rows, total = _nbn_results(first_payload)
    if total > 50_000:
        raise ValueError(f"NBN accepted Fungi species query unexpectedly large: {total}")
    result: dict[str, str] = {}
    _collect_nbn_names(first_rows, result)
    starts = list(range(page_size, total, page_size))
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
        futures = [executor.submit(_nbn_page, start, page_size) for start in starts]
        for future in concurrent.futures.as_completed(futures):
            rows, _ = _nbn_results(future.result())
            _collect_nbn_names(rows, result)
    print(f"UKSI via NBN Atlas: accepted Fungi species={total}; English names={len(result)}")
    return result


def enrich(catalog_path: Path, retrieved_at: str) -> dict[str, int]:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    taxon_names = {
        int(t["id"]): str(t["scientific_name"]).strip()
        for t in catalog.get("taxa", [])
        if t.get("rank") == "species"
    }
    lookups = {"de": _german_names(), "en": _english_names()}
    counts = {}
    sources = list(catalog.get("sources", []))
    for locale, lookup in lookups.items():
        config = SOURCES[locale]
        changed = 0
        for species in catalog.get("species", []):
            scientific = taxon_names.get(int(species["taxon_id"]))
            if not scientific:
                continue
            candidate = lookup.get(scientific.casefold())
            if not candidate:
                continue
            texts = species.setdefault("texts", {})
            localized = texts.setdefault(locale, {})
            current = str(localized.get("common_name", "")).strip()
            if current and current.casefold() != scientific.casefold():
                continue
            localized["common_name"] = candidate
            localized["common_name_source_id"] = config["id"]
            changed += 1
        counts[locale] = changed
        sources = [s for s in sources if s.get("id") != config["id"]]
        sources.append(
            {
                "id": config["id"],
                "title": config["title"],
                "version": "current",
                "url": config["source_url"],
                "license": config["license"],
                "citation": config["citation"],
                "retrieved_at": retrieved_at,
            }
        )
    catalog["sources"] = sources
    catalog_path.write_text(
        json.dumps(catalog, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print("Vernacular enrichment: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    return counts


def main():
    global _CACHE_DIR
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="assets/data/species_catalog.json")
    parser.add_argument("--retrieved-at", default="2026-09-04")
    parser.add_argument("--min-de", type=int, default=100)
    parser.add_argument("--min-en", type=int, default=100)
    parser.add_argument("--cache-dir")
    args = parser.parse_args()
    _CACHE_DIR = Path(args.cache_dir) if args.cache_dir else None
    counts = enrich(Path(args.catalog), args.retrieved_at)
    if counts.get("de", 0) < args.min_de or counts.get("en", 0) < args.min_en:
        raise ValueError(f"Vernacular coverage unexpectedly low: {counts}")


if __name__ == "__main__":
    main()
