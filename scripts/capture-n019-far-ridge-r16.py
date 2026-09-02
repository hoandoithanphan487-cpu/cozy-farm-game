#!/usr/bin/env python3
"""Capture N-019 R16 single transparent far-ridge proof in the real App."""

from __future__ import annotations

import importlib.util
import os
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = Path(os.environ.get(
    "N019_R16_APP",
    "/tmp/creeksprout-n019-r16-dd/Build/Products/Debug/CreekSprout.app",
))
OUT = ROOT / "artifacts/integration/n-019-demo-visual/far-ridge-r16/real-app"

helper_path = ROOT / "scripts/drive-n017-demo-app.py"
spec = importlib.util.spec_from_file_location("n019_r16_driver", helper_path)
driver = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(driver)

driver.APP = APP
driver.OUT = OUT
driver.SHOTS = OUT / "screenshots"
driver.LOG = OUT / "drive-log.md"


def main() -> None:
    if not APP.exists():
        raise RuntimeError(f"app missing: {APP}")
    OUT.mkdir(parents=True, exist_ok=True)
    driver.SHOTS.mkdir(parents=True, exist_ok=True)
    driver.LOG.write_text("# N-019 R16 transparent far-ridge real App capture\n\n", encoding="utf-8")

    driver.run(["osascript", "-e", 'tell application "CreekSprout" to quit'])
    for _ in range(40):
        try:
            driver.pid()
            time.sleep(0.25)
        except RuntimeError:
            break
    subprocess.Popen(["open", "-n", str(APP)])
    for _ in range(80):
        try:
            driver.pid()
            break
        except RuntimeError:
            time.sleep(0.2)
    else:
        raise RuntimeError("app did not launch")

    time.sleep(1.2)
    for _ in range(240):
        try:
            driver.activate_and_resize(1280, 800)
            break
        except RuntimeError:
            time.sleep(0.25)
    else:
        raise RuntimeError("app process launched but no main window appeared")
    driver.enter_demo_session()
    driver.wait_hud()

    driver.walk_to(7, 10)
    driver.capture(
        "01-farm-single-far-ridge-r16",
        "单条透明暖绿远山从 y=12 起，只在房屋与后排田地之后；房屋周围继续显示原草地",
    )

    driver.walk_to(7, 1)
    driver.face_toward("s")
    driver.press("space", 0.5)
    driver.wait_hud()
    driver.walk_to(9, 10)
    driver.capture(
        "02-market-single-far-ridge-r16",
        "单条透明暖绿远山从 y=11 起；中央低谷和既有建筑、人物、花田关系保持",
    )
    print(f"CAPTURE_OK app={APP}")


if __name__ == "__main__":
    main()
