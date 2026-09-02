#!/usr/bin/env python3
"""Expand and validate Nyla's lossless launcher artwork for build tools."""

from __future__ import annotations

import gzip
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRANDING = ROOT / "assets/branding"
SVG_NS = "http://www.w3.org/2000/svg"
EXPECTED_VIEWBOX = "0 0 1254 1254"


def fail(message: str) -> None:
    raise SystemExit(f"prepare_branding: {message}")


def _expand(name: str) -> tuple[Path, ET.Element]:
    source = BRANDING / f"{name}.svgz"
    destination = BRANDING / f"{name}.svg"
    if not source.is_file():
        fail(f"missing canonical artwork: {source.relative_to(ROOT)}")

    try:
        svg = gzip.decompress(source.read_bytes())
    except (OSError, EOFError) as error:
        fail(f"invalid SVGZ artwork {source.name}: {error}")

    try:
        root = ET.fromstring(svg)
    except ET.ParseError as error:
        fail(f"invalid SVG artwork {source.name}: {error}")

    if root.tag != f"{{{SVG_NS}}}svg":
        fail(f"unexpected root element in {source.name}")
    if root.get("viewBox") != EXPECTED_VIEWBOX:
        fail(f"unexpected viewBox in {source.name}: {root.get('viewBox')!r}")

    # Write the renderer-friendly mirror atomically. The SVGZ files remain the
    # only tracked masters; these SVGs are build products used by librsvg.
    temporary = destination.with_suffix(".svg.tmp")
    temporary.write_bytes(svg)
    temporary.replace(destination)
    return destination, root


def prepare_branding() -> None:
    full_path, full = _expand("nyla_app_icon")
    foreground_path, foreground = _expand("nyla_app_icon_foreground")

    full_children = list(full)
    foreground_children = list(foreground)
    if len(full_children) < 6 or len(foreground_children) < 2:
        fail("launcher artwork is unexpectedly incomplete")

    # The full native icon deliberately replaces the reference image's black
    # presentation corners with Nyla's warm canvas. Native launchers apply their
    # own rounded/squircle masks, so black pixels here would create a dark rim.
    canvas = full_children[1]
    if canvas.tag != f"{{{SVG_NS}}}rect" or canvas.get("fill", "").lower() != "#fef9f5":
        fail("full launcher artwork must begin with the warm #FEF9F5 canvas")

    # Android adaptive icons get only the character/orbit/lotus artwork on the
    # foreground layer. The platform supplies the background and outer mask.
    if any(child.tag == f"{{{SVG_NS}}}rect" for child in foreground_children[1:]):
        fail("adaptive foreground must remain transparent")

    print(
        "Nyla branding prepared: "
        f"{full_path.name}, {foreground_path.name}"
    )


if __name__ == "__main__":
    prepare_branding()
