#!/usr/bin/env python3
"""Generate the approved cozy-farm runtime pixel-art batch without third-party deps."""

from __future__ import annotations

import hashlib
import json
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "macos/CreekSprout/CreekSprout/Assets"
EVIDENCE = ROOT / "artifacts/art-style/runtime-batch-r0"
CANDIDATES = ROOT / "artifacts/art-style/candidates/runtime-r0"

P = {
    "clear": (0, 0, 0, 0),
    "ink": (0x26, 0x36, 0x38, 255),
    "stone": (0x55, 0x48, 0x4A, 255),
    "shadow": (0x76, 0x52, 0x47, 255),
    "moss": (0x78, 0x86, 0x53, 255),
    "mist": (0x78, 0x97, 0xA0, 255),
    "creek": (0x4F, 0x70, 0x70, 255),
    "straw": (0xB5, 0x8A, 0x52, 255),
    "honey": (0xC5, 0x8A, 0x59, 255),
    "copper": (0xC6, 0x6E, 0x3D, 255),
    "paper": (0xF0, 0xD9, 0xAD, 255),
}
OPAQUE = {v for k, v in P.items() if k != "clear"}


class Canvas:
    def __init__(self, w: int, h: int, color=P["clear"]):
        self.w, self.h = w, h
        self.px = [color] * (w * h)

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y * self.w + x] = c

    def rect(self, x, y, w, h, c):
        for yy in range(max(0, y), min(self.h, y + h)):
            off = yy * self.w
            for xx in range(max(0, x), min(self.w, x + w)):
                self.px[off + xx] = c

    def line(self, x0, y0, x1, y1, c, thick=1):
        dx, sx = abs(x1 - x0), 1 if x0 < x1 else -1
        dy, sy = -abs(y1 - y0), 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.rect(x0 - thick // 2, y0 - thick // 2, thick, thick, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def ellipse(self, cx, cy, rx, ry, c):
        if rx <= 0 or ry <= 0:
            return
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if ((x - cx) ** 2) * ry * ry + ((y - cy) ** 2) * rx * rx <= rx * rx * ry * ry:
                    self.set(x, y, c)

    def poly(self, pts, c):
        ys = [p[1] for p in pts]
        for y in range(max(0, min(ys)), min(self.h - 1, max(ys)) + 1):
            xs = []
            for i, (x1, y1) in enumerate(pts):
                x2, y2 = pts[(i + 1) % len(pts)]
                if y1 == y2:
                    continue
                if min(y1, y2) <= y < max(y1, y2):
                    xs.append(x1 + (y - y1) * (x2 - x1) / (y2 - y1))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                self.rect(math.ceil(xs[i]), y, math.floor(xs[i + 1]) - math.ceil(xs[i]) + 1, 1, c)

    def blit(self, src: "Canvas", x0: int, y0: int, scale=1, opaque=False):
        for y in range(src.h):
            for x in range(src.w):
                c = src.px[y * src.w + x]
                if c[3] == 0 and not opaque:
                    continue
                self.rect(x0 + x * scale, y0 + y * scale, scale, scale, c)


def png_bytes(img: Canvas) -> bytes:
    raw = bytearray()
    for y in range(img.h):
        raw.append(0)
        for c in img.px[y * img.w:(y + 1) * img.w]:
            raw.extend(c)
    def chunk(kind, payload):
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", img.w, img.h, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")


generated = {}
written = 0
skipped = 0


def decode_png(path: Path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not png")
    pos = 8
    idat = b""
    width = height = None
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        typ = data[pos + 4:pos + 8]
        payload = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if typ == b"IHDR":
            width, height, depth, color, *_ = struct.unpack(">IIBBBBB", payload)
            if depth != 8 or color != 6:
                raise ValueError("not RGBA8")
        elif typ == b"IDAT":
            idat += payload
        elif typ == b"IEND":
            break
    raw = zlib.decompress(idat)
    stride = width * 4
    pixels = []
    p = 0
    for _ in range(height):
        filt = raw[p]
        p += 1
        scan = bytearray(raw[p:p + stride])
        p += stride
        if filt != 0:
            raise ValueError(f"png filter {filt}")
        pixels.extend(tuple(scan[i:i + 4]) for i in range(0, stride, 4))
    return width, height, pixels, data


def canvas_from_pixels(width, height, pixels):
    img = Canvas(width, height)
    img.px = list(pixels)
    return img


def existing_passes_contract(path: Path, size, rel: str):
    try:
        w, h, pixels, _ = decode_png(path)
    except Exception:
        return False
    if (w, h) != size:
        return False
    alpha = {p[3] for p in pixels}
    if not alpha <= {0, 255}:
        return False
    if any(p[3] == 0 and p != (0, 0, 0, 0) for p in pixels):
        return False
    if any(p[3] and p not in OPAQUE for p in pixels):
        return False
    if not any(p[3] for p in pixels):
        return False
    if rel.startswith("char_") and (rel.endswith("_walk.png") or "_action_" in rel):
        baselines = []
        for row in range(4):
            for col in range(4):
                ys = [y for y in range(48) for x in range(32) if pixels[(row * 48 + y) * w + col * 32 + x][3]]
                baselines.append(max(ys) if ys else -1)
        if len(set(baselines)) != 1:
            return False
    return True


def save(rel: str, img: Canvas, candidate=False):
    global written, skipped
    base = CANDIDATES if candidate else ASSETS
    path = base / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and existing_passes_contract(path, (img.w, img.h), rel):
        w, h, pixels, data = decode_png(path)
        generated[("candidate" if candidate else "runtime", rel)] = (canvas_from_pixels(w, h, pixels), data)
        skipped += 1
        return
    data = png_bytes(img)
    path.write_bytes(data)
    generated[("candidate" if candidate else "runtime", rel)] = (img, data)
    written += 1


def checker(w, h):
    c = Canvas(w, h, P["paper"])
    for y in range(0, h, 4):
        for x in range(0, w, 4):
            if ((x // 4) + (y // 4)) % 2:
                c.rect(x, y, 4, 4, P["mist"])
    return c


def character(spec, direction="down", step=0):
    c = Canvas(32, 48)
    skin, hair, tunic, accent, tool, silhouette = spec
    # Keep the bottom-center baseline fixed in every walking frame.
    bob = 0
    leg = -1 if step == 1 else (1 if step == 3 else 0)
    # feet and legs
    c.rect(10 + leg, 40 + bob, 5, 5, P["ink"])
    c.rect(18 - leg, 40 + bob, 5, 5, P["ink"])
    c.rect(11 + leg, 39 + bob, 4, 3, P["stone"])
    c.rect(18 - leg, 39 + bob, 4, 3, P["stone"])
    # body silhouette
    c.rect(9, 23 + bob, 14, 17, P["ink"])
    c.rect(10, 24 + bob, 12, 14, tunic)
    c.rect(6, 26 + bob, 4, 10, P["ink"])
    c.rect(22, 26 + bob, 4, 10, P["ink"])
    c.rect(7, 27 + bob, 3, 8, tunic)
    c.rect(22, 27 + bob, 3, 8, tunic)
    c.rect(9, 32 + bob, 14, 3, accent)
    # head
    c.rect(9, 8 + bob, 14, 15, P["ink"])
    c.rect(10, 10 + bob, 12, 12, skin)
    if direction == "up":
        c.rect(10, 9 + bob, 12, 11, hair)
        c.rect(13, 20 + bob, 6, 2, skin)
    else:
        c.rect(10, 8 + bob, 12, 5, hair)
        c.rect(9, 11 + bob, 3, 8, hair)
        c.rect(20, 11 + bob, 3, 8, hair)
        eye_y = 16 + bob
        if direction == "left":
            c.rect(12, eye_y, 2, 2, P["ink"])
        elif direction == "right":
            c.rect(18, eye_y, 2, 2, P["ink"])
        else:
            c.rect(12, eye_y, 2, 2, P["ink"])
            c.rect(18, eye_y, 2, 2, P["ink"])
    # silhouette/accessory signatures
    if silhouette == "farmer":
        c.rect(7, 7 + bob, 18, 3, hair); c.rect(11, 4 + bob, 10, 4, hair)
        c.line(5, 25 + bob, 5, 44 + bob, tool, 2); c.line(4, 25 + bob, 9, 22 + bob, tool, 2)
    elif silhouette == "apprentice":
        c.rect(8, 6 + bob, 16, 4, P["mist"]); c.rect(12, 3 + bob, 9, 4, P["mist"])
        c.line(25, 27 + bob, 28, 41 + bob, tool, 2); c.rect(25, 25 + bob, 5, 5, P["copper"])
    elif silhouette == "steward":
        c.rect(8, 7 + bob, 16, 3, P["moss"]); c.rect(12, 5 + bob, 8, 3, P["moss"])
        c.rect(4, 29 + bob, 6, 8, P["straw"]); c.rect(5, 30 + bob, 4, 2, P["paper"])
    elif silhouette == "warden":
        c.rect(7, 7 + bob, 18, 3, P["stone"]); c.rect(10, 4 + bob, 12, 4, P["stone"])
        c.line(25, 25 + bob, 28, 39 + bob, P["straw"], 2); c.rect(23, 24 + bob, 5, 3, P["creek"])
    elif silhouette == "hearsay":
        c.ellipse(16, 6 + bob, 5, 4, hair); c.rect(5, 31 + bob, 7, 6, P["straw"]); c.rect(6, 29 + bob, 5, 2, P["paper"])
    elif silhouette == "storyteller":
        c.rect(7, 22 + bob, 18, 5, P["copper"]); c.rect(24, 29 + bob, 5, 8, P["copper"]); c.rect(25, 27 + bob, 3, 3, P["paper"])
    elif silhouette == "evidence":
        c.rect(5, 28 + bob, 6, 10, P["paper"]); c.rect(6, 30 + bob, 4, 1, P["shadow"]); c.rect(6, 33 + bob, 4, 1, P["shadow"])
    elif silhouette == "consensus":
        c.rect(8, 12 + bob, 3, 14, hair); c.rect(21, 12 + bob, 3, 14, hair); c.rect(12, 29 + bob, 8, 6, P["paper"])
    return c


CHARACTERS = {
    "player": (P["paper"], P["shadow"], P["honey"], P["moss"], P["straw"], "farmer"),
    "water_apprentice": (P["paper"], P["ink"], P["mist"], P["creek"], P["copper"], "apprentice"),
    "seed_steward": (P["paper"], P["shadow"], P["moss"], P["straw"], P["paper"], "steward"),
    "creek_warden": (P["honey"], P["ink"], P["shadow"], P["mist"], P["straw"], "warden"),
    "neighbor_hearsay": (P["paper"], P["stone"], P["straw"], P["honey"], P["paper"], "hearsay"),
    "neighbor_storyteller": (P["honey"], P["shadow"], P["copper"], P["straw"], P["paper"], "storyteller"),
    "neighbor_evidence": (P["paper"], P["ink"], P["creek"], P["mist"], P["paper"], "evidence"),
    "neighbor_consensus": (P["paper"], P["straw"], P["paper"], P["shadow"], P["paper"], "consensus"),
}


def gen_characters():
    dirs = ["down", "left", "right", "up"]
    for slug, spec in CHARACTERS.items():
        save(f"char_{slug}.png", character(spec))
        sheet = Canvas(128, 192)
        for row, direction in enumerate(dirs):
            for col in range(4):
                sheet.blit(character(spec, direction, col), col * 32, row * 48)
        save(f"char_{slug}_walk.png", sheet)
    for action in ["hoe", "watering_can", "harvest_glove"]:
        sheet=Canvas(128,192)
        for row,direction in enumerate(dirs):
            for col in range(4):
                frame=character(CHARACTERS["player"],direction,col)
                phase=col-1
                if action=="hoe": frame.line(20,27,27-phase,16+col*3,P["honey"],2); frame.line(24-phase,16+col*3,30-phase,18+col*3,P["stone"],2)
                elif action=="watering_can": frame.rect(20,27,8,7,P["creek"]); frame.line(27,29,31,26+phase,P["mist"],2)
                else: frame.rect(21,26,6,6,P["paper"]); frame.rect(22,30,5,2,P["copper"])
                sheet.blit(frame,col*32,row*48)
        save(f"char_player_action_{action}.png",sheet)


def crop_sprite(slug, stage):
    c = Canvas(32, 32)
    if stage == 0:
        c.rect(14, 26, 4, 3, P["shadow"]); c.rect(15, 25, 2, 2, P["straw"]); return c
    scale = stage
    base = 27
    c.line(16, base, 16, base - (5 + stage * 3), P["moss"], 2)
    if slug == "mist_radish":
        if stage >= 2: c.ellipse(16, 24, 4 + stage, 3 + stage, P["mist"]); c.rect(12, 25, 8, 3, P["paper"])
        c.poly([(15, 21), (8, 15 - stage), (14, 17), (16, 10 - stage), (18, 17), (25, 14 - stage), (19, 22)], P["moss"])
    elif slug == "stream_leaf":
        for i in range(3 + stage):
            x = 7 + i * 4
            c.line(16, 26, x, 14 - stage + (i % 2) * 2, P["moss"], 3)
            c.set(x, 13 - stage + (i % 2) * 2, P["paper"])
        c.rect(14, 25, 5, 3, P["shadow"])
    elif slug == "amber_bean":
        if stage >= 2:
            c.line(9, 28, 11, 8, P["straw"], 2); c.line(23, 28, 21, 8, P["straw"], 2); c.line(11, 9, 21, 9, P["straw"], 2)
        c.line(16, 27, 15, 10 + (3-stage)*3, P["moss"], 2)
        if stage == 3:
            c.rect(12, 14, 3, 6, P["honey"]); c.rect(18, 18, 3, 6, P["straw"]); c.rect(14, 11, 5, 3, P["moss"])
    elif slug == "bell_berry":
        c.ellipse(16, 21, 7 + stage, 5 + stage, P["moss"])
        c.rect(8, 20, 4, 3, P["creek"]); c.rect(20, 18, 4, 3, P["creek"])
        if stage == 3:
            for x, y in [(10, 23), (16, 18), (22, 23)]:
                c.rect(x, y, 4, 4, P["copper"]); c.rect(x + 1, y, 2, 1, P["mist"])
    elif slug == "honey_melon":
        c.line(15, 26, 9, 21, P["moss"], 2); c.line(17, 26, 24, 22, P["moss"], 2)
        if stage >= 2:
            c.ellipse(17, 24, 4 + stage * 2, 3 + stage, P["honey"])
            if stage == 3:
                c.line(14, 20, 14, 27, P["straw"]); c.line(20, 20, 20, 27, P["straw"]); c.line(23, 18, 27, 15, P["moss"])
    return c


def gen_crops():
    for slug in ["mist_radish", "stream_leaf", "amber_bean", "bell_berry", "honey_melon"]:
        for stage in range(4):
            img = crop_sprite(slug, stage)
            save(f"crop_{slug}_stage_{stage}.png", img)
        save(f"crop_{slug}.png", crop_sprite(slug, 3))


def grass_tile(seed=0):
    c = Canvas(24, 24, P["moss"])
    for x, y in [(2+seed, 4), (10, 2+seed), (18, 7), (5, 16+seed%2), (14+seed%2, 19), (22-seed, 13)]:
        c.set(x % 24, y % 24, P["creek"]); c.set((x + 1) % 24, y % 24, P["straw"])
    return c


def tilled(watered=False):
    c = Canvas(24, 24, P["shadow"] if watered else P["honey"])
    for y in [3, 9, 15, 21]:
        c.line(0, y, 23, y, P["stone"] if watered else P["shadow"])
        for x in [4, 14]: c.rect(x, y - 1, 5, 1, P["straw"])
    if watered:
        c.rect(4, 4, 5, 1, P["mist"]); c.rect(15, 16, 4, 1, P["mist"])
    return c


def water(frame=0):
    c = Canvas(24, 24, P["creek"])
    for i, (x, y) in enumerate([(1, 5), (9, 11), (4, 18), (16, 3), (18, 16)]):
        xx = (x + frame * (1 if i % 2 == 0 else -1)) % 24
        c.rect(xx, y, 5 if i % 2 == 0 else 3, 1, P["mist"])
    return c


def water_edge(direction, corner=False):
    c = Canvas(24, 24)
    if corner:
        # corner names indicate the water-filled corner
        sx = 1 if "e" in direction else -1
        sy = 1 if "s" in direction else -1
        cx = 23 if sx > 0 else 0; cy = 23 if sy > 0 else 0
        for y in range(24):
            for x in range(24):
                if (x-cx)*sx >= -15 and (y-cy)*sy >= -15 and abs(x-cx)+abs(y-cy) < 25:
                    c.set(x, y, P["creek"])
        c.line(0 if sx > 0 else 23, cy, cx, 0 if sy > 0 else 23, P["mist"], 2)
    else:
        if direction == "n": c.rect(0, 0, 24, 15, P["creek"]); c.rect(0, 14, 24, 2, P["mist"])
        if direction == "s": c.rect(0, 9, 24, 15, P["creek"]); c.rect(0, 8, 24, 2, P["mist"])
        if direction == "w": c.rect(0, 0, 15, 24, P["creek"]); c.rect(14, 0, 2, 24, P["mist"])
        if direction == "e": c.rect(9, 0, 15, 24, P["creek"]); c.rect(8, 0, 2, 24, P["mist"])
    return c


def stone_path():
    c = Canvas(24, 24)
    for x, y, w, h in [(2, 3, 8, 6), (12, 2, 9, 7), (5, 11, 10, 6), (16, 10, 7, 6), (1, 19, 9, 4), (12, 18, 10, 5)]:
        c.rect(x, y, w, h, P["stone"]); c.rect(x + 1, y + 1, max(1, w - 3), 1, P["mist"])
    return c


def canal(vertical=True):
    c = Canvas(24, 24)
    if vertical:
        c.rect(5, 0, 4, 24, P["stone"]); c.rect(15, 0, 4, 24, P["stone"]); c.rect(9, 0, 6, 24, P["creek"])
        for y in [3, 11, 19]: c.rect(10, y, 4, 1, P["mist"])
    else:
        c.rect(0, 5, 24, 4, P["stone"]); c.rect(0, 15, 24, 4, P["stone"]); c.rect(0, 9, 24, 6, P["creek"])
        for x in [3, 11, 19]: c.rect(x, 10, 1, 4, P["mist"])
    return c


def gen_tiles():
    save("tile_grass.png", grass_tile(0)); save("tile_tilled.png", tilled(False)); save("tile_water_edge.png", water_edge("n"))
    for i, s in enumerate([1, 2, 3], start=1): save(f"tile_grass_{chr(96+i)}.png", grass_tile(s))
    save("tile_tilled_watered.png", tilled(True))
    for i in range(4): save(f"tile_water_f{i:02}.png", water(i))
    for d in "nesw": save(f"tile_water_edge_{d}.png", water_edge(d))
    for d in ["ne", "se", "sw", "nw"]: save(f"tile_water_corner_{d}.png", water_edge(d, True))
    save("tile_stone_path.png", stone_path())
    save("tile_canal_ns.png", canal(True)); save("tile_canal_ew.png", canal(False))


BUILDINGS = {
    "farm_house": (144, 144, "house"),
    "farm_sluice": (192, 168, "sluice"),
    "market_seed_shed": (96, 96, "seed"),
    "market_warden_post": (96, 96, "warden"),
    "market_wharf": (144, 96, "wharf"),
}


def building_layers(w, h, kind):
    layers = {name: Canvas(w, h) for name in ["base", "structure", "roof", "detail", "interaction", "state_fx"]}
    b, s, r, d, inter, fx = [layers[n] for n in layers]
    if kind == "wharf":
        b.rect(12, h-27, w-24, 19, P["stone"]); b.rect(22, h-34, w-44, 9, P["stone"])
        b.rect(18, h-25, w-36, 4, P["mist"]); b.rect(w//2-12, h-18, 24, 10, P["creek"])
        s.rect(16, h-44, 6, 28, P["shadow"]); s.rect(w-22, h-44, 6, 28, P["shadow"])
        s.rect(11, h-49, 16, 7, P["honey"]); s.rect(w-27, h-49, 16, 7, P["honey"])
        # Upper occlusion/cap layer fulfills the six-layer building contract.
        r.rect(38, h-47, w-76, 5, P["ink"]); r.rect(42, h-46, w-84, 3, P["honey"])
        d.rect(w//2-18, h-38, 36, 5, P["straw"]); d.rect(w//2-10, h-32, 20, 3, P["moss"])
        inter.rect(20, h-17, 12, 3, P["paper"]); fx.rect(w//2-8, h-15, 5, 1, P["mist"]); fx.rect(w//2+3, h-11, 6, 1, P["mist"])
        return layers
    x0 = 14 if w <= 100 else 20
    x1 = w - x0
    floor = h - 15
    wall_top = h // 2 if kind != "sluice" else h // 2 + 4
    b.rect(x0, floor-12, x1-x0, 12, P["stone"])
    for x in range(x0+3, x1-3, 15): b.rect(x, floor-10, 11, 7, P["shadow"])
    s.rect(x0+4, wall_top, x1-x0-8, floor-wall_top-9, P["straw"])
    s.rect(x0+7, wall_top+3, 5, floor-wall_top-12, P["shadow"]); s.rect(x1-12, wall_top+3, 5, floor-wall_top-12, P["shadow"])
    # roof, all original gables but differentiated profiles
    if kind == "house":
        r.poly([(x0-5, wall_top+5), (w//2, 18), (x1+5, wall_top+5)], P["ink"])
        r.poly([(x0, wall_top+3), (w//2, 23), (x1, wall_top+3)], P["honey"])
        r.poly([(x0+13, wall_top-10), (w//2+10, 34), (x1-10, wall_top-7)], P["shadow"])
    elif kind == "sluice":
        r.poly([(x0-3, wall_top+2), (x0+20, 28), (x1-27, 28), (x1+2, wall_top+2)], P["ink"])
        r.poly([(x0+1, wall_top), (x0+23, 33), (x1-29, 33), (x1-2, wall_top)], P["creek"])
    elif kind == "seed":
        r.poly([(x0-3, wall_top+2), (w//2-8, 25), (x1+3, wall_top+2)], P["ink"])
        r.poly([(x0+1, wall_top), (w//2-8, 29), (x1-1, wall_top)], P["moss"])
    else:
        r.poly([(x0-3, wall_top+2), (w//2+10, 25), (x1+3, wall_top+2)], P["ink"])
        r.poly([(x0+1, wall_top), (w//2+10, 29), (x1-1, wall_top)], P["mist"])
    # doors/windows/details
    door_x = w//2-7 if kind != "seed" else x0+9
    d.rect(door_x, floor-32, 14, 23, P["ink"]); d.rect(door_x+3, floor-29, 9, 20, P["shadow"]); d.rect(door_x+9, floor-20, 2, 2, P["copper"])
    if kind == "seed":
        d.rect(w//2, floor-34, 27, 14, P["ink"]); d.rect(w//2+2, floor-32, 23, 10, P["paper"])
        for x in range(w//2+3, w//2+24, 7): d.rect(x, floor-24, 5, 5, P["straw"])
        d.rect(x0+4, wall_top+6, 13, 5, P["moss"])
    elif kind == "warden":
        d.poly([(x0+8, floor-40), (w//2+8, floor-46), (x1-8, floor-40), (x1-13, floor-23), (x0+13, floor-23)], P["ink"])
        d.poly([(x0+11, floor-39), (w//2+8, floor-43), (x1-11, floor-39), (x1-15, floor-27), (x0+15, floor-27)], P["mist"])
        d.line(x0+3, floor-39, x0+3, floor-15, P["straw"], 2); d.line(x0+3, floor-38, x0+12, floor-31, P["straw"], 2)
    elif kind == "sluice":
        cx, cy = x1-12, floor-33
        d.ellipse(cx, cy, 25, 25, P["ink"]); d.ellipse(cx, cy, 21, 21, P["honey"]); d.ellipse(cx, cy, 6, 6, P["shadow"])
        for a in range(0, 360, 45):
            d.line(cx, cy, cx+int(19*math.cos(math.radians(a))), cy+int(19*math.sin(math.radians(a))), P["shadow"], 3)
        d.rect(x1+8, floor-34, 24, 8, P["creek"]); d.line(x1+25, floor-30, x1+34, floor-47, P["copper"], 3)
        fx.rect(x1-30, floor-9, 34, 5, P["creek"]); fx.rect(x1-26, floor-8, 15, 1, P["mist"])
    else:
        d.rect(x0+11, floor-38, 17, 13, P["ink"]); d.rect(x0+14, floor-35, 11, 8, P["mist"])
        d.rect(x1-30, floor-38, 17, 13, P["ink"]); d.rect(x1-27, floor-35, 11, 8, P["paper"])
    inter.rect(door_x+2, floor-8, 10, 3, P["paper"])
    inter.rect(door_x+5, floor-5, 4, 2, P["copper"])
    if kind in ("seed", "warden"): fx.rect(x1-23, wall_top+8, 12, 3, P["paper"])
    if kind == "house": fx.rect(w//2-14, 27, 28, 3, P["paper"])
    return layers


def gen_buildings():
    for slug, (w, h, kind) in BUILDINGS.items():
        for layer, img in building_layers(w, h, kind).items():
            save(f"building_{slug}_{layer}.png", img)


def prop_crate():
    c=Canvas(24,24); c.rect(3,5,18,17,P["ink"]); c.rect(5,7,14,13,P["honey"]); c.line(5,7,19,20,P["shadow"],2); c.line(19,7,5,20,P["shadow"],2); return c
def prop_compost():
    c=Canvas(48,48); c.rect(5,16,38,27,P["ink"]); c.rect(8,19,32,21,P["shadow"]); c.rect(10,22,28,8,P["moss"]); c.line(8,19,8,44,P["straw"],3); c.line(40,19,40,44,P["straw"],3); c.line(6,17,42,17,P["honey"],3); return c
def rain_barrel():
    c=Canvas(24,32); c.ellipse(12,8,8,4,P["ink"]); c.rect(4,8,16,19,P["ink"]); c.rect(6,9,12,17,P["shadow"]); c.rect(4,13,16,3,P["straw"]); c.rect(4,23,16,3,P["straw"]); c.ellipse(12,8,6,2,P["creek"]); c.rect(9,7,6,1,P["mist"]); return c
def gather(kind):
    c=Canvas(24,24)
    if kind=="creek_wood": c.line(3,19,20,7,P["ink"],5); c.line(4,18,19,7,P["honey"],3); c.line(13,11,18,17,P["shadow"],2)
    elif kind=="moss_stone": c.ellipse(12,16,9,6,P["stone"]); c.rect(5,12,12,4,P["mist"]); c.rect(8,9,8,4,P["moss"]); c.rect(15,12,5,3,P["moss"])
    else:
        for x in [7,11,15,18]: c.line(x,21,x-2,5+(x%3),P["moss"],2); c.line(x-1,11,x+3,8,P["straw"],1)
        c.rect(5,17,15,3,P["honey"])
    return c
def tool(kind):
    c=Canvas(24,24)
    if kind=="hoe": c.line(6,21,17,5,P["honey"],3); c.line(13,5,21,9,P["stone"],3)
    elif kind=="watering_can": c.rect(5,9,12,10,P["creek"]); c.rect(7,6,8,4,P["ink"]); c.line(16,11,22,8,P["mist"],3); c.rect(3,12,3,5,P["stone"])
    else: c.poly([(7,20),(5,12),(7,7),(10,13),(10,5),(13,12),(14,4),(17,12),(19,8),(20,15),(16,21)],P["paper"]); c.rect(7,18,10,3,P["copper"])
    return c


def gen_props():
    save("prop_wooden_crate.png", prop_crate()); save("prop_stone_path.png", stone_path()); save("prop_compost_rack.png", prop_compost())
    save("prop_canal_segment_ns.png", canal(True)); save("prop_canal_segment_ew.png", canal(False)); save("prop_rain_barrel.png", rain_barrel())
    for k in ["creek_wood","moss_stone","reed_fiber"]: save(f"gather_{k}.png", gather(k))
    for k in ["hoe","watering_can","harvest_glove"]: save(f"tool_{k}.png", tool(k))


def target(valid, frame):
    c=Canvas(24,24); col=P["moss"] if valid else P["copper"]
    seg=6 if valid else 3
    for x,y,dx,dy in [(2,2,1,0),(2,2,0,1),(21,2,-1,0),(21,2,0,1),(2,21,1,0),(2,21,0,-1),(21,21,-1,0),(21,21,0,-1)]:
        c.line(x,y,x+dx*(seg-frame),y+dy*(seg-frame),col,2)
    return c
def splash(frame):
    c=Canvas(32,32); y=25-frame*3
    c.ellipse(16,y,7+frame,2,P["creek"])
    for x,off in [(10,2),(16,5),(22,1)]: c.rect(x,y-4-off-frame,2,3,P["mist"])
    return c
def harvest(frame):
    c=Canvas(32,32); y=24-frame*4; c.ellipse(16,y,5,4,P["copper"]); c.rect(15,y-5,3,2,P["moss"]); c.rect(8+frame*2,26-frame*2,2,2,P["straw"]); c.rect(23-frame,22-frame,2,2,P["paper"]); return c
def flow(frame):
    c=Canvas(24,24); c.rect(0,8,24,8,P["creek"])
    for x in [(-4+frame*4)%24, (8+frame*4)%24, (18+frame*4)%24]: c.rect(x,10,5,1,P["mist"])
    return c
def ui_icon(kind):
    c=Canvas(24,24)
    if kind=="time": c.ellipse(12,12,8,8,P["paper"]); c.ellipse(12,12,6,6,P["ink"]); c.line(12,12,12,7,P["paper"],2); c.line(12,12,16,14,P["paper"],2)
    elif kind=="weather": c.ellipse(10,11,6,4,P["mist"]); c.ellipse(15,13,6,4,P["mist"]); c.line(8,17,6,21,P["creek"],2); c.line(14,17,12,21,P["creek"],2); c.line(20,17,18,21,P["creek"],2)
    elif kind=="stamina": c.poly([(12,21),(4,12),(5,7),(9,5),(12,8),(15,5),(19,7),(20,12)],P["copper"])
    else: c.ellipse(12,13,8,8,P["straw"]); c.ellipse(12,13,5,5,P["honey"]); c.rect(10,8,4,10,P["paper"]); c.rect(8,11,8,4,P["paper"])
    return c


def gen_fx_ui():
    for valid in [True,False]:
        for i in range(2): save(f"fx_target_{'valid' if valid else 'invalid'}_f{i:02}.png",target(valid,i))
    for i in range(4): save(f"fx_water_splash_f{i:02}.png",splash(i)); save(f"fx_harvest_f{i:02}.png",harvest(i)); save(f"fx_canal_flow_f{i:02}.png",flow(i))
    badge=Canvas(24,24); badge.ellipse(12,12,10,10,P["ink"]); badge.rect(6,7,12,10,P["paper"]); badge.rect(9,10,6,4,P["copper"]); save("ui_interact_badge.png",badge)
    slot=Canvas(24,24); slot.rect(2,2,20,20,P["ink"]); slot.rect(4,4,16,16,P["stone"]); save("ui_slot.png",slot)
    selected=Canvas(24,24); selected.rect(1,1,22,22,P["paper"]); selected.rect(3,3,18,18,P["copper"]); selected.rect(5,5,14,14,P["stone"]); save("ui_slot_selected.png",selected)
    for k in ["time","weather","stamina","currency"]: save(f"ui_{k}.png",ui_icon(k))


def cat_character(kind):
    c=Canvas(32,48); fur={"black":P["ink"],"calico":P["paper"],"ragdoll":P["paper"]}[kind]
    c.rect(9,23,14,17,P["ink"]); c.rect(10,24,12,14,P["honey"] if kind!="black" else P["stone"])
    c.rect(9,8,14,15,P["ink"]); c.rect(10,10,12,12,fur); c.poly([(10,10),(10,4),(15,9)],fur); c.poly([(22,10),(22,4),(17,9)],fur)
    if kind=="calico": c.rect(10,10,5,6,P["copper"]); c.rect(18,16,4,5,P["shadow"])
    if kind=="ragdoll": c.rect(10,10,12,6,P["mist"]); c.rect(8,13,3,10,P["paper"]); c.rect(21,13,3,10,P["paper"])
    c.rect(12,16,2,2,P["creek"]); c.rect(18,16,2,2,P["creek"]); c.rect(15,19,2,2,P["copper"])
    c.rect(10,39,5,5,P["ink"]); c.rect(18,39,5,5,P["ink"]); c.rect(8,29,16,3,P["copper"])
    if kind=="black": c.rect(22,26,5,8,P["copper"])
    if kind=="calico": c.rect(5,27,5,8,P["moss"])
    if kind=="ragdoll": c.rect(12,25,8,5,P["paper"])
    return c
def animal(kind):
    c=Canvas(24,24); col={"rabbit":P["paper"],"duck":P["straw"],"squirrel":P["copper"],"hedgehog":P["shadow"],"frog":P["moss"],"bird":P["mist"]}[kind]
    if kind=="rabbit": c.ellipse(12,15,7,5,col); c.rect(8,4,3,8,col); c.rect(14,3,3,9,col); c.rect(16,14,2,2,P["ink"])
    elif kind=="duck": c.ellipse(11,16,8,5,col); c.ellipse(15,10,5,4,col); c.rect(19,10,4,2,P["copper"]); c.rect(16,9,2,2,P["ink"])
    elif kind=="squirrel": c.ellipse(12,16,6,5,col); c.ellipse(7,10,6,7,col); c.rect(14,9,5,6,col); c.rect(17,10,2,2,P["ink"])
    elif kind=="hedgehog": c.poly([(3,17),(5,9),(9,11),(12,6),(15,11),(20,10),(22,18)],P["ink"]); c.ellipse(15,16,6,4,col); c.rect(19,15,2,2,P["ink"])
    elif kind=="frog": c.ellipse(12,16,8,5,col); c.ellipse(8,10,3,3,col); c.ellipse(16,10,3,3,col); c.rect(7,9,2,2,P["ink"]); c.rect(15,9,2,2,P["ink"])
    else: c.ellipse(12,14,7,5,col); c.poly([(6,14),(2,10),(8,11)],col); c.rect(17,12,4,2,P["straw"]); c.rect(14,12,2,2,P["ink"])
    return c
def foliage(kind, idx):
    c=Canvas(24,24)
    if idx==0: blobs=[(12,16,9,6),(7,12,5,5),(16,11,6,6)]
    elif idx==1: blobs=[(11,17,10,5),(5,14,4,5),(13,10,5,7),(19,15,4,5)]
    elif idx==2: blobs=[(12,16,8,7),(7,17,4,4),(17,16,5,5),(12,8,4,6)]
    else: blobs=[(12,17,10,5),(5,13,4,4),(11,12,5,5),(18,10,4,7)]
    for j,(x,y,rx,ry) in enumerate(blobs): c.ellipse(x,y,rx,ry,P["creek"] if j%3==1 else P["moss"])
    flower=[P["paper"],P["copper"],P["mist"],P["straw"]][idx%4]
    if kind=="flower":
        for x,y in [(7,12),(13,8),(18,14),(11,17)]: c.rect(x,y,3,3,flower); c.set(x+1,y+1,P["honey"])
    return c
def cat_shop():
    c=Canvas(144,120); c.rect(15,94,114,14,P["stone"]); c.rect(21,51,102,46,P["straw"]); c.poly([(13,55),(39,22),(106,22),(132,55)],P["ink"]); c.poly([(18,53),(42,27),(103,27),(127,53)],P["honey"]); c.rect(39,60,66,23,P["ink"]); c.rect(42,63,60,17,P["shadow"]); c.rect(26,70,18,27,P["ink"]); c.rect(29,74,12,23,P["copper"]); c.rect(102,67,15,30,P["ink"]); c.rect(105,71,9,26,P["shadow"]); c.rect(54,39,36,10,P["paper"]); c.rect(60,42,6,4,P["copper"]); c.rect(78,42,6,4,P["copper"]); c.rect(48,83,52,5,P["copper"]); c.rect(58,88,32,6,P["ink"]); c.rect(64,90,20,3,P["straw"]); return c


def gen_candidates():
    save("candidate_building_cat_bbq_shop_r0.png",cat_shop(),True)
    for k in ["black","calico","ragdoll"]: save(f"candidate_char_cat_bbq_{k}_r0.png",cat_character(k),True)
    for k in ["rabbit","duck","squirrel","hedgehog","frog","bird"]: save(f"candidate_ambient_{k}_r0.png",animal(k),True)
    for i in range(4): save(f"candidate_shrub_{i+1:02}_r0.png",foliage("shrub",i),True)
    for i in range(4): save(f"candidate_flower_clump_{i+1:02}_r0.png",foliage("flower",i),True)


def make_contact(name, items, cols=4, cell_w=208, cell_h=208):
    rows=math.ceil(len(items)/cols); page=checker(cols*cell_w,rows*cell_h)
    for i,(scope,rel) in enumerate(items):
        img=generated[(scope,rel)][0]; scale=max(1,min((cell_w-16)//img.w,(cell_h-16)//img.h,6))
        x=(i%cols)*cell_w+(cell_w-img.w*scale)//2; y=(i//cols)*cell_h+(cell_h-img.h*scale)//2
        page.blit(img,x,y,scale)
        page.rect((i%cols)*cell_w+3,(i//cols)*cell_h+3,10,10,[P["copper"],P["moss"],P["mist"],P["straw"]][i%4])
    EVIDENCE.mkdir(parents=True,exist_ok=True); (EVIDENCE/name).write_bytes(png_bytes(page))


def make_building_composites():
    cells=[]
    for slug,(w,h,_) in BUILDINGS.items():
        merged=Canvas(w,h)
        for layer in ["base","structure","roof","detail","interaction","state_fx"]:
            merged.blit(generated[("runtime",f"building_{slug}_{layer}.png")][0],0,0)
        cells.append(merged)
    page=checker(640,440)
    positions=[(0,0),(256,0),(0,220),(208,220),(416,220)]
    for i,(img,(x,y)) in enumerate(zip(cells,positions)):
        scale=2 if img.w<=144 and img.h<=144 else 1
        page.blit(img,x+(208-img.w*scale)//2,y+(210-img.h*scale)//2,scale)
        page.rect(x+4,y+4,12,12,[P["honey"],P["copper"],P["moss"],P["mist"],P["stone"]][i])
    (EVIDENCE/"buildings-composite-review.png").write_bytes(png_bytes(page))


def make_tile_3x3_review():
    names=["tile_grass.png","tile_tilled.png","tile_tilled_watered.png","tile_water_f00.png"]
    page=checker(312,312)
    for i,name in enumerate(names):
        src=generated[("runtime",name)][0]; block=Canvas(72,72)
        for yy in range(3):
            for xx in range(3): block.blit(src,xx*24,yy*24)
        x=(i%2)*156+6; y=(i//2)*156+6; page.blit(block,x,y,2)
        page.rect((i%2)*156+3,(i//2)*156+3,8,8,[P["moss"],P["honey"],P["shadow"],P["creek"]][i])
    (EVIDENCE/"tiles-3x3-joint-review.png").write_bytes(png_bytes(page))


def build_manifest():
    records=[]
    for (scope,rel),(img,data) in sorted(generated.items()):
        alpha=sorted({c[3] for c in img.px}); colors=sorted({c for c in img.px if c[3]})
        bad=[c for c in colors if c not in OPAQUE]
        transparent_rgb_clean=all(c==(0,0,0,0) for c in img.px if c[3]==0)
        records.append({"scope":scope,"file":rel,"width":img.w,"height":img.h,"alpha_values":alpha,"opaque_color_count":len(colors),"palette_ok":not bad,"transparent_rgb_clean":transparent_rgb_clean,"sha256":hashlib.sha256(data).hexdigest()})
    EVIDENCE.mkdir(parents=True,exist_ok=True)
    (EVIDENCE/"manifest.json").write_text(json.dumps({"palette":{k:"#%02X%02X%02X"%v[:3] for k,v in P.items() if k!="clear"},"assets":records},ensure_ascii=False,indent=2)+"\n")
    return records


def main():
    gen_characters(); gen_crops(); gen_tiles(); gen_buildings(); gen_props(); gen_fx_ui(); gen_candidates()
    records=build_manifest()
    groups={
        "characters-contact-4x.png":[k for k in generated if k[0]=="runtime" and k[1].startswith("char_") and not k[1].endswith("_walk.png")],
        "crops-contact-4x.png":[k for k in generated if k[0]=="runtime" and k[1].startswith("crop_") and "stage" not in k[1]],
        "tiles-contact-4x.png":[k for k in generated if k[0]=="runtime" and k[1].startswith("tile_")],
        "buildings-contact-2x.png":[k for k in generated if k[0]=="runtime" and k[1].startswith("building_")],
        "props-fx-ui-contact-4x.png":[k for k in generated if k[0]=="runtime" and k[1].split("_")[0] in {"prop","gather","tool","fx","ui"}],
        "world-life-candidates-contact-4x.png":[k for k in generated if k[0]=="candidate"],
    }
    for name,items in groups.items(): make_contact(name,items)
    make_building_composites(); make_tile_3x3_review()
    print(f"generated={len(records)} written={written} skipped={skipped} runtime={sum(r['scope']=='runtime' for r in records)} candidate={sum(r['scope']=='candidate' for r in records)}")
    print(f"palette_ok={all(r['palette_ok'] for r in records)} alpha_ok={all(set(r['alpha_values']) <= {0,255} for r in records)} transparent_rgb_clean={all(r['transparent_rgb_clean'] for r in records)}")


if __name__ == "__main__":
    main()
