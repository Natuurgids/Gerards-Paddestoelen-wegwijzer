import json
import tempfile
import unittest
from pathlib import Path

from enrich_ecology import enrich


class EcologyEnrichmentTest(unittest.TestCase):
    def test_adds_genus_habitat_and_reviewed_lookalikes_without_overwrite(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            catalog = root / "catalog.json"
            reviewed = root / "reviewed.json"
            catalog.write_text(json.dumps({
                "version": 3,
                "sources": [],
                "taxa": [
                    {"id": 1, "rank": "species", "scientific_name": "Cantharellus cibarius"},
                    {"id": 2, "rank": "species", "scientific_name": "Example testii"}
                ],
                "species": [
                    {"id": 1, "taxon_id": 1, "texts": {}},
                    {"id": 2, "taxon_id": 2, "texts": {"nl": {"common_name": "Voorbeeld", "habitat": "Bestaande soortspecifieke habitat."}}}
                ]
            }), encoding="utf-8")
            reviewed.write_text(json.dumps({"species": [{
                "scientific_name": "Cantharellus cibarius",
                "source_id": "first-nature",
                "source_record_id": "record",
                "habitat_nl": "Soortspecifieke habitat.",
                "lookalikes_nl": "Verwar met Example similare."
            }]}), encoding="utf-8")
            source = (
                "GENUS,primary_lifestyle,Secondary_lifestyle,Decay_substrate_template,Aquatic_habitat_template,Specific_hosts\n"
                "Cantharellus,ectomycorrhizal,,,,\n"
                "Example,wood_saprotroph,,wood,non-aquatic,\n"
            )

            habitat_count, lookalike_count = enrich(
                catalog, source, reviewed, 1, "2026-09-06"
            )
            result = json.loads(catalog.read_text(encoding="utf-8"))
            first = result["species"][0]["texts"]["nl"]
            second = result["species"][1]["texts"]["nl"]

            self.assertEqual(habitat_count, 1)
            self.assertEqual(lookalike_count, 1)
            self.assertEqual(first["common_name"], "Cantharellus cibarius")
            self.assertEqual(first["habitat"], "Soortspecifieke habitat.")
            self.assertEqual(first["habitat_basis"], "species")
            self.assertEqual(first["lookalikes"], "Verwar met Example similare.")
            self.assertEqual(second["common_name"], "Voorbeeld")
            self.assertEqual(second["habitat"], "Bestaande soortspecifieke habitat.")
            self.assertTrue(any(s["id"] == "fungaltraits-globi" for s in result["sources"]))


if __name__ == "__main__":
    unittest.main()
