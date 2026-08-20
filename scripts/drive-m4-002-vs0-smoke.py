#!/usr/bin/env python3
"""M4-002 VS-0 offline smoke driver: CGEvent keys, HUD file reads, screenshots."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import time
from ctypes import CDLL, POINTER, c_bool, c_int32, c_uint16, c_uint32, c_void_p
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(os.environ.get("CREEKSPROUT_ROOT", "/Users/fengyifan/Documents/VibeCoding"))
EVIDENCE = Path(os.environ["M4_002_EVIDENCE"])
APP = Path(os.environ.get("M4_002_APP", "/Applications/CreekSprout.app"))
SAVE_DIR = Path(
    os.environ.get(
        "M4_002_SAVE_DIR",
        str(Path.home() / "Library/Containers/com.fengyifan.CreekSprout/Data/Library/Application Support/CreekSprout"),
    )
)
CANDIDATE_SAVE_DIRS = [
    Path.home() / "Library/Containers/com.fengyifan.CreekSprout/Data/Library/Application Support/CreekSprout",
    Path.home() / "Library/Application Support/CreekSprout",
]
HUD_DIR = EVIDENCE / "hud-dumps"
SHOT_DIR = EVIDENCE / "screenshots-or-video"
SAVE_OUT = EVIDENCE / "saves"
MANUAL_SLOT = "slot_manual_1"
LOG_PATH = EVIDENCE / "logs" / "drive-log.md"

KEY = {
    "a": 0x00, "s": 0x01, "d": 0x02, "w": 0x0D, "n": 0x2D, "t": 0x11,
    "i": 0x22, "k": 0x28, "l": 0x25, "1": 0x12, "2": 0x13, "3": 0x14,
    "4": 0x15, "space": 0x31,
}
UNICHAR = {
    "a": "a", "s": "s", "d": "d", "w": "w", "n": "n", "t": "t",
    "i": "i", "k": "k", "l": "l", "1": "1", "2": "2", "3": "3",
    "4": "4", "space": " ",
}

quartz = CDLL("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
cf = CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
quartz.CGEventCreateKeyboardEvent.restype = c_void_p
quartz.CGEventCreateKeyboardEvent.argtypes = [c_void_p, c_uint32, c_bool]
quartz.CGEventPost.argtypes = [c_uint32, c_void_p]
quartz.CGEventSourceCreate.restype = c_void_p
quartz.CGEventSourceCreate.argtypes = [c_uint32]
quartz.CGEventKeyboardSetUnicodeString.argtypes = [c_void_p, c_uint32, POINTER(c_uint16)]
quartz.CGEventPostToPid.argtypes = [c_int32, c_void_p]
cf.CFRelease.argtypes = [c_void_p]

# kCGEventSourceStateHIDSystemState = 1
_SOURCE = quartz.CGEventSourceCreate(c_uint32(1))

log_lines: list[str] = []


def log(msg: str) -> None:
    stamp = datetime.now().strftime("%H:%M:%S")
    line = f"- {stamp} {msg}"
    log_lines.append(line)
    print(line, flush=True)


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, text=True, capture_output=True, **kwargs)


def key_event(keycode: int, down: bool, char: str | None = None, pid: int | None = None) -> None:
    ev = quartz.CGEventCreateKeyboardEvent(_SOURCE, c_uint32(keycode), c_bool(down))
    if char:
        buf = (c_uint16 * 1)(ord(char))
        quartz.CGEventKeyboardSetUnicodeString(ev, c_uint32(1), buf)
    if pid:
        quartz.CGEventPostToPid(c_int32(pid), ev)
    else:
        quartz.CGEventPost(c_uint32(0), ev)
    cf.CFRelease(ev)


def app_pid() -> int | None:
    r = run(["pgrep", "-n", "-x", "CreekSprout"])
    text = (r.stdout or "").strip()
    if r.returncode != 0 or not text:
        return None
    try:
        return int(text.splitlines()[0])
    except ValueError:
        return None


def press(name: str, pause: float = 0.14, *, to_pid: bool = False) -> None:
    code = KEY[name]
    char = UNICHAR.get(name)
    pid = app_pid() if to_pid else None
    key_event(code, True, char, pid)
    time.sleep(0.03)
    key_event(code, False, char, pid)
    time.sleep(pause)


def ax_trusted() -> bool:
    script = "import ApplicationServices; print(ApplicationServices.AXIsProcessTrusted())"
    r = run(["swift", "-e", script])
    return "true" in (r.stdout or "").lower()


def frontmost_name() -> str:
    r = run(["osascript", "-e", "name of application (path to frontmost application as text)"])
    return (r.stdout or "").strip()


def focus_click() -> str:
    """Activate CreekSprout, verify it is frontmost, and click the window center."""
    script = r'''
import AppKit
import ApplicationServices
import CoreGraphics

let trusted = AXIsProcessTrusted()
var owner = "none"
var layer = -1
var clicked = false
let opts: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
let info = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] ?? []
for w in info {
    let name = w[kCGWindowOwnerName as String] as? String ?? ""
    guard name.contains("CreekSprout") else { continue }
    layer = (w[kCGWindowLayer as String] as? Int) ?? -1
    owner = name
    if let b = w[kCGWindowBounds as String] as? [String: Double] {
        let x = b["X"] ?? 0
        let y = b["Y"] ?? 0
        let width = b["Width"] ?? 0
        let height = b["Height"] ?? 0
        let displayH = CGFloat(CGDisplayPixelsHigh(CGMainDisplayID()))
        let cx = x + width / 2
        let cyTop = y + max(48.0, height * 0.55)
        let pt = CGPoint(x: cx, y: displayH - cyTop)
        if let src = CGEventSource(stateID: .hidSystemState) {
            if let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: pt, mouseButton: .left),
               let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: pt, mouseButton: .left) {
                down.post(tap: .cghidEventTap)
                up.post(tap: .cghidEventTap)
                clicked = true
            }
        }
    }
    break
}
let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
print("trusted=\(trusted) owner=\(owner) layer=\(layer) front=\(front) clicked=\(clicked)")
'''
    r = run(["swift", "-e", script])
    return (r.stdout or "").strip().splitlines()[-1] if (r.stdout or "").strip() else "focus_click_failed"


def activate(*, click: bool = False) -> str:
    run(["osascript", "-e", 'tell application "CreekSprout" to activate'])
    run([
        "osascript",
        "-e",
        'tell application "System Events" to set frontmost of process "CreekSprout" to true',
    ])
    time.sleep(0.18)
    info = ""
    if click:
        info = focus_click()
        time.sleep(0.18)
        front = frontmost_name()
        if "CreekSprout" not in front and "CreekSprout" not in info:
            log(f"WARN frontmost={front!r} focus={info}")
        else:
            log(f"focus {info} frontmost={front!r}")
    return info


def hud_path() -> Path:
    return SAVE_DIR / "hud-latest.txt"


def candidate_dirs() -> list[Path]:
    dirs: list[Path] = []
    for path in [SAVE_DIR, *CANDIDATE_SAVE_DIRS]:
        if path not in dirs:
            dirs.append(path)
    return dirs


def resolve_live_save_dir(since: float | None = None) -> Path | None:
    newest: tuple[float, Path] | None = None
    for directory in candidate_dirs():
        path = directory / "hud-latest.txt"
        if not path.exists():
            continue
        mtime = path.stat().st_mtime
        if since is not None and mtime < since - 0.05:
            continue
        if newest is None or mtime > newest[0]:
            newest = (mtime, directory)
    return newest[1] if newest else None


def adopt_save_dir(since: float | None = None) -> Path:
    global SAVE_DIR
    found = resolve_live_save_dir(since=since)
    if found is not None:
        SAVE_DIR = found
    return SAVE_DIR


def hud() -> str:
    adopt_save_dir()
    path = hud_path()
    for _ in range(50):
        if path.exists():
            text = path.read_text(encoding="utf-8")
            if "溪票" in text or "当前目标" in text or "【状态】" in text:
                return text
        time.sleep(0.1)
        path = hud_path()
    return path.read_text(encoding="utf-8") if path.exists() else "HUD_MISSING"


def dump_hud(name: str, text: str | None = None) -> str:
    HUD_DIR.mkdir(parents=True, exist_ok=True)
    text = text if text is not None else hud()
    (HUD_DIR / name).write_text(text + "\n", encoding="utf-8")
    return text


def slot_path(directory: Path | None = None) -> Path:
    return (directory or SAVE_DIR) / f"{MANUAL_SLOT}.json"


def list_save_dir(directory: Path) -> str:
    if not directory.exists():
        return f"{directory}: MISSING"
    names = sorted(p.name for p in directory.iterdir())
    return f"{directory}: {names}"


def copy_save(name: str, timeout: float = 6.0) -> Path:
    SAVE_OUT.mkdir(parents=True, exist_ok=True)
    deadline = time.time() + timeout
    last_listing = ""
    while time.time() < deadline:
        adopt_save_dir()
        for directory in candidate_dirs():
            src = slot_path(directory)
            if src.exists() and src.stat().st_size > 0:
                dest = SAVE_OUT / name
                shutil.copy2(src, dest)
                return dest
        last_listing = " | ".join(list_save_dir(d) for d in candidate_dirs())
        time.sleep(0.15)
    raise RuntimeError(f"{name} missing after {timeout:.1f}s; {last_listing}")


def parse_pos(text: str) -> tuple[int, int, int, int] | None:
    m = re.search(r"玩家 \((-?\d+), (-?\d+)\)  目标 \((-?\d+), (-?\d+)\)", text)
    if not m:
        return None
    return tuple(int(x) for x in m.groups())  # type: ignore[return-value]


def current_pos(text: str) -> tuple[int, int]:
    parsed = parse_pos(text)
    if not parsed:
        raise RuntimeError(f"cannot parse pos:\n{text}")
    return parsed[0], parsed[1]


def expect(text: str, needle: str, context: str) -> None:
    if needle not in text:
        raise RuntimeError(f"{context}: missing {needle!r}\n{text}")


def wait_hud(pred, tries: int = 20, delay: float = 0.15, context: str = "wait") -> str:
    last = ""
    for _ in range(tries):
        last = hud()
        if pred(last):
            return last
        time.sleep(delay)
    raise RuntimeError(f"{context} timed out\n{last}")


def is_fresh_new_game(text: str) -> bool:
    return (
        "溪票 720" in text
        and "第 1 天" in text
        and "收获 3 株成熟雾萝卜" in text
        and "雾萝卜种子×8" in text
        and "待结算 0" in text
    )


def window_id() -> str | None:
    script = r'''
import CoreGraphics
let info = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
var best: (Int, Int) = (0, 0)
for w in info {
    let owner = w["kCGWindowOwnerName"] as? String ?? ""
    guard owner.contains("CreekSprout"), let number = w["kCGWindowNumber"] as? Int else { continue }
    let bounds = w["kCGWindowBounds"] as? [String: Any]
    let height = (bounds?["Height"] as? Int) ?? 0
    if height > best.1 { best = (number, height) }
}
if best.0 != 0 { print(best.0) }
'''
    r = run(["swift", "-e", script])
    wid = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
    return wid or None


def screenshot(name: str) -> Path:
    SHOT_DIR.mkdir(parents=True, exist_ok=True)
    activate(click=False)
    time.sleep(0.15)
    dest = SHOT_DIR / name
    wid = window_id()
    if wid:
        run(["screencapture", "-x", "-l", wid, str(dest)])
    else:
        run(["screencapture", "-x", str(dest)])
    return dest


def process_running() -> bool:
    return app_pid() is not None


def wait_process_gone(timeout: float = 8.0) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if not process_running():
            return
        time.sleep(0.2)
    run(["killall", "-9", "CreekSprout"])
    time.sleep(0.4)
    if process_running():
        raise RuntimeError("CreekSprout still running after killall -9")


def quit_app() -> None:
    run(["osascript", "-e", 'tell application "CreekSprout" to quit'])
    time.sleep(0.4)
    run(["killall", "CreekSprout"])
    wait_process_gone()


def reset_saves() -> None:
    for directory in candidate_dirs():
        directory.mkdir(parents=True, exist_ok=True)
        for name in ("slot_manual_1", "slot_manual_2", "slot_manual_3", "slot_auto", "slot_0"):
            for filename in (f"{name}.json", f"{name}.backup", f"{name}.tmp"):
                path = directory / filename
                path.unlink(missing_ok=True)
        for path in directory.glob("slot_*"):
            path.unlink(missing_ok=True)
        for hud_name in ("hud-latest.txt", "hud-compact-latest.txt"):
            (directory / hud_name).unlink(missing_ok=True)
    deadline = time.time() + 3.0
    while time.time() < deadline:
        leftover = [d / "hud-latest.txt" for d in candidate_dirs() if (d / "hud-latest.txt").exists()]
        if not leftover:
            return
        for path in leftover:
            path.unlink(missing_ok=True)
        time.sleep(0.1)


def launch_app(*, require_new_game: bool = True) -> str:
    quit_app()
    launched = time.time()
    subprocess.Popen(["open", str(APP)])
    last = ""
    for _ in range(80):
        adopt_save_dir(since=launched)
        path = hud_path()
        if path.exists() and path.stat().st_mtime >= launched - 0.05:
            last = path.read_text(encoding="utf-8")
            if require_new_game and is_fresh_new_game(last):
                activate(click=True)
                return last
            if not require_new_game and ("溪票" in last or "【状态】" in last):
                activate(click=True)
                return last
        time.sleep(0.2)
    raise RuntimeError(f"launch timed out (new_game={require_new_game})\n{last or hud()}")


def parse_map(text: str) -> str:
    m = re.search(r"【状态】(.+?)  第 ", text)
    return m.group(1).strip() if m else ""


def expect_farm(text: str, context: str) -> None:
    if parse_map(text) != "农场与农舍":
        raise RuntimeError(f"{context}: not on farm map\n{text}")


def press_seq(keys: str, pause: float = 0.10) -> None:
    for ch in keys:
        press(ch, pause)


def wait_pos(px: int, py: int, tries: int = 12) -> str:
    def ok(t: str) -> bool:
        p = parse_pos(t)
        return p is not None and p[0] == px and p[1] == py

    return wait_hud(ok, tries=tries, context=f"pos ({px},{py})")


def diagnose_input(text: str, keys: list[str]) -> str:
    trusted = ax_trusted()
    front = frontmost_name()
    return (
        f"frontmost={front!r} ax_trusted={trusted} pid={app_pid()} "
        f"keys={''.join(keys)} save_dir={SAVE_DIR}\n{text}"
    )


def prove_keyboard() -> str:
    """Inject one move and require HUD position to change; fail with a diagnosis otherwise."""
    activate(click=True)
    before = hud()
    x, y = current_pos(before)
    key = "s" if y > 0 else "w"
    press(key, 0.2)
    time.sleep(0.15)
    after = hud()
    nx, ny = current_pos(after)
    if (nx, ny) != (x, y):
        log(f"keyboard self-check ok { (x, y) } -> { (nx, ny) } via {key}")
        return after
    activate(click=True)
    press(key, 0.2, to_pid=True)
    time.sleep(0.2)
    after = hud()
    nx, ny = current_pos(after)
    if (nx, ny) != (x, y):
        log(f"keyboard self-check ok after pid-post { (x, y) } -> { (nx, ny) } via {key}")
        return after
    raise RuntimeError(
        "keyboard self-check failed: HUD position did not change after injecting "
        f"{key!r}. Terminal/host likely lacks Accessibility permission, or "
        f"CreekSprout is not the key window.\n{diagnose_input(after, [key])}"
    )


def walk_to_pos(px: int, py: int, max_steps: int = 16) -> str:
    activate()
    keys: list[str] = []
    stalled = 0
    last_pos: tuple[int, int] | None = None
    for _ in range(max_steps):
        text = hud()
        cx, cy = current_pos(text)
        if cx == px and cy == py:
            return text
        if last_pos == (cx, cy):
            stalled += 1
        else:
            stalled = 0
            last_pos = (cx, cy)
        if stalled >= 3:
            raise RuntimeError(
                f"walk_to_pos ({px},{py}) stalled at {(cx, cy)} after 3 keys with no movement.\n"
                f"{diagnose_input(text, keys)}"
            )
        if stalled == 2:
            activate(click=True)
        if cy > py:
            key = "s"
        elif cy < py:
            key = "w"
        elif cx > px:
            key = "a"
        else:
            key = "d"
        keys.append(key)
        press(key, 0.14)
        time.sleep(0.04)
    text = hud()
    raise RuntimeError(
        f"walk_to_pos ({px},{py}) exceeded {max_steps} steps; last={current_pos(text)}.\n"
        f"{diagnose_input(text, keys)}"
    )


def approach_from_north(px: int, py: int) -> str:
    """Arrive on (px, py) with the last step south so the target is (px, py-1)."""
    walk_to_pos(px, py + 1)
    return walk_to_pos(px, py)


def harvest_plot_keys(mark: str) -> str:
    """Teaching plots sit one cell south of the stand tile; tool 4 then space."""
    press("4", 0.08)
    press("space", 0.18)
    return wait_hud(lambda t: mark in t or "已收获" in t, tries=20, context=f"harvest {mark}")


def finish_dialogue() -> str:
    for _ in range(8):
        text = hud()
        if "【对话】" not in text and "对话进行中" not in text:
            return text
        press("space", 0.18)
    return hud()


def json_load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def compare_saves(before: Path, after: Path) -> list[str]:
    a, b = json_load(before), json_load(after)
    mismatches: list[str] = []

    def walk(prefix: str, x, y) -> None:
        if type(x) != type(y):
            mismatches.append(f"{prefix}: type {type(x).__name__} vs {type(y).__name__}")
            return
        if isinstance(x, dict):
            keys = set(x) | set(y)
            for k in sorted(keys):
                walk(f"{prefix}.{k}" if prefix else k, x.get(k), y.get(k))
        elif isinstance(x, list):
            if len(x) != len(y):
                mismatches.append(f"{prefix}: len {len(x)} vs {len(y)}")
            else:
                for i, (xi, yi) in enumerate(zip(x, y)):
                    walk(f"{prefix}[{i}]", xi, yi)
        elif x != y:
            mismatches.append(f"{prefix}: {x!r} vs {y!r}")

    walk("", a, b)
    return mismatches


def main() -> int:
    started = datetime.now(timezone.utc)
    HUD_DIR.mkdir(parents=True, exist_ok=True)
    SHOT_DIR.mkdir(parents=True, exist_ok=True)
    SAVE_OUT.mkdir(parents=True, exist_ok=True)
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)

    log(f"ax_trusted={ax_trusted()}")
    quit_app()
    reset_saves()

    log(f"launch {APP}")
    text = launch_app(require_new_game=True)
    dump_hud("05-new-game.txt", text)
    screenshot("05-new-game.png")
    expect(text, "溪票 720", "new game balance")
    expect(text, "背包 1/16", "inventory slots")
    expect(text, "雾萝卜种子×8", "seeds x8")
    expect(text, "收获 3 株成熟雾萝卜", "tutorial goal")
    log("new game HUD verified")
    text = prove_keyboard()

    # Harvest 3 teaching plots at (4,1)/(5,1)/(6,1) by standing on y=2 facing south.
    activate(click=True)
    approach_from_north(5, 2)
    text = harvest_plot_keys("1/3")
    dump_hud("06-harvest1.txt", text)
    approach_from_north(4, 2)
    text = harvest_plot_keys("2/3")
    dump_hud("06-harvest2.txt", text)
    approach_from_north(6, 2)
    text = harvest_plot_keys("已收获 3")
    dump_hud("06-harvest3.txt", text)
    expect_farm(text, "after harvest 3")
    expect(text, "雾萝卜×3", "backpack 3 radish")
    screenshot("06-harvest3.png")
    log("harvested 3 plots")

    press("i", 0.15)
    text = wait_hud(lambda t: "待结算 3" in t, context="deposit")
    dump_hud("07-deposit.txt", text)
    screenshot("07-deposit.png")
    log("deposited to sell box")

    # Farm three steps at (8,2) — m2-002: 1,D,space / 2,space / 3,space
    press("1", 0.08)
    press("d", 0.10)
    press("space", 0.15)
    text = wait_hud(lambda t: "翻土完成" in t, context="till")
    dump_hud("08-till.txt", text)
    press("2", 0.08)
    press("space", 0.15)
    text = wait_hud(lambda t: "播种完成" in t or "记得浇水" in t, context="plant")
    dump_hud("08-plant.txt", text)
    press("3", 0.08)
    press("space", 0.15)
    text = wait_hud(lambda t: "浇水完成" in t, context="water")
    dump_hud("08-water.txt", text)
    log("farm till/plant/water done")

    # Talk to apprentice — A,S then T
    press_seq("as")
    press("t", 0.15)
    text = wait_hud(lambda t: "【对话】" in t or "对话进行中" in t or "已与水工学徒交谈" in t, context="dialogue start")
    dump_hud("09-dialogue-start.txt", text)
    text = finish_dialogue()
    dump_hud("09-talk-done.txt", text)
    expect(text, "已与水工学徒交谈", "talk complete")
    screenshot("09-talk.png")
    log("apprentice dialogue done")

    press("k", 0.25)
    text = wait_hud(lambda t: "保存成功" in t, context="save")
    dump_hud("10-save.txt", text)
    save_before = copy_save("save-before-quit.json")
    log(f"saved to {save_before}")

    quit_app()
    log("quit for reload test")
    time.sleep(1.0)
    text = launch_app(require_new_game=True)
    press("l", 0.25)
    text = wait_hud(lambda t: "读取成功" in t, context="load")
    dump_hud("11-loaded.txt", text)
    screenshot("11-loaded.png")
    expect(text, "待结算 3", "pending after load")
    expect(text, "溪票 720", "balance after load")
    save_after_load = copy_save("save-after-load.json")
    mismatches = compare_saves(save_before, save_after_load)
    reload_report = EVIDENCE / "saves" / "reload-consistency.json"
    reload_report.write_text(json.dumps({"mismatches": mismatches}, indent=2), encoding="utf-8")
    if mismatches:
        raise RuntimeError(f"save reload mismatches: {mismatches}")
    log("load consistency verified")

    press("n", 0.3)
    text = wait_hud(lambda t: "溪票 894" in t and "174" in t, tries=40, delay=0.2, context="sleep settle")
    dump_hud("12-settled-894.txt", text)
    screenshot("12-settled-894.png")
    expect(text, "174", "settlement 174")
    expect(text, "894", "balance 894")
    press("k", 0.25)
    wait_hud(lambda t: "保存成功" in t, context="save after first sleep")
    save_after_sleep = copy_save("save-after-sleep.json")
    slept = json_load(save_after_sleep)
    if slept.get("economy", {}).get("balance") != 894:
        raise RuntimeError(f"save-after-sleep balance is not 894: {slept.get('economy')}")
    log("first sleep settlement 174/894")

    press("l", 0.25)
    text = wait_hud(lambda t: "读取成功" in t, context="reload after sleep")
    expect(text, "溪票 894", "balance after reloading settled save")
    press("n", 0.3)
    text = wait_hud(lambda t: "溪票 894" in t, tries=40, delay=0.2, context="second sleep")
    dump_hud("13-second-sleep-no-dup.txt", text)
    expect(text, "溪票 894", "balance still 894")
    expect(text, "待结算 0", "pending empty after second sleep")
    if "溪票 1068" in text:
        raise RuntimeError(f"duplicate settlement credited in HUD\n{text}")
    press("k", 0.25)
    wait_hud(lambda t: "保存成功" in t, context="save after second sleep")
    dump_path = copy_save("save-after-second-sleep.json")
    after = json_load(dump_path)
    economy = after.get("economy") or {}
    if economy.get("balance") != 894:
        raise RuntimeError(f"second-sleep balance is not 894: {economy}")
    history = economy.get("settlement_history") or []
    paid = [entry.get("total", 0) for entry in history if isinstance(entry, dict)]
    if sum(paid) != 174:
        raise RuntimeError(f"settlement totals {paid} do not equal a single 174 payout")
    log("second sleep no duplicate payout")

    quit_app()
    elapsed = (datetime.now(timezone.utc) - started).total_seconds()
    header = [
        "# M4-002 offline VS-0 smoke drive log",
        "",
        f"- app: `{APP}`",
        f"- started_utc: {started.isoformat()}",
        f"- elapsed_seconds: {elapsed:.1f}",
        f"- save_dir: `{SAVE_DIR}`",
        "",
        "## Events",
        "",
    ]
    LOG_PATH.write_text("\n".join(header + log_lines) + "\n", encoding="utf-8")
    print(f"DRIVE_OK evidence={EVIDENCE}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"DRIVE_FAIL: {exc}", file=sys.stderr)
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        try:
            dump_hud("FAIL-last.txt")
        except Exception:
            pass
        try:
            quit_app()
        except Exception:
            pass
        LOG_PATH.write_text("\n".join(log_lines + [f"FAIL: {exc}"]) + "\n", encoding="utf-8")
        raise
