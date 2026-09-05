import plistlib
import tempfile
import unittest
from pathlib import Path

from tool.configure_generated_platforms import (
    ANDROID_INTERNET_PERMISSION,
    ANDROID_MIN_SDK,
    IOS_MIN_VERSION,
    configure,
    configure_android,
)


class ConfigureGeneratedPlatformsTest(unittest.TestCase):
    def test_configures_release_requirements_idempotently(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            android = root / "android/app/build.gradle.kts"
            android_manifest = root / "android/app/src/main/AndroidManifest.xml"
            ios_project = root / "ios/Runner.xcodeproj/project.pbxproj"
            ios_info = root / "ios/Flutter/AppFrameworkInfo.plist"
            podfile = root / "ios/Podfile"
            android.parent.mkdir(parents=True)
            android_manifest.parent.mkdir(parents=True)
            ios_project.parent.mkdir(parents=True)
            ios_info.parent.mkdir(parents=True)

            android.write_text(
                "android {\n    defaultConfig {\n        minSdk = flutter.minSdkVersion\n    }\n}\n",
                encoding="utf-8",
            )
            android_manifest.write_text(
                '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <application android:label="App" />\n'
                '</manifest>\n',
                encoding="utf-8",
            )
            ios_project.write_text(
                "IPHONEOS_DEPLOYMENT_TARGET = 12.0;\n"
                "IPHONEOS_DEPLOYMENT_TARGET = 12.0;\n",
                encoding="utf-8",
            )
            with ios_info.open("wb") as handle:
                plistlib.dump({"MinimumOSVersion": "12.0", "CFBundleName": "App"}, handle)
            podfile.write_text("platform :ios, '12.0'\n", encoding="utf-8")

            configure(root)
            configure(root)

            self.assertIn(f"minSdk = {ANDROID_MIN_SDK}", android.read_text(encoding="utf-8"))
            self.assertNotIn("flutter.minSdkVersion", android.read_text(encoding="utf-8"))
            manifest_text = android_manifest.read_text(encoding="utf-8")
            self.assertEqual(manifest_text.count(ANDROID_INTERNET_PERMISSION), 1)
            self.assertIn(
                f'<uses-permission android:name="{ANDROID_INTERNET_PERMISSION}" />',
                manifest_text,
            )
            self.assertEqual(
                ios_project.read_text(encoding="utf-8").count(
                    f"IPHONEOS_DEPLOYMENT_TARGET = {IOS_MIN_VERSION};"
                ),
                2,
            )
            with ios_info.open("rb") as handle:
                self.assertEqual(plistlib.load(handle)["MinimumOSVersion"], IOS_MIN_VERSION)
            self.assertEqual(
                podfile.read_text(encoding="utf-8"),
                f"platform :ios, '{IOS_MIN_VERSION}'\n",
            )

    def test_android_configuration_fails_if_flutter_template_changes(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            build_file = Path(temp_dir) / "build.gradle.kts"
            build_file.write_text("android { defaultConfig { } }\n", encoding="utf-8")

            with self.assertRaises(RuntimeError):
                configure_android(build_file)


if __name__ == "__main__":
    unittest.main()
