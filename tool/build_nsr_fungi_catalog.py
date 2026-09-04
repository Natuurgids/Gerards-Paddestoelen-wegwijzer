#!/usr/bin/env python3
"""Merge accepted Dutch Species Register Fungi species into species_catalog.json.

The source is the Naturalis Dutch Species Register Darwin Core Archive. Curated app
records always win by scientific name; generated records contain catalogue facts
only and deliberately leave biology/safety fields unknown.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import tempfile
import urllib.request
import xml.etree.ElementTree as ET
import zipfile
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_URL = "https://api.biodiversitydata.nl/v2/taxon/dwca/getDataSet/nsr"
SOURCE_ID = "nsr-dutch-species-register"
SOURCE_URL = "https://www.gbif.org/dataset/4dd32523-a3a3-43b7-84df-4cda02f15cf7"
SOURCE_CITATION = (
    "Creuwels J, Pieterse S (2026). Checklist Dutch Species Register - "
    "Nederlands Soortenregister. Naturalis Biodiversity Center. "
    "https://doi.org/10.15468/rjdpzy"
)


def _local(term: str) -> str:
    return term.rsplit("/", 1)[-1].rsplit("#", 1)[-1]


def _char(value: str | None, default: str) -> str:
    if not value:
        return default
    return bytes(value, "utf-8").decode("unicode_escape")


def _table_spec(element: ET.Element) -> tuple[str, str, str, int, dict[int, str], int | None]:
    location = next((c.text for c in element.iter() if c.tag.endswith("location")), None)
    if not location:
        raise ValueError("Darwin Core table has no location")
    delimiter = _char(element.attrib.get("fieldsTerminatedBy"), "\t")
    quote = _char(element.attrib.get("fieldsEnclosedBy"), '"')
    skip = int(element.attrib.get("ignoreHeaderLines", "0"))
    fields: dict[int, str] = {}
    id_index: int | None = None
    for child in element:
        if child.tag.endswith("field"):
            fields[int(child.attrib["index"])] = _local(child.attrib.get("term", ""))
        elif child.tag.endswith("id") or child.tag.endswith("coreid"):
            id_index = int(child.attrib["index"])
    return location, delimiter, quote, skip, fields, id_index


def _rows(zf: zipfile.ZipFile, spec: tuple[str, str, str, int, dict[int, str], int | None]):
    location, delimiter, quote, skip, fields, id_index = spec
    raw = zf.read(location).decode("utf-8-sig", errors="replace")
    reader = csv.reader(io.StringIO(raw), delimiter=delimiter, quotechar=quote or None)
    for _ in range(skip):
        next(reader, None)
    for values in reader:
        item = {name: values[index].strip() if index < len(values) else "" for index, name in fields.items()}
        if id_index is not None and id_index < len(values):
            item["_id"] = values[id_index].strip()
        yield item


def _stable_id(key: str, used: set[int]) -> int:
    salt = 0
    while True:
        digest = hashlib.sha256(f"{key}:{salt}".encode()).digest()
        value = 100_000_000 + int.from_bytes(digest[:4], "big") % 1_900_000_000
        if value not in used:
            used.add(value)
            return value
        salt += 1


def _download(url: str) -> Path:
    temp = tempfile.NamedTemporaryFile(suffix=".zip", delete=False)
    temp.close()
    request = urllib.request.Request(url, headers={"User-Agent": "Gerards-Paddestoelen-Wegwijzer/1.0"})
    with urllib.request.urlopen(request, timeout=120) as response, open(temp.name, "wb") as output:
        output.write(response.read())
    return Path(temp.name)


def build(archive: Path, catalog_path: Path, retrieved_at: str, min_species: int) -> int:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    existing_names = {
        str(t["scientific_name"]).strip().casefold()
        for t in catalog.get("taxa", [])
        if t.get("rank") == "species"
    }
    used_taxon_ids = {int(t["id"]) for t in catalog.get("taxa", [])}
    used_species_ids = {int(s["id"]) for s in catalog.get("species", [])}
    used_ids = used_taxon_ids | used_species_ids

    with zipfile.ZipFile(archive) as zf:
        meta_name = next((n for n in zf.namelist() if n.lower().endswith("meta.xml")), None)
        if not meta_name:
            raise ValueError("Darwin Core archive is missing meta.xml")
        root = ET.fromstring(zf.read(meta_name))
        core = next((e for e in root if e.tag.endswith("core")), None)
        if core is None:
            raise ValueError("Darwin Core archive is missing a core table")
        core_rows = list(_rows(zf, _table_spec(core)))

        dutch_names: dict[str, tuple[bool, str]] = {}
        for extension in (e for e in root if e.tag.endswith("extension")):
            if not extension.attrib.get("rowType", "").endswith("VernacularName"):
                continue
            for row in _rows(zf, _table_spec(extension)):
                taxon_id = row.get("_id", "")
                language = (row.get("language") or row.get("languageCode") or "").lower()
                name = row.get("vernacularName", "").strip()
                if not taxon_id or not name or not language.startswith("nl"):
                    continue
                preferred = (row.get("isPreferredName") or row.get("preferredName") or "").lower() in {"true", "1", "yes"}
                previous = dutch_names.get(taxon_id)
                if previous is None or (preferred and not previous[0]):
                    dutch_names[taxon_id] = (preferred, name)

    generated = []
    for row in core_rows:
        kingdom = row.get("kingdom", "").strip().casefold()
        rank = row.get("taxonRank", "").strip().casefold()
        status = row.get("taxonomicStatus", "").strip().casefold()
        if kingdom != "fungi" or rank != "species":
            continue
        if status and status not in {"accepted", "valid"}:
            continue
        scientific = row.get("scientificName", "").strip()
        taxon_id = (row.get("taxonID") or row.get("_id") or "").strip()
        if not scientific or not taxon_id or scientific.casefold() in existing_names:
            continue
        generated.append((scientific, taxon_id, row))

    generated.sort(key=lambda item: (item[0].casefold(), item[1]))
    if len(generated) + len(existing_names) < min_species:
        raise ValueError(
            f"NSR Fungi species count is unexpectedly low: {len(generated) + len(existing_names)} < {min_species}"
        )

    sources = [s for s in catalog.get("sources", []) if s.get("id") != SOURCE_ID]
    sources.append({
        "id": SOURCE_ID,
        "title": "Checklist Dutch Species Register - Nederlands Soortenregister",
        "version": "2026",
        "url": SOURCE_URL,
        "license": "CC BY 4.0",
        "citation": SOURCE_CITATION,
        "retrieved_at": retrieved_at,
    })
    catalog["sources"] = sources

    added = 0
    for scientific, taxon_id, row in generated:
        taxon_numeric_id = _stable_id(f"nsr-taxon:{taxon_id}", used_ids)
        species_numeric_id = _stable_id(f"nsr-species:{taxon_id}", used_ids)
        authorship = row.get("scientificNameAuthorship", "").strip() or None
        nl_name = dutch_names.get(taxon_id, (False, scientific))[1]
        catalog["taxa"].append({
            "id": taxon_numeric_id,
            "parent_id": None,
            "rank": "species",
            "scientific_name": scientific,
            "author_citation": authorship,
        })
        catalog["species"].append({
            "id": species_numeric_id,
            "taxon_id": taxon_numeric_id,
            "catalog_only": True,
            "edible_status": "unknown",
            "toxicity_level": "unknown",
            "source_id": SOURCE_ID,
            "source_record_id": taxon_id,
            "texts": {
                "nl": {"common_name": nl_name},
                "en": {"common_name": scientific},
                "de": {"common_name": scientific},
            },
        })
        existing_names.add(scientific.casefold())
        added += 1

    catalog["version"] = max(int(catalog.get("version", 1)), 3)
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    total = len(catalog["species"])
    print(f"NSR merge complete: added {added}; catalogue total {total}")
    if total < min_species:
        raise ValueError(f"Generated catalogue has only {total} species")
    return total


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="assets/data/species_catalog.json")
    parser.add_argument("--archive")
    parser.add_argument("--source-url", default=DEFAULT_URL)
    parser.add_argument("--retrieved-at", default=datetime.now(timezone.utc).date().isoformat())
    parser.add_argument("--min-species", type=int, default=10_000)
    args = parser.parse_args()

    downloaded = None
    try:
        archive = Path(args.archive) if args.archive else _download(args.source_url)
        if not args.archive:
            downloaded = archive
        build(archive, Path(args.catalog), args.retrieved_at, args.min_species)
    finally:
        if downloaded is not None:
            downloaded.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
