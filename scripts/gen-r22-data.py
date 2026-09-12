#!/usr/bin/env python3
"""Deterministic R22 web-map data generator for N-031 R3.

Sources:
- docs/game/n-015-map-layout-contract.json  (authoritative frozen map contract)
- macos/CreekSprout/CreekSprout/Presentation/WorldLifeCatalog.swift
  (authoritative deterministic world-life placement tables)

Emits two checked-in TypeScript modules under web/creek-sprout/content/:
- r22-map-data.ts   (geometry: cells, buildings, farm area, spawns, exits, ...)
- r22-world-life.ts (decor placements + asset name mapping)

The generator never reads web code; rerunning it with the same authoritative
sources must reproduce byte-identical output (see source-lock hashes).
"""

import hashlib
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTRACT_PATH = os.path.join(ROOT, "docs", "game", "n-015-map-layout-contract.json")
CATALOG_PATH = os.path.join(
    ROOT, "macos", "CreekSprout", "CreekSprout", "Presentation", "WorldLifeCatalog.swift"
)
OUT_DIR = os.path.join(ROOT, "web", "creek-sprout", "content")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def js(value, indent="  "):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).replace(
        ",", ", "
    )


def main():
    with open(CONTRACT_PATH, encoding="utf-8") as fh:
        contract = json.load(fh)
    with open(CATALOG_PATH, encoding="utf-8") as fh:
        swift = fh.read()

    contract_sha = hashlib.sha256(open(CONTRACT_PATH, "rb").read()).hexdigest()
    catalog_sha = hashlib.sha256(open(CATALOG_PATH, "rb").read()).hexdigest()

    # ---- map geometry from the frozen contract ------------------------------
    maps = {}
    for m in contract["maps"]:
        maps[m["id"].split(".")[-1]] = {
            "columns": m["dimensions"]["columns"],
            "rows": m["dimensions"]["rows"],
            "water_cells": [
                {"x": w["cell"][0], "y": w["cell"][1], "semantic": w["semantic"]}
                for w in m["water_cells"]
            ],
            "canal_cells": [
                {"x": c["cell"][0], "y": c["cell"][1], "semantic": c["semantic"]}
                for c in m["canal_cells"]
            ],
            "path_cells": [[c[0], c[1]] for c in m["path_cells"]],
            "boundary_cells": [
                [c[0], c[1]] for c in m["environment_boundary_cells"]
            ],
            "static_obstacles": [[c[0], c[1]] for c in m.get("static_obstacle_cells", [])],
            "farm_area": m.get("farm_area"),
            "buildings": [],
            "spawns": [],
            "exits": [],
            "gather": [],
            "npc_positions": [],
            "quest_targets": [],
        }
        for b in m["buildings"]:
            entry = {
                "id": b["id"],
                "footprint": [[p[0], p[1]] for p in b.get("footprint", [])],
                "collision_cells": [[p[0], p[1]] for p in b.get("collision_cells", [])],
                "door": b.get("door"),
                "interaction_cells": [[p[0], p[1]] for p in b.get("interaction_cells", [])],
                "occlusion_cells": [[p[0], p[1]] for p in b.get("occlusion_cells", [])],
                "render_anchor": b.get("render_anchor"),
                "render_offset_x": b.get("render_offset_x", 0),
                "render_offset_y": b.get("render_offset_y", 0),
                "layers": [
                    {
                        "semantic": l.get("semantic"),
                        "filename": l.get("filename"),
                        "native_width": (l.get("native_size") or [24, 24])[0],
                        "native_height": (l.get("native_size") or [24, 24])[1],
                        "order": l.get("order"),
                    }
                    for l in b.get("layers", [])
                ],
            }
            maps[m["id"].split(".")[-1]]["buildings"].append(entry)
        for s in m["spawns"]:
            maps[m["id"].split(".")[-1]]["spawns"].append(
                {"id": s["id"], "x": s["position"][0], "y": s["position"][1]}
            )
        for e in m["exits"]:
            maps[m["id"].split(".")[-1]]["exits"].append(
                {
                    "id": e["id"],
                    "x": e["cell"][0],
                    "y": e["cell"][1],
                    "destination_map_id": e["destination_map_id"],
                    "destination_spawn_id": e["destination_spawn_id"],
                }
            )
        for g in m["gather_targets"]:
            maps[m["id"].split(".")[-1]]["gather"].append(
                {
                    "id": g["id"],
                    "x": g["cell"][0],
                    "y": g["cell"][1],
                    "required_unlock_id": g.get("required_unlock_id"),
                }
            )
        for n in m["npc_positions"]:
            maps[m["id"].split(".")[-1]]["npc_positions"].append(
                {
                    "id": n["id"],
                    "x": n["position"][0],
                    "y": n["position"][1],
                    "scope": n.get("scope"),
                }
            )
        for q in m["quest_targets"]:
            maps[m["id"].split(".")[-1]]["quest_targets"].append(
                {
                    "id": q["id"],
                    "x": q["cell"][0],
                    "y": q["cell"][1],
                    "purpose": q.get("purpose"),
                }
            )

    # ---- world-life placements parsed from the Swift catalog ----------------
    placement_re = re.compile(
        r"WorldLifePlacement\(kind: \.([A-Za-z0-9]+),\s*cell: GridPosition\(x: (\d+), y: (\d+)\)\)"
    )

    def placements(name):
        start = swift.index(f"private static let {name}")
        # declaration is `...: [WorldLifePlacement] = [`, skip the type bracket
        list_open = swift.index("] = [", start) + 4
        end = swift.find("]", list_open)
        return [
            (k, int(x), int(y))
            for k, x, y in placement_re.findall(swift, list_open, end)
        ]

    def shoreline_call(name):
        pattern = re.compile(
            r"private static let %s = shorelinePlacements\(\s*northColumns: \[([\d,\s]+)\],\s*southColumns: \[([\d,\s]+)\],\s*northRow: (\d+),\s*southRow: (\d+)\s*\)" % name
        )
        match = pattern.search(swift)
        if not match:
            raise SystemExit("shoreline call not found: " + name)

        def ints(text):
            return [int(v) for v in text.split(",") if v.strip() != ""]

        north_row = int(match.group(3))
        south_row = int(match.group(4))
        return ints(match.group(1)), ints(match.group(2)), north_row, south_row

    def shoreline(north_columns, south_columns, north_row, south_row):
        bank = ["bankNorth01", "bankNorth02", "bankNorth03", "bankNorth04"]
        sbank = ["bankSouth01", "bankSouth02", "bankSouth03", "bankSouth04"]
        result = []
        for index, column in enumerate(north_columns):
            result.append((bank[index % 4], column, north_row))
        for index, column in enumerate(south_columns):
            result.append((sbank[(index + 2) % 4], column, south_row))
        return result

    farm_nc, farm_sc, farm_nr, farm_sr = shoreline_call("farmShorelinePlacements")
    farm_shore = shoreline(farm_nc, farm_sc, farm_nr, farm_sr)
    market_nc, market_sc, market_nr, market_sr = shoreline_call("marketShorelinePlacements")
    market_shore = shoreline(market_nc, market_sc, market_nr, market_sr)

    farm_groups = [
        "farmPlacements",
        "farmTreePlacements",
        "farmFencePlacements",
        "farmPasturePlacements",
        "farmNorthBackdropPlacements",
        "farmRiverStonePlacements",
        "farmRearFieldPlacements",
    ]
    market_groups = [
        "marketPlacements",
        "marketTreePlacements",
        "marketNorthBackdropPlacements",
        "marketRiverStonePlacements",
    ]
    farm = []
    for group in farm_groups:
        for kind, x, y in placements(group):
            farm.append({"kind": kind, "x": x, "y": y})
    for kind, x, y in farm_shore:
        farm.append({"kind": kind, "x": x, "y": y})
    market = []
    for group in market_groups:
        for kind, x, y in placements(group):
            market.append({"kind": kind, "x": x, "y": y})
    for kind, x, y in market_shore:
        market.append({"kind": kind, "x": x, "y": y})
    edge_farm = [
        {"kind": k, "x": x, "y": y}
        for k, x, y in placements("farmEdgeLandscape")
    ]
    edge_market = [
        {"kind": k, "x": x, "y": y}
        for k, x, y in placements("marketEdgeLandscape")
    ]

    os.makedirs(OUT_DIR, exist_ok=True)
    header = (
        "// GENERATED FILE - do not edit by hand.\n"
        f"// source n-015-map-layout-contract.json sha256 {contract_sha}\n"
        f"// source WorldLifeCatalog.swift sha256 {catalog_sha}\n"
        "// regenerated deterministically by scripts/gen-r22-data.py\n"
    )
    with open(os.path.join(OUT_DIR, "r22-map-data.ts"), "w", encoding="utf-8") as fh:
        fh.write(header)
        fh.write("export const R22_CONTRACT_SHA = %s;\n" % js(contract_sha))
        fh.write("export const R22_MAPS = %s;\n" % js(maps))
        fh.write("export type R22MapId = keyof typeof R22_MAPS;\n")
    with open(os.path.join(OUT_DIR, "r22-world-life.ts"), "w", encoding="utf-8") as fh:
        fh.write(header)
        fh.write("export const R22_CATALOG_SHA = %s;\n" % js(catalog_sha))
        fh.write("export const WORLD_LIFE = %s;\n" % js({"farm": farm, "market": market}))
        fh.write("export const EDGE_LANDSCAPE = %s;\n" % js({"farm": edge_farm, "market": edge_market}))
    print("OK farm=%d market=%d edge=%d/%d" % (len(farm), len(market), len(edge_farm), len(edge_market)))
    print("contract sha", contract_sha)
    print("catalog sha", catalog_sha)


if __name__ == "__main__":
    sys.exit(main())
