#!/usr/bin/env python3
"""Capture the bounded N-019 R14 depth and layout proof in the real app."""

from __future__ import annotations

import importlib.util
import os
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = Path(os.environ.get(
    "N019_R14_APP",
    "/private/tmp/creeksprout-n019-r14-derived/Build/Products/Debug/CreekSprout.app",
))
OUT = ROOT / "artifacts/integration/n-019-demo-visual/depth-layout-r14/real-app"

helper_path = ROOT / "scripts/drive-n017-demo-app.py"
spec = importlib.util.spec_from_file_location("n019_r14_driver", helper_path)
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
    driver.LOG.write_text("# N-019 R14 real App capture\n\n", encoding="utf-8")

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
        "01-farm-rear-mountain-fields-r14",
        "后山铺满固定后场；屋后花田与围栏翻土田",
    )
    driver.walk_to(12, 4)
    driver.capture(
        "02-farm-haystack-irregular-pond-r14",
        "牧圈前草垛、软阴影与不规则蓄水池岸",
    )

    driver.walk_to(7, 1)
    driver.face_toward("s")
    driver.press("space", 0.5)
    driver.wait_hud()
    driver.walk_to(9, 10)
    driver.capture(
        "03-market-mountain-flower-cat-r14",
        "集市后山、人物后花田与猫店右侧黑猫",
    )
    driver.walk_to(14, 4)
    driver.capture(
        "04-market-sunflowers-irregular-river-r14",
        "向日葵田、河岸栅栏与不规则流动河岸",
    )
    print(f"CAPTURE_OK app={APP}")


if __name__ == "__main__":
    main()
