#!/usr/bin/env python3
"""N-003 first-round runtime pixels: native-size redraw, locked Master Doc palette.

Redraws only PO-approved first-round files:
  4 character R0 (32x48), 5 crop R0 (32x32), 3 tile R0 (24x24).
Does not scale C0 concept images. Does not touch walk sheets, stages, buildings,
props, FX, UI, or N-004.
"""
from __future__ import annotations

import hashlib
import json
import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "macos/CreekSprout/CreekSprout/Assets"
EVIDENCE = ROOT / "artifacts/art-style/n-003-first-round"

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
        rr_x, rr_y = rx * rx, ry * ry
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if ((x - cx) ** 2) * rr_y + ((y - cy) ** 2) * rr_x <= rr_x * rr_y:
                    self.set(x, y, c)

    def blit_rows(self, ox, oy, rows, pal):
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                color = pal.get(ch)
                if color:
                    self.set(ox + x, oy + y, color)

    def scaled(self, factor: int) -> "Canvas":
        out = Canvas(self.w * factor, self.h * factor)
        for y in range(self.h):
            for x in range(self.w):
                c = self.px[y * self.w + x]
                out.rect(x * factor, y * factor, factor, factor, c)
        return out


def png_bytes(img: Canvas) -> bytes:
    raw = bytearray()
    for y in range(img.h):
        raw.append(0)
        for c in img.px[y * img.w : (y + 1) * img.w]:
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
        + chunk(b"IHDR", struct.pack(">IIBBBBB", img.w, img.h, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )


# Shared 32x48 body language: head around y=8-20, torso 21-35, legs 36-42, boots 43-47.
# Outline uses ink/stone/shadow, never a global black stroke.

PAL = {
    ".": None,
    "i": P["ink"],
    "s": P["stone"],
    "h": P["shadow"],
    "m": P["moss"],
    "f": P["mist"],
    "c": P["creek"],
    "w": P["straw"],
    "y": P["honey"],
    "r": P["copper"],
    "p": P["paper"],
}


def char_player():
    """Moss-tuft hair, honey wrap, moss sash, hoe on viewer-left."""
    c = Canvas(32, 48)
    # hoe shaft + copper blade
    c.line(5, 22, 5, 46, P["straw"], 2)
    c.rect(2, 20, 7, 4, P["ink"])
    c.rect(1, 21, 6, 3, P["copper"])
    c.rect(1, 21, 2, 3, P["creek"])
    # boots
    c.rect(10, 43, 6, 5, P["ink"])
    c.rect(17, 43, 6, 5, P["ink"])
    c.rect(11, 43, 4, 3, P["shadow"])
    c.rect(18, 43, 4, 3, P["shadow"])
    # legs
    c.rect(11, 36, 5, 8, P["stone"])
    c.rect(17, 36, 5, 8, P["stone"])
    c.rect(12, 38, 3, 3, P["moss"])
    c.rect(18, 40, 3, 2, P["moss"])
    # wrap tunic
    c.rect(9, 22, 15, 15, P["ink"])
    c.rect(10, 23, 13, 13, P["honey"])
    c.rect(10, 23, 13, 3, P["moss"])
    c.rect(10, 31, 13, 2, P["moss"])
    c.rect(16, 24, 2, 8, P["shadow"])  # wrap sash diagonal cue
    c.rect(14, 27, 3, 2, P["shadow"])  # pouch
    # arms
    c.rect(6, 24, 4, 10, P["ink"])
    c.rect(7, 25, 3, 8, P["honey"])
    c.rect(23, 24, 4, 10, P["ink"])
    c.rect(23, 25, 3, 8, P["moss"])
    c.rect(6, 33, 4, 3, P["paper"])  # left hand on hoe
    c.rect(23, 33, 4, 3, P["paper"])
    # head + moss tuft
    c.ellipse(16, 14, 7, 7, P["ink"])
    c.ellipse(16, 14, 6, 6, P["paper"])
    c.rect(10, 8, 13, 5, P["shadow"])
    c.rect(12, 5, 9, 4, P["shadow"])
    c.rect(14, 3, 5, 3, P["shadow"])
    c.set(15, 2, P["shadow"])
    c.set(18, 2, P["shadow"])
    c.rect(10, 11, 3, 6, P["shadow"])
    c.rect(20, 11, 3, 6, P["shadow"])
    c.rect(13, 16, 2, 2, P["ink"])
    c.rect(18, 16, 2, 2, P["ink"])
    c.rect(15, 19, 3, 1, P["stone"])
    c.rect(13, 21, 7, 2, P["paper"])  # collar
    return c


def char_water_apprentice():
    """Short ink hair, mist tunic, creek trim, copper wrench, hip shovel."""
    c = Canvas(32, 48)
    c.line(5, 24, 5, 38, P["shadow"], 2)
    c.rect(2, 20, 7, 6, P["ink"])
    c.rect(3, 21, 5, 4, P["copper"])
    c.rect(2, 22, 3, 3, P["mist"])  # C-wrench jaw
    c.rect(1, 23, 3, 2, P["copper"])
    # boots
    c.rect(10, 43, 6, 5, P["ink"])
    c.rect(17, 43, 6, 5, P["ink"])
    c.rect(11, 43, 4, 2, P["paper"])
    c.rect(18, 43, 4, 2, P["paper"])
    c.rect(11, 45, 4, 2, P["honey"])
    c.rect(18, 45, 4, 2, P["honey"])
    # legs
    c.rect(11, 36, 5, 8, P["creek"])
    c.rect(17, 36, 5, 8, P["creek"])
    c.rect(12, 39, 3, 2, P["mist"])
    # tunic
    c.rect(9, 22, 15, 15, P["ink"])
    c.rect(10, 23, 13, 13, P["mist"])
    c.rect(10, 23, 13, 2, P["creek"])
    c.rect(10, 32, 13, 2, P["creek"])
    c.rect(16, 25, 2, 8, P["shadow"])  # cross strap
    c.rect(12, 30, 4, 5, P["straw"])  # shovel blade at hip
    c.rect(13, 31, 2, 3, P["shadow"])
    c.rect(21, 29, 4, 4, P["shadow"])  # pouch
    # arms
    c.rect(6, 24, 4, 10, P["ink"])
    c.rect(7, 25, 3, 8, P["mist"])
    c.rect(23, 24, 4, 10, P["ink"])
    c.rect(23, 25, 3, 8, P["creek"])
    c.rect(6, 33, 4, 3, P["paper"])
    c.rect(23, 33, 4, 3, P["paper"])
    # short hair + head
    c.ellipse(16, 14, 7, 7, P["ink"])
    c.ellipse(16, 14, 6, 6, P["paper"])
    c.rect(10, 7, 13, 6, P["ink"])
    c.rect(12, 5, 8, 3, P["ink"])
    c.set(14, 4, P["ink"])
    c.set(18, 4, P["ink"])
    c.rect(13, 16, 2, 2, P["creek"])
    c.rect(18, 16, 2, 2, P["creek"])
    c.rect(15, 19, 3, 1, P["stone"])
    c.rect(13, 21, 7, 2, P["paper"])
    return c


def char_seed_steward():
    """Long shadow hair, moss tunic, paper apron, seed bag + dish/basket."""
    c = Canvas(32, 48)
    # boots
    c.rect(10, 43, 6, 5, P["ink"])
    c.rect(17, 43, 6, 5, P["ink"])
    c.rect(11, 43, 4, 3, P["shadow"])
    c.rect(18, 43, 4, 3, P["shadow"])
    # legs
    c.rect(11, 37, 5, 7, P["creek"])
    c.rect(17, 37, 5, 7, P["creek"])
    # long tunic
    c.rect(8, 22, 17, 16, P["ink"])
    c.rect(9, 23, 15, 14, P["moss"])
    c.rect(11, 27, 11, 10, P["paper"])  # apron
    c.rect(15, 30, 3, 4, P["moss"])  # sprout mark
    c.rect(14, 26, 5, 2, P["shadow"])  # belt
    # hair curtains
    c.rect(7, 12, 4, 16, P["shadow"])
    c.rect(22, 12, 4, 18, P["shadow"])
    # bag left
    c.rect(3, 28, 6, 8, P["ink"])
    c.rect(4, 29, 4, 6, P["paper"])
    c.rect(5, 31, 2, 3, P["moss"])
    c.rect(5, 27, 2, 2, P["straw"])
    # seed dish/basket right
    c.rect(24, 29, 7, 6, P["ink"])
    c.rect(25, 30, 5, 4, P["straw"])
    c.rect(26, 31, 2, 2, P["honey"])
    c.rect(28, 32, 2, 2, P["moss"])
    # arms
    c.rect(6, 24, 4, 8, P["ink"])
    c.rect(7, 25, 3, 6, P["moss"])
    c.rect(23, 24, 4, 8, P["ink"])
    c.rect(23, 25, 3, 6, P["moss"])
    c.rect(5, 31, 4, 3, P["paper"])
    c.rect(24, 31, 4, 3, P["paper"])
    # head + bun/long hair
    c.ellipse(16, 14, 7, 7, P["ink"])
    c.ellipse(16, 14, 6, 6, P["paper"])
    c.rect(10, 7, 13, 6, P["shadow"])
    c.rect(13, 4, 7, 4, P["shadow"])
    c.set(16, 3, P["shadow"])
    c.rect(13, 16, 2, 2, P["creek"])
    c.rect(18, 16, 2, 2, P["creek"])
    c.rect(15, 19, 3, 1, P["stone"])
    c.rect(13, 21, 7, 2, P["paper"])
    return c


def char_creek_warden():
    """Stone cap, mist scarf, shadow coat, net left, bucket right."""
    c = Canvas(32, 48)
    # boots
    c.rect(10, 43, 6, 5, P["ink"])
    c.rect(17, 43, 6, 5, P["ink"])
    c.rect(11, 43, 4, 2, P["creek"])
    c.rect(18, 43, 4, 2, P["creek"])
    # legs
    c.rect(11, 36, 5, 8, P["stone"])
    c.rect(17, 36, 5, 8, P["stone"])
    c.rect(12, 39, 3, 2, P["moss"])
    # coat
    c.rect(8, 22, 17, 15, P["ink"])
    c.rect(9, 23, 15, 13, P["shadow"])
    c.rect(9, 23, 15, 2, P["mist"])
    c.rect(14, 28, 5, 2, P["creek"])  # sash
    c.rect(18, 27, 4, 5, P["stone"])  # pouch
    # scarf
    c.rect(12, 20, 9, 4, P["mist"])
    c.rect(20, 22, 3, 6, P["creek"])
    # net in left hand
    c.ellipse(6, 34, 5, 6, P["straw"])
    c.ellipse(6, 34, 3, 4, P["clear"])
    c.rect(5, 32, 3, 8, P["straw"])
    c.set(4, 38, P["mist"])
    c.set(8, 39, P["mist"])
    # bucket right
    c.rect(24, 32, 7, 8, P["ink"])
    c.rect(25, 33, 5, 6, P["honey"])
    c.rect(26, 33, 3, 2, P["creek"])
    c.rect(26, 31, 3, 2, P["straw"])
    # arms
    c.rect(6, 24, 4, 9, P["ink"])
    c.rect(7, 25, 3, 7, P["shadow"])
    c.rect(7, 25, 3, 2, P["mist"])
    c.rect(23, 24, 4, 9, P["ink"])
    c.rect(23, 25, 3, 7, P["shadow"])
    c.rect(6, 32, 4, 3, P["paper"])
    c.rect(23, 32, 4, 3, P["paper"])
    # cap + head
    c.ellipse(16, 15, 7, 7, P["ink"])
    c.ellipse(16, 15, 6, 6, P["paper"])
    c.rect(9, 6, 15, 6, P["stone"])
    c.rect(11, 4, 11, 3, P["stone"])
    c.rect(10, 8, 13, 2, P["creek"])
    c.rect(15, 5, 3, 2, P["copper"])
    c.rect(10, 12, 4, 5, P["shadow"])  # bangs
    c.rect(19, 12, 4, 5, P["shadow"])
    c.rect(22, 16, 3, 8, P["shadow"])  # ponytail
    c.rect(13, 17, 2, 2, P["ink"])
    c.rect(18, 17, 2, 2, P["ink"])
    c.rect(15, 20, 3, 1, P["stone"])
    return c


def crop_mist_radish():
    """Low round mist bulb, moss leaf cluster. No pedestal, no halo."""
    c = Canvas(32, 32)
    c.ellipse(16, 22, 9, 7, P["ink"])
    c.ellipse(16, 22, 8, 6, P["mist"])
    c.rect(12, 24, 8, 3, P["paper"])
    c.rect(14, 26, 5, 2, P["straw"])
    # leaves
    c.line(16, 16, 8, 8, P["moss"], 3)
    c.line(16, 16, 16, 4, P["moss"], 3)
    c.line(16, 16, 24, 9, P["moss"], 3)
    c.line(16, 16, 11, 12, P["creek"], 2)
    c.rect(15, 6, 2, 8, P["paper"])
    c.rect(9, 10, 3, 2, P["moss"])
    c.rect(22, 11, 3, 2, P["moss"])
    return c


def crop_stream_leaf():
    """Leaves bend the same creek-ward direction; wet-stone root."""
    c = Canvas(32, 32)
    c.rect(4, 24, 8, 6, P["shadow"])
    c.rect(5, 25, 6, 4, P["stone"])
    c.line(8, 24, 14, 8, P["paper"], 2)
    c.line(9, 24, 22, 6, P["moss"], 3)
    c.line(10, 25, 26, 12, P["moss"], 3)
    c.line(11, 26, 24, 18, P["creek"], 2)
    c.line(12, 26, 20, 22, P["moss"], 2)
    c.set(22, 6, P["paper"])
    c.set(26, 12, P["paper"])
    c.rect(23, 7, 4, 2, P["moss"])
    c.rect(25, 14, 5, 2, P["creek"])
    return c


def crop_amber_bean():
    """Tall straw trellis, honey/straw pods."""
    c = Canvas(32, 32)
    c.line(10, 30, 12, 4, P["straw"], 2)
    c.line(22, 30, 20, 4, P["straw"], 2)
    c.line(12, 5, 20, 5, P["straw"], 2)
    c.rect(14, 3, 5, 3, P["honey"])
    c.line(16, 28, 16, 8, P["moss"], 2)
    c.line(12, 12, 18, 18, P["moss"], 1)
    c.rect(8, 14, 4, 7, P["honey"])
    c.rect(9, 15, 2, 5, P["straw"])
    c.rect(20, 11, 4, 7, P["honey"])
    c.rect(21, 12, 2, 5, P["straw"])
    c.rect(14, 18, 4, 6, P["honey"])
    c.rect(8, 10, 3, 3, P["moss"])
    c.rect(21, 8, 3, 3, P["moss"])
    c.rect(18, 20, 3, 3, P["moss"])
    return c


def crop_bell_berry():
    """Low bush, hanging copper bells with mist highlight."""
    c = Canvas(32, 32)
    c.ellipse(16, 18, 10, 9, P["ink"])
    c.ellipse(16, 18, 9, 8, P["moss"])
    c.rect(14, 10, 3, 6, P["shadow"])
    c.rect(8, 14, 4, 4, P["creek"])
    c.rect(21, 13, 4, 4, P["creek"])
    for x, y in ((9, 18), (15, 16), (21, 19), (12, 22), (19, 23)):
        c.rect(x, y, 4, 5, P["copper"])
        c.rect(x + 1, y, 2, 1, P["mist"])
        c.rect(x + 1, y + 3, 2, 1, P["paper"])
    c.rect(18, 8, 4, 4, P["moss"])
    c.rect(7, 20, 3, 3, P["moss"])
    return c


def crop_honey_melon():
    """Horizontal honey melon, pale ribs, tendril curl. No halo."""
    c = Canvas(32, 32)
    c.ellipse(18, 20, 11, 7, P["ink"])
    c.ellipse(18, 20, 10, 6, P["honey"])
    c.line(12, 17, 12, 24, P["straw"])
    c.line(18, 16, 18, 25, P["paper"])
    c.line(24, 17, 24, 24, P["straw"])
    c.rect(8, 18, 4, 4, P["shadow"])
    c.line(10, 16, 6, 10, P["moss"], 2)
    c.line(8, 12, 4, 14, P["moss"], 2)
    c.rect(5, 8, 5, 4, P["moss"])
    c.rect(3, 12, 2, 2, P["paper"])  # tiny blossom, still palette
    c.rect(22, 12, 5, 4, P["moss"])
    c.line(26, 14, 29, 10, P["creek"], 1)
    c.set(29, 9, P["moss"])
    return c


def tile_grass():
    c = Canvas(24, 24, P["moss"])
    # wrapped low-contrast moss specks; no centered motif
    dots = [
        (1, 3, P["creek"]),
        (8, 1, P["straw"]),
        (15, 4, P["creek"]),
        (21, 2, P["straw"]),
        (4, 9, P["straw"]),
        (12, 11, P["creek"]),
        (19, 8, P["straw"]),
        (2, 16, P["creek"]),
        (9, 18, P["straw"]),
        (17, 15, P["creek"]),
        (22, 20, P["straw"]),
        (6, 22, P["creek"]),
        (13, 21, P["straw"]),
    ]
    for x, y, col in dots:
        c.set(x % 24, y % 24, col)
    return c


def tile_tilled():
    c = Canvas(24, 24, P["honey"])
    for y in (3, 9, 15, 21):
        c.line(0, y, 23, y, P["shadow"])
        c.rect(0, y - 1, 24, 1, P["stone"])
        for x in (5, 14):
            c.rect(x, y + 1, 4, 1, P["straw"])
    return c


def tile_water_edge():
    """Pilot shoreline: opaque water south, stone bank, mist highlight."""
    c = Canvas(24, 24)
    c.rect(0, 0, 24, 9, P["moss"])
    for x, y in ((2, 2), (11, 1), (19, 3), (7, 5)):
        c.set(x, y, P["creek"])
    c.rect(0, 8, 24, 3, P["stone"])
    c.rect(0, 10, 24, 2, P["mist"])
    c.rect(0, 12, 24, 12, P["creek"])
    c.rect(3, 16, 5, 1, P["mist"])
    c.rect(14, 20, 6, 1, P["mist"])
    c.rect(8, 13, 4, 1, P["paper"])
    return c


CHARACTERS = {
    "char_player.png": (char_player, "brookseed.player.sprout", "concept_character_player_v01.png", "bottom-center"),
    "char_water_apprentice.png": (
        char_water_apprentice,
        "brookseed.npc.water_apprentice",
        "concept_character_water_apprentice_v01.png",
        "bottom-center",
    ),
    "char_seed_steward.png": (
        char_seed_steward,
        "brookseed.npc.seed_steward",
        "concept_character_seed_steward_v01.png",
        "bottom-center",
    ),
    "char_creek_warden.png": (
        char_creek_warden,
        "brookseed.npc.creek_warden",
        "concept_character_creek_warden_v01.png",
        "bottom-center",
    ),
}
CROPS = {
    "crop_mist_radish.png": (crop_mist_radish, "brookseed.crop.mist_radish", "mist_radish/concept_crop_mist_radish_v01.png"),
    "crop_stream_leaf.png": (crop_stream_leaf, "brookseed.crop.stream_leaf", "stream_leaf/concept_crop_stream_leaf_v01.png"),
    "crop_amber_bean.png": (crop_amber_bean, "brookseed.crop.amber_bean", "amber_bean/concept_crop_amber_bean_v01.png"),
    "crop_bell_berry.png": (crop_bell_berry, "brookseed.crop.bell_berry", "bell_berry/concept_crop_bell_berry_v01.png"),
    "crop_honey_melon.png": (crop_honey_melon, "brookseed.crop.honey_melon", "honey_melon/concept_crop_honey_melon_v01.png"),
}
TILES = {
    "tile_grass.png": (tile_grass, False, "center"),
    "tile_tilled.png": (tile_tilled, False, "center"),
    "tile_water_edge.png": (tile_water_edge, False, "center"),
}


def inspect(img: Canvas):
    colors = sorted({c for c in img.px if c[3]})
    alpha = sorted({c[3] for c in img.px})
    dirty = [c for c in img.px if c[3] == 0 and c != (0, 0, 0, 0)]
    off = [c for c in colors if c not in OPAQUE]
    return {
        "width": img.w,
        "height": img.h,
        "alpha_values": alpha,
        "opaque_color_count": len(colors),
        "palette_ok": not off,
        "transparent_rgb_clean": not dirty,
        "has_opaque": any(c[3] for c in img.px),
        "off_palette": ["#%02X%02X%02X" % c[:3] for c in off],
    }


def save_png(path: Path, img: Canvas) -> bytes:
    data = png_bytes(img)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return data


def contact_sheet(items, cols, scale, pad=16):
    """Keep the full native canvas (including transparent gutters). Do not crop to opaque bbox."""
    cell_w = items[0].w * scale + pad * 2
    cell_h = items[0].h * scale + pad * 2
    rows = math.ceil(len(items) / cols)
    page = Canvas(cols * cell_w, rows * cell_h, P["stone"])
    for i, img in enumerate(items):
        preview = img.scaled(scale)
        x = (i % cols) * cell_w + pad
        y = (i // cols) * cell_h + pad
        for yy in range(preview.h):
            for xx in range(preview.w):
                c = preview.px[yy * preview.w + xx]
                if c[3]:
                    page.set(x + xx, y + yy, c)
    return page


def tile_3x3(img: Canvas) -> Canvas:
    page = Canvas(72, 72)
    for y in range(3):
        for x in range(3):
            for py in range(24):
                for px in range(24):
                    page.set(x * 24 + px, y * 24 + py, img.px[py * 24 + px])
    return page


def main():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    prev1 = EVIDENCE / "preview-1x"
    prev4 = EVIDENCE / "preview-4x"
    prev1.mkdir(exist_ok=True)
    prev4.mkdir(exist_ok=True)

    records = []
    runtime_images = []
    failures = []

    def emit(name, img, meta):
        data = save_png(ASSETS / name, img)
        save_png(prev1 / name, img)
        save_png(prev4 / name.replace(".png", "_4x.png"), img.scaled(4))
        info = inspect(img)
        info.update(meta)
        info["file"] = name
        info["sha256"] = hashlib.sha256(data).hexdigest()
        records.append(info)
        runtime_images.append((name, img))
        if info["width"] != meta["native"][0] or info["height"] != meta["native"][1]:
            failures.append(f"{name} size")
        if not info["palette_ok"] or not info["transparent_rgb_clean"] or info["alpha_values"] != [0, 255] and info["alpha_values"] != [255]:
            if set(info["alpha_values"]) - {0, 255}:
                failures.append(f"{name} alpha {info['alpha_values']}")
            if not info["palette_ok"]:
                failures.append(f"{name} palette {info['off_palette']}")
            if not info["transparent_rgb_clean"]:
                failures.append(f"{name} dirty transparent RGB")
        if not info["has_opaque"]:
            failures.append(f"{name} empty")

    for name, (fn, stable_id, concept, anchor) in CHARACTERS.items():
        img = fn()
        emit(
            name,
            img,
            {
                "stable_id": stable_id,
                "concept": f"artifacts/art-style/characters/{concept}",
                "native": (32, 48),
                "transparent": True,
                "anchor": anchor,
                "state": "idle-front",
                "prompt_version": "n-003-first-round-r0-v01",
            },
        )
    for name, (fn, stable_id, concept) in CROPS.items():
        emit(
            name,
            fn(),
            {
                "stable_id": stable_id,
                "concept": f"artifacts/art-style/crops/{concept}",
                "native": (32, 32),
                "transparent": True,
                "anchor": "bottom-center",
                "state": "mature",
                "prompt_version": "n-003-first-round-r0-v01",
            },
        )
    for name, (fn, _unused, anchor) in TILES.items():
        img = fn()
        emit(
            name,
            img,
            {
                "stable_id": name.replace(".png", ""),
                "concept": "artifacts/art-style/tiles/",
                "native": (24, 24),
                # R0 water_edge PNG is fully opaque (pilot shoreline fallback).
                # Master Doc §9.4 allows alpha, but metadata must match the file.
                "transparent": False,
                "anchor": anchor,
                "state": "default",
                "prompt_version": "n-003-first-round-r0-v01",
            },
        )

    grass = next(img for name, img in runtime_images if name == "tile_grass.png")
    tilled = next(img for name, img in runtime_images if name == "tile_tilled.png")
    water = next(img for name, img in runtime_images if name == "tile_water_edge.png")
    sheet3 = Canvas(232, 80, P["ink"])
    for idx, img in enumerate((grass, tilled, water)):
        block = tile_3x3(img)
        for y in range(72):
            for x in range(72):
                sheet3.set(4 + idx * 76 + x, 4 + y, block.px[y * 72 + x])
    save_png(EVIDENCE / "tiles-3x3-joint-review.png", sheet3)

    chars = [img for name, img in runtime_images if name.startswith("char_")]
    crops = [img for name, img in runtime_images if name.startswith("crop_")]
    save_png(EVIDENCE / "characters-contact-4x.png", contact_sheet(chars, 4, 4, pad=16))
    save_png(EVIDENCE / "crops-contact-4x.png", contact_sheet(crops, 5, 4, pad=16))

    report = {
        "task": "N-003 first-round R0",
        "order": "char_player C0 confirmed -> characters -> crops -> tiles",
        "visual_anchor": "artifacts/art-style/visual-anchor-warm-medieval-v1.png promoted by Product Owner",
        "palette": {k: "#%02X%02X%02X" % v[:3] for k, v in P.items() if k != "clear"},
        "method": "native-size pixel redraw from C0 silhouette notes; C0 not scaled",
        "failures": failures,
        "assets": records,
    }
    (EVIDENCE / "pixel-check.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(f"wrote={len(records)} failures={failures}")
    if failures:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
