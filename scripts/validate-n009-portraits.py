#!/usr/bin/env python3
"""Validate N-009 portrait PNGs and emit evidence/contact sheet.

Uses only the Python standard library so the task does not require installing
Pillow, OpenCV, ImageMagick, or pngcheck.
"""

from __future__ import annotations

import argparse
import binascii
import hashlib
import json
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PORTRAITS = ROOT / "artifacts/integration/n-009-portraits"
SLUGS = (
    "player",
    "water_apprentice",
    "seed_steward",
    "creek_warden",
    "neighbor_hearsay",
    "neighbor_storyteller",
    "neighbor_evidence",
    "neighbor_consensus",
)
STABLE_IDS = {
    "player": "brookseed.player.sprout",
    "water_apprentice": "brookseed.npc.water_apprentice",
    "seed_steward": "brookseed.npc.seed_steward",
    "creek_warden": "brookseed.npc.creek_warden",
    "neighbor_hearsay": "brookseed.npc.neighbor_hearsay",
    "neighbor_storyteller": "brookseed.npc.neighbor_storyteller",
    "neighbor_evidence": "brookseed.npc.neighbor_evidence",
    "neighbor_consensus": "brookseed.npc.neighbor_consensus",
}


def paeth(a: int, b: int, c: int) -> int:
    candidate = a + b - c
    da, db, dc = abs(candidate - a), abs(candidate - b), abs(candidate - c)
    return a if da <= db and da <= dc else b if db <= dc else c


def decode_png(path: Path) -> tuple[int, int, list[bytearray]]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path}: invalid PNG signature")
    pos, idat = 8, bytearray()
    width = height = depth = color = interlace = None
    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        kind = data[pos + 4 : pos + 8]
        payload = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, color, compression, filtering, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
            if (depth, color, compression, filtering, interlace) != (8, 6, 0, 0, 0):
                raise ValueError(
                    f"{path}: expected non-interlaced 8-bit RGBA PNG, got "
                    f"depth={depth} color={color} interlace={interlace}"
                )
        elif kind == b"IDAT":
            idat.extend(payload)
        elif kind == b"IEND":
            break
    if width is None or height is None:
        raise ValueError(f"{path}: missing IHDR")

    raw = zlib.decompress(bytes(idat))
    bytes_per_pixel, stride = 4, width * 4
    rows: list[bytearray] = []
    previous = bytearray(stride)
    offset = 0
    for _ in range(height):
        filter_type = raw[offset]
        offset += 1
        filtered = raw[offset : offset + stride]
        offset += stride
        row = bytearray(stride)
        for index, value in enumerate(filtered):
            left = row[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
            up = previous[index]
            upper_left = previous[index - bytes_per_pixel] if index >= bytes_per_pixel else 0
            if filter_type == 0:
                reconstructed = value
            elif filter_type == 1:
                reconstructed = value + left
            elif filter_type == 2:
                reconstructed = value + up
            elif filter_type == 3:
                reconstructed = value + ((left + up) // 2)
            elif filter_type == 4:
                reconstructed = value + paeth(left, up, upper_left)
            else:
                raise ValueError(f"{path}: unsupported PNG filter {filter_type}")
            row[index] = reconstructed & 0xFF
        rows.append(row)
        previous = row
    return width, height, rows


def png_chunk(kind: bytes, payload: bytes) -> bytes:
    crc = binascii.crc32(kind + payload) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", crc)


def write_png(path: Path, width: int, height: int, rows: list[bytearray]) -> None:
    raw = bytearray()
    for row in rows:
        raw.append(0)
        raw.extend(row)
    encoded = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + png_chunk(b"IEND", b"")
    )
    path.write_bytes(encoded)


def inspect(path: Path) -> dict[str, object]:
    width, height, rows = decode_png(path)
    transparent = intermediate = opaque = dirty_transparent = 0
    min_x, min_y, max_x, max_y = width, height, -1, -1
    for y, row in enumerate(rows):
        for x in range(width):
            red, green, blue, alpha = row[x * 4 : x * 4 + 4]
            if alpha == 0:
                transparent += 1
                dirty_transparent += int(bool(red or green or blue))
            elif alpha == 255:
                opaque += 1
            else:
                intermediate += 1
            if alpha:
                min_x, min_y = min(min_x, x), min(min_y, y)
                max_x, max_y = max(max_x, x), max(max_y, y)
    bbox = None if max_x < 0 else [min_x, min_y, max_x, max_y]
    return {
        "path": str(path.relative_to(ROOT)),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "width": width,
        "height": height,
        "bit_depth": 8,
        "color_type": 6,
        "transparent": transparent,
        "intermediate_alpha": intermediate,
        "opaque": opaque,
        "dirty_transparent_rgb": dirty_transparent,
        "bbox": bbox,
    }


def build_contact_sheet(processed: dict[str, tuple[int, int, list[bytearray]]]) -> None:
    tile = 512
    width, height = tile * 4, tile * 2
    sheet = [bytearray(width * 4) for _ in range(height)]
    for index, slug in enumerate(SLUGS):
        source_width, source_height, source_rows = processed[slug]
        column, row_index = index % 4, index // 4
        for y in range(tile):
            source_y = min(source_height - 1, y * source_height // tile)
            target = sheet[row_index * tile + y]
            source = source_rows[source_y]
            for x in range(tile):
                source_x = min(source_width - 1, x * source_width // tile)
                start = (column * tile + x) * 4
                target[start : start + 4] = source[source_x * 4 : source_x * 4 + 4]
    output = PORTRAITS / "contact-sheet/n-009-contact-sheet-v01.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    write_png(output, width, height, sheet)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-evidence", action="store_true")
    args = parser.parse_args()
    failures: list[str] = []
    manifest_assets = []
    decoded_processed: dict[str, tuple[int, int, list[bytearray]]] = {}

    for slug in SLUGS:
        source = PORTRAITS / f"source/portrait_{slug}_source_v01.png"
        clean = PORTRAITS / f"processed/portrait_{slug}_clean_v01.png"
        if not source.exists() or not clean.exists():
            failures.append(f"{slug}: source or processed PNG missing")
            continue
        source_stats, clean_stats = inspect(source), inspect(clean)
        record = PORTRAITS / f"records/portrait_{slug}_generation-record-v01.md"
        if not record.exists():
            failures.append(f"{slug}: generation record missing")
        else:
            record_text = record.read_text()
            for required in (
                STABLE_IDS[slug],
                source_stats["sha256"],
                clean_stats["sha256"],
                "## Full generation prompt",
                "Status: `boundary_checked`",
            ):
                if required not in record_text:
                    failures.append(f"{slug}: generation record missing {required}")
        if (clean_stats["width"], clean_stats["height"]) != (2048, 2048):
            failures.append(f"{slug}: processed size is not 2048x2048")
        if clean_stats["opaque"] == 0:
            failures.append(f"{slug}: no fully opaque subject pixels")
        if clean_stats["transparent"] == 0:
            failures.append(f"{slug}: no transparent background pixels")
        if clean_stats["dirty_transparent_rgb"] != 0:
            failures.append(f"{slug}: dirty RGB under alpha=0")
        bbox = clean_stats["bbox"]
        if bbox is None or bbox[0] <= 0 or bbox[1] <= 0 or bbox[2] >= 2047 or bbox[3] >= 2047:
            failures.append(f"{slug}: non-transparent bbox touches canvas edge")
        if bbox is not None:
            subject_height = bbox[3] - bbox[1] + 1
            occupancy = subject_height / 2048
            clean_stats["subject_height_ratio"] = round(occupancy, 4)
            if not 0.70 <= occupancy <= 0.86:
                failures.append(
                    f"{slug}: full-body subject height ratio {occupancy:.4f} outside 0.70..0.86"
                )
        decoded_processed[slug] = decode_png(clean)
        manifest_assets.append(
            {
                "slug": slug,
                "stable_id": STABLE_IDS[slug],
                "prompt_version": "n009-v01",
                "status": "boundary_checked",
                "source": source_stats,
                "processed": clean_stats,
            }
        )

    report = {
        "task": "N-009",
        "composition_contract": "complete full body, head to both feet visible",
        "generator": "built-in imagegen",
        "processing": "sips 1720 export centered on 2048 RGBA canvas + Python stdlib transparent RGB normalization",
        "asset_count": len(manifest_assets),
        "failures": failures,
        "assets": manifest_assets,
    }
    if args.write_evidence:
        evidence = PORTRAITS / "evidence"
        evidence.mkdir(parents=True, exist_ok=True)
        (evidence / "validation-report.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n"
        )
        (PORTRAITS / "manifest.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n"
        )
        if len(decoded_processed) == len(SLUGS):
            build_contact_sheet(decoded_processed)

    for asset in manifest_assets:
        clean = asset["processed"]
        print(
            f"{asset['slug']}: {clean['width']}x{clean['height']} RGBA8 "
            f"opaque={clean['opaque']} intermediate={clean['intermediate_alpha']} "
            f"transparent={clean['transparent']} dirty_rgb={clean['dirty_transparent_rgb']} "
            f"bbox={clean['bbox']} sha256={clean['sha256']}"
        )
    print(f"result={'PASS' if not failures else 'FAIL'} failures={len(failures)}")
    for failure in failures:
        print(f"FAIL: {failure}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
