#!/usr/bin/env python3
"""Generate the approved 48x48 Woodhoney Hearth runtime sprite.

The imagegen concept is a silhouette/material reference only. This script is
the reproducible source of truth for the native pixel asset: RGBA8, locked
palette, transparent background, no resampling.
"""

from __future__ import annotations

import hashlib
import json
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "macos/CreekSprout/CreekSprout/Assets/prop_woodhoney_hearth.png"
EVIDENCE = ROOT / "artifacts/integration/n-015-foundation/woodhoney-hearth.json"
PREVIEW = ROOT / "artifacts/integration/n-015-foundation/woodhoney-hearth-nearest-8x.png"

P = {
    "clear": (0, 0, 0, 0),
    "ink": (0x26, 0x38, 0x45, 255),
    "mist": (0x7E, 0x9E, 0xB0, 255),
    "creek": (0x4F, 0x7F, 0x78, 255),
    "stone": (0x66, 0x53, 0x4A, 255),
    "moss": (0x70, 0x8A, 0x58, 255),
    "straw": (0xB5, 0x8A, 0x52, 255),
    "honey": (0xC5, 0x8A, 0x59, 255),
    "copper": (0xC6, 0x6E, 0x3D, 255),
    "paper": (0xF0, 0xD9, 0xAD, 255),
}


class Canvas:
    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        self.pixels = [P["clear"]] * (width * height)

    def set(self, x: int, y: int, color):
        if 0 <= x < self.width and 0 <= y < self.height:
            self.pixels[y * self.width + x] = color

    def rect(self, x: int, y: int, width: int, height: int, color):
        for yy in range(max(0, y), min(self.height, y + height)):
            for xx in range(max(0, x), min(self.width, x + width)):
                self.set(xx, yy, color)

    def ellipse(self, cx: int, cy: int, rx: int, ry: int, color):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if ((x - cx) ** 2) * ry * ry + ((y - cy) ** 2) * rx * rx <= rx * rx * ry * ry:
                    self.set(x, y, color)

    def poly(self, points, color):
        for y in range(max(0, min(p[1] for p in points)), min(self.height - 1, max(p[1] for p in points)) + 1):
            crossings = []
            for index, (x1, y1) in enumerate(points):
                x2, y2 = points[(index + 1) % len(points)]
                if y1 != y2 and min(y1, y2) <= y < max(y1, y2):
                    crossings.append(x1 + (y - y1) * (x2 - x1) / (y2 - y1))
            crossings.sort()
            for index in range(0, len(crossings) - 1, 2):
                start = math.ceil(crossings[index])
                end = math.floor(crossings[index + 1])
                self.rect(start, y, end - start + 1, 1, color)


def draw() -> Canvas:
    image = Canvas(48, 48)

    # Grounded, asymmetrical silhouette: low prep wing + tall copper flue.
    image.rect(4, 40, 39, 5, P["ink"])
    image.rect(7, 38, 35, 6, P["stone"])
    image.rect(3, 27, 13, 15, P["ink"])
    image.rect(5, 29, 11, 11, P["honey"])
    image.rect(4, 25, 16, 4, P["ink"])
    image.rect(5, 25, 14, 2, P["straw"])

    # Main damp-stone firebox.
    image.poly([(15, 19), (35, 19), (41, 26), (41, 41), (12, 41), (12, 27)], P["ink"])
    image.poly([(17, 21), (33, 21), (38, 27), (38, 39), (15, 39), (15, 28)], P["stone"])
    image.rect(16, 24, 7, 4, P["mist"])
    image.rect(30, 23, 6, 4, P["creek"])
    image.rect(15, 34, 6, 4, P["moss"])
    image.rect(32, 35, 6, 3, P["moss"])
    image.rect(22, 21, 7, 3, P["honey"])

    # Oven mouth and ember readability at 1x.
    image.ellipse(27, 34, 10, 8, P["ink"])
    image.rect(17, 34, 20, 8, P["ink"])
    image.ellipse(27, 35, 7, 5, P["copper"])
    image.rect(20, 35, 15, 7, P["copper"])
    image.ellipse(27, 36, 5, 3, P["honey"])
    image.rect(22, 36, 11, 5, P["honey"])
    image.rect(24, 38, 7, 3, P["paper"])
    image.rect(19, 41, 18, 2, P["ink"])

    # Copper cooking rim.
    image.ellipse(27, 22, 10, 4, P["ink"])
    image.ellipse(27, 22, 8, 3, P["copper"])
    image.ellipse(27, 21, 6, 2, P["stone"])
    image.rect(20, 22, 15, 2, P["copper"])

    # Short, crooked flue with cool rim so it does not read as a generic oven.
    image.rect(33, 8, 8, 15, P["ink"])
    image.rect(35, 9, 5, 13, P["copper"])
    image.rect(36, 10, 2, 10, P["honey"])
    image.rect(32, 7, 10, 3, P["ink"])
    image.rect(33, 6, 8, 2, P["copper"])
    image.rect(39, 10, 2, 10, P["mist"])

    # Original creek-wave inlay on the wooden prep wing.
    image.rect(6, 32, 8, 5, P["creek"])
    image.rect(7, 31, 3, 2, P["creek"])
    image.rect(10, 34, 4, 2, P["honey"])
    image.rect(6, 37, 9, 2, P["copper"])

    # Two clear feet keep the bottom-center anchor unambiguous.
    image.rect(7, 43, 7, 3, P["ink"])
    image.rect(34, 43, 7, 3, P["ink"])
    image.rect(8, 43, 5, 2, P["honey"])
    image.rect(35, 43, 5, 2, P["honey"])
    return image


def png_bytes(image: Canvas) -> bytes:
    raw = bytearray()
    for y in range(image.height):
        raw.append(0)
        for rgba in image.pixels[y * image.width:(y + 1) * image.width]:
            raw.extend(rgba)

    def chunk(kind: bytes, payload: bytes) -> bytes:
        crc = zlib.crc32(kind + payload) & 0xFFFFFFFF
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", crc)

    header = struct.pack(">IIBBBBB", image.width, image.height, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")


def nearest_preview(source: Canvas, factor: int) -> Canvas:
    preview = Canvas(source.width * factor, source.height * factor)
    for y in range(source.height):
        for x in range(source.width):
            color = source.pixels[y * source.width + x]
            preview.rect(x * factor, y * factor, factor, factor, color)
    return preview


def main() -> None:
    image = draw()
    used = set(image.pixels)
    assert used <= set(P.values()), "sprite contains colors outside the locked palette"
    assert P["clear"] in used and any(color[3] == 255 for color in used)
    data = png_bytes(image)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(data)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    PREVIEW.write_bytes(png_bytes(nearest_preview(image, 8)))
    report = {
        "asset": OUTPUT.name,
        "native_size": [48, 48],
        "format": "RGBA8",
        "anchor": "bottom-center",
        "palette": sorted("#%02X%02X%02X" % color[:3] for color in used if color[3]),
        "sha256": hashlib.sha256(data).hexdigest(),
        "concept_reference": "artifacts/po-art/n015-woodhoney-hearth-concept.png",
        "production_source": "scripts/generate-n015-woodhoney-hearth.py",
        "nearest_preview": "artifacts/integration/n-015-foundation/woodhoney-hearth-nearest-8x.png",
    }
    EVIDENCE.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
