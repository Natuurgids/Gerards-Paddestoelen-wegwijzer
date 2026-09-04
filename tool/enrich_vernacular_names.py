#!/usr/bin/env python3
"""Enrich generated species catalogue names from licensed DwC-A checklists.

Matches only exact scientific names. Existing non-scientific localized names always
win. This deliberately imports vernacular names only, never descriptive biology.
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

SOURCES = {
    "de": {
        "id": "dgfm-german-fungi",
        "title": "Taxon list of fungi and fungal-like organisms from Germany compiled by the DGfM",
        "url": "http://services.snsb.info/DTNtaxonlists/rest/v0.1/lists/DiversityTaxonNames_Fungi/1140/dwc",
        "source_url": "https://www.gbif.org/dataset/155b33d2-84b1-4a31-9287-9d9e900bc6c8",
        "license": "CC BY 4.0",
        "citation": "Dämmrich F. Taxon list of fungi and fungal-like organisms from Germany compiled by the DGfM. Staatliche Naturwissenschaftliche Sammlungen Bayerns. doi:10.15468/gtvmjw",
        "languages": {"de", "deu", "ger", "german", "de-de"},
    },
    "en": {
        "id": "uksi-natural-history-museum",
        "title": "United Kingdom Species Inventory (UKSI)",
        "url": "https://registry.nbnatlas.org/UKSI/UKSI_DwCA.zip",
        "source_url": "https://www.gbif.org/dataset/dbaa27eb-29e7-4cbb-8eab-3f689cfce116",
        "license": "CC BY 4.0",
        "citation": "Raper C. United Kingdom Species Inventory (UKSI). Natural History Museum. doi:10.15468/rm6pm4",
        "languages": {"en", "eng", "english", "en-gb"},
    },
}


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
    return (location, _char(element.attrib.get("fieldsTerminatedBy"), "\t"),
            _char(element.attrib.get("fieldsEnclosedBy"), '"'),
            int(element.attrib.get("ignoreHeaderLines", "0")), fields, id_index)


def _rows(zf, spec):
    location, delimiter, quote, skip, fields, id_index = spec
    reader = csv.reader(io.StringIO(zf.read(location).decode("utf-8-sig", errors="replace")),
                        delimiter=delimiter, quotechar=quote or None)
    for _ in range(skip):
        next(reader, None)
    for values in reader:
        row = {name: values[i].strip() if i < len(values) else "" for i, name in fields.items()}
        if id_index is not None and id_index < len(values):
            row["_id"] = values[id_index].strip()
        yield row


def _download(url: str) -> Path:
    temp = tempfile.NamedTemporaryFile(suffix=".zip", delete=False)
    temp.close()
    request = urllib.request.Request(url, headers={"User-Agent": "Gerards-Paddestoelen-Wegwijzer/1.0"})
    with urllib.request.urlopen(request, timeout=180) as response, open(temp.name, "wb") as out:
        out.write(response.read())
    return Path(temp.name)


def _names(archive: Path, languages: set[str]) -> dict[str, str]:
    with zipfile.ZipFile(archive) as zf:
        meta = next((n for n in zf.namelist() if n.lower().endswith("meta.xml")), None)
        if not meta:
            raise ValueError("Darwin Core archive missing meta.xml")
        root = ET.fromstring(zf.read(meta))
        core = next(e for e in root if e.tag.endswith("core"))
        core_rows = list(_rows(zf, _spec(core)))
        scientific_by_id = {}
        for row in core_rows:
            taxon_id = (row.get("taxonID") or row.get("_id") or "").strip()
            scientific = row.get("scientificName", "").strip()
            if taxon_id and scientific:
                scientific_by_id[taxon_id] = scientific
        result: dict[str, tuple[bool, str]] = {}
        for extension in (e for e in root if e.tag.endswith("extension")):
            if not extension.attrib.get("rowType", "").endswith("VernacularName"):
                continue
            for row in _rows(zf, _spec(extension)):
                taxon_id = row.get("_id", "")
                scientific = scientific_by_id.get(taxon_id)
                language = (row.get("language") or row.get("languageCode") or "").strip().casefold()
                name = row.get("vernacularName", "").strip()
                if not scientific or not name or language not in languages:
                    continue
                preferred = (row.get("isPreferredName") or row.get("preferredName") or "").casefold() in {"true", "1", "yes"}
                key = scientific.casefold()
                old = result.get(key)
                if old is None or (preferred and not old[0]):
                    result[key] = (preferred, name)
        return {key: value for key, (_, value) in result.items()}


def enrich(catalog_path: Path, archives: dict[str, Path], retrieved_at: str) -> dict[str, int]:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    taxon_names = {int(t["id"]): str(t["scientific_name"]).strip() for t in catalog.get("taxa", []) if t.get("rank") == "species"}
    counts = {}
    sources = list(catalog.get("sources", []))
    for locale, archive in archives.items():
        config = SOURCES[locale]
        lookup = _names(archive, config["languages"])
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
        sources.append({"id": config["id"], "title": config["title"], "version": "current",
                        "url": config["source_url"], "license": config["license"],
                        "citation": config["citation"], "retrieved_at": retrieved_at})
    catalog["sources"] = sources
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print("Vernacular enrichment: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    return counts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="assets/data/species_catalog.json")
    parser.add_argument("--de-archive")
    parser.add_argument("--en-archive")
    parser.add_argument("--retrieved-at", default="2026-09-04")
    parser.add_argument("--min-de", type=int, default=100)
    parser.add_argument("--min-en", type=int, default=100)
    args = parser.parse_args()
    downloaded = []
    try:
        archives = {}
        for locale, supplied in (("de", args.de_archive), ("en", args.en_archive)):
            if supplied:
                archives[locale] = Path(supplied)
            else:
                archives[locale] = _download(SOURCES[locale]["url"])
                downloaded.append(archives[locale])
        counts = enrich(Path(args.catalog), archives, args.retrieved_at)
        if counts.get("de", 0) < args.min_de or counts.get("en", 0) < args.min_en:
            raise ValueError(f"Vernacular coverage unexpectedly low: {counts}")
    finally:
        for path in downloaded:
            path.unlink(missing_ok=True)

if __name__ == "__main__":
    main()
