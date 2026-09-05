import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from tool.publish_learning_packages import publish


REPO_ROOT = Path(__file__).resolve().parents[1]
OFFERINGS = REPO_ROOT / "assets/data/learning_offerings.json"


class PublishLearningPackagesTest(unittest.TestCase):
    def test_builds_all_seven_packages_with_exact_hash_and_size(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source = root / "private"
            output = root / "publish"
            source.mkdir()
            offerings = self._write_private_sources(source)

            catalog = publish(
                source_dir=source,
                output_dir=output,
                offerings_path=OFFERINGS,
                expected_count=7,
            )

            self.assertEqual(len(catalog["packages"]), 7)
            self.assertEqual(
                [item["package_key"] for item in catalog["packages"]],
                [item["package_key"] for item in offerings],
            )
            on_disk = json.loads(
                (output / "learning_package_catalog.json").read_text(encoding="utf-8")
            )
            self.assertEqual(on_disk, catalog)
            for descriptor in catalog["packages"]:
                payload_path = output / descriptor["package_path"]
                payload = payload_path.read_bytes()
                self.assertEqual(len(payload), descriptor["package_size_bytes"])
                self.assertEqual(
                    hashlib.sha256(payload).hexdigest(),
                    descriptor["package_sha256"],
                )
                package = json.loads(payload.decode("utf-8"))
                self.assertEqual(package["package_key"], descriptor["package_key"])
                self.assertEqual(
                    package["content_version"], descriptor["content_version"]
                )

    def test_invalid_private_package_fails_atomically(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            source = root / "private"
            output = root / "publish"
            source.mkdir()
            offerings = self._write_private_sources(source)
            broken = source / f"{offerings[0]['package_key']}.json"
            package = json.loads(broken.read_text(encoding="utf-8"))
            package["course"]["price"] = "2.99"
            broken.write_text(json.dumps(package), encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "store pricing"):
                publish(
                    source_dir=source,
                    output_dir=output,
                    offerings_path=OFFERINGS,
                    expected_count=7,
                )
            self.assertFalse(output.exists())

    def test_refuses_private_source_inside_public_repository(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "publish"
            with self.assertRaisesRegex(ValueError, "source directory must be outside"):
                publish(
                    source_dir=REPO_ROOT / "assets/data",
                    output_dir=output,
                    offerings_path=OFFERINGS,
                    expected_count=7,
                )

    def _write_private_sources(self, source: Path):
        offerings_root = json.loads(OFFERINGS.read_text(encoding="utf-8"))
        offerings = offerings_root["offerings"]
        for index, offering in enumerate(offerings):
            lesson_id = 1000 + index
            question_id = 10000 + index
            answer_id = 20000 + index * 2
            package = {
                "package_version": 1,
                "package_key": offering["package_key"],
                "content_version": 2,
                "course": {
                    "key": offering["course_key"],
                    "access": "entitlement_required",
                    "delivery": "downloadable",
                    "entitlement_key": offering["entitlement_key"],
                    "product_key": offering["product_key"],
                    "group_key": offering["group_key"],
                    "sort_order": offering["sort_order"],
                    "prerequisite_course_keys": ["determination-foundations"],
                },
                "modules": [
                    {
                        "key": f"{offering['package_key']}-module",
                        "course_key": offering["course_key"],
                        "lesson_ids": [lesson_id],
                        "sort_order": 10,
                    }
                ],
                "training_content": {
                    "version": 2,
                    "lessons": [
                        {
                            "id": lesson_id,
                            "slug": f"{offering['package_key']}-lesson",
                            "difficulty": 2,
                            "sort_order": 10,
                            "texts": {
                                "nl": {"title": "Privéles", "body": "Nieuwe Nederlandse inhoud."},
                                "en": {"title": "Private lesson", "body": "New English content."},
                                "de": {"title": "Private Lektion", "body": "Neue deutsche Inhalte."},
                            },
                            "questions": [
                                {
                                    "id": question_id,
                                    "sort_order": 10,
                                    "texts": {
                                        "nl": {"prompt": "Welke combinatie?", "explanation": "Gebruik meerdere kenmerken."},
                                        "en": {"prompt": "Which combination?", "explanation": "Use multiple characters."},
                                        "de": {"prompt": "Welche Kombination?", "explanation": "Nutze mehrere Merkmale."},
                                    },
                                    "answers": [
                                        {
                                            "id": answer_id,
                                            "correct": True,
                                            "sort_order": 10,
                                            "labels": {"nl": "Meerdere kenmerken", "en": "Multiple characters", "de": "Mehrere Merkmale"},
                                        },
                                        {
                                            "id": answer_id + 1,
                                            "correct": False,
                                            "sort_order": 20,
                                            "labels": {"nl": "Alleen kleur", "en": "Colour only", "de": "Nur Farbe"},
                                        },
                                    ],
                                }
                            ],
                        }
                    ],
                },
            }
            (source / f"{offering['package_key']}.json").write_text(
                json.dumps(package, ensure_ascii=False),
                encoding="utf-8",
            )
        return offerings


if __name__ == "__main__":
    unittest.main()
