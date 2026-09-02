#!/usr/bin/env python3
"""Build N-019 R17 sharp north-edge sky-and-ridge backdrops.

R16 deliberately authored at half resolution and enlarged 2x. That made the
ridge read as soft 2x2 colour blocks in the live game. R17 samples the original
project-owned composition source directly into every native runtime pixel,
then applies a locked project palette and nearest-only presentation scaling.

The resulting 72 px strip occupies the fixed top-screen horizon band. The
market starts at its north boundary; the one-row-taller farm starts on its
unreachable top row so camera framing does not clip the ridge. Its opaque blue
sky intentionally replaces grass only inside that bounded horizon strip.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = ROOT / "artifacts/integration/n-019-demo-visual/sky-ridge-r17"
SOURCE = ARTIFACT / "source/original-ridge-imagegen.png"
PROCESSED = ARTIFACT / "processed"
PREVIEWS = ARTIFACT / "previews-4x"
WORLD_LIFE = ROOT / "macos/CreekSprout/CreekSprout/Presentation/WorldLife"
GRASS_SOURCE = ROOT / "macos/CreekSprout/CreekSprout/Presentation/DisplayR2/r3_tile_grass_a.png"

NATIVE_HEIGHT = 72
RIDGE_HEIGHT = 46

# A restrained cyan-blue sky that sits beside the current muted olive ground
# without introducing a photographic gradient or high-saturation HD colour.
SKY_PALETTE = [
    "#6F9EAE",
    "#7AA9B5",
    "#86B4BA",
    "#94BFC0",
    "#A4CAC3",
]

# Clear warm-grey stone planes and olive pine/ground clusters. The stronger
# value separation is intentional: the ridge remains legible at 3x integer
# zoom while still receding behind the orange-roofed buildings.
RIDGE_PALETTE = [
    "#2F403B",
    "#354D3D",
    "#405943",
    "#4E6647",
    "#5E734B",
    "#708151",
    "#788653",
    "#84905B",
    "#99A16C",
    "#454746",
    "#565653",
    "#68655D",
    "#7B7568",
    "#918877",
    "#A69B83",
    "#BAAC90",
    "#67513C",
    "#816546",
    "#9A7A52",
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


def binary_alpha(image: Image.Image, threshold: int = 88) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= threshold else 0)
    rgba.putalpha(alpha)
    clean = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    clean.paste(rgba, mask=alpha)
    return clean


def remove_generated_checker(image: Image.Image) -> Image.Image:
    """Remove the neutral near-white preview checker from the generated source."""
    rgba = image.convert("RGBA")
    output: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in rgba.getdata():
        chroma = max(red, green, blue) - min(red, green, blue)
        if min(red, green, blue) >= 212 and chroma <= 16:
            output.append((0, 0, 0, 0))
        else:
            output.append((red, green, blue, alpha))
    rgba.putdata(output)
    return binary_alpha(rgba, 56)


def crop_alpha(image: Image.Image) -> Image.Image:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("ridge source contains no visible pixels")
    return image.crop(bbox)


def quantize_ridge(image: Image.Image) -> Image.Image:
    rgba = binary_alpha(image)
    alpha = rgba.getchannel("A")
    # Sharpen only colour planes; alpha is reattached as a hard pixel mask.
    sharpened = rgba.convert("RGB").filter(
        ImageFilter.UnsharpMask(radius=0.8, percent=185, threshold=2)
    )
    indexed = sharpened.quantize(
        palette=palette_image(RIDGE_PALETTE),
        dither=Image.Dither.NONE,
    )
    result = indexed.convert("RGBA")
    result.putalpha(alpha)
    return binary_alpha(result)


def build_sky(width: int) -> Image.Image:
    """Make a clean five-tone pixel sky with only two-row dither transitions."""
    colors = [rgb(color) for color in SKY_PALETTE]
    canvas = Image.new("RGBA", (width, NATIVE_HEIGHT), (*colors[0], 255))
    pixels = canvas.load()
    # Four quiet value bands; the two-pixel ordered boundaries prevent a soft
    # HD gradient while avoiding a single hard horizontal stripe.
    boundaries = [13, 27, 41, 56]
    for y in range(NATIVE_HEIGHT):
        band = sum(y > boundary for boundary in boundaries)
        for x in range(width):
            color_index = band
            for boundary_index, boundary in enumerate(boundaries):
                if y in (boundary, boundary + 1):
                    phase = (x + y) & 3
                    color_index = boundary_index + (1 if phase in (1, 3) else 0)
                    break
            pixels[x, y] = (*colors[color_index], 255)
    return canvas


def build_backdrop(width: int) -> Image.Image:
    source = crop_alpha(remove_generated_checker(Image.open(SOURCE)))

    # Direct-to-native resampling is the key R17 correction. There is no
    # half-resolution work canvas and no 2x enlargement stage.
    ridge = source.resize((width, RIDGE_HEIGHT), Image.Resampling.LANCZOS)
    ridge = quantize_ridge(ridge)

    canvas = build_sky(width)
    # The generated silhouette has small transparent gaps along its foot. A
    # nine-pixel transition in the exact current grass base colour prevents
    # the opaque sky from appearing as a blue line underneath the mountain.
    # Sparse warm/dark pixels mirror the existing four-colour grass texture.
    ground = rgb("#788653")
    ground_dark = rgb("#565653")
    ground_warm = rgb("#9A7A52")
    for y in range(NATIVE_HEIGHT - 9, NATIVE_HEIGHT):
        for x in range(width):
            color = ground
            if (x * 17 + y * 11) % 53 == 0:
                color = ground_dark
            elif (x * 29 + y * 7) % 97 == 0:
                color = ground_warm
            canvas.putpixel((x, y), (*color, 255))
    canvas.alpha_composite(ridge, (0, NATIVE_HEIGHT - RIDGE_HEIGHT))
    return canvas


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def detail_metrics(image: Image.Image) -> dict[str, object]:
    sky = {rgb(color) for color in SKY_PALETTE}
    pixels = image.convert("RGBA")
    data = pixels.load()
    mountain = {
        (x, y)
        for y in range(image.height)
        for x in range(image.width)
        if data[x, y][:3] not in sky
    }
    if not mountain:
        raise ValueError("backdrop contains no mountain pixels")

    transitions = 0
    one_pixel_runs = 0
    for y in range(image.height):
        run_color: tuple[int, int, int] | None = None
        run_length = 0
        for x in range(image.width):
            color = data[x, y][:3]
            if color == run_color:
                run_length += 1
                continue
            if run_color is not None and run_length == 1 and run_color not in sky:
                one_pixel_runs += 1
            if run_color is not None:
                transitions += 1
            run_color = color
            run_length = 1
        if run_color is not None and run_length == 1 and run_color not in sky:
            one_pixel_runs += 1

    comparable_blocks = 0
    uniform_blocks = 0
    for y in range(0, image.height - 1, 2):
        for x in range(0, image.width - 1, 2):
            block = [data[x + dx, y + dy][:3] for dy in (0, 1) for dx in (0, 1)]
            if all(color not in sky for color in block):
                comparable_blocks += 1
                uniform_blocks += len(set(block)) == 1

    xs = [point[0] for point in mountain]
    ys = [point[1] for point in mountain]
    return {
        "mountain_pixel_count": len(mountain),
        "mountain_bbox": [min(xs), min(ys), max(xs) + 1, max(ys) + 1],
        "horizontal_color_transitions": transitions,
        "single_pixel_mountain_runs": one_pixel_runs,
        "uniform_aligned_2x2_ratio": round(
            uniform_blocks / comparable_blocks if comparable_blocks else 0,
            6,
        ),
    }


def save_runtime(image: Image.Image, filename: str) -> dict[str, object]:
    runtime = WORLD_LIFE / filename
    processed = PROCESSED / filename
    preview = PREVIEWS / f"{Path(filename).stem}-4x.png"
    runtime.parent.mkdir(parents=True, exist_ok=True)
    PROCESSED.mkdir(parents=True, exist_ok=True)
    PREVIEWS.mkdir(parents=True, exist_ok=True)

    image.save(runtime, optimize=True)
    image.save(processed, optimize=True)
    image.resize((image.width * 4, image.height * 4), Image.Resampling.NEAREST).save(
        preview,
        optimize=True,
    )

    rgba = image.convert("RGBA")
    colors = {"#%02X%02X%02X" % pixel[:3] for pixel in rgba.getdata()}
    alpha_values = sorted({pixel[3] for pixel in rgba.getdata()})
    return {
        "asset_id": Path(filename).stem,
        "native_size": list(image.size),
        "alpha_values": alpha_values,
        "palette": sorted(colors),
        "top_row_palette": sorted({
            "#%02X%02X%02X" % rgba.getpixel((x, 0))[:3]
            for x in range(image.width)
        }),
        "detail": detail_metrics(image),
        "sha256": sha256(runtime),
    }


def main() -> int:
    records = [
        save_runtime(build_backdrop(528), "wl_backdrop_farm_north_horizon_r6.png"),
        save_runtime(build_backdrop(576), "wl_backdrop_market_north_horizon_r6.png"),
    ]
    allowed = {color.upper() for color in SKY_PALETTE + RIDGE_PALETTE}
    sky = {color.upper() for color in SKY_PALETTE}
    failures: list[str] = []
    for record in records:
        if record["alpha_values"] != [255]:
            failures.append(f"{record['asset_id']}: sky strip must be fully opaque")
        if not set(record["palette"]).issubset(allowed):
            failures.append(f"{record['asset_id']}: colour outside locked palette")
        if not set(record["top_row_palette"]).issubset(sky):
            failures.append(f"{record['asset_id']}: mountain entered the top sky row")
        detail = record["detail"]
        if detail["single_pixel_mountain_runs"] < 40:
            failures.append(f"{record['asset_id']}: insufficient one-pixel ridge detail")
        if detail["uniform_aligned_2x2_ratio"] >= 0.82:
            failures.append(f"{record['asset_id']}: still reads as 2x block enlargement")

    manifest = {
        "task": "N-019",
        "revision": "sky-ridge-r17",
        "source_mode": "project-owned ImageGen composition source rebuilt directly at native pixel resolution",
        "reference_policy": "PO annotation supplies screen-band placement only; no reference-game pixels are shipped",
        "style_contract": {
            "planes_per_map": 1,
            "native_height_px": NATIVE_HEIGHT,
            "screen_band_cells": 3,
            "runtime_anchor_rows": {
                "farm": 14,
                "market": 14,
            },
            "filtering": "nearest",
            "runtime_scaling": "integer only",
            "source_resampling": "direct to full native width; never half-res or 2x enlarged",
            "sky_palette": SKY_PALETTE,
            "ridge_palette": RIDGE_PALETTE,
            "alpha": "fully opaque because the bounded strip intentionally replaces north-edge grass with sky",
            "shape": "high outer shoulders, low central saddle, blue sky above",
            "forbidden": [
                "mountain below the annotated north screen band",
                "grass above the mountain",
                "half-resolution authoring",
                "2x2 enlargement blur",
                "mountain over or around houses",
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
        "detail": [record["detail"] for record in records],
    }, ensure_ascii=False))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
