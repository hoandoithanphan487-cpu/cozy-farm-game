#!/usr/bin/env python3
"""Turn the five project-owned ImageGen building masters into B4 runtime layers."""

from collections import deque
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "macos/CreekSprout/CreekSprout/Assets"
MASTERS = ROOT / "artifacts/integration/n-015-codex-phase-c/generated-building-masters"
MANIFEST = ROOT / "artifacts/art-style/runtime-batch-r0/manifest.json"
GENERATED = Path("/Users/fengyifan/.codex/generated_images/01a03771-751d-77d2-80e4-4570b0ff596f")

BUILDINGS = {
    "building_farm_house": (GENERATED / "exec-644360ad-e220-4ee8-8807-f00897040d7e.png", (144, 144)),
    "building_farm_sluice": (GENERATED / "exec-46981d7b-501b-4655-9b1c-d476c61e7424.png", (192, 168)),
    "building_market_wharf": (GENERATED / "exec-246bda6d-366f-4644-89d9-bcb70a96222d.png", (144, 96)),
    "building_market_seed_shed": (GENERATED / "exec-5e816aa9-7157-47b7-987b-f1e9c28a74ca.png", (96, 96)),
    "building_market_warden_post": (GENERATED / "exec-65884cf2-2a55-448e-af71-786fe57b6832.png", (96, 96)),
}

PALETTE = [
    (0x1D, 0x2B, 0x3A), (0x28, 0x4B, 0x63), (0x4F, 0x77, 0x2D),
    (0x90, 0xA9, 0x55), (0xF4, 0xE7, 0xC1), (0xDD, 0xA1, 0x5E),
    (0xC6, 0x5D, 0x3B), (0xA9, 0xD6, 0xE5), (0xD9, 0x8C, 0x8C),
]


def remove_generated_background(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    if image.mode == "RGBA" and rgba.getextrema()[3][0] == 0:
        return rgba
    pixels = rgba.load()
    width, height = rgba.size

    def eligible(x: int, y: int) -> bool:
        red, green, blue, _ = pixels[x, y]
        return max(red, green, blue) - min(red, green, blue) <= 16 and max(red, green, blue) >= 218

    queue = deque()
    seen = set()
    for x in range(width):
        for y in (0, height - 1):
            if eligible(x, y):
                queue.append((x, y)); seen.add((x, y))
    for y in range(height):
        for x in (0, width - 1):
            if eligible(x, y):
                queue.append((x, y)); seen.add((x, y))
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height and (nx, ny) not in seen and eligible(nx, ny):
                seen.add((nx, ny)); queue.append((nx, ny))
    for x, y in seen:
        red, green, blue, _ = pixels[x, y]
        pixels[x, y] = (red, green, blue, 0)
    return rgba


def nearest_palette(red: int, green: int, blue: int) -> tuple[int, int, int]:
    return min(PALETTE, key=lambda color: sum((channel - target) ** 2 for channel, target in zip(color, (red, green, blue))))


def prepare_master(source: Path, native: tuple[int, int]) -> Image.Image:
    image = remove_generated_background(Image.open(source))
    bbox = image.getbbox()
    if not bbox:
        raise RuntimeError(f"empty generated building: {source}")
    image = image.crop(bbox)
    target_width, target_height = native
    scale = min((target_width - 8) / image.width, (target_height - 8) / image.height)
    resized = image.resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
        Image.Resampling.NEAREST,
    )
    canvas = Image.new("RGBA", native, (0, 0, 0, 0))
    x = (target_width - resized.width) // 2
    y = target_height - resized.height - 3
    canvas.alpha_composite(resized, (x, y))
    converted = []
    for red, green, blue, alpha in canvas.getdata():
        if alpha < 96:
            converted.append((0, 0, 0, 0))
        else:
            converted.append((*nearest_palette(red, green, blue), 255))
    canvas.putdata(converted)
    return canvas


def masked(master: Image.Image, predicate) -> Image.Image:
    result = Image.new("RGBA", master.size, (0, 0, 0, 0))
    source = master.load(); target = result.load()
    for y in range(master.height):
        for x in range(master.width):
            pixel = source[x, y]
            if pixel[3] and predicate(x, y, pixel):
                target[x, y] = pixel
    return result


def build_layers(master: Image.Image) -> dict[str, Image.Image]:
    _left, top, _right, bottom = master.getbbox()
    visual_height = bottom - top
    base_cut = top + int(visual_height * 0.86)
    roof_cut = top + int(visual_height * 0.57)
    highlight = {(0xF4, 0xE7, 0xC1), (0xA9, 0xD6, 0xE5), (0xD9, 0x8C, 0x8C)}
    water_or_moss = {(0x28, 0x4B, 0x63), (0x4F, 0x77, 0x2D), (0x90, 0xA9, 0x55), (0xA9, 0xD6, 0xE5)}
    return {
        "base": masked(master, lambda _x, y, _p: y >= base_cut),
        "structure": masked(master, lambda _x, y, _p: roof_cut <= y < base_cut),
        "roof": masked(master, lambda _x, y, _p: y < roof_cut),
        "detail": masked(master, lambda _x, _y, p: p[:3] in highlight),
        "interaction": masked(master, lambda x, y, _p: master.width * 0.32 <= x <= master.width * 0.68 and top + visual_height * 0.55 <= y < base_cut),
        "state_fx": masked(master, lambda _x, _y, p: p[:3] in water_or_moss),
    }


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    MASTERS.mkdir(parents=True, exist_ok=True)
    for prefix, (source, native) in BUILDINGS.items():
        master = prepare_master(source, native)
        master.save(MASTERS / f"{prefix}_master.png", optimize=False)
        layers = build_layers(master)
        for semantic, layer in layers.items():
            if not layer.getbbox():
                raise RuntimeError(f"empty {semantic} layer for {prefix}")
            layer.save(ASSETS / f"{prefix}_{semantic}.png", optimize=False)
        print(f"{prefix}: {native[0]}x{native[1]}, six non-empty RGBA layers")

    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    by_name = {record["file"]: record for record in manifest["assets"] if record.get("scope") == "runtime"}
    for prefix in BUILDINGS:
        for semantic in ("base", "structure", "roof", "detail", "interaction", "state_fx"):
            filename = f"{prefix}_{semantic}.png"
            record = by_name[filename]
            record["sha256"] = hashlib.sha256((ASSETS / filename).read_bytes()).hexdigest()
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("runtime-batch-r0 manifest: refreshed 30 B4 hashes")


if __name__ == "__main__":
    main()
