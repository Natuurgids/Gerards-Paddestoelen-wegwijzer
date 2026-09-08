import unittest

from tool.build_nsr_fungi_catalog import _field_guide_group


class FieldGuideScopeTest(unittest.TestCase):
    def test_true_fungus_is_included(self):
        self.assertEqual(_field_guide_group({"kingdom": "Fungi"}), "fungus")

    def test_myxomycete_is_included_but_labelled_separately(self):
        self.assertEqual(
            _field_guide_group(
                {
                    "kingdom": "Protozoa",
                    "phylum": "Eumycetozoa",
                    "class": "Myxomycetes",
                }
            ),
            "slime_mould",
        )

    def test_myxogastrea_is_included_but_labelled_separately(self):
        self.assertEqual(
            _field_guide_group(
                {
                    "kingdom": "Protozoa",
                    "phylum": "Amoebozoa",
                    "class": "Myxogastrea",
                }
            ),
            "slime_mould",
        )

    def test_unrelated_protozoa_are_not_included(self):
        self.assertIsNone(
            _field_guide_group(
                {
                    "kingdom": "Protozoa",
                    "phylum": "Amoebozoa",
                    "class": "Tubulinea",
                }
            )
        )

    def test_higher_classification_fallback_is_narrow(self):
        self.assertEqual(
            _field_guide_group(
                {
                    "kingdom": "Protozoa",
                    "higherClassification": "Eukaryota; Amoebozoa; Myxogastrea; Trichiales",
                }
            ),
            "slime_mould",
        )


if __name__ == "__main__":
    unittest.main()
