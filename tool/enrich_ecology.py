#!/usr/bin/env python3
"""Enrich species habitat and reviewed lookalikes without inventing identity claims.

Habitat enrichment uses the published FungalTraits genus table. Because those
traits are genus-level, generated text says so explicitly and never overwrites
more specific curated habitat text. Lookalikes are only populated from the
separate reviewed mapping file, where every record names its source.
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import urllib.request
from pathlib import Path

SOURCE_ID = "fungaltraits-globi"
SOURCE_URL = (
    "https://raw.githubusercontent.com/globalbioticinteractions/fungaltraits/"
    "edac5137e67e2a30b0ae18881248bcd14cf78f0a/"
    "polme2020-s1-fungal-traits-genera.csv"
)
SOURCE_PAGE = "https://doi.org/10.1007/s13225-020-00466-2"
SOURCE_CITATION = (
    "Põlme S, Abarenkov K, Nilsson RH et al. (2020). FungalTraits: a user-friendly "
    "traits database of fungi and fungus-like stramenopiles. Fungal Diversity 105, 1–16."
)

LIFESTYLE_NL = {
    "ectomycorrhizal": "ectomycorrhizaal",
    "arbuscular_mycorrhizal": "arbusculair mycorrhizaal",
    "ericoid_mycorrhizal": "ericoïd mycorrhizaal",
    "orchid_mycorrhizal": "orchidee-mycorrhizaal",
    "litter_saprotroph": "saprotroof op strooisel",
    "soil_saprotroph": "saprotroof in of op de bodem",
    "wood_saprotroph": "saprotroof op hout",
    "plant_pathogen": "plantpathogeen",
    "animal_pathogen": "dierpathogeen",
    "lichenized": "gelicheniseerd",
    "epiphyte": "epifytisch",
    "endophyte": "endofytisch",
    "foliar_endophyte": "bladendofytisch",
    "root_endophyte": "wortelendofytisch",
    "fungal_parasite": "parasiterend op andere schimmels",
}

SUBSTRATE_NL = {
    "leaf/fruit/seed": "blad, vrucht of zaad",
    "wood": "hout",
    "soil": "bodem",
    "litter": "strooisel",
    "dung": "mest",
}


def _download_text(url: str) -> str:
    request = urllib.request.Request(
        url, headers={"User-Agent": "Gerards-Paddestoelen-Wegwijzer/1.0"}
    )
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read().decode("utf-8-sig", errors="replace")


def _clean(value: str | None) -> str:
    return (value or "").strip()


def _translate_token(value: str, mapping: dict[str, str]) -> str:
    normalized = value.strip().casefold().replace(" ", "_")
    return mapping.get(normalized, value.replace("_", " "))


def _traits_by_genus(source_text: str) -> dict[str, dict[str, str]]:
    rows: dict[str, dict[str, str]] = {}
    for row in csv.DictReader(io.StringIO(source_text)):
        genus = _clean(row.get("GENUS"))
        if genus:
            rows[genus.casefold()] = {str(k): _clean(v) for k, v in row.items() if k}
    return rows


def _habitat_text(genus: str, row: dict[str, str]) -> str | None:
    details: list[str] = []
    primary = _clean(row.get("primary_lifestyle"))
    secondary = _clean(row.get("Secondary_lifestyle"))
    substrate = _clean(row.get("Decay_substrate_template"))
    aquatic = _clean(row.get("Aquatic_habitat_template"))
    hosts = _clean(row.get("Specific_hosts"))

    if primary:
        details.append(_translate_token(primary, LIFESTYLE_NL))
    if secondary and secondary.casefold() != primary.casefold():
        details.append("soms " + _translate_token(secondary, LIFESTYLE_NL))
    if substrate:
        details.append("geassocieerd met " + _translate_token(substrate, SUBSTRATE_NL))
    if hosts:
        details.append("bekende gastheerassociaties: " + hosts)
    if aquatic and aquatic.casefold() not in {"non-aquatic", "non_aquatic"}:
        details.append("aquatische habitat: " + aquatic.replace("_", " "))
    if not details:
        return None
    return (
        f"Ecologische context op genusniveau voor {genus}: "
        + "; ".join(details)
        + ". Controleer soortspecifieke habitatbronnen waar beschikbaar."
    )


def enrich(
    catalog_path: Path,
    source_text: str,
    reviewed_path: Path | None,
    min_habitat: int,
) -> tuple[int, int]:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    traits = _traits_by_genus(source_text)
    taxa = {int(t["id"]): t for t in catalog.get("taxa") or []}

    sources = [s for s in catalog.get("sources") or [] if s.get("id") != SOURCE_ID]
    sources.append(
        {
            "id": SOURCE_ID,
            "title": "FungalTraits genus ecology (GloBI reproducible snapshot)",
            "version": "edac5137e67e2a30b0ae18881248bcd14cf78f0a",
            "url": SOURCE_PAGE,
            "license": "CC BY 4.0",
            "citation": SOURCE_CITATION,
        }
    )
    catalog["sources"] = sources

    habitat_added = 0
    for species in catalog.get("species") or []:
        taxon = taxa.get(int(species.get("taxon_id", -1)))
        scientific = _clean(None if taxon is None else taxon.get("scientific_name"))
        if not scientific:
            continue
        genus = scientific.split()[0]
        trait = traits.get(genus.casefold())
        if trait is None:
            continue
        nl = species.setdefault("texts", {}).setdefault("nl", {})
        if _clean(nl.get("habitat")):
            continue
        habitat = _habitat_text(genus, trait)
        if habitat is None:
            continue
        nl["habitat"] = habitat
        nl["habitat_source_id"] = SOURCE_ID
        nl["habitat_basis"] = "genus"
        habitat_added += 1

    reviewed_added = 0
    if reviewed_path is not None and reviewed_path.exists():
        reviewed = json.loads(reviewed_path.read_text(encoding="utf-8"))
        by_name = {
            _clean(entry.get("scientific_name")).casefold(): entry
            for entry in reviewed.get("species") or []
            if _clean(entry.get("scientific_name"))
        }
        for species in catalog.get("species") or []:
            taxon = taxa.get(int(species.get("taxon_id", -1)))
            scientific = _clean(None if taxon is None else taxon.get("scientific_name"))
            entry = by_name.get(scientific.casefold())
            if entry is None:
                continue
            nl = species.setdefault("texts", {}).setdefault("nl", {})
            habitat = _clean(entry.get("habitat_nl"))
            lookalikes = _clean(entry.get("lookalikes_nl"))
            source_id = _clean(entry.get("source_id"))
            source_record_id = _clean(entry.get("source_record_id"))
            if habitat:
                nl["habitat"] = habitat
                nl["habitat_source_id"] = source_id
                nl["habitat_basis"] = "species"
            if lookalikes and not _clean(nl.get("lookalikes")):
                nl["lookalikes"] = lookalikes
                nl["lookalikes_source_id"] = source_id
                nl["lookalikes_source_record_id"] = source_record_id
                reviewed_added += 1

    if habitat_added < min_habitat:
        raise ValueError(
            f"Ecology enrichment unexpectedly low: {habitat_added} habitat additions < {min_habitat}"
        )

    catalog["version"] = max(int(catalog.get("version", 1)), 4)
    catalog_path.write_text(
        json.dumps(catalog, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8",
    )
    print(
        f"Ecology enrichment complete: habitat added {habitat_added}; "
        f"reviewed lookalikes added {reviewed_added}; trait genera {len(traits)}"
    )
    return habitat_added, reviewed_added


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="assets/data/species_catalog.json")
    parser.add_argument("--source-url", default=SOURCE_URL)
    parser.add_argument("--source-file")
    parser.add_argument(
        "--reviewed", default="assets/data/reviewed_species_ecology.json"
    )
    parser.add_argument("--min-habitat", type=int, default=100)
    args = parser.parse_args()

    source_text = (
        Path(args.source_file).read_text(encoding="utf-8-sig")
        if args.source_file
        else _download_text(args.source_url)
    )
    enrich(
        Path(args.catalog),
        source_text,
        Path(args.reviewed) if args.reviewed else None,
        args.min_habitat,
    )


if __name__ == "__main__":
    main()
