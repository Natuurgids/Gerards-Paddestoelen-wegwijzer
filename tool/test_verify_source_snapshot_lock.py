#!/usr/bin/env python3
from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from tool.verify_source_snapshot_lock import _drift_records, _identity_manifest, _manifest_diff, _source_license_mismatches, verify, write_identity_manifest


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


class SourceIdentityRequirementTest(unittest.TestCase):
    def test_missing_required_identity_manifest_fails_before_snapshot_acceptance(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            catalog_path, lock_path = root / "catalog.json", root / "lock.json"
            catalog_path.write_text(json.dumps({"species": [], "sources": []}), encoding="utf-8")
            lock_path.write_text(json.dumps({
                "catalogue": {
                    "total_species": 0,
                    "nsr_species": 0,
                    "dgfm_german_names": 0,
                    "uksi_english_names": 0,
                    "iucn_statuses": 0,
                },
                "snapshot_date": "2026-10-01",
                "required_sources": [],
                "required_source_licenses": {},
            }), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "identity manifest is required"):
                verify(
                    catalog_path,
                    lock_path,
                    identity_manifest_path=root / "missing.json",
                    require_identity_manifest=True,
                )


    def test_legacy_count_only_snapshot_can_still_report_drift(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            catalog_path, lock_path, report_path = root / "catalog.json", root / "lock.json", root / "report.json"
            catalog_path.write_text(json.dumps({
                "species": [{"id": 1, "source_id": "nsr-dutch-species-register"}],
                "sources": [],
            }), encoding="utf-8")
            lock_path.write_text(json.dumps({
                "snapshot_date": "2026-09-08",
                "catalogue": {
                    "total_species": 0, "nsr_species": 0, "dgfm_german_names": 0,
                    "uksi_english_names": 0, "iucn_statuses": 0,
                },
                "required_sources": [], "required_source_licenses": {},
            }), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Source snapshot drift detected"):
                verify(
                    catalog_path, lock_path, report_path,
                    identity_manifest_path=root / "missing.json",
                    require_identity_manifest=True,
                )
            report = json.loads(report_path.read_text(encoding="utf-8"))
            self.assertEqual(report["actual"]["nsr_species"], 1)
            self.assertIsNone(report["identity_diff"])


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

    def test_verify_reports_exact_identity_diff_when_reviewed_manifest_exists(self):
        catalog = {
            "species": [
                {"id": 2, "taxon_id": 12, "source_id": "nsr-dutch-species-register", "source_record_id": "new"},
            ],
            "sources": [{"id": "nsr-dutch-species-register", "license": "CC BY 4.0"}],
        }
        lock = {
            "catalogue": {"total_species": 0, "nsr_species": 0, "dgfm_german_names": 0, "uksi_english_names": 0, "iucn_statuses": 0},
            "required_sources": ["nsr-dutch-species-register"],
            "required_source_licenses": {"nsr-dutch-species-register": "CC BY 4.0"},
        }
        reviewed = {
            "nsr_species": [{"id": 1, "taxon_id": 11, "source_record_id": "old"}],
            "dgfm_german_names": [],
        }
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            catalog_path, lock_path = root / "catalog.json", root / "lock.json"
            report_path, manifest_path = root / "report.json", root / "identities.json"
            catalog_path.write_text(json.dumps(catalog), encoding="utf-8")
            lock_path.write_text(json.dumps(lock), encoding="utf-8")
            manifest_path.write_text(json.dumps(reviewed), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "Source snapshot drift detected"):
                verify(catalog_path, lock_path, report_path, manifest_path)
            diff = json.loads(report_path.read_text(encoding="utf-8"))["identity_diff"]["nsr_species"]
            self.assertEqual([x["source_record_id"] for x in diff["added"]], ["new"])
            self.assertEqual([x["source_record_id"] for x in diff["removed"]], ["old"])

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


class SourceIdentityManifestTest(unittest.TestCase):
    def test_manifest_diff_reports_added_removed_and_changed_identities(self):
        reviewed = {
            "nsr_species": [
                {"id": 1, "taxon_id": 11, "source_record_id": "a"},
                {"id": 2, "taxon_id": 12, "source_record_id": "b"},
            ],
            "dgfm_german_names": [
                {"id": 3, "taxon_id": 13, "de_name": "Alt"},
            ],
        }
        current = {
            "nsr_species": [
                {"id": 2, "taxon_id": 12, "source_record_id": "b"},
                {"id": 4, "taxon_id": 14, "source_record_id": "c"},
            ],
            "dgfm_german_names": [
                {"id": 3, "taxon_id": 13, "de_name": "Neu"},
            ],
        }
        diff = _manifest_diff(current, reviewed)
        self.assertEqual([x["source_record_id"] for x in diff["nsr_species"]["added"]], ["c"])
        self.assertEqual([x["source_record_id"] for x in diff["nsr_species"]["removed"]], ["a"])
        self.assertEqual(len(diff["dgfm_german_names"]["changed"]), 1)

    def test_identity_manifest_writer_is_stable_and_source_scoped(self):
        catalog = {
            "species": [
                {"id": 2, "taxon_id": 12, "source_id": "other"},
                {"id": 1, "taxon_id": 11, "source_id": "nsr-dutch-species-register", "source_record_id": "a"},
                {"id": 3, "taxon_id": 13, "texts": {"de": {"common_name": "Name", "common_name_source_id": "dgfm-german-fungi"}}},
            ]
        }
        with tempfile.TemporaryDirectory() as tmp:
            catalog_path = Path(tmp) / "catalog.json"
            manifest_path = Path(tmp) / "manifest.json"
            catalog_path.write_text(json.dumps(catalog), encoding="utf-8")
            write_identity_manifest(catalog_path, manifest_path)
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            self.assertEqual(manifest["nsr_species"], [{"id": 1, "source_record_id": "a", "taxon_id": 11}])
            self.assertEqual(manifest["dgfm_german_names"], [{"de_name": "Name", "id": 3, "taxon_id": 13}])


if __name__ == "__main__":
    unittest.main()
