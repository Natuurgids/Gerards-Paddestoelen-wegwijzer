#!/usr/bin/env python3
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tool.verify_source_snapshot_lock import _drift_records, _source_license_mismatches, verify


class SourceLicenseLockTest(unittest.TestCase):
    def test_matching_reviewed_license_passes(self):
        catalog = {
            "sources": [
                {"id": "source-a", "license": "CC BY 4.0"},
            ]
        }
        lock = {
            "required_source_licenses": {
                "source-a": "CC BY 4.0",
            }
        }

        self.assertEqual(_source_license_mismatches(catalog, lock), {})

    def test_noncommercial_license_is_detected_as_drift(self):
        catalog = {
            "sources": [
                {"id": "source-a", "license": "CC BY-NC 4.0"},
            ]
        }
        lock = {
            "required_source_licenses": {
                "source-a": "CC BY 4.0",
            }
        }

        self.assertEqual(
            _source_license_mismatches(catalog, lock),
            {
                "source-a": {
                    "expected": "CC BY 4.0",
                    "actual": "CC BY-NC 4.0",
                }
            },
        )

    def test_missing_source_is_detected_as_license_drift(self):
        self.assertEqual(
            _source_license_mismatches(
                {"sources": []},
                {"required_source_licenses": {"source-a": "CC BY 4.0"}},
            ),
            {
                "source-a": {
                    "expected": "CC BY 4.0",
                    "actual": None,
                }
            },
        )


class SourceSnapshotReportTest(unittest.TestCase):
    def test_drift_records_only_include_changed_source_categories(self):
        species = [
            {"id": 1, "taxon_id": 11, "source_id": "nsr-dutch-species-register", "source_record_id": "nsr-1", "texts": {"nl": {"common_name": "Naam"}}},
            {"id": 2, "taxon_id": 12, "texts": {"de": {"common_name": "Name", "common_name_source_id": "dgfm-german-fungi"}}},
        ]
        lock = {"catalogue": {"nsr_species": 0, "dgfm_german_names": 1}}
        records = _drift_records(species, lock)
        self.assertEqual(len(records["nsr_species"]), 1)
        self.assertEqual(records["dgfm_german_names"], [])

    def test_verify_writes_valid_json_report_before_raising(self):
        catalog = {
            "species": [{"id": 1, "taxon_id": 11, "source_id": "nsr-dutch-species-register", "source_record_id": "nsr-1", "texts": {"nl": {"common_name": "Naam"}}}],
            "sources": [{"id": "nsr-dutch-species-register", "license": "CC BY 4.0"}],
        }
        lock = {
            "catalogue": {"total_species": 0, "nsr_species": 0, "dgfm_german_names": 0, "uksi_english_names": 0, "iucn_statuses": 0},
            "required_sources": ["nsr-dutch-species-register"],
            "required_source_licenses": {"nsr-dutch-species-register": "CC BY 4.0"},
        }
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            catalog_path, lock_path, report_path = root / "catalog.json", root / "lock.json", root / "report.json"
            catalog_path.write_text(json.dumps(catalog), encoding="utf-8")
            lock_path.write_text(json.dumps(lock), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Source snapshot drift detected"):
                verify(catalog_path, lock_path, report_path)
            report = json.loads(report_path.read_text(encoding="utf-8"))
            self.assertEqual(report["actual"]["nsr_species"], 1)
            self.assertEqual(report["records"]["nsr_species"][0]["source_record_id"], "nsr-1")


if __name__ == "__main__":
    unittest.main()
