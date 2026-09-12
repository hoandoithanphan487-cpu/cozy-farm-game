// N-031 R3 derived authoritative world geometry (mirror of
// WorldCatalog.swift / MapDefinition.swift / WorldVisualCatalog.swift /
// PixelAssetCatalog.swift decisions). Presentation helpers are pure and
// unit-testable; they never own gameplay rules.

import { R22_MAPS } from './r22-map-data.ts';

export type R22MapId = 'farm' | 'market';
const FULL_ID: Record<R22MapId, 'farm_homestead' | 'creek_market'> = {
  farm: 'farm_homestead',
  market: 'creek_market',
};
import { tileAssetUrl } from './r22-assets.ts';

export type Cell = { x: number; y: number };
export type MapView = {
  id: R22MapId;
  displayName: string;
  columns: number;
  rows: number;
  blocked: Set<string>;
  water: Map<string, 'edgeN' | 'edgeE' | 'edgeS' | 'edgeW' | 'cornerNE' | 'cornerSE' | 'cornerSW' | 'cornerNW' | 'base'>;
  canal: Set<string>;
  canalNS: Set<string>;
  paths: Set<string>;
  boundary: Set<string>;
  staticObstacles: Set<string>;
  doors: Set<string>;
  interactionCells: Map<string, { buildingId: string; landmark: string }>;
  occlusion: Map<string, string[]>; // cell -> building ids covering it
  buildings: R22Building[];
  fieldCells: Set<string>;
  spawns: Map<string, Cell>;
  exits: { cell: Cell; toMap: R22MapId; toSpawn: string }[];
  gather: R22Gather[];
};

export type R22Layer = {
  semantic: string;
  filename: string;
  nativeWidth: number;
  nativeHeight: number;
  order: number;
};

export type R22Building = {
  id: string;
  displayName: string;
  collision: Set<string>;
  footprint: Set<string>;
  door: Cell;
  interaction: Cell[];
  occlusionCells: Cell[];
  renderAnchor: Cell;
  renderOffsetX: number;
  renderOffsetY: number;
  layers: R22Layer[];
  layerPrefix: string;
  specialWharf: boolean;
};

export type R22Gather = {
  id: string;
  slug: string;
  cell: Cell;
  yields: string;
  requiredUnlock?: string;
};

const key = (x: number, y: number) => `${x},${y}`;
export const cellKey = key;

function toMap(mapId: R22MapId): MapView {
  const raw = R22_MAPS[FULL_ID[mapId]];
  const w = raw as unknown as {
    columns: number; rows: number;
    water_cells: Array<{ x: number; y: number; semantic: string }>;
    canal_cells: Array<{ x: number; y: number; semantic: string }>;
    path_cells: number[][]; boundary_cells: number[][];
    static_obstacles: number[][]; farm_area: unknown;
    buildings: Array<{
      id: string; footprint: number[][]; collision_cells: number[][];
      door: [number, number]; interaction_cells: number[][];
      occlusion_cells: number[][];
      render_anchor:
        | { cell: [number, number]; normalized?: [number, number]; pixel_offset?: [number, number] }
        | [number, number];
      render_offset_x: number; render_offset_y: number;
      layers: Array<{ semantic?: string; filename?: string;
        native_width?: number; native_height?: number; order?: number }>;
    }>;
    spawns: Array<{ id: string; x: number; y: number }>;
    exits: Array<{ id: string; x: number; y: number; destination_map_id: string;
      destination_spawn_id: string }>;
    gather: Array<{ id: string; x: number; y: number; required_unlock_id?: string }>;
    npc_positions: Array<{ id: string; x: number; y: number; scope?: string }>;
    quest_targets: Array<{ id: string; x: number; y: number; purpose?: string }>;
  };
  const out: MapView = {
    id: mapId,
    displayName: mapId === 'farm' ? '农场与农舍' : '溪岸集市',
    columns: w.columns,
    rows: w.rows,
    blocked: new Set(),
    water: new Map(),
    canal: new Set(),
    canalNS: new Set(),
    paths: new Set(),
    boundary: new Set(),
    staticObstacles: new Set(),
    doors: new Set(),
    interactionCells: new Map(),
    occlusion: new Map(),
    buildings: [],
    fieldCells: new Set(),
    spawns: new Map(),
    exits: [],
    gather: [],
  };
  for (const waterCell of w.water_cells) {
    const semantic = waterCell.semantic.replaceAll('_', '').toLowerCase();
    out.water.set(
      key(waterCell.x, waterCell.y),
      semantic as WaterSemantic,
    );
  }
  for (const canalCell of w.canal_cells) {
    out.canal.add(key(canalCell.x, canalCell.y));
    if (canalCell.semantic === 'ns') out.canalNS.add(key(canalCell.x, canalCell.y));
  }
  const addCells = (list: number[][], target: Set<string>) =>
    list.forEach(([x, y]) => target.add(key(x, y)));
  addCells(w.path_cells, out.paths);
  addCells(w.boundary_cells, out.boundary);
  addCells(w.static_obstacles ?? [], out.staticObstacles);
  const buildingNames: Record<string, string> = {
    'brookseed.landmark.farm_house': '木构农舍',
    'brookseed.landmark.farm_sluice': '旧铜闸',
    'brookseed.landmark.market_wharf': '苔石埠头',
    'brookseed.landmark.market_seed_shed': '种源棚',
    'brookseed.landmark.market_warden_post': '巡护亭',
  };
  for (const b of w.buildings ?? []) {
    const collision = new Set<string>();
    addCells(b.collision_cells, collision);
    const footprint = new Set<string>();
    addCells(b.footprint, footprint);
    const interaction: Cell[] = (b.interaction_cells ?? []).map(([x, y]) => ({ x, y }));
    const occlusionCells: Cell[] = (b.occlusion_cells ?? []).map(([x, y]) => ({ x, y }));
    const layers = (b.layers ?? []).map((layer) => ({
      semantic: layer.semantic ?? '',
      filename: layer.filename ?? '',
      nativeWidth: (layer.native_width ?? layer.native_height ?? 24) as number,
      nativeHeight: (layer.native_height ?? layer.native_width ?? 24) as number,
      order: layer.order ?? 0,
    }));
    const door = b.door ? { x: b.door[0], y: b.door[1] } : { x: 0, y: 0 };
    out.doors.add(key(door.x, door.y));
    for (const cell of interaction) {
      out.interactionCells.set(key(cell.x, cell.y), {
        buildingId: b.id,
        landmark: buildingNames[b.id] ?? b.id,
      });
    }
    const prefix = (b.id.split('.').pop() ?? '').replace('farm_house', 'farm_house')
      .replace('farm_sluice', 'farm_sluice')
      .replace('market_wharf', 'market_wharf')
      .replace('market_seed_shed', 'market_seed_shed')
      .replace('market_warden_post', 'market_warden_post');
    // Native render_anchor is authored as a placement record:
    // { cell: [x, y], normalized: [0.5, 0.0], pixel_offset: [dx, dy] }.
    // The pixel offset is the authoritative BuildingVisualPresenter root
    // translation in native pixels (positive y runs up in SpriteKit space).
    const anchorCell = Array.isArray(b.render_anchor)
      ? { x: b.render_anchor[0], y: b.render_anchor[1] }
      : b.render_anchor
        ? { x: b.render_anchor.cell[0], y: b.render_anchor.cell[1] }
        : door;
    const anchorPixelOffset = !Array.isArray(b.render_anchor) && b.render_anchor?.pixel_offset
      ? { x: b.render_anchor.pixel_offset[0], y: b.render_anchor.pixel_offset[1] }
      : { x: b.render_offset_x ?? 0, y: b.render_offset_y ?? 0 };
    out.buildings.push({
      id: b.id,
      displayName: buildingNames[b.id] ?? b.id,
      collision,
      footprint,
      door,
      interaction,
      occlusionCells,
      renderAnchor: anchorCell,
      renderOffsetX: anchorPixelOffset.x,
      renderOffsetY: anchorPixelOffset.y,
      layers,
      layerPrefix: prefix,
      specialWharf: b.id === 'brookseed.landmark.market_wharf',
    });
    for (const cell of occlusionCells) {
      const list = out.occlusion.get(key(cell.x, cell.y)) ?? [];
      list.push(b.id);
      out.occlusion.set(key(cell.x, cell.y), list);
    }
  }
  // blocked union: buildings + boundary + water + canal + static obstacles
  out.buildings.forEach((b) =>
    b.collision.forEach((cell) => out.blocked.add(cell)),
  );
  addCells(w.boundary_cells, out.blocked);
  addCells(w.static_obstacles ?? [], out.blocked);
  out.water.forEach((_, cell) => out.blocked.add(cell));
  out.canal.forEach((cell) => out.blocked.add(cell));
  // farm fields
  if (mapId === 'farm') {
    const fa = w.farm_area as {
      primary_rectangles?: number[][];
      rear_cultivable_cells?: number[][];
    } | null;
    const rects = fa?.primary_rectangles ?? [];
    for (const [x, y, width, height] of rects) {
      for (let dy = 0; dy < height; dy += 1)
        for (let dx = 0; dx < width; dx += 1)
          out.fieldCells.add(key(x + dx, y + dy));
    }
    for (const [x, y] of fa?.rear_cultivable_cells ?? [])
      out.fieldCells.add(key(x, y));
  }
  for (const s of w.spawns ?? []) out.spawns.set(s.id, { x: s.x, y: s.y });
  for (const e of w.exits ?? []) {
    out.exits.push({
      cell: { x: e.x, y: e.y },
      toMap: e.destination_map_id.split('.').pop() as R22MapId,
      toSpawn: e.destination_spawn_id,
    });
  }
  const gatherNames: Record<string, string> = {
    'brookseed.gather.farm_wood_cache': '溪木堆',
    'brookseed.gather.farm_reed_cache': '芦丛',
    'brookseed.gather.farm_moss_cache': '苔石堆',
    'brookseed.gather.market_wood_cache': '溪木堆',
    'brookseed.gather.market_reed_cache': '芦丛',
    'brookseed.gather.market_moss_cache': '苔石堆',
    'brookseed.gather.restored_brook_cache': '回流的溪石',
  };
  for (const g of w.gather ?? []) {
    out.gather.push({
      id: g.id,
      slug: g.id.split('.').pop() ?? g.id,
      cell: { x: g.x, y: g.y },
      yields: g.id.includes('wood') ? '溪木' : g.id.includes('reed') ? '芦纤维' : '苔石',
      requiredUnlock: g.required_unlock_id,
    });
    void gatherNames[g.id];
  }
  return out;
}

function buildViews() {
  const farm = toMap('farm' as R22MapId);
  const market = toMap('market' as R22MapId);
  farm.displayName = '农场与农舍';
  market.displayName = '溪岸集市';
  return { farm, market };
}

export const R22_VIEWS = buildViews();

export function view(mapId: R22MapId): MapView {
  return R22_VIEWS[mapId];
}
// ---- presentation path cells (WorldVisualCatalog.presentationPathCells) ----
const FARM_SERVICE_PATH = new Set([
  '1,6', '2,6', '3,6',
  '7,4', '8,4', '9,4', '7,5', '8,5', '9,5', '9,6',
  '7,8', '7,9', '7,10', '7,11',
]);

export function presentationPaths(mapId: R22MapId): Set<string> {
  const v = view(mapId);
  const cells = new Set(v.paths);
  v.doors.forEach((cell) => cells.add(cell));
  if (mapId === 'farm') FARM_SERVICE_PATH.forEach((cell) => cells.add(cell));
  return cells;
}

export function isStonePath(mapId: R22MapId, x: number, y: number): boolean {
  return presentationPaths(mapId).has(key(x, y));
}

// ---- grass/crop tile selection (PixelAssetCatalog mirror) --------------
export function grassVariant(x: number, y: number): string {
  switch (Math.abs(x * 31 + y * 17) % 4) {
    case 1: return 'tile_grass_a';
    case 2: return 'tile_grass_b';
    case 3: return 'tile_grass_c';
    default: return 'tile_grass';
  }
}

export function grassUrl(x: number, y: number): string {
  return tileAssetUrl(grassVariant(x, y));
}

export const CROP_STAGE_ASSETS: Record<string, string[]> = {
  mist_radish: ['crop_mist_radish_stage_0_r3', 'crop_mist_radish_stage_1_r3',
    'crop_mist_radish_stage_2_r3', 'crop_mist_radish_stage_3_r3'],
  stream_leaf: ['crop_stream_leaf_stage_0_r3', 'crop_stream_leaf_stage_1_r3',
    'crop_stream_leaf_stage_2_r3', 'crop_stream_leaf_stage_3_r3'],
  amber_bean: ['crop_amber_bean_stage_0_r3', 'crop_amber_bean_stage_1_r3',
    'crop_amber_bean_stage_2_r3', 'crop_amber_bean_stage_3_r3'],
  bell_berry: ['crop_bell_berry_stage_0_r3', 'crop_bell_berry_stage_1_r3',
    'crop_bell_berry_stage_2_r3', 'crop_bell_berry_stage_3_r3'],
  honey_melon: ['crop_honey_melon_stage_0_r3', 'crop_honey_melon_stage_1_r3',
    'crop_honey_melon_stage_2_r3', 'crop_honey_melon_stage_3_r3'],
};

/** visual stage for a crop: readyToHarvest => 3, else min(progress,0..2) */
export function cropStageAsset(cropId: string, stage: number, ready: boolean) {
  const visual = ready ? 3 : Math.min(Math.max(stage, 0), 2);
  return `${cropId}_stage_${visual}_r3`;
}

// ---- water border overlay keys (WorldVisualCatalog.waterBorder mirror) ----
export type WaterSemantic =
  | 'edgeN' | 'edgeE' | 'edgeS' | 'edgeW'
  | 'cornerNE' | 'cornerSE' | 'cornerSW' | 'cornerNW' | 'base';

export const WATER_OVERLAY: Record<WaterSemantic, string[]> = {
  base: [],
  edgeN: ['tile_water_edge_n'],
  edgeE: ['tile_water_edge_e'],
  edgeS: ['tile_water_edge_s'],
  edgeW: ['tile_water_edge_w'],
  cornerNE: ['tile_water_corner_ne'],
  cornerSE: ['tile_water_corner_se'],
  cornerSW: ['tile_water_corner_sw'],
  cornerNW: ['tile_water_corner_nw'],
};

export function waterPhase(x: number, y: number) {
  return Math.abs(x * 13 + y * 7) % 4;
}
export function canalPhase(y: number) {
  return ((y % 4) + 4) % 4;
}

export const FARM_SLUICE_APRON = { x: 13, y: 8 };
export const MARKET_SLUICE_MOUTH = { x: 3, y: 2 };
export const MARKET_SLUICE_APRON = { x: 3, y: 3 };

/** placement categories that may intentionally sit on landscape boundary */
export function isBlockedCell(mapId: R22MapId, x: number, y: number) {
  return view(mapId).blocked.has(key(x, y));
}

export { tileAssetUrl };
