#!/usr/bin/env python3
"""Rebuild the deeper N-019 R21 scenic-lake animation deterministically."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = ROOT / "artifacts/integration/n-019-demo-visual/visual-feedback-r21"
PROCESSED = ARTIFACT / "processed"
PREVIEWS = ARTIFACT / "previews-6x"
WORLD_LIFE = ROOT / "macos/CreekSprout/CreekSprout/Presentation/WorldLife"
WATER_FRAMES = [
    ROOT / f"macos/CreekSprout/CreekSprout/Presentation/DisplayR2/r4_tile_water_f{index:02d}.png"
    for index in range(4)
]

LOCKED_PALETTE = [
    "#263638", "#55484A", "#765247", "#788653", "#7897A0",
    "#4F7070", "#B58A52", "#C58A59", "#C66E3D", "#F0D9AD",
]


def rgb(value: str) -> tuple[int, int, int]:
    value = value.removeprefix("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def palette_image(colors: list[str]) -> Image.Image:
    image = Image.new("P", (1, 1))
    values: list[int] = []
    for color in colors:
        values.extend(rgb(color))
    fallback = list(rgb(colors[0]))
    for _ in range(256 - len(colors)):
        values.extend(fallback)
    image.putpalette(values)
    return image


def clean(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 96 else 0)
    rgba.putalpha(alpha)
    result = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    result.paste(rgba, mask=alpha)
    return result


def quantize(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 96 else 0)
    indexed = rgba.convert("RGB").quantize(
        palette=palette_image(LOCKED_PALETTE),
        dither=Image.Dither.NONE,
    )
    result = indexed.convert("RGBA")
    result.putalpha(alpha)
    return clean(result)


def lake_mask() -> Image.Image:
    """Return a redrawn 6×4-tile bank, not a resized R20 mask.

    The extra row is distributed through new north coves, broad middle water,
    and a deeper stepped south bank. The centre-south notch remains as a visual
    link to the approved R20 silhouette.
    """
    mask = Image.new("L", (144, 96), 0)
    draw = ImageDraw.Draw(mask)
    draw.polygon(
        [
            (20, 5), (31, 1), (49, 4), (63, 1), (80, 5), (94, 2),
            (110, 5), (130, 2), (142, 9), (140, 24), (143, 39),
            (140, 55), (143, 73), (139, 89), (130, 94), (111, 91),
            (104, 94), (98, 90), (96, 78), (92, 70), (84, 67),
            (77, 70), (73, 78), (72, 91), (65, 95), (48, 92),
            (38, 95), (28, 90), (26, 78), (20, 73), (7, 76),
            (1, 69), (4, 54), (1, 42), (6, 30), (19, 28), (24, 20),
        ],
        fill=255,
    )
    # Small stepped bites keep both long banks organic at native scale.
    for box in [(42, 0, 47, 5), (97, 0, 103, 5), (0, 48, 5, 57), (136, 48, 143, 58)]:
        draw.rectangle(box, fill=0)
    return mask


def lake_frame(frame_index: int) -> Image.Image:
    mask = lake_mask()
    canvas = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    # Re-tile the approved moving-water frames across a new 6×4 area. No R20
    # pixel is stretched; the extra depth receives genuine animated water.
    for row in range(4):
        for column in range(6):
            source_index = (frame_index + column * 2 + row) % len(WATER_FRAMES)
            tile = Image.open(WATER_FRAMES[source_index]).convert("RGBA")
            canvas.alpha_composite(tile, (column * 24, row * 24))
    canvas.putalpha(mask)

    pixels = canvas.load()
    mask_pixels = mask.load()
    width, height = mask.size
    light_bank = rgb("#788653")
    light_glint = rgb("#B58A52")
    dark_bank = rgb("#55484A")
    deep_shadow = rgb("#263638")

    def visible(x: int, y: int) -> bool:
        return 0 <= x < width and 0 <= y < height and mask_pixels[x, y] > 0

    for y in range(height):
        for x in range(width):
            if not visible(x, y):
                continue
            north_or_west = not visible(x, y - 1) or not visible(x - 1, y)
            south_or_east = not visible(x, y + 1) or not visible(x + 1, y)
            if north_or_west:
                pixels[x, y] = (
                    light_glint if (x + y) % 13 < 3 else light_bank
                ) + (255,)
            elif south_or_east:
                pixels[x, y] = (
                    deep_shadow if (x * 3 + y) % 9 < 3 else dark_bank
                ) + (255,)

    draw = ImageDraw.Draw(canvas)
    for x, y in [(24, 8), (67, 4), (116, 7), (138, 51), (31, 88), (107, 89)]:
        draw.rectangle((x, y, x + 2, y + 1), fill=dark_bank + (255,))
        draw.point((x, y), fill=light_bank + (255,))
    canvas.putalpha(mask)
    return quantize(canvas)


def save_asset(image: Image.Image, filename: str) -> dict[str, object]:
    PROCESSED.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    WORLD_LIFE.mkdir(parents=True, exist_ok=True)
    runtime_path = WORLD_LIFE / filename
    processed_path = PROCESSED / filename
    image.save(runtime_path, optimize=True)
    image.save(processed_path, optimize=True)
    image.resize(
        (image.width * 6, image.height * 6),
        Image.Resampling.NEAREST,
    ).save(PREVIEWS / f"{Path(filename).stem}-6x.png", optimize=True)

    alpha_values = sorted(set(image.getchannel("A").getdata()))
    used_rgb = sorted({pixel[:3] for pixel in image.getdata() if pixel[3]})
    dirty = sum(
        1 for red, green, blue, alpha in image.getdata()
        if alpha == 0 and (red or green or blue)
    )
    return {
        "asset_id": Path(filename).stem,
        "native_size": list(image.size),
        "alpha_values": alpha_values,
        "dirty_transparent_rgb": dirty,
        "used_rgb": ["#%02X%02X%02X" % color for color in used_rgb],
        "sha256": hashlib.sha256(runtime_path.read_bytes()).hexdigest(),
    }


def main() -> int:
    records = [
        save_asset(lake_frame(index), f"wl_market_scenic_lake_f{index:02d}_r1.png")
        for index in range(4)
    ]
    allowed = {value.upper() for value in LOCKED_PALETTE}
    failures: list[str] = []
    for record in records:
        if record["native_size"] != [144, 96]:
            failures.append(f"{record['asset_id']}: expected 144x96")
        if record["alpha_values"] != [0, 255]:
            failures.append(f"{record['asset_id']}: alpha is not binary")
        if record["dirty_transparent_rgb"] != 0:
            failures.append(f"{record['asset_id']}: dirty transparent RGB")
        unexpected = set(record["used_rgb"]) - allowed
        if unexpected:
            failures.append(f"{record['asset_id']}: colors outside locked palette")

    manifest = {
        "task": "N-019",
        "revision": "visual-feedback-r21",
        "source_mode": (
            "built-in ImageGen edit used as shoreline-shape reference; "
            "runtime frames rebuilt deterministically from approved water tiles"
        ),
        "imagegen_reference": "source/lake-thickness-shape-reference-imagegen.png",
        "style_contract": {
            "tile_grid": "24x24",
            "filtering": "nearest",
            "runtime_scaling": "integer only",
            "alpha": "binary",
            "palette": LOCKED_PALETTE,
            "not_a_scaled_r20_mask": True,
        },
        "assets": records,
        "status": "PASS" if not failures else "FAIL",
        "failures": failures,
    }
    ARTIFACT.mkdir(parents=True, exist_ok=True)
    (ARTIFACT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(manifest, ensure_ascii=False, indent=2))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
