#!/usr/bin/env python3
"""Apply Nyla's deterministic launcher branding to generated native projects."""

from __future__ import annotations

import json
import re
import shutil
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FULL_ICON = ROOT / "assets/branding/nyla_app_icon.svg"
FOREGROUND_ICON = ROOT / "assets/branding/nyla_app_icon_foreground.svg"
ANDROID_RES = ROOT / "android/app/src/main/res"
IOS_APPICON = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"


def fail(message: str) -> None:
    raise SystemExit(message)


def render(svg: Path, destination: Path, size: int) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["rsvg-convert", "-w", str(size), "-h", str(size), str(svg), "-o", str(destination)],
        check=True,
    )
    if png_size(destination) != (size, size):
        fail(f"Unexpected launcher icon size: {destination}")


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        signature = handle.read(24)
    if len(signature) < 24 or signature[:8] != b"\x89PNG\r\n\x1a\n":
        fail(f"Branding renderer did not create a PNG: {path}")
    return struct.unpack(">II", signature[16:24])


def apply_android() -> None:
    if not ANDROID_RES.exists():
        fail("Android project is missing; generate the pinned scaffold first")

    legacy_sizes = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    foreground_sizes = {
        "mdpi": 108,
        "hdpi": 162,
        "xhdpi": 216,
        "xxhdpi": 324,
        "xxxhdpi": 432,
    }

    for density, size in legacy_sizes.items():
        render(FULL_ICON, ANDROID_RES / f"mipmap-{density}/ic_launcher.png", size)

    for density, size in foreground_sizes.items():
        render(FOREGROUND_ICON, ANDROID_RES / f"drawable-{density}/nyla_launcher_foreground.png", size)

    values = ANDROID_RES / "values/nyla_launcher_colors.xml"
    values.parent.mkdir(parents=True, exist_ok=True)
    values.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <color name="nyla_launcher_background">#FFF8F4</color>\n'
        '</resources>\n',
        encoding="utf-8",
    )

    adaptive = ANDROID_RES / "mipmap-anydpi-v26/ic_launcher.xml"
    adaptive.parent.mkdir(parents=True, exist_ok=True)
    adaptive.write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/nyla_launcher_background" />\n'
        '    <foreground android:drawable="@drawable/nyla_launcher_foreground" />\n'
        '</adaptive-icon>\n',
        encoding="utf-8",
    )

    manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
    text = manifest.read_text(encoding="utf-8")
    text, count = re.subn(r'android:label="[^"]*"', 'android:label="Nyla"', text, count=1)
    if count != 1:
        fail("Could not set the Android app label")
    manifest.write_text(text, encoding="utf-8")


def apply_ios() -> None:
    contents_path = IOS_APPICON / "Contents.json"
    if not contents_path.exists():
        fail("iOS AppIcon catalog is missing; generate the pinned scaffold first")

    contents = json.loads(contents_path.read_text(encoding="utf-8"))
    rendered = 0
    for image in contents.get("images", []):
        filename = image.get("filename")
        size_value = image.get("size")
        scale_value = image.get("scale")
        if not filename or not size_value or not scale_value:
            continue
        points = float(str(size_value).split("x", 1)[0])
        scale = float(str(scale_value).rstrip("x"))
        pixels = round(points * scale)
        render(FULL_ICON, IOS_APPICON / filename, pixels)
        rendered += 1

    if rendered == 0:
        fail("No iOS AppIcon entries were rendered")

    info = ROOT / "ios/Runner/Info.plist"
    text = info.read_text(encoding="utf-8")
    for key in ("CFBundleDisplayName", "CFBundleName"):
        pattern = rf'(<key>{key}</key>\s*<string>)[^<]*(</string>)'
        text, count = re.subn(pattern, rf'\1Nyla\2', text, count=1)
        if count == 0 and key == "CFBundleDisplayName":
            marker = "<dict>"
            insertion = "<dict>\n\t<key>CFBundleDisplayName</key>\n\t<string>Nyla</string>"
            text = text.replace(marker, insertion, 1)
    info.write_text(text, encoding="utf-8")


def main() -> None:
    if shutil.which("rsvg-convert") is None:
        fail("rsvg-convert is required to render Nyla launcher artwork")
    for source in (FULL_ICON, FOREGROUND_ICON):
        if not source.exists():
            fail(f"Missing branding source: {source}")

    apply_android()
    apply_ios()
    print("Applied Nyla launcher branding to Android and iOS.")


if __name__ == "__main__":
    main()
