#!/usr/bin/env python3
"""Fill missing English and German offline ecology text from FungalTraits.

Uses the same pinned CC BY 4.0 genus-level FungalTraits snapshot as
``enrich_ecology.py``. Existing curated text always wins. Generated wording is
explicitly genus-level and therefore does not invent species-specific claims.
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import urllib.request
from datetime import datetime, timezone
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

EN_LIFESTYLE = {
    "ectomycorrhizal": "ectomycorrhizal",
    "arbuscular_mycorrhizal": "arbuscular mycorrhizal",
    "ericoid_mycorrhizal": "ericoid mycorrhizal",
    "orchid_mycorrhizal": "orchid mycorrhizal",
    "litter_saprotroph": "a litter saprotroph",
    "soil_saprotroph": "a soil saprotroph",
    "wood_saprotroph": "a wood saprotroph",
    "plant_pathogen": "a plant pathogen",
    "animal_pathogen": "an animal pathogen",
    "lichenized": "lichenized",
    "epiphyte": "epiphytic",
    "endophyte": "endophytic",
    "foliar_endophyte": "a foliar endophyte",
    "root_endophyte": "a root endophyte",
    "fungal_parasite": "a parasite of other fungi",
}
DE_LIFESTYLE = {
    "ectomycorrhizal": "ektomykorrhizal",
    "arbuscular_mycorrhizal": "arbuskulär-mykorrhizal",
    "ericoid_mycorrhizal": "ericoid-mykorrhizal",
    "orchid_mycorrhizal": "Orchideen-Mykorrhizapilz",
    "litter_saprotroph": "saprotroph auf Streu",
    "soil_saprotroph": "saprotroph im oder auf dem Boden",
    "wood_saprotroph": "saprotroph auf Holz",
    "plant_pathogen": "pflanzenpathogen",
    "animal_pathogen": "tierpathogen",
    "lichenized": "lichenisiert",
    "epiphyte": "epiphytisch",
    "endophyte": "endophytisch",
    "foliar_endophyte": "Blattendophyt",
    "root_endophyte": "Wurzelendophyt",
    "fungal_parasite": "parasitisch auf anderen Pilzen",
}
EN_SUBSTRATE = {"leaf/fruit/seed": "leaves, fruit or seeds", "wood": "wood", "soil": "soil", "litter": "litter", "dung": "dung"}
DE_SUBSTRATE = {"leaf/fruit/seed": "Blättern, Früchten oder Samen", "wood": "Holz", "soil": "Boden", "litter": "Streu", "dung": "Dung"}


def _download(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "Gerards-Paddestoelen-Wegwijzer/1.0"})
    with urllib.request.urlopen(req, timeout=120) as response:
        return response.read().decode("utf-8-sig", errors="replace")


def _clean(value) -> str:
    return str(value or "").strip()


def _key(value: str) -> str:
    return value.strip().casefold().replace(" ", "_")


def _traits(text: str) -> dict[str, dict[str, str]]:
    result = {}
    for row in csv.DictReader(io.StringIO(text)):
        genus = _clean(row.get("GENUS"))
        if genus:
            result[genus.casefold()] = {str(k): _clean(v) for k, v in row.items() if k}
    return result


def _parts(row: dict[str, str], locale: str) -> list[str]:
    life = EN_LIFESTYLE if locale == "en" else DE_LIFESTYLE
    substrate_map = EN_SUBSTRATE if locale == "en" else DE_SUBSTRATE
    primary = _clean(row.get("primary_lifestyle"))
    secondary = _clean(row.get("Secondary_lifestyle"))
    substrate = _clean(row.get("Decay_substrate_template"))
    parts = []
    if primary:
        parts.append(life.get(_key(primary), primary.replace("_", " ")))
    if secondary and secondary.casefold() != primary.casefold():
        translated = life.get(_key(secondary), secondary.replace("_", " "))
        parts.append(("sometimes " if locale == "en" else "teils ") + translated)
    if substrate:
        translated = substrate_map.get(_key(substrate), substrate.replace("_", " "))
        parts.append(("associated with " if locale == "en" else "mit ") + translated)
    return parts


def _texts(genus: str, row: dict[str, str], locale: str) -> tuple[str, str] | None:
    parts = _parts(row, locale)
    if not parts:
        return None
    joined = "; ".join(parts)
    if locale == "en":
        summary = f"Genus-level ecology for {genus}: {joined}."
        habitat = f"FungalTraits reports the genus {genus} as {joined}. This is genus-level context; species-specific habitat can differ."
    else:
        summary = f"Ökologie auf Gattungsebene für {genus}: {joined}."
        habitat = f"FungalTraits beschreibt die Gattung {genus} als {joined}. Dies ist Kontext auf Gattungsebene; der artspezifische Lebensraum kann abweichen."
    return summary, habitat


def enrich(catalog_path: Path, source_text: str, retrieved_at: str, min_added: int) -> dict[str, int]:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    traits = _traits(source_text)
    taxa = {int(t["id"]): t for t in catalog.get("taxa") or []}
    sources = [s for s in catalog.get("sources") or [] if s.get("id") != SOURCE_ID]
    sources.append({"id": SOURCE_ID, "title": "FungalTraits genus ecology (GloBI reproducible snapshot)", "version": "edac5137e67e2a30b0ae18881248bcd14cf78f0a", "url": SOURCE_PAGE, "license": "CC BY 4.0", "citation": SOURCE_CITATION, "retrieved_at": retrieved_at})
    catalog["sources"] = sources
    counts = {"en_summary": 0, "en_habitat": 0, "de_summary": 0, "de_habitat": 0}
    for species in catalog.get("species") or []:
        taxon = taxa.get(int(species.get("taxon_id", -1)))
        scientific = _clean(None if taxon is None else taxon.get("scientific_name"))
        if not scientific:
            continue
        genus = scientific.split()[0]
        row = traits.get(genus.casefold())
        if row is None:
            continue
        for locale in ("en", "de"):
            generated = _texts(genus, row, locale)
            if generated is None:
                continue
            localized = species.setdefault("texts", {}).setdefault(locale, {})
            for field, value in zip(("summary", "habitat"), generated):
                if _clean(localized.get(field)):
                    continue
                localized[field] = value
                localized[f"{field}_source_id"] = SOURCE_ID
                localized[f"{field}_basis"] = "genus"
                counts[f"{locale}_{field}"] += 1
    total = sum(counts.values())
    if total < min_added:
        raise ValueError(f"Localized ecology enrichment unexpectedly low: {total} < {min_added}")
    catalog["version"] = max(int(catalog.get("version", 1)), 5)
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print("Localized ecology enrichment: " + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())))
    return counts


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="assets/data/species_catalog.json")
    parser.add_argument("--source-url", default=SOURCE_URL)
    parser.add_argument("--source-file")
    parser.add_argument("--retrieved-at", default=datetime.now(timezone.utc).date().isoformat())
    parser.add_argument("--min-added", type=int, default=100)
    args = parser.parse_args()
    source = Path(args.source_file).read_text(encoding="utf-8-sig") if args.source_file else _download(args.source_url)
    enrich(Path(args.catalog), source, args.retrieved_at, args.min_added)


if __name__ == "__main__":
    main()
