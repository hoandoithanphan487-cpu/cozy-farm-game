#!/usr/bin/env python3
"""Capture the three product-owner N-019 R19 corrections in the real App."""

from __future__ import annotations

import importlib.util
import os
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = Path(os.environ.get(
    "N019_R19_APP",
    "/tmp/creeksprout-n019-r19-dd/Build/Products/Debug/CreekSprout.app",
))
OUT = ROOT / "artifacts/integration/n-019-demo-visual/canal-sunflowers-r19/real-app"

helper_path = ROOT / "scripts/drive-n017-demo-app.py"
spec = importlib.util.spec_from_file_location("n019_r19_driver", helper_path)
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
    driver.LOG.write_text(
        "# N-019 R19 crate, canal, and sunflower real App capture\n\n",
        encoding="utf-8",
    )

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

    driver.walk_to(9, 6)
    driver.capture(
        "01-farm-crate-canal-r19-frame-a",
        "农场：箱子显示在箭头目标；水渠接入水工建筑并带硬边明暗与流动高光（A 帧）",
    )
    time.sleep(0.42)
    driver.capture(
        "02-farm-crate-canal-r19-frame-b",
        "农场：同机位后的水渠动画 B 帧，用于核对流动变化",
    )

    driver.walk_to(7, 1)
    driver.face_toward("s")
    driver.press("space", 0.5)
    driver.wait_hud()
    driver.walk_to(9, 7)
    driver.capture(
        "03-market-right-sunflowers-r19",
        "集市：右侧标注区域补满与左侧同款的向日葵花田",
    )
    print(f"CAPTURE_OK app={APP}")


if __name__ == "__main__":
    main()
