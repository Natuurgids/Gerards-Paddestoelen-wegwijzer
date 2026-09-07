import unittest

from tool.audit_determination_coverage import build_report


class DeterminationCoverageAuditTest(unittest.TestCase):
    def test_distinguishes_any_and_provenanced_coverage(self) -> None:
        catalog = {
            "taxa": [
                {"id": 101, "scientific_name": "Alpha one"},
                {"id": 102, "scientific_name": "Beta two"},
                {"id": 103, "scientific_name": "Gamma three"},
            ],
            "species": [
                {"id": 1, "taxon_id": 101},
                {"id": 2, "taxon_id": 102},
                {"id": 3, "taxon_id": 103},
            ],
        }
        core = {
            "traits": [{"id": 1}, {"id": 2}],
            "species_traits": [
                {"species_id": 1, "trait_id": 1, "option_id": 10},
            ],
        }
        supplemental = {
            "species_traits": [
                {
                    "species_id": 2,
                    "trait_id": 1,
                    "option_id": 11,
                    "source_id": "reviewed-source",
                    "source_record_id": "record-2",
                },
                {
                    "species_id": 2,
                    "trait_id": 2,
                    "option_id": 12,
                    "source_id": "reviewed-source",
                    "source_record_id": "record-2",
                },
                {
                    "species_id": 999,
                    "trait_id": 1,
                    "option_id": 10,
                    "source_id": "off-catalog",
                    "source_record_id": "ignored",
                },
            ]
        }

        report = build_report(catalog, core, supplemental)

        self.assertEqual(report["catalog_species_considered"], 3)
        self.assertEqual(report["determination_relations_total"], 3)
        self.assertEqual(report["provenanced_relations_total"], 2)
        self.assertEqual(report["species_with_any_determination_traits"], 2)
        self.assertEqual(report["species_with_provenanced_determination_traits"], 1)
        self.assertEqual(report["species_without_determination_traits"], 1)
        self.assertEqual(report["coverage_percent_any"], 66.6667)
        self.assertEqual(report["coverage_percent_provenanced"], 33.3333)
        self.assertEqual(
            report["coverage_gaps"],
            [{"species_id": 3, "scientific_name": "Gamma three"}],
        )
        self.assertTrue(report["policy"]["no_trait_inference_performed"])

    def test_empty_catalog_has_zero_percentages(self) -> None:
        report = build_report({"taxa": [], "species": []}, {"traits": []}, {})
        self.assertEqual(report["coverage_percent_any"], 0.0)
        self.assertEqual(report["coverage_percent_provenanced"], 0.0)


if __name__ == "__main__":
    unittest.main()
