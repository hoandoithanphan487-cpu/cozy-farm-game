#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""N-003 像素资产生成器(程序化,零依赖,原创 100%)

生成 3 职能角色(32x48)+ 5 作物(32x32)+ 3 地块(24x24)像素贴图,
输出到 macos/CreekSprout/CreekSprout/Assets/,并写 generation-log。
零第三方依赖:内置 mini PNG 编码器(zlib + struct)。
"""
import os
import random
import struct
import zlib

OUT = "macos/CreekSprout/CreekSprout/Assets"
os.makedirs(OUT, exist_ok=True)


class Canvas:
    """RGBA 像素画布 + mini PNG 编码器(每行 filter 0, zlib 压缩)。"""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.buf = bytearray(w * h * 4)  # 默认透明 (0,0,0,0)

    def px(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            i = (y * self.w + x) * 4
            self.buf[i:i + 4] = bytes(color[:3]) + bytes([color[3] if len(color) > 3 else 255])

    def save_png(self, path):
        def chunk(tag, data):
            c = struct.pack(">I", len(data)) + tag + data
            c += struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
            return c
        ihdr = struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0)
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)  # filter type 0
            start = y * self.w * 4
            raw += self.buf[start:start + self.w * 4]
        png = (b"\x89PNG\r\n\x1a\n"
               + chunk(b"IHDR", ihdr)
               + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
               + chunk(b"IEND", b""))
        with open(path, "wb") as f:
            f.write(png)

    def scaled(self, factor):
        """最近邻整数放大(预览用)。"""
        out = Canvas(self.w * factor, self.h * factor)
        for y in range(self.h):
            for x in range(self.w):
                i = (y * self.w + x) * 4
                c = tuple(self.buf[i:i + 4])
                for dy in range(factor):
                    for dx in range(factor):
                        out.px(x * factor + dx, y * factor + dy, c)
        return out

    def paste(self, other, ox, oy):
        """把 other 画布粘贴到 (ox,oy)(跳过透明像素)。"""
        for y in range(other.h):
            for x in range(other.w):
                i = (y * other.w + x) * 4
                c = tuple(other.buf[i:i + 4])
                if c[3]:
                    self.px(ox + x, oy + y, c)

# ---- 调色板(PRD 7.2 + N-001 主题色)----
SKIN = (245, 209, 173)
DARK = (56, 50, 46)          # 眼/嘴/靴深色(环境综合色,非纯黑)
WHITE = (242, 246, 240)      # 高光

CHAR_PALETTES = {
    "water_apprentice": dict(
        hair=(46, 50, 58), cloth=(72, 158, 173), edge=(31, 82, 97), accent=(176, 141, 87),
        label="水工学徒:雾蓝工衣/短黑发/青铜扳手"),
    "seed_steward": dict(
        hair=(142, 98, 47), cloth=(87, 143, 82), edge=(41, 77, 36), accent=(216, 178, 92),
        label="种源管理员:苔绿罩衫/麦褐束髻/种子布袋"),
    "creek_warden": dict(
        hair=(77, 71, 61), cloth=(122, 97, 71), edge=(71, 51, 31), accent=(166, 120, 66),
        label="溪岸巡护员:湿石外套/巡护帽/木桶"),
}

CROP_PALETTES = {
    "mist_radish": dict(main=(168, 210, 214), leaf=(60, 128, 82), dark=(96, 148, 152), label="雾萝卜:雾蓝萝卜头+苔绿叶"),
    "stream_leaf": dict(main=(118, 176, 108), dark=(70, 118, 66), stem=(150, 120, 70), label="溪叶菜:细长弯垂叶片"),
    "amber_bean": dict(pod=(214, 168, 84), leaf=(96, 148, 70), stem=(150, 110, 60), label="琥珀豆:藤+琥珀豆荚"),
    "bell_berry": dict(berry=(214, 112, 62), leaf=(74, 128, 64), dark=(140, 64, 38), label="铃花莓:灌木+铃形莓果"),
    "honey_melon": dict(melon=(236, 196, 110), dark=(190, 148, 72), leaf=(92, 140, 66), label="蜜穗瓜:木蜜瓜皮+卷须藤"),
}

# ---- 工具 ----
def new_canvas(w, h):
    return Canvas(w, h)

def px(img, x, y, color):
    img.px(x, y, color)

def blit(img, sx, sy, rows, colors):
    """sx,sy 起始像素;rows: 字符串列表,每字符查 colors 字典(' '=透明)。"""
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            c = colors.get(ch)
            if c:
                px(img, sx + x, sy + y, c)

# ---- 身体(程序化,32x48 画布下半) ----
def draw_body(img, cloth, edge, accent, skin):
    """躯干(行 16-35)+ 腿(36-43)+ 靴(44-47),以像素字典绘制。"""
    for y in range(16, 36):
        for x in range(7, 25):
            c = edge if (x in (7, 24) or y in (16, 35)) else cloth
            px(img, x, y, c)
    # 手臂(两侧,衣色+描边)
    for y in range(18, 32):
        px(img, 5, y, edge); px(img, 6, y, cloth)
        px(img, 25, y, cloth); px(img, 26, y, edge)
    # 腰带(行 27-28, accent)
    for y in (27, 28):
        for x in range(8, 24):
            px(img, x, y, accent)
    px(img, 15, 27, (232, 202, 140)); px(img, 16, 27, (232, 202, 140))  # 扣
    # 腿(行 36-43)
    for y in range(36, 44):
        for x in range(10, 15):
            px(img, x, y, edge if x in (10, 14) else cloth)
        for x in range(17, 22):
            px(img, x, y, edge if x in (17, 21) else cloth)
    # 靴(44-47)
    for y in range(44, 48):
        for x in range(8, 16):
            px(img, x, y, DARK)
        for x in range(16, 24):
            px(img, x, y, DARK)

# ---- 头部模板(16 行,16 列,居中到 x=8) ----
def head_template(kind):
    if kind == "short":      # 水工学徒:短黑发
        return [
            "    HHHHHHHH    ",
            "  HHHHHHHHHHHH  ",
            " HHHHHHHHHHHHHH ",
            " HHSSSSSSSSSSHH ",
            " HSSSSSSSSSSSSH ",
            " HSSSDSSSSDSSSH ",
            " HSSSSSSSSSSSSH ",
            " HSSSSSSSSSSSSH ",
            " HSSSSSSSSSSSSH ",
            " HHSSSSSSSSSSHH ",
            "  HHHSSSSSSHHH  ",
            "    HHSSSSHH    ",
            "     SSSSSS     ",
            "    OSSSSSSO    ",
            "   OOOOOOOOOO   ",
            "  OOOOOOOOOOOO  ",
        ]
    if kind == "bun":        # 种源管理员:麦褐束髻
        return [
            "     HHHHHH     ",
            "    HHSSHHHH    ",
            "   HHSSSSSSHH   ",
            "  HHSSSSSSSSHH  ",
            "  HSSSSSSSSSSH  ",
            "  HSSSDSSSSDSH  ",
            "  HSSSSSSSSSSH  ",
            "  HSSSSSSSSSSH  ",
            "  HSSSSSSSSSSH  ",
            "  HHSSSSSSSSHH  ",
            "   HHSSSSSSHH   ",
            "    HHSSSSHH    ",
            "     SSSSSS     ",
            "    OSSSSSSO    ",
            "   OOOOOOOOOO   ",
            "  OOOOOOOOOOOO  ",
        ]
    # wardencap:溪岸巡护员巡护帽
    return [
        "   HHHHHHHHHHHH   ",
        "  HHHHHHHHHHHHHH  ",
        " HHHHHHHHHHHHHHHH ",
        " HHAAAAAAAAAAAAHH ",
        " HHSSSSSSSSSSSSHH ",
        " HSSSDSSSSSSDSSH ",
        " HSSSSSSSSSSSSSH ",
        " HSSSSSSSSSSSSSH ",
        " HSSSSSSSSSSSSSH ",
        " HHSSSSSSSSSSHH  ",
        "  HHHSSSSSSHHH   ",
        "    HHSSSSHH     ",
        "     SSSSSS      ",
        "    OSSSSSSO     ",
        "   OOOOOOOOOO    ",
        "  OOOOOOOOOOOO   ",
    ]

def make_character(kind, pal):
    img = new_canvas(32, 48)
    # 头部模板
    rows = head_template(kind)
    colors = {
        "H": pal["hair"], "S": SKIN, "D": DARK,
        "O": pal["edge"], "A": pal["accent"], "W": WHITE,
    }
    blit(img, 8, 0, rows, colors)
    draw_body(img, pal["cloth"], pal["edge"], pal["accent"], SKIN)
    return img

# ---- 作物(32x32)----
def make_crop(kind, pal):
    img = new_canvas(32, 32)
    c = {
        "M": pal.get("main") or pal.get("melon") or (236, 196, 110),
        "D": pal.get("dark") or (96, 148, 152),
        "L": pal.get("leaf") or pal.get("main") or (60, 128, 82),
        "S": pal.get("stem") or pal.get("leaf") or pal.get("main") or (150, 120, 70),
        "P": pal.get("pod") or pal.get("main") or (214, 168, 84),
        "B": pal.get("berry") or pal.get("main") or (214, 112, 62),
        "W": WHITE, "K": DARK,
    }
    if kind == "mist_radish":
        rows = [
            "        LLLLLL        ",
            "       LLLLLLLL       ",
            "      LLLLLLLLLL      ",
            "     LLLLLLLLLLLL     ",
            "      LLLLLLLLLL      ",
            "       LLLLLLLL       ",
            "        LLLLLL        ",
            "     DDDDDDDDDDDD     ",
            "    DMMMMMMMMMMMMD    ",
            "   DMMMMMMMMMMMMMMD   ",
            "  DMMMMWMMMMMMWMMMMD  ",
            "  DMMMMMMMMMMMMMMMD   ",
            "  DMMMMMMMDMMMMMMMD   ",
            "  DMMMMMMMMMMMMMMMD   ",
            "   DMMMMMMMMMMMMMD    ",
            "    DDDDDDDDDDDDD     ",
        ]
    elif kind == "stream_leaf":
        rows = [
            "L                     ",
            "LL                    ",
            "LLL                   ",
            " LLL                  ",
            "  LLL                 ",
            "   LLL                ",
            "    LLL               ",
            "     LLL              ",
            "      LLL             ",
            "       LL             ",
            "        L             ",
            "        SS            ",
            "       SSS            ",
            "      SSSS            ",
            "     SSSSS            ",
            "    SSSSSS            ",
            "   SSSSSSS            ",
            "  SSSSSSSS            ",
            " SSSSSSSSS            ",
            "SSSSSSSSS             ",
        ]
    elif kind == "amber_bean":
        rows = [
            "        SS            ",
            "       SSSS           ",
            "      SSLLSS          ",
            "     SSLLLLSS         ",
            "      SSLLSS          ",
            "       SSSS           ",
            "        PP            ",
            "       PPPP           ",
            "      PPPPPP          ",
            "      PPPPPP          ",
            "       PPPP           ",
            "        PP            ",
            "        SS            ",
            "       SSSS           ",
            "      SSLLSS          ",
            "       SSSS           ",
        ]
    elif kind == "bell_berry":
        rows = [
            "      LLLLLLLL        ",
            "     LLLLLLLLLL       ",
            "    LLLLLLLLLLLL      ",
            "   LLLLLLLLLLLLLL     ",
            "    LLLLKKLLLLLL      ",
            "     LLLLLLLL         ",
            "      BBBBBB          ",
            "     BBBBBBBB         ",
            "     BBBBBBBB         ",
            "      BBBBBB          ",
            "      BB  BB          ",
            "      BB  BB          ",
            "     BBBBBBBB         ",
            "     BBBBBBBB         ",
            "      BBBBBB          ",
            "       KKKK           ",
        ]
    else:  # honey_melon
        rows = [
            "       LLLL           ",
            "      LLLLLL          ",
            "     LLLLLLLL         ",
            "      LLLLLL          ",
            "     MMMMMMMMM        ",
            "    MMMMMMMMMMM       ",
            "   MMMMMMMMMMMMM      ",
            "  MMMMMMMWMMMMMMM     ",
            "  MMMMMMMMMMMMMMM     ",
            "  MMMMMMMMMMMMMMM     ",
            "   MMMMMMMMMMMMM      ",
            "    MMMMMMMMMMM       ",
            "     MMMMMMMMM        ",
            "      SS SS           ",
            "     SSSSSS           ",
            "    SS    SS          ",
        ]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            col = c.get(ch)
            if col:
                px(img, x + (32 - len(row)) // 2, y + (32 - len(rows)) // 2, col)
    return img

# ---- 地块(24x24 程序化)----
def make_tile(kind):
    img = new_canvas(24, 24)
    if kind == "grass":
        base = (96, 138, 84)
        dots = [(118, 158, 96), (76, 116, 70), (140, 176, 108)]
    elif kind == "tilled":
        base = (122, 92, 64)
        dots = [(146, 112, 80), (98, 70, 50), (132, 100, 70)]
    else:  # water_edge
        base = (96, 156, 172)
        dots = [(130, 184, 196), (72, 132, 150), (240, 246, 240)]
    for y in range(24):
        for x in range(24):
            img.px(x, y, base)
    import random
    rng = random.Random(7)
    for _ in range(42):
        x, y = rng.randrange(24), rng.randrange(24)
        img.px(x, y, rng.choice(dots))
    if kind == "water_edge":
        for x in range(24):
            img.px(x, 2, (204, 230, 236))
            img.px(x, 20, (70, 120, 128))
    return img

# ---- 生成 ----
log = ["# N-003 资产生成日志(程序化生成器 scripts/generate-pixel-assets.py)", "",
       "| 文件 | 尺寸 | 来源 | 说明 |", "|---|---|---|---|"]

for key, pal in CHAR_PALETTES.items():
    img = make_character(key, pal)
    path = os.path.join(OUT, f"char_{key}.png")
    img.save_png(path)
    log.append(f"| char_{key}.png | 32x48 | 程序化模板 | {pal['label']} |")

for key, pal in CROP_PALETTES.items():
    img = make_crop(key, pal)
    path = os.path.join(OUT, f"crop_{key}.png")
    img.save_png(path)
    log.append(f"| crop_{key}.png | 32x32 | 程序化模板 | {pal['label']} |")

for key in ("grass", "tilled", "water_edge"):
    img = make_tile(key)
    path = os.path.join(OUT, f"tile_{key}.png")
    img.save_png(path)
    log.append(f"| tile_{key}.png | 24x24 | 程序化 | 地块:{key} |")

with open(os.path.join(OUT, "generation-log.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(log) + "\n")

# 合成一张预览图(角色放大 8x)
preview = new_canvas(32 * 8 * 3 + 40, 48 * 8)
for i, key in enumerate(CHAR_PALETTES):
    img = make_character(key, CHAR_PALETTES[key])
    big = img.scaled(8)
    preview.paste(big, i * (32 * 8 + 20), 0)
preview.save_png("artifacts/n-003-pixel-preview.png")
print("生成完成:", sorted(os.listdir(OUT)))
