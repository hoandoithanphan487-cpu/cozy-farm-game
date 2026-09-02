# N-015 Codex Phase C Handoff

- Task: N-015 Phase C — production map rearrangement, runtime art, HD presentation paths, and HUD rebuild
- Decision: DEC-035
- Owner: Product Owner
- Implementation status: `READY FOR DEPARTMENT REVIEW`
- Project status: remains `active / PENDING`
- Independent department acceptance: outstanding

## 1. Player-visible result

- `farm_homestead` now renders the frozen 16×15 production topology with the farm house, sluice workshop, field, crossing path, canal, water edge, exits, gather points, and teaching NPC in their DEC-035 positions.
- `creek_market` now renders the frozen 18×14 topology with the wharf, seed shed, warden post, seven NPCs, market routes, water frontage, gather points, and map exit.
- All five map buildings render from six ordered transparent runtime layers: `base`, `structure`, `roof`, `detail`, `interaction`, and `state_fx`. Roof occlusion is presentation-only; collision remains contract-owned.
- Debug placeholder glyphs such as “阻 / 石阶 / 采” and technical ambience banners are absent from the normal scene.
- Runtime characters use bottom-center anchoring and a 1×1.5-cell presentation envelope. HD character art appears on normal dialogue and Q character-information paths without debug injection.
- The compact HUD uses contract safe zones for status, resources, prompt, toast, and toolbelt. Building cards appear only at an approved interaction/door cell, support compact → expanded → dismissed through E, and do not own gameplay state.

## 2. Production implementation files

### Map, consumers, and save safety

- `macos/CreekSprout/CreekSprout/Content/MapDefinition.swift`
- `macos/CreekSprout/CreekSprout/Content/WorldCatalog.swift`
- `macos/CreekSprout/CreekSprout/Content/ContentCatalog.swift`
- `macos/CreekSprout/CreekSprout/Content/ProgressionCatalog.swift`
- `macos/CreekSprout/CreekSprout/Persistence/SaveMigrator.swift`
- `macos/CreekSprout/CreekSprout/Persistence/SaveStore.swift`
- `macos/CreekSprout/CreekSprout/Persistence/SaveValidation.swift`
- `macos/CreekSprout/CreekSprout/Presentation/WorldVisualCatalog.swift`
- `macos/CreekSprout/CreekSprout/Presentation/BuildingVisualPresenter.swift`
- `macos/CreekSprout/CreekSprout/Presentation/RuntimeArtCatalog.swift`
- `macos/CreekSprout/CreekSprout/Presentation/SpriteSheetAnimator.swift`
- `macos/CreekSprout/CreekSprout/FarmScene.swift`

The save codec remains schema v8. Decode now performs the contract relocation step before validation: preserve a safe position; otherwise choose the nearest safe cell by Manhattan distance, then y, then x, excluding blocked cells and NPC cells. Unknown map IDs and damaged saves still fail closed.

### HUD and HD presentation

- `macos/CreekSprout/CreekSprout/ContentView.swift`
- `macos/CreekSprout/CreekSprout/Presentation/HudPresentationState.swift`
- `macos/CreekSprout/CreekSprout/Presentation/BuildingPresentationCatalog.swift`
- `macos/CreekSprout/CreekSprout/Presentation/PortraitPresentationCatalog.swift`

Real-App QA found and fixed two reactive presentation defects: proximity building cards and dialogue portraits now receive explicit scene-state snapshots instead of waiting for an unrelated SwiftUI refresh. The optional Q panel is reset closed at launch.

### Generated B4 runtime art

- 30 PNG files under `macos/CreekSprout/CreekSprout/Assets/building_*.png`
- `artifacts/art-style/runtime-batch-r0/manifest.json` (deterministic B4 hash refresh only)
- `scripts/process-n015-building-runtime-art.py`
- five generated masters under `artifacts/integration/n-015-codex-phase-c/generated-building-masters/`

The processor removes reference backgrounds where needed, quantizes to the project palette, resizes with nearest-neighbor into each contract native size, and derives six non-empty RGBA layers per building. The six runtime layers—not the 2048 display image—are consumed by the SpriteKit production scene.

## 3. Image generation record

ImageGen was used because Phase C required new bitmap runtime masters. The inputs were the five project-owned HD building references in `Presentation/Buildings/`; the outputs are original project-specific pixel-art interpretations rather than copied genre assets.

Final prompt pattern:

> Use the attached project-owned CreekSprout HD building reference as identity and palette guidance. Create an original clean 2D top-down/three-quarter cozy farming-game pixel-art runtime master for the same building. Preserve its recognizable materials, entrance, roof silhouette, and functional props, but simplify them into crisp pixel clusters suitable for a small native map asset. Use the CreekSprout navy/teal/moss/sand/copper palette, strong readable outline, warm highlights, restrained shadow, no text, no characters, no UI, no scene background, and no protected characters or franchise expression. Center the complete building with generous transparent margin; do not crop roof, foundation, door, wheel, dock, or props.

Building-specific additions preserved the house tower/front door, sluice wheel and channel, moss-stone wharf waterline, seed-shed counter and bins, and warden-post teal roof/entry.

## 4. Runtime consumer audit

Authoritative audit: `artifacts/integration/n-015-codex-phase-c/runtime-art-audit.json`

| Measure | Result |
|---|---:|
| Runtime manifest PNGs | 132 |
| Asset-directory PNGs | 132 |
| Resolved production references | 132 |
| B4 building records | 30 integrated |
| Missing / extra | 0 / 0 |
| Dimension / hash / PNG errors | 0 / 0 / 0 |
| Unreferenced | 0 |

Category counts: building 30, character 19, crop 25, FX 16, gather 3, prop 7, tile 22, tool 3, UI 7. The deterministic consumer-matrix validator reports 132 `integrated` records; this is an implementation measurement, not independent visual acceptance.

## 5. Five-building and HD trigger paths

| Building | Runtime footprint | Natural HD trigger used in real App |
|---|---:|---|
| Farm house | 5×4 | Farm `(3,7)`, E expand/close |
| Farm sluice | 5×4 | Farm `(12,7)`, E expand/close |
| Market wharf | 5×2 | Market `(3,5)` |
| Market seed shed | 3×2 | Market `(1,8)`, E expand/close |
| Market warden post | 3×2 | Market `(16,8)`, E expand/close |

Normal-input portrait evidence covers the water apprentice, seed steward, and creek warden. Q character information was opened for the water apprentice. Catalog and fallback tests cover all eight portrait IDs, aspect-fit layout, and unknown/missing-ID safety.

## 6. Real App evidence

- Contact sheet: `artifacts/integration/n-015-codex-phase-c/real-app/contact-sheet.png`
- Machine-readable index with exact window bounds, player positions, and file sizes: `artifacts/integration/n-015-codex-phase-c/real-app/index.json`
- 17 real-window screenshots: `artifacts/integration/n-015-codex-phase-c/real-app/screenshots/`
- Matching live HUD exports: `artifacts/integration/n-015-codex-phase-c/real-app/hud/`
- Reproducible driver: `scripts/capture-n015-phase-c-app-evidence.py`

The route launches `/tmp/CreekSprout-N015-PhaseC/Build/Products/Debug/CreekSprout.app`, injects normal keyboard input, walks from farm spawn through both maps, triggers 5/5 buildings, opens three dialogues and Q character information, resizes the real window to exactly 960×640 and 1280×800, toggles H, and captures the App window ID. It does not use a test host or debug state injection.

## 7. Validation and performance

- Frozen map validator: PASS; 23 reachable targets, 2 maps, 5 buildings, 30 layers, 1 relocation rule.
- Frozen mutation coverage audit: PASS, including all negative cases.
- Phase C targeted tests: PASS for exact topology, reachability, save relocation, 30 RGBA layers/six-child composition, HUD safe zones, and character scale.
- Full XCTest: 373/373 passed; 0 failed, 0 skipped, 0 expected failures.
- `git diff --check`: PASS.

Performance evidence: `artifacts/integration/n-015-codex-phase-c/performance/`

| Metric | Observed | Gate |
|---|---:|---:|
| Frame work P95 | 1.063 ms | ≤16.67 ms |
| Frame work P99 | 17.031 ms | ≤25 ms |
| Map transition P95 | 17.739 ms | <3000 ms |
| RSS start / end / peak | 130.59 / 59.38 / 130.59 MB | end-start <50; peak-start <80 |

The performance harness also verifies reduced-motion static FX behavior, explicit FX cleanup, and no sustained resident-memory growth during the stress route.

## 8. Frozen boundary and scope audit

Verified SHA-256 values:

- map contract: `328c1afd542464353058e47370373b19e5ca003ac6b49496b00ef2c2e723fd51`
- rearrangement spec: `fd8a7dd2127178af7e7290e3bc9c91f0ae88ae92022a728865626e7b95f05997`

`git diff --name-only` is empty for the protected VSCode r6 package:

- `scripts/validate-n015-map-layout-contract.py`
- `macos/CreekSprout/CreekSproutTests/N015MapLayoutContractTests.swift`
- `docs/game/n-015-vscode-map-foundation-handoff.md`
- `artifacts/integration/n-015-vscode-map-foundation/**`

No stable IDs, economy values, recipes, quest rules, dialogue, or save schema were changed by Phase C. N-014 cat-shop content and N-016 formal music were not started.

## 9. Sequential department gates

Because delegation was not authorized, roles were adopted sequentially and cross-department checks were used; none of these replace an independent final department acceptance.

| Boundary | Specialist owner | Cross-department quality owner | Preliminary verdict | Evidence |
|---|---|---|---|---|
| Gameplay → Art | 🎮 gameplay | 🧱 tech | `APPROVED` | frozen validator, reachability, migration tests |
| Art → Tech | 🎨 art | 🎮 gameplay | `APPROVED` | six-layer consumers, B4 audit, real-map screenshots |
| Tech → UX | 🧱 tech | ✨ ux | `APPROVED` | build, full regression, performance, fail-closed loading |
| UX → Content | ✨ ux | 🎭 content | `APPROVED` | safe zones, real input cards/portraits, stable identities |
| Content → Quality review package | 🎭 content | 🛡️ quality | `APPROVED` | stable IDs/dialogue unchanged, indexed App evidence |

## 10. Known issues and remaining gate

- The generated runtime masters and default presentation are ready for independent art/UX judgment, but this handoff does not declare the visual quality `APPROVED`.
- Real-App screenshots exercise three of eight HD NPC portraits; automated catalog/fallback coverage exercises all eight.
- Missing-asset fallback and reduced-motion behavior are covered by production-path tests rather than by intentionally corrupting the real App bundle used for screenshots.
- The repository was already heavily dirty. Phase C preserved unrelated user changes and did not reset, clean, or rewrite the approved VSCode package. Review should use the file groups in this handoff rather than treating the entire worktree as Phase C-owned.
- The project ledger stays `active / PENDING`; it must not be advanced until Product Owner and independent department quality acceptance occur.

Final handoff status: `READY FOR DEPARTMENT REVIEW`.

## 11. Product Owner character rework — portrait-derived R1 (2026-08-25)

After the Product Owner rejected the generic-looking map characters, the eight runtime identities were regenerated from their retained HD portraits and integrated under the existing filenames. This addendum does not modify or replace any HD portrait.

- Added/replaced: 8 idle sprites, 8 four-direction walk sheets, and 3 matching player action sheets.
- Runtime contract: 32×48 idle; 128×192 sheets; 4×4 down/left/right/up; binary alpha; bottom-center; nearest-neighbor.
- Traceable approved override layer: `docs/game/n-015-character-overrides.json`.
- Deterministic processor and validator: `scripts/process-n015-character-sheets.py`, `scripts/validate-n015-character-sheets.py`.
- Asset gate: 19/19 PASS; full runtime audit: 132/132 referenced, 0 errors, 0 unreferenced.
- Full clean XCTest rerun: 373 passed, 0 failed, 0 skipped, 0 expected failures.
- Real-App rerun: 17/17 captures through both maps; character-info screenshot confirms the HD presentation path remains intact.
- Evidence and recoverable pre-replacement archive: `artifacts/integration/n-015-character-r1/`.

Sequential gate result: 🎨 art handoff `READY`; 🧱 tech cross-department validation `APPROVED`; 🛡️ quality integration package `APPROVED`. Product Owner final visual judgment remains `PENDING`, so N-015 stays `active / PENDING`.
