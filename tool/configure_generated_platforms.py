#!/usr/bin/env python3
"""Apply release platform requirements to Flutter-generated Android/iOS files."""

from __future__ import annotations

import argparse
import plistlib
import re
from pathlib import Path

ANDROID_MIN_SDK = 24
ANDROID_INTERNET_PERMISSION = "android.permission.INTERNET"
IOS_MIN_VERSION = "13.0"


def configure_android(build_file: Path) -> None:
    text = build_file.read_text(encoding="utf-8")
    patterns = (
        (r"minSdk\s*=\s*flutter\.minSdkVersion", f"minSdk = {ANDROID_MIN_SDK}"),
        (r"minSdk\s*=\s*\d+", f"minSdk = {ANDROID_MIN_SDK}"),
        (r"minSdkVersion\s+flutter\.minSdkVersion", f"minSdkVersion {ANDROID_MIN_SDK}"),
        (r"minSdkVersion\s+\d+", f"minSdkVersion {ANDROID_MIN_SDK}"),
    )
    for pattern, replacement in patterns:
        updated, count = re.subn(pattern, replacement, text, count=1)
        if count:
            build_file.write_text(updated, encoding="utf-8")
            return
    raise RuntimeError(f"Could not locate Android minSdk declaration in {build_file}")


def configure_android_manifest(manifest_file: Path) -> None:
    text = manifest_file.read_text(encoding="utf-8")
    if ANDROID_INTERNET_PERMISSION in text:
        return
    match = re.search(r"<manifest\b[^>]*>", text)
    if not match:
        raise RuntimeError(f"Could not locate Android manifest root in {manifest_file}")
    permission = (
        f'    <uses-permission android:name="{ANDROID_INTERNET_PERMISSION}" />'
    )
    updated = f"{text[:match.end()]}\n{permission}{text[match.end():]}"
    manifest_file.write_text(updated, encoding="utf-8")


def configure_ios_project(project_file: Path) -> None:
    text = project_file.read_text(encoding="utf-8")
    updated, count = re.subn(
        r"IPHONEOS_DEPLOYMENT_TARGET\s*=\s*[0-9.]+;",
        f"IPHONEOS_DEPLOYMENT_TARGET = {IOS_MIN_VERSION};",
        text,
    )
    if not count:
        raise RuntimeError(
            f"Could not locate iOS deployment target declarations in {project_file}"
        )
    project_file.write_text(updated, encoding="utf-8")


def configure_ios_framework_info(plist_file: Path) -> None:
    with plist_file.open("rb") as handle:
        data = plistlib.load(handle)
    data["MinimumOSVersion"] = IOS_MIN_VERSION
    with plist_file.open("wb") as handle:
        plistlib.dump(data, handle, sort_keys=False)


def configure_ios_podfile(podfile: Path) -> None:
    if not podfile.exists():
        return
    text = podfile.read_text(encoding="utf-8")
    pattern = r"platform\s+:ios,\s*['\"][0-9.]+['\"]"
    if re.search(pattern, text):
        text = re.sub(pattern, f"platform :ios, '{IOS_MIN_VERSION}'", text, count=1)
    else:
        text = f"platform :ios, '{IOS_MIN_VERSION}'\n{text}"
    podfile.write_text(text, encoding="utf-8")


def configure(root: Path) -> None:
    configure_android(root / "android/app/build.gradle.kts")
    configure_android_manifest(root / "android/app/src/main/AndroidManifest.xml")
    configure_ios_project(root / "ios/Runner.xcodeproj/project.pbxproj")
    configure_ios_framework_info(root / "ios/Flutter/AppFrameworkInfo.plist")
    configure_ios_podfile(root / "ios/Podfile")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path("."))
    args = parser.parse_args()
    configure(args.root)
    print(
        f"Configured generated platforms: Android SDK {ANDROID_MIN_SDK}+ with "
        f"Internet access, iOS {IOS_MIN_VERSION}+"
    )


if __name__ == "__main__":
    main()
