// Q08 journey mini-scenes: transcribed from the authoritative macOS catalogs
// (Content/StoryAnchorCatalog.swift + Content/StoryContentModels.swift),
// read-only port for the web runtime. Scene order matches
// JourneyCheckpointOrder: old waterway -> mist ridge fork -> grey fence farm.

export type JourneyPurpose =
  | 'entry'
  | 'exit'
  | 'interaction'
  | 'playerWaypoint'
  | 'camera'
  | 'npcStart'
  | 'npcExit'
  | 'prop';

export type JourneySceneId =
  | 'old_waterway'
  | 'mist_ridge_fork'
  | 'greygate_farm';

export type JourneyAnchor = {
  id: string;
  scene: JourneySceneId;
  x: number;
  y: number;
  purpose: JourneyPurpose;
};

export type JourneySceneDef = {
  id: JourneySceneId;
  name: string;
  entryAnchorId: string;
  exitAnchorId: string;
  // Normalized collision rects as [minX, minY, maxX, maxY].
  collisions: Array<[number, number, number, number]>;
};

const prefix = 'brookseed.story.anchor.journey.';

export const JOURNEY_SCENES: JourneySceneDef[] = [
  {
    id: 'old_waterway',
    name: '旧水路',
    entryAnchorId: `${prefix}old_waterway.entry`,
    exitAnchorId: `${prefix}old_waterway.exit`,
    collisions: [[0.43, 0.43, 0.56, 0.57]],
  },
  {
    id: 'mist_ridge_fork',
    name: '雾岭岔路',
    entryAnchorId: `${prefix}mist_ridge.entry`,
    exitAnchorId: `${prefix}mist_ridge.exit`,
    collisions: [[0.47, 0.47, 0.54, 0.55]],
  },
  {
    id: 'greygate_farm',
    name: '灰栅农场',
    entryAnchorId: `${prefix}greygate.entry`,
    exitAnchorId: `${prefix}greygate.exit`,
    collisions: [[0.52, 0.42, 0.61, 0.59]],
  },
];

const a = (
  suffix: string,
  scene: JourneySceneId,
  x: number,
  y: number,
  purpose: JourneyPurpose,
): JourneyAnchor => ({ id: `${prefix}${suffix}`, scene, x, y, purpose });

export const JOURNEY_ANCHORS: JourneyAnchor[] = [
  // old waterway
  a('old_waterway.entry', 'old_waterway', 0.08, 0.5, 'entry'),
  a('old_waterway.exit', 'old_waterway', 0.92, 0.5, 'exit'),
  a('old_waterway.sluice', 'old_waterway', 0.32, 0.34, 'interaction'),
  a('old_waterway.drain', 'old_waterway', 0.7, 0.66, 'interaction'),
  a('old_waterway.camera', 'old_waterway', 0.5, 0.12, 'camera'),
  // mist ridge fork
  a('mist_ridge.entry', 'mist_ridge_fork', 0.08, 0.78, 'entry'),
  a('mist_ridge.exit', 'mist_ridge_fork', 0.92, 0.18, 'exit'),
  a('mist_ridge.white_stone', 'mist_ridge_fork', 0.3, 0.62, 'playerWaypoint'),
  a('mist_ridge.track', 'mist_ridge_fork', 0.44, 0.4, 'interaction'),
  a('mist_ridge.burnt_paper', 'mist_ridge_fork', 0.58, 0.62, 'interaction'),
  a('mist_ridge.broken_bell', 'mist_ridge_fork', 0.73, 0.37, 'interaction'),
  a('mist_ridge.evidence_route', 'mist_ridge_fork', 0.8, 0.24, 'playerWaypoint'),
  a('mist_ridge.trade_route', 'mist_ridge_fork', 0.77, 0.48, 'playerWaypoint'),
  a('mist_ridge.waterway_route', 'mist_ridge_fork', 0.67, 0.78, 'playerWaypoint'),
  a('mist_ridge.camera', 'mist_ridge_fork', 0.5, 0.1, 'camera'),
  // grey fence farm
  a('greygate.entry', 'greygate_farm', 0.08, 0.5, 'entry'),
  a('greygate.exit', 'greygate_farm', 0.92, 0.5, 'exit'),
  a('greygate.evidence_table', 'greygate_farm', 0.34, 0.28, 'interaction'),
  a('greygate.trade_yard', 'greygate_farm', 0.48, 0.72, 'interaction'),
  a('greygate.waterway_outlet', 'greygate_farm', 0.66, 0.7, 'interaction'),
  a('greygate.bell_princess', 'greygate_farm', 0.74, 0.34, 'interaction'),
  a('greygate.camera', 'greygate_farm', 0.54, 0.1, 'camera'),
];

// Native SwiftUI colors (StoryJourneySceneView.anchorColor).
export const JOURNEY_ANCHOR_STYLE: Record<JourneyPurpose, { label: string; color: string }> = {
  entry: { label: '入口', color: 'rgba(0,122,255,0.65)' },
  exit: { label: '出口', color: 'rgba(52,199,89,0.65)' },
  interaction: { label: '检查点', color: 'rgba(255,149,0,0.75)' },
  playerWaypoint: { label: '路点', color: 'rgba(255,255,255,0.35)' },
  camera: { label: '', color: 'rgba(255,255,255,0.2)' },
  npcStart: { label: '', color: 'rgba(255,255,255,0.2)' },
  npcExit: { label: '', color: 'rgba(255,255,255,0.2)' },
  prop: { label: '', color: 'rgba(255,255,255,0.2)' },
};

// Player avatar theme from CharacterVisualCatalog (sprout): theme 木蜜衣
// rgb(0.93,0.78,0.42) #EDC76B, outline 苔边 rgb(0.22,0.45,0.38) #387361.
export const JOURNEY_PLAYER = {
  fill: '#edc76b',
  outline: '#387361',
};
