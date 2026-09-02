#!/usr/bin/env python3
"""Build the N-019 R20 greenhouse and dining-set runtime pixel assets."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = ROOT / "artifacts/integration/n-019-demo-visual/farm-amenities-lake-r20"
SOURCE = ARTIFACT / "source"
PROCESSED = ARTIFACT / "processed"
PREVIEWS = ARTIFACT / "previews-6x"
WORLD_LIFE = ROOT / "macos/CreekSprout/CreekSprout/Presentation/WorldLife"
WATER_FRAMES = [
    ROOT / f"macos/CreekSprout/CreekSprout/Presentation/DisplayR2/r4_tile_water_f{index:02d}.png"
    for index in range(4)
]

LOCKED_PALETTE = [
    "#263638",  # deep ink
    "#55484A",  # wet stone
    "#765247",  # chestnut shadow
    "#788653",  # moss green
    "#7897A0",  # mist blue
    "#4F7070",  # river teal
    "#B58A52",  # straw gold
    "#C58A59",  # wood honey
    "#C66E3D",  # copper orange
    "#F0D9AD",  # paper cream
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


def clean(image: Image.Image, alpha_threshold: int = 96) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(
        lambda value: 255 if value >= alpha_threshold else 0
    )
    rgba.putalpha(alpha)
    result = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    result.paste(rgba, mask=alpha)
    return result


def remove_generated_checker(image: Image.Image) -> Image.Image:
    """Remove ImageGen's near-neutral white checker without eating cream ink."""
    rgba = image.convert("RGBA")
    pixels: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in rgba.getdata():
        chroma = max(red, green, blue) - min(red, green, blue)
        if min(red, green, blue) >= 226 and chroma <= 12:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((red, green, blue, alpha))
    rgba.putdata(pixels)
    return clean(rgba, 64)


def crop_alpha(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("generated source contains no visible pixels")
    return image.crop(bbox)


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


def native_sprite(
    source_name: str,
    native_size: tuple[int, int],
    *,
    horizontal_fill: bool,
) -> Image.Image:
    source = crop_alpha(remove_generated_checker(Image.open(SOURCE / source_name)))
    if horizontal_fill:
        # The PO's greenhouse box is a low, side-facing 5x3-tile silhouette.
        # Stretching the already pixel-authored side elevation before palette
        # locking keeps that footprint legible without importing HD detail.
        fitted = source.resize(native_size, Image.Resampling.NEAREST)
    else:
        ratio = min(native_size[0] / source.width, native_size[1] / source.height)
        fitted_size = (
            max(1, round(source.width * ratio)),
            max(1, round(source.height * ratio)),
        )
        fitted = source.resize(fitted_size, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", native_size, (0, 0, 0, 0))
    canvas.alpha_composite(
        fitted,
        ((native_size[0] - fitted.width) // 2, native_size[1] - fitted.height),
    )
    return quantize(canvas)


def lake_mask() -> Image.Image:
    """Six-by-three cell mask: north .XXXXX / middle XXXXXX / south .XX.XX."""
    mask = Image.new("L", (144, 72), 0)
    draw = ImageDraw.Draw(mask)
    # Integer-stepped banks deliberately break the tile rectangle while the
    # deep notch at the south centre keeps the PO's irregular lake silhouette.
    draw.polygon(
        [
            (26, 2), (38, 0), (61, 3), (83, 1), (106, 4), (128, 2), (143, 7),
            (141, 22), (143, 37), (140, 52), (143, 68), (137, 71),
            (99, 69), (96, 65), (98, 50), (92, 47), (76, 49), (72, 54),
            (71, 69), (66, 71), (29, 69), (24, 64), (26, 51), (21, 47),
            (5, 49), (1, 43), (3, 29), (9, 25), (21, 26), (24, 20),
        ],
        fill=255,
    )
    return mask


def lake_frame(frame_index: int) -> Image.Image:
    mask = lake_mask()
    canvas = Image.new("RGBA", mask.size, (0, 0, 0, 0))
    for row in range(3):
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

    # Fixed bank stones stay still while the water highlights move beneath.
    draw = ImageDraw.Draw(canvas)
    for x, y in [(28, 7), (91, 4), (136, 37), (48, 66), (109, 67)]:
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
        1
        for red, green, blue, alpha in image.getdata()
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
        save_asset(
            native_sprite(
                "greenhouse-wide-imagegen.png",
                (144, 48),
                horizontal_fill=True,
            ),
            "wl_market_greenhouse_r1.png",
        ),
        save_asset(
            native_sprite(
                "dining-set-imagegen.png",
                (96, 48),
                horizontal_fill=True,
            ),
            "wl_farm_dining_set_r1.png",
        ),
    ] + [
        save_asset(
            lake_frame(index),
            f"wl_market_scenic_lake_f{index:02d}_r1.png",
        )
        for index in range(4)
    ]

    allowed = {value.upper() for value in LOCKED_PALETTE}
    failures: list[str] = []
    for record in records:
        if record["alpha_values"] != [0, 255]:
            failures.append(f"{record['asset_id']}: alpha is not binary")
        if record["dirty_transparent_rgb"] != 0:
            failures.append(f"{record['asset_id']}: dirty transparent RGB")
        unexpected = set(record["used_rgb"]) - allowed
        if unexpected:
            failures.append(
                f"{record['asset_id']}: colors outside locked palette {sorted(unexpected)}"
            )

    manifest = {
        "task": "N-019",
        "revision": "farm-amenities-lake-r20",
        "source_mode": "built-in ImageGen sources reduced to project-native pixel assets",
        "style_contract": {
            "tile_grid": "24x24",
            "filtering": "nearest",
            "runtime_scaling": "integer only",
            "alpha": "binary",
            "palette": LOCKED_PALETTE,
            "generated_assets_are_presentation_only": True,
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
