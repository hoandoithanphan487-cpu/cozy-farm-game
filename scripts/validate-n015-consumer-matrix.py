#!/usr/bin/env python3
"""Independent validator and refresher for docs/game/n-015-runtime-consumer-matrix.json.

Read-only by default. Writes evidence only with --write-evidence <dir>.
Writes the matrix only with --refresh-matrix (deterministic, tracked).

This script is the single authoritative source for the N-015 consumer matrix.
It does NOT depend on the git-ignored artifacts/integration/.../generate-matrix.py.

Authoritative inputs (resolved in explicit override order
base -> N-003 override -> N-015 character override -> DEC-033 addition):
  - artifacts/art-style/runtime-batch-r0/manifest.json   (N-006 base)
  - artifacts/art-style/n-003-first-round/pixel-check.json (N-003 approved overrides)
  - docs/game/n-015-character-overrides.json             (N-015 portrait-derived character overrides)
  - docs/game/n-015-runtime-additions.json               (DEC-033 addition)
  - scripts/audit-runtime-art-integration.py             (run live for resolved_referenced)

The validator derives, per file, the authoritative expected value of every
contract field (category, provenance, planned_consumer, trigger_state, fallback,
batch) from the filenames plus the authoritative manifests, then compares each
matrix record field-by-field. Any fabricated consumer, wrong batch, swapped
provenance, or mis-category fails validation with a non-zero exit code.

Provenance is compared per file (not just the 104/8/1/19 summary counts): the
validator recomputes the exact provenance of every filename from the four
authoritative manifests and requires the matrix to match exactly.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "artifacts/art-style/runtime-batch-r0/manifest.json"
OVERRIDES = ROOT / "artifacts/art-style/n-003-first-round/pixel-check.json"
CHARACTER_OVERRIDES = ROOT / "docs/game/n-015-character-overrides.json"
ADDITIONS = ROOT / "docs/game/n-015-runtime-additions.json"
AUDIT_SCRIPT = ROOT / "scripts/audit-runtime-art-integration.py"
MATRIX = ROOT / "docs/game/n-015-runtime-consumer-matrix.json"
ASSETS_DIR = ROOT / "macos/CreekSprout/CreekSprout/Assets"

VALID_CATEGORIES = {"char", "crop", "tile", "building", "prop", "gather", "tool", "fx", "ui"}
VALID_PROVENANCE = {
    "n006_base",
    "n003_approved_override",
    "n015_portrait_derived_override",
    "dec033_approved_addition",
}
VALID_BATCH = {"B1", "B2", "B3", "B4", "B5"}
VALID_STATUS = {"integrated", "planned", "blocked"}

EXPECTED_PROVENANCE_COUNTS = {
    "n006_base": 104,
    "n003_approved_override": 8,
    "n015_portrait_derived_override": 19,
    "dec033_approved_addition": 1,
}

EXPECTED_GENERATED_FROM = [
    "artifacts/art-style/runtime-batch-r0/manifest.json",
    "artifacts/art-style/n-003-first-round/pixel-check.json",
    "docs/game/n-015-character-overrides.json",
    "docs/game/n-015-runtime-additions.json",
    "scripts/audit-runtime-art-integration.py",
]

# --- Authoritative per-family contract, from docs/game/n-015-runtime-consumer-contract.md ---
CHAR_STATIC_CONSUMER = "CharacterVisualCatalog / PixelAssetStore"
CHAR_WALK_CONSUMER = "SpriteSheetAnimator"
PLAYER_ACTION_CONSUMER = "PlayerActionPresenter"
CROP_ITEM_CONSUMER = "InventoryItemIconPresenter / CompactFarmHudView"
CROP_STAGE_CONSUMER = "FarmScene.makeCropNode"
GRASS_CONSUMER = "PixelAssetStore.tileKind"
TILLED_CONSUMER = "PixelAssetStore.tileKind"
WATER_CONSUMER = "WaterVisualResolver"
STONE_PATH_CONSUMER = "TerrainVisualResolver"
CANAL_TILE_CONSUMER = "CanalVisualPresenter"
BUILDING_CONSUMER = "BuildingVisualPresenter"
PROP_CONSUMER = "FarmScene.makePlacedObjectGlyph"
GATHER_CONSUMER = "GatherableVisualPresenter"
TOOL_CONSUMER = "CompactFarmHudView"
FX_TARGET_CONSUMER = "TargetFeedbackPresenter"
FX_SPLASH_CONSUMER = "WorldEffectPresenter"
FX_HARVEST_CONSUMER = "WorldEffectPresenter"
FX_CANAL_CONSUMER = "CanalVisualPresenter"
UI_STATUS_CONSUMER = "CompactFarmHudView"
UI_BADGE_CONSUMER = "CompactFarmHudView"
UI_SLOT_CONSUMER = "CompactFarmHudView"

FALLBACK_CHAR = "char_player.png (player idle) or programmatic colored-block fallback"
FALLBACK_CROP = "crop_<crop>.png (mature item icon) or programmatic fallback"
FALLBACK_TILE = "tile_grass.png base tile"
FALLBACK_PROP = "programmatic placed-object glyph"
FALLBACK_FX = "no-op: omit FX node, keep core interaction feedback"
FALLBACK_BUILDING = "omit missing visual layer while retaining authoritative collision and interaction cells"
FALLBACK_TOOL = "programmatic tool glyph"
FALLBACK_UI = "programmatic HUD label"

CHAR_STATIC = [
    "char_player",
    "char_water_apprentice",
    "char_seed_steward",
    "char_creek_warden",
    "char_neighbor_consensus",
    "char_neighbor_evidence",
    "char_neighbor_hearsay",
    "char_neighbor_storyteller",
]
CHAR_WALK = [f"{c}_walk" for c in CHAR_STATIC]
PLAYER_ACTIONS = [
    "char_player_action_hoe",
    "char_player_action_watering_can",
    "char_player_action_harvest_glove",
]


def png_ihdr(path: Path) -> tuple[int, int, int]:
    """Return (width, height, color_type) parsed from the PNG IHDR chunk."""
    with path.open("rb") as handle:
        signature = handle.read(8)
        if signature != b"\x89PNG\r\n\x1a\n":
            raise ValueError("not a PNG file")
        (length,) = struct.unpack(">I", handle.read(4))
        chunk_type = handle.read(4)
        if chunk_type != b"IHDR":
            raise ValueError("first chunk is not IHDR")
        ihdr = handle.read(length)
        if len(ihdr) < 10:
            raise ValueError("truncated IHDR")
        width, height, _bit_depth, color_type = struct.unpack(">IIBB", ihdr[:10])
    return width, height, color_type


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_authoritative(character_overrides_path: Path = CHARACTER_OVERRIDES
                       ) -> tuple[dict[str, dict], set[str], set[str], set[str], list[dict], set[str]]:
    """Return (approved items keyed by filename, N-003 override filenames,
    N-015 character override filenames, DEC-033 addition filenames, raw
    character override entries, known-before-character filenames).

    Resolution order is explicit: base manifest, then N-003 approved overrides
    replace base entries with the same filename, then N-015 character overrides
    replace those, then DEC-033 additions append new filenames.
    """
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    runtime = [i for i in manifest["assets"] if i["scope"] == "runtime"]
    approved: dict[str, dict] = {i["file"]: i for i in runtime}

    overrides_doc = json.loads(OVERRIDES.read_text(encoding="utf-8"))
    overrides: dict[str, dict] = {i["file"]: i for i in overrides_doc["assets"]}
    for name, item in overrides.items():
        if name in approved:
            approved[name] = item

    known_before_character = set(approved)
    character_doc = json.loads(character_overrides_path.read_text(encoding="utf-8"))
    character_entries: list[dict] = character_doc.get("assets", [])
    character_overrides: dict[str, dict] = {}
    for item in character_entries:
        if isinstance(item, dict) and isinstance(item.get("file"), str):
            character_overrides[item["file"]] = item
    for name, item in character_overrides.items():
        if name in known_before_character:
            approved[name] = item

    additions_doc = json.loads(ADDITIONS.read_text(encoding="utf-8"))
    additions: dict[str, dict] = {i["file"]: i for i in additions_doc["assets"]}
    for name, item in additions.items():
        approved[name] = item

    return (approved, set(overrides), set(character_overrides), set(additions),
            character_entries, known_before_character)


def run_audit() -> dict:
    """Run the authoritative audit script to obtain `resolved_referenced`.

    `scripts/audit-runtime-art-integration.py` is the single authoritative
    source for the resolved-consumer set. This function must NOT synthesize a
    result when the audit fails: any failure (subprocess cannot start, non-zero
    return code, non-JSON stdout, or `overall_pass != true`) raises RuntimeError
    so that main()'s top-level guard emits a parseable FAIL report and exits
    non-zero, instead of masking the audit failure with a fabricated success.
    """
    try:
        proc = subprocess.run(
            [sys.executable, str(AUDIT_SCRIPT)],
            capture_output=True,
            text=True,
            cwd=str(ROOT),
        )
    except OSError as exc:
        raise RuntimeError(f"authoritative audit could not be launched: {exc}") from exc

    if proc.returncode != 0:
        detail = proc.stderr.strip() or "no stderr"
        raise RuntimeError(f"authoritative audit exited {proc.returncode}: {detail}")

    try:
        report = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"authoritative audit stdout is not valid JSON: {exc}") from exc

    if report.get("overall_pass") is not True:
        raise RuntimeError("authoritative audit overall_pass is not true")

    return report


# --- Authoritative per-file derivations ---

def category_of(filename: str) -> str:
    return filename.split("_", 1)[0]


def provenance_of(filename: str, overrides: set[str], additions: set[str],
                  character_overrides: set[str]) -> str:
    """Derive provenance from the authoritative sets, never from filename
    prefix guessing. Resolution order: DEC-033 addition, then N-015 character
    override, then N-003 override, then N-006 base."""
    if filename in additions:
        return "dec033_approved_addition"
    if filename in character_overrides:
        return "n015_portrait_derived_override"
    if filename in overrides:
        return "n003_approved_override"
    return "n006_base"


def validate_character_override_manifest(entries: list[dict], approved: dict[str, dict],
                                         known_before_character: set[str],
                                         errors: list[str]) -> None:
    """Validate the N-015 character override manifest itself.

    Requirements (deliverable B.5):
      - exactly 19 files, no duplicates;
      - every file belongs to the final 132-item formal set (i.e. it was known
        before the character override applied — no out-of-band additions);
      - every file has category `char`;
      - 8 idle 32x48, 8 walk 128x192, 3 player action 128x192;
      - per-entry structural fields (file/width/height/sha256/scope) are valid;
      - SHA-256 and IHDR dimensions against the disk Assets are checked by
        compute_hashes(), because the resolved approved item for each of the 19
        files is exactly the override manifest entry.
    """
    raw_files: list[str] = []
    for idx, entry in enumerate(entries):
        where = f"character override assets[{idx}]"
        if not isinstance(entry, dict):
            errors.append(f"{where}: not an object")
            continue
        filename = entry.get("file")
        if not isinstance(filename, str) or not filename.endswith(".png"):
            errors.append(f"{where}: invalid or missing file {filename!r}")
            continue
        raw_files.append(filename)
        if not isinstance(entry.get("width"), int) or not isinstance(entry.get("height"), int):
            errors.append(f"{filename}: width/height must be ints")
        sha = entry.get("sha256")
        if not isinstance(sha, str) or len(sha) != 64 or any(c not in "0123456789abcdef" for c in sha):
            errors.append(f"{filename}: invalid sha256 {sha!r}")
        if entry.get("scope") != "runtime":
            errors.append(f"{filename}: scope must be 'runtime', got {entry.get('scope')!r}")

    dupes = sorted({f for f, count in Counter(raw_files).items() if count > 1})
    if dupes:
        errors.append(f"character override manifest has duplicate filename(s): {dupes}")

    files = set(raw_files)
    if len(files) != 19:
        errors.append(f"character override manifest declares {len(files)} files, expected 19")

    unknown = sorted(files - known_before_character)
    if unknown:
        errors.append(f"character override files outside the formal set: {unknown}")

    for filename in sorted(files):
        if category_of(filename) != "char":
            errors.append(f"{filename}: character override category is "
                          f"{category_of(filename)!r}, expected 'char'")

    idle = {f for f in files if f in {f"{c}.png" for c in CHAR_STATIC}}
    walk = {f for f in files if f in {f"{c}_walk.png" for c in CHAR_STATIC}}
    actions = {f for f in files if f in {f"{a}.png" for a in PLAYER_ACTIONS}}
    unclassified = sorted(files - idle - walk - actions)
    if unclassified:
        errors.append(f"character override files not in the idle/walk/action contract: {unclassified}")

    if len(idle) != 8:
        errors.append(f"expected 8 idle character overrides, got {len(idle)}")
    if len(walk) != 8:
        errors.append(f"expected 8 walk character overrides, got {len(walk)}")
    if len(actions) != 3:
        errors.append(f"expected 3 player action character overrides, got {len(actions)}")

    for filename in sorted(files):
        item = approved.get(filename)
        if item is None:
            continue  # already reported as unknown
        if filename in idle and (item.get("width"), item.get("height")) != (32, 48):
            errors.append(f"{filename}: idle override must be 32x48, "
                          f"got {(item.get('width'), item.get('height'))}")
        if filename in (walk | actions) and (item.get("width"), item.get("height")) != (128, 192):
            errors.append(f"{filename}: walk/action override must be 128x192, "
                          f"got {(item.get('width'), item.get('height'))}")
    return errors


def planned_consumer_for(filename: str) -> str:
    stem = filename[:-4]
    cat = category_of(filename)
    if cat == "building":
        return BUILDING_CONSUMER
    if cat == "char":
        if stem in CHAR_WALK:
            return CHAR_WALK_CONSUMER
        if stem in PLAYER_ACTIONS:
            return PLAYER_ACTION_CONSUMER
        return CHAR_STATIC_CONSUMER
    if cat == "crop":
        return CROP_STAGE_CONSUMER if "_stage_" in stem else CROP_ITEM_CONSUMER
    if cat == "tile":
        if stem in ("tile_grass", "tile_grass_a", "tile_grass_b", "tile_grass_c"):
            return GRASS_CONSUMER
        if stem in ("tile_tilled", "tile_tilled_watered"):
            return TILLED_CONSUMER
        if stem.startswith("tile_canal"):
            return CANAL_TILE_CONSUMER
        if stem.startswith("tile_water"):
            return WATER_CONSUMER
        if stem == "tile_stone_path":
            return STONE_PATH_CONSUMER
        return WATER_CONSUMER
    if cat == "prop":
        return PROP_CONSUMER
    if cat == "gather":
        return GATHER_CONSUMER
    if cat == "tool":
        return TOOL_CONSUMER
    if cat == "fx":
        if stem.startswith("fx_target"):
            return FX_TARGET_CONSUMER
        if stem.startswith("fx_water_splash"):
            return FX_SPLASH_CONSUMER
        if stem.startswith("fx_harvest"):
            return FX_HARVEST_CONSUMER
        if stem.startswith("fx_canal_flow"):
            return FX_CANAL_CONSUMER
        return FX_TARGET_CONSUMER
    if cat == "ui":
        if stem in ("ui_currency", "ui_stamina", "ui_time", "ui_weather"):
            return UI_STATUS_CONSUMER
        if stem == "ui_interact_badge":
            return UI_BADGE_CONSUMER
        return UI_SLOT_CONSUMER
    raise ValueError(f"unmapped file: {filename}")


def trigger_state_for(filename: str) -> str:
    stem = filename[:-4]
    cat = category_of(filename)
    if cat == "building":
        return "building present on map; layer composited by BuildingVisualPresenter"
    if cat == "char":
        if stem in CHAR_WALK:
            return "character moving (4 directions x 4 frames)"
        if stem in PLAYER_ACTIONS:
            return "player performing the matching farm action, then return to idle"
        return "character idle / safe fallback"
    if cat == "crop":
        if "_stage_" in stem:
            return "crop growth stage 0..3 mapped from domain growth state"
        return "inventory/shipping/recipe/seed summary icon"
    if cat == "tile":
        if stem.startswith("tile_grass"):
            return "deterministic grass variant by mapID/x/y hash"
        if stem.startswith("tile_tilled"):
            return "tilled dry / tilled watered cell state"
        if stem.startswith("tile_canal"):
            return "canal facing/connection direction"
        if stem.startswith("tile_water"):
            return "water adjacency mask (edge/corner) or 4-frame loop"
        if stem == "tile_stone_path":
            return "explicit path cell in map visual data"
        return "water adjacency / loop"
    if cat == "prop":
        return "placed object kind / facing"
    if cat == "gather":
        return "gatherable present and available"
    if cat == "tool":
        return "selected tool in compact HUD toolbelt"
    if cat == "fx":
        if stem.startswith("fx_target"):
            return "target cell valid/invalid two-frame feedback"
        if stem.startswith("fx_water_splash"):
            return "after successful watering command (one-shot)"
        if stem.startswith("fx_harvest"):
            return "after successful harvest command (one-shot)"
        if stem.startswith("fx_canal_flow"):
            return "canal state allows flow (loop)"
        return "effect frame"
    if cat == "ui":
        if stem in ("ui_currency", "ui_stamina", "ui_time", "ui_weather"):
            return "compact HUD status field"
        if stem == "ui_interact_badge":
            return "interaction prompt visible"
        return "toolbelt slot / selected slot"
    raise ValueError(f"unmapped trigger for {filename}")


def fallback_for(filename: str) -> str:
    cat = category_of(filename)
    if cat == "building":
        return FALLBACK_BUILDING
    if cat == "char":
        return FALLBACK_CHAR
    if cat == "crop":
        return FALLBACK_CROP
    if cat == "tile":
        return FALLBACK_TILE
    if cat == "prop":
        return FALLBACK_PROP
    if cat == "gather":
        return FALLBACK_PROP
    if cat == "tool":
        return FALLBACK_TOOL
    if cat == "fx":
        return FALLBACK_FX
    if cat == "ui":
        return FALLBACK_UI
    raise ValueError(f"unmapped fallback for {filename}")


def batch_for(filename: str) -> str:
    stem = filename[:-4]
    cat = category_of(filename)
    if cat == "building":
        return "B4"
    if cat == "char":
        if stem in CHAR_WALK:
            return "B2"
        if stem in PLAYER_ACTIONS:
            return "B3"
        return "B1"
    if cat == "crop":
        return "B1"
    if cat == "tile":
        if stem.startswith("tile_grass") or stem.startswith("tile_tilled"):
            return "B1"
        if stem == "tile_water_edge":
            return "B1"
        return "B2"
    if cat == "prop":
        return "B1"
    if cat == "gather":
        return "B3"
    if cat == "tool":
        return "B1"
    if cat == "fx":
        return "B3"
    if cat == "ui":
        return "B1" if stem in ("ui_currency", "ui_stamina", "ui_time", "ui_weather") else "B5"
    raise ValueError(f"unmapped batch for {filename}")


def build_matrix(approved: dict[str, dict], overrides: set[str], additions: set[str],
                 character_overrides: set[str], resolved: set[str]) -> dict:
    """Build the authoritative matrix from first principles."""
    assets = []
    for filename in sorted(approved):
        item = approved[filename]
        cat = category_of(filename)
        prov = provenance_of(filename, overrides, additions, character_overrides)
        if filename in resolved:
            status = "integrated"
            blocker = None
        else:
            status = "planned"
            blocker = None
        assets.append({
            "asset_key": f"{cat}:{filename[:-4]}",
            "filename": filename,
            "category": cat,
            "native_width": item["width"],
            "native_height": item["height"],
            "provenance": prov,
            "planned_consumer": planned_consumer_for(filename),
            "trigger_state": trigger_state_for(filename),
            "fallback": fallback_for(filename),
            "batch": batch_for(filename),
            "runtime_status": status,
            "blocker": blocker,
        })
    return {
        "schema_version": 1,
        "task": "N-015",
        "decision": "DEC-035",
        "generated_from": list(EXPECTED_GENERATED_FROM),
        "expected_asset_count": 132,
        "assets": assets,
    }


def validate(matrix: dict, approved: dict[str, dict], overrides: set[str],
             additions: set[str], character_overrides: set[str],
             resolved: set[str]) -> list[str]:
    errors: list[str] = []

    if matrix.get("schema_version") != 1:
        errors.append(f"schema_version must be 1, got {matrix.get('schema_version')!r}")
    if matrix.get("task") != "N-015":
        errors.append(f"task must be N-015, got {matrix.get('task')!r}")
    if matrix.get("decision") != "DEC-035":
        errors.append(f"decision must be DEC-035, got {matrix.get('decision')!r}")
    if matrix.get("expected_asset_count") != 132:
        errors.append(f"expected_asset_count must be 132, got {matrix.get('expected_asset_count')!r}")
    if matrix.get("generated_from") != EXPECTED_GENERATED_FROM:
        errors.append(f"generated_from must be exactly {EXPECTED_GENERATED_FROM}, "
                      f"got {matrix.get('generated_from')!r}")

    if len(resolved) != 132:
        errors.append(f"resolved consumer set has {len(resolved)} files, expected 132")

    assets = matrix.get("assets")
    if not isinstance(assets, list):
        errors.append("assets must be a list")
        return errors

    approved_files = set(approved)
    disk_files = {p.name for p in ASSETS_DIR.glob("*.png")}
    matrix_files = {a.get("filename") for a in assets if isinstance(a, dict)}

    if len(approved_files) != 132:
        errors.append(f"approved set has {len(approved_files)} files, expected 132")
    if len(disk_files) != 132:
        errors.append(f"disk Assets has {len(disk_files)} PNG files, expected 132")
    if len(matrix_files) != 132:
        errors.append(f"matrix has {len(matrix_files)} filenames, expected 132")

    if approved_files != disk_files:
        errors.append("approved != disk: "
                      f"only-approved={sorted(approved_files - disk_files)}, "
                      f"only-disk={sorted(disk_files - approved_files)}")
    if disk_files != matrix_files:
        errors.append("disk != matrix: "
                      f"only-disk={sorted(disk_files - matrix_files)}, "
                      f"only-matrix={sorted(matrix_files - disk_files)}")

    seen_keys: set[str] = set()
    seen_files: set[str] = set()
    integrated: set[str] = set()
    b4_buildings: list[dict] = []

    for idx, asset in enumerate(assets):
        where = f"assets[{idx}]"
        if not isinstance(asset, dict):
            errors.append(f"{where}: not an object")
            continue
        filename = asset.get("filename")
        key = asset.get("asset_key")
        category = asset.get("category")
        provenance = asset.get("provenance")
        status = asset.get("runtime_status")
        batch = asset.get("batch")
        blocker = asset.get("blocker")

        for field in ("asset_key", "filename", "category", "native_width", "native_height",
                      "provenance", "planned_consumer", "trigger_state", "fallback",
                      "batch", "runtime_status"):
            if asset.get(field) in (None, ""):
                errors.append(f"{where}: missing or empty field {field!r}")

        if not isinstance(asset.get("native_width"), int) or not isinstance(asset.get("native_height"), int):
            errors.append(f"{where}: native_width/native_height must be ints")
        if "blocker" not in asset:
            errors.append(f"{where}: missing 'blocker' field")

        if key is not None:
            if key in seen_keys:
                errors.append(f"{where}: duplicate asset_key {key!r}")
            seen_keys.add(key)
        if filename is not None:
            if filename in seen_files:
                errors.append(f"{where}: duplicate filename {filename!r}")
            seen_files.add(filename)

        # --- Field-by-field authoritative comparison ---
        if isinstance(filename, str) and filename in approved:
            item = approved[filename]
            expected_prov = provenance_of(filename, overrides, additions, character_overrides)
            expected_category = category_of(filename)
            expected_consumer = planned_consumer_for(filename)
            expected_trigger = trigger_state_for(filename)
            expected_fallback = fallback_for(filename)
            expected_batch = batch_for(filename)

            if provenance != expected_prov:
                errors.append(f"{filename}: provenance {provenance!r} != expected {expected_prov!r}")
            if category != expected_category:
                errors.append(f"{filename}: category {category!r} != expected {expected_category!r}")
            if asset.get("planned_consumer") != expected_consumer:
                errors.append(f"{filename}: planned_consumer {asset.get('planned_consumer')!r} "
                              f"!= expected {expected_consumer!r}")
            if asset.get("trigger_state") != expected_trigger:
                errors.append(f"{filename}: trigger_state {asset.get('trigger_state')!r} "
                              f"!= expected {expected_trigger!r}")
            if asset.get("fallback") != expected_fallback:
                errors.append(f"{filename}: fallback {asset.get('fallback')!r} "
                              f"!= expected {expected_fallback!r}")
            if batch != expected_batch:
                errors.append(f"{filename}: batch {batch!r} != expected {expected_batch!r}")
            if asset.get("native_width") != item["width"] or asset.get("native_height") != item["height"]:
                errors.append(f"{filename}: native size {(asset.get('native_width'), asset.get('native_height'))} "
                              f"!= approved {(item['width'], item['height'])}")
            if asset.get("asset_key") != f"{expected_category}:{filename[:-4]}":
                errors.append(f"{filename}: asset_key {asset.get('asset_key')!r} "
                              f"!= expected {expected_category + ':' + filename[:-4]!r}")

        if category not in VALID_CATEGORIES:
            errors.append(f"{where}: invalid category {category!r}")
        if provenance not in VALID_PROVENANCE:
            errors.append(f"{where}: invalid provenance {provenance!r}")
        if batch not in VALID_BATCH:
            errors.append(f"{where}: invalid batch {batch!r}")
        if status not in VALID_STATUS:
            errors.append(f"{where}: invalid runtime_status {status!r}")

        if status == "integrated" and filename:
            integrated.add(filename)
        if category == "building":
            b4_buildings.append(asset)
        if status == "blocked":
            if blocker in (None, ""):
                errors.append(f"{where}: blocked record must have non-empty blocker")
        if status == "planned" and blocker == "":
            errors.append(f"{where}: planned record must not have empty-string blocker")

    # --- DEC-035 Phase C: all 30 B4 buildings are integrated, batch B4 ---
    if len(b4_buildings) != 30:
        errors.append(f"expected 30 building records, got {len(b4_buildings)}")
    for asset in b4_buildings:
        if asset.get("batch") != "B4":
            errors.append(f"building {asset.get('filename')}: batch must be B4, got {asset.get('batch')!r}")
        if asset.get("runtime_status") != "integrated" or asset.get("blocker") is not None:
            errors.append(f"building {asset.get('filename')}: DEC-035 requires integrated with null blocker")

    # --- integrated == authoritative resolved_referenced ---
    if integrated != resolved:
        errors.append("integrated != resolved_referenced: "
                      f"only-integrated={sorted(integrated - resolved)}, "
                      f"only-resolved={sorted(resolved - integrated)}")

    # --- every record is integrated (DEC-035 Phase C complete) ---
    non_integrated = sorted(
        a.get("filename") for a in assets
        if isinstance(a, dict) and a.get("runtime_status") != "integrated"
    )
    if non_integrated:
        errors.append(f"{len(non_integrated)} record(s) not integrated: {non_integrated}")

    # --- provenance summary counts must be exactly 104 / 8 / 19 / 1 ---
    provenance_counts = Counter(a.get("provenance") for a in assets if isinstance(a, dict))
    for prov, expected in EXPECTED_PROVENANCE_COUNTS.items():
        if provenance_counts.get(prov) != expected:
            errors.append(f"provenance {prov!r} count is {provenance_counts.get(prov)}, "
                          f"expected {expected}")
    for prov in provenance_counts:
        if prov not in EXPECTED_PROVENANCE_COUNTS:
            errors.append(f"unexpected provenance key in matrix: {prov!r}")

    # --- the n015_portrait_derived_override set must be exactly the 19 character overrides ---
    n015_matrix_files = {
        a.get("filename") for a in assets
        if isinstance(a, dict) and a.get("provenance") == "n015_portrait_derived_override"
    }
    if n015_matrix_files != set(character_overrides):
        errors.append("n015_portrait_derived_override set != character override manifest: "
                      f"only-matrix={sorted(n015_matrix_files - set(character_overrides))}, "
                      f"only-manifest={sorted(set(character_overrides) - n015_matrix_files)}")

    return errors


def compute_hashes(approved: dict[str, dict], errors: list[str]) -> dict[str, str]:
    hashes: dict[str, str] = {}
    for filename in sorted(approved):
        path = ASSETS_DIR / filename
        item = approved[filename]
        try:
            width, height, color_type = png_ihdr(path)
        except (ValueError, OSError) as exc:
            errors.append(f"{filename}: PNG parse failed: {exc}")
            continue
        if (width, height) != (item["width"], item["height"]):
            errors.append(f"{filename}: dimension mismatch expected {(item['width'], item['height'])} "
                          f"got {(width, height)}")
        if color_type != 6:
            errors.append(f"{filename}: expected RGBA (color_type 6), got {color_type}")
        try:
            digest = sha256(path)
        except OSError as exc:
            errors.append(f"{filename}: sha256 failed: {exc}")
            continue
        hashes[filename] = digest
        if digest != item["sha256"]:
            errors.append(f"{filename}: sha256 mismatch")
    return hashes


def run(args) -> int:
    (approved, overrides, character_overrides, additions, character_entries,
     known_before_character) = load_authoritative(args.character_overrides)
    if len(approved) != 132:
        print(f"expected 132 approved assets, got {len(approved)}", file=sys.stderr)
        return 1

    audit = run_audit()
    resolved = set(audit["swift_literal_consumption"]["resolved_referenced"])

    if args.refresh_matrix:
        matrix = build_matrix(approved, overrides, additions, character_overrides, resolved)
        args.matrix.write_text(json.dumps(matrix, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        try:
            display = args.matrix.relative_to(ROOT)
        except ValueError:
            display = args.matrix
        print(f"refreshed {display}", file=sys.stderr)
    else:
        if not args.matrix.exists():
            print(f"matrix file missing: {args.matrix}", file=sys.stderr)
            return 1
        try:
            matrix = json.loads(args.matrix.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            print(f"matrix is not valid JSON: {exc}", file=sys.stderr)
            return 1

    errors = validate_character_override_manifest(
        character_entries, approved, known_before_character, []
    )
    errors = validate(matrix, approved, overrides, additions, character_overrides, resolved) + errors
    hashes = compute_hashes(approved, errors)

    summary = build_summary(matrix, resolved)

    return finish(errors, args, summary, hashes)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write-evidence", type=Path, default=None)
    parser.add_argument("--matrix", type=Path, default=MATRIX)
    parser.add_argument(
        "--character-overrides",
        type=Path,
        default=CHARACTER_OVERRIDES,
        help="Path to the N-015 character override manifest. Defaults to the "
             "authoritative repository path; the parameter exists only for "
             "read-only validation and negative tests on isolated copies.",
    )
    parser.add_argument(
        "--refresh-matrix",
        action="store_true",
        help="Regenerate the matrix deterministically from authoritative sources, then validate it.",
    )
    args = parser.parse_args()

    try:
        return run(args)
    except Exception as exc:  # noqa: BLE001 - top-level safety net
        # Never let a traceback replace the validation report. Emit a parseable
        # FAIL JSON to stdout and exit non-zero.
        report = {
            "result": "FAIL",
            "failures": 1,
            "errors": [f"validator crashed: {type(exc).__name__}: {exc}"],
            "summary": {},
        }
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 1


def build_summary(matrix: dict, resolved: set[str]) -> dict:
    """Build a summary that never raises on a malformed matrix.

    Uses .get() with a safe fallback so that a deleted required field (which is
    already reported as an error by validate()) cannot crash the summary builder
    with a KeyError and leave stdout empty.
    """
    assets = matrix.get("assets")
    if not isinstance(assets, list):
        return {
            "asset_count": 0,
            "provenance": {},
            "category_counts": {},
            "runtime_status": {},
            "resolved_referenced_count": len(resolved),
        }
    provenance = Counter()
    category_counts = Counter()
    runtime_status = Counter()
    for a in assets:
        if isinstance(a, dict):
            provenance[a.get("provenance", "<missing>")] += 1
            category_counts[a.get("category", "<missing>")] += 1
            runtime_status[a.get("runtime_status", "<missing>")] += 1
    return {
        "asset_count": len(assets),
        "provenance": dict(sorted(provenance.items())),
        "category_counts": dict(sorted(category_counts.items())),
        "runtime_status": dict(sorted(runtime_status.items())),
        "resolved_referenced_count": len(resolved),
    }


def finish(errors: list[str], args, summary: dict, hashes: dict | None = None) -> int:
    report = {
        "result": "PASS" if not errors else "FAIL",
        "failures": len(errors),
        "errors": errors,
        "summary": summary,
    }
    if args.write_evidence is not None:
        out = args.write_evidence
        out.mkdir(parents=True, exist_ok=True)
        (out / "validation-report.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        (out / "matrix-summary.json").write_text(
            json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        if hashes is not None:
            lines = [f"{digest}  {filename}" for filename, digest in sorted(hashes.items())]
            (out / "SHA256SUMS.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
