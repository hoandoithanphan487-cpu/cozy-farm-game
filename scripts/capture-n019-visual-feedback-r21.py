#!/usr/bin/env python3
"""Capture the N-019 R21 visual-feedback proof in the real macOS app."""

from __future__ import annotations

import importlib.util
import os
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = Path(os.environ.get(
    "N019_R21_APP",
    "/tmp/creeksprout-n019-r21/Build/Products/Debug/CreekSprout.app",
))
OUT = ROOT / "artifacts/integration/n-019-demo-visual/visual-feedback-r21/real-app"

helper_path = ROOT / "scripts/drive-n017-demo-app.py"
spec = importlib.util.spec_from_file_location("n019_r21_driver", helper_path)
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
    driver.LOG.write_text("# N-019 R21 real App capture\n\n", encoding="utf-8")

    driver.run(["osascript", "-e", 'tell application "CreekSprout" to quit'])
    time.sleep(0.6)
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
    for _ in range(120):
        try:
            driver.activate_and_resize(1280, 800)
            break
        except RuntimeError:
            time.sleep(0.25)
    else:
        raise RuntimeError("app process launched but no main window appeared")
    driver.enter_demo_session()
    driver.wait_hud()

    driver.walk_to(7, 1)
    driver.face_toward("s")
    driver.press("space", 0.5)
    driver.wait_hud()
    driver.walk_to(9, 10)
    driver.capture(
        "01-market-lake-greenhouse-flowers-r21",
        "加厚湖泊、无遮挡且后移的玻璃房，以及原五格位置花丛",
    )
    time.sleep(0.42)
    driver.capture(
        "02-market-lake-animation-r21",
        "同岸线下一动画帧，证明加厚湖泊仍保持固定岸线流动",
    )
    driver.walk_to(6, 4)
    driver.capture(
        "03-market-river-depth-r21",
        "远岸缩小偏冷、中段水面分层、近岸放大加深的河流景深",
    )
    print(f"CAPTURE_OK app={APP}")


if __name__ == "__main__":
    main()
