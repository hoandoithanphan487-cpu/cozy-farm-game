#!/usr/bin/env python3
"""Convert N-015 ImageGen character sheets into SpriteKit runtime assets.

ImageGen sources are authored as a strict 4x4 grid on a 1024x1536 baked
checkerboard. This processor removes only border-connected neutral background,
downsamples each sheet to the locked 128x192 runtime contract, hardens alpha,
reduces the palette, and derives the 32x48 idle frame from down/frame zero.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw


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


def is_checker_background(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, _ = pixel
    return min(red, green, blue) >= 205 and max(red, green, blue) - min(red, green, blue) <= 18


def clear_connected_background(source: Image.Image) -> Image.Image:
    image = source.convert("RGBA")
    pixels = image.load()
    width, height = image.size
    visited = bytearray(width * height)
    queue: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        index = y * width + x
        if visited[index] or not is_checker_background(pixels[x, y]):
            return
        visited[index] = 1
        queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        pixels[x, y] = (0, 0, 0, 0)
        if x > 0:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y > 0:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)
    return image


def harden_alpha(image: Image.Image, threshold: int = 72) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha < threshold:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (red, green, blue, 255)
    return rgba


def quantize_opaque(image: Image.Image, colors: int = 36) -> Image.Image:
    alpha = image.getchannel("A")
    quantized = image.convert("RGB").quantize(colors=colors, method=Image.Quantize.MAXCOVERAGE).convert("RGBA")
    quantized.putalpha(alpha)
    pixels = quantized.load()
    for y in range(quantized.height):
        for x in range(quantized.width):
            if pixels[x, y][3] == 0:
                pixels[x, y] = (0, 0, 0, 0)
    return quantized


def normalize_frame_baselines(sheet: Image.Image) -> Image.Image:
    normalized = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    for row in range(4):
        for column in range(4):
            left, top = column * 32, row * 48
            frame = sheet.crop((left, top, left + 32, top + 48))
            bbox = frame.getchannel("A").getbbox()
            if bbox is None:
                raise ValueError(f"empty frame row={row} column={column}")
            # Keep one transparent pixel below every contact foot. A stable
            # bottom-center anchor prevents visible hopping between frames.
            desired_shift = 47 - bbox[3]
            # Tall side-facing silhouettes can already touch the top edge.
            # Clamp the downward move so baseline alignment never sacrifices
            # hats or hair; those exceptional frames may use the final row.
            shift_y = max(desired_shift, -bbox[1])
            normalized.alpha_composite(frame, (left, top + shift_y))
    return normalized


def draw_player_action_sheets(player_sheet: Image.Image, output_dir: Path) -> None:
    accents = {
        "hoe": ((118, 82, 63, 255), (174, 151, 116, 255)),
        "watering_can": ((76, 118, 126, 255), (133, 166, 170, 255)),
        "harvest_glove": ((220, 182, 104, 255), (242, 222, 174, 255)),
    }
    for action, (primary, highlight) in accents.items():
        sheet = player_sheet.copy()
        for row in range(4):
            for column in range(4):
                origin_x, origin_y = column * 32, row * 48
                draw = ImageDraw.Draw(sheet)
                phase = (-2, 0, 2, 0)[column]
                if row == 0:  # down
                    hand = (origin_x + 22, origin_y + 29)
                    facing = 1
                elif row == 1:  # left
                    hand = (origin_x + 8, origin_y + 29)
                    facing = -1
                elif row == 2:  # right
                    hand = (origin_x + 24, origin_y + 29)
                    facing = 1
                else:  # up; keep the tool readable beside the silhouette
                    hand = (origin_x + 22, origin_y + 29)
                    facing = 1
                if action == "hoe":
                    end = (hand[0] + facing * (6 + abs(phase)), hand[1] - 8 + phase)
                    draw.line((hand, end), fill=primary, width=2)
                    draw.line((end, (end[0] + facing * 4, end[1] + 1)), fill=highlight, width=2)
                elif action == "watering_can":
                    x = hand[0] + (0 if facing > 0 else -5)
                    draw.rectangle((x, hand[1] - 2, x + 5, hand[1] + 3), fill=primary)
                    draw.line((x + (5 if facing > 0 else 0), hand[1], x + facing * 9, hand[1] - 2 + phase // 2), fill=highlight, width=2)
                else:
                    x = hand[0] + facing * 2
                    draw.rectangle((x - 1, hand[1] - 3, x + 2, hand[1] + 1), fill=primary)
                    draw.point((x, hand[1] - 3), fill=highlight)
        sheet = quantize_opaque(harden_alpha(sheet), colors=40)
        sheet.save(output_dir / f"char_player_action_{action}.png", optimize=False)


def write_contact_sheet(output_dir: Path, slugs: tuple[str, ...]) -> None:
    columns = 4
    tile_width, tile_height = 272, 416
    rows = (len(slugs) + columns - 1) // columns
    contact = Image.new("RGBA", (columns * tile_width, rows * tile_height), (18, 30, 28, 255))
    draw = ImageDraw.Draw(contact)
    for index, slug in enumerate(slugs):
        sheet = Image.open(output_dir / f"char_{slug}_walk.png").convert("RGBA")
        preview = sheet.resize((256, 384), Image.Resampling.NEAREST)
        x = (index % columns) * tile_width + 8
        y = (index // columns) * tile_height + 24
        contact.alpha_composite(preview, (x, y))
        draw.text((x, 6), slug, fill=(232, 220, 180, 255))
    contact.convert("RGB").save(output_dir / "characters-walk-contact-2x.png", optimize=False)


def process(source_path: Path, output_dir: Path, slug: str) -> None:
    source = Image.open(source_path)
    if source.size != (1024, 1536):
        raise ValueError(f"{source_path}: expected 1024x1536, got {source.size}")
    transparent = clear_connected_background(source)
    # BOX maps each exact 8x8 source block into one runtime pixel. It retains
    # the authored cluster shapes without the ringing/soft halo of LANCZOS.
    runtime = transparent.resize((128, 192), Image.Resampling.BOX)
    runtime = normalize_frame_baselines(quantize_opaque(harden_alpha(runtime)))

    output_dir.mkdir(parents=True, exist_ok=True)
    sheet_path = output_dir / f"char_{slug}_walk.png"
    idle_path = output_dir / f"char_{slug}.png"
    runtime.save(sheet_path, optimize=False)
    runtime.crop((0, 0, 32, 48)).save(idle_path, optimize=False)

    if slug == "player":
        draw_player_action_sheets(runtime, output_dir)

    preview = runtime.resize((1024, 1536), Image.Resampling.NEAREST)
    preview.save(output_dir / f"char_{slug}_walk_preview_8x.png", optimize=False)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--slug", choices=CHARACTERS, action="append")
    args = parser.parse_args()

    slugs = tuple(args.slug) if args.slug else CHARACTERS
    for slug in slugs:
        source_path = args.source_dir / f"char_{slug}_sheet_source.png"
        if not source_path.is_file():
            raise FileNotFoundError(source_path)
        process(source_path, args.output_dir, slug)
        print(f"processed {slug}")
    write_contact_sheet(args.output_dir, slugs)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
