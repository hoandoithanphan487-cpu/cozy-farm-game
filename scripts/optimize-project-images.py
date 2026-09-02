#!/usr/bin/env python3
"""Create non-destructive 2048 RGBA review derivatives for approved project art.

This script intentionally performs no generative redraw. It preserves source RGB
values, hardens approved soft alpha, uses nearest-neighbor resampling, and writes
only under artifacts/integration/image-optimization-r1/.
"""

from __future__ import annotations

import hashlib
import json
import math
from collections import defaultdict, deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_ROOT = ROOT / "artifacts/integration/image-optimization-r1"
OPTIMIZED_ROOT = OUTPUT_ROOT / "optimized"
CONTACT_ROOT = OUTPUT_ROOT / "contact-sheets"
CANVAS = 2048
MAX_SUBJECT_EDGE = 1720
MIN_MARGIN = (CANVAS - MAX_SUBJECT_EDGE) // 2

CONCEPT_ROOT = ROOT / "artifacts/art-style"
RUNTIME_MANIFEST = ROOT / "artifacts/art-style/runtime-batch-r0/manifest.json"
RUNTIME_ASSET_ROOT = ROOT / "macos/CreekSprout/CreekSprout/Assets"
CANDIDATE_ASSET_ROOT = ROOT / "artifacts/art-style/candidates/runtime-r0"
PORTRAIT_MANIFEST = ROOT / "artifacts/integration/n-009-portraits/manifest.json"
BUILDING_MANIFEST = ROOT / "artifacts/integration/n-013-buildings/manifest.json"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("empty alpha subject")
    return bbox


def alpha_values(image: Image.Image) -> list[int]:
    histogram = image.getchannel("A").histogram()
    return [index for index, count in enumerate(histogram) if count]


def choose_threshold(image: Image.Image) -> int:
    values = alpha_values(image)
    if set(values).issubset({0, 255}):
        return 1
    return 128


def clean_binary_alpha(image: Image.Image, threshold: int) -> Image.Image:
    rgba = image.convert("RGBA")
    source_rgb = rgba.convert("RGB")
    binary_alpha = rgba.getchannel("A").point(
        lambda value: 255 if value >= threshold else 0
    )
    clean_rgb = Image.composite(
        source_rgb,
        Image.new("RGB", rgba.size, (0, 0, 0)),
        binary_alpha,
    )
    red, green, blue = clean_rgb.split()
    return Image.merge("RGBA", (red, green, blue, binary_alpha))


def extract_edge_connected_matte(image: Image.Image) -> Image.Image:
    """Remove an RGB presentation matte using only edge-connected background pixels.

    Legacy C0 files use either a light-neutral checkerboard or a warm paper matte.
    The predicate is derived from border samples, while flood connectivity prevents
    similarly colored enclosed subject details from being removed.
    """

    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    border: list[tuple[int, int, int]] = []
    step = max(1, min(width, height) // 256)
    for x in range(0, width, step):
        border.append(pixels[x, 0])
        border.append(pixels[x, height - 1])
    for y in range(0, height, step):
        border.append(pixels[0, y])
        border.append(pixels[width - 1, y])
    channels = [sorted(sample[index] for sample in border) for index in range(3)]
    median = tuple(channel[len(channel) // 2] for channel in channels)
    light_neutral = min(median) >= 220 and max(median) - min(median) <= 24

    def is_background(pixel: tuple[int, int, int]) -> bool:
        if light_neutral:
            return min(pixel) >= 224 and max(pixel) - min(pixel) <= 26
        distance = sum((pixel[index] - median[index]) ** 2 for index in range(3)) ** 0.5
        return distance <= 58

    background = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def push(x: int, y: int) -> None:
        index = y * width + x
        if background[index] or not is_background(pixels[x, y]):
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

    alpha = Image.new("L", rgb.size, 255)
    alpha_data = alpha.load()
    for y in range(height):
        row = y * width
        for x in range(width):
            if background[row + x]:
                alpha_data[x, y] = 0
    clean_rgb = Image.composite(rgb, Image.new("RGB", rgb.size, (0, 0, 0)), alpha)
    red, green, blue = clean_rgb.split()
    return Image.merge("RGBA", (red, green, blue, alpha))


def fit_on_canvas(image: Image.Image, integer_scale: bool) -> tuple[Image.Image, dict[str, object]]:
    input_bbox = alpha_bbox(image)
    subject = image.crop(input_bbox)
    if integer_scale:
        scale = max(1, math.floor(MAX_SUBJECT_EDGE / max(subject.size)))
        output_size = (subject.width * scale, subject.height * scale)
    else:
        scale = min(MAX_SUBJECT_EDGE / subject.width, MAX_SUBJECT_EDGE / subject.height)
        output_size = (
            max(1, round(subject.width * scale)),
            max(1, round(subject.height * scale)),
        )
    if subject.size != output_size:
        subject = subject.resize(output_size, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    origin = ((CANVAS - subject.width) // 2, (CANVAS - subject.height) // 2)
    canvas.alpha_composite(subject, origin)
    output_bbox = alpha_bbox(canvas)
    placement = {
        "input_bbox": list(input_bbox),
        "output_bbox": list(output_bbox),
        "subject_size": list(subject.size),
        "scale": scale,
        "integer_scale": integer_scale,
        "margins": {
            "left": output_bbox[0],
            "top": output_bbox[1],
            "right": CANVAS - output_bbox[2],
            "bottom": CANVAS - output_bbox[3],
        },
    }
    return canvas, placement


def rgba_metrics(image: Image.Image) -> dict[str, object]:
    rgba = image.convert("RGBA")
    histogram = rgba.getchannel("A").histogram()
    bbox = alpha_bbox(rgba)
    dirty_transparent_rgb = 0
    opaque_colors: set[tuple[int, int, int]] = set()
    for red, green, blue, alpha in rgba.get_flattened_data():
        if alpha == 0:
            if red or green or blue:
                dirty_transparent_rgb += 1
        elif alpha == 255:
            opaque_colors.add((red, green, blue))
    return {
        "width": rgba.width,
        "height": rgba.height,
        "mode": rgba.mode,
        "alpha_values": [index for index, count in enumerate(histogram) if count],
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
        "opaque_color_count": len(opaque_colors),
    }


def retained_source_colors(image: Image.Image, threshold: int) -> set[tuple[int, int, int]]:
    return {
        (red, green, blue)
        for red, green, blue, alpha in image.convert("RGBA").get_flattened_data()
        if alpha >= threshold
    }


def output_colors(image: Image.Image) -> set[tuple[int, int, int]]:
    return {
        (red, green, blue)
        for red, green, blue, alpha in image.convert("RGBA").get_flattened_data()
        if alpha == 255
    }


def process_one(
    *,
    category: str,
    group: str,
    source: Path,
    output: Path,
    integer_scale: bool,
    preserve_full_frame: bool = False,
) -> dict[str, object]:
    with Image.open(source) as opened:
        source_mode = opened.mode
        has_alpha = "A" in opened.getbands()
        source_image = opened.convert("RGBA")
    if preserve_full_frame:
        threshold = 255
        retained_colors = {
            (red, green, blue)
            for red, green, blue, _ in source_image.get_flattened_data()
        }
        cleaned = source_image
        extraction_method = "opaque-full-frame"
    elif has_alpha:
        threshold = choose_threshold(source_image)
        retained_colors = retained_source_colors(source_image, threshold)
        cleaned = clean_binary_alpha(source_image, threshold)
        extraction_method = "binary-alpha-threshold"
    else:
        threshold = 255
        retained_colors = {
            (red, green, blue)
            for red, green, blue, _ in source_image.get_flattened_data()
        }
        cleaned = extract_edge_connected_matte(source_image)
        extraction_method = "edge-connected-border-matte"
    final, placement = fit_on_canvas(cleaned, integer_scale)
    final_colors = output_colors(final)
    new_colors = sorted(final_colors - retained_colors)
    output.parent.mkdir(parents=True, exist_ok=True)
    final.save(output, format="PNG", optimize=True)
    metrics = rgba_metrics(final)
    failures: list[str] = []
    if metrics["width"] != CANVAS or metrics["height"] != CANVAS:
        failures.append("canvas is not 2048x2048")
    if metrics["alpha_values"] != [0, 255]:
        failures.append(f"alpha values are {metrics['alpha_values']}")
    if metrics["dirty_transparent_rgb"]:
        failures.append("dirty transparent RGB")
    if min(metrics["margins"].values()) < MIN_MARGIN:
        failures.append(f"margin below {MIN_MARGIN}")
    if new_colors:
        failures.append(f"introduced {len(new_colors)} RGB colors")
    return {
        "category": category,
        "group": group,
        "source": str(source.relative_to(ROOT)),
        "source_sha256": sha256(source),
        "source_width": source_image.width,
        "source_height": source_image.height,
        "source_mode": source_mode,
        "extraction_method": extraction_method,
        "alpha_threshold": threshold,
        "retained_source_color_count": len(retained_colors),
        "output": str(output.relative_to(ROOT)),
        "output_sha256": sha256(output),
        "output_color_count": len(final_colors),
        "new_color_count": len(new_colors),
        "placement": placement,
        "metrics": metrics,
        "failures": failures,
    }


def source_jobs() -> list[dict[str, object]]:
    jobs: list[dict[str, object]] = []
    for source in sorted(CONCEPT_ROOT.rglob("concept_*.png")):
        relative = source.relative_to(CONCEPT_ROOT)
        output_name = f"{source.stem}_optimized_2048_v02.png"
        jobs.append(
            {
                "category": "concept",
                "group": relative.parts[0],
                "source": source,
                "output": OPTIMIZED_ROOT / "concepts" / relative.parent / output_name,
                "integer_scale": False,
            }
        )

    visual_anchor = CONCEPT_ROOT / "visual-anchor-warm-medieval-v1.png"
    jobs.append(
        {
            "category": "scene-anchor",
            "group": "warm-medieval-v1",
            "source": visual_anchor,
            "output": OPTIMIZED_ROOT / "scene-anchors" / "visual-anchor-warm-medieval-v1_optimized_2048_v02.png",
            "integer_scale": False,
            "preserve_full_frame": True,
        }
    )

    runtime_manifest = json.loads(RUNTIME_MANIFEST.read_text())
    for asset in runtime_manifest["assets"]:
        scope = asset["scope"]
        base = RUNTIME_ASSET_ROOT if scope == "runtime" else CANDIDATE_ASSET_ROOT
        source = base / asset["file"]
        jobs.append(
            {
                "category": "pixel-display",
                "group": scope,
                "source": source,
                "output": OPTIMIZED_ROOT / "pixel-display" / scope / f"{source.stem}_display_2048_v01.png",
                "integer_scale": True,
            }
        )

    portrait_manifest = json.loads(PORTRAIT_MANIFEST.read_text())
    for asset in portrait_manifest["assets"]:
        source = ROOT / asset["processed"]["path"]
        jobs.append(
            {
                "category": "portrait",
                "group": "n-009-full-body",
                "source": source,
                "output": OPTIMIZED_ROOT / "portraits" / f"portrait_{asset['slug']}_optimized_2048_v02.png",
                "integer_scale": False,
            }
        )

    building_manifest = json.loads(BUILDING_MANIFEST.read_text())
    for asset in building_manifest["records"]:
        source = ROOT / asset["processed_relative_path"]
        jobs.append(
            {
                "category": "building-display",
                "group": "n-013-buildings",
                "source": source,
                "output": OPTIMIZED_ROOT / "buildings" / f"building_{asset['slug']}_optimized_2048_v02.png",
                "integer_scale": False,
            }
        )
    return jobs


def checkerboard(size: tuple[int, int], cell: int = 20) -> Image.Image:
    image = Image.new("RGB", size, (238, 232, 216))
    draw = ImageDraw.Draw(image)
    colors = ((238, 232, 216), (210, 221, 213))
    for y in range(0, size[1], cell):
        for x in range(0, size[0], cell):
            draw.rectangle(
                (x, y, min(x + cell - 1, size[0] - 1), min(y + cell - 1, size[1] - 1)),
                fill=colors[((x // cell) + (y // cell)) % 2],
            )
    return image


def contact_sheets(records: list[dict[str, object]]) -> list[str]:
    groups: dict[str, list[dict[str, object]]] = defaultdict(list)
    for record in records:
        groups[f"{record['category']}-{record['group']}"] .append(record)
    outputs: list[str] = []
    columns, rows = 4, 3
    cell_width, cell_height = 420, 420
    page_size = columns * rows
    font = ImageFont.load_default(size=17)
    CONTACT_ROOT.mkdir(parents=True, exist_ok=True)
    for group, items in sorted(groups.items()):
        for page_index in range(math.ceil(len(items) / page_size)):
            page_items = items[page_index * page_size:(page_index + 1) * page_size]
            sheet = Image.new("RGB", (columns * cell_width, rows * cell_height), (38, 54, 56))
            draw = ImageDraw.Draw(sheet)
            for index, record in enumerate(page_items):
                column = index % columns
                row = index // columns
                x = column * cell_width
                y = row * cell_height
                preview = checkerboard((cell_width - 24, cell_height - 64))
                with Image.open(ROOT / record["output"]) as opened:
                    asset = opened.convert("RGBA")
                asset.thumbnail((preview.width - 32, preview.height - 32), Image.Resampling.NEAREST)
                origin = ((preview.width - asset.width) // 2, (preview.height - asset.height) // 2)
                preview.paste(asset, origin, asset)
                sheet.paste(preview, (x + 12, y + 12))
                label = Path(record["source"]).stem[:48]
                draw.text((x + 14, y + cell_height - 43), label, font=font, fill=(240, 217, 173))
            output = CONTACT_ROOT / f"{group}-contact-{page_index + 1:02}.png"
            sheet.save(output, format="PNG", optimize=True)
            outputs.append(str(output.relative_to(ROOT)))
    return outputs


def main() -> int:
    jobs = source_jobs()
    expected = {
        "concept": 53,
        "scene-anchor": 1,
        "pixel-display": 149,
        "portrait": 8,
        "building-display": 5,
    }
    actual: dict[str, int] = defaultdict(int)
    for job in jobs:
        actual[str(job["category"])] += 1
    if dict(actual) != expected:
        raise SystemExit(f"input count mismatch: actual={dict(actual)} expected={expected}")

    records = [process_one(**job) for job in jobs]
    contacts = contact_sheets(records)
    failures = [
        {"output": record["output"], "failures": record["failures"]}
        for record in records
        if record["failures"]
    ]
    manifest = {
        "package": "IMG-OPT-R1",
        "method": "deterministic alpha cleanup + nearest-neighbor 2048 normalization",
        "generative_redraw": False,
        "canvas": [CANVAS, CANVAS],
        "max_subject_edge": MAX_SUBJECT_EDGE,
        "minimum_margin": MIN_MARGIN,
        "counts": dict(actual),
        "total": len(records),
        "contact_sheets": contacts,
        "failures": failures,
        "records": records,
    }
    manifest_path = OUTPUT_ROOT / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    report = {
        "package": "IMG-OPT-R1",
        "result": "PASS" if not failures else "FAIL",
        "total": len(records),
        "counts": dict(actual),
        "failure_count": len(failures),
        "checks": [
            "2048x2048 RGBA",
            "binary alpha",
            "transparent RGB cleared",
            f"minimum {MIN_MARGIN}px margin",
            "no RGB colors introduced",
            "source files not overwritten",
        ],
    }
    (OUTPUT_ROOT / "production-validation.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    )
    print(
        f"IMG_OPT result={report['result']} total={len(records)} "
        f"concept={actual['concept']} pixel={actual['pixel-display']} "
        f"scene={actual['scene-anchor']} portraits={actual['portrait']} "
        f"buildings={actual['building-display']} "
        f"failures={len(failures)} contacts={len(contacts)}"
    )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
