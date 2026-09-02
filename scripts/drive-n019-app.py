#!/usr/bin/env python3
"""N-019 evidence tool: drive a real CreekSprout.app window and capture
Retina screenshots via ScreenCaptureKit (compiled Swift helper).

Usage:
  N019_APP=/path/to/CreekSprout.app python3 scripts/drive-n019-app.py --shot <name>
  python3 scripts/drive-n019-app.py --keys return --wait 2 --shot farm
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from ctypes import CDLL, POINTER, c_bool, c_int32, c_uint16, c_uint32, c_void_p
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = Path(os.environ.get(
    "N019_APP",
    "/tmp/creeksprout-n019/Build/Products/Debug/CreekSprout.app",
))
OUT = Path(os.environ.get(
    "N019_EVIDENCE",
    ROOT / "artifacts/integration/n-019-demo-visual/evidence",
))

KEY = {
    "a": 0x00, "s": 0x01, "d": 0x02, "w": 0x0D, "e": 0x0E, "h": 0x04,
    "i": 0x22, "k": 0x28, "l": 0x25, "q": 0x0C, "t": 0x11, "r": 0x0F,
    "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17, "6": 0x16,
    "7": 0x1A, "8": 0x1C, "9": 0x19,
    "space": 0x31, "return": 0x24, "escape": 0x35, "tab": 0x30,
    "down": 0x7D, "up": 0x7E, "left": 0x7B, "right": 0x7C,
    "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B, "n": 0x2D, "m": 0x2E,
    "f": 0x03, "g": 0x05, "j": 0x26, "u": 0x20, "y": 0x10, "p": 0x23,
}
CHAR = {**{key: key for key in "asdewhikltqr123456789zxcvbnmfgjuy"},
        "space": " ", "return": "\r", "escape": "", "tab": "\t",
        "down": "", "up": "", "left": "", "right": ""}

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

SWIFT_CAP = ROOT / "scripts/n019-cap-window.swift"
CAP_BIN = OUT / "n019-cap-bin"
SWIFT_CAP_TEXT = """import AppKit
import ScreenCaptureKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

_ = NSApplication.shared
let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: cap <windowid> <out.png>"); exit(2) }
let windowID = UInt32(args[1]) ?? 0
let outPath = args[2]
let sema = DispatchSemaphore(value: 0)
Task {
    do {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            print("WINDOW NOT FOUND"); sema.signal(); exit(3)
        }
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width * 2)
        config.height = Int(window.frame.height * 2)
        config.showsCursor = false
        config.scalesToFit = true
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        let url = URL(fileURLWithPath: outPath) as CFURL
        if let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(dest, image, nil)
            if CGImageDestinationFinalize(dest) { print("SAVED \\(image.width)x\\(image.height)") }
            else { print("FINALIZE FAILED"); exit(4) }
        }
    } catch { print("ERROR:", error); exit(5) }
    sema.signal()
}
sema.wait()
"""


def run(args):
    return subprocess.run(args, text=True, capture_output=True, check=False)


def pid() -> int:
    result = run(["pgrep", "-n", "-x", "CreekSprout"])
    if result.returncode or not result.stdout.strip():
        raise RuntimeError("CreekSprout process not found")
    return int(result.stdout.strip().splitlines()[0])


def press(name: str, pause: float = 0.15) -> None:
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


def window_info() -> tuple[int, dict]:
    script = """import AppKit
import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for w in list {
    let owner = w[kCGWindowOwnerName as String] as? String ?? ""
    if owner.contains("CreekSprout") {
        let num = w[kCGWindowNumber as String] as? Int ?? -1
        let b = w[kCGWindowBounds as String] as? [String: Double] ?? [:]
        print("id=\\(num) frame=\\(b["X"] ?? 0),\\(b["Y"] ?? 0),\\(b["Width"] ?? 0),\\(b["Height"] ?? 0)")
    }
}
"""
    src = OUT / "n019-wininfo.swift"
    OUT.mkdir(parents=True, exist_ok=True)
    src.write_text(script, encoding="utf-8")
    result = run(["swift", str(src)])
    for line in result.stdout.strip().splitlines():
        if line.startswith("id="):
            parts = line.replace("id=", "").split(" frame=")
            wid = int(parts[0])
            x, y, w, h = [float(v) for v in parts[1].split(",")]
            return wid, {"x": x, "y": y, "width": w, "height": h}
    raise RuntimeError("CreekSprout window not found")


def ensure_cap_bin() -> Path:
    CAP_BIN.parent.mkdir(parents=True, exist_ok=True)
    if not CAP_BIN.exists():
        src = OUT / "n019-cap-window.swift"
        src.write_text(SWIFT_CAP_TEXT, encoding="utf-8")
        result = run(["swiftc", str(src), "-o", str(CAP_BIN)])
        if result.returncode != 0:
            raise RuntimeError(f"swiftc failed: {result.stderr}")
    return CAP_BIN


def capture(name: str, note: str = "") -> Path:
    OUT.mkdir(parents=True, exist_ok=True)
    shots = OUT / "screenshots"
    shots.mkdir(parents=True, exist_ok=True)
    wid, bounds = window_info()
    path = shots / f"{name}.png"
    result = run([str(ensure_cap_bin()), str(wid), str(path)])
    print(f"[capture] {name}: {result.stdout.strip()} {note}")
    with (OUT / "capture-log.txt").open("a", encoding="utf-8") as handle:
        handle.write(f"{time.strftime('%H:%M:%S')} {name} {result.stdout.strip()} "
                     f"bounds={bounds} note={note}\n")
    return path


def activate():
    run(["osascript", "-e", 'tell application "CreekSprout" to activate'])
    time.sleep(0.6)


def launch():
    if not APP.exists():
        raise RuntimeError(f"App not found: {APP}")
    run(["open", str(APP)])
    time.sleep(4)
    activate()


def main() -> None:
    args = sys.argv[1:]
    if "--launch" in args:
        launch()
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--keys":
            for key in args[i + 1].split(","):
                press(key)
            i += 2
        elif arg == "--wait":
            time.sleep(float(args[i + 1]))
            i += 2
        elif arg == "--shot":
            capture(args[i + 1], args[i + 2] if i + 2 < len(args) else "")
            i += 2 if i + 2 < len(args) else 1
        elif arg == "--activate":
            activate()
            i += 1
        else:
            i += 1


if __name__ == "__main__":
    main()
