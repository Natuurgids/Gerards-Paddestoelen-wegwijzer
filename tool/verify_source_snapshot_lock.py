#!/usr/bin/env python3
"""Fail release builds when live source enrichment drifts from the reviewed snapshot."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def _count_species_with_source(species: list[dict], source_id: str) -> int:
    return sum(1 for item in species if item.get("source_id") == source_id)


def _count_localized_names(species: list[dict], locale: str, source_id: str) -> int:
    count = 0
    for item in species:
        texts = item.get("texts") or {}
        localized = texts.get(locale) or {}
        if localized.get("common_name_source_id") == source_id:
            count += 1
    return count


def _count_conservation(species: list[dict], source_id: str) -> int:
    return sum(1 for item in species if item.get("conservation_source_id") == source_id)


def _source_license_mismatches(catalog: dict, lock: dict) -> dict[str, dict[str, str | None]]:
    source_by_id = {
        str(item.get("id")): item
        for item in catalog.get("sources") or []
        if item.get("id") is not None
    }
    expected_licenses = lock.get("required_source_licenses") or {}
    mismatches: dict[str, dict[str, str | None]] = {}
    for source_id, expected_license in expected_licenses.items():
        source = source_by_id.get(source_id)
        actual_license = None if source is None else source.get("license")
        if actual_license != expected_license:
            mismatches[source_id] = {
                "expected": expected_license,
                "actual": actual_license,
            }
    return mismatches


def _identity_manifest(species: list[dict]) -> dict[str, list[dict]]:
    """Stable source identities used to make future drift an exact diff."""
    nsr = sorted(
        (
            {
                "id": item.get("id"),
                "taxon_id": item.get("taxon_id"),
                "source_record_id": item.get("source_record_id"),
            }
            for item in species
            if item.get("source_id") == "nsr-dutch-species-register"
        ),
        key=lambda item: (
            str(item.get("source_record_id") or ""),
            str(item.get("taxon_id") or ""),
            str(item.get("id") or ""),
        ),
    )
    dgfm = sorted(
        (
            {
                "id": item.get("id"),
                "taxon_id": item.get("taxon_id"),
                "de_name": ((item.get("texts") or {}).get("de") or {}).get("common_name"),
            }
            for item in species
            if ((item.get("texts") or {}).get("de") or {}).get("common_name_source_id")
            == "dgfm-german-fungi"
        ),
        key=lambda item: (
            str(item.get("taxon_id") or ""),
            str(item.get("id") or ""),
            str(item.get("de_name") or ""),
        ),
    )
    return {"nsr_species": nsr, "dgfm_german_names": dgfm}


def _manifest_diff(current: dict[str, list[dict]], reviewed: dict[str, list[dict]]) -> dict[str, dict[str, list[dict]]]:
    """Exact additions/removals when a reviewed identity manifest is available."""
    out: dict[str, dict[str, list[dict]]] = {}
    for category in ("nsr_species", "dgfm_german_names"):
        def key(item: dict) -> str:
            if category == "nsr_species":
                return str(item.get("source_record_id") or item.get("taxon_id") or item.get("id"))
            return str(item.get("taxon_id") or item.get("id"))
        now = {key(item): item for item in current.get(category, [])}
        old = {key(item): item for item in reviewed.get(category, [])}
        out[category] = {
            "added": [now[k] for k in sorted(now.keys() - old.keys())],
            "removed": [old[k] for k in sorted(old.keys() - now.keys())],
            "changed": [
                {"reviewed": old[k], "current": now[k]}
                for k in sorted(now.keys() & old.keys())
                if now[k] != old[k]
            ],
        }
    return out


def _drift_records(species: list[dict], lock: dict) -> dict[str, list[dict]]:
    """Return inspectable records for sources whose reviewed counts drifted."""
    expected = lock["catalogue"]
    nsr = [
        {
            "id": item.get("id"),
            "taxon_id": item.get("taxon_id"),
            "source_record_id": item.get("source_record_id"),
            "nl_name": ((item.get("texts") or {}).get("nl") or {}).get("common_name"),
        }
        for item in species
        if item.get("source_id") == "nsr-dutch-species-register"
    ]
    dgfm = [
        {
            "id": item.get("id"),
            "taxon_id": item.get("taxon_id"),
            "de_name": ((item.get("texts") or {}).get("de") or {}).get("common_name"),
        }
        for item in species
        if ((item.get("texts") or {}).get("de") or {}).get("common_name_source_id")
        == "dgfm-german-fungi"
    ]
    return {
        "nsr_species": nsr if len(nsr) != expected.get("nsr_species") else [],
        "dgfm_german_names": dgfm if len(dgfm) != expected.get("dgfm_german_names") else [],
    }


def write_identity_manifest(catalog_path: Path, manifest_path: Path) -> None:
    if require_identity_manifest and (
        identity_manifest_path is None or not identity_manifest_path.exists()
    ):
        raise ValueError(
            "Reviewed source identity manifest is required; create it only when "
            "accepting a source snapshot deliberately."
        )
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(
        json.dumps(_identity_manifest(list(catalog.get("species") or [])), ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def verify(
    catalog_path: Path,
    lock_path: Path,
    report_path: Path | None = None,
    identity_manifest_path: Path | None = None,
    require_identity_manifest: bool = False,
) -> None:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    lock = json.loads(lock_path.read_text(encoding="utf-8"))
    species = list(catalog.get("species") or [])
    expected = lock["catalogue"]

    actual = {
        "total_species": len(species),
        "nsr_species": _count_species_with_source(species, "nsr-dutch-species-register"),
        "dgfm_german_names": _count_localized_names(species, "de", "dgfm-german-fungi"),
        "uksi_english_names": _count_localized_names(
            species, "en", "uksi-natural-history-museum"
        ),
        "iucn_statuses": _count_conservation(species, "iucn-red-list"),
    }

    source_ids = {str(item.get("id")) for item in catalog.get("sources") or []}
    missing_sources = sorted(set(lock.get("required_sources") or []) - source_ids)
    license_mismatches = _source_license_mismatches(catalog, lock)
    count_mismatches = {
        key: {"expected": expected[key], "actual": value}
        for key, value in actual.items()
        if value != expected.get(key)
    }
    if missing_sources or license_mismatches or count_mismatches:
        if report_path is not None:
            report_path.parent.mkdir(parents=True, exist_ok=True)
            report_path.write_text(
                json.dumps(
                    {
                        "expected": expected,
                        "actual": actual,
                        "count_mismatches": count_mismatches,
                        "records": _drift_records(species, lock),
                        "identity_diff": (
                            _manifest_diff(
                                _identity_manifest(species),
                                json.loads(identity_manifest_path.read_text(encoding="utf-8")),
                            )
                            if identity_manifest_path is not None and identity_manifest_path.exists()
                            else None
                        ),
                    },
                    ensure_ascii=False,
                    indent=2,
                    sort_keys=True,
                ) + "\n",
                encoding="utf-8",
            )
        details = []
        if missing_sources:
            details.append(f"missing sources: {', '.join(missing_sources)}")
        if license_mismatches:
            details.append(
                "license drift: " + json.dumps(license_mismatches, sort_keys=True)
            )
        if count_mismatches:
            details.append(
                f"count drift: {json.dumps(count_mismatches, sort_keys=True)}"
            )
        raise ValueError(
            "Source snapshot drift detected; review upstream changes and update "
            f"{lock_path} deliberately. " + "; ".join(details)
        )

    print(
        "Source snapshot lock verified: "
        + ", ".join(f"{key}={value}" for key, value in actual.items())
        + f", licenses={len(lock.get('required_source_licenses') or {})}"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", default="assets/data/species_catalog.json")
    parser.add_argument("--lock", default="tool/source_snapshot_lock.json")
    parser.add_argument("--report")
    parser.add_argument(
        "--require-identity-manifest",
        action="store_true",
        help="Fail if the reviewed identity manifest is absent.",
    )
    parser.add_argument(
        "--identity-manifest",
        help="Reviewed identity manifest used to report exact additions/removals/changes.",
    )
    parser.add_argument(
        "--write-identity-manifest",
        help="Write stable NSR/DGfM identities for a deliberately reviewed snapshot.",
    )
    args = parser.parse_args()
    if args.write_identity_manifest:
        write_identity_manifest(Path(args.catalog), Path(args.write_identity_manifest))
        return
    verify(
        Path(args.catalog),
        Path(args.lock),
        Path(args.report) if args.report else None,
        Path(args.identity_manifest) if args.identity_manifest else None,
        args.require_identity_manifest,
    )


if __name__ == "__main__":
    main()
