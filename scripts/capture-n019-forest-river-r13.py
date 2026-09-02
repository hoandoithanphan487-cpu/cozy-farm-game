#!/usr/bin/env python3
"""Capture the bounded N-019 R13 forest, stone, and creek visual proof."""

from __future__ import annotations

import importlib.util
import os
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = Path(os.environ.get(
    "N019_R13_APP",
    "/private/tmp/creeksprout-n019-r13.k6QJEW/Build/Products/Debug/CreekSprout.app",
))
OUT = ROOT / "artifacts/integration/n-019-demo-visual/forest-river-r13/real-app"

helper_path = ROOT / "scripts/drive-n017-demo-app.py"
spec = importlib.util.spec_from_file_location("n019_r13_driver", helper_path)
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
    driver.LOG.write_text("# N-019 R13 real App capture\n\n", encoding="utf-8")

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
    driver.activate_and_resize(1280, 800)
    driver.enter_demo_session()
    driver.wait_hud()

    driver.walk_to(7, 10)
    driver.capture(
        "01-farm-forest-ridge-r13",
        "山林上移、连续林脊与两侧自然框景",
    )
    driver.walk_to(11, 2)
    driver.capture(
        "02-farm-flowing-water-stones-r13",
        "农场溪口四帧纵向流水、苔石与踏石路",
    )

    driver.walk_to(7, 1)
    driver.face_toward("s")
    driver.press("space", 0.5)
    driver.wait_hud()
    driver.capture(
        "03-market-north-frame-r13",
        "集市北侧溪谷上移与入口留白",
    )
    driver.walk_to(9, 3)
    driver.capture(
        "04-market-flowing-creek-stones-r13",
        "集市连续水面、方向流纹与河岸苔石",
    )
    print(f"CAPTURE_OK app={APP}")


if __name__ == "__main__":
    main()
