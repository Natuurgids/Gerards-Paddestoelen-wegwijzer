#!/usr/bin/env python3
"""Enrich generated species catalogue names from licensed GBIF checklists.

Matches only exact scientific names. Existing non-scientific localized names always
win. This deliberately imports vernacular names only, never descriptive biology.
Both sources are read through GBIF's indexed Species API. GBIF performs checklist,
rank and accepted-status filtering; Fungi membership is then verified from each
returned record before any vernacular name is considered.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import urllib.parse
import urllib.request
from pathlib import Path

FUNGI_GBIF_KEY = 5
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
        "dataset_key": "dbaa27eb-29e7-4cbb-8eab-3f689cfce116",
        "source_url": "https://www.gbif.org/dataset/dbaa27eb-29e7-4cbb-8eab-3f689cfce116",
        "license": "CC BY 4.0",
        "citation": "Raper C. United Kingdom Species Inventory (UKSI). Natural History Museum. doi:10.15468/rm6pm4",
        "languages": {"en", "eng", "english", "en-gb"},
    },
}


def _request_json(url: str) -> dict:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Gerards-Paddestoelen-Wegwijzer/1.0",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        return json.load(response)


def _page(dataset_key: str, offset: int, limit: int) -> dict:
    # species/search accepts checklist, rank and taxonomic-status filters. The
    # earlier higher-taxon/origin combination is intentionally avoided here:
    # those fields are not consistently indexed for source checklist usages.
    query = urllib.parse.urlencode(
        {
            "datasetKey": dataset_key,
            "rank": "SPECIES",
            "status": "ACCEPTED",
            "limit": limit,
            "offset": offset,
        }
    )
    return _request_json(f"https://api.gbif.org/v1/species/search?{query}")


def _is_fungus(row: dict) -> bool:
    kingdom = str(row.get("kingdom") or "").strip().casefold()
    kingdom_key = row.get("kingdomKey")
    return kingdom == "fungi" or kingdom_key == FUNGI_GBIF_KEY


def _collect_names(payload: dict, languages: set[str], result: dict[str, str]) -> None:
    for row in payload.get("results", []):
        if not _is_fungus(row):
            continue
        scientific = str(row.get("scientificName") or "").strip()
        if not scientific:
            continue
        for item in row.get("vernacularNames") or []:
            language = str(item.get("language") or "").strip().casefold()
            name = str(item.get("vernacularName") or "").strip()
            if name and language in languages:
                result.setdefault(scientific.casefold(), name)
                break


def _names_from_gbif(dataset_key: str, languages: set[str]) -> dict[str, str]:
    """Enumerate accepted species in one checklist and retain Fungi only."""
    limit = 1000
    first = _page(dataset_key, 0, limit)
    result: dict[str, str] = {}
    _collect_names(first, languages, result)
    count = int(first.get("count") or len(first.get("results", [])))
    if count > 150_000:
        raise ValueError(
            f"Filtered GBIF checklist has {count} accepted species, above safe pagination bound"
        )
    offsets = list(range(limit, count, limit))
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        futures = [executor.submit(_page, dataset_key, offset, limit) for offset in offsets]
        for future in concurrent.futures.as_completed(futures):
            _collect_names(future.result(), languages, result)
    print(
        f"GBIF checklist {dataset_key}: accepted species={count}; "
        f"fungal vernacular species={len(result)}"
    )
    return result


def enrich(catalog_path: Path, retrieved_at: str) -> dict[str, int]:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    taxon_names = {
        int(t["id"]): str(t["scientific_name"]).strip()
        for t in catalog.get("taxa", [])
        if t.get("rank") == "species"
    }
    counts = {}
    sources = list(catalog.get("sources", []))
    for locale, config in SOURCES.items():
        lookup = _names_from_gbif(config["dataset_key"], config["languages"])
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
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="assets/data/species_catalog.json")
    parser.add_argument("--retrieved-at", default="2026-09-04")
    parser.add_argument("--min-de", type=int, default=100)
    parser.add_argument("--min-en", type=int, default=100)
    args = parser.parse_args()
    counts = enrich(Path(args.catalog), args.retrieved_at)
    if counts.get("de", 0) < args.min_de or counts.get("en", 0) < args.min_en:
        raise ValueError(f"Vernacular coverage unexpectedly low: {counts}")


if __name__ == "__main__":
    main()
