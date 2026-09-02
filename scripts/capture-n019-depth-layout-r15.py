#!/usr/bin/env python3
"""Capture the corrected N-019 R15 pixel-style depth/layout proof."""

from __future__ import annotations

import importlib.util
import os
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = Path(os.environ.get(
    "N019_R15_APP",
    "/private/tmp/creeksprout-n019-r15-derived/Build/Products/Debug/CreekSprout.app",
))
OUT = ROOT / "artifacts/integration/n-019-demo-visual/depth-layout-r15/real-app"

helper_path = ROOT / "scripts/drive-n017-demo-app.py"
spec = importlib.util.spec_from_file_location("n019_r15_driver", helper_path)
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
    driver.LOG.write_text("# N-019 R15 corrected real App capture\n\n", encoding="utf-8")

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
        "01-farm-three-plane-mountains-fields-r15",
        "远山、中景林带、近景山脚全部位于房屋后；屋后花田与围栏翻土田",
    )
    driver.walk_to(10, 4)
    driver.capture(
        "02-farm-haystack-irregular-pond-r15",
        "中间活动区与右侧牧圈之间的谷堆，以及不规则蓄水池岸",
    )

    driver.walk_to(7, 1)
    driver.face_toward("s")
    driver.press("space", 0.5)
    driver.wait_hud()
    driver.walk_to(9, 10)
    driver.capture(
        "03-market-three-plane-mountains-layout-r15",
        "后山三层背景；左屋、人物、花田、猫店、猫与原 NPC 的手稿关系",
    )
    driver.walk_to(6, 4)
    driver.capture(
        "04-market-sunflowers-irregular-river-r15",
        "下方建筑右侧向日葵田、临水栅栏与不规则流动河岸",
    )
    print(f"CAPTURE_OK app={APP}")


if __name__ == "__main__":
    main()
