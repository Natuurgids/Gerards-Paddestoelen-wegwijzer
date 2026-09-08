#!/usr/bin/env python3
import importlib.util
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("collect_verspreidingsatlas_reference_images.py")
spec = importlib.util.spec_from_file_location("verspreidingsatlas_collector", MODULE_PATH)
assert spec and spec.loader
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)

PAGE_URL = "https://www.verspreidingsatlas.nl/1234567"


class PhotoCandidateTest(unittest.TestCase):
    def parse(self, html: str):
        return collector._photo_candidate(PAGE_URL, html.encode("utf-8"))

    def test_cc0_in_figure_is_eligible(self):
        status, candidate, incompatible = self.parse(
            '<figure><img src="/photos/a.jpg"><figcaption>Jane Doe · CC0</figcaption></figure>'
        )
        self.assertEqual(status, "eligible_photo")
        self.assertEqual(candidate["license"], "CC0")
        self.assertEqual(candidate["source_photo_url"], "https://www.verspreidingsatlas.nl/photos/a.jpg")
        self.assertIsNone(incompatible)

    def test_cc_by_in_named_photo_block_is_eligible(self):
        status, candidate, incompatible = self.parse(
            '<div class="species-photo"><a href="/photos/a-full.jpg"><img src="/photos/a.jpg"></a>'
            '<div class="photo-credit">Jane Doe · CC BY 4.0</div></div>'
        )
        self.assertEqual(status, "eligible_photo")
        self.assertEqual(candidate["license"], "CC BY")
        self.assertEqual(candidate["source_photo_url"], "https://www.verspreidingsatlas.nl/photos/a-full.jpg")
        self.assertIsNone(incompatible)

    def test_generic_ancestor_license_is_not_bound_to_photo(self):
        status, candidate, incompatible = self.parse(
            '<section><div class="content"><img src="/photos/a.jpg"></div>'
            '<p>Website content CC BY 4.0</p></section>'
        )
        self.assertEqual(status, "eligible_license_visible_but_not_bound_to_individual_photo")
        self.assertIsNone(candidate)
        self.assertIsNone(incompatible)

    def test_neighbouring_photo_license_does_not_contaminate_unlicensed_photo(self):
        html = (
            '<div class="gallery">'
            '<div class="item"><img src="/photos/a.jpg"></div>'
            '<figure><img src="/photos/b.jpg"><figcaption>Jane Doe · CC BY-SA 4.0</figcaption></figure>'
            '</div>'
        )
        status, candidate, incompatible = self.parse(html)
        self.assertEqual(status, "photo_available_but_incompatible_or_unknown_license")
        self.assertIsNone(candidate)
        self.assertEqual(incompatible["source_photo_url"], "https://www.verspreidingsatlas.nl/photos/b.jpg")

    def test_incompatible_license_is_not_eligible(self):
        status, candidate, incompatible = self.parse(
            '<figure><img src="/photos/a.jpg"><figcaption>Jane Doe · CC BY-NC 4.0</figcaption></figure>'
        )
        self.assertEqual(status, "photo_available_but_incompatible_or_unknown_license")
        self.assertIsNone(candidate)
        self.assertIsNotNone(incompatible)

    def test_unknown_license_is_not_eligible(self):
        status, candidate, incompatible = self.parse(
            '<figure><img src="/photos/a.jpg"><figcaption>Photo: Jane Doe</figcaption></figure>'
        )
        self.assertEqual(status, "no_usable_photo_detected")
        self.assertIsNone(candidate)
        self.assertIsNone(incompatible)


if __name__ == "__main__":
    unittest.main()
