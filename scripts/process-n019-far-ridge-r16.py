#!/usr/bin/env python3
"""Build N-019 R16 single-plane transparent far-ridge sprites.

The ImageGen source is only a composition source. Runtime output is rebuilt at
half resolution, quantized to the current land palette, given binary alpha,
then enlarged 2x with nearest-neighbour sampling. No source reference sprite is
copied directly into the game.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = ROOT / "artifacts/integration/n-019-demo-visual/far-ridge-r16"
SOURCE = ARTIFACT / "source/original-ridge-imagegen.png"
PROCESSED = ARTIFACT / "processed"
PREVIEWS = ARTIFACT / "previews-4x"
WORLD_LIFE = ROOT / "macos/CreekSprout/CreekSprout/Presentation/WorldLife"
GRASS_SOURCE = ROOT / "macos/CreekSprout/CreekSprout/Presentation/DisplayR2/r3_tile_grass_a.png"

# Warm olive land + warm grey-brown stone. The first colour is the exact grass
# transition colour sampled from the current runtime surface.
RIDGE_PALETTE = [
    "#788653",
    "#6F7B47",
    "#52633F",
    "#3F503C",
    "#334344",
    "#485352",
    "#55484A",
    "#5D615A",
    "#737064",
    "#8B826E",
    "#A49980",
    "#B9AE91",
    "#765B3E",
    "#B58A52",
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


def clean(image: Image.Image, threshold: int = 96) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= threshold else 0)
    rgba.putalpha(alpha)
    result = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    result.paste(rgba, mask=alpha)
    return result


def remove_generated_checker(image: Image.Image) -> Image.Image:
    """Remove only the neutral near-white ImageGen preview checker.

    Runtime colours top out below this luminance, so the threshold cannot erase
    any colour that survives the locked R16 palette.
    """
    rgba = image.convert("RGBA")
    output: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in rgba.getdata():
        chroma = max(red, green, blue) - min(red, green, blue)
        if min(red, green, blue) >= 214 and chroma <= 14:
            output.append((0, 0, 0, 0))
        else:
            output.append((red, green, blue, alpha))
    rgba.putdata(output)
    return clean(rgba, 56)


def crop_alpha(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("ridge source contains no visible pixels")
    return image.crop(bbox)


def quantize(image: Image.Image) -> Image.Image:
    rgba = clean(image)
    alpha = rgba.getchannel("A")
    indexed = rgba.convert("RGB").quantize(
        palette=palette_image(RIDGE_PALETTE),
        dither=Image.Dither.NONE,
    )
    result = indexed.convert("RGBA")
    result.putalpha(alpha)
    return clean(result)


def build_ridge(width: int) -> Image.Image:
    source = crop_alpha(remove_generated_checker(Image.open(SOURCE)))

    # Work at half resolution so every final colour cluster is an intentional
    # 2x2 native-pixel block. Horizontal padding keeps all four corners truly
    # transparent and prevents another rectangular edge plate.
    half_width = width // 2
    half_height = 36
    inner_width = half_width - 4
    inner_height = 34
    reduced = source.resize((inner_width, inner_height), Image.Resampling.BOX)
    reduced = clean(reduced, 72)

    canvas = Image.new("RGBA", (half_width, half_height), (0, 0, 0, 0))
    canvas.alpha_composite(reduced, (2, half_height - inner_height))
    canvas = quantize(canvas)

    # The asset itself carries the pixel grid. SpriteKit must only apply
    # nearest-neighbour integer presentation scaling after this point.
    return canvas.resize((width, 72), Image.Resampling.NEAREST)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save_runtime(image: Image.Image, filename: str) -> dict[str, object]:
    runtime = WORLD_LIFE / filename
    processed = PROCESSED / filename
    preview = PREVIEWS / f"{Path(filename).stem}-4x.png"
    runtime.parent.mkdir(parents=True, exist_ok=True)
    PROCESSED.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)

    image = clean(image)
    image.save(runtime, optimize=True)
    image.save(processed, optimize=True)
    image.resize((image.width * 4, image.height * 4), Image.Resampling.NEAREST).save(
        preview,
        optimize=True,
    )

    pixels = list(image.getdata())
    alpha_values = sorted({alpha for _, _, _, alpha in pixels})
    visible = [(red, green, blue) for red, green, blue, alpha in pixels if alpha == 255]
    transparent_count = sum(1 for _, _, _, alpha in pixels if alpha == 0)
    dirty = sum(
        1 for red, green, blue, alpha in pixels
        if alpha == 0 and (red or green or blue)
    )
    alpha = image.getchannel("A")
    full_rows = [
        row for row in range(image.height)
        if all(alpha.getpixel((column, row)) == 255 for column in range(image.width))
    ]
    full_columns = [
        column for column in range(image.width)
        if all(alpha.getpixel((column, row)) == 255 for row in range(image.height))
    ]
    return {
        "asset_id": Path(filename).stem,
        "native_size": list(image.size),
        "alpha_values": alpha_values,
        "transparent_ratio": round(transparent_count / len(pixels), 6),
        "opaque_ratio": round(len(visible) / len(pixels), 6),
        "visible_palette": ["#%02X%02X%02X" % color for color in sorted(set(visible))],
        "full_opaque_rows": full_rows,
        "full_opaque_columns": full_columns,
        "corners_alpha": [
            alpha.getpixel((0, 0)),
            alpha.getpixel((image.width - 1, 0)),
            alpha.getpixel((0, image.height - 1)),
            alpha.getpixel((image.width - 1, image.height - 1)),
        ],
        "dirty_transparent_rgb": dirty,
        "sha256": sha256(runtime),
    }


def main() -> int:
    records = [
        save_runtime(build_ridge(384), "wl_backdrop_farm_far_r5.png"),
        save_runtime(build_ridge(432), "wl_backdrop_market_far_r5.png"),
    ]
    allowed = {color.upper() for color in RIDGE_PALETTE}
    failures: list[str] = []
    for record in records:
        if record["alpha_values"] != [0, 255]:
            failures.append(f"{record['asset_id']}: alpha must be binary and non-empty")
        if record["dirty_transparent_rgb"] != 0:
            failures.append(f"{record['asset_id']}: dirty transparent RGB")
        if record["transparent_ratio"] < 0.45:
            failures.append(f"{record['asset_id']}: transparent ratio below 45%")
        if record["full_opaque_rows"] or record["full_opaque_columns"]:
            failures.append(f"{record['asset_id']}: rectangular opaque row/column")
        if any(record["corners_alpha"]):
            failures.append(f"{record['asset_id']}: corners must remain transparent")
        if not set(record["visible_palette"]).issubset(allowed):
            failures.append(f"{record['asset_id']}: colour outside locked palette")

    manifest = {
        "task": "N-019",
        "revision": "far-ridge-r16",
        "source_mode": "built-in ImageGen composition source, rebuilt as original project-native pixel art",
        "reference_policy": "user references supplied silhouette/depth only; no reference pixels are shipped",
        "style_contract": {
            "planes_per_map": 1,
            "filtering": "nearest",
            "scaling": "integer only",
            "palette": RIDGE_PALETTE,
            "alpha": "binary 0/255",
            "shape": "high outer shoulders, low central saddle, irregular transparent foot",
            "forbidden": [
                "opaque rectangular background",
                "mountain pixels below rear-house line",
                "mid/near mountain plates",
                "cold teal forest wall",
                "reference sprite copying",
            ],
        },
        "inputs": {
            "imagegen_source_sha256": sha256(SOURCE),
            "runtime_grass_source": str(GRASS_SOURCE.relative_to(ROOT)),
            "runtime_grass_sha256": sha256(GRASS_SOURCE),
        },
        "assets": records,
        "failures": failures,
        "result": "PASS" if not failures else "FAIL",
    }
    ARTIFACT.mkdir(parents=True, exist_ok=True)
    (ARTIFACT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({
        "result": manifest["result"],
        "assets": len(records),
        "failures": failures,
        "transparent_ratios": [record["transparent_ratio"] for record in records],
    }, ensure_ascii=False))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
