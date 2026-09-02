#!/usr/bin/env python3
"""Convert N-019 R9 ImageGen atlases into native, versioned farm sprites."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "artifacts/integration/n-019-demo-visual/farm-coherence-r9"
SOURCE = EVIDENCE / "source"
PROCESSED = EVIDENCE / "processed"
PREVIEWS = EVIDENCE / "previews-8x"
ASSETS = ROOT / "macos/CreekSprout/CreekSprout/Assets"

PALETTE = (
    (0x26, 0x36, 0x38),
    (0x55, 0x48, 0x4A),
    (0x76, 0x52, 0x47),
    (0x78, 0x86, 0x53),
    (0x78, 0x97, 0xA0),
    (0x4F, 0x70, 0x70),
    (0xB5, 0x8A, 0x52),
    (0xC5, 0x8A, 0x59),
    (0xC6, 0x6E, 0x3D),
    (0xF0, 0xD9, 0xAD),
)

CROPS = ("mist_radish", "stream_leaf", "amber_bean", "bell_berry", "honey_melon")
PROPS = (
    ("gather_creek_wood_r2", (24, 24), (22, 19)),
    ("prop_compost_bin_r2", (48, 48), (44, 40)),
    ("prop_rain_barrel_r2", (24, 32), (22, 30)),
    ("prop_wooden_crate_r2", (24, 24), (22, 22)),
    ("prop_woodhoney_hearth_r2", (48, 48), (44, 42)),
)


def nearest_palette(red: int, green: int, blue: int) -> tuple[int, int, int]:
    return min(
        PALETTE,
        key=lambda color: sum((source - target) ** 2 for source, target in zip((red, green, blue), color)),
    )


def palette_and_alpha(image: Image.Image, threshold: int = 96) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = []
    for red, green, blue, alpha in rgba.getdata():
        if alpha < threshold:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((*nearest_palette(red, green, blue), 255))
    rgba.putdata(pixels)
    return rgba


def crop_grid_cell(image: Image.Image, columns: int, rows: int, column: int, row: int) -> Image.Image:
    left = round(column * image.width / columns)
    right = round((column + 1) * image.width / columns)
    top = round(row * image.height / rows)
    bottom = round((row + 1) * image.height / rows)
    return image.crop((left, top, right, bottom))


def fit_subject(source: Image.Image, canvas_size: tuple[int, int], max_size: tuple[int, int]) -> Image.Image:
    rgba = source.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 48 else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("empty atlas cell")
    subject = rgba.crop(bbox)
    scale = min(max_size[0] / subject.width, max_size[1] / subject.height)
    new_size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(new_size, Image.Resampling.LANCZOS)
    subject = palette_and_alpha(subject)
    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    x = (canvas_size[0] - subject.width) // 2
    y = canvas_size[1] - 2 - subject.height
    canvas.alpha_composite(subject, (x, y))
    return canvas


def save_asset(asset_id: str, image: Image.Image, records: list[dict[str, object]]) -> None:
    runtime = ASSETS / f"{asset_id}.png"
    processed = PROCESSED / f"{asset_id}.png"
    preview = PREVIEWS / f"{asset_id}-8x.png"
    image.save(runtime, format="PNG", optimize=False)
    image.save(processed, format="PNG", optimize=False)
    image.resize((image.width * 8, image.height * 8), Image.Resampling.NEAREST).save(
        preview, format="PNG", optimize=False
    )
    pixels = list(image.getdata())
    record = {
        "asset_id": asset_id,
        "native_size": [image.width, image.height],
        "alpha_values": sorted({pixel[3] for pixel in pixels}),
        "opaque_palette": sorted({"#%02X%02X%02X" % pixel[:3] for pixel in pixels if pixel[3]}),
        "dirty_transparent_rgb": sum(
            1 for red, green, blue, alpha in pixels if alpha == 0 and (red or green or blue)
        ),
        "sha256": hashlib.sha256(runtime.read_bytes()).hexdigest(),
    }
    if record["alpha_values"] not in ([255], [0, 255]):
        raise ValueError(f"{asset_id}: alpha is not binary")
    if record["dirty_transparent_rgb"] != 0:
        raise ValueError(f"{asset_id}: dirty transparent RGB")
    records.append(record)


def process_crops(records: list[dict[str, object]]) -> list[tuple[str, Image.Image]]:
    atlas = Image.open(SOURCE / "crop-growth-atlas-imagegen.png").convert("RGBA")
    images: list[tuple[str, Image.Image]] = []
    max_heights = (10, 16, 23, 28)
    for row, crop in enumerate(CROPS):
        for stage in range(4):
            cell = crop_grid_cell(atlas, columns=4, rows=5, column=stage, row=row)
            sprite = fit_subject(cell, (32, 32), (27, max_heights[stage]))
            asset_id = f"crop_{crop}_stage_{stage}_r3"
            save_asset(asset_id, sprite, records)
            images.append((asset_id, sprite))
    return images


def process_props(records: list[dict[str, object]]) -> list[tuple[str, Image.Image]]:
    atlas = Image.open(SOURCE / "farm-utility-atlas-imagegen.png").convert("RGBA")
    images: list[tuple[str, Image.Image]] = []
    for column, (asset_id, canvas_size, max_size) in enumerate(PROPS):
        cell = crop_grid_cell(atlas, columns=5, rows=1, column=column, row=0)
        sprite = fit_subject(cell, canvas_size, max_size)
        save_asset(asset_id, sprite, records)
        images.append((asset_id, sprite))
    return images


def process_soil(records: list[dict[str, object]]) -> list[tuple[str, Image.Image]]:
    atlas = Image.open(SOURCE / "tilled-soil-atlas-imagegen.png").convert("RGB")
    images: list[tuple[str, Image.Image]] = []
    for column, asset_id in enumerate(("tile_tilled_r2", "tile_tilled_watered_r2")):
        cell = crop_grid_cell(atlas, columns=2, rows=1, column=column, row=0)
        tile = cell.resize((24, 24), Image.Resampling.LANCZOS)
        tile = palette_and_alpha(tile, threshold=0)
        save_asset(asset_id, tile, records)
        images.append((asset_id, tile))
    return images


def contact_sheet(
    crops: list[tuple[str, Image.Image]],
    props: list[tuple[str, Image.Image]],
    soil: list[tuple[str, Image.Image]],
) -> None:
    scale = 8
    margin = 24
    crop_cell = 32 * scale
    sheet = Image.new("RGBA", (crop_cell * 4 + margin * 2, crop_cell * 7 + margin * 3), (38, 54, 56, 255))
    draw = ImageDraw.Draw(sheet)
    for index, (_, crop) in enumerate(crops):
        column = index % 4
        row = index // 4
        tile = soil[index % 2][1].resize((24 * scale, 24 * scale), Image.Resampling.NEAREST)
        x = margin + column * crop_cell
        y = margin + row * crop_cell
        sheet.alpha_composite(tile, (x + (crop_cell - tile.width) // 2, y + crop_cell - tile.height))
        sheet.alpha_composite(crop.resize((crop_cell, crop_cell), Image.Resampling.NEAREST), (x, y))
    prop_y = margin * 2 + crop_cell * 5
    for index, (_, prop) in enumerate(props):
        display = prop.resize((prop.width * 5, prop.height * 5), Image.Resampling.NEAREST)
        x = margin + index * ((crop_cell * 4) // 5) + (((crop_cell * 4) // 5) - display.width) // 2
        y = prop_y + (crop_cell * 2 - display.height) // 2
        sheet.alpha_composite(display, (x, y))
    draw.text((margin, sheet.height - 18), "N-019 R9 native crop stages and farm utility props", fill=(240, 217, 173, 255))
    sheet.save(EVIDENCE / "farm-coherence-r9-contact-8x.png", optimize=False)


def main() -> None:
    PROCESSED.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []
    soil = process_soil(records)
    crops = process_crops(records)
    props = process_props(records)
    contact_sheet(crops, props, soil)
    manifest = {
        "task": "N-019",
        "revision": "farm-coherence-r9",
        "source_mode": "built-in ImageGen atlases converted to native pixel assets",
        "palette": ["#%02X%02X%02X" % color for color in PALETTE],
        "assets": records,
        "failures": [],
    }
    (EVIDENCE / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"PASS assets={len(records)} crops={len(crops)} props={len(props)} soil={len(soil)}")


if __name__ == "__main__":
    main()
