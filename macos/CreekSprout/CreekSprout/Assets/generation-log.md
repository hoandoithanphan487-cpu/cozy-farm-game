# Assets generation log

## N-003 first-round R0 (2026-08-20)

- Generator: `scripts/generate-n003-first-round.py`
- Scope: 4 character idle + 5 mature crops + 3 farm tiles
- Files replaced in this directory: `char_player.png`, `char_water_apprentice.png`, `char_seed_steward.png`, `char_creek_warden.png`, `crop_mist_radish.png`, `crop_stream_leaf.png`, `crop_amber_bean.png`, `crop_bell_berry.png`, `crop_honey_melon.png`, `tile_grass.png`, `tile_tilled.png`, `tile_water_edge.png`
- Spec: characters 32×48, crops 32×32, tiles 24×24; Master Doc §3 palette only; native redraw, not C0 downscale
- Evidence: `artifacts/art-style/n-003-first-round/`
- Not touched: walk sheets, growth stages, buildings, props, FX, UI, N-004

## N-006 runtime batch (historical note)

The remaining PNGs in this folder still come from `scripts/generate-runtime-art-batch.py`. N-006 whole-pack visual sign-off remains with Product Owner and is not claimed by the N-003 first-round pass.

- 生成器：`scripts/generate-runtime-art-batch.py`
- 独立校验器：`scripts/validate-runtime-art-batch.py`
- 正式运行时 PNG：131 张（其中 12 张首轮文件已由 N-003 首轮重绘覆盖）
- 规格：角色 32×48、角色 R1/R2 128×192、作物 32×32、地块 24×24、建筑按 Master Doc §9.5 母画布、其余按 §9.6–§9.7。
- 色票：仅使用 Master Doc §3 的 10 个锁定色；透明像素 RGB 为 0；无半透明软边。
- 概念来源：`artifacts/art-style/` 下既有 C0；运行时资产为目标尺寸逐像素重绘，不是概念图缩小件。
- 审核证据：`artifacts/art-style/runtime-batch-r0/manifest.json`、`validation-report.md` 与分类联系表。
- 世界生机候选 18 张位于 `artifacts/art-style/candidates/runtime-r0/`，不属于正式运行时 Assets。
- 当前门禁：🎨 art 已交付；🧱 tech 规格复核 `APPROVED`；Product Owner 整包目检 `PENDING`。

## N-015 portrait-derived runtime characters R1 (2026-08-25)

- Product Owner request: retain the HD portraits, regenerate the low-pixel map characters from them, and integrate the result.
- Image sources: eight project-owned `Presentation/Portraits/portrait_*_clean_v01.png` files; the HD files remain unchanged.
- Processor: `scripts/process-n015-character-sheets.py`
- Validator: `scripts/validate-n015-character-sheets.py`
- Runtime replacement: 8 idle sprites, 8 four-direction walk sheets, and 3 matching player action sheets.
- Contract: idle 32×48; sheets 128×192 (4×4, down/left/right/up); RGBA binary alpha; bottom-center; nearest-neighbor.
- Generated masters, prior runtime archive, processed output and real-App evidence: `artifacts/integration/n-015-character-r1/`
- Gate: 🎨 art package `READY`; 🧱 tech asset/runtime gates `APPROVED`; 373/373 tests and 17/17 real-App captures pass; Product Owner visual acceptance remains `PENDING`.
