#!/usr/bin/env python3
"""Process N-014 cat barbecue HD sources into validated 2048 RGBA assets."""

from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
TASK_ROOT = ROOT / "artifacts/integration/n-014-cat-bbq-hd"
SOURCE_DIR = TASK_ROOT / "source"
PROCESSED_DIR = TASK_ROOT / "processed"
EVIDENCE_DIR = TASK_ROOT / "evidence"
CONTACT_DIR = TASK_ROOT / "contact-sheet"

CANVAS = 2048
MAX_SUBJECT_EDGE = 1720
MIN_FOREGROUND_COMPONENT = 100

ASSETS = (
    {
        "slug": "cat_bbq_shop",
        "name": "Creekfire Cat Eatery",
        "kind": "building",
        "source": "cat_bbq_shop-source-v02.png",
        "processed": "cat_bbq_shop-display-2048-v02.png",
    },
    {
        "slug": "cat_staff_black",
        "name": "Black Cat Cook",
        "kind": "character",
        "source": "cat_staff_black-source-v02.png",
        "processed": "cat_staff_black-fullbody-2048-v02.png",
    },
    {
        "slug": "cat_staff_calico",
        "name": "Calico Cat Server",
        "kind": "character",
        "source": "cat_staff_calico-source-v02.png",
        "processed": "cat_staff_calico-fullbody-2048-v02.png",
    },
    {
        "slug": "cat_staff_white_ragdoll",
        "name": "White Ragdoll Seasoning Specialist",
        "kind": "character",
        "source": "cat_staff_white_ragdoll-source-v02.png",
        "processed": "cat_staff_white_ragdoll-fullbody-2048-v02.png",
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


def remove_light_checker_matte(image: Image.Image) -> Image.Image:
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

    # Remove large enclosed checker regions while preserving small pale highlights.
    enclosed = bytearray(width * height)
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
            if len(component) >= 1000:
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


def remove_small_foreground_components(image: Image.Image) -> tuple[Image.Image, int]:
    rgba = image.convert("RGBA")
    width, height = rgba.size
    alpha = rgba.getchannel("A")
    alpha_pixels = alpha.load()
    source = rgba.load()
    visited = bytearray(width * height)
    components: list[list[tuple[int, int]]] = []

    for y in range(height):
        for x in range(width):
            index = y * width + x
            if visited[index] or alpha_pixels[x, y] == 0:
                continue
            visited[index] = 1
            component = [(x, y)]
            queue: deque[tuple[int, int]] = deque([(x, y)])
            while queue:
                cx, cy = queue.popleft()
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if not (0 <= nx < width and 0 <= ny < height):
                        continue
                    neighbor = ny * width + nx
                    if visited[neighbor] or alpha_pixels[nx, ny] == 0:
                        continue
                    visited[neighbor] = 1
                    component.append((nx, ny))
                    queue.append((nx, ny))
            components.append(component)

    kept = [component for component in components if len(component) >= MIN_FOREGROUND_COMPONENT]
    output = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    target = output.load()
    for component in kept:
        for x, y in component:
            target[x, y] = source[x, y]
    return output, len(components) - len(kept)


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("image has no non-transparent subject")
    return bbox


def fit_on_canvas(image: Image.Image) -> tuple[Image.Image, dict[str, object]]:
    bbox = alpha_bbox(image)
    subject = image.crop(bbox)
    scale = min(MAX_SUBJECT_EDGE / subject.width, MAX_SUBJECT_EDGE / subject.height)
    size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(size, Image.Resampling.LANCZOS)
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


def checkerboard(size: tuple[int, int], cell: int = 22) -> Image.Image:
    image = Image.new("RGB", size, (239, 233, 218))
    draw = ImageDraw.Draw(image)
    colors = ((239, 233, 218), (214, 224, 216))
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            draw.rectangle(
                (x, y, x + cell - 1, y + cell - 1),
                fill=colors[((x // cell) + (y // cell)) % 2],
            )
    return image


def build_contact_sheet(records: list[dict[str, object]]) -> Path:
    cell_width = 900
    cell_height = 900
    sheet = Image.new("RGB", (cell_width * 2, cell_height * 2), (38, 54, 56))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=28)
    for index, record in enumerate(records):
        x = (index % 2) * cell_width
        y = (index // 2) * cell_height
        preview = checkerboard((cell_width - 40, cell_height - 100))
        with Image.open(record["processed_path"]) as opened:
            asset = opened.convert("RGBA")
        asset.thumbnail((cell_width - 80, cell_height - 150), Image.Resampling.LANCZOS)
        origin = ((preview.width - asset.width) // 2, (preview.height - asset.height) // 2)
        preview.paste(asset, origin, asset)
        sheet.paste(preview, (x + 20, y + 20))
        draw.text(
            (x + 26, y + cell_height - 60),
            f"{index + 1}. {record['name']}",
            fill=(240, 217, 173),
            font=font,
        )
    output = CONTACT_DIR / "n-014-cat-bbq-hd-contact-sheet-v02.png"
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
            cutout = remove_light_checker_matte(opened)
        cutout, removed_components = remove_small_foreground_components(cutout)
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
                "processing": "light-checker matte removal + small-component cleanup + Lanczos 2048 fit",
                "removed_small_foreground_components": removed_components,
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
        "task": "N-014",
        "round": "HD Presentation v02",
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
            f"intermediate={metrics['intermediate_alpha_pixels']} "
            f"removed_components={record['removed_small_foreground_components']}"
        )
    for failure in failures:
        print(f"FAIL {failure}")
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
