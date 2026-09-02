#!/usr/bin/env python3
"""Process N-019 R11 ImageGen gatherables into native 24 px R2 sprites."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "artifacts/integration/n-019-demo-visual/farm-pasture-r11"
SOURCE = EVIDENCE / "source"
PROCESSED = EVIDENCE / "processed"
PREVIEWS = EVIDENCE / "previews-8x"
ASSETS = ROOT / "macos/CreekSprout/CreekSprout/Assets"

PALETTE = (
    (38, 54, 56),
    (85, 72, 74),
    (118, 82, 71),
    (79, 112, 112),
    (120, 134, 83),
    (150, 168, 95),
    (181, 138, 82),
    (197, 138, 89),
    (198, 110, 61),
    (240, 217, 173),
)

SPECS = (
    ("gather_moss_stone_r2", "gather-moss-stone-imagegen.png", (22, 18)),
    ("gather_reed_fiber_r2", "gather-reed-fiber-imagegen.png", (17, 22)),
)


def nearest_palette(red: int, green: int, blue: int) -> tuple[int, int, int]:
    return min(
        PALETTE,
        key=lambda colour: sum(
            (source - target) ** 2
            for source, target in zip((red, green, blue), colour)
        ),
    )


def fit_sprite(source: Image.Image, max_size: tuple[int, int]) -> Image.Image:
    rgba = source.convert("RGBA")
    # ImageGen can leave a low-alpha presentation glow. Only the opaque sprite
    # body is accepted; runtime art must have a hard, binary pixel silhouette.
    # Brightness is part of the mask because the generated glow can itself be
    # quite opaque while remaining close to black.
    hard_alpha = Image.new("L", rgba.size)
    hard_alpha.putdata([
        255 if alpha >= 48 and (red + green + blue) / 3 >= 58 else 0
        for red, green, blue, alpha in rgba.getdata()
    ])
    bbox = hard_alpha.getbbox()
    if bbox is None:
        raise ValueError("empty generated gatherable")
    subject = rgba.crop(bbox)
    subject.putalpha(hard_alpha.crop(bbox))
    if max_size == (17, 22):
        # The ImageGen reed source is intentionally tall. A proportionate
        # 24 px reduction collapses five stalks into one line, so widen only
        # this presentation sprite while keeping its height and bottom anchor.
        subject = subject.resize(max_size, Image.Resampling.LANCZOS)
    else:
        subject.thumbnail(max_size, Image.Resampling.LANCZOS)

    pixels: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in subject.getdata():
        if alpha < 96:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((*nearest_palette(red, green, blue), 255))
    subject.putdata(pixels)

    canvas = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    x = (24 - subject.width) // 2
    y = 23 - subject.height
    canvas.alpha_composite(subject, (x, y))
    return canvas


def validate_and_record(asset_id: str, image: Image.Image) -> dict[str, object]:
    pixels = list(image.getdata())
    alpha_values = sorted({pixel[3] for pixel in pixels})
    dirty_transparent_rgb = sum(
        1 for red, green, blue, alpha in pixels if alpha == 0 and (red or green or blue)
    )
    if alpha_values != [0, 255]:
        raise ValueError(f"{asset_id}: expected binary alpha, got {alpha_values}")
    if dirty_transparent_rgb:
        raise ValueError(f"{asset_id}: dirty transparent RGB")
    runtime = ASSETS / f"{asset_id}.png"
    return {
        "asset_id": asset_id,
        "native_size": [image.width, image.height],
        "alpha_values": alpha_values,
        "opaque_palette": sorted({
            "#%02X%02X%02X" % pixel[:3] for pixel in pixels if pixel[3]
        }),
        "dirty_transparent_rgb": dirty_transparent_rgb,
        "sha256": hashlib.sha256(runtime.read_bytes()).hexdigest(),
    }


def main() -> None:
    PROCESSED.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []
    for asset_id, source_name, max_size in SPECS:
        image = fit_sprite(Image.open(SOURCE / source_name), max_size)
        for destination in (PROCESSED / f"{asset_id}.png", ASSETS / f"{asset_id}.png"):
            image.save(destination, format="PNG", optimize=False)
        image.resize((192, 192), Image.Resampling.NEAREST).save(
            PREVIEWS / f"{asset_id}-8x.png", format="PNG", optimize=False
        )
        records.append(validate_and_record(asset_id, image))

    manifest = {
        "task": "N-019",
        "revision": "farm-pasture-r11",
        "source_mode": "built-in ImageGen edits processed to native pixel assets",
        "palette": ["#%02X%02X%02X" % colour for colour in PALETTE],
        "assets": records,
        "failures": [],
    }
    (EVIDENCE / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"PASS assets={len(records)} failures=0")


if __name__ == "__main__":
    main()
