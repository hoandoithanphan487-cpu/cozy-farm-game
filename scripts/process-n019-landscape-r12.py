#!/usr/bin/env python3
"""Process N-019 north-edge landscape sources into native pixel panoramas."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT = ROOT / "artifacts/integration/n-019-demo-visual/north-landscape-r12"
SOURCE = ARTIFACT / "source"
PROCESSED = ARTIFACT / "processed"
PREVIEWS = ARTIFACT / "previews-4x"
RUNTIME = ROOT / "macos/CreekSprout/CreekSprout/Presentation/WorldLife"

PALETTE = [
    "#263638",
    "#1C4A4F",
    "#315E5B",
    "#4F7070",
    "#65818A",
    "#7E9393",
    "#55484A",
    "#765247",
    "#788653",
    "#96A85F",
    "#B3B876",
    "#B58A52",
    "#C58A59",
    "#C66E3D",
    "#D7C99A",
    "#F0D9AD",
]

ASSETS = [
    {
        "asset_id": "wl_backdrop_farm_mountain_r1",
        "source": "farm-mountain-ridge-imagegen.png",
        "canvas": (384, 72),
        "draw": (384, 60),
    },
    {
        "asset_id": "wl_backdrop_market_creek_valley_r1",
        "source": "market-creek-valley-imagegen.png",
        "canvas": (432, 72),
        "draw": (432, 72),
    },
]


def rgb(hex_value: str) -> tuple[int, int, int]:
    value = hex_value.removeprefix("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def palette_image() -> Image.Image:
    image = Image.new("P", (1, 1))
    values: list[int] = []
    for color in PALETTE:
        values.extend(rgb(color))
    # Pillow considers all 256 palette slots during quantization. Repeating the
    # darkest approved project colour prevents unused slots from introducing
    # an accidental pure black that is not part of the locked palette.
    darkest = list(rgb(PALETTE[0]))
    for _ in range(256 - len(PALETTE)):
        values.extend(darkest)
    image.putpalette(values)
    return image


def threshold_bbox(image: Image.Image, threshold: int = 64) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value >= threshold else 0).getbbox()
    if bbox is None:
        raise ValueError("source has no opaque landscape pixels")
    return bbox


def process_asset(spec: dict[str, object]) -> dict[str, object]:
    source_path = SOURCE / str(spec["source"])
    canvas_size = tuple(spec["canvas"])
    draw_size = tuple(spec["draw"])
    asset_id = str(spec["asset_id"])

    source = Image.open(source_path).convert("RGBA")
    cropped = source.crop(threshold_bbox(source))
    resized = cropped.resize(draw_size, Image.Resampling.LANCZOS)

    alpha = resized.getchannel("A").point(lambda value: 255 if value >= 96 else 0)
    indexed = resized.convert("RGB").quantize(
        palette=palette_image(),
        dither=Image.Dither.NONE,
    )
    quantized = indexed.convert("RGBA")
    quantized.putalpha(alpha)

    canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    canvas.alpha_composite(quantized, (0, canvas_size[1] - draw_size[1]))
    clean = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    clean.paste(canvas, mask=canvas.getchannel("A"))

    runtime_path = RUNTIME / f"{asset_id}.png"
    processed_path = PROCESSED / runtime_path.name
    preview_path = PREVIEWS / f"{asset_id}-4x.png"
    clean.save(runtime_path, optimize=True)
    clean.save(processed_path, optimize=True)
    clean.resize(
        (canvas_size[0] * 4, canvas_size[1] * 4),
        Image.Resampling.NEAREST,
    ).save(preview_path, optimize=True)

    opaque = clean.getchannel("A")
    alpha_values = sorted(set(opaque.getdata()))
    colors = sorted({
        "#{:02X}{:02X}{:02X}".format(red, green, blue)
        for red, green, blue, value in clean.getdata()
        if value == 255
    })
    dirty_transparent_rgb = sum(
        1 for red, green, blue, value in clean.getdata()
        if value == 0 and (red or green or blue)
    )
    digest = hashlib.sha256(runtime_path.read_bytes()).hexdigest()
    return {
        "asset_id": asset_id,
        "native_size": list(clean.size),
        "alpha_values": alpha_values,
        "opaque_palette": colors,
        "dirty_transparent_rgb": dirty_transparent_rgb,
        "sha256": digest,
    }


def main() -> int:
    for directory in (PROCESSED, PREVIEWS, RUNTIME):
        directory.mkdir(parents=True, exist_ok=True)

    failures: list[str] = []
    records: list[dict[str, object]] = []
    for spec in ASSETS:
        try:
            record = process_asset(spec)
            records.append(record)
            if record["alpha_values"] != [0, 255]:
                failures.append(f"{record['asset_id']}: alpha is not binary")
            if record["dirty_transparent_rgb"] != 0:
                failures.append(f"{record['asset_id']}: transparent RGB is dirty")
            unexpected = sorted(set(record["opaque_palette"]) - set(PALETTE))
            if unexpected:
                failures.append(
                    f"{record['asset_id']}: unexpected palette colours {unexpected}"
                )
        except Exception as error:  # pragma: no cover - evidence path
            failures.append(f"{spec['asset_id']}: {error}")

    manifest = {
        "task": "N-019",
        "revision": "north-landscape-r12",
        "source_mode": "built-in ImageGen sources processed to native pixel panoramas",
        "palette": PALETTE,
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
