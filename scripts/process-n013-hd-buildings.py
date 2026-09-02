#!/usr/bin/env python3
"""Process N-013 R2 storybook building art into 2048px RGBA assets.

The built-in image generator may return an RGB PNG with a baked light checker
matte. This script removes only neutral matte pixels, preserves the generated
building, fits it on a transparent 2048px canvas with Lanczos resampling, and
writes reproducible validation evidence for the HD Presentation lane.
"""

from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
TASK_ROOT = ROOT / "artifacts/integration/n-013-buildings/r2-hd-presentation"
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
        "source": "building_farm_house-source-v02.png",
        "processed": "building_farm_house-display-2048-v02.png",
        "enclosed_matte_min_pixels": None,
    },
    {
        "slug": "farm_sluice",
        "name": "Bronze-Gate Waterworks",
        "stable_id": "brookseed.landmark.farm_sluice",
        "source": "building_farm_sluice-source-v02.png",
        "processed": "building_farm_sluice-display-2048-v02.png",
        "enclosed_matte_min_pixels": None,
    },
    {
        "slug": "market_seed_shed",
        "name": "Seed Shed",
        "stable_id": "brookseed.landmark.market_seed_shed",
        "source": "building_market_seed_shed-source-v02.png",
        "processed": "building_market_seed_shed-display-2048-v02.png",
        "enclosed_matte_min_pixels": 1000,
    },
    {
        "slug": "market_warden_post",
        "name": "Creek-Warden Post",
        "stable_id": "brookseed.landmark.market_warden_post",
        "source": "building_market_warden_post-source-v02.png",
        "processed": "building_market_warden_post-display-2048-v02.png",
        "enclosed_matte_min_pixels": 1000,
    },
    {
        "slug": "market_wharf",
        "name": "Moss-Stone Wharf",
        "stable_id": "brookseed.landmark.market_wharf",
        "source": "building_market_wharf-source-v02.png",
        "processed": "building_market_wharf-display-2048-v02.png",
        "enclosed_matte_min_pixels": None,
    },
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def is_matte(pixel: tuple[int, int, int, int], *, strict: bool = False) -> bool:
    red, green, blue, _ = pixel
    low = min(red, green, blue)
    spread = max(red, green, blue) - low
    if strict:
        return low >= 230 and spread <= 8
    return low >= 220 and spread <= 18


def remove_light_checker_matte(
    image: Image.Image, enclosed_matte_min_pixels: int | None
) -> Image.Image:
    """Remove edge-connected and enclosed baked checkerboard pixels.

    The generated subjects use colored materials plus dark outlines, while the
    checker matte is very light and nearly neutral. Edge flood fill identifies
    the exterior. A stricter neutral test removes enclosed checker cells inside
    doors, windows, wheel spokes, and net openings without keying out warm stone,
    cloth, or painted highlights.
    """

    rgba = image.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()
    exterior = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def push(x: int, y: int) -> None:
        index = y * width + x
        if exterior[index] or not is_matte(pixels[x, y]):
            return
        exterior[index] = 1
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

    enclosed = bytearray(width * height)
    if enclosed_matte_min_pixels is not None:
        visited = bytearray(width * height)
        for y in range(height):
            for x in range(width):
                index = y * width + x
                if exterior[index] or visited[index] or not is_matte(pixels[x, y], strict=True):
                    continue
                visited[index] = 1
                component = [(x, y)]
                component_queue: deque[tuple[int, int]] = deque([(x, y)])
                while component_queue:
                    cx, cy = component_queue.popleft()
                    for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                        if not (0 <= nx < width and 0 <= ny < height):
                            continue
                        neighbor = ny * width + nx
                        if (
                            exterior[neighbor]
                            or visited[neighbor]
                            or not is_matte(pixels[nx, ny], strict=True)
                        ):
                            continue
                        visited[neighbor] = 1
                        component.append((nx, ny))
                        component_queue.append((nx, ny))
                if len(component) >= enclosed_matte_min_pixels:
                    for cx, cy in component:
                        enclosed[cy * width + cx] = 1

    output = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    target = output.load()
    for y in range(height):
        row = y * width
        for x in range(width):
            pixel = pixels[x, y]
            if exterior[row + x] or enclosed[row + x]:
                continue
            target[x, y] = (pixel[0], pixel[1], pixel[2], 255)
    return output


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("image has no non-transparent subject")
    return bbox


def clean_transparent_rgb(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    transparent = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    transparent.alpha_composite(rgba)
    return transparent


def fit_on_canvas(image: Image.Image) -> tuple[Image.Image, dict[str, object]]:
    bbox = alpha_bbox(image)
    subject = image.crop(bbox)
    scale = min(MAX_SUBJECT_EDGE / subject.width, MAX_SUBJECT_EDGE / subject.height)
    size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    origin = ((CANVAS - size[0]) // 2, (CANVAS - size[1]) // 2)
    canvas.alpha_composite(subject, origin)
    canvas = clean_transparent_rgb(canvas)
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
        "resampling": "Pillow.Image.Resampling.LANCZOS",
    }


def image_metrics(image: Image.Image) -> dict[str, object]:
    rgba = image.convert("RGBA")
    histogram = rgba.getchannel("A").histogram()
    bbox = alpha_bbox(rgba)
    dirty_transparent_rgb = 0
    for red, green, blue, alpha in rgba.get_flattened_data():
        if alpha == 0 and (red or green or blue):
            dirty_transparent_rgb += 1
    return {
        "width": rgba.width,
        "height": rgba.height,
        "mode": rgba.mode,
        "alpha_min": next(index for index, count in enumerate(histogram) if count),
        "alpha_max": max(index for index, count in enumerate(histogram) if count),
        "transparent_pixels": histogram[0],
        "opaque_pixels": histogram[255],
        "intermediate_alpha_pixels": sum(histogram[1:255]),
        "dirty_transparent_rgb": dirty_transparent_rgb,
        "bbox": list(bbox),
        "margins": {
            "left": bbox[0],
            "top": bbox[1],
            "right": rgba.width - bbox[2],
            "bottom": rgba.height - bbox[3],
        },
    }


def checkerboard(size: tuple[int, int], cell: int = 20) -> Image.Image:
    image = Image.new("RGB", size, (239, 233, 218))
    draw = ImageDraw.Draw(image)
    colors = ((239, 233, 218), (214, 224, 216))
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            color = colors[((x // cell) + (y // cell)) % 2]
            draw.rectangle((x, y, x + cell - 1, y + cell - 1), fill=color)
    return image


def build_contact_sheet(records: list[dict[str, object]]) -> Path:
    cell_width = 720
    cell_height = 700
    sheet = Image.new("RGB", (cell_width * 3, cell_height * 2), (38, 54, 56))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=26)
    for index, record in enumerate(records):
        x = (index % 3) * cell_width
        y = (index // 3) * cell_height
        preview = checkerboard((cell_width - 40, cell_height - 90))
        with Image.open(record["processed_path"]) as opened:
            asset = opened.convert("RGBA")
        asset.thumbnail((cell_width - 70, cell_height - 125), Image.Resampling.LANCZOS)
        origin = ((preview.width - asset.width) // 2, (preview.height - asset.height) // 2)
        preview.paste(asset, origin, asset)
        sheet.paste(preview, (x + 20, y + 20))
        draw.text(
            (x + 24, y + cell_height - 54),
            f"{index + 1}. {record['name']}",
            fill=(240, 217, 173),
            font=font,
        )
    draw.text((cell_width * 2 + 44, cell_height + 220), "N-013 R2", fill=(240, 217, 173), font=font)
    draw.text((cell_width * 2 + 44, cell_height + 270), "HD Presentation", fill=(181, 138, 82), font=font)
    draw.text((cell_width * 2 + 44, cell_height + 320), "2048 RGBA", fill=(181, 138, 82), font=font)
    output = CONTACT_DIR / "n-013-buildings-hd-contact-sheet-v02.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, format="PNG", optimize=True)
    return output


def main() -> int:
    PROCESSED_DIR.mkdir(parents=True, exist_ok=True)
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []
    failures: list[str] = []

    for asset in ASSETS:
        source_path = SOURCE_DIR / asset["source"]
        processed_path = PROCESSED_DIR / asset["processed"]
        with Image.open(source_path) as opened:
            cutout = remove_light_checker_matte(opened, asset["enclosed_matte_min_pixels"])
        final, placement = fit_on_canvas(cutout)
        final.save(processed_path, format="PNG", optimize=True)
        metrics = image_metrics(final)
        records.append(
            {
                **asset,
                "source_path": str(source_path.relative_to(ROOT)),
                "processed_path": str(processed_path),
                "processed_relative_path": str(processed_path.relative_to(ROOT)),
                "source_sha256": sha256(source_path),
                "processed_sha256": sha256(processed_path),
                "processing": "edge-connected light checker matte removal + Lanczos 2048 fit",
                "placement": placement,
                "metrics": metrics,
            }
        )

        if (metrics["width"], metrics["height"]) != (CANVAS, CANVAS):
            failures.append(f"{asset['slug']}: not {CANVAS}x{CANVAS}")
        if metrics["mode"] != "RGBA":
            failures.append(f"{asset['slug']}: mode is not RGBA")
        if metrics["alpha_min"] != 0 or metrics["alpha_max"] != 255:
            failures.append(f"{asset['slug']}: alpha endpoints are not 0 and 255")
        if metrics["intermediate_alpha_pixels"] == 0:
            failures.append(f"{asset['slug']}: no anti-aliased alpha transition")
        if metrics["dirty_transparent_rgb"] != 0:
            failures.append(f"{asset['slug']}: dirty transparent RGB")
        if min(metrics["margins"].values()) < 100:
            failures.append(f"{asset['slug']}: subject margin below 100px")
        if not 0.80 <= placement["max_subject_ratio"] <= 0.86:
            failures.append(f"{asset['slug']}: max subject ratio outside 0.80-0.86")

    contact_sheet = build_contact_sheet(records)
    report = {
        "task": "N-013",
        "round": "R2 HD Presentation",
        "canvas": [CANVAS, CANVAS],
        "required_mode": "RGBA",
        "alpha_contract": "transparent background, opaque subject, anti-aliased edge transition",
        "records": [{k: v for k, v in record.items() if k != "processed_path"} for record in records],
        "contact_sheet": str(contact_sheet.relative_to(ROOT)),
        "failures": failures,
        "result": "PASS" if not failures else "FAIL",
    }
    (EVIDENCE_DIR / "validation-report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    (TASK_ROOT / "manifest.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"{report['result']} assets={len(records)} failures={len(failures)}")
    for record in records:
        metrics = record["metrics"]
        print(
            f"{record['slug']}: bbox={metrics['bbox']} margins={metrics['margins']} "
            f"alpha=({metrics['alpha_min']},{metrics['alpha_max']}) "
            f"intermediate={metrics['intermediate_alpha_pixels']}"
        )
    for failure in failures:
        print(f"FAIL {failure}")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
