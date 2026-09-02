#!/usr/bin/env python3
"""Independent authoritative validator for docs/game/n-015-map-layout-contract.json.

Work package: N-015-VSCODE-MAP-01 (VSCode stage B foundation gate), r2.

This script is the single authoritative source for validating the frozen Codex
stage-A map re-layout machine contract. It is read-only: it never rewrites the
contract, the spec, the matrix, or any production file.

Authoritative inputs (all read-only):
  - docs/game/n-015-map-layout-contract.json   (frozen machine contract)
  - docs/game/n-015-map-rearrangement-spec.md  (frozen human spec; SHA-256 recorded)
  - docs/game/n-015-runtime-consumer-matrix.json (B4 filename/native-size/provenance authority)

The validator does NOT copy another script's audit algorithm and does NOT run
scripts/audit-runtime-art-integration.py. It derives every count and every
expected semantic from the frozen contract + spec + matrix.

Exit code: 0 on PASS, 1 on FAIL. Both paths emit a single parseable JSON object
on stdout. No traceback is ever emitted; unexpected exceptions are caught and
converted into a parseable FAIL JSON.

Usage:
  python3 scripts/validate-n015-map-layout-contract.py
  python3 scripts/validate-n015-map-layout-contract.py --contract-only
  python3 scripts/validate-n015-map-layout-contract.py --write-evidence <dir>
  python3 scripts/validate-n015-map-layout-contract.py --contract <path>   # negative-test isolation only
  python3 scripts/validate-n015-map-layout-contract.py --coverage-audit <dir>
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "docs/game/n-015-map-layout-contract.json"
SPEC = ROOT / "docs/game/n-015-map-rearrangement-spec.md"
MATRIX = ROOT / "docs/game/n-015-runtime-consumer-matrix.json"

TASK = "N-015-VSCODE-MAP-01"
DECISION_ID = "DEC-035"
SCHEMA_VERSION = 1

# Fixed building footprints (frozen in DEC-035 and spec section 5.2).
EXPECTED_BUILDINGS = {
    "brookseed.landmark.farm_house": (5, 4),
    "brookseed.landmark.farm_sluice": (5, 4),
    "brookseed.landmark.market_wharf": (5, 2),
    "brookseed.landmark.market_seed_shed": (3, 2),
    "brookseed.landmark.market_warden_post": (3, 2),
}
# Building -> expected native canvas size (width, height), from spec section 6.
BUILDING_NATIVE_SIZE = {
    "brookseed.landmark.farm_house": (144, 144),
    "brookseed.landmark.farm_sluice": (192, 168),
    "brookseed.landmark.market_wharf": (144, 96),
    "brookseed.landmark.market_seed_shed": (96, 96),
    "brookseed.landmark.market_warden_post": (96, 96),
}
# Building -> which map it belongs to (frozen).
BUILDING_MAP = {
    "brookseed.landmark.farm_house": "brookseed.map.farm_homestead",
    "brookseed.landmark.farm_sluice": "brookseed.map.farm_homestead",
    "brookseed.landmark.market_wharf": "brookseed.map.creek_market",
    "brookseed.landmark.market_seed_shed": "brookseed.map.creek_market",
    "brookseed.landmark.market_warden_post": "brookseed.map.creek_market",
}
EXPECTED_MAPS = [
    "brookseed.map.creek_market",
    "brookseed.map.farm_homestead",
]
# Frozen order of the maps array in the contract (deterministic_ordering.named_records).
MAP_ARRAY_ORDER_FROZEN = [
    "brookseed.map.farm_homestead",
    "brookseed.map.creek_market",
]
LAYER_ORDER = ["base", "structure", "roof", "detail", "interaction", "state_fx"]

# Frozen NPC -> map + position + approach cells (from spec sections 3 and 4).
NPC_FROZEN = {
    "brookseed.npc.water_apprentice": {"map": "brookseed.map.farm_homestead", "position": (8, 6), "approach": [(7, 6), (8, 5), (8, 7), (9, 6)]},
    "brookseed.npc.seed_steward": {"map": "brookseed.map.creek_market", "position": (4, 9), "approach": [(4, 8), (4, 10), (5, 9)]},
    "brookseed.npc.creek_warden": {"map": "brookseed.map.creek_market", "position": (13, 9), "approach": [(12, 9), (13, 8), (13, 10)]},
    "brookseed.npc.neighbor_hearsay": {"map": "brookseed.map.creek_market", "position": (5, 7), "approach": [(4, 7), (5, 6), (5, 8)]},
    "brookseed.npc.neighbor_storyteller": {"map": "brookseed.map.creek_market", "position": (7, 6), "approach": [(6, 6), (7, 5), (7, 7)]},
    "brookseed.npc.neighbor_evidence": {"map": "brookseed.map.creek_market", "position": (11, 6), "approach": [(10, 6), (11, 5), (11, 7), (12, 6)]},
    "brookseed.npc.neighbor_consensus": {"map": "brookseed.map.creek_market", "position": (7, 11), "approach": [(6, 11), (7, 10), (7, 12), (8, 11)]},
}
# water_apprentice also appears on the market map (same stable ID, different
# position/approach). Map-specific frozen records are keyed by (map, id).
NPC_MAP_OVERRIDES = {
    ("brookseed.map.creek_market", "brookseed.npc.water_apprentice"): {
        "position": (3, 6), "approach": [(2, 6), (3, 5), (3, 7), (4, 6)],
    },
}

# Frozen spawn -> map + position (from spec).
SPAWN_FROZEN = {
    "brookseed.spawn.farm_wake": ("brookseed.map.farm_homestead", (7, 6)),
    "brookseed.spawn.farm_from_market": ("brookseed.map.farm_homestead", (7, 1)),
    "brookseed.spawn.market_from_farm": ("brookseed.map.creek_market", (9, 11)),
}

# Frozen exit -> map + cell + destination (from spec).
EXIT_FROZEN = {
    "brookseed.exit.farm_to_market": {
        "map": "brookseed.map.farm_homestead",
        "cell": (7, 0),
        "destination_map_id": "brookseed.map.creek_market",
        "destination_spawn_id": "brookseed.spawn.market_from_farm",
    },
    "brookseed.exit.market_to_farm": {
        "map": "brookseed.map.creek_market",
        "cell": (9, 12),
        "destination_map_id": "brookseed.map.farm_homestead",
        "destination_spawn_id": "brookseed.spawn.farm_from_market",
    },
}

# Frozen gather targets -> map + cell (from spec).
GATHER_FROZEN = {
    "brookseed.gather.farm_wood_cache": ("brookseed.map.farm_homestead", (1, 6)),
    "brookseed.gather.farm_reed_cache": ("brookseed.map.farm_homestead", (11, 1)),
    "brookseed.gather.farm_moss_cache": ("brookseed.map.farm_homestead", (12, 6)),
    "brookseed.gather.market_wood_cache": ("brookseed.map.creek_market", (6, 4)),
    "brookseed.gather.market_reed_cache": ("brookseed.map.creek_market", (12, 4)),
    "brookseed.gather.market_moss_cache": ("brookseed.map.creek_market", (15, 4)),
    "brookseed.gather.restored_brook_cache": ("brookseed.map.creek_market", (16, 3)),
}

# Frozen quest targets -> map + cell (from spec).
QUEST_FROZEN = {
    ("brookseed.map.farm_homestead", "brookseed.landmark.farm_beds"): (5, 3),
    ("brookseed.map.farm_homestead", "brookseed.npc.water_apprentice"): (8, 6),
    ("brookseed.map.farm_homestead", "brookseed.interaction.farm_sluice.gate"): (12, 7),
    ("brookseed.map.creek_market", "brookseed.npc.creek_warden"): (13, 9),
    ("brookseed.map.creek_market", "brookseed.landmark.market_blocked_mouth"): (16, 2),
    ("brookseed.map.creek_market", "brookseed.npc.water_apprentice"): (3, 6),
}

# R6: quest_targets[].purpose is frozen exactly per (map_id, target_id). The
# purpose text is part of the machine contract, not decorative prose; tampering
# it must FAIL with the exact field path.
QUEST_PURPOSE_FROZEN = {
    ("brookseed.map.farm_homestead", "brookseed.landmark.farm_beds"): "tutorial farming",
    ("brookseed.map.farm_homestead", "brookseed.npc.water_apprentice"): "tutorial talk and canal delivery",
    ("brookseed.map.farm_homestead", "brookseed.interaction.farm_sluice.gate"): "sluice interaction",
    ("brookseed.map.creek_market", "brookseed.npc.creek_warden"): "optional notice objective",
    ("brookseed.map.creek_market", "brookseed.landmark.market_blocked_mouth"): "restoration state landmark",
    ("brookseed.map.creek_market", "brookseed.npc.water_apprentice"): "mainline dialogue",
}

# Frozen landmark -> map + anchor (from spec).
LANDMARK_FROZEN = {
    "brookseed.landmark.farm_house": ("brookseed.map.farm_homestead", (3, 8)),
    "brookseed.landmark.farm_beds": ("brookseed.map.farm_homestead", (5, 3)),
    "brookseed.landmark.farm_steps": ("brookseed.map.farm_homestead", (7, 0)),
    "brookseed.landmark.farm_sluice": ("brookseed.map.farm_homestead", (12, 8)),
    "brookseed.landmark.market_blocked_mouth": ("brookseed.map.creek_market", (16, 2)),
    "brookseed.landmark.market_seed_shed": ("brookseed.map.creek_market", (1, 9)),
    "brookseed.landmark.market_steps": ("brookseed.map.creek_market", (9, 12)),
    "brookseed.landmark.market_table": ("brookseed.map.creek_market", (6, 7)),
    "brookseed.landmark.market_warden_post": ("brookseed.map.creek_market", (16, 9)),
    "brookseed.landmark.market_wharf": ("brookseed.map.creek_market", (3, 4)),
}

# Frozen map dimensions (from spec).
MAP_DIMENSIONS_FROZEN = {
    "brookseed.map.farm_homestead": (16, 15),
    "brookseed.map.creek_market": (18, 14),
}

# Frozen legacy bounds (from spec section 9).
LEGACY_BOUNDS_FROZEN = {
    "brookseed.map.farm_homestead": (10, 6),
    "brookseed.map.creek_market": (10, 8),
}

# Frozen world safe playable bounds (from contract world_safe_zone).
WORLD_PLAYABLE_BOUNDS_FROZEN = {
    "brookseed.map.farm_homestead": [0, 0, 15, 11],
    "brookseed.map.creek_market": [1, 3, 16, 12],
}

# Frozen water cells: map -> {cell: semantic} (from contract; cross-checked against spec).
WATER_FROZEN = {
    "brookseed.map.farm_homestead": {
        (12, 0): "corner_sw", (12, 1): "corner_nw",
        (13, 0): "edge_s", (13, 1): "edge_n",
        (14, 0): "corner_se", (14, 1): "corner_ne",
    },
    "brookseed.map.creek_market": {
        (0, 0): "corner_sw", (0, 1): "edge_w", (0, 2): "corner_nw",
        (17, 0): "corner_se", (17, 1): "edge_e", (17, 2): "corner_ne",
    },
}

# Full frozen market stream water cells (18x3 at x=0..17, y=0..2).
_MARKET_STREAM_WATER = {(x, 0): "edge_s" for x in range(1, 17)}
_MARKET_STREAM_WATER.update({(x, 2): "edge_n" for x in range(1, 17)})
_MARKET_STREAM_WATER.update({(x, 1): "base" for x in range(1, 17)})
_MARKET_STREAM_WATER.update({
    (0, 0): "corner_sw", (0, 1): "edge_w", (0, 2): "corner_nw",
    (17, 0): "corner_se", (17, 1): "edge_e", (17, 2): "corner_ne",
})
WATER_FROZEN["brookseed.map.creek_market"] = _MARKET_STREAM_WATER

# Frozen canal cells: map -> {cell: semantic}.
CANAL_FROZEN = {
    "brookseed.map.farm_homestead": {(13, y): "ns" for y in range(2, 8)},
    "brookseed.map.creek_market": {},
}

# Frozen static obstacles: map -> set of cells.
STATIC_OBSTACLE_FROZEN = {
    "brookseed.map.farm_homestead": set(),
    "brookseed.map.creek_market": {(6, 7)},
}

# ---------------------------------------------------------------------------
# R3-1: complete frozen building records. Each building's footprint origin,
# width/height, collision cells, door, interaction cells, occlusion cells,
# render anchor (cell/normalized/pixel_offset), and state are frozen exactly.
# These are derived from the frozen contract + spec (sections 3, 4, 5.2, 6).
# ---------------------------------------------------------------------------
BUILDING_RECORDS_FROZEN = {
    "brookseed.landmark.farm_house": {
        "footprint": {"origin": [1, 8], "width": 5, "height": 4},
        "collision_cells": [
            [1, 8], [1, 9], [1, 10], [1, 11],
            [2, 8], [2, 9], [2, 10], [2, 11],
            [3, 9], [3, 10], [3, 11],
            [4, 8], [4, 9], [4, 10], [4, 11],
            [5, 8], [5, 9], [5, 10], [5, 11],
        ],
        "door": [3, 8],
        "interaction_cells": [[3, 7]],
        "occlusion_cells": [[1, 8], [2, 8], [3, 8], [4, 8], [5, 8]],
        "render_anchor": {"cell": [3, 8], "normalized": [0.5, 0.0], "pixel_offset": [0, -12]},
        "state": "default",
    },
    "brookseed.landmark.farm_sluice": {
        "footprint": {"origin": [10, 8], "width": 5, "height": 4},
        "collision_cells": [
            [10, 8], [10, 9], [10, 10], [10, 11],
            [11, 8], [11, 9], [11, 10], [11, 11],
            [12, 9], [12, 10], [12, 11],
            [13, 8], [13, 9], [13, 10], [13, 11],
            [14, 8], [14, 9], [14, 10], [14, 11],
        ],
        "door": [12, 8],
        "interaction_cells": [[12, 7]],
        "occlusion_cells": [[10, 8], [11, 8], [12, 8], [13, 8], [14, 8]],
        "render_anchor": {"cell": [12, 8], "normalized": [0.5, 0.0], "pixel_offset": [-12, -12]},
        "state": "default_or_active",
    },
    "brookseed.landmark.market_wharf": {
        "footprint": {"origin": [1, 3], "width": 5, "height": 2},
        "collision_cells": [
            [1, 3], [1, 4], [2, 3], [2, 4], [3, 3],
            [4, 3], [4, 4], [5, 3], [5, 4],
        ],
        "door": [3, 4],
        "interaction_cells": [[3, 5]],
        "occlusion_cells": [[1, 4], [2, 4], [3, 4], [4, 4], [5, 4]],
        "render_anchor": {"cell": [3, 3], "normalized": [0.5, 0.0], "pixel_offset": [0, -12]},
        "state": "default_or_wet",
    },
    "brookseed.landmark.market_seed_shed": {
        "footprint": {"origin": [1, 9], "width": 3, "height": 2},
        "collision_cells": [
            [1, 10], [2, 9], [2, 10], [3, 9], [3, 10],
        ],
        "door": [1, 9],
        "interaction_cells": [[1, 8]],
        "occlusion_cells": [[1, 9], [2, 9], [3, 9]],
        "render_anchor": {"cell": [2, 9], "normalized": [0.5, 0.0], "pixel_offset": [0, -12]},
        "state": "default_or_open",
    },
    "brookseed.landmark.market_warden_post": {
        "footprint": {"origin": [14, 9], "width": 3, "height": 2},
        "collision_cells": [
            [14, 9], [14, 10], [15, 9], [15, 10], [16, 10],
        ],
        "door": [16, 9],
        "interaction_cells": [[16, 8]],
        "occlusion_cells": [[14, 9], [15, 9], [16, 9]],
        "render_anchor": {"cell": [15, 9], "normalized": [0.5, 0.0], "pixel_offset": [0, -12]},
        "state": "default_or_open",
    },
}

# ---------------------------------------------------------------------------
# R3-2: per-(building_id, semantic) exact filename. Each building has exactly
# six layers in fixed order base→structure→roof→detail→interaction→state_fx.
# The exact filename for each (building, semantic) is frozen; a swap between
# two same-size buildings must still fail because the filename is tied to the
# building ID + semantic, not the size.
# ---------------------------------------------------------------------------
BUILDING_LAYER_FILENAMES_FROZEN = {
    "brookseed.landmark.farm_house": {
        "base": "building_farm_house_base.png",
        "structure": "building_farm_house_structure.png",
        "roof": "building_farm_house_roof.png",
        "detail": "building_farm_house_detail.png",
        "interaction": "building_farm_house_interaction.png",
        "state_fx": "building_farm_house_state_fx.png",
    },
    "brookseed.landmark.farm_sluice": {
        "base": "building_farm_sluice_base.png",
        "structure": "building_farm_sluice_structure.png",
        "roof": "building_farm_sluice_roof.png",
        "detail": "building_farm_sluice_detail.png",
        "interaction": "building_farm_sluice_interaction.png",
        "state_fx": "building_farm_sluice_state_fx.png",
    },
    "brookseed.landmark.market_wharf": {
        "base": "building_market_wharf_base.png",
        "structure": "building_market_wharf_structure.png",
        "roof": "building_market_wharf_roof.png",
        "detail": "building_market_wharf_detail.png",
        "interaction": "building_market_wharf_interaction.png",
        "state_fx": "building_market_wharf_state_fx.png",
    },
    "brookseed.landmark.market_seed_shed": {
        "base": "building_market_seed_shed_base.png",
        "structure": "building_market_seed_shed_structure.png",
        "roof": "building_market_seed_shed_roof.png",
        "detail": "building_market_seed_shed_detail.png",
        "interaction": "building_market_seed_shed_interaction.png",
        "state_fx": "building_market_seed_shed_state_fx.png",
    },
    "brookseed.landmark.market_warden_post": {
        "base": "building_market_warden_post_base.png",
        "structure": "building_market_warden_post_structure.png",
        "roof": "building_market_warden_post_roof.png",
        "detail": "building_market_warden_post_detail.png",
        "interaction": "building_market_warden_post_interaction.png",
        "state_fx": "building_market_warden_post_state_fx.png",
    },
}

# ---------------------------------------------------------------------------
# R3-3: frozen map spatial records. path_cells, environment_boundary_cells,
# farm_area, and static obstacles are frozen per map. Deleting all path_cells
# or drifting a boundary/farm-area must fail.
# ---------------------------------------------------------------------------
PATH_CELLS_FROZEN = {
    "brookseed.map.farm_homestead": [
        [3, 7], [4, 7], [5, 7], [6, 7],
        [7, 0], [7, 1], [7, 2], [7, 3], [7, 4], [7, 5], [7, 6], [7, 7],
        [8, 7], [9, 7], [10, 7], [11, 7], [12, 7],
    ],
    "brookseed.map.creek_market": [
        [1, 8],
        [2, 5], [2, 6], [2, 7], [2, 8],
        [3, 5], [3, 8],
        [4, 5], [4, 8],
        [5, 5], [5, 8],
        [6, 5], [6, 8],
        [7, 5], [7, 8],
        [8, 3], [8, 4], [8, 5], [8, 6], [8, 7], [8, 8], [8, 9], [8, 10], [8, 11], [8, 12],
        [9, 3], [9, 4], [9, 5], [9, 6], [9, 7], [9, 8], [9, 9], [9, 10], [9, 11], [9, 12],
        [10, 5], [10, 8],
        [11, 5], [11, 8],
        [12, 5], [12, 8],
        [13, 5], [13, 8],
        [14, 5], [14, 8],
        [15, 5], [15, 6], [15, 7], [15, 8],
        [16, 8],
    ],
}

BOUNDARY_CELLS_FROZEN = {
    "brookseed.map.farm_homestead": [
        [0, 12], [0, 13], [0, 14], [1, 12], [1, 13], [1, 14],
        [2, 12], [2, 13], [2, 14], [3, 12], [3, 13], [3, 14],
        [4, 12], [4, 13], [4, 14], [5, 12], [5, 13], [5, 14],
        [6, 12], [6, 13], [6, 14], [7, 14],
        [8, 14], [9, 12], [9, 13], [9, 14],
        [10, 12], [10, 13], [10, 14], [11, 12], [11, 13], [11, 14],
        [12, 12], [12, 13], [12, 14], [13, 12], [13, 13], [13, 14],
        [14, 12], [14, 13], [14, 14], [15, 12], [15, 13], [15, 14],
    ],
    "brookseed.map.creek_market": [
        [0, 3], [0, 4], [0, 5], [0, 6], [0, 7], [0, 8], [0, 9], [0, 10], [0, 11], [0, 12], [0, 13],
        [1, 13], [2, 13], [3, 13], [4, 13], [5, 13], [6, 13], [7, 13], [8, 13], [9, 13], [10, 13], [11, 13], [12, 13], [13, 13], [14, 13], [15, 13], [16, 13], [17, 13],
        [17, 3], [17, 4], [17, 5], [17, 6], [17, 7], [17, 8], [17, 9], [17, 10], [17, 11], [17, 12],
    ],
}

FARM_AREA_FROZEN = {
    "brookseed.map.farm_homestead": {
        "primary_rectangles": [[2, 2, 5, 4], [8, 2, 4, 4]],
        "rear_cultivable_cells": [[7, 12], [7, 13], [8, 12], [8, 13]],
        "starting_cells": [[4, 3], [5, 3], [6, 3]],
        "legacy_farm_cells_remain_valid": True,
    },
    "brookseed.map.creek_market": None,
}

# Frozen HUD safe zones (from spec section 8).
HUD_FROZEN = {
    (960, 640): {
        "world_safe_rect_default": [16, 72, 928, 376],
        "world_safe_rect_near_building": [16, 72, 664, 376],
        "status_left": [16, 16, 272, 44],
        "status_right": [688, 16, 256, 44],
        "toolbelt": [300, 568, 360, 56],
        "toast": [240, 504, 480, 48],
        "context_prompt": [240, 456, 480, 40],
        "building_card_near": [696, 80, 248, 120],
        "building_card_expanded": [568, 80, 376, 400],
    },
    (1280, 800): {
        "world_safe_rect_default": [16, 72, 1248, 528],
        "world_safe_rect_near_building": [16, 72, 840, 528],
        "status_left": [16, 16, 304, 44],
        "status_right": [960, 16, 304, 44],
        "toolbelt": [456, 728, 368, 56],
        "toast": [360, 656, 560, 48],
        "context_prompt": [360, 608, 560, 40],
        "building_card_near": [976, 80, 288, 128],
        "building_card_expanded": [872, 80, 392, 480],
    },
}

HUD_BEHAVIOR_FROZEN = {
    "building_card": "hidden by default; compact only while near a building; expanded only after explicit interaction; dismissible",
    "debug_layer": "hidden by default and toggled only with H",
    "toast_priority": ["error", "warning", "success"],
    "transient_feedback_seconds": 2.5,
}

SAVE_RELOCATION_FROZEN = {
    "applies_after_decode_before_validation": True,
    "no_schema_change": True,
    "save_schema_version": 8,
    "idempotent": True,
    "unknown_map_id": "reject as invalid contents; do not guess",
    "writeback": "normal subsequent save writes the relocated coordinate without adding fields",
    "nearest_safe_rule": {
        "distance": "manhattan",
        "tie_break": ["distance_ascending", "y_ascending", "x_ascending"],
        "candidate": "in-bounds walkable cell excluding building collision, environment boundary, static obstacle, water, canal, and NPC occupied cells",
    },
    "coordinate_records": {
        "farm_cells": "preserve every previously valid legacy coordinate; additionally accept the four N-019 rear cultivable cells without changing schema or furniture placement bounds",
        "placed_objects": "preserve every previously valid footprint and origin in the farm legacy region; visual paths do not invalidate placement",
        "player_position": "preserve if in bounds and walkable; otherwise relocate",
    },
}

# Frozen immutable stable IDs (from contract). The exact frozen order of the
# buildings/exits/maps/npcs/spawns lists lives in IMMUTABLE_ORDER_FROZEN below
# (compared item-for-item, never sorted()).
IMMUTABLE_FROZEN = {
    "stable_id_families": [
        "all existing crop IDs",
        "all existing dialogue IDs",
        "all existing item IDs",
        "all existing placed-object IDs",
        "all existing quest IDs",
        "all existing recipe IDs",
    ],
}

# R6: the frozen explicit order of every immutable stable-ID list, read verbatim
# from the frozen contract. These sequences are the literal order the contract
# declares; they are NOT derived by sorting IDs, and the comparison must be
# item-for-item in this order (reversing any list must FAIL).
IMMUTABLE_ORDER_FROZEN = {
    "buildings": [
        "brookseed.landmark.farm_house",
        "brookseed.landmark.farm_sluice",
        "brookseed.landmark.market_seed_shed",
        "brookseed.landmark.market_warden_post",
        "brookseed.landmark.market_wharf",
    ],
    "exits": [
        "brookseed.exit.farm_to_market",
        "brookseed.exit.market_to_farm",
    ],
    "maps": [
        "brookseed.map.creek_market",
        "brookseed.map.farm_homestead",
    ],
    "npcs": [
        "brookseed.npc.creek_warden",
        "brookseed.npc.neighbor_consensus",
        "brookseed.npc.neighbor_evidence",
        "brookseed.npc.neighbor_hearsay",
        "brookseed.npc.neighbor_storyteller",
        "brookseed.npc.seed_steward",
        "brookseed.npc.water_apprentice",
    ],
    "spawns": [
        "brookseed.spawn.farm_from_market",
        "brookseed.spawn.farm_wake",
        "brookseed.spawn.market_from_farm",
    ],
}

# ---------------------------------------------------------------------------
# R5: complete frozen value records for the non-spatial semantic objects.
# Every field of coordinate_system, movement_semantics, immutable stable IDs
# (including stable_id_families), terrain, and world safe zone is frozen
# exactly. Deleting or tampering any field must FAIL.
# ---------------------------------------------------------------------------
COORDINATE_SYSTEM_FROZEN = {
    "cell_origin": "southwest",
    "screen_origin": "top_left",
    "tile_size_px": 24,
    "x_axis": "east",
    "y_axis": "north",
}

MOVEMENT_SEMANTICS_FROZEN = {
    "blocked_union": [
        "building.collision_cells", "canal_cells", "environment_boundary_cells",
        "static_obstacle_cells", "water_cells",
    ],
    "doors": "walkable and contained in footprint but excluded from collision_cells",
    "interaction_cells": "walkable, outside collision, and reachable from a spawn",
    "npc_positions": "walkable terrain reserved at runtime; never a door, exit, spawn, or main-road cell",
    "roof_occlusion": "render-only; never added to collision",
    "walkable": "every in-bounds cell not in blocked_union; NPC occupancy is added only for route validation and runtime actor collision",
}

# Frozen terrain per map (exact object). creek_market has plaza_semantic;
# farm_homestead does not. Deleting/tampering path_semantic or visual_variants
# must FAIL.
TERRAIN_FROZEN = {
    "brookseed.map.farm_homestead": {
        "default": "grass",
        "path_semantic": "stone_path",
        "visual_variants": "deterministic_hash",
    },
    "brookseed.map.creek_market": {
        "default": "grass",
        "path_semantic": "stone_path",
        "plaza_semantic": "wet_stone",
        "visual_variants": "deterministic_hash",
    },
}

# Frozen world safe zone per map (exact object). visual_buffer_rows is frozen
# exactly and must not be tampered (e.g. changed to 999).
WORLD_SAFE_ZONE_FROZEN = {
    "brookseed.map.farm_homestead": {
        "playable_bounds": [0, 0, 15, 11],
        "visual_buffer_rows": [12, 13, 14],
    },
    "brookseed.map.creek_market": {
        "playable_bounds": [1, 3, 16, 12],
        "visual_buffer_rows": [13],
    },
}

# ---------------------------------------------------------------------------
# R5: record-specific frozen fields, keyed by stable ID. These fields appear
# only on specific records and must be frozen exactly per record — a global
# "optional" allowance would let deletion or tampering pass.
# ---------------------------------------------------------------------------
# NPC scope: only the farm teaching NPC (water_apprentice on farm_homestead)
# carries `scope: "teaching_spawn"`. Every NPC's scope field is frozen exactly
# (either the literal value, or the explicit absence of the field).
NPC_SCOPE_FROZEN = {
    ("brookseed.map.farm_homestead", "brookseed.npc.water_apprentice"): "teaching_spawn",
}

# Gather required_unlock_id: only restored_brook_cache carries it. Every gather
# target's required_unlock_id is frozen exactly (value or explicit absence).
GATHER_REQUIRED_UNLOCK_FROZEN = {
    "brookseed.gather.restored_brook_cache": "brookseed.gather.restored_brook_cache",
}

# ---------------------------------------------------------------------------
# R4: frozen explicit order of named records, per map. The contract's
# deterministic_ordering.named_records declares "explicit semantic order frozen
# in this document". These sequences are the exact frozen order of each named
# record array; reversing any array must FAIL. They are NOT derived by sorting
# IDs — they are the literal frozen order read from the contract.
# ---------------------------------------------------------------------------
NAMED_RECORD_ORDER_FROZEN = {
    "spawns": {
        "brookseed.map.farm_homestead": [
            "brookseed.spawn.farm_from_market",
            "brookseed.spawn.farm_wake",
        ],
        "brookseed.map.creek_market": [
            "brookseed.spawn.market_from_farm",
        ],
    },
    "exits": {
        "brookseed.map.farm_homestead": [
            "brookseed.exit.farm_to_market",
        ],
        "brookseed.map.creek_market": [
            "brookseed.exit.market_to_farm",
        ],
    },
    "npc_positions": {
        "brookseed.map.farm_homestead": [
            "brookseed.npc.water_apprentice",
        ],
        "brookseed.map.creek_market": [
            "brookseed.npc.creek_warden",
            "brookseed.npc.neighbor_consensus",
            "brookseed.npc.neighbor_evidence",
            "brookseed.npc.neighbor_hearsay",
            "brookseed.npc.neighbor_storyteller",
            "brookseed.npc.seed_steward",
            "brookseed.npc.water_apprentice",
        ],
    },
    "gather_targets": {
        "brookseed.map.farm_homestead": [
            "brookseed.gather.farm_wood_cache",
            "brookseed.gather.farm_reed_cache",
            "brookseed.gather.farm_moss_cache",
        ],
        "brookseed.map.creek_market": [
            "brookseed.gather.market_wood_cache",
            "brookseed.gather.market_reed_cache",
            "brookseed.gather.market_moss_cache",
            "brookseed.gather.restored_brook_cache",
        ],
    },
    "quest_targets": {
        "brookseed.map.farm_homestead": [
            "brookseed.landmark.farm_beds",
            "brookseed.npc.water_apprentice",
            "brookseed.interaction.farm_sluice.gate",
        ],
        "brookseed.map.creek_market": [
            "brookseed.npc.creek_warden",
            "brookseed.landmark.market_blocked_mouth",
            "brookseed.npc.water_apprentice",
        ],
    },
    "landmarks": {
        "brookseed.map.farm_homestead": [
            "brookseed.landmark.farm_house",
            "brookseed.landmark.farm_beds",
            "brookseed.landmark.farm_steps",
            "brookseed.landmark.farm_sluice",
        ],
        "brookseed.map.creek_market": [
            "brookseed.landmark.market_blocked_mouth",
            "brookseed.landmark.market_seed_shed",
            "brookseed.landmark.market_steps",
            "brookseed.landmark.market_table",
            "brookseed.landmark.market_warden_post",
            "brookseed.landmark.market_wharf",
        ],
    },
}

# ---------------------------------------------------------------------------
# R4: frozen explicit order of buildings per map (footprint origin y ascending,
# then x ascending — verified against the frozen contract). Each entry is the
# frozen building ID sequence for that map.
# ---------------------------------------------------------------------------
BUILDING_ORDER_FROZEN = {
    "brookseed.map.farm_homestead": [
        "brookseed.landmark.farm_house",
        "brookseed.landmark.farm_sluice",
    ],
    "brookseed.map.creek_market": [
        "brookseed.landmark.market_wharf",
        "brookseed.landmark.market_seed_shed",
        "brookseed.landmark.market_warden_post",
    ],
}

VALID_WATER_SEMANTICS = {
    "base", "edge_n", "edge_e", "edge_s", "edge_w",
    "corner_ne", "corner_se", "corner_sw", "corner_nw",
}
VALID_CANAL_SEMANTICS = {"ns", "ew"}

FORBIDDEN_DIAGNOSTIC_MARKERS = ["阻", "石阶", "采"]

# Known fields (strict schema — unknown fields fail).
KNOWN_TOP_LEVEL = {
    "coordinate_system", "decision_id", "deterministic_ordering", "forbidden_scope",
    "hud", "immutable_stable_ids", "movement_semantics", "maps", "reachability",
    "save_relocation", "schema_version", "task",
}
KNOWN_MAP_FIELDS = {
    "buildings", "canal_cells", "dimensions", "environment_boundary_cells", "exits",
    "farm_area", "gather_targets", "id", "landmarks", "legacy_bounds", "npc_positions",
    "path_cells", "quest_targets", "spawns", "static_obstacle_cells", "terrain",
    "water_cells", "world_safe_zone",
}
KNOWN_BUILDING_FIELDS = {
    "collision_cells", "door", "footprint", "id", "interaction_cells", "layers",
    "occlusion_cells", "render_anchor", "state",
}
KNOWN_LAYER_FIELDS = {"filename", "native_size", "order", "semantic"}
KNOWN_FOOTPRINT_FIELDS = {"height", "origin", "width"}
KNOWN_RENDER_ANCHOR_FIELDS = {"cell", "normalized", "pixel_offset"}
KNOWN_HUD_FIELDS = {"behavior", "safe_zones"}
KNOWN_HUD_BEHAVIOR_FIELDS = {
    "building_card", "debug_layer", "toast_priority", "transient_feedback_seconds",
}
KNOWN_SAFE_ZONE_FIELDS = {
    "building_card_expanded", "building_card_near", "context_prompt", "origin",
    "status_left", "status_right", "toast", "toolbelt", "viewport",
    "world_safe_rect_default", "world_safe_rect_near_building",
}
KNOWN_REACHABILITY_FIELDS = {"movement", "required_pairs"}
KNOWN_PAIR_FIELDS = {"from", "map_id", "name", "to"}
KNOWN_SAVE_RELOCATION_FIELDS = {
    "applies_after_decode_before_validation", "coordinate_records", "idempotent",
    "nearest_safe_rule", "no_schema_change", "save_schema_version", "unknown_map_id",
    "writeback",
}
KNOWN_NEAREST_SAFE_FIELDS = {"candidate", "distance", "tie_break"}
KNOWN_COORDINATE_RECORDS_FIELDS = {"farm_cells", "placed_objects", "player_position"}
KNOWN_COORDINATE_SYSTEM_FIELDS = {
    "cell_origin", "screen_origin", "tile_size_px", "x_axis", "y_axis",
}
KNOWN_MOVEMENT_SEMANTICS_FIELDS = {
    "blocked_union", "doors", "interaction_cells", "npc_positions",
    "roof_occlusion", "walkable",
}
KNOWN_IMMUTABLE_FIELDS = {
    "buildings", "exits", "maps", "npcs", "spawns", "stable_id_families",
}
KNOWN_DETERMINISTIC_ORDERING_FIELDS = {"buildings", "cells", "layers", "named_records"}
KNOWN_TERRAIN_FIELDS = {"default", "path_semantic", "plaza_semantic", "visual_variants"}
KNOWN_WORLD_SAFE_ZONE_FIELDS = {"playable_bounds", "visual_buffer_rows"}
KNOWN_NPC_FIELDS = {"approach_cells", "id", "position", "scope"}
KNOWN_SPAWN_FIELDS = {"id", "position"}
KNOWN_EXIT_FIELDS = {"cell", "destination_map_id", "destination_spawn_id", "id"}
KNOWN_GATHER_FIELDS = {"cell", "id", "required_unlock_id"}
KNOWN_QUEST_FIELDS = {"cell", "id", "purpose"}
KNOWN_LANDMARK_FIELDS = {"anchor", "id"}
KNOWN_WATER_FIELDS = {"cell", "semantic"}
KNOWN_CANAL_FIELDS = {"cell", "semantic"}
KNOWN_LEGACY_BOUNDS_FIELDS = {"columns", "rows"}
KNOWN_DIMENSIONS_FIELDS = {"columns", "rows"}
KNOWN_FARM_AREA_FIELDS = {
    "primary_rectangles", "rear_cultivable_cells", "starting_cells",
    "legacy_farm_cells_remain_valid",
}

# ---------------------------------------------------------------------------
# R3-4: required fields for top-level and nested objects. Missing any of these
# must FAIL (previously only unknown-field checks existed).
# ---------------------------------------------------------------------------
REQUIRED_TOP_LEVEL = {
    "coordinate_system", "decision_id", "deterministic_ordering", "forbidden_scope",
    "hud", "immutable_stable_ids", "movement_semantics", "maps", "reachability",
    "save_relocation", "schema_version", "task",
}
REQUIRED_MAP_FIELDS = {
    "buildings", "canal_cells", "dimensions", "environment_boundary_cells", "exits",
    "farm_area", "gather_targets", "id", "landmarks", "legacy_bounds",
    "npc_positions", "path_cells", "quest_targets", "spawns", "terrain",
    "water_cells", "world_safe_zone",
}
REQUIRED_BUILDING_FIELDS = {
    "collision_cells", "door", "footprint", "id", "interaction_cells", "layers",
    "occlusion_cells", "render_anchor", "state",
}
REQUIRED_LAYER_FIELDS = {"filename", "native_size", "order", "semantic"}
REQUIRED_FOOTPRINT_FIELDS = {"height", "origin", "width"}
REQUIRED_RENDER_ANCHOR_FIELDS = {"cell", "normalized", "pixel_offset"}
REQUIRED_NPC_FIELDS = {"approach_cells", "id", "position"}
REQUIRED_SPAWN_FIELDS = {"id", "position"}
REQUIRED_EXIT_FIELDS = {"cell", "destination_map_id", "destination_spawn_id", "id"}
REQUIRED_GATHER_FIELDS = {"cell", "id"}
REQUIRED_QUEST_FIELDS = {"cell", "id", "purpose"}
REQUIRED_LANDMARK_FIELDS = {"anchor", "id"}
REQUIRED_WATER_FIELDS = {"cell", "semantic"}
REQUIRED_CANAL_FIELDS = {"cell", "semantic"}
REQUIRED_DIMENSIONS_FIELDS = {"columns", "rows"}
REQUIRED_LEGACY_BOUNDS_FIELDS = {"columns", "rows"}
REQUIRED_PAIR_FIELDS = {"from", "map_id", "name", "to"}
REQUIRED_NEAREST_SAFE_FIELDS = {"candidate", "distance", "tie_break"}
REQUIRED_COORDINATE_RECORDS_FIELDS = {"farm_cells", "placed_objects", "player_position"}
REQUIRED_DETERMINISTIC_ORDERING_FIELDS = {"buildings", "cells", "layers", "named_records"}
REQUIRED_HUD_FIELDS = {"behavior", "safe_zones"}
REQUIRED_HUD_BEHAVIOR_FIELDS = {
    "building_card", "debug_layer", "toast_priority", "transient_feedback_seconds",
}
REQUIRED_SAFE_ZONE_FIELDS = {
    "building_card_expanded", "building_card_near", "context_prompt", "origin",
    "status_left", "status_right", "toast", "toolbelt", "viewport",
    "world_safe_rect_default", "world_safe_rect_near_building",
}
REQUIRED_REACHABILITY_FIELDS = {"movement", "required_pairs"}
REQUIRED_SAVE_RELOCATION_FIELDS = {
    "applies_after_decode_before_validation", "coordinate_records", "idempotent",
    "nearest_safe_rule", "no_schema_change", "save_schema_version", "unknown_map_id",
    "writeback",
}

# Frozen deterministic_ordering contract value (exact, from contract).
DETERMINISTIC_ORDERING_FROZEN = {
    "buildings": "footprint origin y ascending, then x ascending",
    "cells": "x ascending, then y ascending",
    "layers": "order ascending",
    "named_records": "explicit semantic order frozen in this document",
}


class Failures:
    def __init__(self) -> None:
        self.items: list[str] = []

    def add(self, message: str) -> None:
        self.items.append(message)

    def __bool__(self) -> bool:
        return bool(self.items)

    def __len__(self) -> int:
        return len(self.items)


def _cells_to_tuple(cells) -> list[tuple[int, int]]:
    return [tuple(c) for c in cells]


def _in_bounds(cell, columns: int, rows: int) -> bool:
    x, y = cell
    return 0 <= x < columns and 0 <= y < rows


def _footprint_cells(origin, width: int, height: int) -> list[tuple[int, int]]:
    ox, oy = origin
    return [(ox + dx, oy + dy) for dy in range(height) for dx in range(width)]


def _bfs_reachable(start, target, blocked: set, columns: int, rows: int) -> bool:
    if start in blocked or target in blocked:
        return False
    if start == target:
        return True
    queue = [start]
    seen = {start}
    while queue:
        x, y = queue.pop(0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if not _in_bounds((nx, ny), columns, rows):
                continue
            if (nx, ny) in blocked:
                continue
            if (nx, ny) == target:
                return True
            if (nx, ny) not in seen:
                seen.add((nx, ny))
                queue.append((nx, ny))
    return False


def _manhattan(a, b) -> int:
    return abs(a[0] - b[0]) + abs(a[1] - b[1])


def _is_orthogonally_adjacent(a, b) -> bool:
    return _manhattan(a, b) == 1


def _load_json(path: Path) -> object:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _check_unknown_fields(obj: dict, known: set, context: str, f: Failures) -> None:
    for key in obj:
        if key not in known:
            f.add(f"{context}: unknown field '{key}'")


def _check_required_fields(obj: dict, required: set, context: str, f: Failures) -> None:
    for key in required:
        if key not in obj:
            f.add(f"{context}: missing required field '{key}'")


def _compare_cells(actual, expected, context: str, f: Failures) -> None:
    """Compare a cell list against a frozen cell set exactly (order-insensitive but
    duplicate-sensitive). Used for collision/occlusion/interaction/path/boundary."""
    actual_t = _cells_to_tuple(actual)
    expected_t = _cells_to_tuple(expected)
    if sorted(actual_t) != sorted(expected_t):
        f.add(f"{context}: got {sorted(actual_t)}, expected {sorted(expected_t)}")


def _check_cell_order(actual, context: str, f: Failures) -> None:
    """R4: enforce the contract's deterministic_ordering.cells rule on a pure cell
    list — x ascending, then y ascending. This is independent of _compare_cells
    (which is deliberately order-insensitive for set-equivalence); this helper
    rejects any list that is not already in the frozen (x, y) ascending order."""
    actual_t = _cells_to_tuple(actual)
    if len(actual_t) <= 1:
        return
    expected = sorted(actual_t, key=lambda c: (c[0], c[1]))
    if actual_t != expected:
        f.add(f"{context}: cell order must be x ascending then y ascending; got {actual_t}")


def _check_cell_record_order(actual, context: str, f: Failures) -> None:
    """R4: enforce cell-record order (records carrying a 'cell' field, e.g.
    water_cells / canal_cells) — by their cell x ascending, then y ascending."""
    cells = []
    for rec in actual:
        if isinstance(rec, dict) and isinstance(rec.get("cell"), list) and len(rec["cell"]) == 2:
            cells.append(tuple(rec["cell"]))
    if len(cells) <= 1:
        return
    expected = sorted(cells, key=lambda c: (c[0], c[1]))
    if cells != expected:
        f.add(f"{context}: cell-record order must be x ascending then y ascending; got {cells}")


def _check_named_record_order(actual, expected_ids, context: str, f: Failures) -> None:
    """R4: enforce the frozen explicit semantic order of a named-record array.
    The actual array's id sequence must equal the frozen sequence exactly."""
    actual_ids = [rec.get("id") for rec in actual if isinstance(rec, dict) and isinstance(rec.get("id"), str)]
    if actual_ids != list(expected_ids):
        f.add(f"{context}: order must be {list(expected_ids)}, got {actual_ids}")


def _check_rect(rect, viewport, name: str, context: str, f: Failures) -> None:
    if not isinstance(rect, list) or len(rect) != 4 or not all(isinstance(v, int) for v in rect):
        f.add(f"{context}.{name} must be a list of 4 integers")
        return
    x, y, w, h = rect
    if x < 0 or y < 0:
        f.add(f"{context}.{name} has negative origin {rect}")
    if w <= 0 or h <= 0:
        f.add(f"{context}.{name} has non-positive width/height {rect}")
    vw, vh = viewport
    if x + w > vw or y + h > vh:
        f.add(f"{context}.{name} {rect} exceeds viewport {viewport}")


def _rects_overlap(a, b) -> bool:
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return not (ax + aw <= bx or bx + bw <= ax or ay + ah <= by or by + bh <= ay)


def _derive_water_semantic(cell, water_cells: set, columns: int, rows: int):
    """Derive the shoreline semantic for a water cell from its orthogonal water
    neighbors. The semantic names the LAND (non-water) side(s) of the tile, in
    compass terms: a corner cell has exactly two land sides, an edge cell one,
    and a fully-surrounded cell is 'base'."""
    if cell not in water_cells:
        return None
    x, y = cell
    n = (x, y + 1) in water_cells
    s = (x, y - 1) in water_cells
    e = (x + 1, y) in water_cells
    w = (x - 1, y) in water_cells
    land_n = not n
    land_s = not s
    land_e = not e
    land_w = not w
    land_count = sum([land_n, land_s, land_e, land_w])
    if land_count == 0:
        return "base"
    if land_count == 1:
        if land_n:
            return "edge_n"
        if land_s:
            return "edge_s"
        if land_e:
            return "edge_e"
        if land_w:
            return "edge_w"
    if land_count == 2:
        if land_n and land_e:
            return "corner_ne"
        if land_n and land_w:
            return "corner_nw"
        if land_s and land_e:
            return "corner_se"
        if land_s and land_w:
            return "corner_sw"
    return None


def _path_str(steps: list) -> str:
    """Render a list of path steps (str keys / int indices) as a JSON path,
    e.g. ['maps', 0, 'buildings', 1, 'collision_cells', 2, 0]
    -> 'maps[0].buildings[1].collision_cells[2][0]'."""
    out = ""
    for step in steps:
        if isinstance(step, int):
            out += f"[{step}]"
        else:
            out += ("" if not out else ".") + step
    return out


def _compact(value, limit: int = 60) -> str:
    text = repr(value)
    if len(text) > limit:
        text = text[: limit - 1] + "…"
    return text


def _deep_diff(expected, actual, steps: list, f: Failures) -> None:
    """R6 complete leaf freezing: compare the candidate against the frozen
    reference contract structurally, field path by field path. Every
    difference — a deleted key, an extra (even globally-known) key, a changed
    scalar/string/bool/number leaf, a reordered list — produces a failure whose
    message carries the exact JSON path of the divergence. Types are compared
    strictly (bool != int != float). This is NOT a hash comparison: every
    divergence is reported individually at field-path granularity."""
    if type(expected) is not type(actual):
        f.add(
            f"frozen tree mismatch at {_path_str(steps)}: "
            f"expected {type(expected).__name__}, got {type(actual).__name__} "
            f"({_compact(actual)})"
        )
        return
    if isinstance(expected, dict):
        for key in sorted(set(expected) | set(actual)):
            if key not in expected:
                f.add(
                    f"frozen tree mismatch at {_path_str(steps + [key])}: "
                    f"unexpected key (got {_compact(actual[key])})"
                )
            elif key not in actual:
                f.add(
                    f"frozen tree mismatch at {_path_str(steps + [key])}: "
                    f"missing key (frozen value {_compact(expected[key])})"
                )
            else:
                _deep_diff(expected[key], actual[key], steps + [key], f)
        return
    if isinstance(expected, list):
        if len(expected) != len(actual):
            f.add(
                f"frozen tree mismatch at {_path_str(steps)}: "
                f"expected list of length {len(expected)}, got {len(actual)}"
            )
        for i in range(min(len(expected), len(actual))):
            _deep_diff(expected[i], actual[i], steps + [i], f)
        return
    if expected != actual:
        f.add(
            f"frozen tree mismatch at {_path_str(steps)}: "
            f"expected {_compact(expected)}, got {_compact(actual)}"
        )


def validate_contract(contract_path: Path, matrix_path: Path, spec_path: Path, reference_path: Path | None = None) -> tuple[Failures, dict]:
    f = Failures()
    summary: dict = {}

    try:
        contract = _load_json(contract_path)
    except Exception as exc:  # noqa: BLE001
        f.add(f"contract is not parseable JSON: {exc}")
        return f, summary
    if not isinstance(contract, dict):
        f.add("contract root is not a JSON object")
        return f, summary

    # R6: complete leaf freezing. Compare the candidate against the frozen
    # reference contract field path by field path, before any semantic rule.
    # Every deleted key, every extra key (even a globally-known one that this
    # object must not carry), every changed leaf value, and every reordered
    # list is reported with its exact JSON path. This closes the r5 gap where
    # required-but-not-value-frozen fields (e.g. quest_targets[].purpose) could
    # be tampered without failing.
    ref_path = reference_path if reference_path is not None else CONTRACT
    try:
        reference = _load_json(ref_path)
    except Exception as exc:  # noqa: BLE001
        f.add(f"frozen reference contract is not parseable JSON: {exc}")
        reference = None
    if reference is not None:
        _deep_diff(reference, contract, [], f)

    matrix = None
    matrix_b4: dict = {}
    try:
        matrix = _load_json(matrix_path)
        for asset in matrix.get("assets", []):
            if asset.get("batch") == "B4":
                matrix_b4[asset.get("filename")] = {
                    "native_size": [asset.get("native_width"), asset.get("native_height")],
                    "provenance": asset.get("provenance"),
                    "batch": asset.get("batch"),
                }
    except Exception as exc:  # noqa: BLE001
        f.add(f"consumer matrix is not parseable JSON: {exc}")

    spec_text = ""
    try:
        spec_text = spec_path.read_text(encoding="utf-8")
    except Exception as exc:  # noqa: BLE001
        f.add(f"spec is not readable: {exc}")

    # Rule 1: schema / required fields / types / unknown fields.
    _check_unknown_fields(contract, KNOWN_TOP_LEVEL, "contract", f)
    _check_required_fields(contract, REQUIRED_TOP_LEVEL, "contract", f)
    if contract.get("schema_version") != SCHEMA_VERSION:
        f.add(f"contract.schema_version must be {SCHEMA_VERSION}, got {contract.get('schema_version')!r}")
    if contract.get("task") != "N-015":
        f.add(f"contract.task must be 'N-015', got {contract.get('task')!r}")
    if contract.get("decision_id") != DECISION_ID:
        f.add(f"contract.decision_id must be '{DECISION_ID}', got {contract.get('decision_id')!r}")

    cs = contract.get("coordinate_system")
    if not isinstance(cs, dict):
        f.add("contract.coordinate_system is missing or not an object")
    else:
        _check_unknown_fields(cs, KNOWN_COORDINATE_SYSTEM_FIELDS, "coordinate_system", f)
        _check_required_fields(cs, KNOWN_COORDINATE_SYSTEM_FIELDS, "coordinate_system", f)
        # R5: every coordinate_system field is frozen exactly (axes, origins,
        # tile size). Deleting screen_origin or tampering x_axis must FAIL.
        for key, exp in COORDINATE_SYSTEM_FROZEN.items():
            if cs.get(key) != exp:
                f.add(f"coordinate_system.{key} must be {exp!r}, got {cs.get(key)!r}")

    det = contract.get("deterministic_ordering")
    if not isinstance(det, dict):
        f.add("contract.deterministic_ordering is missing")
    else:
        _check_unknown_fields(det, KNOWN_DETERMINISTIC_ORDERING_FIELDS, "deterministic_ordering", f)
        _check_required_fields(det, REQUIRED_DETERMINISTIC_ORDERING_FIELDS, "deterministic_ordering", f)
        if det != DETERMINISTIC_ORDERING_FROZEN:
            f.add(f"contract.deterministic_ordering must be {DETERMINISTIC_ORDERING_FROZEN}, got {det}")

    ms = contract.get("movement_semantics")
    if not isinstance(ms, dict):
        f.add("contract.movement_semantics is missing")
    else:
        _check_unknown_fields(ms, KNOWN_MOVEMENT_SEMANTICS_FIELDS, "movement_semantics", f)
        _check_required_fields(ms, KNOWN_MOVEMENT_SEMANTICS_FIELDS, "movement_semantics", f)
        # R5: every movement_semantics field is frozen exactly. Deleting
        # `walkable` or tampering any semantic string must FAIL.
        for key, exp in MOVEMENT_SEMANTICS_FROZEN.items():
            got = ms.get(key)
            if key == "blocked_union":
                if not isinstance(got, list) or sorted(got) != sorted(exp):
                    f.add(f"movement_semantics.blocked_union mismatch: got {got}")
            elif got != exp:
                f.add(f"movement_semantics.{key} must be {exp!r}, got {got!r}")

    immutable = contract.get("immutable_stable_ids")
    if not isinstance(immutable, dict):
        f.add("contract.immutable_stable_ids is missing")
    else:
        _check_unknown_fields(immutable, KNOWN_IMMUTABLE_FIELDS, "immutable_stable_ids", f)
        _check_required_fields(immutable, KNOWN_IMMUTABLE_FIELDS, "immutable_stable_ids", f)
        for key in KNOWN_IMMUTABLE_FIELDS:
            got = immutable.get(key)
            if key in IMMUTABLE_ORDER_FROZEN:
                # R6: immutable stable-ID lists are frozen in explicit order.
                # The comparison is item-for-item against the frozen sequence;
                # it must NOT be sorted() before comparing (reversing a list
                # must FAIL).
                expected = IMMUTABLE_ORDER_FROZEN[key]
                if got != expected:
                    f.add(f"immutable_stable_ids.{key} order must be {expected}, got {got}")
            elif key == "stable_id_families":
                # stable_id_families is a frozen ordered list of literal strings.
                if got != IMMUTABLE_FROZEN["stable_id_families"]:
                    f.add(f"immutable_stable_ids.{key} must be {IMMUTABLE_FROZEN['stable_id_families']}, got {got}")

    maps = contract.get("maps")
    if not isinstance(maps, list) or len(maps) != 2:
        f.add("contract.maps must be a list of exactly 2 maps")
        return f, summary

    map_ids_seen: list[str] = []
    total_buildings = 0
    total_layers = 0
    contract_b4: dict = {}
    map_dimensions: dict[str, tuple[int, int]] = {}
    map_buildings: dict[str, list] = {}
    map_spawns: dict[str, list] = {}
    map_exits: dict[str, list] = {}
    map_npcs: dict[str, list] = {}
    map_water: dict[str, list] = {}
    map_canal: dict[str, list] = {}
    map_gather: dict[str, list] = {}
    map_quest: dict[str, list] = {}
    map_static_obstacles: dict[str, list] = {}
    map_farm_area: dict[str, object] = {}
    map_landmarks: dict[str, list] = {}
    map_boundary: dict[str, list] = {}
    map_path_cells: dict[str, list] = {}

    for map_index, m in enumerate(maps):
        mctx = f"maps[{map_index}]"
        if not isinstance(m, dict):
            f.add(f"{mctx} is not an object")
            continue
        _check_unknown_fields(m, KNOWN_MAP_FIELDS, mctx, f)
        _check_required_fields(m, REQUIRED_MAP_FIELDS, mctx, f)

        map_id = m.get("id")
        if not isinstance(map_id, str) or not map_id:
            f.add(f"{mctx}.id is missing")
            continue
        if map_id not in EXPECTED_MAPS:
            f.add(f"{mctx}.id '{map_id}' is not a frozen map ID")
        if map_id in map_ids_seen:
            f.add(f"{mctx}.id '{map_id}' is duplicated")
        map_ids_seen.append(map_id)

        dims = m.get("dimensions")
        if not isinstance(dims, dict):
            f.add(f"{mctx}.dimensions is missing")
            continue
        _check_unknown_fields(dims, KNOWN_DIMENSIONS_FIELDS, f"{mctx}.dimensions", f)
        _check_required_fields(dims, REQUIRED_DIMENSIONS_FIELDS, f"{mctx}.dimensions", f)
        columns, rows = dims.get("columns"), dims.get("rows")
        if not isinstance(columns, int) or not isinstance(rows, int):
            f.add(f"{mctx}.dimensions is malformed")
            continue
        map_dimensions[map_id] = (columns, rows)
        if MAP_DIMENSIONS_FROZEN.get(map_id) != (columns, rows):
            f.add(f"{mctx}.dimensions must be {MAP_DIMENSIONS_FROZEN.get(map_id)}, got {(columns, rows)}")

        lb = m.get("legacy_bounds")
        if not isinstance(lb, dict):
            f.add(f"{mctx}.legacy_bounds is missing")
        else:
            _check_unknown_fields(lb, KNOWN_LEGACY_BOUNDS_FIELDS, f"{mctx}.legacy_bounds", f)
            _check_required_fields(lb, REQUIRED_LEGACY_BOUNDS_FIELDS, f"{mctx}.legacy_bounds", f)
            if (lb.get("columns"), lb.get("rows")) != LEGACY_BOUNDS_FROZEN.get(map_id):
                f.add(f"{mctx}.legacy_bounds must be {LEGACY_BOUNDS_FROZEN.get(map_id)}")

        wsz = m.get("world_safe_zone")
        if not isinstance(wsz, dict):
            f.add(f"{mctx}.world_safe_zone is missing")
        else:
            _check_unknown_fields(wsz, KNOWN_WORLD_SAFE_ZONE_FIELDS, f"{mctx}.world_safe_zone", f)
            _check_required_fields(wsz, KNOWN_WORLD_SAFE_ZONE_FIELDS, f"{mctx}.world_safe_zone", f)
            # R5: world safe zone is frozen exactly (playable_bounds AND
            # visual_buffer_rows). Tampering visual_buffer_rows must FAIL.
            exp_wsz = WORLD_SAFE_ZONE_FROZEN.get(map_id)
            if exp_wsz is not None:
                if wsz.get("playable_bounds") != exp_wsz["playable_bounds"]:
                    f.add(f"{mctx}.world_safe_zone.playable_bounds must be {exp_wsz['playable_bounds']}, got {wsz.get('playable_bounds')}")
                if wsz.get("visual_buffer_rows") != exp_wsz["visual_buffer_rows"]:
                    f.add(f"{mctx}.world_safe_zone.visual_buffer_rows must be {exp_wsz['visual_buffer_rows']}, got {wsz.get('visual_buffer_rows')}")

        terrain = m.get("terrain")
        if not isinstance(terrain, dict):
            f.add(f"{mctx}.terrain is missing")
        else:
            _check_unknown_fields(terrain, KNOWN_TERRAIN_FIELDS, f"{mctx}.terrain", f)
            # R5: terrain is frozen exactly per map, including path_semantic,
            # plaza_semantic (market only) and visual_variants. The exact key
            # set differs per map (farm has no plaza_semantic), so required
            # fields are per-map rather than global.
            exp_terrain = TERRAIN_FROZEN.get(map_id)
            if exp_terrain is not None:
                # R6: the exact terrain key set is frozen per map. farm_homestead
                # must not carry plaza_semantic (market-only), and any other
                # extra — even globally-known — key is rejected.
                for key in terrain:
                    if key not in exp_terrain:
                        f.add(f"{mctx}.terrain: unexpected field '{key}' (not allowed for {map_id})")
                for key in exp_terrain:
                    if key not in terrain:
                        f.add(f"{mctx}.terrain is missing required field '{key}'")
                for key, exp in exp_terrain.items():
                    if terrain.get(key) != exp:
                        f.add(f"{mctx}.terrain.{key} must be {exp!r}, got {terrain.get(key)!r}")

        boundary = m.get("environment_boundary_cells")
        if not isinstance(boundary, list):
            f.add(f"{mctx}.environment_boundary_cells is not a list")
        else:
            map_boundary[map_id] = boundary
            for cell in _cells_to_tuple(boundary):
                if not _in_bounds(cell, columns, rows):
                    f.add(f"{mctx}.environment_boundary_cells cell {cell} is out of bounds")
            if map_id in BOUNDARY_CELLS_FROZEN:
                _compare_cells(boundary, BOUNDARY_CELLS_FROZEN[map_id], f"{mctx}.environment_boundary_cells", f)
            # R4: pure cell arrays must be x ascending, then y ascending.
            _check_cell_order(boundary, f"{mctx}.environment_boundary_cells", f)

        path_cells = m.get("path_cells")
        if not isinstance(path_cells, list):
            f.add(f"{mctx}.path_cells is not a list")
        else:
            map_path_cells[map_id] = path_cells
            for cell in _cells_to_tuple(path_cells):
                if not _in_bounds(cell, columns, rows):
                    f.add(f"{mctx}.path_cells cell {cell} is out of bounds")
            if map_id in PATH_CELLS_FROZEN:
                _compare_cells(path_cells, PATH_CELLS_FROZEN[map_id], f"{mctx}.path_cells", f)
            # R4: pure cell arrays must be x ascending, then y ascending.
            _check_cell_order(path_cells, f"{mctx}.path_cells", f)

        # R5: static_obstacle_cells is frozen per map. farm_homestead freezes an
        # empty set (field absent); creek_market freezes [[6,7]]. Distinguish
        # "field missing" from "explicit empty array" — both are allowed only
        # where the frozen set is empty, and a non-empty frozen set requires the
        # field to be present.
        if "static_obstacle_cells" in m:
            obstacles = m.get("static_obstacle_cells")
        else:
            obstacles = []
        if not isinstance(obstacles, list):
            f.add(f"{mctx}.static_obstacle_cells is not a list")
        else:
            map_static_obstacles[map_id] = obstacles
            for cell in _cells_to_tuple(obstacles):
                if not _in_bounds(cell, columns, rows):
                    f.add(f"{mctx}.static_obstacle_cells cell {cell} is out of bounds")
            if set(_cells_to_tuple(obstacles)) != STATIC_OBSTACLE_FROZEN.get(map_id, set()):
                f.add(f"{mctx}.static_obstacle_cells mismatch: got {sorted(_cells_to_tuple(obstacles))}, expected {sorted(STATIC_OBSTACLE_FROZEN.get(map_id, set()))}")

        # Buildings (R2-1)
        buildings = m.get("buildings")
        if not isinstance(buildings, list):
            f.add(f"{mctx}.buildings is not a list")
            continue
        map_buildings[map_id] = buildings
        total_buildings += len(buildings)
        # R4: buildings must be ordered by footprint origin y ascending, then x
        # ascending. Reversing a building array must FAIL. We verify both that
        # the observed order equals the frozen explicit order AND that the
        # footprint origins are non-decreasing in (y, x).
        if map_id in BUILDING_ORDER_FROZEN:
            _check_named_record_order(buildings, BUILDING_ORDER_FROZEN[map_id], f"{mctx}.buildings", f)
        building_origins_in_order: list[tuple[int, int]] = []
        for _b in buildings:
            if isinstance(_b, dict) and isinstance(_b.get("footprint"), dict):
                _o = _b["footprint"].get("origin")
                if isinstance(_o, list) and len(_o) == 2 and all(isinstance(v, int) for v in _o):
                    building_origins_in_order.append((_o[0], _o[1]))
        if building_origins_in_order != sorted(building_origins_in_order, key=lambda c: (c[1], c[0])):
            f.add(f"{mctx}.buildings: footprint origins must be y ascending then x ascending; got {building_origins_in_order}")
        building_ids_in_map: set[str] = set()
        for b_index, b in enumerate(buildings):
            bctx = f"{mctx}.buildings[{b_index}]"
            if not isinstance(b, dict):
                f.add(f"{bctx} is not an object")
                continue
            _check_unknown_fields(b, KNOWN_BUILDING_FIELDS, bctx, f)
            _check_required_fields(b, REQUIRED_BUILDING_FIELDS, bctx, f)
            bid = b.get("id")
            if not isinstance(bid, str) or not bid:
                f.add(f"{bctx}.id is missing")
                continue
            if bid not in EXPECTED_BUILDINGS:
                f.add(f"{bctx}.id '{bid}' is not a frozen building ID")
            if bid in building_ids_in_map:
                f.add(f"{bctx}.id '{bid}' is duplicated within map")
            building_ids_in_map.add(bid)
            if BUILDING_MAP.get(bid) != map_id:
                f.add(f"{bctx}.id '{bid}' belongs to {BUILDING_MAP.get(bid)}, not {map_id}")

            expected_w, expected_h = EXPECTED_BUILDINGS.get(bid, (None, None))
            footprint = b.get("footprint")
            if not isinstance(footprint, dict):
                f.add(f"{bctx}.footprint is missing")
                continue
            _check_unknown_fields(footprint, KNOWN_FOOTPRINT_FIELDS, f"{bctx}.footprint", f)
            _check_required_fields(footprint, REQUIRED_FOOTPRINT_FIELDS, f"{bctx}.footprint", f)
            origin = footprint.get("origin")
            width = footprint.get("width")
            height = footprint.get("height")
            if not isinstance(origin, list) or len(origin) != 2 or not all(isinstance(v, int) for v in origin):
                f.add(f"{bctx}.footprint.origin is malformed")
                continue
            if not isinstance(width, int) or not isinstance(height, int):
                f.add(f"{bctx}.footprint.width/height must be integers, got {width!r}/{height!r}")
                continue
            if width != expected_w or height != expected_h:
                f.add(f"{bctx}.footprint must be {expected_w}x{expected_h}, got {width}x{height}")
            origin_t = tuple(origin)
            # R3-1: footprint origin is frozen exactly (whole-building shift must fail).
            if bid in BUILDING_RECORDS_FROZEN:
                exp_fp = BUILDING_RECORDS_FROZEN[bid]["footprint"]
                if list(origin) != exp_fp["origin"]:
                    f.add(f"{bctx}.footprint.origin must be {exp_fp['origin']}, got {origin}")
            fp_cells = _footprint_cells(origin_t, width, height)
            for cell in fp_cells:
                if not _in_bounds(cell, columns, rows):
                    f.add(f"{bctx}.footprint cell {cell} is out of bounds")

            door = b.get("door")
            if not isinstance(door, list) or len(door) != 2 or not all(isinstance(v, int) for v in door):
                f.add(f"{bctx}.door is malformed")
            else:
                if tuple(door) not in fp_cells:
                    f.add(f"{bctx}.door {tuple(door)} is not inside footprint")
                if bid in BUILDING_RECORDS_FROZEN and list(door) != BUILDING_RECORDS_FROZEN[bid]["door"]:
                    f.add(f"{bctx}.door must be {BUILDING_RECORDS_FROZEN[bid]['door']}, got {door}")

            collision = b.get("collision_cells")
            if not isinstance(collision, list):
                f.add(f"{bctx}.collision_cells is missing")
            else:
                collision_t = _cells_to_tuple(collision)
                if len(set(collision_t)) != len(collision_t):
                    f.add(f"{bctx}.collision_cells has duplicates")
                for cell in collision_t:
                    if not _in_bounds(cell, columns, rows):
                        f.add(f"{bctx}.collision_cells cell {cell} is out of bounds")
                    if cell not in fp_cells:
                        f.add(f"{bctx}.collision_cells cell {cell} is outside footprint")
                # R3-1: collision_cells must equal the frozen footprint-minus-door set exactly.
                if bid in BUILDING_RECORDS_FROZEN:
                    _compare_cells(collision, BUILDING_RECORDS_FROZEN[bid]["collision_cells"], f"{bctx}.collision_cells", f)
                # R6: deterministic_ordering.cells covers building cell arrays;
                # collision_cells must be x ascending, then y ascending.
                _check_cell_order(collision, f"{bctx}.collision_cells", f)

            interaction = b.get("interaction_cells")
            if not isinstance(interaction, list) or len(interaction) == 0:
                f.add(f"{bctx}.interaction_cells is missing or empty")
            else:
                for cell in _cells_to_tuple(interaction):
                    if not _in_bounds(cell, columns, rows):
                        f.add(f"{bctx}.interaction_cells cell {cell} is out of bounds")
                if bid in BUILDING_RECORDS_FROZEN:
                    _compare_cells(interaction, BUILDING_RECORDS_FROZEN[bid]["interaction_cells"], f"{bctx}.interaction_cells", f)
                # R6: deterministic_ordering.cells covers building cell arrays.
                _check_cell_order(interaction, f"{bctx}.interaction_cells", f)

            occlusion = b.get("occlusion_cells")
            if not isinstance(occlusion, list):
                f.add(f"{bctx}.occlusion_cells is missing")
            else:
                for cell in _cells_to_tuple(occlusion):
                    if not _in_bounds(cell, columns, rows):
                        f.add(f"{bctx}.occlusion_cells cell {cell} is out of bounds")
                if bid in BUILDING_RECORDS_FROZEN:
                    _compare_cells(occlusion, BUILDING_RECORDS_FROZEN[bid]["occlusion_cells"], f"{bctx}.occlusion_cells", f)
                # R6: deterministic_ordering.cells covers building cell arrays.
                _check_cell_order(occlusion, f"{bctx}.occlusion_cells", f)

            anchor = b.get("render_anchor")
            if not isinstance(anchor, dict):
                f.add(f"{bctx}.render_anchor is missing")
            else:
                _check_unknown_fields(anchor, KNOWN_RENDER_ANCHOR_FIELDS, f"{bctx}.render_anchor", f)
                _check_required_fields(anchor, REQUIRED_RENDER_ANCHOR_FIELDS, f"{bctx}.render_anchor", f)
                if "cell" not in anchor or "normalized" not in anchor or "pixel_offset" not in anchor:
                    f.add(f"{bctx}.render_anchor is missing cell/normalized/pixel_offset")
                else:
                    # R3-1: render anchor cell/normalized/pixel_offset must match frozen exactly.
                    if bid in BUILDING_RECORDS_FROZEN:
                        exp_anchor = BUILDING_RECORDS_FROZEN[bid]["render_anchor"]
                        if anchor.get("cell") != exp_anchor["cell"]:
                            f.add(f"{bctx}.render_anchor.cell must be {exp_anchor['cell']}, got {anchor.get('cell')}")
                        if anchor.get("pixel_offset") != exp_anchor["pixel_offset"]:
                            f.add(f"{bctx}.render_anchor.pixel_offset must be {exp_anchor['pixel_offset']}, got {anchor.get('pixel_offset')}")
                    norm = anchor.get("normalized")
                    if not isinstance(norm, list) or len(norm) != 2 or not all(isinstance(v, (int, float)) for v in norm):
                        f.add(f"{bctx}.render_anchor.normalized must be a list of 2 numbers, got {norm!r}")
                    else:
                        if not all(0.0 <= float(v) <= 1.0 for v in norm):
                            f.add(f"{bctx}.render_anchor.normalized values must be within [0,1], got {norm}")
                        if bid in BUILDING_RECORDS_FROZEN and norm != BUILDING_RECORDS_FROZEN[bid]["render_anchor"]["normalized"]:
                            f.add(f"{bctx}.render_anchor.normalized must be {BUILDING_RECORDS_FROZEN[bid]['render_anchor']['normalized']}, got {norm}")

            if bid in BUILDING_RECORDS_FROZEN and b.get("state") != BUILDING_RECORDS_FROZEN[bid]["state"]:
                f.add(f"{bctx}.state must be '{BUILDING_RECORDS_FROZEN[bid]['state']}', got {b.get('state')!r}")

            layers = b.get("layers")
            if not isinstance(layers, list):
                f.add(f"{bctx}.layers is missing")
                continue
            total_layers += len(layers)
            if len(layers) != 6:
                f.add(f"{bctx}.layers must have exactly 6 layers, got {len(layers)}")
            expected_native = BUILDING_NATIVE_SIZE.get(bid)
            for l_index, layer in enumerate(layers):
                lctx = f"{bctx}.layers[{l_index}]"
                if not isinstance(layer, dict):
                    f.add(f"{lctx} is not an object")
                    continue
                _check_unknown_fields(layer, KNOWN_LAYER_FIELDS, lctx, f)
                _check_required_fields(layer, REQUIRED_LAYER_FIELDS, lctx, f)
                semantic = layer.get("semantic")
                order = layer.get("order")
                filename = layer.get("filename")
                native_size = layer.get("native_size")
                if l_index < len(LAYER_ORDER):
                    if semantic != LAYER_ORDER[l_index]:
                        f.add(f"{lctx}.semantic must be '{LAYER_ORDER[l_index]}' at order {l_index}, got {semantic!r}")
                if order != l_index:
                    f.add(f"{lctx}.order must be {l_index}, got {order!r}")
                if not isinstance(filename, str) or not filename.endswith(".png"):
                    f.add(f"{lctx}.filename is missing or not a .png")
                    continue
                # R3-2: exact filename per (building_id, semantic). A swap between
                # two same-size buildings still fails because filename is tied to
                # the building ID + semantic, not the native size.
                if bid in BUILDING_LAYER_FILENAMES_FROZEN and semantic in BUILDING_LAYER_FILENAMES_FROZEN[bid]:
                    expected_filename = BUILDING_LAYER_FILENAMES_FROZEN[bid][semantic]
                    if filename != expected_filename:
                        f.add(f"{lctx}.filename must be '{expected_filename}' for {bid}/{semantic}, got '{filename}'")
                if filename in contract_b4:
                    f.add(f"{lctx}.filename '{filename}' is duplicated (already used by another layer)")
                contract_b4[filename] = {"building_id": bid, "semantic": semantic, "native_size": native_size, "order": order}
                if not isinstance(native_size, list) or len(native_size) != 2 or not all(isinstance(v, int) for v in native_size):
                    f.add(f"{lctx}.native_size is malformed")
                elif native_size[0] <= 0 or native_size[1] <= 0:
                    f.add(f"{lctx}.native_size must be positive, got {native_size}")
                elif expected_native is not None and tuple(native_size) != expected_native:
                    f.add(f"{lctx}.native_size must be {expected_native}, got {native_size}")
                if matrix is not None and filename in matrix_b4:
                    m_native = matrix_b4[filename]["native_size"]
                    if native_size is not None and native_size != m_native:
                        f.add(f"{lctx}.native_size {native_size} does not match matrix {m_native}")
                    if matrix_b4[filename]["provenance"] != "n006_base":
                        f.add(f"{lctx}.filename '{filename}' provenance must be n006_base, got {matrix_b4[filename]['provenance']}")

        # Spawns
        spawns = m.get("spawns")
        if not isinstance(spawns, list):
            f.add(f"{mctx}.spawns is not a list")
        else:
            map_spawns[map_id] = spawns
            if map_id in NAMED_RECORD_ORDER_FROZEN["spawns"]:
                _check_named_record_order(spawns, NAMED_RECORD_ORDER_FROZEN["spawns"][map_id], f"{mctx}.spawns", f)
            for s in spawns:
                if not isinstance(s, dict):
                    f.add(f"{mctx}.spawns entry is not an object")
                    continue
                _check_unknown_fields(s, KNOWN_SPAWN_FIELDS, f"{mctx}.spawns", f)
                _check_required_fields(s, REQUIRED_SPAWN_FIELDS, f"{mctx}.spawns", f)
                sid = s.get("id")
                pos = s.get("position")
                if not isinstance(sid, str) or not sid:
                    f.add(f"{mctx}.spawns entry is missing id")
                    continue
                if not isinstance(pos, list) or len(pos) != 2 or not all(isinstance(v, int) for v in pos):
                    f.add(f"{mctx}.spawns[{sid}].position is malformed")
                    continue
                if not _in_bounds(tuple(pos), columns, rows):
                    f.add(f"{mctx}.spawns[{sid}].position {tuple(pos)} is out of bounds")
                if sid in SPAWN_FROZEN:
                    exp_map, exp_pos = SPAWN_FROZEN[sid]
                    if exp_map != map_id:
                        f.add(f"{mctx}.spawns[{sid}] belongs to {exp_map}, not {map_id}")
                    if tuple(pos) != exp_pos:
                        f.add(f"{mctx}.spawns[{sid}].position must be {exp_pos}, got {tuple(pos)}")
                else:
                    f.add(f"{mctx}.spawns[{sid}] is not a frozen spawn ID")

        # Exits
        exits = m.get("exits")
        if not isinstance(exits, list):
            f.add(f"{mctx}.exits is not a list")
        else:
            map_exits[map_id] = exits
            if map_id in NAMED_RECORD_ORDER_FROZEN["exits"]:
                _check_named_record_order(exits, NAMED_RECORD_ORDER_FROZEN["exits"][map_id], f"{mctx}.exits", f)
            for e in exits:
                if not isinstance(e, dict):
                    f.add(f"{mctx}.exits entry is not an object")
                    continue
                _check_unknown_fields(e, KNOWN_EXIT_FIELDS, f"{mctx}.exits", f)
                _check_required_fields(e, REQUIRED_EXIT_FIELDS, f"{mctx}.exits", f)
                eid = e.get("id")
                cell = e.get("cell")
                if not isinstance(eid, str) or not eid:
                    f.add(f"{mctx}.exits entry is missing id")
                    continue
                if not isinstance(cell, list) or len(cell) != 2 or not all(isinstance(v, int) for v in cell):
                    f.add(f"{mctx}.exits[{eid}].cell is malformed")
                    continue
                if not _in_bounds(tuple(cell), columns, rows):
                    f.add(f"{mctx}.exits[{eid}].cell {tuple(cell)} is out of bounds")
                if eid in EXIT_FROZEN:
                    exp = EXIT_FROZEN[eid]
                    if exp["map"] != map_id:
                        f.add(f"{mctx}.exits[{eid}] belongs to {exp['map']}, not {map_id}")
                    if tuple(cell) != exp["cell"]:
                        f.add(f"{mctx}.exits[{eid}].cell must be {exp['cell']}, got {tuple(cell)}")
                    if e.get("destination_map_id") != exp["destination_map_id"]:
                        f.add(f"{mctx}.exits[{eid}].destination_map_id must be {exp['destination_map_id']}")
                    if e.get("destination_spawn_id") != exp["destination_spawn_id"]:
                        f.add(f"{mctx}.exits[{eid}].destination_spawn_id must be {exp['destination_spawn_id']}")
                else:
                    f.add(f"{mctx}.exits[{eid}] is not a frozen exit ID")

        # NPC positions (R2-2)
        npcs = m.get("npc_positions")
        if not isinstance(npcs, list):
            f.add(f"{mctx}.npc_positions is not a list")
        else:
            map_npcs[map_id] = npcs
            if map_id in NAMED_RECORD_ORDER_FROZEN["npc_positions"]:
                _check_named_record_order(npcs, NAMED_RECORD_ORDER_FROZEN["npc_positions"][map_id], f"{mctx}.npc_positions", f)
            for n in npcs:
                if not isinstance(n, dict):
                    f.add(f"{mctx}.npc_positions entry is not an object")
                    continue
                _check_unknown_fields(n, KNOWN_NPC_FIELDS, f"{mctx}.npc_positions", f)
                _check_required_fields(n, REQUIRED_NPC_FIELDS, f"{mctx}.npc_positions", f)
                nid = n.get("id")
                pos = n.get("position")
                if not isinstance(nid, str) or not nid:
                    f.add(f"{mctx}.npc_positions entry is missing id")
                    continue
                if not isinstance(pos, list) or len(pos) != 2 or not all(isinstance(v, int) for v in pos):
                    f.add(f"{mctx}.npc[{nid}].position is malformed")
                    continue
                if not _in_bounds(tuple(pos), columns, rows):
                    f.add(f"{mctx}.npc[{nid}].position {tuple(pos)} is out of bounds")
                if (map_id, nid) in NPC_MAP_OVERRIDES:
                    exp = NPC_MAP_OVERRIDES[(map_id, nid)]
                    if tuple(pos) != exp["position"]:
                        f.add(f"{mctx}.npc[{nid}].position must be {exp['position']}, got {tuple(pos)}")
                elif nid in NPC_FROZEN:
                    exp = NPC_FROZEN[nid]
                    if exp["map"] != map_id:
                        f.add(f"{mctx}.npc[{nid}] belongs to {exp['map']}, not {map_id}")
                    if tuple(pos) != exp["position"]:
                        f.add(f"{mctx}.npc[{nid}].position must be {exp['position']}, got {tuple(pos)}")
                else:
                    f.add(f"{mctx}.npc[{nid}] is not a frozen NPC ID")
                approach = n.get("approach_cells")
                if not isinstance(approach, list) or len(approach) == 0:
                    f.add(f"{mctx}.npc[{nid}] has no approach_cells")
                    continue
                seen_approach: set = set()
                for acell in _cells_to_tuple(approach):
                    if acell in seen_approach:
                        f.add(f"{mctx}.npc[{nid}] approach cell {acell} is duplicated")
                    seen_approach.add(acell)
                    if not _in_bounds(acell, columns, rows):
                        f.add(f"{mctx}.npc[{nid}] approach cell {acell} is out of bounds")
                    if not _is_orthogonally_adjacent(acell, tuple(pos)):
                        f.add(f"{mctx}.npc[{nid}] approach cell {acell} is not orthogonally adjacent to {tuple(pos)}")
                if (map_id, nid) in NPC_MAP_OVERRIDES:
                    exp_approach = set(NPC_MAP_OVERRIDES[(map_id, nid)]["approach"])
                elif nid in NPC_FROZEN:
                    exp_approach = set(NPC_FROZEN[nid]["approach"])
                else:
                    exp_approach = None
                if exp_approach is not None:
                    if set(_cells_to_tuple(approach)) != exp_approach:
                        f.add(f"{mctx}.npc[{nid}].approach_cells mismatch: got {sorted(_cells_to_tuple(approach))}, expected {sorted(exp_approach)}")
                # R6: deterministic_ordering.cells covers NPC approach cells;
                # the list must be x ascending, then y ascending.
                _check_cell_order(approach, f"{mctx}.npc[{nid}].approach_cells", f)
                # R5: record-specific `scope` is frozen exactly per (map, npc).
                # Only the farm teaching NPC has scope == "teaching_spawn"; all
                # others must NOT carry a scope field. Tampering or adding a
                # scope field must FAIL.
                expected_scope = NPC_SCOPE_FROZEN.get((map_id, nid))
                has_scope = "scope" in n
                if expected_scope is not None:
                    if not has_scope:
                        f.add(f"{mctx}.npc[{nid}] is missing required field 'scope' (must be {expected_scope!r})")
                    elif n.get("scope") != expected_scope:
                        f.add(f"{mctx}.npc[{nid}].scope must be {expected_scope!r}, got {n.get('scope')!r}")
                else:
                    if has_scope:
                        f.add(f"{mctx}.npc[{nid}] must not carry a 'scope' field, got {n.get('scope')!r}")

        # Water cells (R2-4)
        water = m.get("water_cells", [])
        if not isinstance(water, list):
            f.add(f"{mctx}.water_cells is not a list")
        else:
            map_water[map_id] = water
            # R4: cell records (with 'cell' field) must be x ascending, then y ascending.
            _check_cell_record_order(water, f"{mctx}.water_cells", f)
            water_by_cell: dict = {}
            for w in water:
                if not isinstance(w, dict):
                    f.add(f"{mctx}.water_cells entry is not an object")
                    continue
                _check_unknown_fields(w, KNOWN_WATER_FIELDS, f"{mctx}.water_cells", f)
                _check_required_fields(w, REQUIRED_WATER_FIELDS, f"{mctx}.water_cells", f)
                cell = tuple(w.get("cell")) if isinstance(w.get("cell"), list) and len(w.get("cell")) == 2 else None
                semantic = w.get("semantic")
                if cell is None:
                    f.add(f"{mctx}.water_cells entry has malformed cell")
                    continue
                if semantic not in VALID_WATER_SEMANTICS:
                    f.add(f"{mctx}.water_cells cell {cell} has invalid semantic {semantic!r}")
                if cell in water_by_cell:
                    f.add(f"{mctx}.water_cells cell {cell} has multiple semantics")
                water_by_cell[cell] = semantic
                if not _in_bounds(cell, columns, rows):
                    f.add(f"{mctx}.water_cells cell {cell} is out of bounds")

        # Canal cells (R2-4)
        # R5: canal_cells is a required map field. A frozen explicit empty
        # array (creek_market) must be present; deleting the field must FAIL.
        # Distinguish "field missing" from "explicit empty array".
        if "canal_cells" in m:
            canal = m.get("canal_cells")
        else:
            canal = None
        if not isinstance(canal, list):
            f.add(f"{mctx}.canal_cells is not a list")
        else:
            map_canal[map_id] = canal
            # R4: cell records (with 'cell' field) must be x ascending, then y ascending.
            _check_cell_record_order(canal, f"{mctx}.canal_cells", f)
            canal_by_cell: set = set()
            for c in canal:
                if not isinstance(c, dict):
                    f.add(f"{mctx}.canal_cells entry is not an object")
                    continue
                _check_unknown_fields(c, KNOWN_CANAL_FIELDS, f"{mctx}.canal_cells", f)
                _check_required_fields(c, REQUIRED_CANAL_FIELDS, f"{mctx}.canal_cells", f)
                cell = tuple(c.get("cell")) if isinstance(c.get("cell"), list) and len(c.get("cell")) == 2 else None
                semantic = c.get("semantic")
                if cell is None:
                    f.add(f"{mctx}.canal_cells entry has malformed cell")
                    continue
                if semantic not in VALID_CANAL_SEMANTICS:
                    f.add(f"{mctx}.canal_cells cell {cell} has invalid semantic {semantic!r}")
                if cell in canal_by_cell:
                    f.add(f"{mctx}.canal_cells cell {cell} is duplicated")
                canal_by_cell.add(cell)
                if not _in_bounds(cell, columns, rows):
                    f.add(f"{mctx}.canal_cells cell {cell} is out of bounds")

        # Gather targets
        gather = m.get("gather_targets", [])
        if not isinstance(gather, list):
            f.add(f"{mctx}.gather_targets is not a list")
        else:
            map_gather[map_id] = gather
            if map_id in NAMED_RECORD_ORDER_FROZEN["gather_targets"]:
                _check_named_record_order(gather, NAMED_RECORD_ORDER_FROZEN["gather_targets"][map_id], f"{mctx}.gather_targets", f)
            for g in gather:
                if not isinstance(g, dict):
                    f.add(f"{mctx}.gather_targets entry is not an object")
                    continue
                _check_unknown_fields(g, KNOWN_GATHER_FIELDS, f"{mctx}.gather_targets", f)
                _check_required_fields(g, REQUIRED_GATHER_FIELDS, f"{mctx}.gather_targets", f)
                gid = g.get("id")
                cell = g.get("cell")
                if not isinstance(gid, str) or not gid:
                    f.add(f"{mctx}.gather_targets entry is missing id")
                    continue
                if not isinstance(cell, list) or len(cell) != 2 or not all(isinstance(v, int) for v in cell):
                    f.add(f"{mctx}.gather_targets[{gid}].cell is malformed")
                    continue
                if not _in_bounds(tuple(cell), columns, rows):
                    f.add(f"{mctx}.gather_targets[{gid}].cell {tuple(cell)} is out of bounds")
                if gid in GATHER_FROZEN:
                    exp_map, exp_cell = GATHER_FROZEN[gid]
                    if exp_map != map_id:
                        f.add(f"{mctx}.gather_targets[{gid}] belongs to {exp_map}, not {map_id}")
                    if tuple(cell) != exp_cell:
                        f.add(f"{mctx}.gather_targets[{gid}].cell must be {exp_cell}, got {tuple(cell)}")
                else:
                    f.add(f"{mctx}.gather_targets[{gid}] is not a frozen gather ID")
                # R5: record-specific `required_unlock_id` is frozen exactly per
                # gather ID. Only restored_brook_cache carries it; all others
                # must NOT carry the field. Deleting/tampering must FAIL.
                expected_unlock = GATHER_REQUIRED_UNLOCK_FROZEN.get(gid)
                has_unlock = "required_unlock_id" in g
                if expected_unlock is not None:
                    if not has_unlock:
                        f.add(f"{mctx}.gather_targets[{gid}] is missing required field 'required_unlock_id' (must be {expected_unlock!r})")
                    elif g.get("required_unlock_id") != expected_unlock:
                        f.add(f"{mctx}.gather_targets[{gid}].required_unlock_id must be {expected_unlock!r}, got {g.get('required_unlock_id')!r}")
                else:
                    if has_unlock:
                        f.add(f"{mctx}.gather_targets[{gid}] must not carry a 'required_unlock_id' field, got {g.get('required_unlock_id')!r}")

        # Quest targets
        quest = m.get("quest_targets", [])
        if not isinstance(quest, list):
            f.add(f"{mctx}.quest_targets is not a list")
        else:
            map_quest[map_id] = quest
            if map_id in NAMED_RECORD_ORDER_FROZEN["quest_targets"]:
                _check_named_record_order(quest, NAMED_RECORD_ORDER_FROZEN["quest_targets"][map_id], f"{mctx}.quest_targets", f)
            for q in quest:
                if not isinstance(q, dict):
                    f.add(f"{mctx}.quest_targets entry is not an object")
                    continue
                _check_unknown_fields(q, KNOWN_QUEST_FIELDS, f"{mctx}.quest_targets", f)
                _check_required_fields(q, REQUIRED_QUEST_FIELDS, f"{mctx}.quest_targets", f)
                qid = q.get("id")
                cell = q.get("cell")
                if not isinstance(qid, str) or not qid:
                    f.add(f"{mctx}.quest_targets entry is missing id")
                    continue
                if not isinstance(cell, list) or len(cell) != 2 or not all(isinstance(v, int) for v in cell):
                    f.add(f"{mctx}.quest_targets[{qid}].cell is malformed")
                    continue
                if not _in_bounds(tuple(cell), columns, rows):
                    f.add(f"{mctx}.quest_targets[{qid}].cell {tuple(cell)} is out of bounds")
                key = (map_id, qid)
                if key in QUEST_FROZEN:
                    exp_cell = QUEST_FROZEN[key]
                    if tuple(cell) != exp_cell:
                        f.add(f"{mctx}.quest_targets[{qid}].cell must be {exp_cell}, got {tuple(cell)}")
                    # R6: purpose is frozen exactly per (map, target). Tampering
                    # the purpose text must FAIL with the exact field path.
                    exp_purpose = QUEST_PURPOSE_FROZEN.get(key)
                    if exp_purpose is not None and q.get("purpose") != exp_purpose:
                        f.add(f"{mctx}.quest_targets[{qid}].purpose must be {exp_purpose!r}, got {q.get('purpose')!r}")
                else:
                    f.add(f"{mctx}.quest_targets[{qid}] is not a frozen quest target ID for {map_id}")

        # Landmarks
        landmarks = m.get("landmarks", [])
        if not isinstance(landmarks, list):
            f.add(f"{mctx}.landmarks is not a list")
        else:
            map_landmarks[map_id] = landmarks
            if map_id in NAMED_RECORD_ORDER_FROZEN["landmarks"]:
                _check_named_record_order(landmarks, NAMED_RECORD_ORDER_FROZEN["landmarks"][map_id], f"{mctx}.landmarks", f)
            for lm in landmarks:
                if not isinstance(lm, dict):
                    f.add(f"{mctx}.landmarks entry is not an object")
                    continue
                _check_unknown_fields(lm, KNOWN_LANDMARK_FIELDS, f"{mctx}.landmarks", f)
                _check_required_fields(lm, REQUIRED_LANDMARK_FIELDS, f"{mctx}.landmarks", f)
                lid = lm.get("id")
                anchor = lm.get("anchor")
                if not isinstance(lid, str) or not lid:
                    f.add(f"{mctx}.landmarks entry is missing id")
                    continue
                if not isinstance(anchor, list) or len(anchor) != 2 or not all(isinstance(v, int) for v in anchor):
                    f.add(f"{mctx}.landmarks[{lid}].anchor is malformed")
                    continue
                if not _in_bounds(tuple(anchor), columns, rows):
                    f.add(f"{mctx}.landmarks[{lid}].anchor {tuple(anchor)} is out of bounds")
                if lid in LANDMARK_FROZEN:
                    exp_map, exp_anchor = LANDMARK_FROZEN[lid]
                    if exp_map != map_id:
                        f.add(f"{mctx}.landmarks[{lid}] belongs to {exp_map}, not {map_id}")
                    if tuple(anchor) != exp_anchor:
                        f.add(f"{mctx}.landmarks[{lid}].anchor must be {exp_anchor}, got {tuple(anchor)}")
                else:
                    f.add(f"{mctx}.landmarks[{lid}] is not a frozen landmark ID")

        # farm_area
        # R5: farm_area is a required map field. creek_market freezes it as an
        # explicit null; farm_homestead freezes a full object. Deleting the
        # field must FAIL even when the frozen value is null (distinguish
        # "field missing" from "explicit null").
        if "farm_area" in m:
            farm_area = m.get("farm_area")
        else:
            farm_area = None
        if farm_area is not None:
            if not isinstance(farm_area, dict):
                f.add(f"{mctx}.farm_area is not an object")
            else:
                _check_unknown_fields(farm_area, KNOWN_FARM_AREA_FIELDS, f"{mctx}.farm_area", f)
                _check_required_fields(farm_area, KNOWN_FARM_AREA_FIELDS, f"{mctx}.farm_area", f)
                map_farm_area[map_id] = farm_area
                for rect in farm_area.get("primary_rectangles", []):
                    if not isinstance(rect, list) or len(rect) != 4 or not all(isinstance(v, int) for v in rect):
                        f.add(f"{mctx}.farm_area.primary_rectangles entry is malformed")
                for cell in farm_area.get("starting_cells", []):
                    if not isinstance(cell, list) or len(cell) != 2:
                        f.add(f"{mctx}.farm_area.starting_cells entry is malformed")
                    elif not _in_bounds(tuple(cell), columns, rows):
                        f.add(f"{mctx}.farm_area.starting_cells cell {tuple(cell)} is out of bounds")
                for cell in farm_area.get("rear_cultivable_cells", []):
                    if not isinstance(cell, list) or len(cell) != 2:
                        f.add(f"{mctx}.farm_area.rear_cultivable_cells entry is malformed")
                    elif not _in_bounds(tuple(cell), columns, rows):
                        f.add(f"{mctx}.farm_area.rear_cultivable_cells cell {tuple(cell)} is out of bounds")
                if map_id in FARM_AREA_FROZEN and FARM_AREA_FROZEN[map_id] is not None:
                    exp_fa = FARM_AREA_FROZEN[map_id]
                    if farm_area.get("primary_rectangles") != exp_fa["primary_rectangles"]:
                        f.add(f"{mctx}.farm_area.primary_rectangles must be {exp_fa['primary_rectangles']}, got {farm_area.get('primary_rectangles')}")
                    if farm_area.get("starting_cells") != exp_fa["starting_cells"]:
                        f.add(f"{mctx}.farm_area.starting_cells must be {exp_fa['starting_cells']}, got {farm_area.get('starting_cells')}")
                    if farm_area.get("rear_cultivable_cells") != exp_fa["rear_cultivable_cells"]:
                        f.add(f"{mctx}.farm_area.rear_cultivable_cells must be {exp_fa['rear_cultivable_cells']}, got {farm_area.get('rear_cultivable_cells')}")
                    if farm_area.get("legacy_farm_cells_remain_valid") != exp_fa["legacy_farm_cells_remain_valid"]:
                        f.add(f"{mctx}.farm_area.legacy_farm_cells_remain_valid must be {exp_fa['legacy_farm_cells_remain_valid']}")
                    # R6: deterministic_ordering.cells covers farm_area.starting_cells;
                    # the list must be x ascending, then y ascending.
                    _check_cell_order(farm_area.get("starting_cells", []), f"{mctx}.farm_area.starting_cells", f)
                    _check_cell_order(farm_area.get("rear_cultivable_cells", []), f"{mctx}.farm_area.rear_cultivable_cells", f)
        elif map_id in FARM_AREA_FROZEN and FARM_AREA_FROZEN[map_id] is not None:
            f.add(f"{mctx}.farm_area is missing (must be present for this map)")
        elif map_id in FARM_AREA_FROZEN and FARM_AREA_FROZEN[map_id] is None:
            # Frozen null: field present with explicit null is the frozen value.
            # No additional check required; absence was already rejected above.
            pass

    # Rule 2: exactly two frozen map IDs, in frozen stable order (R3-4).
    if sorted(map_ids_seen) != sorted(EXPECTED_MAPS):
        f.add(f"maps must be exactly {sorted(EXPECTED_MAPS)}, got {sorted(map_ids_seen)}")
    if map_ids_seen != MAP_ARRAY_ORDER_FROZEN:
        f.add(f"maps array order must be {MAP_ARRAY_ORDER_FROZEN}, got {map_ids_seen}")

    # Rule 3: five buildings.
    all_building_ids: list[str] = []
    for buildings in map_buildings.values():
        for b in buildings:
            if isinstance(b, dict) and isinstance(b.get("id"), str):
                all_building_ids.append(b["id"])
    if sorted(all_building_ids) != sorted(EXPECTED_BUILDINGS.keys()):
        missing = set(EXPECTED_BUILDINGS) - set(all_building_ids)
        extra = set(all_building_ids) - set(EXPECTED_BUILDINGS)
        if missing:
            f.add(f"missing buildings: {sorted(missing)}")
        if extra:
            f.add(f"fabricated buildings: {sorted(extra)}")

    # R2-2: stable entity completeness.
    all_spawn_ids: list[str] = []
    for spawns in map_spawns.values():
        for s in spawns:
            if isinstance(s, dict) and isinstance(s.get("id"), str):
                all_spawn_ids.append(s["id"])
    if sorted(all_spawn_ids) != sorted(SPAWN_FROZEN.keys()):
        f.add(f"spawns must be exactly {sorted(SPAWN_FROZEN.keys())}, got {sorted(all_spawn_ids)}")

    all_exit_ids: list[str] = []
    for exits in map_exits.values():
        for e in exits:
            if isinstance(e, dict) and isinstance(e.get("id"), str):
                all_exit_ids.append(e["id"])
    if sorted(all_exit_ids) != sorted(EXIT_FROZEN.keys()):
        f.add(f"exits must be exactly {sorted(EXIT_FROZEN.keys())}, got {sorted(all_exit_ids)}")

    all_npc_ids: list[str] = []
    for npcs in map_npcs.values():
        for n in npcs:
            if isinstance(n, dict) and isinstance(n.get("id"), str):
                all_npc_ids.append(n["id"])
    # Expected NPC multiset: 7 unique stable IDs, with water_apprentice present
    # on both maps (farm teaching_spawn + market mainline).
    expected_npc_multiset = sorted(list(NPC_FROZEN.keys()) + ["brookseed.npc.water_apprentice"])
    if sorted(all_npc_ids) != expected_npc_multiset:
        missing = [x for x in expected_npc_multiset if expected_npc_multiset.count(x) > all_npc_ids.count(x)]
        extra = [x for x in all_npc_ids if all_npc_ids.count(x) > expected_npc_multiset.count(x)]
        if missing:
            f.add(f"missing NPCs: {sorted(set(missing))}")
        if extra:
            f.add(f"fabricated NPCs: {sorted(set(extra))}")

    # Rule 5 / R2-1: 30 layers exact mapping vs matrix.
    if matrix is not None:
        contract_filenames = set(contract_b4.keys())
        matrix_filenames = set(matrix_b4.keys())
        if contract_filenames != matrix_filenames:
            missing = matrix_filenames - contract_filenames
            extra = contract_filenames - matrix_filenames
            if missing:
                f.add(f"B4 filenames missing from contract: {sorted(missing)}")
            if extra:
                f.add(f"B4 filenames in contract but missing from matrix: {sorted(extra)}")

    # Rule 6: blocked union + overlaps.
    all_blocked_cells: dict[str, set] = {}
    for map_id in map_ids_seen:
        if map_id not in map_dimensions:
            continue
        columns, rows = map_dimensions[map_id]
        water_cells = {tuple(w["cell"]) for w in map_water.get(map_id, []) if isinstance(w, dict) and isinstance(w.get("cell"), list) and len(w["cell"]) == 2}
        canal_cells = {tuple(c["cell"]) for c in map_canal.get(map_id, []) if isinstance(c, dict) and isinstance(c.get("cell"), list) and len(c["cell"]) == 2}
        boundary_cells = set(_cells_to_tuple(map_boundary.get(map_id, [])))
        obstacle_cells = set(_cells_to_tuple(map_static_obstacles.get(map_id, [])))
        npc_cells = {tuple(n["position"]) for n in map_npcs.get(map_id, []) if isinstance(n, dict) and isinstance(n.get("position"), list) and len(n["position"]) == 2}
        spawn_cells = {tuple(s["position"]) for s in map_spawns.get(map_id, []) if isinstance(s, dict) and isinstance(s.get("position"), list) and len(s["position"]) == 2}
        exit_cells = {tuple(e["cell"]) for e in map_exits.get(map_id, []) if isinstance(e, dict) and isinstance(e.get("cell"), list) and len(e["cell"]) == 2}

        blocked = water_cells | canal_cells | boundary_cells | obstacle_cells
        building_footprints: list[tuple[str, set]] = []
        for b in map_buildings.get(map_id, []):
            if not isinstance(b, dict):
                continue
            bid = b.get("id")
            for cell in _cells_to_tuple(b.get("collision_cells", [])):
                blocked.add(cell)
            fp = b.get("footprint")
            if isinstance(fp, dict) and isinstance(fp.get("origin"), list) and isinstance(fp.get("width"), int) and isinstance(fp.get("height"), int):
                cells = set(_footprint_cells(tuple(fp["origin"]), fp["width"], fp["height"]))
                building_footprints.append((bid, cells))
        all_blocked_cells[map_id] = blocked

        for i in range(len(building_footprints)):
            for j in range(i + 1, len(building_footprints)):
                overlap = building_footprints[i][1] & building_footprints[j][1]
                if overlap:
                    f.add(f"{map_id}: buildings {building_footprints[i][0]} and {building_footprints[j][0]} overlap at {sorted(overlap)}")

        for bid, cells in building_footprints:
            for cell in cells:
                if cell in water_cells:
                    f.add(f"{map_id}: building {bid} overlaps water cell {cell}")
                if cell in canal_cells:
                    f.add(f"{map_id}: building {bid} overlaps canal cell {cell}")
                if cell in boundary_cells:
                    f.add(f"{map_id}: building {bid} overlaps boundary cell {cell}")
                if cell in obstacle_cells:
                    f.add(f"{map_id}: building {bid} overlaps obstacle cell {cell}")

        for cell in water_cells & canal_cells:
            f.add(f"{map_id}: cell {cell} is both water and canal")

        for s in map_spawns.get(map_id, []):
            if isinstance(s, dict) and isinstance(s.get("position"), list) and len(s["position"]) == 2:
                if tuple(s["position"]) in blocked:
                    f.add(f"{map_id}: spawn {s.get('id')} is blocked")
        for e in map_exits.get(map_id, []):
            if isinstance(e, dict) and isinstance(e.get("cell"), list) and len(e["cell"]) == 2:
                if tuple(e["cell"]) in blocked:
                    f.add(f"{map_id}: exit {e.get('id')} is blocked")
        for n in map_npcs.get(map_id, []):
            if isinstance(n, dict) and isinstance(n.get("position"), list) and len(n["position"]) == 2:
                pos = tuple(n["position"])
                if pos in blocked:
                    f.add(f"{map_id}: npc {n.get('id')} is blocked")
                if pos in exit_cells:
                    f.add(f"{map_id}: npc {n.get('id')} occupies an exit")
                if pos in spawn_cells:
                    f.add(f"{map_id}: npc {n.get('id')} occupies a spawn")
                for b in map_buildings.get(map_id, []):
                    if isinstance(b, dict) and isinstance(b.get("door"), list) and len(b["door"]) == 2:
                        if pos == tuple(b["door"]):
                            f.add(f"{map_id}: npc {n.get('id')} occupies building door {b.get('id')}")
        for b in map_buildings.get(map_id, []):
            if not isinstance(b, dict):
                continue
            door = b.get("door")
            if isinstance(door, list) and len(door) == 2 and tuple(door) in blocked:
                f.add(f"{map_id}: building {b.get('id')} door is blocked")
            for cell in _cells_to_tuple(b.get("interaction_cells", [])):
                if cell in blocked:
                    f.add(f"{map_id}: building {b.get('id')} interaction cell {cell} is blocked")

        for n in map_npcs.get(map_id, []):
            if not isinstance(n, dict):
                continue
            nid = n.get("id")
            pos = n.get("position")
            if not isinstance(pos, list) or len(pos) != 2:
                continue
            approach = n.get("approach_cells", [])
            if not isinstance(approach, list):
                continue
            has_reachable = False
            for acell in _cells_to_tuple(approach):
                if acell in blocked:
                    f.add(f"{map_id}: npc {nid} approach cell {acell} is blocked")
                else:
                    has_reachable = True
            if not has_reachable and len(approach) > 0:
                f.add(f"{map_id}: npc {nid} has no walkable approach cell")

    # R2-4: water/canal topology.
    for map_id in map_ids_seen:
        if map_id not in map_dimensions:
            continue
        columns, rows = map_dimensions[map_id]
        water_cells = {tuple(w["cell"]) for w in map_water.get(map_id, []) if isinstance(w, dict) and isinstance(w.get("cell"), list) and len(w["cell"]) == 2}
        water_by_cell = {tuple(w["cell"]): w.get("semantic") for w in map_water.get(map_id, []) if isinstance(w, dict) and isinstance(w.get("cell"), list) and len(w["cell"]) == 2}

        for cell in water_cells:
            expected = _derive_water_semantic(cell, water_cells, columns, rows)
            actual = water_by_cell.get(cell)
            if expected is not None and actual != expected:
                f.add(f"{map_id}: water cell {cell} semantic must be '{expected}', got '{actual}'")
            elif expected is None:
                f.add(f"{map_id}: water cell {cell} has no valid shoreline derivation (isolated or malformed topology)")

        frozen_water = WATER_FROZEN.get(map_id, {})
        if frozen_water:
            if water_cells != set(frozen_water.keys()):
                missing = set(frozen_water.keys()) - water_cells
                extra = water_cells - set(frozen_water.keys())
                if missing:
                    f.add(f"{map_id}: missing water cells {sorted(missing)}")
                if extra:
                    f.add(f"{map_id}: extra water cells {sorted(extra)}")

        canal_cells = {tuple(c["cell"]) for c in map_canal.get(map_id, []) if isinstance(c, dict) and isinstance(c.get("cell"), list) and len(c["cell"]) == 2}
        canal_by_cell = {tuple(c["cell"]): c.get("semantic") for c in map_canal.get(map_id, []) if isinstance(c, dict) and isinstance(c.get("cell"), list) and len(c["cell"]) == 2}
        frozen_canal = CANAL_FROZEN.get(map_id, {})
        if frozen_canal:
            if canal_cells != set(frozen_canal.keys()):
                missing = set(frozen_canal.keys()) - canal_cells
                extra = canal_cells - set(frozen_canal.keys())
                if missing:
                    f.add(f"{map_id}: missing canal cells {sorted(missing)}")
                if extra:
                    f.add(f"{map_id}: extra canal cells {sorted(extra)}")
        for cell in canal_cells:
            actual = canal_by_cell.get(cell)
            if cell in frozen_canal and actual != frozen_canal[cell]:
                f.add(f"{map_id}: canal cell {cell} semantic must be '{frozen_canal[cell]}', got '{actual}'")
        if canal_cells:
            sem = next(iter(canal_by_cell.values()), None)
            if sem == "ns":
                xs = {c[0] for c in canal_cells}
                ys = sorted(c[1] for c in canal_cells)
                if len(xs) != 1:
                    f.add(f"{map_id}: ns canal must be a single column, got x={sorted(xs)}")
                else:
                    for i in range(len(ys) - 1):
                        if ys[i + 1] - ys[i] != 1:
                            f.add(f"{map_id}: ns canal is not vertically contiguous at y={ys[i]}..{ys[i+1]}")
            elif sem == "ew":
                ys = {c[1] for c in canal_cells}
                xs = sorted(c[0] for c in canal_cells)
                if len(ys) != 1:
                    f.add(f"{map_id}: ew canal must be a single row, got y={sorted(ys)}")
                else:
                    for i in range(len(xs) - 1):
                        if xs[i + 1] - xs[i] != 1:
                            f.add(f"{map_id}: ew canal is not horizontally contiguous at x={xs[i]}..{xs[i+1]}")

    # Rule 8 / R2-3: reachability.
    reachability = contract.get("reachability")
    if not isinstance(reachability, dict):
        f.add("contract.reachability is missing")
    else:
        _check_unknown_fields(reachability, KNOWN_REACHABILITY_FIELDS, "reachability", f)
        _check_required_fields(reachability, REQUIRED_REACHABILITY_FIELDS, "reachability", f)
        if reachability.get("movement") != "orthogonal_4_way":
            f.add(f"reachability.movement must be 'orthogonal_4_way', got {reachability.get('movement')!r}")
        pairs = reachability.get("required_pairs")
        if not isinstance(pairs, list):
            f.add("reachability.required_pairs is missing or not a list")
            pairs = []
        summary["reachable_required_target_count"] = len(pairs)

        expected_pairs: list[tuple[str, str, tuple, tuple]] = []
        farm_wake = (7, 6)
        expected_pairs += [
            ("wake_to_exit", "brookseed.map.farm_homestead", farm_wake, (7, 0)),
            ("wake_to_farm_area", "brookseed.map.farm_homestead", farm_wake, (4, 3)),
            ("wake_to_farm_house", "brookseed.map.farm_homestead", farm_wake, (3, 7)),
            ("wake_to_farm_sluice", "brookseed.map.farm_homestead", farm_wake, (12, 7)),
            ("wake_to_farm_moss", "brookseed.map.farm_homestead", farm_wake, (12, 6)),
            ("wake_to_farm_reed", "brookseed.map.farm_homestead", farm_wake, (11, 1)),
            ("wake_to_farm_wood", "brookseed.map.farm_homestead", farm_wake, (1, 6)),
            ("wake_to_teaching_npc", "brookseed.map.farm_homestead", farm_wake, (8, 5)),
        ]
        market_spawn = (9, 11)
        expected_pairs += [
            ("market_spawn_to_exit", "brookseed.map.creek_market", market_spawn, (9, 12)),
            ("market_spawn_to_creek_warden", "brookseed.map.creek_market", market_spawn, (13, 8)),
            ("market_spawn_to_neighbor_consensus", "brookseed.map.creek_market", market_spawn, (7, 10)),
            ("market_spawn_to_neighbor_evidence", "brookseed.map.creek_market", market_spawn, (11, 5)),
            ("market_spawn_to_neighbor_hearsay", "brookseed.map.creek_market", market_spawn, (5, 6)),
            ("market_spawn_to_neighbor_storyteller", "brookseed.map.creek_market", market_spawn, (7, 5)),
            ("market_spawn_to_seed_shed", "brookseed.map.creek_market", market_spawn, (1, 8)),
            ("market_spawn_to_seed_steward", "brookseed.map.creek_market", market_spawn, (4, 8)),
            ("market_spawn_to_warden_post", "brookseed.map.creek_market", market_spawn, (16, 8)),
            ("market_spawn_to_water_apprentice", "brookseed.map.creek_market", market_spawn, (3, 5)),
            ("market_spawn_to_wharf", "brookseed.map.creek_market", market_spawn, (3, 5)),
            ("market_spawn_to_market_moss", "brookseed.map.creek_market", market_spawn, (15, 4)),
            ("market_spawn_to_market_reed", "brookseed.map.creek_market", market_spawn, (12, 4)),
            ("market_spawn_to_market_wood", "brookseed.map.creek_market", market_spawn, (6, 4)),
            ("market_spawn_to_restored_brook", "brookseed.map.creek_market", market_spawn, (16, 3)),
        ]
        expected_names = {p[0] for p in expected_pairs}
        actual_by_name: dict[str, dict] = {}
        for p_index, p in enumerate(pairs):
            pctx = f"reachability.required_pairs[{p_index}]"
            if not isinstance(p, dict):
                f.add(f"{pctx} is not an object")
                continue
            _check_unknown_fields(p, KNOWN_PAIR_FIELDS, pctx, f)
            _check_required_fields(p, REQUIRED_PAIR_FIELDS, pctx, f)
            name = p.get("name")
            mid = p.get("map_id")
            start = p.get("from")
            target = p.get("to")
            if not isinstance(name, str):
                f.add(f"{pctx}.name is missing")
                continue
            if name in actual_by_name:
                f.add(f"{pctx}.name '{name}' is duplicated")
            actual_by_name[name] = {"map_id": mid, "from": start, "to": target}
            if mid not in map_dimensions:
                f.add(f"{pctx}.map_id '{mid}' is unknown")
                continue
            columns, rows = map_dimensions[mid]
            if not isinstance(start, list) or len(start) != 2 or not isinstance(target, list) or len(target) != 2:
                f.add(f"{pctx} has malformed from/to")
                continue
            blocked = all_blocked_cells.get(mid, set())
            if not _in_bounds(tuple(start), columns, rows):
                f.add(f"{pctx}.from {tuple(start)} is out of bounds")
            if not _in_bounds(tuple(target), columns, rows):
                f.add(f"{pctx}.to {tuple(target)} is out of bounds")
            if tuple(start) in blocked:
                f.add(f"{pctx}.from {tuple(start)} is blocked")
            if tuple(target) in blocked:
                f.add(f"{pctx}.to {tuple(target)} is blocked")
            if not _bfs_reachable(tuple(start), tuple(target), blocked, columns, rows):
                f.add(f"{pctx} '{name}' is unreachable: {tuple(start)} -> {tuple(target)}")

        if set(actual_by_name.keys()) != expected_names:
            missing = expected_names - set(actual_by_name.keys())
            extra = set(actual_by_name.keys()) - expected_names
            if missing:
                f.add(f"reachability.required_pairs missing required pairs: {sorted(missing)}")
            if extra:
                f.add(f"reachability.required_pairs has fabricated pairs: {sorted(extra)}")
        else:
            for e in expected_pairs:
                ename, emap, efrom, eto = e
                a = actual_by_name.get(ename)
                if a is None:
                    continue
                if a["map_id"] != emap:
                    f.add(f"pair '{ename}' map_id must be {emap}, got {a['map_id']}")
                if a["from"] != list(efrom):
                    f.add(f"pair '{ename}' from must be {list(efrom)}, got {a['from']}")
                if a["to"] != list(eto):
                    f.add(f"pair '{ename}' to must be {list(eto)}, got {a['to']}")

    # R2-5: HUD safe zones + save relocation.
    hud = contract.get("hud")
    if not isinstance(hud, dict):
        f.add("contract.hud is missing")
    else:
        _check_unknown_fields(hud, KNOWN_HUD_FIELDS, "hud", f)
        _check_required_fields(hud, REQUIRED_HUD_FIELDS, "hud", f)
        behavior = hud.get("behavior")
        if not isinstance(behavior, dict):
            f.add("hud.behavior is missing")
        else:
            _check_unknown_fields(behavior, KNOWN_HUD_BEHAVIOR_FIELDS, "hud.behavior", f)
            _check_required_fields(behavior, REQUIRED_HUD_BEHAVIOR_FIELDS, "hud.behavior", f)
            if behavior.get("building_card") != HUD_BEHAVIOR_FROZEN["building_card"]:
                f.add("hud.behavior.building_card does not match frozen contract")
            if behavior.get("debug_layer") != HUD_BEHAVIOR_FROZEN["debug_layer"]:
                f.add("hud.behavior.debug_layer does not match frozen contract")
            if behavior.get("toast_priority") != HUD_BEHAVIOR_FROZEN["toast_priority"]:
                f.add(f"hud.behavior.toast_priority must be {HUD_BEHAVIOR_FROZEN['toast_priority']}")
            if behavior.get("transient_feedback_seconds") != HUD_BEHAVIOR_FROZEN["transient_feedback_seconds"]:
                f.add("hud.behavior.transient_feedback_seconds must be 2.5")

        safe_zones = hud.get("safe_zones")
        if not isinstance(safe_zones, list) or len(safe_zones) != 2:
            f.add("hud.safe_zones must have exactly 2 entries")
        else:
            viewports = set()
            for z_index, z in enumerate(safe_zones):
                zctx = f"hud.safe_zones[{z_index}]"
                if not isinstance(z, dict):
                    f.add(f"{zctx} is not an object")
                    continue
                _check_unknown_fields(z, KNOWN_SAFE_ZONE_FIELDS, zctx, f)
                _check_required_fields(z, REQUIRED_SAFE_ZONE_FIELDS, zctx, f)
                vp = z.get("viewport")
                if not isinstance(vp, list) or len(vp) != 2 or not all(isinstance(v, int) for v in vp):
                    f.add(f"{zctx}.viewport is malformed")
                    continue
                viewports.add(tuple(vp))
                if z.get("origin") != "top_left":
                    f.add(f"{zctx}.origin must be 'top_left'")
                rect_names = [
                    "world_safe_rect_default", "world_safe_rect_near_building",
                    "status_left", "status_right", "toolbelt", "toast",
                    "context_prompt", "building_card_near", "building_card_expanded",
                ]
                for rn in rect_names:
                    if rn not in z:
                        f.add(f"{zctx} is missing '{rn}'")
                        continue
                    _check_rect(z[rn], tuple(vp), rn, zctx, f)
                if tuple(vp) in HUD_FROZEN:
                    for rn, exp in HUD_FROZEN[tuple(vp)].items():
                        if rn in z and z[rn] != exp:
                            f.add(f"{zctx}.{rn} must be {exp}, got {z[rn]}")
                fixed = ["status_left", "status_right", "toolbelt", "toast", "context_prompt"]
                for i in range(len(fixed)):
                    for j in range(i + 1, len(fixed)):
                        a = z.get(fixed[i])
                        b = z.get(fixed[j])
                        if isinstance(a, list) and len(a) == 4 and isinstance(b, list) and len(b) == 4:
                            if _rects_overlap(a, b):
                                f.add(f"{zctx}: {fixed[i]} and {fixed[j]} overlap")
            if viewports != {(960, 640), (1280, 800)}:
                f.add(f"hud.safe_zones viewports must be exactly 960x640 and 1280x800, got {sorted(viewports)}")

    save_relocation = contract.get("save_relocation")
    if not isinstance(save_relocation, dict):
        f.add("contract.save_relocation is missing")
        summary["save_relocation_rule_count"] = 0
    else:
        _check_unknown_fields(save_relocation, KNOWN_SAVE_RELOCATION_FIELDS, "save_relocation", f)
        _check_required_fields(save_relocation, REQUIRED_SAVE_RELOCATION_FIELDS, "save_relocation", f)
        summary["save_relocation_rule_count"] = 1
        for key, exp in SAVE_RELOCATION_FROZEN.items():
            if key == "nearest_safe_rule":
                nrs = save_relocation.get("nearest_safe_rule")
                if not isinstance(nrs, dict):
                    f.add("save_relocation.nearest_safe_rule is missing")
                else:
                    _check_unknown_fields(nrs, KNOWN_NEAREST_SAFE_FIELDS, "nearest_safe_rule", f)
                    _check_required_fields(nrs, REQUIRED_NEAREST_SAFE_FIELDS, "nearest_safe_rule", f)
                    if nrs.get("distance") != exp["distance"]:
                        f.add("nearest_safe_rule.distance must be 'manhattan'")
                    if nrs.get("tie_break") != exp["tie_break"]:
                        f.add(f"nearest_safe_rule.tie_break must be {exp['tie_break']}")
                    if nrs.get("candidate") != exp["candidate"]:
                        f.add("nearest_safe_rule.candidate does not match frozen contract")
            elif key == "coordinate_records":
                cr = save_relocation.get("coordinate_records")
                if not isinstance(cr, dict):
                    f.add("save_relocation.coordinate_records is missing")
                else:
                    _check_unknown_fields(cr, KNOWN_COORDINATE_RECORDS_FIELDS, "coordinate_records", f)
                    _check_required_fields(cr, REQUIRED_COORDINATE_RECORDS_FIELDS, "coordinate_records", f)
                    for ck, cv in exp.items():
                        if cr.get(ck) != cv:
                            f.add(f"save_relocation.coordinate_records.{ck} does not match frozen contract")
            else:
                if save_relocation.get(key) != exp:
                    f.add(f"save_relocation.{key} must be {exp!r}, got {save_relocation.get(key)!r}")

    # Rule 13: forbidden scope.
    forbidden = contract.get("forbidden_scope")
    expected_forbidden = [
        "N-014 candidate content", "dialogue changes", "economy changes",
        "formal audio production", "item or recipe changes", "quest rule changes",
        "save schema changes", "stable ID changes",
    ]
    if forbidden != expected_forbidden:
        f.add(f"forbidden_scope mismatch: got {forbidden}, expected {expected_forbidden}")

    # Rule 10: forbidden diagnostic markers.
    contract_text = json.dumps(contract, ensure_ascii=False, sort_keys=True)
    for marker in FORBIDDEN_DIAGNOSTIC_MARKERS:
        if marker in contract_text:
            f.add(f"contract contains forbidden diagnostic marker '{marker}'")

    # Rule 14 / R2-6: spec consistency.
    if spec_text:
        for label in ["木构农舍", "铜闸水工坊", "苔石埠头", "种源棚", "巡护亭"]:
            if label not in spec_text:
                f.add(f"spec is missing building label '{label}'")

    summary["map_count"] = len(map_ids_seen)
    summary["building_count"] = total_buildings
    summary["building_layer_count"] = total_layers
    return f, summary


def build_result(failures: Failures, summary: dict, contract_path: Path) -> dict:
    result = "PASS" if not failures else "FAIL"
    return {
        "schema_version": SCHEMA_VERSION,
        "task": TASK,
        "decision_id": DECISION_ID,
        "result": result,
        "failures": failures.items,
        "summary": summary,
        "contract_sha256": _sha256(contract_path),
    }


def write_evidence(evidence_dir: Path, result: dict, contract_path: Path, spec_path: Path, negative_cases: list[dict], boundary_report: dict, test_summary: dict) -> None:
    evidence_dir.mkdir(parents=True, exist_ok=True)
    (evidence_dir / "validator-result.json").write_text(
        json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (evidence_dir / "negative-case-summary.json").write_text(
        json.dumps(negative_cases, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (evidence_dir / "contract-sha256.txt").write_text(
        f"{_sha256(contract_path)}  {contract_path.name}\n"
        f"{_sha256(spec_path)}  {spec_path.name}\n",
        encoding="utf-8",
    )
    (evidence_dir / "file-boundary-report.json").write_text(
        json.dumps(boundary_report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (evidence_dir / "test-summary.json").write_text(
        json.dumps(test_summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


# ---------------------------------------------------------------------------
# R6: automated coverage audit. This is a permanent validator subcommand, not a
# throwaway script. It mutates the FROZEN contract (never the file itself —
# every candidate is a temporary copy) and runs the actual validator as a
# subprocess for every mutation:
#
#   A. key deletion  — every dict key of the frozen contract is deleted once;
#   B. leaf mutation — every scalar/string/bool/number leaf is replaced with a
#                      type-preserving different value once;
#   C. array reverse — every list with length > 1 whose reversal actually
#                      changes it is reversed once; symmetric lists whose
#                      reversal is a no-op are not mutations and are recorded
#                      explicitly in no_op_reversals (never silently ignored).
#
# Every case must FAIL (exit 1, parseable FAIL JSON, non-empty failures, no
# traceback). Any case that PASSes must be listed in COVERAGE_WHITELIST with an
# explicit semantic reason; an unwhitelisted PASS is a coverage GAP and makes
# the audit exit 1. The emitted evidence JSON is deterministic: case order is
# sorted by (phase, JSON path), the temporary candidate path is fixed, and no
# timestamps or random identifiers appear.
# ---------------------------------------------------------------------------

COVERAGE_AUDIT_VERSION = 1
COVERAGE_WHITELIST: dict[tuple[str, str], str] = {
    # No allowed-PASS path exists: the frozen contract is frozen in full. If a
    # mutation ever passes, that is a genuine coverage gap, not an exception.
}


def _collect_key_locations(node, steps: list) -> list[tuple[list, str]]:
    """Deterministic enumeration of every dict key in the frozen contract.
    Returns (container_steps, key) pairs; dict keys are iterated sorted and
    list indices in order."""
    locations: list[tuple[list, str]] = []
    if isinstance(node, dict):
        for key in sorted(node.keys()):
            locations.append((steps, key))
            locations.extend(_collect_key_locations(node[key], steps + [key]))
    elif isinstance(node, list):
        for i, item in enumerate(node):
            locations.extend(_collect_key_locations(item, steps + [i]))
    return locations


def _collect_leaf_locations(node, steps: list) -> list[list]:
    """Deterministic enumeration of every scalar/string/bool/number leaf.
    Explicit null values are containers' absence markers, not scalar leaves;
    they are covered by the key-deletion phase."""
    locations: list[list] = []
    if isinstance(node, dict):
        for key in sorted(node.keys()):
            locations.extend(_collect_leaf_locations(node[key], steps + [key]))
    elif isinstance(node, list):
        for i, item in enumerate(node):
            locations.extend(_collect_leaf_locations(item, steps + [i]))
    elif node is None:
        pass
    else:
        locations.append(steps)
    return locations


def _collect_array_locations(node, steps: list) -> list[list]:
    """Deterministic enumeration of every list with length > 1. This is a
    superset of the arrays the contract declares stable (deterministic_ordering
    cells/buildings/layers/named_records, the maps array, and every
    immutable_stable_ids list); the frozen-tree layer makes every one of them
    order-sensitive, so reversing any of them must FAIL."""
    locations: list[list] = []
    if isinstance(node, dict):
        for key in sorted(node.keys()):
            locations.extend(_collect_array_locations(node[key], steps + [key]))
    elif isinstance(node, list):
        if len(node) > 1:
            locations.append(steps)
        for i, item in enumerate(node):
            locations.extend(_collect_array_locations(item, steps + [i]))
    return locations


def _get_at(node, steps: list):
    cur = node
    for step in steps:
        cur = cur[step]
    return cur


def _set_at(node, steps: list, value) -> None:
    cur = node
    for step in steps[:-1]:
        cur = cur[step]
    cur[steps[-1]] = value


def _mutate_leaf_value(value):
    """A type-preserving value mutation guaranteed to differ from the original."""
    if isinstance(value, bool):
        return not value
    if isinstance(value, int):
        return value + 1
    if isinstance(value, float):
        return value + 1.0
    if isinstance(value, str):
        return value + " [coverage-mutation]"
    raise TypeError(f"not a scalar leaf: {type(value).__name__}")


def _short(value, limit: int = 40) -> str:
    text = repr(value)
    if len(text) > limit:
        text = text[: limit - 1] + "…"
    return text


def _run_coverage_case(candidate, tmp_path: Path) -> tuple[int, str, list]:
    with tmp_path.open("w", encoding="utf-8") as handle:
        json.dump(candidate, handle, ensure_ascii=False)
    proc = subprocess.run(
        [sys.executable, str(Path(__file__).resolve()), "--contract", str(tmp_path)],
        capture_output=True,
        text=True,
    )
    exit_code = proc.returncode
    try:
        payload = json.loads(proc.stdout or "{}")
    except Exception:  # noqa: BLE001
        payload = {"result": "CRASH", "failures": [proc.stdout[:200]]}
    result = payload.get("result")
    failures = payload.get("failures") or []
    if not isinstance(failures, list):
        failures = [str(failures)]
    return exit_code, result, failures


def run_coverage_audit(evidence_dir: Path, contract_path: Path) -> dict:
    contract = _load_json(contract_path)

    key_locations = _collect_key_locations(contract, [])
    leaf_locations = _collect_leaf_locations(contract, [])
    array_locations = _collect_array_locations(contract, [])

    tmp_path = Path(tempfile.gettempdir()) / "n015-map-coverage-candidate.json"

    # Baseline: the frozen contract itself must PASS.
    baseline_exit, baseline_result, baseline_failures = _run_coverage_case(copy.deepcopy(contract), tmp_path)

    cases: list[dict] = []
    gaps: list[dict] = []
    whitelisted: list[dict] = []

    def record_case(phase: str, path: str, mutation: str, summary_text: str, candidate) -> None:
        exit_code, result, failures = _run_coverage_case(candidate, tmp_path)
        matched = any(isinstance(m, str) and path in m for m in failures)
        case = {
            "phase": phase,
            "json_path": path,
            "mutation": mutation,
            "mutated_value_summary": summary_text,
            "expected": "FAIL",
            "exit": exit_code,
            "result": result,
            "failures": len(failures),
            "matched_failure_path": matched,
            "failure_excerpt": failures[0] if failures else "",
        }
        passed = exit_code == 0 or result != "FAIL" or not failures
        if passed:
            reason = COVERAGE_WHITELIST.get((phase, path))
            if reason is not None:
                case["whitelist_reason"] = reason
                whitelisted.append({"phase": phase, "json_path": path, "reason": reason})
            else:
                case["gap"] = True
                gaps.append({"phase": phase, "json_path": path, "mutation": mutation})
        cases.append(case)

    # Phase A: delete every dict key, one at a time.
    for steps, key in key_locations:
        path = _path_str(steps + [key])
        candidate = copy.deepcopy(contract)
        del _get_at(candidate, steps)[key]
        record_case("key_deletion", path, f"deleted key {key!r}", f"deleted key {key!r}", candidate)

    # Phase B: type-preserving mutation of every scalar leaf, one at a time.
    for steps in leaf_locations:
        path = _path_str(steps)
        original = _get_at(contract, steps)
        mutated = _mutate_leaf_value(original)
        candidate = copy.deepcopy(contract)
        _set_at(candidate, steps, mutated)
        record_case(
            "leaf_mutation",
            path,
            f"{type(original).__name__} {_short(original)} -> {_short(mutated)}",
            f"{type(original).__name__}: {_short(original)} -> {_short(mutated)}",
            candidate,
        )

    # Phase C: reverse every list with length > 1, one at a time. Lists whose
    # reversal is a no-op (symmetric pairs such as [144, 144] or [7, 7]) are
    # NOT mutations — the candidate is byte-for-byte identical to the frozen
    # contract, so PASS is correct. They are recorded explicitly (never
    # silently ignored) in no_op_reversals with the semantic reason.
    no_op_reversals: list[dict] = []
    for steps in array_locations:
        path = _path_str(steps)
        original = _get_at(contract, steps)
        if list(reversed(original)) == original:
            no_op_reversals.append({
                "json_path": path,
                "value": original,
                "reason": "reversal is a no-op on a symmetric list; the candidate is identical to the frozen contract, so this is not a mutation",
            })
            continue
        candidate = copy.deepcopy(contract)
        _get_at(candidate, steps).reverse()
        record_case("array_reverse", path, f"reversed list of length {len(original)}", f"reversed list of length {len(original)}", candidate)

    # Deterministic ordering: group by phase in A/B/C order, then sort by path.
    phase_order = {"key_deletion": 0, "leaf_mutation": 1, "array_reverse": 2}
    cases.sort(key=lambda c: (phase_order[c["phase"]], c["json_path"]))
    no_op_reversals.sort(key=lambda c: c["json_path"])

    passed = [c for c in cases if c["exit"] == 0 or c["result"] != "FAIL" or not c["failures"]]
    phase_counts = {
        "key_deletion": len(key_locations),
        "leaf_mutation": len(leaf_locations),
        "array_reverse": len(array_locations) - len(no_op_reversals),
        "array_reverse_no_op": len(no_op_reversals),
    }
    audit = {
        "coverage_audit_version": COVERAGE_AUDIT_VERSION,
        "deterministic": True,
        "validator": "scripts/validate-n015-map-layout-contract.py",
        "subprocess": True,
        "contract": "docs/game/n-015-map-layout-contract.json",
        "contract_sha256": _sha256(contract_path),
        "baseline": {
            "exit": baseline_exit,
            "result": baseline_result,
            "failures": len(baseline_failures),
        },
        "phase_counts": phase_counts,
        "statistics": {
            "total_cases": len(cases),
            "failed": len(cases) - len(passed),
            "passed": len(passed),
            "whitelisted": len(whitelisted),
            "gaps": len(gaps),
        },
        "whitelist": whitelisted,
        "no_op_reversals": no_op_reversals,
        "cases": cases,
        "gaps": gaps,
    }
    evidence_dir.mkdir(parents=True, exist_ok=True)
    (evidence_dir / "coverage-audit.json").write_text(
        json.dumps(audit, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return audit


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Validate the N-015 map layout contract.")
    parser.add_argument("--contract-only", action="store_true", help="validate the contract only (default behavior)")
    parser.add_argument("--write-evidence", metavar="DIR", help="write evidence files to DIR")
    parser.add_argument("--contract", metavar="PATH", help="path to a contract JSON (negative-test isolation only)")
    parser.add_argument("--reference", metavar="PATH", help="frozen reference contract for the deep leaf-freeze diff (defaults to the frozen contract)")
    parser.add_argument("--coverage-audit", metavar="DIR", help="run the automated coverage audit and write coverage-audit.json to DIR")
    args = parser.parse_args(argv)

    if args.coverage_audit:
        try:
            audit = run_coverage_audit(Path(args.coverage_audit), CONTRACT)
        except Exception as exc:  # noqa: BLE001
            print(json.dumps({"result": "FAIL", "failures": [f"coverage audit crashed: {exc}"]}, ensure_ascii=False, indent=2))
            return 1
        print(json.dumps(audit, ensure_ascii=False, indent=2, sort_keys=True))
        return 0 if audit["statistics"]["gaps"] == 0 else 1

    contract_path = Path(args.contract) if args.contract else CONTRACT
    matrix_path = MATRIX
    spec_path = SPEC
    reference_path = Path(args.reference) if args.reference else None

    try:
        failures, summary = validate_contract(contract_path, matrix_path, spec_path, reference_path=reference_path)
        result = build_result(failures, summary, contract_path)

        if args.write_evidence:
            evidence_dir = Path(args.write_evidence)
            write_evidence(evidence_dir, result, contract_path, spec_path, negative_cases=[], boundary_report={"note": "generated by --write-evidence"}, test_summary={"note": "run XCTest for authoritative counts"})

        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0 if result["result"] == "PASS" else 1
    except Exception as exc:  # noqa: BLE001
        error_result = {
            "schema_version": SCHEMA_VERSION,
            "task": TASK,
            "decision_id": DECISION_ID,
            "result": "FAIL",
            "failures": [f"validator crashed: {exc}"],
            "summary": {},
        }
        print(json.dumps(error_result, ensure_ascii=False, indent=2))
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
