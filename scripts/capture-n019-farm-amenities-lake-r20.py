#!/usr/bin/env python3
"""Capture N-019 R20 dining, rear field, greenhouse, and scenic lake proof."""

from __future__ import annotations

import importlib.util
import os
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = Path(os.environ.get(
    "N019_R20_APP",
    "/tmp/CreekSprout-R20-FullDerivedData/Build/Products/Debug/CreekSprout.app",
))
OUT = ROOT / "artifacts/integration/n-019-demo-visual/farm-amenities-lake-r20/real-app"

helper_path = ROOT / "scripts/drive-n017-demo-app.py"
spec = importlib.util.spec_from_file_location("n019_r20_driver", helper_path)
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
        "# N-019 R20 farm amenities and market lake real App capture\n\n",
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
        "01-farm-rear-path-field-r20",
        "农场：两屋之间的同款石路穿过单格围栏开口，并接入四格真实后田",
    )
    driver.walk_to(4, 2)
    driver.capture(
        "02-farm-dining-area-r20",
        "农场：左下用一张略大的木桌和三张凳子形成明确吃饭区",
    )

    driver.walk_to(7, 1)
    driver.face_toward("s")
    driver.press("space", 0.5)
    driver.wait_hud()
    driver.walk_to(9, 10)
    driver.capture(
        "03-market-greenhouse-lake-r20-frame-a",
        "集市：左上 45 度玻璃保温室与右上不规则湖泊（动态 A 帧）",
    )
    time.sleep(0.42)
    driver.capture(
        "04-market-greenhouse-lake-r20-frame-b",
        "集市：同机位湖面高光变化（动态 B 帧），岸线与阴影保持固定",
    )
    print(f"CAPTURE_OK app={APP}")


if __name__ == "__main__":
    main()
