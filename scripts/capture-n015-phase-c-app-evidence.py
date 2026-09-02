#!/usr/bin/env python3
"""Capture N-015 Phase C evidence from the built CreekSprout.app."""

from __future__ import annotations

import json
import os
import re
import subprocess
import time
from ctypes import CDLL, POINTER, c_bool, c_int32, c_uint16, c_uint32, c_void_p
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
APP = Path(os.environ.get("N015_APP", "/tmp/CreekSprout-N015-PhaseC/Build/Products/Debug/CreekSprout.app"))
OUT = Path(os.environ.get("N015_APP_EVIDENCE", ROOT / "artifacts/integration/n-015-codex-phase-c/real-app"))
SHOTS = OUT / "screenshots"
HUDS = OUT / "hud"

KEY = {"a": 0x00, "s": 0x01, "d": 0x02, "w": 0x0D, "e": 0x0E, "h": 0x04, "q": 0x0C, "t": 0x11, "space": 0x31}
CHAR = {**{key: key for key in "asdewhqt"}, "space": " "}

quartz = CDLL("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
cf = CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
quartz.CGEventSourceCreate.restype = c_void_p
quartz.CGEventSourceCreate.argtypes = [c_uint32]
quartz.CGEventCreateKeyboardEvent.restype = c_void_p
quartz.CGEventCreateKeyboardEvent.argtypes = [c_void_p, c_uint32, c_bool]
quartz.CGEventKeyboardSetUnicodeString.argtypes = [c_void_p, c_uint32, POINTER(c_uint16)]
quartz.CGEventPostToPid.argtypes = [c_int32, c_void_p]
cf.CFRelease.argtypes = [c_void_p]
SOURCE = quartz.CGEventSourceCreate(c_uint32(1))


def run(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, text=True, capture_output=True, check=False)


def pid() -> int:
    result = run(["pgrep", "-n", "-x", "CreekSprout"])
    if result.returncode or not result.stdout.strip():
        raise RuntimeError("CreekSprout process not found")
    return int(result.stdout.strip().splitlines()[0])


def press(name: str, pause: float = 0.14) -> None:
    target = pid()
    for down in (True, False):
        event = quartz.CGEventCreateKeyboardEvent(SOURCE, c_uint32(KEY[name]), c_bool(down))
        char = CHAR[name]
        value = (c_uint16 * 1)(ord(char))
        quartz.CGEventKeyboardSetUnicodeString(event, c_uint32(1), value)
        quartz.CGEventPostToPid(c_int32(target), event)
        cf.CFRelease(event)
        time.sleep(0.025)
    time.sleep(pause)


def save_dirs() -> list[Path]:
    home = Path.home()
    return [
        home / "Library/Containers/com.fengyifan.CreekSprout/Data/Library/Application Support/CreekSprout",
        home / "Library/Application Support/CreekSprout",
    ]


def hud_file() -> Path:
    candidates = [path / "hud-latest.txt" for path in save_dirs() if (path / "hud-latest.txt").exists()]
    if not candidates:
        raise RuntimeError("live HUD export not found")
    return max(candidates, key=lambda path: path.stat().st_mtime)


def hud() -> str:
    for _ in range(50):
        try:
            text = hud_file().read_text(encoding="utf-8")
            if "【状态】" in text:
                return text
        except (OSError, RuntimeError):
            pass
        time.sleep(0.1)
    raise RuntimeError("HUD export did not become ready")


def position() -> tuple[int, int]:
    match = re.search(r"玩家 \((-?\d+), (-?\d+)\)", hud())
    if not match:
        raise RuntimeError("player position absent from HUD")
    return int(match.group(1)), int(match.group(2))


def walk_to(x: int, y: int, limit: int = 40) -> None:
    for _ in range(limit):
        px, py = position()
        if (px, py) == (x, y):
            return
        key = "s" if py > y else "w" if py < y else "a" if px > x else "d"
        press(key)
    raise RuntimeError(f"walk stalled at {position()}, wanted {(x, y)}")


def finish_dialogue() -> None:
    for _ in range(10):
        if "【对话】" not in hud():
            return
        press("space", 0.2)
    raise RuntimeError("dialogue did not finish")


def activate_and_resize(width: int, height: int) -> None:
    script = (
        'tell application "CreekSprout" to activate\n'
        'tell application "System Events" to tell process "CreekSprout"\n'
        'set frontmost to true\n'
        'set position of front window to {30, 50}\n'
        f'set size of front window to {{{width}, {height}}}\n'
        'end tell'
    )
    result = run(["osascript", "-e", script])
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "window resize failed")
    time.sleep(0.35)


def window_info() -> tuple[str, dict[str, int]]:
    swift = r'''
import CoreGraphics
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for w in windows {
  let owner = w[kCGWindowOwnerName as String] as? String ?? ""
  guard owner.contains("CreekSprout"), let number = w[kCGWindowNumber as String] as? Int,
        let b = w[kCGWindowBounds as String] as? [String: Double] else { continue }
  let x = Int(b["X"] ?? 0)
  let y = Int(b["Y"] ?? 0)
  let width = Int(b["Width"] ?? 0)
  let height = Int(b["Height"] ?? 0)
  print("\(number) \(x) \(y) \(width) \(height)")
  break
}
'''
    result = run(["swift", "-e", swift])
    parts = result.stdout.strip().split()
    if len(parts) != 5:
        raise RuntimeError(result.stderr.strip() or "window id not found")
    return parts[0], dict(zip(("x", "y", "width", "height"), map(int, parts[1:])))


records: list[dict[str, object]] = []


def capture(name: str, note: str) -> None:
    SHOTS.mkdir(parents=True, exist_ok=True)
    HUDS.mkdir(parents=True, exist_ok=True)
    window, bounds = window_info()
    image = SHOTS / f"{name}.png"
    result = run(["screencapture", "-x", "-l", window, str(image)])
    if result.returncode or not image.exists():
        raise RuntimeError(result.stderr.strip() or f"capture failed: {name}")
    state = hud()
    (HUDS / f"{name}.txt").write_text(state + "\n", encoding="utf-8")
    records.append({"name": name, "note": note, "window_bounds": bounds, "player": position(), "bytes": image.stat().st_size})


def contact_sheet() -> None:
    tiles: list[tuple[Image.Image, str]] = []
    for record in records:
        name = str(record["name"])
        image = Image.open(SHOTS / f"{name}.png").convert("RGB")
        image.thumbnail((480, 320), Image.Resampling.LANCZOS)
        tiles.append((image.copy(), name))
    canvas = Image.new("RGB", (1000, ((len(tiles) + 1) // 2) * 360), "#16212b")
    draw = ImageDraw.Draw(canvas)
    for index, (image, label) in enumerate(tiles):
        x = 10 + (index % 2) * 500
        y = 10 + (index // 2) * 360
        canvas.paste(image, (x, y))
        draw.text((x, y + 325), label, fill="#f4e3bc")
    canvas.save(OUT / "contact-sheet.png")


def main() -> int:
    if not APP.exists():
        raise RuntimeError(f"app missing: {APP}")
    OUT.mkdir(parents=True, exist_ok=True)
    run(["osascript", "-e", 'tell application "CreekSprout" to quit'])
    time.sleep(0.5)
    subprocess.Popen(["open", "-n", str(APP)])
    for _ in range(80):
        try:
            pid()
            state = hud()
            if "农场与农舍" in state:
                break
        except RuntimeError:
            pass
        time.sleep(0.2)
    else:
        raise RuntimeError("real app launch timed out")

    activate_and_resize(960, 640)
    capture("01-farm-960", "farm production topology, runtime art and safe-zone HUD")
    walk_to(3, 7)
    capture("02-farm-house-compact-960", "natural proximity trigger for HD farm house")
    press("e")
    capture("03-farm-house-expanded-960", "expanded building card using the same safe zone")
    press("e")
    walk_to(12, 7)
    capture("04-farm-sluice-compact-960", "natural farm sluice HD trigger")
    press("e")
    capture("05-farm-sluice-expanded-960", "expanded farm sluice HD card")
    press("e")
    walk_to(7, 7)
    walk_to(7, 0)
    press("space", 0.35)
    if "溪岸集市" not in hud():
        raise RuntimeError("farm-to-market travel did not occur")
    capture("06-market-960", "market production topology, seven NPCs and three HD buildings")
    walk_to(3, 5)
    capture("07-market-wharf-compact-960", "natural market wharf HD trigger")
    press("w")
    press("t", 0.85)
    capture("08-water-apprentice-dialogue-960", "water apprentice dialogue portrait")
    press("q", 0.35)
    capture("09-water-apprentice-character-info-960", "Q character information full-body portrait")
    press("q")
    finish_dialogue()
    walk_to(4, 5)
    walk_to(4, 8)
    press("w")
    press("t", 0.85)
    capture("10-seed-steward-dialogue-960", "seed steward dialogue portrait")
    finish_dialogue()
    walk_to(1, 8)
    capture("11-market-seed-shed-compact-960", "natural seed shed building trigger")
    press("e")
    capture("12-market-seed-shed-expanded-960", "expanded seed shed card")
    press("e")
    walk_to(16, 8)
    capture("13-market-warden-post-compact-960", "natural warden post HD trigger")
    press("e")
    capture("14-market-warden-post-expanded-960", "expanded warden post HD card")
    press("e")
    walk_to(13, 8)
    press("w")
    press("t", 0.85)
    capture("15-creek-warden-dialogue-960", "creek warden dialogue portrait")
    activate_and_resize(1280, 800)
    capture("16-market-dialogue-portrait-1280", "1280 resized safe zones without sprite stretching")
    press("h")
    capture("17-market-hud-toggle-1280", "H-toggle HUD evidence")

    contact_sheet()
    (OUT / "index.json").write_text(json.dumps({"app": str(APP), "captures": records}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    run(["osascript", "-e", 'tell application "CreekSprout" to quit'])
    print(json.dumps({"pass": True, "capture_count": len(records), "output": str(OUT)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
