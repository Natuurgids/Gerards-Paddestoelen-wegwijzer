#!/usr/bin/env python3
from __future__ import annotations

import unittest

from tool.verify_source_snapshot_lock import _source_license_mismatches


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


if __name__ == "__main__":
    unittest.main()
