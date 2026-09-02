#!/usr/bin/env python3
"""Drive a real CreekSprout.app and capture N-018 visual-finish evidence."""

from __future__ import annotations

import json
import os
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
import importlib.util

_n017_path = ROOT / "scripts" / "drive-n017-demo-app.py"
_spec = importlib.util.spec_from_file_location("drive_n017_demo_app", _n017_path)
n017 = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(n017)

activate_and_resize = n017.activate_and_resize
click_named_button = n017.click_named_button
enter_demo_session = n017.enter_demo_session
face_toward = n017.face_toward
finish_dialogue = n017.finish_dialogue
hud = n017.hud
n017_capture = n017.capture
pid = n017.pid
position = n017.position
press = n017.press
run = n017.run
wait_hud = n017.wait_hud
walk_to = n017.walk_to

APP = Path(os.environ.get("N018_APP", os.environ.get("N017_APP", "/tmp/creeksprout-n018-demo/Build/Products/Release/CreekSprout.app")))
OUT = Path(os.environ.get("N018_APP_EVIDENCE", ROOT / "artifacts/integration/n-018-visual/real-app"))
SHOTS = OUT / "screenshots"
LOG = OUT / "drive-log.md"
MIN_SECONDS = int(os.environ.get("N018_MIN_SECONDS", "720"))

# Rebind n017 capture output.
n017.APP = APP
n017.OUT = OUT
n017.SHOTS = SHOTS
n017.LOG = LOG


def log(message: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    line = f"- {datetime.now().strftime('%H:%M:%S')} {message}"
    print(line, flush=True)
    with LOG.open("a", encoding="utf-8") as handle:
        handle.write(line + "\n")


n017.log = log


def capture(name: str, note: str) -> dict[str, object]:
    return n017_capture(name, note)


def talk(approach_x: int, approach_y: int, face: str, name: str, note: str) -> None:
    walk_to(approach_x, approach_y)
    face_toward(face)
    press("t", 0.45)
    wait_hud()
    capture(name, note)
    finish_dialogue()


def inspect_building(x: int, y: int, name: str, note: str) -> None:
    walk_to(x, y)
    press("e", 0.45)
    capture(name, note)
    press("e", 0.2)


def main() -> int:
    if not APP.exists():
        raise RuntimeError(f"app missing: {APP}")
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True, exist_ok=True)
    SHOTS.mkdir(parents=True, exist_ok=True)
    LOG.write_text("# N-018 real App visual drive\n\n", encoding="utf-8")
    started = time.time()
    log(f"app={APP}")

    run(["osascript", "-e", 'tell application "CreekSprout" to quit'])
    time.sleep(0.6)
    import subprocess

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
    capture("01-welcome-1280x800", "欢迎页只作为入口")
    enter_demo_session()
    wait_hud()
    log(f"entered demo at {position()}")
    capture("02-farm-sunny-1280x800", "农场晴天默认画面")

    press("q", 0.45)
    capture("07a-player-portrait-1280", "玩家高清立绘")
    press("q", 0.2)

    press("2", 0.2)
    press("2", 0.2)
    press("2", 0.2)
    press("2", 0.2)
    press("2", 0.2)
    capture("13a-seed-cycle-1280", "五类作物种子图标")

    press("4")
    walk_to(4, 4)
    face_toward("s")
    press("space")
    capture("10-harvest-1280", "收获事件")
    walk_to(5, 4)
    face_toward("s")
    press("space")
    walk_to(6, 4)
    face_toward("s")
    press("space")
    press("i", 0.3)
    capture("11-sell-1280", "出售投入事件")

    press("1")
    walk_to(2, 2)
    face_toward("w")
    press("space")
    capture("12-till-1280", "耕地事件")
    press("2")
    press("space")
    capture("13-sow-1280", "播种事件")
    press("3")
    press("space")
    capture("14-water-1280", "浇水事件")

    inspect_building(3, 7, "08-farm-house-1280", "农场高清农舍展示")
    inspect_building(12, 7, "08b-farm-sluice-1280", "农场高清铜闸展示")

    walk_to(7, 1)
    face_toward("s")
    press("space", 0.5)
    wait_hud()
    capture("04-market-sunny-1280x800", "集市晴天默认画面")

    talk(3, 5, "w", "07-dialogue-apprentice-1280", "水工学徒对话与高清立绘")
    talk(4, 8, "w", "07b-dialogue-steward-1280", "种源管理员对话与高清立绘")
    talk(6, 6, "d", "07c-dialogue-storyteller-1280", "石灯对话与高清立绘")
    talk(4, 7, "d", "07d-dialogue-hearsay-1280", "涧麦婶对话与高清立绘")
    talk(10, 6, "d", "07e-dialogue-evidence-1280", "青砚对话与高清立绘")
    talk(12, 7, "d", "07f-dialogue-consensus-1280", "絮宁对话与高清立绘")
    talk(12, 9, "d", "07g-dialogue-warden-1280", "溪岸巡护员对话与高清立绘")
    capture("07-dialogue-portrait-1280", "人物对话与高清立绘汇总前帧")

    inspect_building(3, 5, "09-market-wharf-1280", "集市高清埠头展示")
    inspect_building(1, 8, "09b-market-seed-shed-1280", "集市高清种源棚展示")
    inspect_building(16, 8, "09c-market-warden-post-1280", "集市高清巡护亭展示")
    capture("09-market-building-1280", "集市建筑展示")

    walk_to(9, 8)
    walk_to(9, 11)
    face_toward("w")
    press("space", 0.5)
    wait_hud()
    walk_to(9, 7)
    face_toward("s")
    press("space", 0.4)
    capture("15-craft-1280", "制作/加工入口")
    press("escape", 0.2)
    walk_to(7, 6)

    press("n", 0.8)
    wait_hud()
    capture("03-farm-rain-1280x800", "农场雨天默认画面")
    walk_to(7, 1)
    face_toward("s")
    press("space", 0.5)
    wait_hud()
    capture("05-market-rain-1280x800", "集市雨天默认画面")
    walk_to(9, 11)
    face_toward("w")
    press("space", 0.5)
    wait_hud()

    press("escape", 0.35)
    press("2", 0.4)
    capture("16-settings-1280", "设置页")
    press("down", 0.2)
    press("down", 0.2)
    press("left", 0.2)
    capture("17-volume-1280", "音量调节")
    press("left", 0.2)
    press("left", 0.2)
    capture("18-mute-1280", "静音")
    press("3", 0.3)
    capture("19-restore-defaults-1280", "恢复默认")
    press("escape", 0.3)
    press("escape", 0.3)
    press("1", 0.25)

    activate_and_resize(960, 640)
    time.sleep(0.5)
    capture("06-farm-960x640", "农场默认 960×640")
    walk_to(7, 1)
    face_toward("s")
    press("space", 0.5)
    wait_hud()
    capture("06b-market-960x640", "集市默认 960×640")
    activate_and_resize(1280, 800)

    remaining = MIN_SECONDS - (time.time() - started)
    log(f"idling {max(remaining, 0):.1f}s to reach {MIN_SECONDS}s")
    deadline = started + MIN_SECONDS
    while time.time() < deadline:
        press("a" if int(time.time()) % 2 == 0 else "d", 0.8)
        time.sleep(8)

    elapsed = time.time() - started
    consumed_src = None
    for folder in n017.demo_dirs():
        candidate = folder / "consumed-runtime-pngs.txt"
        if candidate.exists():
            consumed_src = candidate
    if consumed_src:
        shutil.copy2(consumed_src, OUT / "consumed-runtime-pngs.txt")
    (OUT / "runtime-duration.txt").write_text(
        f"started_utc={datetime.fromtimestamp(started, timezone.utc).isoformat()}\n"
        f"elapsed_seconds={elapsed:.1f}\n"
        f"required_seconds={MIN_SECONDS}\n",
        encoding="utf-8",
    )
    log(f"DRIVE_OK elapsed={elapsed:.1f}s")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:  # noqa: BLE001
        log(f"DRIVE_FAIL {error}")
        raise
