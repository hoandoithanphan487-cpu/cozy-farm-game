#!/usr/bin/env python3
"""Capture the bounded N-019 R6 crop and market-sluice visual proof."""

from __future__ import annotations

import importlib.util
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = Path(
    "/Users/fengyifan/Library/Developer/Xcode/DerivedData/"
    "CreekSprout-gbsayxwynrkqivcpwgdarulvxunt/Build/Products/Debug/CreekSprout.app"
)
OUT = ROOT / "artifacts/integration/n-019-demo-visual/crop-sluice-r6/real-app"

helper_path = ROOT / "scripts/drive-n017-demo-app.py"
spec = importlib.util.spec_from_file_location("n019_r6_driver", helper_path)
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
    driver.walk_to(7, 1)
    driver.face_toward("s")
    driver.press("space", 0.5)
    driver.wait_hud()
    driver.walk_to(3, 5)
    driver.capture(
        "18-market-crops-sluice-r2-final",
        "N-019 R6：五类紧凑成熟作物与连续水坝口—河流连接",
    )
    print(f"CAPTURE_OK position={driver.position()}")


if __name__ == "__main__":
    main()
