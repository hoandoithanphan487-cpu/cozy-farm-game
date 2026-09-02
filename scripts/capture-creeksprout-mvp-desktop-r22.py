#!/usr/bin/env python3
"""Verify and capture the persistent R22 MVP desktop delivery."""

from __future__ import annotations

import importlib.util
import os
import signal
import subprocess
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = Path("/Users/fengyifan/Desktop/溪谷新芽.app")
OUT = ROOT / "artifacts/releases/creeksprout-mvp-r22/evidence"

helper_path = ROOT / "scripts/drive-n017-demo-app.py"
spec = importlib.util.spec_from_file_location("mvp_r22_driver", helper_path)
driver = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(driver)

driver.APP = APP
driver.OUT = OUT
driver.SHOTS = OUT / "screenshots"
driver.LOG = OUT / "drive-log.md"


def launch_fresh() -> None:
    # Multiple historical bundles share the same process name. Terminate every
    # exact CreekSprout process so LaunchServices cannot reactivate an old page.
    running = driver.run(["pgrep", "-x", "CreekSprout"])
    if running.returncode == 0:
        for value in running.stdout.split():
            os.kill(int(value), signal.SIGTERM)
    for _ in range(40):
        if driver.run(["pgrep", "-x", "CreekSprout"]).returncode != 0:
            break
        time.sleep(0.25)
    else:
        raise RuntimeError("historical CreekSprout process did not quit")
    subprocess.Popen(["open", "-n", str(APP)])
    for _ in range(80):
        try:
            driver.pid()
            break
        except RuntimeError:
            time.sleep(0.2)
    else:
        raise RuntimeError("desktop MVP app did not launch")

    time.sleep(1.2)
    for _ in range(240):
        try:
            driver.activate_and_resize(1280, 800)
            return
        except RuntimeError:
            time.sleep(0.25)
    raise RuntimeError("desktop MVP app launched without a visible window")


def process_command() -> str:
    result = driver.run([
        "ps", "-p", str(driver.pid()), "-o", "command=",
    ])
    if result.returncode or not result.stdout.strip():
        raise RuntimeError(result.stderr.strip() or "could not resolve process command")
    return result.stdout.strip()


def main() -> None:
    if not APP.is_symlink():
        raise RuntimeError(f"desktop entry is not the expected stable symlink: {APP}")
    resolved = APP.resolve(strict=True)
    expected = Path("/Users/fengyifan/Applications/溪谷新芽.app")
    if resolved != expected:
        raise RuntimeError(f"unexpected desktop target: {resolved}")

    OUT.mkdir(parents=True, exist_ok=True)
    driver.SHOTS.mkdir(parents=True, exist_ok=True)
    driver.LOG.write_text(
        "# CreekSprout MVP R22 desktop Release drive\n\n",
        encoding="utf-8",
    )

    launch_fresh()
    command = process_command()
    if str(expected / "Contents/MacOS/CreekSprout") not in command:
        raise RuntimeError(f"wrong executable launched: {command}")
    driver.log(f"desktop_entry={APP}")
    driver.log(f"resolved_payload={resolved}")
    driver.log(f"process_command={command}")
    driver.capture(
        "01-mvp-welcome",
        "从桌面唯一入口冷启动后的《溪谷新芽》欢迎页",
    )

    driver.enter_demo_session()
    time.sleep(1.0)
    driver.wait_hud()
    driver.walk_to(7, 10)
    driver.capture(
        "02-mvp-r22-farm",
        "当前 R22 农场：花丛前移、两区向日葵、指定横栅栏删除",
    )

    driver.walk_to(7, 1)
    driver.face_toward("s")
    driver.press("space", 0.5)
    driver.wait_hud()
    driver.walk_to(9, 10)
    driver.capture(
        "03-mvp-r22-market-lake-a",
        "当前 R22 集市：湖泊退离山脚并保留动态水纹 A 帧",
    )
    time.sleep(0.42)
    driver.capture(
        "04-mvp-r22-market-lake-b",
        "当前 R22 集市：相同岸线与动态水纹 B 帧",
    )

    # Leave the Product Owner at the new welcome page after verification.
    launch_fresh()
    final_command = process_command()
    if str(expected / "Contents/MacOS/CreekSprout") not in final_command:
        raise RuntimeError(f"wrong executable left open: {final_command}")
    driver.capture(
        "05-mvp-welcome-left-open",
        "验收完成后留在桌面的新版欢迎页",
    )
    driver.log(f"left_open_process_command={final_command}")
    print(f"MVP_DESKTOP_CAPTURE_OK entry={APP} payload={resolved}")


if __name__ == "__main__":
    main()
