export const GRID_WIDTH = 12;
export const GRID_HEIGHT = 8;

export type Direction = 'up' | 'down' | 'left' | 'right';
export type Tool = 'hoe' | 'seed' | 'water' | 'harvest';

export type Plot = {
  soil: 'grass' | 'tilled';
  crop: null | { stage: 0 | 1 | 2 | 3; watered: boolean };
};

export type Milestones = {
  tilled: boolean;
  planted: boolean;
  watered: boolean;
  ripe: boolean;
  harvested: boolean;
  sold: boolean;
};

export type GameState = {
  version: 1;
  day: number;
  stamina: number;
  coins: number;
  seeds: number;
  produce: number;
  player: { x: number; y: number; direction: Direction };
  plots: Record<string, Plot>;
  milestones: Milestones;
  message: string;
};

const SHIPPING_BIN = { x: 10, y: 5 };

export function createInitialGame(): GameState {
  return {
    version: 1,
    day: 1,
    stamina: 100,
    coins: 120,
    seeds: 6,
    produce: 0,
    player: { x: 7, y: 4, direction: 'left' },
    plots: {},
    milestones: {
      tilled: false,
      planted: false,
      watered: false,
      ripe: false,
      harvested: false,
      sold: false,
    },
    message: '向左走到田边，翻开第一格土地。',
  };
}

export function isField(x: number, y: number) {
  return x >= 2 && x <= 6 && y >= 2 && y <= 6;
}

export function getTarget(state: GameState) {
  const delta = {
    up: { x: 0, y: -1 },
    down: { x: 0, y: 1 },
    left: { x: -1, y: 0 },
    right: { x: 1, y: 0 },
  }[state.player.direction];
  return { x: state.player.x + delta.x, y: state.player.y + delta.y };
}

export function movePlayer(state: GameState, direction: Direction): GameState {
  const delta = {
    up: { x: 0, y: -1 },
    down: { x: 0, y: 1 },
    left: { x: -1, y: 0 },
    right: { x: 1, y: 0 },
  }[direction];
  const x = Math.max(0, Math.min(GRID_WIDTH - 1, state.player.x + delta.x));
  const y = Math.max(0, Math.min(GRID_HEIGHT - 1, state.player.y + delta.y));
  if (x === SHIPPING_BIN.x && y === SHIPPING_BIN.y) {
    return {
      ...state,
      player: { ...state.player, direction },
      message: '木箱装得很结实，站到它旁边就好。',
    };
  }
  return {
    ...state,
    player: { x, y, direction },
    message: isAdjacentToShippingBin({ x, y })
      ? '你到了出售箱旁。收成可以换成溪票。'
      : state.message,
  };
}

export function applyTool(state: GameState, tool: Tool): GameState {
  const target = getTarget(state);
  if (!isField(target.x, target.y))
    return { ...state, message: '前方不是可耕作的田地。' };
  if (state.stamina < 2)
    return { ...state, message: '体力见底了，先睡到明天吧。' };

  const key = `${target.x},${target.y}`;
  const plot = state.plots[key] ?? { soil: 'grass', crop: null };
  const milestones = { ...state.milestones };
  let nextPlot: Plot = plot;
  let message = '';

  if (tool === 'hoe') {
    if (plot.soil === 'tilled')
      return { ...state, message: '这格土地已经翻好了。' };
    nextPlot = { soil: 'tilled', crop: null };
    milestones.tilled = true;
    message = '泥土松开了，闻起来像刚下过雨。';
  } else if (tool === 'seed') {
    if (plot.soil !== 'tilled' || plot.crop)
      return { ...state, message: '要先找一格空的翻耕地。' };
    if (state.seeds <= 0) return { ...state, message: '雾萝卜种子用完了。' };
    nextPlot = { soil: 'tilled', crop: { stage: 0, watered: false } };
    milestones.planted = true;
    message = '种子落进土里，轻轻盖好了。';
  } else if (tool === 'water') {
    if (!plot.crop) return { ...state, message: '这里还没有作物需要浇水。' };
    if (plot.crop.watered) return { ...state, message: '今天已经浇过水了。' };
    nextPlot = { ...plot, crop: { ...plot.crop, watered: true } };
    milestones.watered = true;
    message = '水慢慢渗进土里。睡一觉，它会长大。';
  } else {
    if (!plot.crop || plot.crop.stage < 3)
      return { ...state, message: '还没成熟，再照料几天吧。' };
    nextPlot = { soil: 'tilled', crop: null };
    milestones.harvested = true;
    message = '收获一颗雾萝卜！去右下角的木箱旁出售吧。';
  }

  return {
    ...state,
    stamina: state.stamina - 2,
    seeds: tool === 'seed' ? state.seeds - 1 : state.seeds,
    produce: tool === 'harvest' ? state.produce + 1 : state.produce,
    plots: { ...state.plots, [key]: nextPlot },
    milestones,
    message,
  };
}

export function advanceDay(state: GameState): GameState {
  let ripe = state.milestones.ripe;
  const plots = Object.fromEntries(
    Object.entries(state.plots).map(([key, plot]) => {
      if (!plot.crop) return [key, plot];
      const stage = plot.crop.watered
        ? (Math.min(3, plot.crop.stage + 1) as 0 | 1 | 2 | 3)
        : plot.crop.stage;
      if (stage === 3) ripe = true;
      return [key, { ...plot, crop: { stage, watered: false } }];
    }),
  );
  return {
    ...state,
    day: state.day + 1,
    stamina: 100,
    plots,
    milestones: { ...state.milestones, ripe },
    message: ripe
      ? '清晨的雾散了，田里有作物成熟了。'
      : '新的一天。浇过水的嫩芽又长高了一点。',
  };
}

export function isAdjacentToShippingBin(player: { x: number; y: number }) {
  return (
    Math.abs(player.x - SHIPPING_BIN.x) +
      Math.abs(player.y - SHIPPING_BIN.y) ===
    1
  );
}

export function sellProduce(state: GameState): GameState {
  if (!isAdjacentToShippingBin(state.player))
    return { ...state, message: '要站到右下角的木箱旁才能出售。' };
  if (state.produce === 0)
    return { ...state, message: '背包里还没有可出售的收成。' };
  const income = state.produce * 58;
  return {
    ...state,
    coins: state.coins + income,
    produce: 0,
    milestones: { ...state.milestones, sold: true },
    message: `木箱收下了作物，到账 ${income} 溪票。`,
  };
}

export function parseGame(raw: string | null): GameState | null {
  if (!raw) return null;
  try {
    const parsed = JSON.parse(raw) as Partial<GameState>;
    if (
      parsed.version !== 1 ||
      typeof parsed.day !== 'number' ||
      typeof parsed.stamina !== 'number' ||
      typeof parsed.coins !== 'number' ||
      typeof parsed.seeds !== 'number' ||
      typeof parsed.produce !== 'number' ||
      !parsed.player ||
      !parsed.plots ||
      !parsed.milestones
    )
      return null;
    return parsed as GameState;
  } catch {
    return null;
  }
}
