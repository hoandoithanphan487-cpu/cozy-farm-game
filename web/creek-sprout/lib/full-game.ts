export type MapId = 'farm' | 'market';
export type Direction = 'up' | 'down' | 'left' | 'right';
export type Tool = 'hoe' | 'seed' | 'water' | 'harvest' | 'hand';
export type CropId =
  | 'mist_radish'
  | 'stream_leaf'
  | 'amber_bean'
  | 'bell_berry'
  | 'honey_melon';
export type ItemId =
  | `${CropId}_seed`
  | CropId
  | 'creek_wood'
  | 'moss_stone'
  | 'reed_fiber'
  | 'canal_segment'
  | 'rain_barrel'
  | 'wooden_crate'
  | 'compost_rack'
  | 'woodhoney_hearth'
  | 'leaf_preserve'
  | 'amber_paste'
  | 'berry_glaze'
  | 'melon_syrup';

import { view } from '../content/r22-world.ts';
import type { R22MapId } from '../content/r22-world.ts';

export type CropDefinition = {
  id: CropId;
  name: string;
  seedName: string;
  days: number;
  price: number;
  color: string;
};

export const CROPS: Record<CropId, CropDefinition> = {
  mist_radish: {
    id: 'mist_radish',
    name: '雾萝卜',
    seedName: '雾萝卜种子',
    days: 3,
    price: 58,
    color: '#d6e8c4',
  },
  stream_leaf: {
    id: 'stream_leaf',
    name: '溪叶菜',
    seedName: '溪叶菜种子',
    days: 3,
    price: 72,
    color: '#87bc68',
  },
  amber_bean: {
    id: 'amber_bean',
    name: '琥珀豆',
    seedName: '琥珀豆种子',
    days: 4,
    price: 94,
    color: '#dcad52',
  },
  bell_berry: {
    id: 'bell_berry',
    name: '铃莓',
    seedName: '铃莓种子',
    days: 4,
    price: 116,
    color: '#b95f71',
  },
  honey_melon: {
    id: 'honey_melon',
    name: '蜜穗瓜',
    seedName: '蜜穗瓜种子',
    days: 5,
    price: 148,
    color: '#e7c768',
  },
};

export const ITEM_NAMES: Record<string, string> = {
  creek_wood: '溪木',
  moss_stone: '苔石',
  reed_fiber: '芦纤维',
  canal_segment: '水渠接片',
  rain_barrel: '雨水桶',
  wooden_crate: '木箱',
  compost_rack: '堆肥架',
  woodhoney_hearth: '木蜜灶台',
  leaf_preserve: '溪叶渍菜',
  amber_paste: '琥珀豆酱',
  berry_glaze: '铃莓釉',
  melon_syrup: '蜜穗糖浆',
  ...Object.fromEntries(
    Object.values(CROPS).flatMap((crop) => [
      [crop.id, crop.name],
      [`${crop.id}_seed`, crop.seedName],
    ]),
  ),
};

export type Plot = {
  soil: 'grass' | 'tilled';
  crop: CropId | null;
  stage: number;
  watered: boolean;
  // Native crop-care parity (CropCareService.settleCrops): number of
  // consecutive un-watered nights while growing. 1=thirsty (paused),
  // 2=wilted (must care tonight), 3=withered (dead, hoe to clear).
  // Optional for save compatibility; absent means 0.
  dryStreak?: number;
};
export const plotDry = (plot: Plot): number => plot.dryStreak ?? 0;
export const isWithered = (plot: Plot): boolean => plotDry(plot) >= 3;
export type Animal = {
  id: string;
  kind: 'cow' | 'sheep' | 'goat';
  name: string;
  age: number;
  careDays: number;
  caredDay: number | null;
  protected: boolean;
};
export type StoryState = {
  arcIndex: number;
  stageIndex: number;
  choices: Record<string, string>;
  completedArcs: string[];
  journeyCheckpoint: number;
  preRevealSave: boolean;
  ending: 'water' | 'leave' | null;
};
export type GameState = {
  version: 3;
  campaignId: string;
  day: number;
  hour: number;
  minute: number;
  weather: '晴' | '小雨' | '阴';
  stamina: number;
  coins: number;
  standing: number;
  watershed: number;
  map: MapId;
  player: { x: number; y: number; direction: Direction };
  selectedTool: Tool;
  selectedSeed: CropId;
  inventory: Partial<Record<ItemId, number>>;
  plots: Record<string, Plot>;
  gathered: string[];
  placed: Partial<
    Record<
      | 'canal_segment'
      | 'rain_barrel'
      | 'wooden_crate'
      | 'compost_rack'
      | 'woodhoney_hearth',
      number
    >
  >;
  recipesUnlocked: string[];
  quest: { canalPlaced: boolean; canalReported: boolean; noticeRead: boolean };
  relationships: Record<string, number>;
  animals: Animal[];
  catShopSales: Record<string, number>;
  story: StoryState;
  message: string;
  updatedAt: string;
};

export type WorldObject = {
  id: string;
  map: MapId;
  x: number;
  y: number;
  label: string;
  asset: string;
  kind: 'building' | 'npc' | 'animal' | 'deco' | 'gather' | 'shop';
  width?: number;
  height?: number;
};

/**
 * Authoritative R22 geometry (n-015-map-layout-contract.json, DEC-035).
 * Coordinate convention: cell origin southwest, y grows north/up, matching
 * the macOS engine and this domain layer. Farm/market rows and columns come
 * from the frozen contract; see content/r22-map-data.ts for the raw cells.
 */
export const MAPS: Record<
  MapId,
  {
    id: MapId;
    name: string;
    width: number;
    height: number;
    spawn: { x: number; y: number };
    spawnFromMarket: { x: number; y: number };
    spawnFromFarm: { x: number; y: number };
    exit: { x: number; y: number };
  }
> = {
  farm: {
    id: 'farm',
    name: '农场与农舍',
    width: 16,
    height: 15,
    spawn: { x: 7, y: 6 },
    spawnFromMarket: { x: 7, y: 1 },
    spawnFromFarm: { x: 9, y: 11 },
    exit: { x: 7, y: 0 },
  },
  market: {
    id: 'market',
    name: '溪岸集市',
    width: 18,
    height: 14,
    spawn: { x: 9, y: 11 },
    spawnFromMarket: { x: 7, y: 1 },
    spawnFromFarm: { x: 9, y: 11 },
    exit: { x: 9, y: 12 },
  },
};

export const A = '/full-assets/assets';
export const W = '/full-assets/world';

/**
 * Player/NPC/gather/livestock presence anchors, transcribed from the
 * authoritative macOS catalogs (WorldCatalog.swift + contract quest targets).
 * Renderers must use content/r22-* for world geometry; this list only feeds
 * reachability, tests and the presence UI.
 */
export const NPC_ANCHORS: Array<{
  id: string;
  map: MapId;
  x: number;
  y: number;
  label: string;
  asset: string;
}> = [
  // Farm teaching presence (ContentCatalog startingNpcSpawns).
  { id: 'apprentice', map: 'farm', x: 8, y: 6, label: '水工学徒', asset: `${A}/char_water_apprentice.png` },
  // Creek market residents (WorldCatalog.npcs positions).
  { id: 'apprentice', map: 'market', x: 3, y: 6, label: '水工学徒', asset: `${A}/char_water_apprentice.png` },
  { id: 'steward', map: 'market', x: 4, y: 9, label: '种源管理员', asset: `${A}/char_seed_steward.png` },
  { id: 'warden', map: 'market', x: 13, y: 9, label: '溪岸巡护员', asset: `${A}/char_creek_warden.png` },
  { id: 'hearsay', map: 'market', x: 5, y: 7, label: '涧麦婶', asset: `${A}/char_neighbor_hearsay.png` },
  { id: 'storyteller', map: 'market', x: 7, y: 6, label: '石灯', asset: `${A}/char_neighbor_storyteller.png` },
  { id: 'evidence', map: 'market', x: 11, y: 6, label: '青砚', asset: `${A}/char_neighbor_evidence.png` },
  { id: 'consensus', map: 'market', x: 7, y: 11, label: '絮宁', asset: `${A}/char_neighbor_consensus.png` },
];

export const GATHER_ANCHORS: Array<{
  id: string;
  map: MapId;
  x: number;
  y: number;
  label: string;
  unlockAfterWatershed?: boolean;
}> = [
  { id: 'wood', map: 'farm', x: 1, y: 6, label: '溪木堆' },
  { id: 'reed', map: 'farm', x: 11, y: 1, label: '芦丛' },
  { id: 'moss', map: 'farm', x: 12, y: 6, label: '苔石堆' },
  { id: 'wood', map: 'market', x: 6, y: 4, label: '溪木堆' },
  { id: 'reed', map: 'market', x: 12, y: 4, label: '芦丛' },
  { id: 'moss', map: 'market', x: 15, y: 4, label: '苔石堆' },
  { id: 'brook', map: 'market', x: 16, y: 3, label: '回流的溪石', unlockAfterWatershed: true },
];

/** Farm livestock pasture anchors (world-life farm placements). */
export const LIVESTOCK_ANCHORS: Record<string, { x: number; y: number }> = {
  cow: { x: 15, y: 4 },
  sheep: { x: 14, y: 5 },
  goat: { x: 15, y: 6 },
};

/** Cat shop presentation zone (WorldLifeCatalog.isNearCatBbqShop). */
export const CAT_SHOP = {
  anchor: { x: 11, y: 10 },
  zone: { x1: 9, x2: 13, y1: 7, y2: 12 },
};

export const DEMO_CRATE_DISPLAY = { x: 10, y: 5 };

/**
 * Legacy flat object registry (kept for tooling/tests). The authoritative
 * geometry lives in content/r22-map-data.ts + content/r22-world.ts.
 */
export const WORLD_OBJECTS: WorldObject[] = [
  ...NPC_ANCHORS.map((npc) => ({
    id: `${npc.map}-${npc.id}`,
    map: npc.map,
    x: npc.x,
    y: npc.y,
    label: npc.label,
    asset: npc.asset,
    kind: 'npc' as const,
  })),
  ...GATHER_ANCHORS.map((gather) => ({
    id: `${gather.map}-${gather.id}`,
    map: gather.map,
    x: gather.x,
    y: gather.y,
    label: gather.label,
    asset: `${A}/gather_${gather.id === 'brook' ? 'moss_stone' : gather.id}_r2.png`,
    kind: 'gather' as const,
  })),
  {
    id: 'market-cat_shop',
    map: 'market' as MapId,
    x: CAT_SHOP.anchor.x,
    y: CAT_SHOP.anchor.y,
    label: '溪火猫食铺',
    asset: `${W}/wl_cat_bbq_shop_r3.png`,
    kind: 'shop' as const,
    width: 3,
    height: 3,
  },
];

export const NPC_NAMES: Record<string, string> = {
  waterApprentice: '水工学徒',
  seedSteward: '种源管理员',
  creekWarden: '溪岸巡护员',
  neighborHearsay: '涧麦婶',
  neighborStoryteller: '石灯',
  neighborEvidence: '青砚',
  neighborConsensus: '絮宁',
  catShopBlack: '黑猫店员',
  catShopCalico: '三花店员',
  catShopRagdoll: '布偶猫店员',
  bellPrincess: '绒铃',
  greygateRepresentative: '灰栅代表',
  greygateFarmer: '灰栅农场主',
  system: '系统',
  ledger: '账簿',
};

export const CHOICE_LABELS: Record<string, string> = {
  field_first: '先保生长田',
  reed_first: '先稳下游芦线',
  inspect_first: '先查闸再分水',
  harvest: '派人抢收',
  sandbag: '派人搬沙袋',
  patrol: '派人巡田',
  livestock: '优先照料动物',
  cut_test: '公开切果检验',
  trace_rumor: '追查三种说法',
  protect_inventory: '先保护库存',
  regroup: '按记录重分组',
  parallel_crop: '两批继续并种',
  publish_missing_page: '公开缺页与标签异常',
  public: '拒绝独家，要求公开数量单',
  coop: '提出多农场联合供货',
  delay: '暂缓签约',
  talk: '请两人分别说事实与感受',
  no_side: '拒绝替任何人站队',
  pause: '建议暂时分开冷静',
  love: '承认爱意',
  tender: '温柔回应',
  friend: '守住友情',
  menu: '优先开放保底菜单',
  inventory: '优先调度库存',
  evidence: '证据路线',
  trade_union: '商业联合路线',
  old_waterway: '旧水道营救路线',
  take_ledger: '带走账簿，当众对质',
  keep_reading: '留在原地，继续读完',
  close_ledger: '合上账簿，不回应',
  return_titles: '把两块英雄牌放到账簿上',
  why_me: '质问：为什么是我',
  any_truth: '质问：有没有一句是真的',
  silence: '沉默',
  break_titles: '摔下两块英雄牌',
  water: '回田里完成最后一次浇水',
  leave: '停止浇水并离开农场',
  confirm_departure: '确认托管并出发',
  wait: '暂不出发',
};

export function createNewGame(): GameState {
  const inventory: Partial<Record<ItemId, number>> = {
    creek_wood: 0,
    moss_stone: 0,
    reed_fiber: 0,
  };
  (Object.keys(CROPS) as CropId[]).forEach((id) => {
    inventory[`${id}_seed`] = id === 'mist_radish' ? 8 : 4;
    inventory[id] = 0;
  });
  return {
    version: 3,
    campaignId: `web-${Date.now().toString(36)}`,
    day: 1,
    hour: 6,
    minute: 30,
    weather: '晴',
    stamina: 100,
    coins: 720,
    standing: 50,
    watershed: 0,
    map: 'farm',
    player: { ...MAPS.farm.spawn, direction: 'down' },
    selectedTool: 'hoe',
    selectedSeed: 'mist_radish',
    inventory,
    plots: {},
    gathered: [],
    placed: {},
    recipesUnlocked: [
      'wooden_crate',
      'compost_rack',
      'woodhoney_hearth',
      'canal_segment',
    ],
    quest: { canalPlaced: false, canalReported: false, noticeRead: false },
    relationships: {
      apprentice: 0,
      steward: 0,
      warden: 0,
      hearsay: 0,
      storyteller: 0,
      evidence: 0,
      consensus: 0,
    },
    animals: [
      {
        id: 'starter-cow',
        kind: 'cow',
        name: '团云',
        age: 3,
        careDays: 0,
        caredDay: null,
        protected: true,
      },
      {
        id: 'starter-sheep',
        kind: 'sheep',
        name: '软铃',
        age: 2,
        careDays: 0,
        caredDay: null,
        protected: true,
      },
      {
        id: 'starter-goat',
        kind: 'goat',
        name: '小坡',
        age: 0,
        careDays: 0,
        caredDay: null,
        protected: true,
      },
    ],
    catShopSales: {},
    story: {
      arcIndex: 0,
      stageIndex: 0,
      choices: {},
      completedArcs: [],
      journeyCheckpoint: 0,
      preRevealSave: false,
      ending: null,
    },
    message: '欢迎来到新芽农场。走到水工学徒面前按 E 交谈开始主线；F 查看当前该找谁，J 打开手册。',
    updatedAt: new Date().toISOString(),
  };
}

export function parseGame(raw: string | null): GameState | null {
  if (!raw) return null;
  try {
    const value = JSON.parse(raw) as Partial<GameState>;
    if (
      value.version !== 3 ||
      !value.player ||
      !value.inventory ||
      !value.plots ||
      !value.story ||
      !Array.isArray(value.animals)
    )
      return null;
    if (
      !['farm', 'market'].includes(String(value.map)) ||
      typeof value.day !== 'number' ||
      typeof value.coins !== 'number'
    )
      return null;
    return value as GameState;
  } catch {
    return null;
  }
}

function touched(state: GameState, message: string): GameState {
  return {
    ...state,
    message,
    updatedAt: new Date().toISOString(),
    hour: Math.min(23, state.hour + (state.minute >= 50 ? 1 : 0)),
    minute: (state.minute + 10) % 60,
  };
}

function delta(direction: Direction) {
  return {
    up: { x: 0, y: 1 },
    down: { x: 0, y: -1 },
    left: { x: -1, y: 0 },
    right: { x: 1, y: 0 },
  }[direction];
}

export function getTarget(state: GameState) {
  const d = delta(state.player.direction);
  return { x: state.player.x + d.x, y: state.player.y + d.y };
}

function isBlockingObject(state: GameState, x: number, y: number) {
  // Authoritative union from n-015: building collisions, environment
  // boundary, static obstacles, water cells and canal cells.
  return view(state.map as R22MapId).blocked.has(`${x},${y}`);
}

export function movePlayer(state: GameState, direction: Direction): GameState {
  const map = MAPS[state.map];
  const d = delta(direction);
  const x = Math.max(0, Math.min(map.width - 1, state.player.x + d.x));
  const y = Math.max(0, Math.min(map.height - 1, state.player.y + d.y));
  if (isBlockingObject(state, x, y))
    return touched(
      { ...state, player: { ...state.player, direction } },
      '建筑挡住了路，绕到入口或招牌旁看看。',
    );
  if (x === map.exit.x && y === map.exit.y) return travel(state);
  return touched(
    { ...state, player: { x, y, direction } },
    `${MAPS[state.map].name} · (${x + 1}, ${y + 1})`,
  );
}

export function travel(state: GameState): GameState {
  // Authoritative exits: farm (7,0) -> market spawn (9,11);
  // market (9,12) -> farm spawn (7,1).
  const map: MapId = state.map === 'farm' ? 'market' : 'farm';
  const spawn =
    map === 'farm' ? MAPS.farm.spawnFromMarket : MAPS.market.spawnFromFarm;
  return touched(
    {
      ...state,
      map,
      player: { ...spawn, direction: map === 'farm' ? 'up' : 'down' },
    },
    map === 'farm'
      ? '已回到农场与农舍。'
      : '已进入溪岸集市。七位邻里和猫食铺都在这里。',
  );
}

export function isField(x: number, y: number) {
  // n-015 farm_area: primary rectangles [x,y,w,h] + rear cultivable cells.
  const inPrimary =
    (x >= 2 && x <= 6 && y >= 2 && y <= 5) ||
    (x >= 8 && x <= 11 && y >= 2 && y <= 5);
  const inRear = (x === 7 || x === 8) && (y === 12 || y === 13);
  return inPrimary || inRear;
}

export function applyTool(state: GameState): GameState {
  const target = getTarget(state);
  if (state.map !== 'farm' || !isField(target.x, target.y))
    return touched(state, '前方不是可耕作的农田。');
  if (state.stamina < 2)
    return touched(state, '体力见底了，回农舍睡到明天吧。');
  const key = `${target.x},${target.y}`;
  const plot = state.plots[key] ?? {
    soil: 'grass',
    crop: null,
    stage: 0,
    watered: false,
  };
  let next = plot;
  const inventory = { ...state.inventory };
  let message = '';
  if (state.selectedTool === 'hoe') {
    if (plot.crop && isWithered(plot)) {
      next = { soil: 'tilled', crop: null, stage: 0, watered: false };
      message = '枯萎残株已清理，土地可以重新播种。';
    } else if (plot.soil === 'tilled') {
      return touched(state, '这格地已经翻好了。');
    } else {
      next = { soil: 'tilled', crop: null, stage: 0, watered: false };
      message = '泥土松开了。';
    }
  } else if (state.selectedTool === 'seed') {
    const seed = `${state.selectedSeed}_seed` as ItemId;
    if (plot.soil !== 'tilled' || plot.crop)
      return touched(state, '要在空的翻耕地播种。');
    if ((inventory[seed] ?? 0) < 1)
      return touched(state, `${CROPS[state.selectedSeed].seedName}不够。`);
    inventory[seed] = (inventory[seed] ?? 0) - 1;
    next = { ...plot, crop: state.selectedSeed, stage: 0, watered: false };
    message = `播下了${CROPS[state.selectedSeed].seedName}。`;
  } else if (state.selectedTool === 'water') {
    if (!plot.crop) return touched(state, '这格还没有作物。');
    if (isWithered(plot))
      return touched(state, '这株作物已经枯萎，请先清理残株。');
    if (plot.watered) return touched(state, '今天已经浇过了。');
    next = { ...plot, watered: true, dryStreak: 0 };
    message = '水慢慢渗进土里。';
  } else if (
    state.selectedTool === 'harvest' ||
    state.selectedTool === 'hand'
  ) {
    if (!plot.crop || plot.stage < CROPS[plot.crop].days)
      return touched(state, '作物还没有成熟。');
    inventory[plot.crop] = (inventory[plot.crop] ?? 0) + 1;
    message = `收获了${CROPS[plot.crop].name}。`;
    next = { soil: 'tilled', crop: null, stage: 0, watered: false };
  }
  return touched(
    {
      ...state,
      stamina: state.stamina - 2,
      inventory,
      plots: { ...state.plots, [key]: next },
    },
    message,
  );
}

export function selectTool(state: GameState, tool: Tool): GameState {
  return { ...state, selectedTool: tool };
}
export function selectSeed(state: GameState, seed: CropId): GameState {
  return { ...state, selectedSeed: seed, selectedTool: 'seed' };
}

export function sleep(state: GameState): GameState {
  const day = state.day + 1;
  const weather = (['晴', '小雨', '晴', '阴', '晴'] as const)[(day - 1) % 5];
  const rain = weather === '小雨';
  const plots = Object.fromEntries(
    Object.entries(state.plots).map(([key, plot]) => {
      if (!plot.crop) return [key, { ...plot, watered: rain, dryStreak: 0 }];
      const mature = plot.stage >= CROPS[plot.crop].days;
      const dry = plotDry(plot);
      if (mature) {
        // Mature crops are immune to wilting (native settleCrops).
        return [key, { ...plot, watered: rain, dryStreak: 0 }];
      }
      if (dry >= 3) {
        // Already withered: no growth, no watering; hoe to clear.
        return [key, { ...plot, watered: false }];
      }
      if (plot.watered || rain) {
        return [
          key,
          {
            ...plot,
            stage: Math.min(CROPS[plot.crop].days, plot.stage + 1),
            watered: rain,
            dryStreak: 0,
          },
        ];
      }
      const nextDry = Math.min(3, dry + 1);
      return [key, { ...plot, dryStreak: nextDry, watered: false }];
    }),
  );
  const witheredCount = Object.entries(state.plots).filter(
    ([, plot]) =>
      !!plot.crop &&
      plot.stage < CROPS[plot.crop].days &&
      plotDry(plot) === 2 &&
      !plot.watered &&
      !rain,
  ).length;
  const animals = state.animals.map((animal) => ({
    ...animal,
    age: animal.age + 1,
    protected: animal.protected && animal.careDays < 3,
  }));
  const base =
    rain ? '细雨替你润湿了田地。' : '新的一天开始了。';
  const wiltNote =
    witheredCount > 0 ? ` ${witheredCount} 株作物因缺水枯萎了，用锄头清理残株。` : '';
  return touched(
    {
      ...state,
      day,
      hour: 6,
      minute: 30,
      weather,
      stamina: 100,
      plots,
      animals,
      catShopSales: {},
    },
    `${base} 动物也长大了一天。${wiltNote}`,
  );
}

// Morning crop report, mirrors the native MorningCropReportService sections:
// mature (immune), required (dry 2 + no today rain -> would wither tonight),
// recommended (dry <2, growth only pauses), covered (today's rain / watering).
export interface MorningReportEntry {
  crop: string;
  cell: string;
  note: string;
}
export interface MorningReport {
  day: number;
  weather: string;
  required: MorningReportEntry[];
  recommended: MorningReportEntry[];
  mature: MorningReportEntry[];
  covered: MorningReportEntry[];
  safetyMessage: string;
  minimumStamina: number;
  fullCareStamina: number;
}
export function morningReport(state: GameState): MorningReport {
  const required: MorningReportEntry[] = [];
  const recommended: MorningReportEntry[] = [];
  const mature: MorningReportEntry[] = [];
  const covered: MorningReportEntry[] = [];
  const rainToday = state.weather === '小雨';
  for (const [key, plot] of Object.entries(state.plots)) {
    if (!plot.crop) continue;
    const [x, y] = key.split(',').map(Number);
    const crop = CROPS[plot.crop];
    const cell = `格位 (${x + 1}, ${y + 1})`;
    const ripe = plot.stage >= crop.days;
    const dry = plotDry(plot);
    if (ripe) {
      mature.push({ crop: crop.name, cell, note: '成熟作物不会因缺水枯萎' });
      continue;
    }
    if (dry >= 3) continue; // withered: not actionable in the report
    if (rainToday) {
      covered.push({ crop: crop.name, cell, note: '今日雨水会浇灌' });
    } else if (dry === 2) {
      required.push({
        crop: crop.name,
        cell,
        note: `已连续缺水 ${dry} 天，今晚不处理会枯萎`,
      });
    } else {
      recommended.push({
        crop: crop.name,
        cell,
        note: dry === 1 ? '已暂停成长一晚' : '当前不会在今晚枯萎',
      });
    }
  }
  const safetyMessage = required.length
    ? `还有 ${required.length} 格作物今晚必须照料，否则会枯萎。`
    : '没有必须处理的作物，田地都安全。';
  const waterCost = 2;
  return {
    day: state.day,
    weather: state.weather,
    required,
    recommended,
    mature,
    covered,
    safetyMessage,
    minimumStamina: required.length * waterCost,
    fullCareStamina: (required.length + recommended.length) * waterCost,
  };
}

const GATHER_REWARDS: Record<string, Partial<Record<ItemId, number>>> = {
  wood: { creek_wood: 8 },
  moss: { moss_stone: 4 },
  reed: { reed_fiber: 6 },
  brook: { moss_stone: 6 },
};

export function gather(state: GameState, id: string): GameState {
  const key = `${state.map}:${id}`;
  if (state.gathered.includes(key) || (state.map === 'farm' && state.gathered.includes(id)))
    return touched(state, '这个采集点已经收拾过了。');
  const rewards = GATHER_REWARDS[id];
  if (!rewards) return touched(state, '这里没有可采集资源。');
  const inventory = { ...state.inventory };
  Object.entries(rewards).forEach(([item, qty]) => {
    inventory[item as ItemId] = (inventory[item as ItemId] ?? 0) + (qty ?? 0);
  });
  return touched(
    {
      ...state,
      stamina: Math.max(0, state.stamina - 2),
      inventory,
      gathered: [...state.gathered, key],
    },
    `采集完成：${Object.entries(rewards)
      .map(([id2, qty]) => `${ITEM_NAMES[id2]}×${qty}`)
      .join('、')}。`,
  );
}

export const CRAFTS = [
  {
    id: 'canal_segment',
    name: '水渠接片',
    needs: { creek_wood: 6, moss_stone: 4 },
  },
  {
    id: 'rain_barrel',
    name: '雨水桶',
    needs: { creek_wood: 5, reed_fiber: 3 },
  },
  { id: 'wooden_crate', name: '木箱', needs: { creek_wood: 4 } },
  {
    id: 'compost_rack',
    name: '堆肥架',
    needs: { creek_wood: 3, reed_fiber: 2 },
  },
  {
    id: 'woodhoney_hearth',
    name: '木蜜灶台',
    needs: { creek_wood: 5, moss_stone: 2 },
  },
] as const;

export function craft(state: GameState, recipeId: string): GameState {
  const recipe = CRAFTS.find((value) => value.id === recipeId);
  if (!recipe) return touched(state, '未找到这个制作配方。');
  const inventory = { ...state.inventory };
  const missing = Object.entries(recipe.needs).find(
    ([item, qty]) => (inventory[item as ItemId] ?? 0) < qty,
  );
  if (missing) return touched(state, `${ITEM_NAMES[missing[0]]}不足。`);
  Object.entries(recipe.needs).forEach(([item, qty]) => {
    inventory[item as ItemId] = (inventory[item as ItemId] ?? 0) - qty;
  });
  inventory[recipe.id as ItemId] = (inventory[recipe.id as ItemId] ?? 0) + 1;
  return touched({ ...state, inventory }, `制作完成：${recipe.name}。`);
}

export function placeCrafted(
  state: GameState,
  id: keyof GameState['placed'],
): GameState {
  const inventory = { ...state.inventory };
  if ((inventory[id] ?? 0) < 1)
    return touched(state, `背包里没有${ITEM_NAMES[id]}。`);
  inventory[id] = (inventory[id] ?? 0) - 1;
  const quest =
    id === 'canal_segment'
      ? { ...state.quest, canalPlaced: true }
      : state.quest;
  const watershed =
    id === 'canal_segment' && !state.quest.canalPlaced
      ? state.watershed + 12
      : state.watershed;
  return touched(
    {
      ...state,
      inventory,
      placed: { ...state.placed, [id]: (state.placed[id] ?? 0) + 1 },
      quest,
      watershed,
    },
    id === 'canal_segment'
      ? '水渠接片咬合旧铜闸，水脉恢复了 12 点。去集市向水工学徒回报。'
      : `${ITEM_NAMES[id]}已安放在农场。`,
  );
}

export const PROCESSING = [
  {
    id: 'leaf_preserve',
    name: '溪叶渍菜',
    input: 'stream_leaf' as ItemId,
    output: 'leaf_preserve' as ItemId,
    price: 98,
  },
  {
    id: 'amber_paste',
    name: '琥珀豆酱',
    input: 'amber_bean' as ItemId,
    output: 'amber_paste' as ItemId,
    price: 128,
  },
  {
    id: 'berry_glaze',
    name: '铃莓釉',
    input: 'bell_berry' as ItemId,
    output: 'berry_glaze' as ItemId,
    price: 158,
  },
  {
    id: 'melon_syrup',
    name: '蜜穗糖浆',
    input: 'honey_melon' as ItemId,
    output: 'melon_syrup' as ItemId,
    price: 202,
  },
];

export function processItem(state: GameState, id: string): GameState {
  const recipe = PROCESSING.find((value) => value.id === id);
  if (!recipe || (state.inventory[recipe.input] ?? 0) < 1)
    return touched(state, '原料不足，木蜜灶台没有启动。');
  const inventory = {
    ...state.inventory,
    [recipe.input]: (state.inventory[recipe.input] ?? 0) - 1,
    [recipe.output]: (state.inventory[recipe.output] ?? 0) + 1,
  };
  return touched({ ...state, inventory }, `加工完成：${recipe.name}。`);
}

export function shipAll(state: GameState): GameState {
  const inventory = { ...state.inventory };
  let income = 0;
  let count = 0;
  Object.values(CROPS).forEach((crop) => {
    const qty = inventory[crop.id] ?? 0;
    income += qty * crop.price;
    count += qty;
    inventory[crop.id] = 0;
  });
  PROCESSING.forEach((recipe) => {
    const qty = inventory[recipe.output] ?? 0;
    income += qty * recipe.price;
    count += qty;
    inventory[recipe.output] = 0;
  });
  if (!count) return touched(state, '出售箱里没有可结算的作物或加工品。');
  return touched(
    { ...state, inventory, coins: state.coins + income },
    `出售 ${count} 份货物，收入 ${income} 溪票。`,
  );
}

export function careAnimal(state: GameState, id: string): GameState {
  const animal = state.animals.find((value) => value.id === id);
  if (!animal) return touched(state, '没有找到这只动物。');
  if (animal.caredDay === state.day)
    return touched(state, `${animal.name}今天已经照料过了。`);
  if (state.stamina < 2) return touched(state, '体力不足。');
  const animals = state.animals.map((value) =>
    value.id === id
      ? {
          ...value,
          careDays: value.careDays + 1,
          caredDay: state.day,
          protected: value.careDays + 1 < 3,
        }
      : value,
  );
  return touched(
    { ...state, animals, stamina: state.stamina - 2 },
    `给${animal.name}添水、梳毛，它安静地蹭了蹭你。`,
  );
}

export function catShopSellCrop(state: GameState, crop: CropId): GameState {
  const qty = state.inventory[crop] ?? 0;
  const key = `crop:${crop}`;
  const sold = state.catShopSales[key] ?? 0;
  const amount = Math.min(qty, 6 - sold);
  if (amount <= 0)
    return touched(state, '今天没有可交付数量，或该报价已到上限。');
  const unit = Math.max(
    CROPS[crop].price + 1,
    Math.floor(CROPS[crop].price * 1.1),
  );
  return touched(
    {
      ...state,
      inventory: { ...state.inventory, [crop]: qty - amount },
      coins: state.coins + amount * unit,
      catShopSales: { ...state.catShopSales, [key]: sold + amount },
    },
    `猫店收购${CROPS[crop].name}×${amount}，即时支付 ${amount * unit} 溪票。`,
  );
}

export function catShopSellAnimal(state: GameState, id: string): GameState {
  const animal = state.animals.find((value) => value.id === id);
  if (!animal) return touched(state, '没有找到这只动物。');
  if (animal.protected || animal.careDays < 3)
    return touched(
      state,
      `${animal.name}仍在农场保护期，不能交接。连续温和照料三天后再决定。`,
    );
  const price =
    animal.kind === 'cow' ? 420 : animal.kind === 'sheep' ? 300 : 260;
  return touched(
    {
      ...state,
      animals: state.animals.filter((value) => value.id !== id),
      coins: state.coins + price,
    },
    `已与猫店完成${animal.name}的非暴力抽象交接，收到 ${price} 溪票。`,
  );
}

export function talkToNpc(state: GameState, npcId: string): GameState {
  const relationships = {
    ...state.relationships,
    [npcId]: Math.min(100, (state.relationships[npcId] ?? 0) + 1),
  };
  let next = { ...state, relationships };
  if (
    npcId === 'apprentice' &&
    state.quest.canalPlaced &&
    !state.quest.canalReported
  ) {
    next = {
      ...next,
      quest: { ...state.quest, canalReported: true },
      watershed: state.watershed + 8,
      recipesUnlocked: [...new Set([...state.recipesUnlocked, 'rain_barrel'])],
    };
    return touched(
      next,
      '水工学徒确认修复。水脉 12+8 达到 20，雨水桶配方已解锁。',
    );
  }
  if (npcId === 'warden' && !state.quest.noticeRead)
    next.quest = { ...state.quest, noticeRead: true };
  const labels: Record<string, string> = {
    apprentice: '水工学徒检查着铜闸刻度。',
    steward: '种源管理员给你留了几包种子。',
    warden: '溪岸巡护员提醒你留意水口。',
    hearsay: '涧麦婶讲起了今天集市的新鲜事。',
    storyteller: '石灯把传闻记进随身小册。',
    evidence: '青砚正在比对岸边痕迹。',
    consensus: '絮宁问你今天过得怎么样。',
  };
  return touched(next, labels[npcId] ?? '你们聊了一会儿。');
}

export function buySeeds(state: GameState, crop: CropId): GameState {
  const cost = Math.max(12, Math.floor(CROPS[crop].price * 0.45));
  if (state.coins < cost) return touched(state, '溪票不够。');
  const seed = `${crop}_seed` as ItemId;
  return touched(
    {
      ...state,
      coins: state.coins - cost,
      inventory: {
        ...state.inventory,
        [seed]: (state.inventory[seed] ?? 0) + 4,
      },
    },
    `买到${CROPS[crop].seedName}×4。`,
  );
}

export function advanceStory(
  state: GameState,
  arcId: string,
  stageCount: number,
  choice?: string,
): GameState {
  const story = { ...state.story, choices: { ...state.story.choices } };
  if (choice) story.choices[`${arcId}:${story.stageIndex}`] = choice;
  if (arcId === 'q09' && !story.preRevealSave) story.preRevealSave = true;
  if (arcId === 'q10' && choice && ['water', 'leave'].includes(choice))
    story.ending = choice as 'water' | 'leave';
  if (story.stageIndex + 1 >= stageCount) {
    story.completedArcs = [...new Set([...story.completedArcs, arcId])];
    story.arcIndex = Math.min(9, story.arcIndex + 1);
    story.stageIndex =
      story.arcIndex >= 9 && arcId === 'q10' ? stageCount - 1 : 0;
  } else story.stageIndex += 1;
  const standing =
    Number(arcId.slice(1)) <= 7 &&
    !state.story.completedArcs.includes(arcId) &&
    story.completedArcs.includes(arcId)
      ? Math.min(100, state.standing + 6)
      : state.standing;
  return touched(
    { ...state, story, standing },
    story.completedArcs.includes('q10')
      ? `毕业结局已记录：${story.ending === 'leave' ? '离开农场' : '最后一次浇水'}。`
      : `剧情推进：${arcId.toUpperCase()}。`,
  );
}

export function completeJourneyCheckpoint(state: GameState): GameState {
  const checkpoint = Math.min(3, state.story.journeyCheckpoint + 1);
  return touched(
    { ...state, story: { ...state.story, journeyCheckpoint: checkpoint } },
    checkpoint === 3
      ? '雾岭三处检查点完成，可以继续救援与返乡。'
      : `雾岭检查点 ${checkpoint}/3 已确认。`,
  );
}

export function objective(state: GameState) {
  if (!state.quest.canalPlaced) return '采集溪木与苔石，制作并安放水渠接片';
  if (!state.quest.canalReported)
    return '前往溪岸集市，向水工学徒回报旧铜闸修复';
  if (state.story.completedArcs.length < 10)
    return `主线 Q${String(state.story.arcIndex + 1).padStart(2, '0')} · 打开剧情手册继续`;
  return `毕业后 · ${state.story.ending === 'leave' ? '新的路已经开始' : '守住最后一畦水光'}`;
}

export function countInventory(state: GameState) {
  return Object.values(state.inventory).reduce(
    (sum, qty) => sum + (qty ?? 0),
    0,
  );
}
