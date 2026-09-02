#!/usr/bin/env python3
"""Build N-019 R14 depth, field, haystack, and irregular-bank runtime art."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = ROOT / "artifacts/integration/n-019-demo-visual/depth-layout-r14"
SOURCE = ARTIFACT / "source"
PROCESSED = ARTIFACT / "processed"
PREVIEWS = ARTIFACT / "previews-4x"
WORLD_LIFE = ROOT / "macos/CreekSprout/CreekSprout/Presentation/WorldLife"


def clean_transparent_rgb(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    clean = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    clean.alpha_composite(rgba)
    return clean


def crop_alpha(image: Image.Image, threshold: int = 8) -> Image.Image:
    rgba = image.convert("RGBA")
    bbox = rgba.getchannel("A").point(lambda value: 255 if value >= threshold else 0).getbbox()
    if bbox is None:
        raise ValueError("source contains no visible pixels")
    return rgba.crop(bbox)


def fit_on_canvas(image: Image.Image, size: tuple[int, int], padding: int = 2) -> Image.Image:
    inner = (size[0] - padding * 2, size[1] - padding * 2)
    fitted = ImageOps.contain(crop_alpha(image), inner, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(
        fitted,
        ((size[0] - fitted.width) // 2, size[1] - padding - fitted.height),
    )
    return clean_transparent_rgb(canvas)


def soften_alpha(image: Image.Image, radius: float = 0.35) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").filter(ImageFilter.GaussianBlur(radius=radius))
    rgba.putalpha(alpha)
    return clean_transparent_rgb(rgba)


def save_runtime(image: Image.Image, filename: str) -> dict[str, object]:
    image = clean_transparent_rgb(image)
    runtime = WORLD_LIFE / filename
    runtime.parent.mkdir(parents=True, exist_ok=True)
    PROCESSED.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    image.save(runtime, optimize=True)
    image.save(PROCESSED / filename, optimize=True)
    image.resize(
        (image.width * 4, image.height * 4),
        Image.Resampling.NEAREST,
    ).save(PREVIEWS / f"{Path(filename).stem}-4x.png", optimize=True)
    alpha = image.getchannel("A")
    alpha_values = sorted(set(alpha.getdata()))
    dirty = sum(
        1 for red, green, blue, value in image.getdata()
        if value == 0 and (red or green or blue)
    )
    return {
        "asset_id": Path(filename).stem,
        "native_size": list(image.size),
        "alpha_min": min(alpha_values),
        "alpha_max": max(alpha_values),
        "alpha_value_count": len(alpha_values),
        "dirty_transparent_rgb": dirty,
        "sha256": hashlib.sha256(runtime.read_bytes()).hexdigest(),
    }


def build_backdrops() -> list[dict[str, object]]:
    source = crop_alpha(Image.open(SOURCE / "deep-mountain-vista-imagegen.png"))
    records: list[dict[str, object]] = []
    for filename, size, saturation, brightness, sky_top, sky_low in [
        (
            "wl_backdrop_farm_vista_r3.png", (384, 168), 0.88, 0.92,
            (91, 126, 136), (174, 191, 174),
        ),
        (
            "wl_backdrop_market_vista_r3.png", (432, 168), 0.80, 0.86,
            (79, 111, 124), (158, 181, 176),
        ),
    ]:
        # A taller native canvas lets the mountains occupy the whole fixed
        # inaccessible rear stage. Buildings, actors, and fields render above it.
        fitted = ImageOps.fit(source, size, Image.Resampling.LANCZOS, centering=(0.5, 0.58))
        fitted = ImageEnhance.Color(fitted).enhance(saturation)
        fitted = ImageEnhance.Brightness(fitted).enhance(brightness)
        fitted = soften_alpha(fitted, 0.25)
        sky = Image.new("RGBA", size, (0, 0, 0, 0))
        sky_draw = ImageDraw.Draw(sky)
        for y in range(size[1]):
            ratio = y / max(1, size[1] - 1)
            color = tuple(round(sky_top[index] * (1 - ratio) + sky_low[index] * ratio)
                          for index in range(3))
            # The upper valley is opaque sky; the lower quarter fades away so
            # the mountain foothills, rather than a rectangle, meet the map.
            alpha = 255 if ratio <= 0.68 else round(255 * (1 - ratio) / 0.32)
            sky_draw.line((0, y, size[0], y), fill=color + (max(0, alpha),))
        result = Image.alpha_composite(sky, fitted)
        records.append(save_runtime(result, filename))
    return records


def build_scene_props() -> list[dict[str, object]]:
    sheet = Image.open(SOURCE / "meadow-sunflower-hay-imagegen.png").convert("RGBA")
    third = sheet.width // 3
    pieces = [
        sheet.crop((0, 0, third, sheet.height)),
        sheet.crop((third, 0, third * 2, sheet.height)),
        sheet.crop((third * 2, 0, sheet.width, sheet.height)),
    ]
    specs = [
        (pieces[0], (96, 48), "wl_flower_meadow_r1.png"),
        (pieces[1], (72, 48), "wl_sunflower_field_r1.png"),
        (pieces[2], (48, 48), "wl_haystack_r1.png"),
    ]
    records: list[dict[str, object]] = []
    for piece, size, filename in specs:
        result = fit_on_canvas(piece, size, padding=1)
        result = soften_alpha(result, 0.30)
        records.append(save_runtime(result, filename))
    return records


def bank_mask(orientation: str, variant: int, scale: int = 4) -> Image.Image:
    # Four deliberately different silhouettes prevent the long creek edge from
    # reading as a tiled rectangle. Curves are antialiased at 4x resolution.
    profiles = [
        [4, 5, 5, 7, 6, 9, 8, 6, 5],
        [5, 5, 8, 13, 16, 14, 8, 6, 5],
        [4, 6, 9, 12, 14, 15, 16, 12, 8],
        [10, 14, 13, 8, 5, 6, 10, 9, 5],
    ][variant]
    width = height = 24
    xs = [round(index * width / (len(profiles) - 1)) for index in range(len(profiles))]
    points = [(x * scale, y * scale) for x, y in zip(xs, profiles)]
    mask = Image.new("L", (width * scale, height * scale), 0)
    draw = ImageDraw.Draw(mask)
    if orientation == "north":
        polygon = [(0, 0), (width * scale, 0)] + list(reversed(points))
    else:
        mirrored = [(x, (height - y) * scale) for x, y in zip(xs, profiles)]
        polygon = [(0, height * scale), (width * scale, height * scale)] + list(reversed(mirrored))
    draw.polygon(polygon, fill=255)
    return mask.resize((width, height), Image.Resampling.LANCZOS)


def build_banks() -> list[dict[str, object]]:
    grass_path = ROOT / "macos/CreekSprout/CreekSprout/Presentation/DisplayR2/r3_tile_grass_a.png"
    grass = Image.open(grass_path).convert("RGBA").resize((24, 24), Image.Resampling.LANCZOS)
    records: list[dict[str, object]] = []
    for orientation in ("north", "south"):
        for variant in range(4):
            mask = bank_mask(orientation, variant)
            canvas = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
            grass_layer = grass.copy()
            grass_layer.putalpha(mask)
            canvas.alpha_composite(grass_layer)

            # A narrow earthen lip and soft water-side shadow make the bank read
            # as land over water instead of a hard pixel cutout.
            edge = mask.filter(ImageFilter.FIND_EDGES)
            soil = Image.new("RGBA", (24, 24), (104, 84, 58, 0))
            soil.putalpha(edge.point(lambda value: min(190, value)))
            canvas.alpha_composite(soil)
            shifted = Image.new("L", (24, 24), 0)
            offset = 2 if orientation == "north" else -2
            shifted.paste(edge, (0, offset))
            shadow = Image.new("RGBA", (24, 24), (13, 28, 32, 0))
            shadow.putalpha(shifted.filter(ImageFilter.GaussianBlur(1.0)).point(lambda value: value // 3))
            canvas = Image.alpha_composite(shadow, canvas)
            records.append(save_runtime(
                canvas,
                f"wl_bank_{orientation}_{variant + 1:02d}_r1.png",
            ))
    return records


def main() -> int:
    for directory in (PROCESSED, PREVIEWS, WORLD_LIFE):
        directory.mkdir(parents=True, exist_ok=True)
    records = build_backdrops() + build_scene_props() + build_banks()
    failures = [
        f"{record['asset_id']}: dirty transparent RGB"
        for record in records
        if record["dirty_transparent_rgb"] != 0
    ]
    manifest = {
        "task": "N-019",
        "revision": "depth-layout-r14",
        "source_mode": "built-in ImageGen sources plus deterministic shoreline processing",
        "design_intent": [
            "rear mountains fill the fixed inaccessible stage",
            "market and farm fields follow Product Owner landmark anchors",
            "water topology is unchanged while bank silhouettes become irregular",
            "soft alpha edges preserve painterly depth and contact-shadow integration",
        ],
        "assets": records,
        "failures": failures,
    }
    (ARTIFACT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"{'PASS' if not failures else 'FAIL'} assets={len(records)} failures={len(failures)}")
    for failure in failures:
        print(f"- {failure}")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
