#!/usr/bin/env python3
"""Enrich the generated species catalogue with sourced IUCN conservation status.

The source is the IUCN Red List Darwin Core Archive published through GBIF under
CC BY 4.0. Matching is exact by scientific name. This imports conservation status
only; it does not infer legal protection, edibility, toxicity, morphology or media.
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import tempfile
import urllib.request
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

DEFAULT_URL = "https://hosted-datasets.gbif.org/datasets/iucn/iucn-latest.zip"
SOURCE_ID = "iucn-red-list"
SOURCE_URL = "https://www.gbif.org/dataset/19491596-35ae-4a91-9a98-85cf505f1bd3"
SOURCE_TITLE = "The IUCN Red List of Threatened Species"
SOURCE_CITATION = (
    "IUCN (2026). The IUCN Red List of Threatened Species. Version 2026-1. "
    "doi:10.15468/0qnb58"
)
STATUS_FIELDS = (
    "threatStatus",
    "iucnRedListCategory",
    "redListCategory",
    "category",
)


def _local(term: str) -> str:
    return term.rsplit("/", 1)[-1].rsplit("#", 1)[-1]


def _char(value: str | None, default: str) -> str:
    if not value:
        return default
    return bytes(value, "utf-8").decode("unicode_escape")


def _spec(element):
    location = next((c.text for c in element.iter() if c.tag.endswith("location")), None)
    if not location:
        raise ValueError("Darwin Core table has no location")
    fields = {}
    id_index = None
    for child in element:
        if child.tag.endswith("field"):
            fields[int(child.attrib["index"])] = _local(child.attrib.get("term", ""))
        elif child.tag.endswith("id") or child.tag.endswith("coreid"):
            id_index = int(child.attrib["index"])
    return (
        location,
        _char(element.attrib.get("fieldsTerminatedBy"), "\t"),
        _char(element.attrib.get("fieldsEnclosedBy"), '"'),
        int(element.attrib.get("ignoreHeaderLines", "0")),
        fields,
        id_index,
    )


def _rows(zf, spec):
    location, delimiter, quote, skip, fields, id_index = spec
    reader = csv.reader(
        io.StringIO(zf.read(location).decode("utf-8-sig", errors="replace")),
        delimiter=delimiter,
        quotechar=quote or None,
    )
    for _ in range(skip):
        next(reader, None)
    for values in reader:
        row = {
            name: values[index].strip() if index < len(values) else ""
            for index, name in fields.items()
        }
        if id_index is not None and id_index < len(values):
            row["_id"] = values[id_index].strip()
        yield row


def _download(url: str) -> Path:
    temp = tempfile.NamedTemporaryFile(suffix=".zip", delete=False)
    temp.close()
    request = urllib.request.Request(
        url, headers={"User-Agent": "Gerards-Paddestoelen-Wegwijzer/1.0"}
    )
    with urllib.request.urlopen(request, timeout=180) as response, open(temp.name, "wb") as out:
        out.write(response.read())
    return Path(temp.name)


def _status(row: dict[str, str]) -> str:
    for field in STATUS_FIELDS:
        value = row.get(field, "").strip()
        if value:
            return value
    return ""


def _statuses(archive: Path) -> dict[str, str]:
    with zipfile.ZipFile(archive) as zf:
        meta = next((name for name in zf.namelist() if name.lower().endswith("meta.xml")), None)
        if not meta:
            raise ValueError("Darwin Core archive missing meta.xml")
        root = ET.fromstring(zf.read(meta))
        core = next((e for e in root if e.tag.endswith("core")), None)
        if core is None:
            raise ValueError("Darwin Core archive missing taxon core")

        core_rows = list(_rows(zf, _spec(core)))
        scientific_by_id: dict[str, str] = {}
        result: dict[str, str] = {}
        for row in core_rows:
            scientific = row.get("scientificName", "").strip()
            taxon_id = row.get("_id", "").strip() or row.get("taxonID", "").strip()
            if scientific and taxon_id:
                scientific_by_id[taxon_id] = scientific
            status = _status(row)
            if scientific and status:
                result[scientific.casefold()] = status

        # Current IUCN archives may expose conservation terms in an extension rather
        # than on the taxon core. Resolve extension coreid values back to the core
        # scientific name and retain only explicit status terms.
        for extension in (e for e in root if e.tag.endswith("extension")):
            spec = _spec(extension)
            field_names = set(spec[4].values())
            if not any(field in field_names for field in STATUS_FIELDS):
                continue
            for row in _rows(zf, spec):
                status = _status(row)
                if not status:
                    continue
                scientific = row.get("scientificName", "").strip()
                if not scientific:
                    scientific = scientific_by_id.get(row.get("_id", "").strip(), "")
                if scientific:
                    result[scientific.casefold()] = status

        if not result:
            available = sorted(
                {
                    field
                    for table in root
                    if table.tag.endswith("core") or table.tag.endswith("extension")
                    for field in _spec(table)[4].values()
                    if "status" in field.casefold()
                    or "category" in field.casefold()
                    or "iucn" in field.casefold()
                }
            )
            raise ValueError(
                "IUCN archive contains no recognized conservation status values; "
                f"candidate fields={available}"
            )
        print(f"IUCN archive explicit statuses={len(result)}")
        return result


def enrich(catalog_path: Path, archive: Path, retrieved_at: str) -> int:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    taxon_names = {
        int(t["id"]): str(t["scientific_name"]).strip()
        for t in catalog.get("taxa", [])
        if t.get("rank") == "species"
    }
    lookup = _statuses(archive)
    changed = 0
    for species in catalog.get("species", []):
        scientific = taxon_names.get(int(species["taxon_id"]))
        if not scientific:
            continue
        status = lookup.get(scientific.casefold())
        if not status:
            continue
        species["conservation_status"] = status
        species["conservation_scope"] = "global"
        species["conservation_source_id"] = SOURCE_ID
        changed += 1

    sources = [s for s in catalog.get("sources", []) if s.get("id") != SOURCE_ID]
    sources.append(
        {
            "id": SOURCE_ID,
            "title": SOURCE_TITLE,
            "version": "2026-1",
            "url": SOURCE_URL,
            "license": "CC BY 4.0",
            "citation": SOURCE_CITATION,
            "retrieved_at": retrieved_at,
        }
    )
    catalog["sources"] = sources
    catalog_path.write_text(
        json.dumps(catalog, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(f"IUCN conservation enrichment: matched={changed}")
    return changed


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="assets/data/species_catalog.json")
    parser.add_argument("--archive")
    parser.add_argument("--source-url", default=DEFAULT_URL)
    parser.add_argument("--retrieved-at", default="2026-09-04")
    parser.add_argument("--min-matches", type=int, default=1)
    args = parser.parse_args()
    downloaded = None
    try:
        archive = Path(args.archive) if args.archive else _download(args.source_url)
        if not args.archive:
            downloaded = archive
        count = enrich(Path(args.catalog), archive, args.retrieved_at)
        if count < args.min_matches:
            raise ValueError(f"IUCN conservation coverage unexpectedly low: {count}")
    finally:
        if downloaded is not None:
            downloaded.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
