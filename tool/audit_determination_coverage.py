#!/usr/bin/env python3
"""Audit catalogue-wide determination coverage without inventing biological data.

The report combines the bundled core and supplemental species-trait mappings, counts
coverage only for species present in the catalogue, and distinguishes legacy/unsourced
relations from provenance-backed relations. It is intended to guide future reviewed
coverage batches; it does not infer or add any traits.
"""

from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path
from typing import Any


def _species_rows(catalog: dict[str, Any]) -> list[tuple[int, str]]:
    taxa = {
        int(taxon["id"]): str(taxon.get("scientific_name") or "").strip()
        for taxon in catalog.get("taxa", [])
    }
    rows: list[tuple[int, str]] = []
    for species in catalog.get("species", []):
        species_id = int(species["id"])
        scientific_name = taxa.get(int(species["taxon_id"]), "")
        rows.append((species_id, scientific_name))
    rows.sort(key=lambda row: row[0])
    return rows


def _relations(payload: dict[str, Any]) -> list[dict[str, Any]]:
    relations = payload.get("species_traits", [])
    if not isinstance(relations, list):
        raise ValueError("species_traits must be a list")
    return [dict(item) for item in relations]


def build_report(
    catalog: dict[str, Any],
    core_traits: dict[str, Any],
    supplemental_traits: dict[str, Any],
) -> dict[str, Any]:
    species_rows = _species_rows(catalog)
    catalog_ids = {species_id for species_id, _ in species_rows}
    relations = _relations(core_traits) + _relations(supplemental_traits)

    by_species: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for relation in relations:
        species_id = int(relation["species_id"])
        if species_id in catalog_ids:
            by_species[species_id].append(relation)

    covered_species: list[dict[str, Any]] = []
    coverage_gaps: list[dict[str, Any]] = []
    total_relations = 0
    provenanced_relations = 0
    species_with_provenance = 0

    for species_id, scientific_name in species_rows:
        species_relations = by_species.get(species_id, [])
        if not species_relations:
            coverage_gaps.append(
                {"species_id": species_id, "scientific_name": scientific_name}
            )
            continue

        total_relations += len(species_relations)
        sourced = sum(
            1
            for relation in species_relations
            if str(relation.get("source_id") or "").strip()
            and str(relation.get("source_record_id") or "").strip()
        )
        provenanced_relations += sourced
        if sourced:
            species_with_provenance += 1
        covered_species.append(
            {
                "species_id": species_id,
                "scientific_name": scientific_name,
                "relation_count": len(species_relations),
                "provenanced_relation_count": sourced,
                "trait_group_count": len(
                    {int(relation["trait_id"]) for relation in species_relations}
                ),
            }
        )

    catalog_species = len(species_rows)
    species_with_any = len(covered_species)
    percent = lambda value: round((100.0 * value / catalog_species), 4) if catalog_species else 0.0

    return {
        "version": 1,
        "catalog_species_considered": catalog_species,
        "trait_groups_available": len(core_traits.get("traits", [])),
        "determination_relations_total": total_relations,
        "provenanced_relations_total": provenanced_relations,
        "species_with_any_determination_traits": species_with_any,
        "species_with_provenanced_determination_traits": species_with_provenance,
        "species_without_determination_traits": catalog_species - species_with_any,
        "species_without_provenanced_determination_traits": catalog_species
        - species_with_provenance,
        "coverage_percent_any": percent(species_with_any),
        "coverage_percent_provenanced": percent(species_with_provenance),
        "covered_species": covered_species,
        "coverage_gaps": coverage_gaps,
        "policy": {
            "unknown_traits_remain_unmapped": True,
            "no_trait_inference_performed": True,
            "provenance_requires_source_id_and_source_record_id": True,
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="assets/data/species_catalog.json")
    parser.add_argument("--core-traits", default="assets/data/identification_traits.json")
    parser.add_argument(
        "--supplemental-traits", default="assets/data/species_traits_europe.json"
    )
    parser.add_argument(
        "--output", default="build/determination-coverage-audit.json"
    )
    args = parser.parse_args()

    report = build_report(
        json.loads(Path(args.catalog).read_text(encoding="utf-8")),
        json.loads(Path(args.core_traits).read_text(encoding="utf-8")),
        json.loads(Path(args.supplemental_traits).read_text(encoding="utf-8")),
    )
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        json.dumps(
            {
                key: report[key]
                for key in (
                    "catalog_species_considered",
                    "species_with_any_determination_traits",
                    "species_with_provenanced_determination_traits",
                    "coverage_percent_any",
                    "coverage_percent_provenanced",
                )
            }
        ),
        flush=True,
    )


if __name__ == "__main__":
    main()
