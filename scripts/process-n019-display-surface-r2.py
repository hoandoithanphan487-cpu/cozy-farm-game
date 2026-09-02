#!/usr/bin/env python3
"""Build the N-019 R2 display-layer cat shop, ground, path and water pixels.

ImageGen files are source masters only. This script converts them into the
locked native canvases consumed by SpriteKit, derives coherent water banks and
canals, hardens alpha, and writes review previews plus a machine-readable
manifest. Runtime output is deliberately deterministic.
"""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
GENERATED = Path(
    "/Users/fengyifan/.codex/generated_images/"
    "01a039ed-26f9-76f3-a5c1-cd42c2573cf8"
)
EVIDENCE = ROOT / "artifacts/integration/n-019-demo-visual/display-r2"
SOURCE = EVIDENCE / "source"
PROCESSED = EVIDENCE / "processed"
PREVIEWS = EVIDENCE / "previews-8x"
ASSETS = ROOT / "macos/CreekSprout/CreekSprout/Assets"
WORLD_LIFE = ROOT / "macos/CreekSprout/CreekSprout/Presentation/WorldLife"
DISPLAY_R2 = ROOT / "macos/CreekSprout/CreekSprout/Presentation/DisplayR2"

SOURCE_FILES = {
    "cat_shop": "exec-73a780fd-5d21-4094-a873-7f01574a2a2d.png",
    "grass": "exec-3478d56c-95e1-40bc-839a-a602eb5def8c.png",
    "stone": "exec-398c5e88-5b98-4053-88e1-eb0812b515a1.png",
    "water": "exec-d67a6c02-8148-4053-8a96-86df61059088.png",
}


def quantized(image: Image.Image, colors: int) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= 96 else 0)
    rgb = rgba.convert("RGB").quantize(
        colors=colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    result = rgb.convert("RGBA")
    result.putalpha(alpha)
    pixels = []
    for red, green, blue, a in result.getdata():
        pixels.append((red, green, blue, 255) if a else (0, 0, 0, 0))
    result.putdata(pixels)
    return result


def crop_subject(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError(f"source has no alpha subject: {path}")
    return image.crop(bbox)


def fit_cat_shop(path: Path) -> Image.Image:
    subject = crop_subject(path)
    target = (144, 120)
    scale = min(138 / subject.width, 115 / subject.height)
    subject = subject.resize(
        (round(subject.width * scale), round(subject.height * scale)),
        Image.Resampling.LANCZOS,
    )
    subject = quantized(subject, 64)
    canvas = Image.new("RGBA", target, (0, 0, 0, 0))
    canvas.alpha_composite(subject, ((target[0] - subject.width) // 2, target[1] - subject.height))
    return canvas


def make_seamless(tile: Image.Image) -> Image.Image:
    tile = tile.convert("RGBA")
    pixels = tile.load()
    width, height = tile.size
    for y in range(height):
        left = pixels[0, y]
        right = pixels[width - 1, y]
        mean = tuple((left[index] + right[index]) // 2 for index in range(4))
        pixels[0, y] = mean
        pixels[width - 1, y] = mean
    for x in range(width):
        top = pixels[x, 0]
        bottom = pixels[x, height - 1]
        mean = tuple((top[index] + bottom[index]) // 2 for index in range(4))
        pixels[x, 0] = mean
        pixels[x, height - 1] = mean
    return tile


def surface_tile(path: Path, colors: int) -> Image.Image:
    source = Image.open(path).convert("RGB")
    side = min(source.size)
    # ImageGen masters already contain deliberate macro-pixel clusters. A
    # whole-image reduction would average those clusters back into a flat
    # colour, so sample a representative 192px window and preserve it with
    # nearest-neighbour reduction into the locked native tile.
    sample_side = min(side, 192)
    left = (source.width - sample_side) // 2
    top = (source.height - sample_side) // 2
    source = source.crop((left, top, left + sample_side, top + sample_side))
    source = source.resize((24, 24), Image.Resampling.NEAREST).convert("RGBA")
    source.putalpha(255)
    return quantized(make_seamless(source), colors)


def grass_variants(base: Image.Image) -> list[Image.Image]:
    return [
        base,
        ImageChops.offset(base, 7, 5),
        ImageChops.offset(base.transpose(Image.Transpose.FLIP_LEFT_RIGHT), 3, 11),
        ImageChops.offset(base.transpose(Image.Transpose.FLIP_TOP_BOTTOM), 13, 2),
    ]


def bank_mask(edge_names: set[str]) -> Image.Image:
    mask = Image.new("L", (24, 24), 0)
    draw = ImageDraw.Draw(mask)
    pattern = (5, 4, 5, 6, 5, 4, 4, 5)
    if "n" in edge_names:
        for x in range(24):
            draw.line((x, 0, x, pattern[x % len(pattern)] - 1), fill=255)
    if "s" in edge_names:
        for x in range(24):
            depth = pattern[(x + 3) % len(pattern)]
            draw.line((x, 24 - depth, x, 23), fill=255)
    if "w" in edge_names:
        for y in range(24):
            draw.line((0, y, pattern[(y + 2) % len(pattern)] - 1, y), fill=255)
    if "e" in edge_names:
        for y in range(24):
            depth = pattern[(y + 5) % len(pattern)]
            draw.line((24 - depth, y, 23, y), fill=255)
    return mask


def water_bank(water: Image.Image, grass: Image.Image, edges: set[str]) -> Image.Image:
    mask = bank_mask(edges)
    result = Image.composite(grass, water, mask)
    # Pillow exposes filters through ImageFilter, but a direct one-pixel dark
    # shoreline is clearer and deterministic at the locked 24px canvas.
    pixels = result.load()
    mask_pixels = mask.load()
    dark = (31, 58, 62, 255)
    for y in range(24):
        for x in range(24):
            if mask_pixels[x, y] != 0:
                continue
            neighbours = ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
            if any(0 <= nx < 24 and 0 <= ny < 24 and mask_pixels[nx, ny] for nx, ny in neighbours):
                pixels[x, y] = dark
    return quantized(result, 24)


def canal(stone: Image.Image, water: Image.Image, north_south: bool) -> Image.Image:
    result = stone.copy()
    if north_south:
        result.paste(water.crop((6, 0, 18, 24)), (6, 0))
        draw = ImageDraw.Draw(result)
        draw.line((5, 0, 5, 23), fill=(31, 58, 62, 255))
        draw.line((18, 0, 18, 23), fill=(31, 58, 62, 255))
    else:
        result.paste(water.crop((0, 6, 24, 18)), (0, 6))
        draw = ImageDraw.Draw(result)
        draw.line((0, 5, 23, 5), fill=(31, 58, 62, 255))
        draw.line((0, 18, 23, 18), fill=(31, 58, 62, 255))
    return quantized(result, 24)


def flow_overlay(water: Image.Image, offset: int) -> Image.Image:
    shifted = ImageChops.offset(water, offset, offset // 2)
    result = Image.new("RGBA", shifted.size, (0, 0, 0, 0))
    source = shifted.load()
    output = result.load()
    for y in range(24):
        for x in range(24):
            red, green, blue, _ = source[x, y]
            if green + blue > 335 and blue > red + 12:
                output[x, y] = (174, 226, 218, 220)
    return result


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(name: str, image: Image.Image, runtime: Path, records: list[dict[str, object]]) -> None:
    processed = PROCESSED / name
    image.save(processed, optimize=False)
    shutil.copy2(processed, runtime)
    preview = image.resize((image.width * 8, image.height * 8), Image.Resampling.NEAREST)
    preview.save(PREVIEWS / f"{Path(name).stem}-8x.png", optimize=False)
    records.append({
        "asset": name,
        "runtime": str(runtime.relative_to(ROOT)),
        "size": [image.width, image.height],
        "sha256": sha256(runtime),
        "alpha_values": sorted(set(image.getchannel("A").getdata())),
        "opaque_colors": len(set(pixel[:3] for pixel in image.getdata() if pixel[3] == 255)),
    })


def main() -> None:
    for directory in (SOURCE, PROCESSED, PREVIEWS, ASSETS, WORLD_LIFE, DISPLAY_R2):
        directory.mkdir(parents=True, exist_ok=True)
    sources: dict[str, Path] = {}
    for slug, generated_name in SOURCE_FILES.items():
        generated = GENERATED / generated_name
        if not generated.exists():
            raise FileNotFoundError(generated)
        destination = SOURCE / f"{slug}-source.png"
        shutil.copy2(generated, destination)
        sources[slug] = destination

    records: list[dict[str, object]] = []
    cat_shop = fit_cat_shop(sources["cat_shop"])
    save("wl_cat_bbq_shop_r2.png", cat_shop, WORLD_LIFE / "wl_cat_bbq_shop_r2.png", records)

    grass = surface_tile(sources["grass"], 18)
    grass_names = ("tile_grass.png", "tile_grass_a.png", "tile_grass_b.png", "tile_grass_c.png")
    for name, image in zip(grass_names, grass_variants(grass)):
        save(f"r2_{name}", image, DISPLAY_R2 / f"r2_{name}", records)

    stone = surface_tile(sources["stone"], 24)
    save("r2_tile_stone_path.png", stone, DISPLAY_R2 / "r2_tile_stone_path.png", records)
    save("r2_prop_stone_path.png", stone, DISPLAY_R2 / "r2_prop_stone_path.png", records)

    water = surface_tile(sources["water"], 20)
    water_frames = [ImageChops.offset(water, offset, 0) for offset in (0, 2, 4, 6)]
    for index, frame in enumerate(water_frames):
        name = f"tile_water_f{index:02d}.png"
        save(f"r2_{name}", frame, DISPLAY_R2 / f"r2_{name}", records)

    edge_map = {
        "tile_water_edge_n.png": {"n"},
        "tile_water_edge_s.png": {"s"},
        "tile_water_edge_w.png": {"w"},
        "tile_water_edge_e.png": {"e"},
        "tile_water_corner_nw.png": {"n", "w"},
        "tile_water_corner_ne.png": {"n", "e"},
        "tile_water_corner_sw.png": {"s", "w"},
        "tile_water_corner_se.png": {"s", "e"},
    }
    banks: dict[str, Image.Image] = {}
    for name, edges in edge_map.items():
        banks[name] = water_bank(water, grass, edges)
        save(f"r2_{name}", banks[name], DISPLAY_R2 / f"r2_{name}", records)
    save(
        "r2_tile_water_edge.png",
        banks["tile_water_edge_n.png"],
        DISPLAY_R2 / "r2_tile_water_edge.png",
        records,
    )

    canal_ns = canal(stone, water, north_south=True)
    canal_ew = canal(stone, water, north_south=False)
    for name, image in (
        ("tile_canal_ns.png", canal_ns),
        ("tile_canal_ew.png", canal_ew),
        ("prop_canal_segment_ns.png", canal_ns),
        ("prop_canal_segment_ew.png", canal_ew),
    ):
        save(f"r2_{name}", image, DISPLAY_R2 / f"r2_{name}", records)
    for index, offset in enumerate((0, 2, 4, 6)):
        name = f"fx_canal_flow_f{index:02d}.png"
        save(
            f"r2_{name}",
            flow_overlay(water, offset),
            DISPLAY_R2 / f"r2_{name}",
            records,
        )

    manifest = {
        "task": "N-019 display R2",
        "contract": "native pixel runtime; nearest integer scaling; coherent cat shop, ground, path and water",
        "source_files": SOURCE_FILES,
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
