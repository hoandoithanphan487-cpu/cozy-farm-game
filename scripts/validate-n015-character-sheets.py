#!/usr/bin/env python3
"""Validate portrait-derived N-015 runtime character assets."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


CHARACTERS = (
    "player",
    "water_apprentice",
    "seed_steward",
    "creek_warden",
    "neighbor_hearsay",
    "neighbor_storyteller",
    "neighbor_evidence",
    "neighbor_consensus",
)
ACTIONS = ("hoe", "watering_can", "harvest_glove")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_png(path: Path, expected_size: tuple[int, int], palette_limit: int) -> dict[str, object]:
    errors: list[str] = []
    if not path.is_file():
        return {"path": str(path), "errors": ["missing"]}

    image = Image.open(path)
    if image.mode != "RGBA":
        errors.append(f"mode {image.mode}, expected RGBA")
    rgba = image.convert("RGBA")
    if rgba.size != expected_size:
        errors.append(f"size {rgba.size}, expected {expected_size}")

    alpha_values = set(rgba.getchannel("A").getdata())
    if not alpha_values.issubset({0, 255}):
        errors.append(f"soft alpha values: {sorted(alpha_values - {0, 255})[:8]}")

    transparent_rgb_clean = all(
        alpha != 0 or (red, green, blue) == (0, 0, 0)
        for red, green, blue, alpha in rgba.getdata()
    )
    if not transparent_rgb_clean:
        errors.append("transparent pixels contain non-zero RGB")

    opaque_colors = {(red, green, blue) for red, green, blue, alpha in rgba.getdata() if alpha == 255}
    if len(opaque_colors) > palette_limit:
        errors.append(f"opaque palette {len(opaque_colors)}, limit {palette_limit}")

    result: dict[str, object] = {
        "path": str(path),
        "size": list(rgba.size),
        "mode": image.mode,
        "opaque_palette": len(opaque_colors),
        "alpha_values": sorted(alpha_values),
        "transparent_rgb_clean": transparent_rgb_clean,
        "sha256": sha256(path),
        "errors": errors,
    }

    if rgba.size == (128, 192):
        frame_hashes: list[list[str]] = []
        frame_bottoms: list[list[int]] = []
        for row in range(4):
            row_hashes: list[str] = []
            row_bottoms: list[int] = []
            for column in range(4):
                frame = rgba.crop((column * 32, row * 48, column * 32 + 32, row * 48 + 48))
                bbox = frame.getchannel("A").getbbox()
                if bbox is None:
                    errors.append(f"empty frame row={row} column={column}")
                    row_bottoms.append(-1)
                else:
                    row_bottoms.append(bbox[3])
                    if bbox[3] not in {47, 48}:
                        errors.append(f"unstable baseline row={row} column={column}: bottom={bbox[3]}")
                row_hashes.append(hashlib.sha256(frame.tobytes()).hexdigest())
            if len(set(row_hashes)) < 3:
                errors.append(f"row {row} has fewer than three distinct animation frames")
            frame_hashes.append(row_hashes)
            frame_bottoms.append(row_bottoms)
        result["frame_hashes"] = frame_hashes
        result["frame_bottoms"] = frame_bottoms

    return result


def validate_directory(asset_dir: Path) -> dict[str, object]:
    records: list[dict[str, object]] = []
    errors: list[str] = []
    for slug in CHARACTERS:
        idle_path = asset_dir / f"char_{slug}.png"
        walk_path = asset_dir / f"char_{slug}_walk.png"
        idle = validate_png(idle_path, (32, 48), 36)
        walk = validate_png(walk_path, (128, 192), 36)
        records.extend((idle, walk))
        errors.extend(f"{Path(record['path']).name}: {error}" for record in (idle, walk) for error in record["errors"])
        if not idle["errors"] and not walk["errors"]:
            idle_pixels = Image.open(idle_path).convert("RGBA").tobytes()
            first_frame = Image.open(walk_path).convert("RGBA").crop((0, 0, 32, 48)).tobytes()
            if idle_pixels != first_frame:
                errors.append(f"char_{slug}.png does not match down/idle frame zero")

    for action in ACTIONS:
        record = validate_png(asset_dir / f"char_player_action_{action}.png", (128, 192), 40)
        records.append(record)
        errors.extend(f"{Path(record['path']).name}: {error}" for error in record["errors"])

    return {"asset_dir": str(asset_dir), "records": records, "errors": errors}


def compare_directories(processed: Path, runtime: Path) -> list[str]:
    errors: list[str] = []
    names = [f"char_{slug}{suffix}.png" for slug in CHARACTERS for suffix in ("", "_walk")]
    names.extend(f"char_player_action_{action}.png" for action in ACTIONS)
    for name in names:
        left, right = processed / name, runtime / name
        if not right.is_file():
            errors.append(f"runtime missing {name}")
        elif sha256(left) != sha256(right):
            errors.append(f"runtime differs from processed source: {name}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--processed-dir", type=Path, required=True)
    parser.add_argument("--runtime-dir", type=Path)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()

    processed = validate_directory(args.processed_dir)
    runtime = validate_directory(args.runtime_dir) if args.runtime_dir else None
    comparison_errors = compare_directories(args.processed_dir, args.runtime_dir) if args.runtime_dir else []
    errors = list(processed["errors"])
    if runtime:
        errors.extend(runtime["errors"])
    errors.extend(comparison_errors)
    report = {
        "contract": {
            "idle": "32x48 RGBA",
            "walk": "128x192 RGBA, 4 columns x 4 rows",
            "directions_top_to_bottom": ["down", "left", "right", "up"],
            "alpha": "binary; transparent RGB zero",
            "anchor": "bottom center; frame bbox bottom 47 or 48",
        },
        "processed": processed,
        "runtime": runtime,
        "comparison_errors": comparison_errors,
        "errors": errors,
        "status": "PASS" if not errors else "FAIL",
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"{report['status']}: {len(processed['records'])} processed assets")
    for error in errors:
        print(f"- {error}")
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
