#!/usr/bin/env python3
"""Capture the four product-owner N-019 R22 visual corrections in the real App."""

from __future__ import annotations

import importlib.util
import os
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = Path(os.environ.get(
    "N019_R22_APP",
    "/tmp/creeksprout-n019-r22/Build/Products/Debug/CreekSprout.app",
))
OUT = ROOT / "artifacts/integration/n-019-demo-visual/visual-feedback-r22/real-app"

helper_path = ROOT / "scripts/drive-n017-demo-app.py"
spec = importlib.util.spec_from_file_location("n019_r22_driver", helper_path)
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
        "# N-019 R22 product-owner visual corrections real App capture\n\n",
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

    driver.walk_to(7, 10)
    driver.capture(
        "01-farm-flower-sunflowers-fence-r22",
        "农场：左侧花丛前移；后方两块标注区域铺满向日葵；指定屋侧横栅栏已删除",
    )

    driver.walk_to(7, 1)
    driver.face_toward("s")
    driver.press("space", 0.5)
    driver.wait_hud()
    driver.walk_to(9, 10)
    driver.capture(
        "02-market-lake-retracted-r22-frame-a",
        "集市：湖泊山侧与右侧岸线向内收，不再压到远山（动态 A 帧）",
    )
    time.sleep(0.42)
    driver.capture(
        "03-market-lake-retracted-r22-frame-b",
        "集市：同机位动态 B 帧；水面动画保留且收边轮廓固定",
    )
    print(f"CAPTURE_OK app={APP}")


if __name__ == "__main__":
    main()
