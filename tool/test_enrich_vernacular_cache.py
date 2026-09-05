#!/usr/bin/env python3
from __future__ import annotations

import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tool import enrich_vernacular_names as module


class _Response(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        self.close()
        return False


class VernacularCacheTest(unittest.TestCase):
    def tearDown(self):
        module._CACHE_DIR = None

    def test_second_request_uses_cached_json_without_network(self):
        url = "https://example.test/source?page=1"
        payload = {"results": [{"scientificName": "Testus fungalis"}], "count": 1}
        with tempfile.TemporaryDirectory() as directory:
            module._CACHE_DIR = Path(directory)
            with mock.patch.object(
                module.urllib.request,
                "urlopen",
                return_value=_Response(json.dumps(payload).encode("utf-8")),
            ) as urlopen:
                self.assertEqual(module._request_json(url), payload)
                self.assertEqual(urlopen.call_count, 1)

            with mock.patch.object(
                module.urllib.request,
                "urlopen",
                side_effect=AssertionError("network should not be used on cache hit"),
            ):
                self.assertEqual(module._request_json(url), payload)

    def test_different_urls_have_different_cache_files(self):
        with tempfile.TemporaryDirectory() as directory:
            module._CACHE_DIR = Path(directory)
            self.assertNotEqual(
                module._cache_path("https://example.test/a"),
                module._cache_path("https://example.test/b"),
            )


if __name__ == "__main__":
    unittest.main()
