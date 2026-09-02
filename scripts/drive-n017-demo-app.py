#!/usr/bin/env python3
"""Drive a real CreekSprout.app through the N-017 internal demo route."""

from __future__ import annotations

import json
import os
import shutil
import time
from ctypes import CDLL, POINTER, c_bool, c_int32, c_uint16, c_uint32, c_void_p
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = Path(os.environ.get("N017_APP", "/tmp/creeksprout-n017-demo/Build/Products/Release/CreekSprout.app"))
OUT = Path(os.environ.get("N017_APP_EVIDENCE", ROOT / "artifacts/integration/n-017-demo/real-app"))
SHOTS = OUT / "screenshots"
LOG = OUT / "drive-log.md"
MIN_SECONDS = int(os.environ.get("N017_MIN_SECONDS", "720"))

KEY = {
    "a": 0x00,
    "s": 0x01,
    "d": 0x02,
    "w": 0x0D,
    "e": 0x0E,
    "h": 0x04,
    "i": 0x22,
    "k": 0x28,
    "l": 0x25,
    "q": 0x0C,
    "t": 0x11,
    "1": 0x12,
    "2": 0x13,
    "3": 0x14,
    "4": 0x15,
    "5": 0x17,
    "space": 0x31,
    "return": 0x24,
    "escape": 0x35,
    "down": 0x7D,
    "up": 0x7E,
}
CHAR = {**{key: key for key in "asdewhikltq12345"}, "space": " ", "return": "\r", "escape": "", "down": "", "up": ""}

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

import subprocess
import re


def run(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, text=True, capture_output=True, check=False)


def log(message: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    line = f"- {datetime.now().strftime('%H:%M:%S')} {message}"
    print(line, flush=True)
    with LOG.open("a", encoding="utf-8") as handle:
        handle.write(line + "\n")


def pid() -> int:
    result = run(["pgrep", "-n", "-x", "CreekSprout"])
    if result.returncode or not result.stdout.strip():
        raise RuntimeError("CreekSprout process not found")
    return int(result.stdout.strip().splitlines()[0])


def press(name: str, pause: float = 0.16) -> None:
    target = pid()
    for down in (True, False):
        event = quartz.CGEventCreateKeyboardEvent(SOURCE, c_uint32(KEY[name]), c_bool(down))
        char = CHAR.get(name, "")
        if char:
            value = (c_uint16 * 1)(ord(char))
            quartz.CGEventKeyboardSetUnicodeString(event, c_uint32(1), value)
        quartz.CGEventPostToPid(c_int32(target), event)
        cf.CFRelease(event)
        time.sleep(0.03)
    time.sleep(pause)


def save_roots() -> list[Path]:
    home = Path.home()
    return [
        home / "Library/Containers/com.fengyifan.CreekSprout/Data/Library/Application Support/CreekSprout",
        home / "Library/Application Support/CreekSprout",
    ]


def demo_dirs() -> list[Path]:
    return [root / "n017-demo-session" for root in save_roots()]


def hud_file() -> Path:
    candidates = [path / "hud-latest.txt" for path in demo_dirs() if (path / "hud-latest.txt").exists()]
    if not candidates:
        raise RuntimeError("demo HUD export not found")
    return max(candidates, key=lambda path: path.stat().st_mtime)


def hud() -> str:
    for _ in range(80):
        try:
            text = hud_file().read_text(encoding="utf-8")
            if "【状态】" in text:
                return text
        except (OSError, RuntimeError):
            pass
        time.sleep(0.1)
    raise RuntimeError("HUD export did not become ready")


def wait_hud(timeout: float = 20.0) -> str:
    deadline = time.time() + timeout
    last = ""
    while time.time() < deadline:
        try:
            last = hud()
            return last
        except RuntimeError as error:
            last = str(error)
            time.sleep(0.15)
    listing = []
    for path in demo_dirs():
        listing.append(f"{path} exists={path.exists()}")
        if path.exists():
            listing.extend(f"  {child.name}" for child in sorted(path.iterdir()))
    raise RuntimeError(f"timed out waiting for demo HUD: {last!r}; dirs={listing}")


def position() -> tuple[int, int]:
    match = re.search(r"玩家 \((-?\d+), (-?\d+)\)", hud())
    if not match:
        raise RuntimeError("player position absent from HUD")
    return int(match.group(1)), int(match.group(2))


def walk_to(x: int, y: int, limit: int = 80) -> None:
    for _ in range(limit):
        px, py = position()
        if (px, py) == (x, y):
            return
        dx = x - px
        dy = y - py
        ordered: list[str] = []
        if abs(dx) >= abs(dy):
            if dx:
                ordered.append("d" if dx > 0 else "a")
            if dy:
                ordered.append("w" if dy > 0 else "s")
        else:
            if dy:
                ordered.append("w" if dy > 0 else "s")
            if dx:
                ordered.append("d" if dx > 0 else "a")
        for extra in ("a", "d", "w", "s"):
            if extra not in ordered:
                ordered.append(extra)
        start = (px, py)
        moved = False
        for key in ordered:
            press(key)
            if position() != start:
                moved = True
                break
        if not moved:
            raise RuntimeError(f"walk stalled at {position()}, wanted {(x, y)}")
    raise RuntimeError(f"walk stalled at {position()}, wanted {(x, y)}")


def face_toward(direction: str) -> None:
    opposite = {"w": "s", "s": "w", "a": "d", "d": "a"}[direction]
    start = position()
    press(opposite, 0.08)
    press(direction, 0.08)
    if position() != start:
        walk_to(*start)


def finish_dialogue() -> None:
    for _ in range(12):
        if "【对话】" not in hud():
            return
        press("space", 0.22)
    raise RuntimeError("dialogue did not finish")


def activate_and_resize(width: int, height: int) -> None:
    script = (
        'tell application "CreekSprout" to activate\n'
        'tell application "System Events" to tell process "CreekSprout"\n'
        "set frontmost to true\n"
        "set position of front window to {40, 40}\n"
        f"set size of front window to {{{width}, {height}}}\n"
        "end tell"
    )
    result = run(["osascript", "-e", script])
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "window resize failed")
    time.sleep(0.4)


def click_named_button(title: str) -> bool:
    script = (
        'tell application "System Events" to tell process "CreekSprout"\n'
        "set frontmost to true\n"
        "try\n"
        f'  click (first button whose name is "{title}")\n'
        "  return \"ok\"\n"
        "on error errMsg\n"
        "  return errMsg\n"
        "end try\n"
        "end tell"
    )
    result = run(["osascript", "-e", script])
    ok = result.returncode == 0 and "ok" in (result.stdout or "")
    log(f"ax click {title}: {'ok' if ok else (result.stdout or result.stderr).strip()}")
    return ok


def enter_demo_session() -> None:
    press("return", 0.5)
    if any((path / "hud-latest.txt").exists() for path in demo_dirs()):
        return
    click_named_button("开始演示")
    time.sleep(0.4)
    if any((path / "hud-latest.txt").exists() for path in demo_dirs()):
        return
    press("1", 0.6)


def hide_app() -> None:
    run(["osascript", "-e", 'tell application "System Events" to keystroke "h" using command down'])
    time.sleep(1.2)


def window_info() -> tuple[str, dict[str, int]]:
    swift = r"""
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
"""
    result = run(["swift", "-e", swift])
    parts = result.stdout.strip().split()
    if len(parts) != 5:
        raise RuntimeError(result.stderr.strip() or "window id not found")
    return parts[0], dict(zip(("x", "y", "width", "height"), map(int, parts[1:])))


def capture(name: str, note: str) -> dict[str, object]:
    SHOTS.mkdir(parents=True, exist_ok=True)
    window, bounds = window_info()
    image = SHOTS / f"{name}.png"
    result = run(["screencapture", "-x", "-l", window, str(image)])
    if result.returncode or not image.exists():
        raise RuntimeError(result.stderr.strip() or f"capture failed: {name}")
    record = {
        "name": name,
        "note": note,
        "window_bounds": bounds,
        "bytes": image.stat().st_size,
        "path": str(image),
    }
    log(f"screenshot {name}: {bounds} {note}")
    return record


def latest_demo_save() -> Path:
    candidates = [path / "slot_manual_1.json" for path in demo_dirs() if (path / "slot_manual_1.json").exists()]
    if not candidates:
        raise RuntimeError("demo save missing")
    return max(candidates, key=lambda path: path.stat().st_mtime)


def production_fingerprint() -> dict[str, str]:
    names = ["slot_manual_1.json", "slot_manual_2.json", "slot_manual_3.json", "slot_auto.json", "slot_0.json"]
    result: dict[str, str] = {}
    for root in save_roots():
        for name in names:
            path = root / name
            if path.exists():
                digest = run(["shasum", "-a", "256", str(path)]).stdout.split()[0]
                result[str(path)] = digest
    return result


def copy_json(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


def main() -> int:
    if not APP.exists():
        raise RuntimeError(f"app missing: {APP}")
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True, exist_ok=True)
    SHOTS.mkdir(parents=True, exist_ok=True)
    LOG.write_text("# N-017 real App drive log\n\n", encoding="utf-8")
    started = time.time()
    log(f"app={APP}")
    production_before = production_fingerprint()
    (OUT / "production-fingerprint-before.json").write_text(
        json.dumps(production_before, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    for demo in demo_dirs():
        if demo.exists():
            shutil.rmtree(demo)

    run(["osascript", "-e", 'tell application "CreekSprout" to quit'])
    time.sleep(0.6)
    subprocess.Popen(["open", "-n", str(APP)])
    for _ in range(80):
        try:
            pid()
            break
        except RuntimeError:
            time.sleep(0.2)
    else:
        raise RuntimeError("app did not launch")
    time.sleep(1.2)
    activate_and_resize(1280, 800)
    time.sleep(0.6)
    capture("01-welcome-1280x800", "欢迎页 1280×800")
    enter_demo_session()
    wait_hud()
    log(f"entered demo at {position()}")
    capture("02-farm-default", "农场默认页面")

    press("4")
    walk_to(4, 4)
    face_toward("s")
    press("space")
    walk_to(5, 4)
    face_toward("s")
    press("space")
    walk_to(6, 4)
    face_toward("s")
    press("space")
    press("i", 0.3)
    log("harvested and deposited")

    press("1")
    walk_to(2, 2)
    face_toward("w")
    press("space")
    press("2")
    press("space")
    press("3")
    press("space")
    log("till/plant/water")

    walk_to(3, 7)
    press("e", 0.35)
    capture("04-farm-building-card", "农舍或水工坊建筑卡")
    press("e", 0.2)
    press("e", 0.2)

    walk_to(7, 1)
    face_toward("s")
    press("space", 0.4)
    wait_hud()
    capture("05-market-default", "溪岸集市默认页面")

    walk_to(3, 5)
    face_toward("w")
    press("t", 0.35)
    wait_hud()
    if "水工学徒" not in hud() and "【对话】" not in hud():
        raise RuntimeError("water apprentice dialogue did not open")
    capture("03-farm-dialogue-portrait", "水工学徒对话与高清立绘（N-015 后驻溪岸集市）")
    finish_dialogue()

    walk_to(4, 8)
    face_toward("w")
    press("t", 0.35)
    capture("06-market-dialogue", "集市角色对话")
    finish_dialogue()

    walk_to(1, 8)
    press("e", 0.35)
    capture("07-market-building-card", "集市建筑卡")
    press("e", 0.2)
    press("e", 0.2)

    walk_to(9, 8)
    walk_to(9, 11)
    face_toward("w")
    press("space", 0.4)
    wait_hud()
    walk_to(9, 6)
    face_toward("s")
    press("space", 0.35)
    log("opened woodhoney hearth processing entrance")
    walk_to(7, 6)
    log(f"left hearth to save-safe tile {position()}")

    press("escape", 0.35)
    capture("09-pause", "暂停页面")
    press("2", 0.4)
    capture("08-settings", "设置页面")
    press("return", 0.25)
    press("escape", 0.3)
    press("escape", 0.3)
    press("1", 0.25)

    press("k", 0.5)
    wait_hud()
    if "保存成功" not in hud() and "成功：" not in hud():
        raise RuntimeError(f"save did not succeed: {hud().splitlines()[-8:]}")
    before = latest_demo_save()
    copy_json(before, OUT / "save-before.json")
    press("w", 0.2)
    press("d", 0.2)
    press("l", 0.5)
    after = latest_demo_save()
    copy_json(after, OUT / "save-after-load.json")
    capture("10-after-save-load", "保存读取后的恢复页面")
    before_obj = json.loads((OUT / "save-before.json").read_text(encoding="utf-8"))
    after_obj = json.loads((OUT / "save-after-load.json").read_text(encoding="utf-8"))
    comparison = {
        "schema_version_before": before_obj.get("schema_version"),
        "schema_version_after": after_obj.get("schema_version"),
        "stamina_before": before_obj.get("stamina"),
        "stamina_after": after_obj.get("stamina"),
        "balance_before": (before_obj.get("economy") or {}).get("balance"),
        "balance_after": (after_obj.get("economy") or {}).get("balance"),
        "map_before": before_obj.get("current_map_id") or before_obj.get("currentMapID"),
        "equal_payload": before_obj == after_obj,
    }
    (OUT / "save-comparison.json").write_text(
        json.dumps(comparison, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )

    hide_app()
    activate_and_resize(1280, 800)
    log("foreground restored after hide")
    activate_and_resize(960, 640)
    log("resized to 960x640")
    activate_and_resize(1280, 800)
    run(["osascript", "-e", 'tell application "CreekSprout" to activate'])
    time.sleep(0.3)
    run(["osascript", "-e", 'tell application "System Events" to tell process "CreekSprout" to set frontmost to true'])
    run(["osascript", "-e", 'tell application "System Events" to keystroke "f" using {command down, control down}'])
    time.sleep(1.0)
    log("toggled fullscreen on")
    run(["osascript", "-e", 'tell application "CreekSprout" to activate'])
    run(["osascript", "-e", 'tell application "System Events" to keystroke "f" using {command down, control down}'])
    time.sleep(1.0)
    log("toggled fullscreen off")
    activate_and_resize(1280, 800)

    remaining = MIN_SECONDS - (time.time() - started)
    log(f"idling {max(remaining, 0):.1f}s to reach {MIN_SECONDS}s")
    deadline = started + MIN_SECONDS
    while time.time() < deadline:
        press("a" if int(time.time()) % 2 == 0 else "d", 0.8)
        time.sleep(8)

    press("escape", 0.3)
    press("5", 0.4)
    time.sleep(0.6)
    capture("11-back-to-title", "返回标题")

    elapsed = time.time() - started
    (OUT / "runtime-duration.txt").write_text(
        f"started_utc={datetime.fromtimestamp(started, timezone.utc).isoformat()}\n"
        f"elapsed_seconds={elapsed:.1f}\n"
        f"required_seconds={MIN_SECONDS}\n",
        encoding="utf-8",
    )
    production_after = production_fingerprint()
    (OUT / "production-fingerprint-after.json").write_text(
        json.dumps(production_after, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    if production_before != production_after:
        raise RuntimeError("production save slots changed during demo")
    log(f"DRIVE_OK elapsed={elapsed:.1f}s")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:  # noqa: BLE001
        log(f"DRIVE_FAIL {error}")
        raise
