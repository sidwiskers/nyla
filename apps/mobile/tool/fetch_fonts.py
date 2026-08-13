#!/usr/bin/env python3
"""Fetch Nyla's pinned OFL typefaces with content verification."""

from __future__ import annotations

import hashlib
import os
import tempfile
import urllib.request
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FONT_DIR = ROOT / "assets/fonts"


@dataclass(frozen=True)
class FontAsset:
    name: str
    filename: str
    url: str
    size: int
    git_blob_sha1: str


FONTS = (
    FontAsset(
        name="Onest",
        filename="Onest-Variable.ttf",
        url=(
            "https://raw.githubusercontent.com/google/fonts/"
            "038b637da7b3fd956a4ed93ffc607c3d5e4ce172/"
            "ofl/onest/Onest%5Bwght%5D.ttf"
        ),
        size=193056,
        git_blob_sha1="477cb31027450d80e486a53119641bf87dde3d4c",
    ),
    FontAsset(
        name="Newsreader",
        filename="Newsreader-Variable.ttf",
        url=(
            "https://raw.githubusercontent.com/productiontype/Newsreader/"
            "cfcb4f7af0e52c25e8df2a2431814c8e5fe2e155/"
            "fonts/variable/ttf/Newsreader%5Bopsz%2Cwght%5D.ttf"
        ),
        size=451664,
        git_blob_sha1="ad4a9a8c44ec328c80b61c773f1ba02f6b5ed292",
    ),
)


def git_blob_sha1(data: bytes) -> str:
    header = f"blob {len(data)}\0".encode()
    return hashlib.sha1(header + data).hexdigest()


def valid(asset: FontAsset, data: bytes) -> bool:
    return len(data) == asset.size and git_blob_sha1(data) == asset.git_blob_sha1


def fetch(asset: FontAsset) -> None:
    destination = FONT_DIR / asset.filename
    if destination.exists() and valid(asset, destination.read_bytes()):
        return

    request = urllib.request.Request(
        asset.url,
        headers={"User-Agent": "Nyla deterministic font fetcher"},
    )
    with urllib.request.urlopen(request, timeout=45) as response:
        data = response.read(asset.size + 1)

    if not valid(asset, data):
        raise SystemExit(
            f"Font verification failed for {asset.name}: "
            f"expected {asset.size} bytes / {asset.git_blob_sha1}, "
            f"got {len(data)} bytes / {git_blob_sha1(data)}"
        )

    FONT_DIR.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=f".{asset.filename}.", dir=FONT_DIR)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main() -> None:
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    for asset in FONTS:
        fetch(asset)
    print("Nyla typography assets are ready.")


if __name__ == "__main__":
    main()
