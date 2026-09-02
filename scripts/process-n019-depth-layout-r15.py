#!/usr/bin/env python3
"""Build N-019 R15 pixel-matched depth layers and strict-layout props."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = ROOT / "artifacts/integration/n-019-demo-visual/depth-layout-r15"
SOURCE = ARTIFACT / "source"
PROCESSED = ARTIFACT / "processed"
PREVIEWS = ARTIFACT / "previews-4x"
WORLD_LIFE = ROOT / "macos/CreekSprout/CreekSprout/Presentation/WorldLife"

FAR_PALETTE = [
    "#263D3D", "#355050", "#48605B", "#5C7066", "#718276", "#879688",
    "#9EAA9A", "#B8C2AE", "#D4D2B0", "#4B6870", "#60808A", "#7897A0",
    "#91AEB4", "#AFC4C2", "#CBD6C7", "#E3DFC0",
]
MID_PALETTE = [
    "#173B3A", "#214B43", "#2E5A49", "#3D6A50", "#527958", "#698A60",
    "#839C6B", "#A2AE79", "#394846", "#505A55", "#68675C", "#807763",
    "#9C8E70", "#B6A47D", "#CFC097", "#DCD1AA",
]
PROP_PALETTE = [
    "#162E2E", "#234239", "#31513E", "#466143", "#5E7449", "#788950",
    "#96A45E", "#B4BA75", "#D4CD92", "#EFE1AD", "#5B4032", "#76503A",
    "#916044", "#B2754A", "#D08A4D", "#EDA54E", "#F2C45A", "#FFE18A",
    "#74577A", "#9A6D92", "#C487A9", "#E1A2BB", "#D9D8C0", "#F3EED2",
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
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= alpha_threshold else 0)
    rgba.putalpha(alpha)
    result = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    result.paste(rgba, mask=alpha)
    return result


def remove_checker(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = []
    for red, green, blue, alpha in rgba.getdata():
        chroma = max(red, green, blue) - min(red, green, blue)
        if min(red, green, blue) >= 226 and chroma <= 12:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((red, green, blue, alpha))
    rgba.putdata(pixels)
    return clean(rgba, 64)


def crop_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("source contains no visible pixels")
    return rgba.crop(bbox)


def quantize(image: Image.Image, colors: list[str], binary_alpha: bool = True) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    indexed = rgba.convert("RGB").quantize(
        palette=palette_image(colors),
        dither=Image.Dither.NONE,
    )
    result = indexed.convert("RGBA")
    if binary_alpha:
        alpha = alpha.point(lambda value: 255 if value >= 96 else 0)
    result.putalpha(alpha)
    return clean(result, 1 if not binary_alpha else 96)


def pixel_fit(
    image: Image.Image,
    size: tuple[int, int],
    colors: list[str],
    contain: bool = False,
    padding: int = 0,
) -> Image.Image:
    inner = (size[0] - padding * 2, size[1] - padding * 2)
    source = crop_alpha(image)
    if contain:
        fitted = ImageOps.contain(source, inner, Image.Resampling.NEAREST)
    else:
        fitted = ImageOps.fit(source, inner, Image.Resampling.NEAREST, centering=(0.5, 0.62))
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(
        fitted,
        ((size[0] - fitted.width) // 2, size[1] - padding - fitted.height),
    )
    return quantize(canvas, colors)


def save_runtime(image: Image.Image, filename: str) -> dict[str, object]:
    image = clean(image)
    runtime = WORLD_LIFE / filename
    runtime.parent.mkdir(parents=True, exist_ok=True)
    PROCESSED.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)
    image.save(runtime, optimize=True)
    image.save(PROCESSED / filename, optimize=True)
    image.resize((image.width * 4, image.height * 4), Image.Resampling.NEAREST).save(
        PREVIEWS / f"{Path(filename).stem}-4x.png",
        optimize=True,
    )
    alpha = image.getchannel("A")
    alpha_values = sorted(set(alpha.getdata()))
    dirty = sum(
        1 for red, green, blue, value in image.getdata()
        if value == 0 and (red or green or blue)
    )
    return {
        "asset_id": Path(filename).stem,
        "native_size": list(image.size),
        "alpha_values": alpha_values,
        "dirty_transparent_rgb": dirty,
        "sha256": hashlib.sha256(runtime.read_bytes()).hexdigest(),
    }


def build_depth_layers() -> list[dict[str, object]]:
    # The corrected far plate is a continuous 3/4 top-down mountain forest,
    # not a side-view sky strip. It provides actual land beneath the PO's
    # unreachable rear fields while filling the full game-width backdrop.
    far_source = Image.open(SOURCE / "topdown-mountain-forest-imagegen.png").convert("RGBA")
    far_source.putalpha(255)

    mid_source = remove_checker(Image.open(SOURCE / "mid-forest-imagegen.png"))
    near_source = clean(Image.open(SOURCE / "near-ridge-imagegen.png"), 64)

    records: list[dict[str, object]] = []
    for prefix, width, saturation, brightness in [
        ("farm", 384, 0.90, 0.92),
        ("market", 432, 0.78, 0.86),
    ]:
        far = ImageEnhance.Color(far_source).enhance(saturation)
        far = ImageEnhance.Brightness(far).enhance(brightness)
        far = ImageOps.fit(far, (width // 2, 84), Image.Resampling.BOX, centering=(0.5, 0.48))
        far = far.resize((width, 168), Image.Resampling.NEAREST)
        far = quantize(far, FAR_PALETTE)
        records.append(save_runtime(far, f"wl_backdrop_{prefix}_far_r4.png"))

        mid = ImageEnhance.Color(mid_source).enhance(saturation)
        mid = ImageEnhance.Brightness(mid).enhance(brightness)
        mid = pixel_fit(mid, (width // 2, 60), MID_PALETTE)
        mid = mid.resize((width, 120), Image.Resampling.NEAREST)
        records.append(save_runtime(mid, f"wl_backdrop_{prefix}_mid_r4.png"))

        near = ImageEnhance.Color(near_source).enhance(saturation)
        near = ImageEnhance.Brightness(near).enhance(brightness)
        near = pixel_fit(near, (width // 2, 36), MID_PALETTE)
        if prefix == "farm":
            # The farm sketch places an unreachable fenced plot at the rear
            # centre. Fill the source's central valley with a second offset
            # ridge silhouette so that plot has a visible mountain terrace.
            # Market keeps the open saddle around its north landmark axis.
            filled = Image.new("RGBA", near.size, (0, 0, 0, 0))
            filled.alpha_composite(ImageChops.offset(near, near.width // 4, 0))
            filled.alpha_composite(near)
            near = quantize(filled, MID_PALETTE)
        near = near.resize((width, 72), Image.Resampling.NEAREST)
        records.append(save_runtime(near, f"wl_backdrop_{prefix}_near_r4.png"))
    return records


def build_props() -> list[dict[str, object]]:
    flower = clean(Image.open(SOURCE / "wildflower-field-imagegen.png"), 96)
    sunflower = clean(Image.open(SOURCE / "sunflower-field-imagegen.png"), 96)
    haystack = clean(Image.open(SOURCE / "haystack-imagegen.png"), 96)
    return [
        save_runtime(pixel_fit(flower, (72, 36), PROP_PALETTE, contain=True), "wl_flower_meadow_r2.png"),
        save_runtime(pixel_fit(sunflower, (48, 36), PROP_PALETTE, contain=True), "wl_sunflower_field_r2.png"),
        save_runtime(pixel_fit(haystack, (32, 32), PROP_PALETTE, contain=True), "wl_haystack_r2.png"),
    ]


def make_bank(orientation: str, variant: int) -> Image.Image:
    # Strongly different profiles are intentionally clustered at selected
    # columns; this breaks the rectangle without changing collision topology.
    profiles = [
        [4, 4, 5, 6, 8, 11, 8, 5, 4],
        [4, 5, 9, 14, 16, 13, 8, 5, 4],
        [5, 7, 10, 12, 14, 16, 15, 10, 6],
        [11, 15, 14, 10, 6, 5, 7, 9, 5],
    ][variant]
    grass_path = ROOT / "macos/CreekSprout/CreekSprout/Presentation/DisplayR2/r3_tile_grass_a.png"
    grass = Image.open(grass_path).convert("RGBA").resize((24, 24), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    pixels = canvas.load()
    grass_pixels = grass.load()
    soil = rgb("#76503A")
    shadow = rgb("#233A3A")
    for x in range(24):
        slot = min(8, x * 9 // 24)
        depth = profiles[slot]
        boundary = depth if orientation == "north" else 24 - depth
        for y in range(24):
            is_land = y <= boundary if orientation == "north" else y >= boundary
            if is_land:
                pixels[x, y] = grass_pixels[x, y]
            elif abs(y - boundary) <= 1:
                pixels[x, y] = soil + (255,)
            elif abs(y - boundary) <= 3:
                pixels[x, y] = shadow + (110,)
    return clean(canvas, 48)


def build_banks() -> list[dict[str, object]]:
    records: list[dict[str, object]] = []
    for orientation in ("north", "south"):
        for variant in range(4):
            records.append(save_runtime(
                make_bank(orientation, variant),
                f"wl_bank_{orientation}_{variant + 1:02d}_r2.png",
            ))
    return records


def main() -> int:
    records = build_depth_layers() + build_props() + build_banks()
    failures: list[str] = []
    for record in records:
        if record["dirty_transparent_rgb"] != 0:
            failures.append(f"{record['asset_id']}: dirty transparent RGB")
        if any(value not in (0, 255) for value in record["alpha_values"]):
            failures.append(f"{record['asset_id']}: alpha is not binary")

    manifest = {
        "task": "N-019",
        "revision": "depth-layout-r15",
        "source_mode": "built-in ImageGen references processed into project-matched native pixel art",
        "style_contract": {
            "filtering": "nearest",
            "scaling": "integer only",
            "alpha": "binary",
            "shadows": "baked hard-edged pixel shadows; no runtime vector blur",
            "depth": "far continuous top-down mountain forest -> mid forest -> near ridge -> buildings/props/actors",
        },
        "assets": records,
        "failures": failures,
    }
    ARTIFACT.mkdir(parents=True, exist_ok=True)
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
