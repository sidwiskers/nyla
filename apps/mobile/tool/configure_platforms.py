#!/usr/bin/env python3
"""Apply Nyla's required native Android/iOS configuration.

The repository intentionally keeps Flutter platform scaffolds generated from a
pinned SDK instead of checking in a large amount of template boilerplate. This
script is the single idempotent patch layer used by CI and release builds.
"""

from __future__ import annotations

import plistlib
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ANDROID = ROOT / "android"
IOS = ROOT / "ios"
ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", ANDROID_NS)


def android_attr(name: str) -> str:
    return f"{{{ANDROID_NS}}}{name}"


def fail(message: str) -> None:
    raise SystemExit(f"configure_platforms: {message}")


def require(path: Path) -> Path:
    if not path.exists():
        fail(f"missing generated platform file: {path.relative_to(ROOT)}")
    return path


def indent_and_write(tree: ET.ElementTree, path: Path) -> None:
    ET.indent(tree, space="    ")
    tree.write(path, encoding="utf-8", xml_declaration=True)


def configure_android_manifest() -> None:
    path = require(ANDROID / "app/src/main/AndroidManifest.xml")
    tree = ET.parse(path)
    root = tree.getroot()

    permissions = {
        "android.permission.CAMERA",
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.RECEIVE_BOOT_COMPLETED",
        "android.permission.USE_BIOMETRIC",
    }
    existing = {
        node.get(android_attr("name"))
        for node in root.findall("uses-permission")
    }
    insertion = 0
    for permission in sorted(permissions - existing):
        node = ET.Element("uses-permission", {android_attr("name"): permission})
        root.insert(insertion, node)
        insertion += 1

    application = root.find("application")
    if application is None:
        fail("AndroidManifest.xml has no <application>")
    application.set(android_attr("label"), "Nyla")
    # Local health data and encryption material must never enter Android's
    # platform backup/transfer systems. Nyla has its own E2E encrypted sync.
    application.set(android_attr("allowBackup"), "false")
    application.set(android_attr("fullBackupContent"), "@xml/backup_rules")
    application.set(android_attr("dataExtractionRules"), "@xml/data_extraction_rules")

    receiver_names = {
        node.get(android_attr("name")): node for node in application.findall("receiver")
    }
    scheduled_name = "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
    if scheduled_name not in receiver_names:
        ET.SubElement(
            application,
            "receiver",
            {
                android_attr("android:name".split(":")[-1]): scheduled_name,
                android_attr("exported"): "false",
            },
        )

    boot_name = "com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
    boot = receiver_names.get(boot_name)
    if boot is None:
        boot = ET.SubElement(
            application,
            "receiver",
            {android_attr("name"): boot_name, android_attr("exported"): "false"},
        )
        intent = ET.SubElement(boot, "intent-filter")
        for action_name in (
            "android.intent.action.BOOT_COMPLETED",
            "android.intent.action.MY_PACKAGE_REPLACED",
        ):
            ET.SubElement(intent, "action", {android_attr("name"): action_name})

    indent_and_write(tree, path)


def configure_android_backup_rules() -> None:
    xml_dir = ANDROID / "app/src/main/res/xml"
    xml_dir.mkdir(parents=True, exist_ok=True)
    (xml_dir / "backup_rules.xml").write_text(
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
        "<full-backup-content>\n"
        "    <exclude domain=\"root\" path=\".\" />\n"
        "    <exclude domain=\"file\" path=\".\" />\n"
        "    <exclude domain=\"database\" path=\".\" />\n"
        "    <exclude domain=\"sharedpref\" path=\".\" />\n"
        "    <exclude domain=\"external\" path=\".\" />\n"
        "</full-backup-content>\n",
        encoding="utf-8",
    )
    (xml_dir / "data_extraction_rules.xml").write_text(
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
        "<data-extraction-rules>\n"
        "    <cloud-backup disableIfNoEncryptionCapabilities=\"true\">\n"
        "        <exclude domain=\"root\" path=\".\" />\n"
        "        <exclude domain=\"file\" path=\".\" />\n"
        "        <exclude domain=\"database\" path=\".\" />\n"
        "        <exclude domain=\"sharedpref\" path=\".\" />\n"
        "        <exclude domain=\"external\" path=\".\" />\n"
        "    </cloud-backup>\n"
        "    <device-transfer>\n"
        "        <exclude domain=\"root\" path=\".\" />\n"
        "        <exclude domain=\"file\" path=\".\" />\n"
        "        <exclude domain=\"database\" path=\".\" />\n"
        "        <exclude domain=\"sharedpref\" path=\".\" />\n"
        "        <exclude domain=\"external\" path=\".\" />\n"
        "    </device-transfer>\n"
        "</data-extraction-rules>\n",
        encoding="utf-8",
    )


def configure_android_activity() -> None:
    matches = list((ANDROID / "app/src/main/kotlin").rglob("MainActivity.kt"))
    if len(matches) != 1:
        fail(f"expected one MainActivity.kt, found {len(matches)}")
    path = matches[0]
    text = path.read_text(encoding="utf-8")
    text = text.replace(
        "import io.flutter.embedding.android.FlutterActivity",
        "import io.flutter.embedding.android.FlutterFragmentActivity",
    ).replace("FlutterActivity()", "FlutterFragmentActivity()")
    if "FlutterFragmentActivity" not in text:
        fail("could not configure FlutterFragmentActivity")
    path.write_text(text, encoding="utf-8")


def configure_android_theme() -> None:
    paths = list((ANDROID / "app/src/main/res").glob("values*/styles.xml"))
    if not paths:
        fail("no Android styles.xml files found")
    for path in paths:
        tree = ET.parse(path)
        changed = False
        for style in tree.getroot().findall("style"):
            if style.get("name") == "LaunchTheme":
                style.set("parent", "Theme.AppCompat.DayNight")
                changed = True
        if changed:
            indent_and_write(tree, path)


def configure_android_gradle() -> None:
    path = require(ANDROID / "app/build.gradle.kts")
    text = path.read_text(encoding="utf-8")

    signing_prelude = """val nylaKeystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
val nylaKeystorePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
val nylaKeyAlias = System.getenv("ANDROID_KEY_ALIAS")
val nylaKeyPassword = System.getenv("ANDROID_KEY_PASSWORD")
val nylaReleaseSigningConfigured = listOf(
    nylaKeystorePath,
    nylaKeystorePassword,
    nylaKeyAlias,
    nylaKeyPassword,
).all { !it.isNullOrBlank() }

"""
    if "val nylaKeystorePath =" not in text:
        android_marker = "android {\n"
        if android_marker not in text:
            fail("unexpected Flutter Android Gradle template: no android block")
        text = text.replace(android_marker, signing_prelude + android_marker, 1)

    signing_block = """    if (nylaReleaseSigningConfigured) {
        signingConfigs {
            create("release") {
                storeFile = file(nylaKeystorePath!!)
                storePassword = nylaKeystorePassword
                keyAlias = nylaKeyAlias
                keyPassword = nylaKeyPassword
            }
        }
    }

"""
    if "create(\"release\")" not in text:
        default_config_marker = "    defaultConfig {\n"
        if default_config_marker not in text:
            fail("unexpected Flutter Android Gradle template: no defaultConfig block")
        text = text.replace(default_config_marker, signing_block + default_config_marker, 1)

    debug_signing = "            signingConfig = signingConfigs.getByName(\"debug\")"
    release_signing = (
        "            signingConfig = if (nylaReleaseSigningConfigured) "
        "signingConfigs.getByName(\"release\") else signingConfigs.getByName(\"debug\")"
    )
    if release_signing not in text:
        if debug_signing not in text:
            fail("unexpected Flutter Android Gradle template: release signing marker changed")
        text = text.replace(debug_signing, release_signing, 1)

    marker = "        targetCompatibility = JavaVersion.VERSION_17\n"
    if "isCoreLibraryDesugaringEnabled = true" not in text:
        if marker not in text:
            fail("unexpected Flutter compileOptions template")
        text = text.replace(
            marker,
            marker + "        isCoreLibraryDesugaringEnabled = true\n",
            1,
        )
    dependency = 'coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")'
    if dependency not in text:
        text = text.rstrip() + f"\n\ndependencies {{\n    {dependency}\n}}\n"
    path.write_text(text, encoding="utf-8")


def configure_ios_deployment_target() -> None:
    path = require(IOS / "Runner.xcodeproj/project.pbxproj")
    text = path.read_text(encoding="utf-8")
    text, replacements = re.subn(
        r"IPHONEOS_DEPLOYMENT_TARGET\s*=\s*[^;]+;",
        "IPHONEOS_DEPLOYMENT_TARGET = 14.0;",
        text,
    )
    if replacements == 0:
        fail("could not set the generated iOS deployment target")
    path.write_text(text, encoding="utf-8")


def configure_ios_info() -> None:
    path = require(IOS / "Runner/Info.plist")
    with path.open("rb") as handle:
        data = plistlib.load(handle)
    data["NSCameraUsageDescription"] = (
        "Nyla uses the camera only to scan a one-time QR code from a trusted device."
    )
    data["NSFaceIDUsageDescription"] = "Use Face ID to unlock your private Nyla health data."
    with path.open("wb") as handle:
        plistlib.dump(data, handle, sort_keys=False)


def configure_ios_keychain() -> None:
    runner = IOS / "Runner"
    entitlements = {
        "keychain-access-groups": [],
    }
    for name in ("DebugProfile.entitlements", "Release.entitlements"):
        with (runner / name).open("wb") as handle:
            plistlib.dump(entitlements, handle, sort_keys=False)

    debug = require(IOS / "Flutter/Debug.xcconfig")
    release = require(IOS / "Flutter/Release.xcconfig")
    _append_xcconfig(debug, "CODE_SIGN_ENTITLEMENTS=Runner/DebugProfile.entitlements")
    _append_xcconfig(release, "CODE_SIGN_ENTITLEMENTS=Runner/Release.entitlements")


def _append_xcconfig(path: Path, line: str) -> None:
    text = path.read_text(encoding="utf-8")
    key = line.split("=", 1)[0]
    kept = [entry for entry in text.splitlines() if not entry.startswith(f"{key}=")]
    kept.append(line)
    path.write_text("\n".join(kept).rstrip() + "\n", encoding="utf-8")


def main() -> None:
    if not ANDROID.is_dir() or not IOS.is_dir():
        fail("generate Android and iOS scaffolds with the pinned Flutter SDK first")
    configure_android_manifest()
    configure_android_backup_rules()
    configure_android_activity()
    configure_android_theme()
    configure_android_gradle()
    configure_ios_deployment_target()
    configure_ios_info()
    configure_ios_keychain()
    print("Nyla native platform configuration applied.")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:  # fail closed with a useful CI diagnostic
        print(f"configure_platforms: {error}", file=sys.stderr)
        raise
