#!/usr/bin/env python3
"""Build N-019 R13 forest, flowing-water, and river-stone runtime art."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = ROOT / "artifacts/integration/n-019-demo-visual/forest-river-r13"
SOURCE = ARTIFACT / "source"
PROCESSED = ARTIFACT / "processed"
PREVIEWS = ARTIFACT / "previews-8x"
WORLD_LIFE = ROOT / "macos/CreekSprout/CreekSprout/Presentation/WorldLife"
DISPLAY = ROOT / "macos/CreekSprout/CreekSprout/Presentation/DisplayR2"

LANDSCAPE_PALETTE = [
    "#173C3B", "#1E5148", "#2F6650", "#477A58", "#65915E",
    "#83A66B", "#A8BC78", "#334F55", "#4C6870", "#70888A",
    "#68705B", "#84795E", "#9B8B69", "#B6A77A", "#D0C28C",
    "#39413F", "#53534A", "#726B58", "#8A8066", "#E1D39F",
]
WATER_PALETTE = [
    "#1F3A3E", "#374F55", "#376173", "#3D6873", "#456F75",
    "#4B7477", "#557D7C", "#597F80", "#73978E", "#B8CEC0",
]
STONE_PALETTE = [
    "#334344", "#485352", "#5D615A", "#737064", "#8B826E",
    "#A49980", "#B9AE91", "#D1C49F", "#52633F", "#6F7B47",
    "#879452", "#A3A866",
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


def quantize(image: Image.Image, colors: list[str]) -> Image.Image:
    alpha = image.getchannel("A")
    indexed = image.convert("RGB").quantize(
        palette=palette_image(colors),
        dither=Image.Dither.NONE,
    )
    result = indexed.convert("RGBA")
    result.putalpha(alpha.point(lambda value: 255 if value >= 96 else 0))
    clean = Image.new("RGBA", result.size, (0, 0, 0, 0))
    clean.paste(result, mask=result.getchannel("A"))
    return clean


def remove_generated_checker(image: Image.Image) -> Image.Image:
    """Remove the near-white checker baked into the generated ridge source."""
    rgba = image.convert("RGBA")
    pixels = []
    for red, green, blue, _ in rgba.getdata():
        chroma = max(red, green, blue) - min(red, green, blue)
        alpha = 0 if min(red, green, blue) >= 205 and chroma <= 24 else 255
        pixels.append((red, green, blue, alpha))
    rgba.putdata(pixels)
    return rgba


def fit_inside(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    fitted = ImageOps.contain(image, size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(
        fitted,
        ((size[0] - fitted.width) // 2, size[1] - fitted.height),
    )
    return canvas


def save_runtime(image: Image.Image, path: Path, preview_scale: int = 8) -> dict[str, object]:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    processed = PROCESSED / path.name
    image.save(processed, optimize=True)
    image.resize(
        (image.width * preview_scale, image.height * preview_scale),
        Image.Resampling.NEAREST,
    ).save(PREVIEWS / f"{path.stem}-{preview_scale}x.png", optimize=True)
    alpha_values = sorted(set(image.getchannel("A").getdata()))
    dirty = sum(
        1 for red, green, blue, alpha in image.getdata()
        if alpha == 0 and (red or green or blue)
    )
    return {
        "asset_id": path.stem,
        "native_size": list(image.size),
        "alpha_values": alpha_values,
        "dirty_transparent_rgb": dirty,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def build_ridge() -> tuple[Image.Image, dict[str, object]]:
    source = remove_generated_checker(
        Image.open(SOURCE / "farm-forest-ridge-imagegen.png")
    )
    bbox = source.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("ridge source contains no foreground")
    cropped = source.crop(bbox)
    # Compress the concept into a low, layered horizon. Runtime placement adds
    # the remaining elevation so the ridge frames instead of bisecting roofs.
    ridge = cropped.resize((384, 58), Image.Resampling.LANCZOS)
    ridge = ImageEnhance.Color(ridge).enhance(0.88)
    canvas = Image.new("RGBA", (384, 72), (0, 0, 0, 0))
    canvas.alpha_composite(ridge, (0, 14))
    result = quantize(canvas, LANDSCAPE_PALETTE)
    record = save_runtime(
        result,
        WORLD_LIFE / "wl_backdrop_farm_forest_r2.png",
        preview_scale=4,
    )
    return result, record


def build_water() -> list[dict[str, object]]:
    source = Image.open(SOURCE / "creek-water-imagegen.png").convert("RGB")
    side = min(source.size)
    left = (source.width - side) // 2
    top = (source.height - side) // 2
    square = source.crop((left, top, left + side, top + side))

    # Mirror before the small crop so opposite tile edges share visual mass.
    half = side // 2
    core = square.crop((half // 2, half // 2, half // 2 + half, half // 2 + half))
    seamless = Image.new("RGB", (half * 2, half * 2))
    seamless.paste(core, (0, 0))
    seamless.paste(ImageOps.mirror(core), (half, 0))
    seamless.paste(ImageOps.flip(core), (0, half))
    seamless.paste(ImageOps.flip(ImageOps.mirror(core)), (half, half))
    base = seamless.resize((24, 24), Image.Resampling.LANCZOS).convert("RGBA")
    base.putalpha(255)
    base = quantize(base, WATER_PALETTE)

    records: list[dict[str, object]] = []
    for index, offset in enumerate((0, 2, 4, 6)):
        # A vertical wrap turns the coherent source texture into a readable
        # four-frame downstream loop without changing shoreline topology.
        frame = ImageChops.offset(base, 0, -offset)
        draw = ImageDraw.Draw(frame)
        # Hand-authored tiny current marks survive the 24 px reduction. Their
        # stepped downstream phase makes motion legible without a foam carpet.
        for start_x, start_y, length in [(2, 3, 5), (13, 8, 6), (6, 16, 4), (17, 21, 4)]:
            y = (start_y - offset) % 24
            points = [((start_x + step) % 24, (y + step // 3) % 24) for step in range(length)]
            draw.point(points, fill=rgb("#B8CEC0") + (255,))
            if length >= 5:
                shadow = [((x - 1) % 24, (py + 1) % 24) for x, py in points[1:-1]]
                draw.point(shadow, fill=rgb("#73978E") + (255,))
        records.append(save_runtime(
            frame,
            DISPLAY / f"r4_tile_water_f{index:02d}.png",
        ))
    return records


def rock_cells(source: Image.Image) -> list[Image.Image]:
    cells: list[Image.Image] = []
    cell_width = source.width // 4
    cell_height = source.height // 2
    for row in range(2):
        for column in range(4):
            cell = source.crop((
                column * cell_width,
                row * cell_height,
                (column + 1) * cell_width,
                (row + 1) * cell_height,
            ))
            bbox = cell.getchannel("A").point(lambda value: 255 if value >= 64 else 0).getbbox()
            if bbox is not None:
                cells.append(cell.crop(bbox))
    if len(cells) < 6:
        raise ValueError(f"expected at least 6 separated stones, got {len(cells)}")
    return cells


def make_stone_sprite(source: Image.Image, index: int) -> Image.Image:
    target = (18, 15) if index < 4 else (22, 18)
    fitted = fit_inside(source, target)
    canvas = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    canvas.alpha_composite(fitted, (0, 24 - fitted.height))
    return quantize(canvas, STONE_PALETTE)


def build_stones_and_path() -> list[dict[str, object]]:
    source = Image.open(SOURCE / "river-stones-imagegen.png").convert("RGBA")
    cells = rock_cells(source)
    sprites = [make_stone_sprite(cell, index) for index, cell in enumerate(cells[:6])]
    records: list[dict[str, object]] = []
    for index, sprite in enumerate(sprites[:4], start=1):
        records.append(save_runtime(
            sprite,
            WORLD_LIFE / f"wl_river_stone_{index:02d}_r1.png",
        ))

    grass_path = ROOT / "macos/CreekSprout/CreekSprout/Presentation/DisplayR2/r3_tile_grass_a.png"
    if not grass_path.exists():
        grass_path = ROOT / "macos/CreekSprout/CreekSprout/Assets/tile_grass_a.png"
    path = Image.open(grass_path).convert("RGBA").resize((24, 24), Image.Resampling.NEAREST)
    # Three separated stepping stones preserve green joints and stop the road
    # reading as a stacked masonry wall.
    for sprite, position, scale in [
        (cells[1], (-1, 1), (11, 8)),
        (cells[3], (12, 7), (10, 8)),
        (cells[0], (3, 15), (10, 8)),
    ]:
        fitted = fit_inside(sprite, scale)
        fitted = quantize(fitted, STONE_PALETTE)
        path.alpha_composite(fitted, position)
    records.append(save_runtime(
        path,
        DISPLAY / "r4_tile_stone_path.png",
    ))
    return records


def main() -> int:
    for directory in (PROCESSED, PREVIEWS, WORLD_LIFE, DISPLAY):
        directory.mkdir(parents=True, exist_ok=True)
    failures: list[str] = []
    records: list[dict[str, object]] = []
    try:
        _, ridge = build_ridge()
        records.append(ridge)
        records.extend(build_water())
        records.extend(build_stones_and_path())
    except Exception as error:  # pragma: no cover - evidence path
        failures.append(str(error))

    for record in records:
        if record["dirty_transparent_rgb"] != 0:
            failures.append(f"{record['asset_id']}: dirty transparent RGB")
        if any(value not in (0, 255) for value in record["alpha_values"]):
            failures.append(f"{record['asset_id']}: alpha is not binary")

    manifest = {
        "task": "N-019",
        "revision": "forest-river-r13",
        "source_mode": "built-in ImageGen sources processed into native pixel runtime art",
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
