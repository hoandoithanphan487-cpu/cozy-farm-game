#!/usr/bin/env python3
"""Build N-018 contact sheet and 132/132 player-path consumption matrix."""

from __future__ import annotations

import json
import os
from collections import defaultdict
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = Path(os.environ.get("N018_APP_EVIDENCE", ROOT / "artifacts/integration/n-018-visual/real-app"))
SHOTS = OUT / "screenshots"
MATRIX = ROOT / "docs/game/n-015-runtime-consumer-matrix.json"
PORTRAITS = ROOT / "macos/CreekSprout/CreekSprout/Presentation/Portraits"
BUILDINGS = ROOT / "macos/CreekSprout/CreekSprout/Presentation/Buildings"

SCREEN_HINTS = {
    "char_": ["02-farm-sunny-1280x800", "04-market-sunny-1280x800", "07-dialogue-apprentice-1280"],
    "char_player": ["02-farm-sunny-1280x800", "12-till-1280", "14-water-1280", "10-harvest-1280"],
    "char_player_action_hoe": ["12-till-1280"],
    "char_player_action_watering_can": ["14-water-1280"],
    "char_player_action_harvest_glove": ["10-harvest-1280"],
    "crop_": ["02-farm-sunny-1280x800", "13a-seed-cycle-1280"],
    "tile_": ["02-farm-sunny-1280x800", "04-market-sunny-1280x800"],
    "building_": ["02-farm-sunny-1280x800", "04-market-sunny-1280x800"],
    "prop_": ["02-farm-sunny-1280x800"],
    "gather_": ["02-farm-sunny-1280x800", "04-market-sunny-1280x800"],
    "tool_": ["02-farm-sunny-1280x800"],
    "fx_target": ["02-farm-sunny-1280x800"],
    "fx_harvest": ["10-harvest-1280"],
    "fx_water_splash": ["03-farm-rain-1280x800", "14-water-1280"],
    "fx_canal_flow": ["03-farm-rain-1280x800"],
    "ui_": ["02-farm-sunny-1280x800", "06-farm-960x640"],
    "tile_canal_ew": ["02-farm-sunny-1280x800"],
    "tile_water_edge": ["02-farm-sunny-1280x800", "04-market-sunny-1280x800"],
}


def font() -> ImageFont.ImageFont:
    for name in ("PingFang.ttc", "Helvetica.ttc"):
        path = Path("/System/Library/Fonts") / name
        if path.exists():
            return ImageFont.truetype(str(path), 14)
    return ImageFont.load_default()


def contact_sheet() -> Path:
    images = sorted(SHOTS.glob("*.png"))
    if not images:
        raise RuntimeError(f"no screenshots in {SHOTS}")
    cols = 4
    thumb = (320, 200)
    rows = (len(images) + cols - 1) // cols
    canvas = Image.new("RGB", (cols * 340 + 20, rows * 230 + 48), "#101418")
    draw = ImageDraw.Draw(canvas)
    label_font = font()
    draw.text((16, 12), "N-018 real App contact sheet", fill="#f4e3bc", font=label_font)
    for index, path in enumerate(images):
        image = Image.open(path).convert("RGB")
        image.thumbnail(thumb, Image.Resampling.LANCZOS)
        x = 16 + (index % cols) * 340
        y = 40 + (index // cols) * 230
        canvas.paste(image, (x, y))
        draw.text((x, y + thumb[1] + 4), path.stem, fill="#d7c4a3", font=label_font)
    destination = OUT / "contact-sheet.png"
    canvas.save(destination)
    return destination


def screens_for(filename: str) -> list[str]:
    stem = filename[:-4]
    hits: list[str] = []
    for prefix, names in SCREEN_HINTS.items():
        if stem == prefix or stem.startswith(prefix):
            hits.extend(names)
    if not hits:
        hits = ["02-farm-sunny-1280x800", "04-market-sunny-1280x800"]
    existing = [name for name in hits if (SHOTS / f"{name}.png").exists()]
    return existing or [path.stem for path in sorted(SHOTS.glob("*.png"))[:2]]


def consumption_matrix() -> dict[str, object]:
    document = json.loads(MATRIX.read_text(encoding="utf-8"))
    loaded_path = OUT / "consumed-runtime-pngs.txt"
    loaded = set()
    if loaded_path.exists():
        loaded = {line.strip() for line in loaded_path.read_text(encoding="utf-8").splitlines() if line.strip()}
    by_category: dict[str, list[dict[str, object]]] = defaultdict(list)
    missing_loaded: list[str] = []
    for asset in document["assets"]:
        filename = asset["filename"]
        stem = filename[:-4]
        screens = screens_for(filename)
        record = {
            "filename": filename,
            "category": asset["category"],
            "planned_consumer": asset["planned_consumer"],
            "screens": screens,
            "loaded_in_real_app": stem in loaded if loaded else None,
        }
        if loaded and stem not in loaded:
            missing_loaded.append(filename)
        by_category[asset["category"]].append(record)
    portraits = sorted(path.name for path in PORTRAITS.glob("portrait_*_clean_v01.png"))
    buildings = sorted(path.name for path in BUILDINGS.glob("building_*_display_2048_v02.png"))
    payload = {
        "task": "N-018",
        "expected_runtime_pngs": 132,
        "observed_runtime_pngs": len(document["assets"]),
        "loaded_in_real_app_count": len(loaded) if loaded else None,
        "missing_loaded": missing_loaded,
        "hd_portraits": portraits,
        "hd_portrait_count": len(portraits),
        "hd_buildings": buildings,
        "hd_building_count": len(buildings),
        "screenshot_count": len(list(SHOTS.glob("*.png"))),
        "categories": {
            category: {
                "count": len(items),
                "assets": items,
            }
            for category, items in sorted(by_category.items())
        },
    }
    output = OUT / "n-018-consumption-matrix.json"
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return payload


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = contact_sheet()
    payload = consumption_matrix()
    summary = OUT / "n-018-visual-summary.md"
    summary.write_text(
        "\n".join(
            [
                "# N-018 visual evidence summary",
                "",
                f"- contact sheet: `{sheet.relative_to(ROOT)}`",
                f"- screenshots: {payload['screenshot_count']}",
                f"- runtime PNG matrix: {payload['observed_runtime_pngs']}/{payload['expected_runtime_pngs']}",
                f"- loaded in real App: {payload['loaded_in_real_app_count']}",
                f"- missing loaded: {len(payload['missing_loaded'])}",
                f"- HD portraits: {payload['hd_portrait_count']}/8",
                f"- HD buildings: {payload['hd_building_count']}/5",
                "",
            ]
        ),
        encoding="utf-8",
    )
    print(json.dumps({key: payload[key] for key in ("observed_runtime_pngs", "loaded_in_real_app_count", "missing_loaded", "hd_portrait_count", "hd_building_count", "screenshot_count")}, ensure_ascii=False, indent=2))
    return 0 if payload["observed_runtime_pngs"] == 132 and payload["hd_portrait_count"] == 8 and payload["hd_building_count"] == 5 else 1


if __name__ == "__main__":
    raise SystemExit(main())
