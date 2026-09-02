#!/usr/bin/env python3
"""Build N-019 presentation-only native pixel flora/fauna assets.

ImageGen outputs are treated only as pixel-art source masters.  This script
fits them to their locked native canvases, converts every opaque pixel to the
project Master Doc palette, hardens alpha, clears RGB below transparent
pixels, and writes nearest-neighbour review evidence.
"""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
GENERATED = Path(
    "/Users/fengyifan/.codex/generated_images/"
    "01a03805-268a-74b1-bbf8-dba1cba4b7ad"
)
EVIDENCE = ROOT / "artifacts/integration/n-019-demo-visual/pixel-world-life"
SOURCE_DIR = EVIDENCE / "source"
PROCESSED_DIR = EVIDENCE / "processed"
PREVIEW_DIR = EVIDENCE / "previews-8x"
RUNTIME_DIR = ROOT / "macos/CreekSprout/CreekSprout/Presentation/WorldLife"

PALETTE = {
    "deep_creek_ink": (0x26, 0x36, 0x38),
    "wet_stone_brown": (0x55, 0x48, 0x4A),
    "chestnut_shadow": (0x76, 0x52, 0x47),
    "moss_leaf_green": (0x78, 0x86, 0x53),
    "mist_blue": (0x78, 0x97, 0xA0),
    "riverbank_teal": (0x4F, 0x70, 0x70),
    "straw_gold": (0xB5, 0x8A, 0x52),
    "wood_honey": (0xC5, 0x8A, 0x59),
    "copper_orange": (0xC6, 0x6E, 0x3D),
    "paper_cream": (0xF0, 0xD9, 0xAD),
}
PALETTE_COLORS = tuple(PALETTE.values())

ASSETS = (
    ("flower_01", "溪白雏菊", "exec-f2af33c3-7383-4169-9f3a-cde0dae63a8d.png", (24, 24)),
    ("flower_02", "雾铃花", "exec-da5d5b29-77b4-4a7a-8695-23a135c187c3.png", (24, 24)),
    ("flower_03", "铜阳万寿菊", "exec-15f4d9fd-c191-411a-a6ba-922182aee1d9.png", (24, 24)),
    ("flower_04", "溪星野花", "exec-1f8d62c7-5d42-41bf-b666-5cf32ca3a889.png", (24, 24)),
    ("tree_maple", "溪枫", "exec-5bc7accc-0c7c-4c96-820c-2850002a2787.png", (96, 96)),
    ("tree_honey_pear", "蜜梨树", "exec-b7d390bc-9d5b-4953-b9e7-902dea49cf52.png", (96, 96)),
    ("tree_mist_pine", "雾针松", "exec-567c42f0-937f-4344-bf13-b2d1b159d4a9.png", (96, 96)),
    ("tree_creek_willow", "溪柳", "exec-42865bfc-4ca4-40e7-8f02-fd7c61b561fe.png", (96, 96)),
    ("farm_hen", "谷羽鸡", "exec-e96e6fc4-a563-4e56-a0e1-3af53a5bd1b5.png", (32, 32)),
    ("farm_cow", "木蜜奶牛", "exec-227d592f-cbcd-4430-a433-1ec93d08100a.png", (48, 32)),
    ("farm_sheep", "雾绒羊", "exec-18f6a174-4cef-41f1-9675-0affcbea3111.png", (48, 32)),
    ("farm_goat", "石铃山羊", "exec-79ca3e17-7edc-4019-b25b-3efc66b45b3c.png", (48, 32)),
    ("farm_pig", "铜鼻猪", "exec-9b38a24a-9755-4cdb-975c-ea0c2f0d5a9f.png", (48, 32)),
    ("farm_goose", "溪岸鹅", "exec-a4154bd6-933f-4476-b96c-ea3811ca0e15.png", (32, 32)),
)


def nearest_palette(red: int, green: int, blue: int) -> tuple[int, int, int]:
    return min(
        PALETTE_COLORS,
        key=lambda color: sum(
            (source - target) ** 2
            for source, target in zip((red, green, blue), color)
        ),
    )


def clean_source(source: Path) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    converted = []
    for red, green, blue, alpha in image.getdata():
        if alpha < 112:
            converted.append((0, 0, 0, 0))
        else:
            converted.append((red, green, blue, 255))
    image.putdata(converted)
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"empty source after alpha cleanup: {source}")
    return image.crop(bbox)


def fit_native(source: Path, size: tuple[int, int]) -> Image.Image:
    subject = clean_source(source)
    width, height = size
    margin_x = 3 if width <= 48 else 4
    margin_top = 3 if height <= 48 else 4
    margin_bottom = 2 if height <= 48 else 3
    scale = min(
        (width - margin_x * 2) / subject.width,
        (height - margin_top - margin_bottom) / subject.height,
    )
    resized = subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        Image.Resampling.NEAREST,
    )
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    origin = ((width - resized.width) // 2, height - margin_bottom - resized.height)
    canvas.alpha_composite(resized, origin)

    native_pixels = []
    for red, green, blue, alpha in canvas.getdata():
        if alpha < 128:
            native_pixels.append((0, 0, 0, 0))
        else:
            native_pixels.append((*nearest_palette(red, green, blue), 255))
    canvas.putdata(native_pixels)
    return canvas


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metrics(image: Image.Image) -> dict[str, object]:
    pixels = list(image.getdata())
    alpha_values = sorted({pixel[3] for pixel in pixels})
    opaque_colors = sorted(
        {"#%02X%02X%02X" % pixel[:3] for pixel in pixels if pixel[3] == 255}
    )
    dirty = sum(
        1 for red, green, blue, alpha in pixels
        if alpha == 0 and (red or green or blue)
    )
    bbox = image.getchannel("A").getbbox()
    return {
        "width": image.width,
        "height": image.height,
        "alpha_values": alpha_values,
        "opaque_palette": opaque_colors,
        "opaque_color_count": len(opaque_colors),
        "dirty_transparent_rgb": dirty,
        "bbox": list(bbox) if bbox else None,
    }


def contact_sheet(records: list[dict[str, object]]) -> None:
    cell_width, cell_height = 800, 880
    columns = 5
    rows = (len(records) + columns - 1) // columns
    sheet = Image.new("RGB", (cell_width * columns, cell_height * rows), (38, 54, 56))
    draw = ImageDraw.Draw(sheet)
    for index, record in enumerate(records):
        x = index % columns * cell_width
        y = index // columns * cell_height
        preview = Image.open(PREVIEW_DIR / f"{record['asset_name']}-8x.png").convert("RGBA")
        px = x + (cell_width - preview.width) // 2
        py = y + 36
        sheet.paste(preview, (px, py), preview)
        draw.text((x + 24, y + cell_height - 72), f"{record['display_name']}  {record['native_size']}", fill=(240, 217, 173))
    sheet.save(EVIDENCE / "n-019-world-life-pixel-contact-8x.png", optimize=False)


def main() -> None:
    for directory in (SOURCE_DIR, PROCESSED_DIR, PREVIEW_DIR, RUNTIME_DIR):
        directory.mkdir(parents=True, exist_ok=True)

    records: list[dict[str, object]] = []
    for slug, display_name, generated_name, native_size in ASSETS:
        generated = GENERATED / generated_name
        if not generated.exists():
            raise FileNotFoundError(generated)
        source = SOURCE_DIR / f"concept_pixel_{slug}_v01.png"
        shutil.copy2(generated, source)

        native = fit_native(source, native_size)
        asset_name = f"wl_{slug}"
        processed = PROCESSED_DIR / f"{asset_name}.png"
        runtime = RUNTIME_DIR / f"{asset_name}.png"
        native.save(processed, optimize=False)
        shutil.copy2(processed, runtime)

        preview = native.resize(
            (native.width * 8, native.height * 8),
            Image.Resampling.NEAREST,
        )
        preview.save(PREVIEW_DIR / f"{asset_name}-8x.png", optimize=False)
        record = {
            "slug": slug,
            "display_name": display_name,
            "asset_name": asset_name,
            "source": str(source.relative_to(ROOT)),
            "processed": str(processed.relative_to(ROOT)),
            "runtime": str(runtime.relative_to(ROOT)),
            "native_size": f"{native.width}x{native.height}",
            "sha256": sha256(runtime),
            **metrics(native),
        }
        if record["alpha_values"] != [0, 255]:
            raise RuntimeError(f"{asset_name}: non-binary alpha")
        if record["dirty_transparent_rgb"] != 0:
            raise RuntimeError(f"{asset_name}: dirty transparent RGB")
        if record["opaque_color_count"] > len(PALETTE_COLORS):
            raise RuntimeError(f"{asset_name}: palette overflow")
        records.append(record)
        print(
            f"PASS {asset_name} {record['native_size']} "
            f"colors={record['opaque_color_count']} alpha={record['alpha_values']}"
        )

    manifest = {
        "task": "N-019",
        "contract": "native runtime pixels; nearest integer scaling; presentation-only",
        "palette": {name: "#%02X%02X%02X" % color for name, color in PALETTE.items()},
        "assets": records,
        "failures": [],
    }
    (EVIDENCE / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    contact_sheet(records)
    print(f"PASS assets={len(records)} failures=0")


if __name__ == "__main__":
    main()
