#!/usr/bin/env python3
"""Render a screenshot as coarse ASCII art for layout review without vision.

Usage: python3 scripts/ascii-shot.py <png> [cols] [rows]
"""
import sys
from PIL import Image

def main() -> None:
    path = sys.argv[1]
    cols = int(sys.argv[2]) if len(sys.argv) > 2 else 96
    rows = int(sys.argv[3]) if len(sys.argv) > 3 else 48
    im = Image.open(path).convert("RGB")
    w, h = im.size
    small = im.resize((cols, rows))
    px = small.load()

    def classify(r, g, b):
        # 先按色相分类，再按亮度
        mx, mn = max(r, g, b), min(r, g, b)
        if mx - mn < 14:
            if mx < 40:
                return " "
            if mx < 90:
                return "."
            if mx < 150:
                return ":"
            return "+"
        # 饱和度较高
        if g >= r and g >= b:
            if g < 110:
                return "G"
            return "g"
        if r >= g and r >= b:
            if r < 140:
                return "R"
            return "r"
        # 蓝色主导
        if b >= 140:
            return "B"
        if b >= 90:
            return "b"
        return "?"

    for y in range(rows):
        line = ""
        for x in range(cols):
            r, g, b = px[x, y]
            line += classify(r, g, b)
        print(line)

if __name__ == "__main__":
    main()
