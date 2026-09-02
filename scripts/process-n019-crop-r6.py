#!/usr/bin/env python3
"""Convert approved N-019 R6 ImageGen sources into native runtime sprites.

The source images are intentionally archived outside runtime Assets. This script
normalizes alpha, fits every mature plant to the same visual footprint, limits
the palette, and writes versioned R2 sprites without touching the original
N-006 files. It also replaces the mislabeled market-wharf garden silhouette
with a compact, actual stone-and-timber sluice while preserving the original
six-layer B4 files as fallback evidence.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "artifacts/integration/n-019-demo-visual/crop-sluice-r6"
SOURCE = EVIDENCE / "source"
OUTPUT = ROOT / "macos/CreekSprout/CreekSprout/Assets"
PROCESSED = EVIDENCE / "processed"

SOURCES = {
    "crop_mist_radish_stage_3_r2": "mist-radish-imagegen.png",
    "crop_stream_leaf_stage_3_r2": "stream-leaf-imagegen.png",
    "crop_amber_bean_stage_3_r2": "amber-bean-imagegen.png",
    "crop_bell_berry_stage_3_r2": "bell-berry-imagegen.png",
    "crop_honey_melon_stage_3_r2": "honey-melon-imagegen.png",
}

WHARF_SOURCE = "market-wharf-r2-imagegen.png"
WHARF_ASSET_ID = "building_market_wharf_r2"


def normalize(source: Path) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A").point(lambda value: 255 if value >= 32 else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError(f"empty alpha: {source}")
    subject = image.crop(bbox)

    # All five plants share one compact footprint. The two-pixel bottom margin
    # keeps roots visually planted without touching the neighbouring tile.
    max_width, max_height = 22, 24
    scale = min(max_width / subject.width, max_height / subject.height)
    size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(size, Image.Resampling.LANCZOS)
    subject = subject.quantize(colors=12, method=Image.Quantize.FASTOCTREE).convert("RGBA")
    subject.putalpha(subject.getchannel("A").point(lambda value: 255 if value >= 104 else 0))

    canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    x = (32 - subject.width) // 2
    y = 30 - subject.height
    canvas.alpha_composite(subject, (x, y))
    return canvas


def make_contact_sheet(images: list[tuple[str, Image.Image]]) -> Image.Image:
    soil = Image.open(OUTPUT / "tile_tilled_watered.png").convert("RGBA")
    scale = 6
    cell = 32 * scale
    sheet = Image.new("RGBA", (cell * len(images), cell), (74, 91, 58, 255))
    for index, (_, sprite) in enumerate(images):
        tile = soil.resize((24 * scale, 24 * scale), Image.Resampling.NEAREST)
        sprite_large = sprite.resize((cell, cell), Image.Resampling.NEAREST)
        tile_x = index * cell + (cell - tile.width) // 2
        tile_y = cell - tile.height
        sheet.alpha_composite(tile, (tile_x, tile_y))
        sheet.alpha_composite(sprite_large, (index * cell, 0))
    return sheet


def normalize_wharf(source: Path) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A").point(lambda value: 255 if value >= 32 else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError(f"empty alpha: {source}")
    subject = image.crop(bbox)

    # Keep the replacement within the original 144x96 B4 canvas but reduce its
    # visible mass. The bottom-centred channel remains aligned with the two
    # presentation-only canal cells that continue into the creek.
    max_width, max_height = 124, 84
    scale = min(max_width / subject.width, max_height / subject.height)
    size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(size, Image.Resampling.LANCZOS)
    subject = subject.quantize(colors=24, method=Image.Quantize.FASTOCTREE).convert("RGBA")
    subject.putalpha(subject.getchannel("A").point(lambda value: 255 if value >= 104 else 0))

    canvas = Image.new("RGBA", (144, 96), (0, 0, 0, 0))
    canvas.alpha_composite(subject, ((144 - subject.width) // 2, 96 - subject.height))
    return canvas


def main() -> None:
    PROCESSED.mkdir(parents=True, exist_ok=True)
    rendered: list[tuple[str, Image.Image]] = []
    for asset_id, filename in SOURCES.items():
        sprite = normalize(SOURCE / filename)
        runtime_path = OUTPUT / f"{asset_id}.png"
        evidence_path = PROCESSED / f"{asset_id}.png"
        sprite.save(runtime_path, format="PNG", optimize=True, dpi=(72, 72))
        sprite.save(evidence_path, format="PNG", optimize=True, dpi=(72, 72))
        rendered.append((asset_id, sprite))

    contact = make_contact_sheet(rendered)
    contact.save(PROCESSED / "crop-r6-soil-contact-6x.png", format="PNG", optimize=True)

    wharf = normalize_wharf(SOURCE / WHARF_SOURCE)
    wharf.save(OUTPUT / f"{WHARF_ASSET_ID}.png", format="PNG", optimize=True, dpi=(72, 72))
    wharf.save(PROCESSED / f"{WHARF_ASSET_ID}.png", format="PNG", optimize=True, dpi=(72, 72))
    wharf.resize((576, 384), Image.Resampling.NEAREST).save(
        PROCESSED / "market-wharf-r2-4x.png",
        format="PNG",
        optimize=True,
    )
    print(
        f"PASS crops={len(rendered)} size=32x32 alpha=binary palette<=12 "
        "wharf=144x96 alpha=binary palette<=24"
    )


if __name__ == "__main__":
    main()
