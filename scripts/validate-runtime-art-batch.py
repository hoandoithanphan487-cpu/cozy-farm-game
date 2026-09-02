#!/usr/bin/env python3
"""Independent contract validator for N-006 generated PNGs."""

import json
import struct
import zlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/"macos/CreekSprout/CreekSprout/Assets"
CAND=ROOT/"artifacts/art-style/candidates/runtime-r0"
EVIDENCE=ROOT/"artifacts/art-style/runtime-batch-r0"
PALETTE={
    (0x26,0x36,0x38,255),(0x55,0x48,0x4A,255),(0x76,0x52,0x47,255),
    (0x78,0x86,0x53,255),(0x78,0x97,0xA0,255),(0x4F,0x70,0x70,255),
    (0xB5,0x8A,0x52,255),(0xC5,0x8A,0x59,255),(0xC6,0x6E,0x3D,255),
    (0xF0,0xD9,0xAD,255),
}

expected={}
chars=["player","water_apprentice","seed_steward","creek_warden","neighbor_hearsay","neighbor_storyteller","neighbor_evidence","neighbor_consensus"]
for s in chars: expected[f"char_{s}.png"]=(32,48); expected[f"char_{s}_walk.png"]=(128,192)
for action in ["hoe","watering_can","harvest_glove"]: expected[f"char_player_action_{action}.png"]=(128,192)
crops=["mist_radish","stream_leaf","amber_bean","bell_berry","honey_melon"]
for s in crops:
    expected[f"crop_{s}.png"]=(32,32)
    for i in range(4): expected[f"crop_{s}_stage_{i}.png"]=(32,32)
for n in ["tile_grass.png","tile_tilled.png","tile_water_edge.png","tile_grass_a.png","tile_grass_b.png","tile_grass_c.png","tile_tilled_watered.png","tile_stone_path.png","tile_canal_ns.png","tile_canal_ew.png"]: expected[n]=(24,24)
for i in range(4): expected[f"tile_water_f{i:02}.png"]=(24,24)
for d in "nesw": expected[f"tile_water_edge_{d}.png"]=(24,24)
for d in ["ne","se","sw","nw"]: expected[f"tile_water_corner_{d}.png"]=(24,24)
buildings={"farm_house":(144,144),"farm_sluice":(192,168),"market_seed_shed":(96,96),"market_warden_post":(96,96),"market_wharf":(144,96)}
for s,size in buildings.items():
    for layer in ["base","structure","roof","detail","interaction","state_fx"]: expected[f"building_{s}_{layer}.png"]=size
expected.update({
    "prop_wooden_crate.png":(24,24),"prop_stone_path.png":(24,24),"prop_compost_rack.png":(48,48),
    "prop_canal_segment_ns.png":(24,24),"prop_canal_segment_ew.png":(24,24),"prop_rain_barrel.png":(24,32),
    "gather_creek_wood.png":(24,24),"gather_moss_stone.png":(24,24),"gather_reed_fiber.png":(24,24),
    "tool_hoe.png":(24,24),"tool_watering_can.png":(24,24),"tool_harvest_glove.png":(24,24),
    "ui_interact_badge.png":(24,24),"ui_slot.png":(24,24),"ui_slot_selected.png":(24,24),
    "ui_time.png":(24,24),"ui_weather.png":(24,24),"ui_stamina.png":(24,24),"ui_currency.png":(24,24),
})
for state in ["valid","invalid"]:
    for i in range(2): expected[f"fx_target_{state}_f{i:02}.png"]=(24,24)
for family,size in [("water_splash",(32,32)),("harvest",(32,32)),("canal_flow",(24,24))]:
    for i in range(4): expected[f"fx_{family}_f{i:02}.png"]=size

candidate={"candidate_building_cat_bbq_shop_r0.png":(144,120)}
for s in ["black","calico","ragdoll"]: candidate[f"candidate_char_cat_bbq_{s}_r0.png"]=(32,48)
for s in ["rabbit","duck","squirrel","hedgehog","frog","bird"]: candidate[f"candidate_ambient_{s}_r0.png"]=(24,24)
for i in range(1,5): candidate[f"candidate_shrub_{i:02}_r0.png"]=(24,24); candidate[f"candidate_flower_clump_{i:02}_r0.png"]=(24,24)

def decode(path):
    data=path.read_bytes(); assert data[:8]==b"\x89PNG\r\n\x1a\n"
    pos=8; idat=b""; width=height=None
    while pos<len(data):
        length=struct.unpack(">I",data[pos:pos+4])[0]; typ=data[pos+4:pos+8]; payload=data[pos+8:pos+8+length]; pos+=12+length
        if typ==b"IHDR": width,height,depth,color,_,_,_=struct.unpack(">IIBBBBB",payload); assert depth==8 and color==6
        elif typ==b"IDAT": idat+=payload
        elif typ==b"IEND": break
    raw=zlib.decompress(idat); stride=width*4; pixels=[]; previous=bytearray(stride); p=0
    for _ in range(height):
        filt=raw[p]; p+=1; scan=bytearray(raw[p:p+stride]); p+=stride
        assert filt==0, f"unsupported PNG filter {filt}"
        pixels.extend(tuple(scan[i:i+4]) for i in range(0,stride,4)); previous=scan
    return width,height,pixels

def validate(base, contract, scope):
    rows=[]
    for name,size in sorted(contract.items()):
        path=base/name
        if not path.exists(): rows.append((name,"MISSING")); continue
        w,h,pixels=decode(path); issues=[]
        if (w,h)!=size: issues.append(f"size {w}x{h} != {size[0]}x{size[1]}")
        alpha={p[3] for p in pixels}
        if not alpha<={0,255}: issues.append(f"alpha {sorted(alpha)}")
        if any(p[3]==0 and p!=(0,0,0,0) for p in pixels): issues.append("dirty transparent RGB")
        if any(p[3] and p not in PALETTE for p in pixels): issues.append("off-palette")
        if not any(p[3] for p in pixels): issues.append("empty image")
        if name.startswith("char_") and (name.endswith("_walk.png") or "_action_" in name):
            baselines=[]
            for row in range(4):
                for col in range(4):
                    ys=[y for y in range(48) for x in range(32) if pixels[(row*48+y)*w+col*32+x][3]]
                    baselines.append(max(ys) if ys else -1)
            if len(set(baselines))!=1: issues.append(f"walking baseline drift {sorted(set(baselines))}")
        rows.append((name,"PASS" if not issues else "; ".join(issues)))
    return rows

runtime_rows=validate(ASSETS,expected,"runtime"); candidate_rows=validate(CAND,candidate,"candidate")
all_rows=runtime_rows+candidate_rows; failed=[r for r in all_rows if r[1]!="PASS"]
manifest=json.loads((EVIDENCE/"manifest.json").read_text())
manifest_names={(r["scope"],r["file"]) for r in manifest["assets"]}
contract_names={("runtime",n) for n in expected}|{("candidate",n) for n in candidate}
if manifest_names!=contract_names: failed.append(("manifest","name set mismatch"))
report=["# N-006 independent pixel contract validation","",f"- Runtime: {sum(s=='PASS' for _,s in runtime_rows)}/{len(runtime_rows)} PASS",f"- Candidate: {sum(s=='PASS' for _,s in candidate_rows)}/{len(candidate_rows)} PASS",f"- Result: {'PASS' if not failed else 'FAIL'}","","## Failures","",*(f"- `{n}`: {s}" for n,s in failed)]
(EVIDENCE/"validation-report.md").write_text("\n".join(report)+"\n")
print(f"runtime={len(runtime_rows)} candidate={len(candidate_rows)} failures={len(failed)} result={'PASS' if not failed else 'FAIL'}")
raise SystemExit(1 if failed else 0)
