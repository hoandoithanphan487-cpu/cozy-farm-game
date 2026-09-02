#!/usr/bin/env python3
"""Build N-013 2048 RGBA building display assets and validation evidence.

Requires Pillow. In the Codex desktop workspace, run with the bundled Python:
  /Users/fengyifan/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 \
    scripts/process-n013-buildings.py
"""

from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
TASK_ROOT = ROOT / "artifacts/integration/n-013-buildings"
SOURCE_DIR = TASK_ROOT / "source"
PROCESSED_DIR = TASK_ROOT / "processed"
EVIDENCE_DIR = TASK_ROOT / "evidence"
CONTACT_DIR = TASK_ROOT / "contact-sheet"

CANVAS = 2048
MAX_SUBJECT_EDGE = 1720

ASSETS = (
    {
        "slug": "farm_house",
        "name": "Timber Farmhouse",
        "stable_id": "brookseed.landmark.farm_house",
        "source": "building_farm_house-source-v01.png",
        "processed": "building_farm_house-display-2048-v01.png",
        "background": "native_alpha",
    },
    {
        "slug": "farm_sluice",
        "name": "Bronze-Gate Waterworks",
        "stable_id": "brookseed.landmark.farm_sluice",
        "source": "building_farm_sluice-source-v01.png",
        "processed": "building_farm_sluice-display-2048-v01.png",
        "background": "light_matte",
    },
    {
        "slug": "market_seed_shed",
        "name": "Seed Shed",
        "stable_id": "brookseed.landmark.market_seed_shed",
        "source": "building_market_seed_shed-source-v01.png",
        "processed": "building_market_seed_shed-display-2048-v01.png",
        "background": "light_matte",
    },
    {
        "slug": "market_warden_post",
        "name": "Creek-Warden Post",
        "stable_id": "brookseed.landmark.market_warden_post",
        "source": "building_market_warden_post-source-v01.png",
        "processed": "building_market_warden_post-display-2048-v01.png",
        "background": "light_matte",
    },
    {
        "slug": "market_wharf",
        "name": "Moss-Stone Wharf",
        "stable_id": "brookseed.landmark.market_wharf",
        "source": "building_market_wharf-source-v01.png",
        "processed": "building_market_wharf-display-2048-v01.png",
        "background": "light_matte",
    },
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_light_neutral(pixel: tuple[int, int, int, int], strict: bool = False) -> bool:
    red, green, blue, _ = pixel
    low = min(red, green, blue)
    spread = max(red, green, blue) - low
    if strict:
        return low >= 235 and spread <= 10
    return low >= 222 and spread <= 18


def remove_light_matte(image: Image.Image) -> Image.Image:
    """Remove a white/checker matte without touching colored in-subject highlights.

    The generated building edge is dark and crisp. Background pixels are near-neutral
    values from 240 to 255. We first flood only edge-connected light-neutral pixels,
    then remove strict checker values anywhere so enclosed openings become transparent.
    """

    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    background = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def push(x: int, y: int) -> None:
        index = y * width + x
        if background[index] or not is_light_neutral(pixels[x, y]):
            return
        background[index] = 1
        queue.append((x, y))

    for x in range(width):
        push(x, 0)
        push(x, height - 1)
    for y in range(height):
        push(0, y)
        push(width - 1, y)

    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height:
                push(nx, ny)

    output = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    out = output.load()
    for y in range(height):
        row = y * width
        for x in range(width):
            pixel = pixels[x, y]
            if background[row + x] or is_light_neutral(pixel, strict=True):
                continue
            out[x, y] = (pixel[0], pixel[1], pixel[2], 255)
    return output


def normalize_native_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    output = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    source = rgba.load()
    target = output.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = source[x, y]
            if alpha >= 128:
                target[x, y] = (red, green, blue, 255)
    return output


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("image has no non-transparent subject")
    return bbox


def fit_on_canvas(image: Image.Image) -> tuple[Image.Image, dict[str, object]]:
    bbox = alpha_bbox(image)
    subject = image.crop(bbox)
    scale = min(MAX_SUBJECT_EDGE / subject.width, MAX_SUBJECT_EDGE / subject.height)
    size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(size, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    origin = ((CANVAS - size[0]) // 2, (CANVAS - size[1]) // 2)
    canvas.alpha_composite(subject, origin)
    final_bbox = alpha_bbox(canvas)
    return canvas, {
        "input_bbox": list(bbox),
        "scaled_subject_size": list(size),
        "output_bbox": list(final_bbox),
        "margins": {
            "left": final_bbox[0],
            "top": final_bbox[1],
            "right": CANVAS - final_bbox[2],
            "bottom": CANVAS - final_bbox[3],
        },
        "max_subject_ratio": max(size) / CANVAS,
    }


def image_metrics(image: Image.Image) -> dict[str, object]:
    rgba = image.convert("RGBA")
    alphas = rgba.getchannel("A")
    bbox = alpha_bbox(rgba)
    alpha_values = sorted(set(alphas.get_flattened_data()))
    transparent = 0
    opaque = 0
    intermediate = 0
    dirty_transparent_rgb = 0
    for red, green, blue, alpha in rgba.get_flattened_data():
        if alpha == 0:
            transparent += 1
            if red or green or blue:
                dirty_transparent_rgb += 1
        elif alpha == 255:
            opaque += 1
        else:
            intermediate += 1
    return {
        "width": rgba.width,
        "height": rgba.height,
        "mode": rgba.mode,
        "alpha_values": alpha_values,
        "transparent_pixels": transparent,
        "opaque_pixels": opaque,
        "intermediate_alpha_pixels": intermediate,
        "dirty_transparent_rgb": dirty_transparent_rgb,
        "bbox": list(bbox),
        "margins": {
            "left": bbox[0],
            "top": bbox[1],
            "right": rgba.width - bbox[2],
            "bottom": rgba.height - bbox[3],
        },
    }


def checkerboard(size: tuple[int, int], cell: int = 24) -> Image.Image:
    image = Image.new("RGB", size, (239, 233, 218))
    draw = ImageDraw.Draw(image)
    colors = ((239, 233, 218), (214, 224, 216))
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            color = colors[((x // cell) + (y // cell)) % 2]
            draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=color)
    return image


def build_contact_sheet(processed: list[dict[str, object]]) -> None:
    cell_width = 620
    cell_height = 580
    sheet = Image.new("RGB", (cell_width * 3, cell_height * 2), (38, 54, 56))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=24)
    for index, record in enumerate(processed):
        x = (index % 3) * cell_width
        y = (index // 3) * cell_height
        preview = checkerboard((cell_width - 40, cell_height - 90))
        asset = Image.open(record["processed_path"]).convert("RGBA")
        asset.thumbnail((cell_width - 80, cell_height - 130), Image.Resampling.NEAREST)
        origin = ((preview.width - asset.width) // 2, (preview.height - asset.height) // 2)
        preview.paste(asset, origin, asset)
        sheet.paste(preview, (x + 20, y + 20))
        draw.text((x + 24, y + cell_height - 56), f"{index + 1}. {record['name']}", fill=(240, 217, 173), font=font)
    draw.text((cell_width * 2 + 44, cell_height + 190), "N-013", fill=(240, 217, 173), font=font)
    draw.text((cell_width * 2 + 44, cell_height + 235), "2048 RGBA", fill=(181, 138, 82), font=font)
    output = CONTACT_DIR / "n-013-buildings-contact-sheet-v01.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, format="PNG", optimize=True)


def main() -> int:
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []
    failures: list[str] = []

    for asset in ASSETS:
        source_path = SOURCE_DIR / asset["source"]
        processed_path = PROCESSED_DIR / asset["processed"]
        source = Image.open(source_path)
        if asset["background"] == "native_alpha":
            cutout = normalize_native_alpha(source)
        else:
            cutout = remove_light_matte(source)
        final, placement = fit_on_canvas(cutout)
        final.save(processed_path, format="PNG", optimize=True)

        metrics = image_metrics(final)
        record = {
            **asset,
            "source_path": str(source_path.relative_to(ROOT)),
            "processed_path": str(processed_path),
            "processed_relative_path": str(processed_path.relative_to(ROOT)),
            "source_sha256": sha256(source_path),
            "processed_sha256": sha256(processed_path),
            "placement": placement,
            "metrics": metrics,
        }
        records.append(record)

        if metrics["width"] != CANVAS or metrics["height"] != CANVAS:
            failures.append(f"{asset['slug']}: not {CANVAS}x{CANVAS}")
        if metrics["mode"] != "RGBA":
            failures.append(f"{asset['slug']}: mode is not RGBA")
        if metrics["alpha_values"] != [0, 255]:
            failures.append(f"{asset['slug']}: alpha values are not binary")
        if metrics["dirty_transparent_rgb"] != 0:
            failures.append(f"{asset['slug']}: dirty transparent RGB")
        if min(metrics["margins"].values()) < 100:
            failures.append(f"{asset['slug']}: subject margin below 100 px")
        if not 0.80 <= placement["max_subject_ratio"] <= 0.86:
            failures.append(f"{asset['slug']}: max subject ratio outside 0.80-0.86")

    build_contact_sheet(records)
    report = {
        "task": "N-013",
        "canvas": [CANVAS, CANVAS],
        "required_mode": "RGBA",
        "required_alpha": [0, 255],
        "records": [{k: v for k, v in record.items() if k != "processed_path"} for record in records],
        "failures": failures,
        "result": "PASS" if not failures else "FAIL",
    }
    report_path = EVIDENCE_DIR / "validation-report.json"
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    manifest_path = TASK_ROOT / "manifest.json"
    manifest_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{report['result']} assets={len(records)} failures={len(failures)}")
    for failure in failures:
        print(f"FAIL {failure}")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
