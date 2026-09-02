#!/usr/bin/env python3
"""Build the compact N-019 R4 cat-shop landmark for the market entrance."""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "macos/CreekSprout/CreekSprout/Presentation/WorldLife/wl_cat_bbq_shop_r2.png"
RUNTIME = ROOT / "macos/CreekSprout/CreekSprout/Presentation/WorldLife/wl_cat_bbq_shop_r3.png"
EVIDENCE = ROOT / "artifacts/integration/n-019-demo-visual/market-entry-r4"

PALETTE = [
    (24, 47, 49),
    (37, 75, 75),
    (77, 100, 63),
    (113, 128, 79),
    (85, 72, 74),
    (118, 82, 71),
    (130, 88, 62),
    (197, 138, 89),
    (198, 110, 61),
    (120, 151, 160),
    (181, 138, 82),
    (240, 217, 173),
]


def nearest(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
    return min(PALETTE, key=lambda colour: sum((rgb[i] - colour[i]) ** 2 for i in range(3)))


def main() -> None:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    source = Image.open(SOURCE).convert("RGBA")
    alpha = source.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("cat-shop source has no opaque subject")
    subject = source.crop(bbox)
    scale = min(70 / subject.width, 70 / subject.height)
    size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(size, Image.Resampling.LANCZOS)
    subject.putalpha(subject.getchannel("A").point(lambda value: 255 if value >= 112 else 0))

    pixels = []
    for red, green, blue, value in subject.getdata():
        if value == 0:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((*nearest((red, green, blue)), 255))
    subject.putdata(pixels)

    canvas = Image.new("RGBA", (72, 72), (0, 0, 0, 0))
    canvas.alpha_composite(subject, ((72 - subject.width) // 2, 71 - subject.height))
    canvas.save(RUNTIME, optimize=False)
    shutil.copy2(RUNTIME, EVIDENCE / RUNTIME.name)
    canvas.resize((576, 576), Image.Resampling.NEAREST).save(
        EVIDENCE / "wl_cat_bbq_shop_r3-8x.png",
        optimize=False,
    )

    alpha = canvas.getchannel("A")
    manifest = {
        "asset": RUNTIME.name,
        "source": str(SOURCE.relative_to(ROOT)),
        "runtime": str(RUNTIME.relative_to(ROOT)),
        "size": list(canvas.size),
        "bbox": list(alpha.getbbox()) if alpha.getbbox() else None,
        "alpha_values": sorted(set(alpha.getdata())),
        "opaque_colours": len(set(pixel[:3] for pixel in canvas.getdata() if pixel[3] == 255)),
        "sha256": hashlib.sha256(RUNTIME.read_bytes()).hexdigest(),
        "purpose": "three-cell entrance landmark; preserve a clear market arrival corridor",
    }
    (EVIDENCE / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print("PASS asset=1 failures=0")


if __name__ == "__main__":
    main()
