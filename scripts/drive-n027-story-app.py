#!/usr/bin/env python3
"""Drive the real Debug CreekSprout.app through the N-027 presentation smoke
path with an isolated evidence root, and freeze production Application Support
roots before/after (byte-identical manifest diff required).

Path covered per run: 启动 → 新游戏选槽 → 晨报 → 触发一段剧情对白 → 取消归还控制.
Window sizes 960x640 / 1280x800 and UI scales 100% / 125% / 150% are covered,
plus the journey mini-scene fixture and the ending-gallery fixture.

Usage:
  python3 scripts/drive-n027-story-app.py [--app /path/to/CreekSprout.app]

Environment:
  N027_APP        override the app bundle path
  N027_RUNTIME    override the runtime evidence root (screenshots land there)
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from ctypes import CDLL, POINTER, c_bool, c_int32, c_uint16, c_uint32, c_void_p
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE = ROOT / "artifacts/integration/n-027-main-story-runtime/runtime"
SHOTS = EVIDENCE / "screenshots"

KEY = {
    "a": 0x00, "s": 0x01, "d": 0x02, "w": 0x0D,
    "e": 0x0E, "h": 0x04, "q": 0x0C, "t": 0x11,
    "1": 0x12, "2": 0x13, "3": 0x14,
    "space": 0x31, "return": 0x24, "escape": 0x35,
    "up": 0x7E, "down": 0x7D, "left": 0x7B, "right": 0x7C,
}

# macOS virtual key codes for System Events keystroke (key code N).
SE_KEY_CODE = {
    "a": 0, "s": 1, "d": 2, "w": 13,
    "e": 14, "h": 4, "q": 12, "t": 17,
    "1": 18, "2": 19, "3": 20,
    "space": 49, "return": 36, "escape": 53,
    "up": 126, "down": 125, "left": 123, "right": 124,
}
CHAR = {
    **{key: key for key in "asdewhqt123"},
    "space": " ", "return": "\r", "escape": "\x1b",
    "up": "\uf700", "down": "\uf701", "left": "\uf702", "right": "\uf703",
}

quartz = CDLL("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
cf = CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
quartz.CGEventSourceCreate.restype = c_void_p
quartz.CGEventSourceCreate.argtypes = [c_uint32]
quartz.CGEventCreateKeyboardEvent.restype = c_void_p
quartz.CGEventCreateKeyboardEvent.argtypes = [c_void_p, c_uint32, c_bool]
quartz.CGEventKeyboardSetUnicodeString.argtypes = [c_void_p, c_uint32, POINTER(c_uint16)]
quartz.CGEventPost.argtypes = [c_uint32, c_void_p]
cf.CFRelease.argtypes = [c_void_p]
SOURCE = quartz.CGEventSourceCreate(c_uint32(1))

records: list[dict[str, object]] = []


def run(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, text=True, capture_output=True, check=False)


def activate() -> None:
    run(["osascript", "-e", 'tell application "CreekSprout" to activate'])
    time.sleep(0.35)


# Key events are posted at HID level (kCGHIDEventTap) with the unicode
# character attached: SwiftUI's KeyPress needs the character, and HID events
# follow the real keyboard path into the frontmost window. System Events
# `key code` alone does not carry the character and is ignored by the shell.
def press(name: str, pause: float = 0.18) -> None:
    activate()
    for down in (True, False):
        event = quartz.CGEventCreateKeyboardEvent(
            SOURCE, c_uint32(KEY[name]), c_bool(down)
        )
        char = CHAR[name]
        value = (c_uint16 * 1)(ord(char))
        quartz.CGEventKeyboardSetUnicodeString(event, c_uint32(1), value)
        quartz.CGEventPost(c_uint32(0), event)  # kCGHIDEventTap
        cf.CFRelease(event)
        time.sleep(0.05)
    time.sleep(pause)


def confirm_slot(evidence_root: Path) -> None:
    """Confirms the manual-slot picker with retries (return then digit 1).
    Each launch uses a fresh evidence root, so the HUD file only appears when
    the farm scene attached; the content check guards stale files."""
    for _ in range(4):
        press("return", 0.7)
        time.sleep(1.3)
        if hud_has_state(evidence_root):
            return
        press("1", 0.7)
        time.sleep(1.3)
        if hud_has_state(evidence_root):
            return
    raise RuntimeError("manual slot confirm never produced the farm HUD")


def hud_has_state(evidence_root: Path) -> bool:
    path = hud_path(evidence_root)
    try:
        return "【状态】" in path.read_text(encoding="utf-8")
    except OSError:
        return False


def window_info() -> tuple[str, dict[str, int]]:
    swift = r'''
import CoreGraphics
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for w in windows {
  let owner = w[kCGWindowOwnerName as String] as? String ?? ""
  guard owner.contains("CreekSprout"), let number = w[kCGWindowNumber as String] as? Int,
        let b = w[kCGWindowBounds as String] as? [String: Double] else { continue }
  let x = Int(b["X"] ?? 0); let y = Int(b["Y"] ?? 0)
  let width = Int(b["Width"] ?? 0); let height = Int(b["Height"] ?? 0)
  print("\(number) \(x) \(y) \(width) \(height)")
  break
}
'''
    result = run(["swift", "-e", swift])
    parts = result.stdout.strip().split()
    if len(parts) != 5:
        raise RuntimeError("CreekSprout window not found")
    return parts[0], dict(zip(("x", "y", "width", "height"), map(int, parts[1:])))


def activate_and_resize(width: int, height: int) -> None:
    script = (
        'tell application "CreekSprout" to activate\n'
        'tell application "System Events" to tell process "CreekSprout"\n'
        'set frontmost to true\n'
        'set position of front window to {40, 60}\n'
        f'set size of front window to {{{width}, {height}}}\n'
        'end tell'
    )
    result = run(["osascript", "-e", script])
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "window resize failed")
    time.sleep(0.4)


def hud_path(evidence_root: Path) -> Path:
    return evidence_root / "hud-latest.txt"


def hud(evidence_root: Path) -> str:
    for _ in range(80):
        path = hud_path(evidence_root)
        try:
            text = path.read_text(encoding="utf-8")
            if "【状态】" in text or "溪票" in text or "存档槽" in text:
                return text
        except (OSError, RuntimeError):
            pass
        time.sleep(0.15)
    raise RuntimeError("HUD export did not become ready")


def wait_hud_contains(evidence_root: Path, marker: str, timeout: float = 12.0) -> str:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            text = hud_path(evidence_root).read_text(encoding="utf-8")
            if marker in text:
                return text
        except OSError:
            pass
        time.sleep(0.15)
    raise RuntimeError(f"HUD never contained {marker!r}")


def capture(name: str, note: str, story_state: str) -> None:
    SHOTS.mkdir(parents=True, exist_ok=True)
    window, bounds = window_info()
    image = SHOTS / f"{name}.png"
    result = run(["screencapture", "-x", "-l", window, str(image)])
    if result.returncode or not image.exists():
        raise RuntimeError(result.stderr.strip() or f"capture failed: {name}")
    records.append({
        "name": name,
        "note": note,
        "window_bounds": bounds,
        "story_state": story_state,
        "bytes": image.stat().st_size,
    })
    print(f"  shot {name} @ {bounds['width']}x{bounds['height']}")


def production_roots() -> list[Path]:
    home = Path.home()
    return [
        home / "Library/Application Support/CreekSprout",
        home / "Library/Containers/com.fengyifan.CreekSprout/Data/Library/Application Support/CreekSprout",
    ]


def manifest_text() -> str:
    lines: list[str] = []
    for root in production_roots():
        if not root.exists():
            lines.append(f"MISSING:{root}")
            continue
        files = sorted(
            path
            for path in root.rglob("*")
            if path.is_file()
            and path.suffix in {".json", ".backup", ".tmp", ".txt"}
        )
        for path in files:
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            lines.append(f"{digest}  {path.relative_to(root)}")
    return "\n".join(lines) + "\n"


def launch_app(app: Path, evidence_root: Path, fixture: str, ui_scale: int, size: tuple[int, int]) -> None:
    # Only one CreekSprout instance may exist: HID key events go to the
    # frontmost app window, and a leftover instance would swallow them.
    run(["killall", "CreekSprout"])
    time.sleep(1.0)
    subprocess.Popen([
        "open", "-n", str(app), "--args",
        "--n027-evidence-root", str(evidence_root),
        "--n027-smoke-fixture", fixture,
        "--n027-ui-scale", str(ui_scale),
    ])
    time.sleep(1.6)
    activate()
    activate_and_resize(*size)


def run_q01_path(app: Path, evidence_root: Path, size: tuple[int, int], ui_scale: int, tag: str) -> None:
    print(f"[{tag}] launch q01 fixture {size[0]}x{size[1]} ui {ui_scale}%")
    launch_app(app, evidence_root, "q01_warning_one", ui_scale, size)
    time.sleep(0.6)

    capture(f"{tag}-01-welcome", "formal title page", "welcome")
    press("return", 0.5)
    time.sleep(0.6)
    capture(f"{tag}-02-slot-picker", "new game manual slot picker", "slot_picker")
    confirm_slot(evidence_root)

    hud_text = hud(evidence_root)
    if "【状态】" in hud_text:
        # Morning crop report appears on first farm entry of the day.
        capture(f"{tag}-03-morning-report", "morning crop report overlay", "morning_report")
        press("escape", 0.4)
        time.sleep(0.5)
        hud_text = wait_hud_contains(evidence_root, "【状态】")
        capture(f"{tag}-04-farm-after-report", "morning report closed, control returned", "roaming")
    else:
        raise RuntimeError("farm HUD never appeared")

    press("space", 0.4)
    wait_hud_contains(evidence_root, "【剧情】")
    capture(f"{tag}-05-story-dialogue-page1", "Q01 warning_1 multi-speaker dialogue, page 1", "story_dialogue_page_1")

    press("space", 0.5)
    time.sleep(0.5)
    hud_text = hud_path(evidence_root).read_text(encoding="utf-8")
    page_note = "advanced" if "【剧情】" in hud_text else "page unchanged"
    capture(f"{tag}-06-story-dialogue-page2", f"Q01 dialogue {page_note}", "story_dialogue_page_2")

    press("escape", 0.4)
    time.sleep(0.5)
    hud_text = hud_path(evidence_root).read_text(encoding="utf-8")
    if "【剧情】" in hud_text:
        raise RuntimeError("story dialogue did not cancel")
    capture(f"{tag}-07-control-returned", "cancel returned control; no story dialogue in HUD", "roaming_after_cancel")

    press("d", 0.3)
    time.sleep(0.4)
    capture(f"{tag}-08-roaming-after-cancel", "player moves freely after cancel", "roaming_moved")


def run_journey_path(app: Path, evidence_root: Path) -> None:
    print("[journey] launch journey fixture 960x640 ui 100%")
    launch_app(app, evidence_root, "journey", 100, (960, 640))
    time.sleep(0.4)
    press("return", 0.5)
    time.sleep(0.4)
    confirm_slot(evidence_root)
    capture("journey-01-old-waterway", "Q08 old-waterway journey mini-scene with local anchors", "journey_scene")
    press("right", 0.25)
    press("right", 0.25)
    press("down", 0.25)
    time.sleep(0.4)
    capture("journey-02-moved", "player moved across normalized scene (collision-aware)", "journey_scene_moved")
    press("escape", 0.4)
    time.sleep(0.4)
    capture("journey-03-closed", "journey view closed, control returned", "roaming_after_journey")


def run_gallery_path(app: Path, evidence_root: Path) -> None:
    print("[gallery] launch gallery fixture 960x640 ui 100%")
    launch_app(app, evidence_root, "gallery", 100, (960, 640))
    time.sleep(0.4)
    press("return", 0.5)
    time.sleep(0.4)
    confirm_slot(evidence_root)
    capture("gallery-01-unlocked", "ending gallery: ledger pages, annotations, keepsakes, ending", "gallery_unlocked")
    press("escape", 0.4)
    time.sleep(0.4)
    capture("gallery-02-closed", "gallery closed, control returned", "roaming_after_gallery")


def main() -> int:
    if "--help" in sys.argv or "-h" in sys.argv:
        print(__doc__)
        return 0

    env_app = os.environ.get("N027_APP")
    if env_app:
        app = Path(env_app)
    else:
        # Newest Debug build by mtime; older builds may predate wiring fixes.
        candidates = sorted(
            glob_private_tmp(),
            key=lambda path: os.path.getmtime(path),
            reverse=True,
        )
        app = Path(candidates[0]) if candidates else None
    if app is None or not app.exists():
        print("CreekSprout.app not found; pass --app or N027_APP", file=sys.stderr)
        return 2

    runtime_root = Path(os.environ.get("N027_RUNTIME", tempfile.mkdtemp(prefix="creeksprout-n027-runtime.")))
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    SHOTS.mkdir(parents=True, exist_ok=True)

    before = manifest_text()
    (EVIDENCE / "production-before.sha256").write_text(before, encoding="utf-8")

    run_q01_path(app, runtime_root / "run-q01-960-100", (960, 640), 100, "q01-960-100")
    run_q01_path(app, runtime_root / "run-q01-1280-100", (1280, 800), 100, "q01-1280-100")
    run_q01_path(app, runtime_root / "run-q01-960-125", (960, 640), 125, "q01-960-125")
    run_q01_path(app, runtime_root / "run-q01-1280-125", (1280, 800), 125, "q01-1280-125")
    run_q01_path(app, runtime_root / "run-q01-960-150", (960, 640), 150, "q01-960-150")
    run_q01_path(app, runtime_root / "run-q01-1280-150", (1280, 800), 150, "q01-1280-150")
    run_journey_path(app, runtime_root / "run-journey")
    run_gallery_path(app, runtime_root / "run-gallery")

    run(["killall", "CreekSprout"])
    time.sleep(1.0)

    after = manifest_text()
    (EVIDENCE / "production-after.sha256").write_text(after, encoding="utf-8")
    diff = "".join(
        line + "\n" for line in before.splitlines() if line not in after.splitlines()
    ) + "".join(
        line + "\n" for line in after.splitlines() if line not in before.splitlines()
    )
    (EVIDENCE / "production-diff.txt").write_text(diff, encoding="utf-8")
    if diff:
        print("PRODUCTION MANIFEST CHANGED:", file=sys.stderr)
        print(diff, file=sys.stderr)
        return 3

    index = {
        "app": str(app),
        "evidence_root": str(runtime_root),
        "window_sizes": ["960x640", "1280x800"],
        "ui_scales": [100, 125, 150],
        "fixtures": ["q01_warning_one", "journey", "gallery"],
        "production_roots": [str(p) for p in production_roots()],
        "production_diff_empty": True,
        "captures": records,
    }
    (EVIDENCE / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps({
        "pass": True,
        "capture_count": len(records),
        "output": str(EVIDENCE),
    }, ensure_ascii=False))
    return 0


def glob_private_tmp() -> list[str]:
    """Newest Debug app under /private/tmp/n027-w5.* build products."""
    import glob
    return glob.glob("/private/tmp/n027-w5.*/DD/Build/Products/Debug/CreekSprout.app")


if __name__ == "__main__":
    raise SystemExit(main())
