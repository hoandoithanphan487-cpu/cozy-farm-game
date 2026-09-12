/**
 * Native `StoryAnchorCatalog.worldGridAnchors` (transcribed): the grid cells
 * where a story beat may be raised. Standing on one of these cells lets the
 * interact key open the pending dialogue, exactly like the macOS scene — any
 * other cell keeps the interact key on farming and tools.
 */
export type StoryWorldAnchor = { id: string; x: number; y: number };

export const STORY_WORLD_ANCHORS: Record<'farm' | 'market', StoryWorldAnchor[]> = {
  farm: [
    { id: 'farm.entry', x: 7, y: 1 },
    { id: 'farm.main_south', x: 7, y: 2 },
    { id: 'farm.field_west', x: 5, y: 6 },
    { id: 'farm.field_east', x: 9, y: 6 },
    { id: 'farm.field_edge', x: 6, y: 5 },
    { id: 'farm.main_center', x: 7, y: 7 },
    { id: 'farm.workyard', x: 8, y: 7 },
    { id: 'farm.house_interaction', x: 3, y: 7 },
    { id: 'farm.sluice_interaction', x: 12, y: 7 },
    { id: 'farm.canal_bank_north', x: 12, y: 6 },
    { id: 'farm.canal_bank_mid', x: 12, y: 4 },
    { id: 'farm.canal_tail', x: 12, y: 2 },
    { id: 'farm.stone_steps', x: 7, y: 1 },
  ],
  market: [
    { id: 'market.entry', x: 9, y: 11 },
    { id: 'market.steps', x: 9, y: 11 },
    { id: 'market.axis_north', x: 9, y: 9 },
    { id: 'market.axis_center', x: 9, y: 8 },
    { id: 'market.axis_south', x: 9, y: 5 },
    { id: 'market.table_west', x: 5, y: 7 },
    { id: 'market.table_south', x: 6, y: 6 },
    { id: 'market.record_table', x: 11, y: 6 },
    { id: 'market.waterside_walk', x: 8, y: 5 },
    { id: 'market.cat_shop_front', x: 14, y: 5 },
    { id: 'market.cat_shop_side', x: 13, y: 5 },
    { id: 'market.cat_shop_curtain', x: 15, y: 5 },
    { id: 'market.seed_shed', x: 1, y: 8 },
    { id: 'market.warden_post', x: 16, y: 8 },
    { id: 'market.wharf_departure', x: 3, y: 5 },
  ],
};

export function storyAnchorAt(
  map: 'farm' | 'market',
  x: number,
  y: number,
): StoryWorldAnchor | null {
  return STORY_WORLD_ANCHORS[map].find((a) => a.x === x && a.y === y) ?? null;
}

/**
 * Story speaker -> world NPC mapping.
 *
 * `story.json` lines carry a `speaker` (camelCase). Most speakers are residents
 * that exist on the world grid (WorldCatalog.npcs positions / world-life cats),
 * so a stage is advanced by FINDING that person and talking to them instead of
 * playing one mixed ensemble dialogue. Speakers without world presence (system
 * narration, journey-only cast) are read directly with the story key.
 */
export type StorySpeakerTarget = {
  npcId: string;
  map: 'farm' | 'market';
  x: number;
  y: number;
  label: string;
};

export const STORY_SPEAKER_TARGETS: Record<string, StorySpeakerTarget[]> = {
  waterApprentice: [
    { npcId: 'apprentice', map: 'farm', x: 8, y: 6, label: '水工学徒' },
    { npcId: 'apprentice', map: 'market', x: 3, y: 6, label: '水工学徒' },
  ],
  seedSteward: [{ npcId: 'steward', map: 'market', x: 4, y: 9, label: '种源管理员' }],
  creekWarden: [{ npcId: 'warden', map: 'market', x: 13, y: 9, label: '溪岸巡护员' }],
  neighborHearsay: [{ npcId: 'hearsay', map: 'market', x: 5, y: 7, label: '涧麦婶' }],
  neighborStoryteller: [
    { npcId: 'storyteller', map: 'market', x: 7, y: 6, label: '石灯' },
  ],
  neighborEvidence: [{ npcId: 'evidence', map: 'market', x: 11, y: 6, label: '青砚' }],
  neighborConsensus: [{ npcId: 'consensus', map: 'market', x: 7, y: 11, label: '絮宁' }],
  // Cat-shop staff live in the world-life layer; the shop zone hosts them.
  catShopBlack: [{ npcId: 'cat-shop', map: 'market', x: 10, y: 9, label: '黑猫店员' }],
  catShopCalico: [{ npcId: 'cat-shop', map: 'market', x: 13, y: 6, label: '三花店员' }],
  catShopRagdoll: [{ npcId: 'cat-shop', map: 'market', x: 10, y: 6, label: '布偶猫店员' }],
};

/** All world targets for a speaker (a resident may appear on two maps). */
export function speakerTargets(speaker: string | null | undefined): StorySpeakerTarget[] {
  if (!speaker) return [];
  return STORY_SPEAKER_TARGETS[speaker] ?? [];
}

/** True when the speaker has to be found on the world grid. */
export function speakerNeedsTravel(speaker: string | null | undefined): boolean {
  return speakerTargets(speaker).length > 0;
}

/** The target on the map the player is currently standing on, if any. */
export function speakerTargetOnMap(
  speaker: string | null | undefined,
  map: 'farm' | 'market',
): StorySpeakerTarget | null {
  return speakerTargets(speaker).find((t) => t.map === map) ?? null;
}
