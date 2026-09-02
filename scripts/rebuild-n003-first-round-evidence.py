#!/usr/bin/env python3
"""Rebuild N-003 first-round *evidence* images only.

Does not write runtime PNGs under macos/CreekSprout/CreekSprout/Assets/.
Keeps full native canvases (including transparent padding) for 1x/4x and contact sheets.
"""
from __future__ import annotations

import hashlib
import json
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "macos/CreekSprout/CreekSprout/Assets"
EVIDENCE = ROOT / "artifacts/art-style/n-003-first-round"
INTEGRATION = ROOT / "artifacts/integration/n-003-pixel"

INK = (0x26, 0x36, 0x38, 255)
STONE = (0x55, 0x48, 0x4A, 255)
PAPER = (0xF0, 0xD9, 0xAD, 255)
CLEAR = (0, 0, 0, 0)

CHARACTERS = [
    "char_player.png",
    "char_water_apprentice.png",
    "char_seed_steward.png",
    "char_creek_warden.png",
]
CROPS = [
    "crop_mist_radish.png",
    "crop_stream_leaf.png",
    "crop_amber_bean.png",
    "crop_bell_berry.png",
    "crop_honey_melon.png",
]
TILES = ["tile_grass.png", "tile_tilled.png", "tile_water_edge.png"]
RUNTIME_12 = CHARACTERS + CROPS + TILES


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    if pb <= pc:
        return b
    return c


def decode_png(path: Path):
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    pos = 8
    width = height = bit_depth = color_type = None
    idat = bytearray()
    while pos < len(data):
        length = struct.unpack(">I", data[pos : pos + 4])[0]
        kind = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type, *_ = struct.unpack(">IIBBBBB", chunk)
        elif kind == b"IDAT":
            idat.extend(chunk)
        elif kind == b"IEND":
            break
    if width is None or bit_depth != 8 or color_type not in (2, 6):
        raise ValueError(f"unsupported png {path} {width}x{height} d={bit_depth} t={color_type}")
    bpp = 4 if color_type == 6 else 3
    raw = zlib.decompress(bytes(idat))
    stride = width * bpp
    rows = []
    i = 0
    prev = bytearray(stride)
    for _ in range(height):
        f = raw[i]
        i += 1
        cur = bytearray(raw[i : i + stride])
        i += stride
        if f == 1:
            for x in range(stride):
                cur[x] = (cur[x] + (cur[x - bpp] if x >= bpp else 0)) & 255
        elif f == 2:
            for x in range(stride):
                cur[x] = (cur[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride):
                left = cur[x - bpp] if x >= bpp else 0
                cur[x] = (cur[x] + ((left + prev[x]) // 2)) & 255
        elif f == 4:
            for x in range(stride):
                left = cur[x - bpp] if x >= bpp else 0
                up = prev[x]
                ul = prev[x - bpp] if x >= bpp else 0
                cur[x] = (cur[x] + paeth(left, up, ul)) & 255
        elif f != 0:
            raise ValueError(f"filter {f} in {path}")
        rows.append(bytes(cur))
        prev = cur
    pixels = []
    for row in rows:
        if bpp == 4:
            for x in range(width):
                o = x * 4
                pixels.append((row[o], row[o + 1], row[o + 2], row[o + 3]))
        else:
            for x in range(width):
                o = x * 3
                pixels.append((row[o], row[o + 1], row[o + 2], 255))
    return width, height, pixels


def encode_png(width, height, pixels) -> bytes:
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        for c in pixels[y * width : (y + 1) * width]:
            raw.extend(c)

    def chunk(kind, payload):
        return (
            struct.pack(">I", len(payload))
            + kind
            + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
        )

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


def scale_nearest(w, h, px, factor):
    nw, nh = w * factor, h * factor
    out = [CLEAR] * (nw * nh)
    for y in range(h):
        for x in range(w):
            c = px[y * w + x]
            for dy in range(factor):
                row = (y * factor + dy) * nw
                for dx in range(factor):
                    out[row + x * factor + dx] = c
    return nw, nh, out


def checker_fill(w, h, a=INK, b=STONE, size=8):
    out = [CLEAR] * (w * h)
    for y in range(h):
        for x in range(w):
            out[y * w + x] = a if ((x // size) + (y // size)) % 2 == 0 else b
    return out


def blit(dst_w, dst, src_w, src_h, src, ox, oy, copy_clear=False):
    for y in range(src_h):
        for x in range(src_w):
            c = src[y * src_w + x]
            if c[3] == 0 and not copy_clear:
                continue
            dx, dy = ox + x, oy + y
            if 0 <= dx < dst_w and 0 <= dy < (len(dst) // dst_w):
                dst[dy * dst_w + dx] = c


def opaque_bbox(w, h, px):
    xs, ys = [], []
    for y in range(h):
        for x in range(w):
            if px[y * w + x][3]:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def contact_sheet(images, cols, scale, pad):
    sw, sh, _ = images[0]
    cell_w = sw * scale + pad * 2
    cell_h = sh * scale + pad * 2
    rows = (len(images) + cols - 1) // cols
    page_w, page_h = cols * cell_w, rows * cell_h
    page = checker_fill(page_w, page_h)
    cells = []
    for i, (w, h, px) in enumerate(images):
        nw, nh, scaled = scale_nearest(w, h, px, scale)
        col, row = i % cols, i // cols
        ox = col * cell_w + pad
        oy = row * cell_h + pad
        # Mark the native-canvas rectangle with a 1px paper frame *outside* the sprite
        # so left/right/top/bottom transparent gutters stay inside the frame.
        for x in range(ox - 1, ox + nw + 1):
            if 0 <= x < page_w:
                if oy - 1 >= 0:
                    page[(oy - 1) * page_w + x] = PAPER
                if oy + nh < page_h:
                    page[(oy + nh) * page_w + x] = PAPER
        for y in range(oy - 1, oy + nh + 1):
            if 0 <= y < page_h:
                if ox - 1 >= 0:
                    page[y * page_w + ox - 1] = PAPER
                if ox + nw < page_w:
                    page[y * page_w + ox + nw] = PAPER
        blit(page_w, page, nw, nh, scaled, ox, oy)
        cells.append(
            {
                "index": i,
                "cell": [col * cell_w, row * cell_h, cell_w, cell_h],
                "canvas": [ox, oy, nw, nh],
                "bbox": opaque_bbox(nw, nh, scaled),
            }
        )
    return page_w, page_h, page, {"cell_w": cell_w, "cell_h": cell_h, "pad": pad, "scale": scale, "cells": cells}


def seam_score(w, h, px):
    """Mean channel delta across opposite edges; Hermes cited ~2.75 for water 3x3."""
    def chans(a, b):
        return [abs(a[i] - b[i]) for i in range(3)]

    lr, tb = [], []
    for y in range(h):
        lr.extend(chans(px[y * w], px[y * w + w - 1]))
    for x in range(w):
        tb.extend(chans(px[x], px[(h - 1) * w + x]))
    return {
        "left_right_mean": round(sum(lr) / len(lr), 4),
        "top_bottom_mean": round(sum(tb) / len(tb), 4),
        "combined_mean": round((sum(lr) / len(lr) + sum(tb) / len(tb)) / 2, 4),
    }


def nfr007_sheet(named):
    """Native + 8x nearest from PNG bytes; locked palette, no SKView compositing."""
    gap = 12
    label = 8
    cols = []
    max_h = 0
    for name, (w, h, px) in named:
        nw, nh, mag = scale_nearest(w, h, px, 8)
        cols.append((name, w, h, px, nw, nh, mag))
        max_h = max(max_h, h, nh)
    col_w = max(c[1] + gap + c[4] for c in cols) + gap
    page_w = col_w * len(cols) + gap
    page_h = max_h + gap * 2 + label
    page = [INK] * (page_w * page_h)
    for i, (_name, w, h, px, nw, nh, mag) in enumerate(cols):
        origin_x = gap + i * col_w
        origin_y = gap
        blit(page_w, page, w, h, px, origin_x, origin_y)
        blit(page_w, page, nw, nh, mag, origin_x + w + gap, origin_y)
    return page_w, page_h, page


def main():
    before = {name: sha256_file(ASSETS / name) for name in RUNTIME_12}
    (EVIDENCE / "revise-validation").mkdir(parents=True, exist_ok=True)
    (EVIDENCE / "preview-1x").mkdir(exist_ok=True)
    (EVIDENCE / "preview-4x").mkdir(exist_ok=True)

    decoded = {}
    for name in RUNTIME_12:
        decoded[name] = decode_png(ASSETS / name)

    # Full-canvas 1x / 4x previews (no opaque-bbox crop).
    for name, (w, h, px) in decoded.items():
        (EVIDENCE / "preview-1x" / name).write_bytes(encode_png(w, h, px))
        nw, nh, scaled = scale_nearest(w, h, px, 4)
        (EVIDENCE / "preview-4x" / name.replace(".png", "_4x.png")).write_bytes(encode_png(nw, nh, scaled))

    char_imgs = [decoded[n] for n in CHARACTERS]
    crop_imgs = [decoded[n] for n in CROPS]
    cw, ch, cpx, cmeta = contact_sheet(char_imgs, 4, 4, pad=16)
    (EVIDENCE / "characters-contact-4x.png").write_bytes(encode_png(cw, ch, cpx))
    crw, crh, crpx, crmeta = contact_sheet(crop_imgs, 5, 4, pad=16)
    (EVIDENCE / "crops-contact-4x.png").write_bytes(encode_png(crw, crh, crpx))

    nfr_w, nfr_h, nfr_px = nfr007_sheet(
        [
            (n, decoded[n])
            for n in ["char_player.png", "char_water_apprentice.png", "crop_mist_radish.png", "tile_grass.png"]
        ]
    )
    nfr_path = EVIDENCE / "nfr-007-nearest-8x-from-png.png"
    nfr_path.write_bytes(encode_png(nfr_w, nfr_h, nfr_px))

    # O-3: align manifest with actual PNG alpha.
    report_path = EVIDENCE / "pixel-check.json"
    report = json.loads(report_path.read_text())
    o3_fixes = []
    for asset in report["assets"]:
        name = asset["file"]
        w, h, px = decoded[name]
        alphas = sorted({c[3] for c in px})
        actual_transparent_capable = 0 in alphas
        if asset.get("transparent") and not actual_transparent_capable:
            o3_fixes.append(
                {
                    "file": name,
                    "was": True,
                    "now": False,
                    "reason": f"alpha_values={alphas}; PNG is fully opaque",
                }
            )
            asset["transparent"] = False
        asset["alpha_values"] = alphas
        asset["sha256"] = before[name]
    report["metadata_corrections"] = {
        "o3": o3_fixes,
        "note": "Corrected evidence metadata only; runtime PNGs unchanged.",
    }
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")

    # Contact completeness: opaque bbox must sit strictly inside the preserved canvas rect.
    completeness = []
    ok = True
    for name, cell in zip(CHARACTERS, cmeta["cells"]):
        canvas = cell["canvas"]
        bbox = cell["bbox"]
        cx, cy, cw_, ch_ = canvas
        if bbox is None:
            ok = False
            completeness.append({"file": name, "pass": False, "reason": "empty"})
            continue
        x0, y0, x1, y1 = bbox
        # bbox is relative to scaled sprite; sprite is placed at canvas origin.
        headroom = {
            "top": y0,
            "left": x0,
            "right": cw_ - 1 - x1,
            "bottom": ch_ - 1 - y1,
            "canvas_w": cw_,
            "canvas_h": ch_,
            "sheet": [cw, ch],
            "pad_outside_canvas": cmeta["pad"],
        }
        # Full 32x48 canvas is present (128x192 at 4x). Transparent margins of the
        # native canvas plus 16px sheet pad must remain. Fail only if the *canvas*
        # was cropped (canvas_h < 192 or canvas_w < 128) or canvas hits sheet edge.
        canvas_complete = cw_ == 32 * 4 and ch_ == 48 * 4
        inset = (
            cx > 0
            and cy > 0
            and cx + cw_ < cw
            and cy + ch_ < ch
        )
        passed = canvas_complete and inset
        if not passed:
            ok = False
        completeness.append({"file": name, "pass": passed, **headroom, "canvas_complete": canvas_complete, "inset": inset})

    water_seams = seam_score(*decoded["tile_water_edge.png"])
    after = {name: sha256_file(ASSETS / name) for name in RUNTIME_12}
    hashes_unchanged = before == after

    validation = {
        "runtime_png_hashes_changed": not hashes_unchanged,
        "before": before,
        "after": after,
        "characters_contact": {"width": cw, "height": ch, **{k: cmeta[k] for k in ("cell_w", "cell_h", "pad", "scale")}},
        "crops_contact": {"width": crw, "height": crh, **{k: crmeta[k] for k in ("cell_w", "cell_h", "pad", "scale")}},
        "contact_completeness": completeness,
        "contact_completeness_pass": ok,
        "o2_tile_water_edge_seam": water_seams,
        "o3_fixes": o3_fixes,
        "nfr007_from_png": str(nfr_path.relative_to(ROOT)),
        "style_spec": str((EVIDENCE / "assets/style-spec.md").relative_to(ROOT)),
        "originality_review": str((EVIDENCE / "assets/originality-review.md").relative_to(ROOT)),
    }
    out = EVIDENCE / "revise-validation/rebuild-report.json"
    out.write_text(json.dumps(validation, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps({k: validation[k] for k in [
        "runtime_png_hashes_changed",
        "contact_completeness_pass",
        "characters_contact",
        "o2_tile_water_edge_seam",
        "o3_fixes",
    ]}, indent=2))
    if not hashes_unchanged:
        raise SystemExit("runtime PNG hashes changed")
    if not ok:
        raise SystemExit("contact completeness failed")


if __name__ == "__main__":
    main()
