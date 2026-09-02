#!/usr/bin/env python3
"""Independent read-path validator for IMG-OPT-R1 outputs."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "artifacts/integration/image-optimization-r1"
MANIFEST = PACKAGE / "manifest.json"
EXPECTED_COUNTS = {
    "concept": 53,
    "scene-anchor": 1,
    "pixel-display": 149,
    "portrait": 8,
    "building-display": 5,
}
EXPECTED_TOTAL = sum(EXPECTED_COUNTS.values())
MIN_MARGIN = 164


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def inspect(path: Path) -> dict[str, object]:
    with Image.open(path) as opened:
        mode = opened.mode
        rgba = opened.convert("RGBA")
    histogram = rgba.getchannel("A").histogram()
    alpha = [index for index, count in enumerate(histogram) if count]
    bbox = rgba.getchannel("A").getbbox()
    dirty = 0
    colors: set[tuple[int, int, int]] = set()
    for red, green, blue, value in rgba.get_flattened_data():
        if value == 0 and (red or green or blue):
            dirty += 1
        elif value == 255:
            colors.add((red, green, blue))
    return {
        "mode": mode,
        "width": rgba.width,
        "height": rgba.height,
        "alpha_values": alpha,
        "bbox": list(bbox) if bbox else None,
        "dirty_transparent_rgb": dirty,
        "colors": colors,
    }


def retained_colors(path: Path, threshold: int) -> set[tuple[int, int, int]]:
    with Image.open(path) as opened:
        rgba = opened.convert("RGBA")
    return {
        (red, green, blue)
        for red, green, blue, alpha in rgba.get_flattened_data()
        if alpha >= threshold
    }


def main() -> int:
    manifest = json.loads(MANIFEST.read_text())
    failures: list[dict[str, object]] = []
    counts = {key: 0 for key in EXPECTED_COUNTS}
    seen_outputs: set[str] = set()

    if manifest.get("total") != EXPECTED_TOTAL:
        failures.append({"scope": "manifest", "issue": f"total {manifest.get('total')} != {EXPECTED_TOTAL}"})
    if manifest.get("generative_redraw") is not False:
        failures.append({"scope": "manifest", "issue": "generative_redraw is not false"})

    for record in manifest["records"]:
        category = record["category"]
        if category not in counts:
            failures.append({"scope": record["output"], "issue": f"unknown category {category}"})
            continue
        counts[category] += 1
        if record["output"] in seen_outputs:
            failures.append({"scope": record["output"], "issue": "duplicate output"})
        seen_outputs.add(record["output"])

        source = ROOT / record["source"]
        output = ROOT / record["output"]
        issues: list[str] = []
        if not source.exists():
            issues.append("source missing")
        elif sha256(source) != record["source_sha256"]:
            issues.append("source hash changed")
        if not output.exists():
            issues.append("output missing")
        else:
            if sha256(output) != record["output_sha256"]:
                issues.append("output hash mismatch")
            metrics = inspect(output)
            if metrics["mode"] != "RGBA":
                issues.append(f"mode {metrics['mode']} != RGBA")
            if (metrics["width"], metrics["height"]) != (2048, 2048):
                issues.append(f"size {metrics['width']}x{metrics['height']}")
            if metrics["alpha_values"] != [0, 255]:
                issues.append(f"alpha {metrics['alpha_values']}")
            if metrics["dirty_transparent_rgb"]:
                issues.append("dirty transparent RGB")
            if metrics["bbox"] is None:
                issues.append("empty output")
            else:
                left, top, right, bottom = metrics["bbox"]
                margins = (left, top, 2048 - right, 2048 - bottom)
                if min(margins) < MIN_MARGIN:
                    issues.append(f"margin {min(margins)} < {MIN_MARGIN}")
            if source.exists():
                source_colors = retained_colors(source, int(record["alpha_threshold"]))
                new_colors = metrics["colors"] - source_colors
                if new_colors:
                    issues.append(f"introduced {len(new_colors)} colors")
        if issues:
            failures.append({"scope": record["output"], "issues": issues})

    if counts != EXPECTED_COUNTS:
        failures.append({"scope": "counts", "issue": f"{counts} != {EXPECTED_COUNTS}"})

    result = {
        "package": "IMG-OPT-R1",
        "review_role": "quality",
        "result": "APPROVED" if not failures else "REVISE",
        "counts": counts,
        "total": sum(counts.values()),
        "failures": failures,
        "checks": {
            "manifest_and_unique_outputs": not any(item.get("scope") in {"manifest", "counts"} for item in failures),
            "source_hashes_unchanged": not any("source hash changed" in item.get("issues", []) for item in failures),
            "rgba_2048_binary_alpha": not failures,
            "transparent_rgb_clean": not failures,
            "minimum_margin": MIN_MARGIN,
            "no_new_rgb_colors": not failures,
        },
    }
    (PACKAGE / "quality-validation.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    )
    print(
        f"QUALITY result={result['result']} total={result['total']} "
        f"concept={counts['concept']} pixel={counts['pixel-display']} "
        f"scene={counts['scene-anchor']} portraits={counts['portrait']} "
        f"buildings={counts['building-display']} "
        f"failures={len(failures)}"
    )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
