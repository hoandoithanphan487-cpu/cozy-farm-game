#!/usr/bin/env python3
"""Build N-019 R3 grass, readable shrubs, and native cat-staff sprites.

ImageGen outputs are source masters only. This deterministic pass produces
locked 24x24 ground tiles, 24x24 transparent shrubs, and 32x48 transparent
character sprites using the project palette, binary alpha, and nearest-
neighbour review previews.
"""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageChops


ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "artifacts/integration/n-019-demo-visual/ground-cats-r3"
SOURCE = EVIDENCE / "source"
PROCESSED = EVIDENCE / "processed"
PREVIEWS = EVIDENCE / "previews-8x"
DISPLAY = ROOT / "macos/CreekSprout/CreekSprout/Presentation/DisplayR2"
WORLD_LIFE = ROOT / "macos/CreekSprout/CreekSprout/Presentation/WorldLife"

GRASS_SOURCE = SOURCE / "grass-source.png"
CAT_SOURCES = {
    "wl_cat_black_r2.png": SOURCE / "cat-black-source.png",
    "wl_cat_calico_r2.png": SOURCE / "cat-calico-source.png",
    "wl_cat_ragdoll_r2.png": SOURCE / "cat-ragdoll-source.png",
}
SHRUB_SOURCES = {
    "wl_shrub_01_r2.png": SOURCE / "shrub-moss-source.png",
    "wl_shrub_02_r2.png": SOURCE / "shrub-willow-source.png",
    "wl_shrub_03_r2.png": SOURCE / "shrub-mist-flower-source.png",
    "wl_shrub_04_r2.png": SOURCE / "shrub-amber-berry-source.png",
}

LOCKED_PALETTE = [
    (38, 54, 56),    # deep creek ink
    (85, 72, 74),    # wet stone brown
    (118, 82, 71),   # chestnut shadow
    (120, 134, 83),  # moss leaf green
    (120, 151, 160), # mist blue
    (79, 112, 112),  # riverbank teal
    (181, 138, 82),  # straw gold
    (197, 138, 89),  # wood honey
    (198, 110, 61),  # copper orange
    (240, 217, 173), # paper cream
]

# Grass deliberately excludes blue/teal. The prior source's large cool
# clusters were the ambiguous "blue blocks" called out by the Product Owner.
GRASS_PALETTE = [
    (38, 54, 56),
    (85, 72, 74),
    (120, 134, 83),
    (181, 138, 82),
    (197, 138, 89),
]


def nearest_colour(rgb: tuple[int, int, int], palette: list[tuple[int, int, int]]) -> tuple[int, int, int]:
    return min(
        palette,
        key=lambda colour: sum((rgb[index] - colour[index]) ** 2 for index in range(3)),
    )


def remap_palette(image: Image.Image, palette: list[tuple[int, int, int]]) -> Image.Image:
    rgba = image.convert("RGBA")
    remapped = []
    for red, green, blue, alpha in rgba.getdata():
        if alpha == 0:
            remapped.append((0, 0, 0, 0))
        else:
            colour = nearest_colour((red, green, blue), palette)
            remapped.append((*colour, 255))
    rgba.putdata(remapped)
    return rgba


def make_seamless(image: Image.Image) -> Image.Image:
    result = image.copy().convert("RGBA")
    pixels = result.load()
    width, height = result.size
    for y in range(height):
        left = pixels[0, y][:3]
        right = pixels[width - 1, y][:3]
        colour = nearest_colour(
            tuple((left[index] + right[index]) // 2 for index in range(3)),
            GRASS_PALETTE,
        )
        pixels[0, y] = (*colour, 255)
        pixels[width - 1, y] = (*colour, 255)
    for x in range(width):
        top = pixels[x, 0][:3]
        bottom = pixels[x, height - 1][:3]
        colour = nearest_colour(
            tuple((top[index] + bottom[index]) // 2 for index in range(3)),
            GRASS_PALETTE,
        )
        pixels[x, 0] = (*colour, 255)
        pixels[x, height - 1] = (*colour, 255)
    return result


def grass_base(path: Path) -> Image.Image:
    source = Image.open(path).convert("RGB")
    # The master already uses deliberate macro-pixels. Sampling the whole
    # square with nearest preserves those clusters without creating a single
    # pond-like centre mark.
    tile = source.resize((24, 24), Image.Resampling.NEAREST).convert("RGBA")
    tile.putalpha(255)
    return make_seamless(remap_palette(tile, GRASS_PALETTE))


def grass_variants(base: Image.Image) -> list[Image.Image]:
    return [
        base,
        ImageChops.offset(base, 7, 5),
        ImageChops.offset(base.transpose(Image.Transpose.FLIP_LEFT_RIGHT), 3, 11),
        ImageChops.offset(base.transpose(Image.Transpose.FLIP_TOP_BOTTOM), 13, 2),
    ]


def cat_sprite(path: Path) -> Image.Image:
    source = Image.open(path).convert("RGBA")
    # Drop ImageGen's soft display glow while preserving the solid sprite.
    hard_alpha = source.getchannel("A").point(lambda value: 255 if value >= 144 else 0)
    source.putalpha(hard_alpha)
    bbox = hard_alpha.getbbox()
    if bbox is None:
        raise RuntimeError(f"source has no opaque subject: {path}")
    subject = source.crop(bbox)
    scale = min(30 / subject.width, 46 / subject.height)
    size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(size, Image.Resampling.LANCZOS)
    subject.putalpha(subject.getchannel("A").point(lambda value: 255 if value >= 96 else 0))
    subject = remap_palette(subject, LOCKED_PALETTE)

    canvas = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    x = (32 - subject.width) // 2
    y = 47 - subject.height
    canvas.alpha_composite(subject, (x, y))
    return canvas


def isolated_subject(path: Path) -> Image.Image:
    """Extract an ImageGen subject from real alpha or a baked white checker."""
    source = Image.open(path).convert("RGBA")
    alpha = source.getchannel("A")
    if alpha.getextrema() == (255, 255):
        mask_data = []
        for red, green, blue, _ in source.getdata():
            neutral_light = max(red, green, blue) - min(red, green, blue) <= 15 and min(red, green, blue) >= 165
            mask_data.append(0 if neutral_light else 255)
        alpha = Image.new("L", source.size)
        alpha.putdata(mask_data)
    else:
        alpha = alpha.point(lambda value: 255 if value >= 144 else 0)
    source.putalpha(alpha)
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError(f"source has no isolated subject: {path}")
    return source.crop(bbox)


def shrub_sprite(path: Path) -> Image.Image:
    subject = isolated_subject(path)
    scale = min(22 / subject.width, 22 / subject.height)
    size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(size, Image.Resampling.LANCZOS)
    subject.putalpha(subject.getchannel("A").point(lambda value: 255 if value >= 112 else 0))
    subject = remap_palette(subject, LOCKED_PALETTE)

    canvas = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    x = (24 - subject.width) // 2
    y = 23 - subject.height
    canvas.alpha_composite(subject, (x, y))
    return canvas


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(name: str, image: Image.Image, runtime: Path, records: list[dict[str, object]]) -> None:
    processed = PROCESSED / name
    image.save(processed, optimize=False)
    shutil.copy2(processed, runtime)
    image.resize((image.width * 8, image.height * 8), Image.Resampling.NEAREST).save(
        PREVIEWS / f"{Path(name).stem}-8x.png",
        optimize=False,
    )
    alpha = image.getchannel("A")
    records.append({
        "asset": name,
        "runtime": str(runtime.relative_to(ROOT)),
        "size": list(image.size),
        "sha256": sha256(runtime),
        "alpha_values": sorted(set(alpha.getdata())),
        "bbox": list(alpha.getbbox()) if alpha.getbbox() else None,
        "opaque_colours": len(set(pixel[:3] for pixel in image.getdata() if pixel[3] == 255)),
    })


def main() -> None:
    for directory in (SOURCE, PROCESSED, PREVIEWS, DISPLAY, WORLD_LIFE):
        directory.mkdir(parents=True, exist_ok=True)
    required = [GRASS_SOURCE, *CAT_SOURCES.values(), *SHRUB_SOURCES.values()]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise FileNotFoundError("missing source masters: " + ", ".join(missing))

    records: list[dict[str, object]] = []
    grass = grass_base(GRASS_SOURCE)
    for suffix, image in zip(("", "_a", "_b", "_c"), grass_variants(grass)):
        name = f"r3_tile_grass{suffix}.png"
        save(name, image, DISPLAY / name, records)

    for name, source in CAT_SOURCES.items():
        save(name, cat_sprite(source), WORLD_LIFE / name, records)

    for name, source in SHRUB_SOURCES.items():
        save(name, shrub_sprite(source), WORLD_LIFE / name, records)

    manifest = {
        "task": "N-019 ground, shrubs, and cats clarity R3",
        "contract": "24x24 opaque seamless grass; 24x24 transparent shrubs; 32x48 transparent cat staff; locked palette; nearest integer scaling",
        "imagegen_mode": "built-in",
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
