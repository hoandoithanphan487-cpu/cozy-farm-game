// Strict GameState payload validator used by the save store and import path.
import type { SaveValidator } from './save-store.ts';
import { MAPS, CROPS } from '../lib/full-game.ts';

export const CURRENT_SCHEMA = 3;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isFiniteNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

/** Structural + semantic validation of a web GameState v3 payload. */
export function validateGamePayload(raw: string): { ok: boolean; error?: string } {
  let value: unknown;
  try {
    value = JSON.parse(raw);
  } catch {
    return { ok: false, error: 'not JSON' };
  }
  if (!isRecord(value)) return { ok: false, error: 'not an object' };
  if (value.version !== CURRENT_SCHEMA) {
    return { ok: false, error: `unsupported version ${String(value.version)}` };
  }
  if (typeof value.campaignId !== 'string' || !value.campaignId) {
    return { ok: false, error: 'missing campaignId' };
  }
  if (!isFiniteNumber(value.day) || value.day < 1 || value.day > 999) {
    return { ok: false, error: 'invalid day' };
  }
  if (!isFiniteNumber(value.coins) || value.coins < 0) {
    return { ok: false, error: 'invalid coins' };
  }
  if (!isFiniteNumber(value.stamina) || value.stamina < 0 || value.stamina > 200) {
    return { ok: false, error: 'invalid stamina' };
  }
  if (!isFiniteNumber(value.watershed) || value.watershed < 0 || value.watershed > 40) {
    return { ok: false, error: 'invalid watershed' };
  }
  if (!isRecord(value.player)) return { ok: false, error: 'missing player' };
  const mapId = value.map;
  if (mapId !== 'farm' && mapId !== 'market') return { ok: false, error: 'invalid map' };
  const map = MAPS[mapId];
  const player = value.player as Record<string, unknown>;
  if (
    !isFiniteNumber(player.x) || !isFiniteNumber(player.y) ||
    player.x < 0 || player.x >= map.width || player.y < 0 || player.y >= map.height
  ) {
    return { ok: false, error: 'player outside map' };
  }
  const directions = ['up', 'down', 'left', 'right'];
  if (!directions.includes(String(player.direction))) {
    return { ok: false, error: 'invalid player direction' };
  }
  if (!isRecord(value.inventory)) return { ok: false, error: 'missing inventory' };
  for (const [item, qty] of Object.entries(value.inventory)) {
    if (!isFiniteNumber(qty) || (qty as number) < 0 || (qty as number) > 9999) {
      return { ok: false, error: `invalid inventory qty ${item}` };
    }
  }
  if (!isRecord(value.plots)) return { ok: false, error: 'missing plots' };
  for (const [plotKey, plot] of Object.entries(value.plots)) {
    const match = /^(-?\d+),(-?\d+)$/.exec(plotKey);
    if (!match) return { ok: false, error: `bad plot key ${plotKey}` };
    const px = Number(match[1]);
    const py = Number(match[2]);
    if (px < 0 || px >= map.width || py < 0 || py >= map.height) {
      return { ok: false, error: `plot outside map ${plotKey}` };
    }
    if (!isRecord(plot)) return { ok: false, error: `bad plot ${plotKey}` };
    if (plot.soil !== 'grass' && plot.soil !== 'tilled') {
      return { ok: false, error: `bad soil ${plotKey}` };
    }
    if (plot.crop !== null && typeof plot.crop === 'string' && !(plot.crop in CROPS)) {
      return { ok: false, error: `unknown crop ${plot.crop}` };
    }
    if (
      plot.crop &&
      typeof plot.crop === 'string' &&
      (!isFiniteNumber(plot.stage) || (plot.stage as number) < 0)
    ) {
      return { ok: false, error: `bad stage ${plotKey}` };
    }
    if (
      plot.dryStreak !== undefined &&
      (!isFiniteNumber(plot.dryStreak) ||
        (plot.dryStreak as number) < 0 ||
        (plot.dryStreak as number) > 3)
    ) {
      return { ok: false, error: `bad dryStreak ${plotKey}` };
    }
  }
  if (!isRecord(value.story)) return { ok: false, error: 'missing story' };
  if (!Array.isArray(value.gathered)) return { ok: false, error: 'missing gathered' };
  if (!Array.isArray(value.animals)) return { ok: false, error: 'missing animals' };
  if (!isRecord(value.placed)) return { ok: false, error: 'missing placed' };
  if (!Array.isArray(value.relationships) && !isRecord(value.relationships)) {
    return { ok: false, error: 'missing relationships' };
  }
  if (!Array.isArray(value.catShopSales) && !isRecord(value.catShopSales)) {
    return { ok: false, error: 'missing catShopSales' };
  }
  return { ok: true };
}

export const gameValidator: SaveValidator = {
  validate: validateGamePayload,
  currentVersion: CURRENT_SCHEMA,
};
