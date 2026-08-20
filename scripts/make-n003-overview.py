#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""N-003 overview 合成:角色/作物/地块最近邻放大拼图(零依赖)。"""
import os, struct, zlib

def load_png(path):
    data = open(path, 'rb').read()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    pos, w, h, idat = 8, 0, 0, b''
    while pos < len(data):
        ln = struct.unpack('>I', data[pos:pos+4])[0]
        tag = data[pos+4:pos+8]
        chunk = data[pos+8:pos+8+ln]
        if tag == b'IHDR':
            w, h = struct.unpack('>II', chunk[:8])
        elif tag == b'IDAT':
            idat += chunk
        pos += 12 + ln
    raw = zlib.decompress(idat)
    px = []
    stride = w * 4
    for y in range(h):
        row = raw[y * (stride + 1) + 1 : (y + 1) * (stride + 1)]
        px.append(list(row))
    return w, h, px

def save_png(path, w, h, px):
    def chunk(tag, d):
        crc = zlib.crc32(tag + d)
        if crc < 0:
            crc = crc + (1 << 32)
        return struct.pack('>I', len(d)) + tag + d + struct.pack('>I', crc)
    raw = bytearray()
    for row in px:
        raw.append(0)
        raw += bytes(row)
    png = (b'\x89PNG\r\n\x1a\n'
           + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
           + chunk(b'IDAT', zlib.compress(bytes(raw), 9))
           + chunk(b'IEND', b''))
    open(path, 'wb').write(png)

def scaled(path, f):
    w, h, px = load_png(path)
    out_w, out_h = w * f, h * f
    out = [[0] * (out_w * 4) for _ in range(out_h)]
    for y in range(h):
        for x in range(w):
            c = px[y][x*4:x*4+4]
            for dy in range(f):
                for dx in range(f):
                    out[y*f+dy][(x*f+dx)*4:(x*f+dx)*4+4] = c
    return out_w, out_h, out

def compose(items, gap=24, label_h=34, scale=8):
    total_w = sum(w for _, _, w, h in items) + gap * (len(items) - 1)
    total_h = max(h for _, _, w, h in items) + label_h
    flat = bytearray([255, 255, 255, 255]) * (total_w * total_h)
    def setpx(x, y, c):
        if 0 <= x < total_w and 0 <= y < total_h:
            i = (y * total_w + x) * 4
            flat[i:i+4] = bytes(c[:3]) + bytes([255])
    ox = 0
    for title, path, w, h in items:
        _, _, px = scaled(path, scale)
        for y in range(h):
            for x in range(w):
                c = px[y][x*4:x*4+4]
                if c[3] > 0:
                    setpx(ox + x, label_h + y, c[:3] + [255])
        ox += w + gap
    rows = [list(flat[i:i+total_w*4]) for i in range(0, len(flat), total_w * 4)]
    save_png('artifacts/n-003-overview.png', total_w, total_h, rows)

A = 'macos/CreekSprout/CreekSprout/Assets'
if __name__ == '__main__':
    chars = [('水工学徒', f'{A}/char_water_apprentice.png', 32*8, 48*8),
             ('种源管理员', f'{A}/char_seed_steward.png', 32*8, 48*8),
             ('溪岸巡护员', f'{A}/char_creek_warden.png', 32*8, 48*8)]
    compose(chars)
    print('角色总览已生成 artifacts/n-003-overview.png')
