#!/usr/bin/env python3
"""Fail closed on basic Google Play release invariants for the generated Android AAB."""

from __future__ import annotations

import argparse
import json
import re
import zipfile
from pathlib import Path

AAB_PREFIX = "base/assets/flutter_assets/"
EXPECTED_APPLICATION_ID = "nl.natuurgids.gerards_paddestoelen_wegwijzer"
EXPECTED_MIN_SDK = 24
EXPECTED_TARGET_SDK = 36
ALLOWED_SOURCE_PERMISSIONS = {"android.permission.INTERNET"}
FORBIDDEN_NAME_FRAGMENTS = (
    ".env",
    "keystore",
    "key.properties",
    "google-services.json",
    "service-account",
    "credentials",
    "secret",
)


def _manifest_paths(manifest_path: Path) -> list[str]:
    payload = json.loads(manifest_path.read_text(encoding="utf-8"))
    paths = [
        str(image.get("path") or "").strip()
        for species in payload.get("species", [])
        for image in species.get("images", [])
    ]
    paths = [path for path in paths if path]
    if not paths:
        raise SystemExit("Species image manifest contains no image paths")
    if len(paths) != len(set(paths)):
        raise SystemExit("Species image manifest contains duplicate image paths")
    return paths


def _verify_gradle(build_file: Path) -> None:
    text = build_file.read_text(encoding="utf-8")
    app_id = re.search(r'applicationId\s*=\s*"([^"]+)"', text)
    min_sdk = re.search(r"minSdk\s*=\s*(\d+)", text)
    target_sdk = re.search(r"targetSdk\s*=\s*(\d+)", text)
    if not app_id or app_id.group(1) != EXPECTED_APPLICATION_ID:
        raise SystemExit(f"Unexpected or missing applicationId; expected {EXPECTED_APPLICATION_ID}")
    if not min_sdk or int(min_sdk.group(1)) != EXPECTED_MIN_SDK:
        raise SystemExit(f"Unexpected or missing minSdk; expected {EXPECTED_MIN_SDK}")
    if not target_sdk or int(target_sdk.group(1)) < EXPECTED_TARGET_SDK:
        raise SystemExit(f"targetSdk must be at least {EXPECTED_TARGET_SDK}")
    if "debuggable = true" in text or "isDebuggable = true" in text:
        raise SystemExit("Release Gradle configuration contains an explicit debuggable=true")


def _verify_source_manifest(manifest_file: Path) -> None:
    text = manifest_file.read_text(encoding="utf-8")
    permissions = set(re.findall(r'<uses-permission\s+android:name="([^"]+)"', text))
    unexpected = permissions - ALLOWED_SOURCE_PERMISSIONS
    if unexpected:
        raise SystemExit(f"Unexpected source permissions: {sorted(unexpected)}")
    if "android:usesCleartextTraffic=\"true\"" in text:
        raise SystemExit("Cleartext HTTP traffic is explicitly enabled")
    exported = re.findall(r'<([A-Za-z0-9_.]+)[^>]*android:exported="true"[^>]*>', text, re.S)
    if len(exported) > 1:
        raise SystemExit(f"Unexpected exported Android components: {exported}")


def verify(aab_path: Path, image_manifest: Path, build_file: Path, android_manifest: Path) -> int:
    _verify_gradle(build_file)
    _verify_source_manifest(android_manifest)
    expected = _manifest_paths(image_manifest)

    with zipfile.ZipFile(aab_path) as bundle:
        names = set(bundle.namelist())

    if "base/manifest/AndroidManifest.xml" not in names:
        raise SystemExit("AAB does not contain the base Android manifest")
    if "BundleConfig.pb" not in names:
        raise SystemExit("File is not a valid Android App Bundle: BundleConfig.pb missing")

    lower_names = [name.lower() for name in names]
    leaked = [
        name for name, lower in zip(names, lower_names)
        if any(fragment in lower for fragment in FORBIDDEN_NAME_FRAGMENTS)
    ]
    if leaked:
        raise SystemExit(f"Potentially sensitive files packaged in AAB: {sorted(leaked)[:10]}")

    missing = [path for path in expected if AAB_PREFIX + path not in names]
    packaged_species_images = [
        name for name in names
        if name.startswith(AAB_PREFIX + "assets/images/species/")
        and name.lower().endswith((".jpg", ".jpeg", ".png", ".webp"))
    ]
    if missing:
        raise SystemExit(
            f"AAB is missing {len(missing)} of {len(expected)} manifest species images; "
            f"first entries: {missing[:10]}"
        )
    if len(packaged_species_images) != len(expected):
        raise SystemExit(
            f"AAB contains {len(packaged_species_images)} species images; expected exactly {len(expected)}"
        )

    print(
        "Google Play release verification passed: "
        f"applicationId={EXPECTED_APPLICATION_ID}, minSdk={EXPECTED_MIN_SDK}, "
        f"targetSdk>={EXPECTED_TARGET_SDK}, permissions={sorted(ALLOWED_SOURCE_PERMISSIONS)}, "
        f"species_images={len(expected)}, AAB structure valid"
    )
    return len(expected)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--aab", default="build/app/outputs/bundle/release/app-release.aab")
    parser.add_argument("--image-manifest", default="assets/data/species_images.json")
    parser.add_argument("--build-file", default="android/app/build.gradle.kts")
    parser.add_argument("--android-manifest", default="android/app/src/main/AndroidManifest.xml")
    args = parser.parse_args()
    verify(
        Path(args.aab),
        Path(args.image_manifest),
        Path(args.build_file),
        Path(args.android_manifest),
    )


if __name__ == "__main__":
    main()
