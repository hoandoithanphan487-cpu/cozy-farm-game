'use client';

// N-031 R3 layered Canvas world renderer.
// Draws the authoritative R22 maps cell-by-cell from content/r22-map-data.ts,
// mirrors native z/layer/anchor/zoom rules of the macOS SpriteKit app, and
// drives water/canal animation, world-life, gatherers, buildings, crops,
// NPC presence, the player and camera framing. This file is the only world
// source; the legacy DOM/CSS map was deleted in P0-1.

import { useEffect, useRef } from 'react';
import {
  R22_VIEWS,
  presentationPaths,
  isStonePath,
  grassUrl,
  cropStageAsset,
  WATER_OVERLAY,
  waterPhase,
  canalPhase,
  FARM_SLUICE_APRON,
  MARKET_SLUICE_MOUTH,
} from '@/content/r22-world';
import type { R22MapId } from '@/content/r22-world';
import {
  WORLD_LIFE,
  EDGE_LANDSCAPE,
} from '@/content/r22-world-life';
import {
  WORLD_LIFE_ASSET,
  worldLifeKindCategory,
  WORLD_LIFE_SCENIC_LAKE_FRAMES,
  TILE,
  tileAssetUrl,
  ASSETS,
  WORLD,
  SHEET_FRAME_W,
  SHEET_FRAME_H,
  FRAME_ROW,
  NPC_SHEETS,
  ACTION_SHEET,
  FX,
} from '@/content/r22-assets';
import type { WorldLifeKind } from '@/content/r22-assets';
import {
  CROPS,
  NPC_ANCHORS,
  GATHER_ANCHORS,
  getTarget,
  type GameState,
  type Direction,
} from '@/lib/full-game';

const TILE_PX = 24;
export const ZOOM_DESKTOP = 3; // 24-art tile -> 72 css px
export const ZOOM_COMPACT = 2; // 48 css px on narrow viewports

type Presence = {
  id: string;
  map: R22MapId;
  x: number;
  y: number;
  label: string;
};

const PRESENCES: Presence[] = NPC_ANCHORS.map((npc) => ({
  id: npc.id,
  map: npc.map as R22MapId,
  x: npc.x,
  y: npc.y,
  label: npc.label,
}));

export type WorldViewSettings = { reducedMotion: boolean };

export type ToolEventKind = 'hoe' | 'water' | 'harvest';
export type ToolEvent = { kind: ToolEventKind; at: number };

type CanvasWorldProps = {
  game: GameState;
  settings: WorldViewSettings;
  toolEvent: ToolEvent | null;
  onActCell: (x: number, y: number, direction: Direction) => void;
  onPresence: (presenceId: string) => void;
  onTravel: () => void;
};

type LoadedImage = { image: HTMLImageElement; width: number; height: number };

const spriteCache = new Map<string, LoadedImage>();
const pendingRequests = new Map<string, Promise<LoadedImage>>();
export const worldSpriteCache = spriteCache;

export function requestSprite(url: string): Promise<LoadedImage> {
  const cached = spriteCache.get(url);
  if (cached) return Promise.resolve(cached);
  const pending = pendingRequests.get(url);
  if (pending) return pending;
  const promise = new Promise<LoadedImage>((resolve) => {
    const image = new Image();
    image.onload = () => {
      const loaded = { image, width: image.naturalWidth, height: image.naturalHeight };
      spriteCache.set(url, loaded);
      pendingRequests.delete(url);
      resolve(loaded);
    };
    image.onerror = () => {
      pendingRequests.delete(url);
      // mark a transparent 1x1 so the renderer keeps running; audit catches
      // missing files before release
      const loaded = { image: new Image(), width: 0, height: 0 };
      spriteCache.set(url, loaded);
      resolve(loaded);
    };
    image.src = url;
  });
  pendingRequests.set(url, promise);
  return promise;
}

function ensure(url: string) {
  if (!spriteCache.has(url)) void requestSprite(url);
  return spriteCache.get(url);
}

const cellKeyOf = (x: number, y: number) => `${x},${y}`;

export type CameraState = {
  originX: number;
  originY: number;
  zoom: number;
  cell: number;
};

export function cameraFor(
  viewport: { width: number; height: number },
  player: { x: number; y: number },
  mapId: R22MapId,
): CameraState {
  // Native contract: WorldCamera.integerZoom uses viewport >=1200 || >=760.
  const zoom =
    viewport.width >= 1200 || viewport.height >= 760 ? ZOOM_DESKTOP : ZOOM_COMPACT;
  const cell = TILE_PX * zoom;
  const map = R22_VIEWS[mapId];
  const mapPxW = map.columns * cell;
  const mapPxH = map.rows * cell;
  // Native contract: FarmScene.applyCamera frames the world with
  // HudSafeZoneLayout.worldSafeRectDefault (HUD rect x 16, y 92, width-32,
  // height-244), i.e. 92 px of world margin at the top and 152 px at the
  // bottom on the desktop tier — not WorldCamera.framingRect (52/58).
  const safeLeft = 16;
  const safeRight = viewport.width - 16;
  const safeTop = 92;
  const safeBottom = 152;
  const safeWidth = Math.max(safeRight - safeLeft, 1);
  const safeHeight = Math.max(viewport.height - safeTop - safeBottom, 1);
  // Native SpriteKit world space runs south -> north, so a map row index
  // grows towards the top of the screen. originY below is where the map's
  // northern edge lands on screen, hence the player's distance to the north
  // edge is (rows - y - 0.5) cells, exactly like WorldCamera.worldOrigin.
  const playerWorld = { x: (player.x + 0.5) * cell, y: (map.rows - player.y - 0.5) * cell };
  let originX = safeLeft + safeWidth / 2 - playerWorld.x;
  let originY = safeTop + safeHeight / 2 - playerWorld.y;
  if (mapPxW >= safeWidth) {
    originX = Math.min(safeLeft, originX);
    originX = Math.max(safeRight - mapPxW, originX);
  } else originX = safeLeft + (safeWidth - mapPxW) / 2;
  if (mapPxH >= safeHeight) {
    originY = Math.min(safeTop, originY);
    originY = Math.max(safeTop + safeHeight - mapPxH, originY);
  } else originY = safeTop + (safeHeight - mapPxH) / 2;
  return { originX: Math.round(originX), originY: Math.round(originY), zoom, cell };
}

type LifeItem = { kind: WorldLifeKind; x: number; y: number };

/** Pure per-frame painter shared by the canvas loop and headless tests. */
export function paintWorld(
  ctx: CanvasRenderingContext2D,
  viewport: { width: number; height: number },
  state: GameState,
  settings: WorldViewSettings,
  timeMs: number,
  lifeOverride?: LifeItem[],
  toolEvent?: ToolEvent | null,
  walkAt?: number,
) {
  const mapId = state.map as R22MapId;
  const map = R22_VIEWS[mapId];
  const cam = cameraFor(viewport, state.player, mapId);
  const { cell, zoom, originX, originY } = cam;
  ctx.imageSmoothingEnabled = false;
  ctx.clearRect(0, 0, viewport.width, viewport.height);

  const rain = state.weather === '小雨';
  let rgb = mapId === 'market' ? [46, 77, 87] : [71, 102, 56];
  if (rain) rgb = mapId === 'market' ? [26, 41, 61] : [31, 46, 41];
  ctx.fillStyle = `rgb(${rgb[0]},${rgb[1]},${rgb[2]})`;
  ctx.fillRect(0, 0, viewport.width, viewport.height);

  const sx = (x: number) => originX + x * cell;
  // Screen mapping mirroring SpriteKit's south-origin world: row `y` sits
  // (rows - 1 - y) cells below the map's northern edge.
  const sy = (y: number) => originY + (map.rows - 1 - y) * cell;
  const motion = !settings.reducedMotion;

  const drawImage = (
    url: string,
    x: number,
    y: number,
    w: number,
    h: number,
    flip = false,
    alpha = 1,
  ) => {
    const loaded = spriteCache.get(url);
    if (!loaded) {
      ensure(url);
      ctx.fillStyle = '#41513a';
      ctx.globalAlpha = alpha;
      ctx.fillRect(x, y, Math.max(0, w), Math.max(0, h));
      ctx.globalAlpha = 1;
      return;
    }
    if (!loaded.width) return; // load error fallback drawn elsewhere
    ctx.globalAlpha = alpha;
    if (flip) {
      ctx.save();
      ctx.translate(x + w, y);
      ctx.scale(-1, 1);
      ctx.drawImage(loaded.image, 0, 0, w, h);
      ctx.restore();
    } else ctx.drawImage(loaded.image, x, y, w, h);
    ctx.globalAlpha = 1;
  };

  const blocks = map.blocked;
  const paths = presentationPaths(mapId);
  const onFarm = mapId === 'farm';
  const target = getTarget(state);
  const targetKey = cellKeyOf(target.x, target.y);
  const playerKey = cellKeyOf(state.player.x, state.player.y);
  const plotReady = (key: string) => {
    const plot = state.plots[key];
    return !!plot?.crop && plot.stage >= CROPS[plot.crop].days;
  };

  // North-horizon backdrop. Native presentation keeps the authored pixel
  // zoom (never stretched to map width) and uses a bottom-centre anchor on
  // the horizontal map centre, with the lower edge one map row inside the
  // northern boundary so the ridge sits behind buildings yet only bleeds
  // into the camera margin above the map.
  const backdropKind: WorldLifeKind = mapId === 'farm' ? 'farmMountainBackdrop' : 'marketCreekValleyBackdrop';
  const backdropUrl = `${WORLD}/${WORLD_LIFE_ASSET[backdropKind]}.png`;
  const backdrop = spriteCache.get(backdropUrl);
  if (!backdrop) ensure(backdropUrl);
  const backdropPlacement = (WORLD_LIFE[mapId] as LifeItem[]).find(
    (item) => worldLifeKindCategory(item.kind) === 'backdrop',
  );
  if (backdrop && backdrop.width && backdropPlacement) {
    const bw = backdrop.width * zoom;
    const bh = backdrop.height * zoom;
    const mapCentreX = originX + (map.columns * cell) / 2;
    const bottomY = originY + (map.rows - backdropPlacement.y) * cell;
    drawImage(backdropUrl, mapCentreX - bw / 2, bottomY - bh, bw, bh);
  }

  // camera bleed ------------------------------------------------------------
  // Native bleedRoot paints the base grass field three cells beyond every map
  // edge at 88% alpha (z=-1) so the world never shows flat background colour
  // where the camera overhangs the map.
  const BLEED_CELLS = 3;
  for (let by = -BLEED_CELLS; by < map.rows + BLEED_CELLS; by += 1) {
    for (let bx = -BLEED_CELLS; bx < map.columns + BLEED_CELLS; bx += 1) {
      if (bx >= 0 && bx < map.columns && by >= 0 && by < map.rows) continue;
      const url = grassUrl(bx, by);
      const bleed = spriteCache.get(url);
      if (!bleed) ensure(url);
      drawImage(url, sx(bx), sy(by), cell, cell, false, 0.88);
    }
  }

  // terrain cells ----------------------------------------------------------
  for (let y = 0; y < map.rows; y += 1) {
    for (let x = 0; x < map.columns; x += 1) {
      const k = cellKeyOf(x, y);
      const px = sx(x);
      const py = sy(y);
      if (map.water.has(k)) {
        const semantic = map.water.get(k) as keyof typeof WATER_OVERLAY;
        drawImage(tileAssetUrl(TILE.waterEdge), px, py, cell, cell);
        const phase = waterPhase(x, y);
        const frame = (phase + Math.floor(timeMs / 140)) % TILE.waterFrames.length;
        const waterUrl = tileAssetUrl(TILE.waterFrames[frame]);
        drawImage(waterUrl, px, py, cell, cell);
        if (mapId === 'market') {
          if (y === 2) ctx.fillStyle = 'rgba(120,151,160,0.20)';
          else if (y === 0) ctx.fillStyle = 'rgba(38,54,56,0.18)';
          else ctx.fillStyle = 'transparent';
          if (y !== 1) ctx.fillRect(px, py, cell, cell);
        }
        for (const overlay of WATER_OVERLAY[semantic] ?? []) {
          drawImage(tileAssetUrl(overlay), px, py, cell, cell);
        }
        if (!onFarm && x === MARKET_SLUICE_MOUTH.x && y === MARKET_SLUICE_MOUTH.y) {
          drawImage(tileAssetUrl(TILE.canalNS), px, py, cell, cell);
        }
        continue;
      }
      const isApron = onFarm && x === FARM_SLUICE_APRON.x && y === FARM_SLUICE_APRON.y;
      if (map.canal.has(k) || isApron) {
        drawImage(tileAssetUrl(TILE.canalNS), px, py, cell, cell);
        if (isStonePath(mapId, x + 1, y) || isStonePath(mapId, x - 1, y)) {
          drawImage(tileAssetUrl(TILE.canalEW), px, py, cell, cell);
        }
        // Native makeNorthSouthCanalDepthOverlay: sprites centred on the cell
        // centre, offset +5/-5 native pixels along x, 2/1 native pixels wide.
        ctx.fillStyle = 'rgba(14,33,41,0.34)';
        ctx.fillRect(px + cell / 2 + zoom * 5 - zoom, py, zoom * 2, cell);
        ctx.fillStyle = 'rgba(173,224,214,0.28)';
        ctx.fillRect(px + cell / 2 - zoom * 5 - zoom / 2, py, zoom, cell);
        if (isApron) {
          ctx.fillStyle = 'rgba(14,33,41,0.48)';
          ctx.fillRect(
            px + cell / 2 - zoom * 5,
            py + cell / 2 - cell * 0.36 - zoom,
            zoom * 10,
            zoom * 2,
          );
        }
        const flowShown = onFarm || state.watershed >= 20 || rain;
        if (flowShown) {
          const phase = canalPhase(y);
          const flowUrl = tileAssetUrl(
            TILE.canalFlowFrames[(phase + Math.floor(timeMs / 140)) % TILE.canalFlowFrames.length],
          );
          drawImage(flowUrl, px, py, cell, cell);
        }
        continue;
      }
      if (paths.has(k)) {
        drawImage(tileAssetUrl(TILE.stonePath), px, py, cell, cell);
        continue;
      }
      drawImage(grassUrl(x, y), px, py, cell, cell);
    }
  }

  // farm plots (soil + crop sprites) ---------------------------------------
  if (onFarm) {
    for (const [plotKey, plot] of Object.entries(state.plots)) {
      const [x, y] = plotKey.split(',').map(Number);
      if (x === undefined || y === undefined) continue;
      const px = sx(x);
      const py = sy(y);
      if (plot.soil === 'tilled') {
        drawImage(tileAssetUrl(plot.watered ? TILE.tilledWatered : TILE.tilled), px, py, cell, cell);
      }
      if (plot.crop) {
        const stageAsset = cropStageAsset(plot.crop, plot.stage, plotReady(plotKey));
        const artUrl = `${ASSETS}/${stageAsset}.png`;
        const w = 32 * zoom;
        const h = 32 * zoom;
        drawImage(artUrl, px + (cell - w) / 2, py + (cell - h) / 2, w, h);
        if (plotKey === targetKey && plotReady(plotKey)) {
          ctx.strokeStyle = '#ffd740';
          ctx.lineWidth = Math.max(2, cell * 0.06);
          ctx.strokeRect(px + cell * 0.07, py + cell * 0.07, cell * 0.86, cell * 0.86);
        }
      }
    }
  }

  // collect drawables with explicit painter z ------------------------------
  // Native z plan (worldRoot children + their local offsets): buildings
  // buildingBase 5 + order*0.1, lifeRoot 4.6 + local z (backdrop 0.15, ground
  // decor 5.75-6.9, dining 7.7, greenhouse 9.4, trees/actors 13.6-14.4),
  // npcRoot 9, player 10, roof occluder 12, interaction fx 20, prompts 30.
  type Job = { z: number; run: () => void };
  const jobs: Job[] = [];

  // placed props (canal segments, rain barrel, crate, rack, hearth) --------
  const placedAssets: Record<string, string> = {
    canal_segment: 'prop_canal_segment_ns',
    rain_barrel: 'prop_rain_barrel_r2',
    wooden_crate: 'prop_wooden_crate_r2',
    compost_rack: 'prop_compost_bin_r2',
    woodhoney_hearth: 'prop_woodhoney_hearth_r2',
  };
  for (const [placedId, count] of Object.entries(state.placed)) {
    if (!count) continue;
    const art = placedAssets[placedId];
    if (!art) continue;
    const [x, y] = placedId === 'wooden_crate' ? [10, 5] : [7, 4]; // demo display
    const px = sx(x);
    const py = sy(y);
    const nativeW = art.includes('compost') || art.includes('woodhoney') ? 48 : 24;
    const nativeH = art.includes('rain_barrel') ? 32 : art.includes('compost') || art.includes('woodhoney') ? 48 : 24;
    const w = nativeW * zoom;
    const h = nativeH * zoom;
    drawImage(`${ASSETS}/${art}.png`, px + (cell - w) / 2, py + cell - h, w, h);
  }

  // buildings (six B4 layers + wharf R2 + occluder roof) -------------------
  for (const building of map.buildings) {
    const isWharf = building.specialWharf;
    const scale = zoom;
    // Native BuildingVisualPresenter + FarmScene anchoring: layers are
    // bottom-centre anchored, stacked at buildingBase + order*0.1 and offset
    // by renderOffset (world pixels, positive up). FarmScene puts the root on
    // the floor of the render-anchor cell, which is the cell's bottom edge.
    const ox = building.renderOffsetX * scale;
    const oy = -building.renderOffsetY * scale;
    const anchorX = sx(building.renderAnchor.x) + cell / 2 + ox;
    const anchorY = sy(building.renderAnchor.y) + cell + oy;
    const roofRaised =
      building.occlusionCells.some((c) => cellKeyOf(c.x, c.y) === playerKey) &&
      building.id.includes('farm_house');
    const layerPrefix = building.id.split('.').pop() ?? '';
    if (isWharf) {
      const url = `${ASSETS}/building_market_wharf_r2.png`;
      const w = 144 * scale;
      const h = 96 * scale;
      jobs.push({ z: 5, run: () => drawImage(url, anchorX - w / 2, anchorY - h, w, h) });
      continue;
    }
    const active =
      layerPrefix === 'market_wharf'
        ? true
        : layerPrefix === 'farm_sluice'
          ? state.watershed >= 20
          : false;
    for (const layer of building.layers) {
      const url = `${ASSETS}/${layer.filename}`;
      const w = layer.nativeWidth * scale;
      const h = layer.nativeHeight * scale;
      const z = layer.semantic === 'roof' && roofRaised ? 12 : 5 + layer.order * 0.1;
      const alpha = layer.semantic === 'state_fx' ? (active ? 0.72 : 0.18) : 1;
      jobs.push({ z, run: () => drawImage(url, anchorX - w / 2, anchorY - h, w, h, false, alpha) });
    }
  }

  // world-life placements ---------------------------------------------------
  const lifeItems: LifeItem[] = lifeOverride ??
    [...(WORLD_LIFE[mapId] as LifeItem[]), ...(EDGE_LANDSCAPE[mapId] as LifeItem[])];
  const livestockKind: Partial<Record<WorldLifeKind, string>> = {
    farmCow: 'cow',
    farmSheep: 'sheep',
    farmGoat: 'goat',
  };
  const gatherCellKinds = new Map<string, string>();
  for (const gather of GATHER_ANCHORS) {
    if (gather.map === mapId) gatherCellKinds.set(cellKeyOf(gather.x, gather.y), gather.id);
  }
  const npcCellSet = new Set<string>();
  for (const presence of PRESENCES) {
    if (presence.map === mapId) npcCellSet.add(cellKeyOf(presence.x, presence.y));
  }
  const exitSet = new Set(map.exits.map((e) => cellKeyOf(e.cell.x, e.cell.y)));
  const spawnSet = new Set([...map.spawns.values()].map((s) => cellKeyOf(s.x, s.y)));

  const sway = (x: number, y: number) => {
    if (!motion) return 0;
    const t = timeMs / 1000;
    return Math.round(Math.sin((t * Math.PI) / 0.9 + ((x * 3 + y) % 4)));
  };
  for (const item of lifeItems) {
    const kind = item.kind;
    const { x, y } = item;
    const cat = worldLifeKindCategory(kind);
    if (cat === 'backdrop') continue;
    if (livestockKind[kind] && !state.animals.some((a) => a.kind === livestockKind[kind])) continue;
    if (x < 0 || y < 0 || x >= map.columns || y >= map.rows) continue;
    const k = cellKeyOf(x, y);
    const artName = WORLD_LIFE_ASSET[kind];
    // tile-style kinds live in assets/; wl_* canvases live in world/
    const tileKind =
      kind === 'gardenBed' ||
      kind === 'scenicTilled' ||
      kind.startsWith('crop');
    const url = `${tileKind ? ASSETS : WORLD}/${artName}.png`;
    const loaded = spriteCache.get(url);
    if (!loaded) ensure(url);
    const artW = loaded?.width ?? 24;
    const artH = loaded?.height ?? 24;
    const px = sx(x);
    const py = sy(y);
    if (kind === 'catBbqShop') {
      // 72x72 canvas, bottom-centre anchor: the floor of the art rests on the
      // floor of its anchor cell, matching the native landmark placement.
      const w = artW * zoom;
      const h = artH * zoom;
      jobs.push({ z: 4.6, run: () => drawImage(url, px + cell / 2 - w / 2, py + cell - h, w, h) });
      continue;
    }
    const intentionalBoundary = map.boundary.has(k) &&
      ['tree', 'shrub', 'flower', 'fence', 'fieldPatch', 'scenicTilled'].includes(cat);
    const intentionalWater =
      ['riverStone', 'shoreInset'].includes(cat) && map.water.has(k);
    if (blocks.has(k) && !intentionalBoundary && !intentionalWater) continue;
    if (paths.has(k) && cat !== 'pastureGround') continue;
    if (npcCellSet.has(k) || gatherCellKinds.has(k) || exitSet.has(k) || spawnSet.has(k)) continue;

    const w = artW * zoom;
    const h = artH * zoom;
    // Native anchor rules (FarmScene.rebuildWorldLife): most world-life art
    // is bottom-centre anchored with its lower edge on the cell floor; ground
    // beds, tilled soil, pasture, fences and shore insets use a true centre
    // anchor; the dining set is top anchored so its stools reach into the
    // southern bleed; the greenhouse is rendered half a tile toward horizon.
    const cx = px + cell / 2;
    const cy = py + cell / 2;
    const floorTop = py + cell - h;
    switch (cat) {
      case 'greenhouse': {
        const retreat = cell * 0.5;
        jobs.push({ z: 9.4, run: () => drawImage(url, cx - w / 2, floorTop - retreat, w, h) });
        break;
      }
      case 'scenicLake': {
        const frameName = WORLD_LIFE_SCENIC_LAKE_FRAMES[
          Math.floor(timeMs / 140) % WORLD_LIFE_SCENIC_LAKE_FRAMES.length
        ];
        const frameUrl = `${WORLD}/${frameName}.png`;
        // Bottom-centre anchor on the cell floor, like the BBQ landmark.
        jobs.push({ z: 1.1, run: () => drawImage(frameUrl, cx - w / 2, floorTop, w, h) });
        break;
      }
      case 'diningSet':
        // Top-centre anchor on the cell ceiling.
        jobs.push({ z: 7.7, run: () => drawImage(url, cx - w / 2, py, w, h) });
        break;
      case 'tree':
        jobs.push({ z: 13.6, run: () => drawImage(url, cx - w / 2, floorTop, w, h) });
        break;
      case 'animal':
        jobs.push({ z: 14.1, run: () => drawImage(url, cx - w / 2, floorTop + sway(x, y), w, h) });
        break;
      case 'catStaff':
        jobs.push({ z: 14.4, run: () => drawImage(url, cx - w / 2, floorTop + sway(x, y), w, h) });
        break;
      case 'gardenBed':
      case 'scenicTilled':
      case 'pastureGround':
        jobs.push({ z: cat === 'pastureGround' ? 5.75 : cat === 'scenicTilled' ? 5.78 : 5.8, run: () => drawImage(url, cx - w / 2, cy - h / 2, w, h) });
        break;
      case 'shoreInset': {
        const sub = kind.startsWith('bankNorth') ? zoom - 1 : zoom + 1;
        const sw = artW * Math.max(1, sub);
        const sh = artH * Math.max(1, sub);
        // Far bank pieces are colour-blended toward the cool distant plane,
        // near pieces toward the dark foreground rim.
        const far = kind.startsWith('bankNorth');
        const tint = far ? 'rgba(120,151,160,0.16)' : 'rgba(38,54,56,0.14)';
        jobs.push({
          z: far ? 6.22 : 6.68,
          run: () => {
            drawImage(url, cx - sw / 2, cy - sh / 2, sw, sh);
            ctx.fillStyle = tint;
            ctx.fillRect(cx - sw / 2, cy - sh / 2, sw, sh);
          },
        });
        break;
      }
      case 'riverStone':
        jobs.push({ z: 6.45, run: () => drawImage(url, cx - w / 2, floorTop, w, h) });
        break;
      case 'cropDisplay': {
        const sub = Math.max(1, zoom - 1);
        const cw = artW * sub;
        const ch = artH * sub;
        jobs.push({ z: 6.3, run: () => drawImage(url, cx - cw / 2, py + cell - ch, cw, ch) });
        break;
      }
      case 'fieldPatch':
      case 'haystack':
        jobs.push({ z: 6.15, run: () => drawImage(url, cx - w / 2, floorTop, w, h) });
        break;
      case 'fence':
        jobs.push({ z: 6.5, run: () => drawImage(url, cx - w / 2, cy - h / 2, w, h) });
        break;
      case 'shrub':
      case 'flower':
      default:
        jobs.push({ z: 6.0, run: () => drawImage(url, cx - w / 2, floorTop + sway(x, y), w, h) });
    }
  }

  // gather nodes ------------------------------------------------------------
  for (const gather of GATHER_ANCHORS) {
    if (gather.map !== mapId) continue;
    if (gather.unlockAfterWatershed && state.watershed < 20) continue;
    const gatheredKey = `${mapId}:${gather.id}`;
    if (
      state.gathered.includes(gatheredKey) ||
      (mapId === 'farm' && state.gathered.includes(gather.id))
    )
      continue;
    const art = gather.id === 'brook' || gather.id === 'moss'
      ? 'gather_moss_stone_r2'
      : gather.id === 'reed'
        ? 'gather_reed_fiber_r2'
        : 'gather_creek_wood_r2';
    const url = `${ASSETS}/${art}.png`;
    const loaded = spriteCache.get(url);
    if (!loaded) ensure(url);
    const artW = loaded?.width ?? 24;
    const artH = loaded?.height ?? 24;
    const px = sx(gather.x);
    const py = sy(gather.y);
    if (gather.id === 'wood') {
      const pieceW = artW * Math.max(1, zoom - 1);
      const pieceH = artH * Math.max(1, zoom - 1);
      jobs.push({ z: 2, run: () => {
        drawImage(url, px - cell * 0.1 - pieceW, py + cell - pieceH, pieceW, pieceH);
        drawImage(url, px + cell * 0.14, py + cell - pieceH + zoom * 2, pieceW, pieceH, true);
      } });
    } else {
      const w = artW * zoom;
      const h = artH * zoom;
      jobs.push({ z: 2, run: () => drawImage(url, px - w / 2, py + cell - h, w, h) });
    }
  }

  // NPC presence ------------------------------------------------------------
  for (const presence of PRESENCES) {
    if (presence.map !== mapId) continue;
    const px = sx(presence.x);
    const py = sy(presence.y);
    const sheetId = NPC_SHEETS[presence.id];
    const url = `${ASSETS}/${sheetId}.png`;
    const sheet = spriteCache.get(url);
    if (!sheet) ensure(url);
    const w = cell;
    const h = cell * 1.5;
    const proximity = Math.max(
      Math.abs(state.player.x - presence.x),
      Math.abs(state.player.y - presence.y),
    );
    const showName = proximity <= 3;
    const showBadge = proximity <= 1;
    const dy = showName ? sway(presence.x, presence.y + 2) : 0;
    jobs.push({ z: 9.5, run: () => {
      if (sheet && sheet.width) {
        ctx.drawImage(
          sheet.image,
          0,
          0,
          SHEET_FRAME_W,
          SHEET_FRAME_H,
          px - w / 2,
          py + cell - h + dy,
          w,
          h,
        );
      }
      if (showName) {
        ctx.font = `700 ${Math.max(10, Math.round(cell * 0.2))}px "PingFang SC", "Microsoft YaHei", sans-serif`;
        ctx.textAlign = 'center';
        ctx.lineWidth = 3;
        ctx.strokeStyle = 'rgba(18,24,16,0.9)';
        ctx.strokeText(presence.label, px, py + cell - h - 4 + dy);
        ctx.fillStyle = '#fff3c9';
        ctx.fillText(presence.label, px, py + cell - h - 4 + dy);
      }
      if (showBadge) {
        const badgeUrl = `${ASSETS}/ui_interact_badge.png`;
        const badge = spriteCache.get(badgeUrl);
        if (!badge) ensure(badgeUrl);
        if (badge && badge.width) {
          const bw = badge.width * zoom;
          const bh = badge.height * zoom;
          ctx.drawImage(badge.image, px - bw / 2, py + cell - h - (showName ? 6 : 0) - bh + dy, bw, bh);
        }
      }
    } });
  }

  // player (four-direction sheet, action sheets, walk frames) ---------------
  const px = sx(state.player.x);
  const py = sy(state.player.y);
  const w = cell;
  const h = cell * 1.5;
  const row = FRAME_ROW[state.player.direction];
  // action sheets run 4 frames at 90ms after a successful hoe/water/harvest
  const actionAlive =
    toolEvent && timeMs - toolEvent.at >= 0 && timeMs - toolEvent.at < 90 * 4;
  const actionKind = actionAlive && toolEvent ? toolEvent.kind : null;
  // Native actors are bottom-centre anchored on the cell floor (cell-wide art,
  // 1.5 cells tall), one layer above npcRoot.
  jobs.push({ z: 10, run: () => {
  if (actionKind) {
    const sheetId = ACTION_SHEET[actionKind];
    const url = `${ASSETS}/${sheetId}.png`;
    const sheet = spriteCache.get(url);
    if (!sheet) ensure(url);
    if (sheet && sheet.width) {
      const col = Math.min(3, Math.floor((timeMs - (toolEvent?.at ?? 0)) / 90));
      ctx.drawImage(
        sheet.image,
        col * SHEET_FRAME_W,
        row * SHEET_FRAME_H,
        SHEET_FRAME_W,
        SHEET_FRAME_H,
        px - w / 2,
        py + cell - h,
        w,
        h,
      );
    }
  } else {
    const sheetUrl = `${ASSETS}/char_player_walk.png`;
    const sheet = spriteCache.get(sheetUrl);
    if (!sheet) ensure(sheetUrl);
    if (sheet && sheet.width) {
      const walking = walkAt !== undefined && timeMs - walkAt >= 0 && timeMs - walkAt < 4 * 75;
      const col = walking && motion ? Math.floor((timeMs - walkAt) / 75) % 4 : 0;
      ctx.drawImage(
        sheet.image,
        col * SHEET_FRAME_W,
        row * SHEET_FRAME_H,
        SHEET_FRAME_W,
        SHEET_FRAME_H,
        px - w / 2,
        py + cell - h,
        w,
        h,
      );
    }
  }
  } });

  // action fx (hoe/water/harvest) fire from the domain message as fx ticks
  // target highlight: valid tool rings pulse on the actionable tile
  const fieldTarget =
    onFarm &&
    ((state.selectedTool === 'hoe') ||
      (state.selectedTool === 'seed') ||
      (state.selectedTool === 'water') ||
      (state.selectedTool === 'harvest' || state.selectedTool === 'hand'));
  if (fieldTarget && target.x >= 0 && target.x < map.columns && target.y >= 0 && target.y < map.rows) {
    const k = cellKeyOf(target.x, target.y);
    const plot = state.plots[k];
    const valid =
      (state.selectedTool === 'hoe' && (!plot || plot.soil === 'grass')) ||
      (state.selectedTool === 'seed' && !!plot && plot.soil === 'tilled' && !plot.crop) ||
      (state.selectedTool === 'water' && !!plot?.crop && !plot.watered) ||
      ((state.selectedTool === 'harvest' || state.selectedTool === 'hand') &&
        !!plot?.crop && plot.stage >= CROPS[plot.crop].days);
    if (valid) {
      const frames = FX.targetValid;
      const url = `${ASSETS}/${frames[Math.floor(timeMs / 120) % frames.length]}.png`;
      jobs.push({ z: 20, run: () => drawImage(url, sx(target.x), sy(target.y), cell, cell) });
    }
  }

  // exit prompt (stone steps at the map exit + chevron)
  for (const exit of map.exits) {
    const ex = sx(exit.cell.x);
    const ey = sy(exit.cell.y);
    jobs.push({ z: 30, run: () => {
    ctx.fillStyle = 'rgba(210,200,168,0.9)';
    ctx.fillRect(ex + cell * 0.15, ey + cell * 0.15, cell * 0.7, cell * 0.14);
    ctx.fillRect(ex + cell * 0.28, ey + cell * 0.02, cell * 0.44, cell * 0.14);
    const nearExit =
      Math.abs(state.player.x - exit.cell.x) <= 1 &&
      Math.abs(state.player.y - exit.cell.y) <= 1;
    if (nearExit && motion) {
      const bob = Math.floor(timeMs / 250) % 2;
      ctx.fillStyle = '#ffe9a3';
      const arrowX = ex + cell / 2;
      const arrowY = ey + cell * (0.9 + bob * 0.06);
      ctx.beginPath();
      ctx.moveTo(arrowX - cell * 0.14, arrowY);
      ctx.lineTo(arrowX + cell * 0.14, arrowY);
      ctx.lineTo(arrowX, arrowY + cell * 0.16);
      ctx.closePath();
      ctx.fill();
    }
    } });
  }
  jobs.sort((a, b) => a.z - b.z);
  jobs.forEach((job) => job.run());
  void blocks;
  return cam;
}

/** React component hosting the world canvas + animation loop. */
export function CanvasWorld({ game, settings, toolEvent, onActCell, onPresence, onTravel }: CanvasWorldProps) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const walkAtRef = useRef(0);
  const lastPosRef = useRef({ x: game.player.x, y: game.player.y, map: game.map });

  useEffect(() => {
    const last = lastPosRef.current;
    if (last.x !== game.player.x || last.y !== game.player.y || last.map !== game.map) {
      lastPosRef.current = { x: game.player.x, y: game.player.y, map: game.map };
      walkAtRef.current = performance.now();
    }
  }, [game.map, game.player.x, game.player.y]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const context = canvas.getContext('2d');
    if (!context) return;
    let raf = 0;
    const draw = () => {
      try {
        const rect = canvas.getBoundingClientRect();
        if (rect.width < 2 || rect.height < 2) {
          raf = requestAnimationFrame(draw);
          return;
        }
        const dpr = Math.min(window.devicePixelRatio || 1, 2);
        const width = Math.max(1, Math.round(rect.width));
        const height = Math.max(1, Math.round(rect.height));
        const targetW = Math.round(width * dpr);
        const targetH = Math.round(height * dpr);
        if (canvas.width !== targetW || canvas.height !== targetH) {
          canvas.width = targetW;
          canvas.height = targetH;
        }
        context.setTransform(dpr, 0, 0, dpr, 0, 0);
        const now = performance.now();
        paintWorld(
          context,
          { width, height },
          game,
          settings,
          now,
          undefined,
          toolEvent,
          walkAtRef.current,
        );
        const apiWin = window as unknown as {
          __creekSproutWorld?: Record<string, unknown>;
        };
        if (apiWin.__creekSproutWorld) {
          apiWin.__creekSproutWorld.cam = cameraFor(
            { width, height },
            game.player,
            game.map as R22MapId,
          );
          // Walkthrough/E2E probe: the authoritative grid position of the hero.
          apiWin.__creekSproutWorld.player = {
            x: game.player.x,
            y: game.player.y,
            map: game.map,
          };
        }
      } catch (error) {
        console.error('[world-frame]', error);
      }
      raf = requestAnimationFrame(draw);
    };
    raf = requestAnimationFrame(draw);
    const observer = new ResizeObserver(draw);
    observer.observe(canvas);
    return () => {
      cancelAnimationFrame(raf);
      observer.disconnect();
    };
  }, [game, settings, toolEvent]);

  const handlePointer = (event: React.PointerEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const viewport = { width: rect.width, height: rect.height };
    const mapId = game.map as R22MapId;
    const cam = cameraFor(viewport, game.player, mapId);
    const map = R22_VIEWS[mapId];
    const screenX = event.clientX - rect.left;
    const screenY = event.clientY - rect.top;
    const worldX = Math.floor((screenX - cam.originX) / cam.cell);
    // Rows count south -> north, so screen rows count backwards from the map's
    // northern edge.
    const worldY = map.rows - 1 - Math.floor((screenY - cam.originY) / cam.cell);
    if (worldX < 0 || worldX >= map.columns || worldY < 0 || worldY >= map.rows) return;
    const adjacent =
      Math.abs(worldX - game.player.x) + Math.abs(worldY - game.player.y) <= 1;
    const exit = map.exits.find((e) => e.cell.x === worldX && e.cell.y === worldY);
    if (exit && adjacent) {
      onTravel();
      return;
    }
    const presence = PRESENCES.find((p) => p.map === mapId && p.x === worldX && p.y === worldY);
    if (presence && adjacent) {
      onPresence(presence.id);
      return;
    }
    const catShopZone =
      mapId === 'market' &&
      worldX >= 9 && worldX <= 13 && worldY >= 7 && worldY <= 12;
    if (catShopZone && adjacent) {
      onPresence('cat-shop');
      return;
    }
    const gatherNode = GATHER_ANCHORS.find(
      (g) => g.map === mapId && g.x === worldX && g.y === worldY,
    );
    if (gatherNode && adjacent) {
      onPresence(`gather:${gatherNode.id}`);
      return;
    }
    if (adjacent) {
      const dx = worldX - game.player.x;
      const dy = worldY - game.player.y;
      const direction: Direction =
        dx === 1 ? 'right' : dx === -1 ? 'left' : dy === 1 ? 'up' : 'down';
      onActCell(worldX, worldY, direction);
    }
  };

  return (
    <canvas
      ref={canvasRef}
      className="world-canvas"
      onPointerDown={handlePointer}
      aria-label="《溪谷新芽》游戏世界"
    />
  );
}

// Evidence/driver hook: exposes the authoritative blocked grid and presence
// anchors so browser-level E2E can steer with real BFS instead of heuristics.
if (typeof window !== 'undefined') {
  const api = window as unknown as {
    __creekSproutWorld: Record<string, unknown>;
  };
  api.__creekSproutWorld = api.__creekSproutWorld ?? {};
  api.__creekSproutWorld.view = (mapId: R22MapId) => {
    const map = R22_VIEWS[mapId];
    return {
      columns: map.columns,
      rows: map.rows,
      blocked: [...map.blocked],
      presences: PRESENCES.filter((presence) => presence.map === mapId),
      spawns: [...map.spawns.values()],
    };
  };
}

