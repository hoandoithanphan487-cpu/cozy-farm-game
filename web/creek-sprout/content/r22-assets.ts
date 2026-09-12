// N-031 R3 authoritative runtime asset catalog (presentation only).
// Mirrors macos/CreekSprout/CreekSprout/Presentation/{RuntimeArtCatalog,
// PixelAssetStore,PixelAssetCatalog,WorldLifeCatalog,WorldVisualCatalog}.
// Every filename here must exist under public/full-assets (see audit:parity).

export const ASSETS = '/full-assets/assets';
export const WORLD = '/full-assets/world';
export const DISPLAY_R2 = '/full-assets/display-r2';

export type WorldLifeKind =
  | 'bird' | 'duck' | 'frog' | 'hedgehog' | 'rabbit' | 'squirrel'
  | 'flower01' | 'flower02' | 'flower03' | 'flower04'
  | 'shrub01' | 'shrub02' | 'shrub03' | 'shrub04'
  | 'treeMaple' | 'treeHoneyPear' | 'treeMistPine' | 'treeCreekWillow'
  | 'farmHen' | 'farmCow' | 'farmSheep' | 'farmGoat' | 'farmPig' | 'farmGoose'
  | 'catBbqShop' | 'catBlack' | 'catCalico' | 'catRagdoll'
  | 'gardenBed'
  | 'cropMistRadish' | 'cropStreamLeaf' | 'cropAmberBean' | 'cropBellBerry'
  | 'cropHoneyMelon'
  | 'fenceHorizontal' | 'fenceVertical' | 'fenceCornerNW' | 'fenceCornerNE'
  | 'fenceCornerSW' | 'fenceCornerSE' | 'fencePost'
  | 'pastureGrass01' | 'pastureGrass02' | 'pastureGrass03' | 'pastureGrass04'
  | 'farmMountainBackdrop' | 'marketCreekValleyBackdrop'
  | 'riverStone01' | 'riverStone02' | 'riverStone03' | 'riverStone04'
  | 'flowerMeadow' | 'sunflowerField' | 'haystack' | 'farmDiningSet'
  | 'marketGreenhouse' | 'marketScenicLake' | 'scenicTilled'
  | 'bankNorth01' | 'bankNorth02' | 'bankNorth03' | 'bankNorth04'
  | 'bankSouth01' | 'bankSouth02' | 'bankSouth03' | 'bankSouth04';

export type KindCategory =
  | 'animal' | 'catStaff' | 'shrub' | 'flower' | 'tree' | 'fence'
  | 'fieldPatch' | 'haystack' | 'diningSet' | 'greenhouse' | 'scenicLake'
  | 'scenicTilled' | 'shoreInset' | 'riverStone' | 'pastureGround'
  | 'cropDisplay' | 'gardenBed' | 'backdrop' | 'catBbqShop';

/** WorldLifeKind -> display asset file (authoritative assetName mapping). */
export const WORLD_LIFE_ASSET: Record<WorldLifeKind, string> = {
  bird: 'wl_bird', duck: 'wl_duck', frog: 'wl_frog', hedgehog: 'wl_hedgehog',
  rabbit: 'wl_rabbit', squirrel: 'wl_squirrel',
  flower01: 'wl_flower_01', flower02: 'wl_flower_02',
  flower03: 'wl_flower_03', flower04: 'wl_flower_04',
  shrub01: 'wl_shrub_01_r2', shrub02: 'wl_shrub_02_r2',
  shrub03: 'wl_shrub_03_r2', shrub04: 'wl_shrub_04_r2',
  treeMaple: 'wl_tree_maple', treeHoneyPear: 'wl_tree_honey_pear',
  treeMistPine: 'wl_tree_mist_pine', treeCreekWillow: 'wl_tree_creek_willow',
  farmHen: 'wl_farm_hen', farmCow: 'wl_farm_cow', farmSheep: 'wl_farm_sheep',
  farmGoat: 'wl_farm_goat', farmPig: 'wl_farm_pig', farmGoose: 'wl_farm_goose',
  catBbqShop: 'wl_cat_bbq_shop_r3', catBlack: 'wl_cat_black_r2',
  catCalico: 'wl_cat_calico_r2', catRagdoll: 'wl_cat_ragdoll_r2',
  gardenBed: 'tile_tilled_watered_r2',
  cropMistRadish: 'crop_mist_radish_stage_3_r3',
  cropStreamLeaf: 'crop_stream_leaf_stage_3_r3',
  cropAmberBean: 'crop_amber_bean_stage_3_r3',
  cropBellBerry: 'crop_bell_berry_stage_3_r3',
  cropHoneyMelon: 'crop_honey_melon_stage_3_r3',
  fenceHorizontal: 'wl_fence_horizontal_r1', fenceVertical: 'wl_fence_vertical_r1',
  fenceCornerNW: 'wl_fence_corner_nw_r2', fenceCornerNE: 'wl_fence_corner_ne_r2',
  fenceCornerSW: 'wl_fence_corner_sw_r2', fenceCornerSE: 'wl_fence_corner_se_r2',
  fencePost: 'wl_fence_post_r1',
  pastureGrass01: 'wl_pasture_grass_01_r1',
  pastureGrass02: 'wl_pasture_grass_02_r1',
  pastureGrass03: 'wl_pasture_grass_03_r1',
  pastureGrass04: 'wl_pasture_grass_04_r1',
  farmMountainBackdrop: 'wl_backdrop_farm_north_horizon_r6',
  marketCreekValleyBackdrop: 'wl_backdrop_market_north_horizon_r6',
  riverStone01: 'wl_river_stone_01_r1', riverStone02: 'wl_river_stone_02_r1',
  riverStone03: 'wl_river_stone_03_r1', riverStone04: 'wl_river_stone_04_r1',
  flowerMeadow: 'wl_flower_meadow_r2', sunflowerField: 'wl_sunflower_field_r2',
  haystack: 'wl_haystack_r2', farmDiningSet: 'wl_farm_dining_set_r1',
  marketGreenhouse: 'wl_market_greenhouse_r1',
  marketScenicLake: 'wl_market_scenic_lake_f00_r1',
  scenicTilled: 'tile_tilled_r2',
  bankNorth01: 'wl_bank_north_01_r2', bankNorth02: 'wl_bank_north_02_r2',
  bankNorth03: 'wl_bank_north_03_r2', bankNorth04: 'wl_bank_north_04_r2',
  bankSouth01: 'wl_bank_south_01_r2', bankSouth02: 'wl_bank_south_02_r2',
  bankSouth03: 'wl_bank_south_03_r2', bankSouth04: 'wl_bank_south_04_r2',
};

export const WORLD_LIFE_SCENIC_LAKE_FRAMES = ['wl_market_scenic_lake_f00_r1',
  'wl_market_scenic_lake_f01_r1', 'wl_market_scenic_lake_f02_r1',
  'wl_market_scenic_lake_f03_r1'];

export const WORLD_LIFE_HD_CATS: Record<'shop' | 'black' | 'calico' | 'ragdoll', string> = {
  shop: 'cat_bbq_shop_display_2048',
  black: 'cat_black_fullbody_2048',
  calico: 'cat_calico_fullbody_2048',
  ragdoll: 'cat_ragdoll_fullbody_2048',
};

export function worldLifeKindCategory(kind: WorldLifeKind): KindCategory {
  switch (kind) {
    case 'catBbqShop': return 'catBbqShop';
    case 'catBlack': case 'catCalico': case 'catRagdoll': return 'catStaff';
    case 'shrub01': case 'shrub02': case 'shrub03': case 'shrub04': return 'shrub';
    case 'flower01': case 'flower02': case 'flower03': case 'flower04': return 'flower';
    case 'treeMaple': case 'treeHoneyPear': case 'treeMistPine':
    case 'treeCreekWillow': return 'tree';
    case 'fenceHorizontal': case 'fenceVertical': case 'fenceCornerNW':
    case 'fenceCornerNE': case 'fenceCornerSW': case 'fenceCornerSE':
    case 'fencePost': return 'fence';
    case 'flowerMeadow': case 'sunflowerField': return 'fieldPatch';
    case 'haystack': return 'haystack';
    case 'farmDiningSet': return 'diningSet';
    case 'marketGreenhouse': return 'greenhouse';
    case 'marketScenicLake': return 'scenicLake';
    case 'scenicTilled': return 'scenicTilled';
    case 'gardenBed': return 'gardenBed';
    case 'farmMountainBackdrop': case 'marketCreekValleyBackdrop': return 'backdrop';
    case 'bankNorth01': case 'bankNorth02': case 'bankNorth03': case 'bankNorth04':
    case 'bankSouth01': case 'bankSouth02': case 'bankSouth03': case 'bankSouth04':
      return 'shoreInset';
    case 'riverStone01': case 'riverStone02': case 'riverStone03':
    case 'riverStone04': return 'riverStone';
    case 'pastureGrass01': case 'pastureGrass02': case 'pastureGrass03':
    case 'pastureGrass04': return 'pastureGround';
    case 'cropMistRadish': case 'cropStreamLeaf': case 'cropAmberBean':
    case 'cropBellBerry': case 'cropHoneyMelon': return 'cropDisplay';
    default: return 'animal';
  }
}

/** DisplayR2/R3/R4 override resolution, mirroring PixelAssetStore load order. */
export function tileAssetUrl(assetId: string): string {
  const r4 = new Set(['tile_stone_path', 'tile_water_f00', 'tile_water_f01',
    'tile_water_f02', 'tile_water_f03']);
  const r3 = new Set(['tile_grass', 'tile_grass_a', 'tile_grass_b',
    'tile_grass_c']);
  const r2 = new Set(['tile_grass', 'tile_grass_a', 'tile_grass_b',
    'tile_grass_c', 'tile_stone_path', 'prop_stone_path', 'tile_water_f00',
    'tile_water_f01', 'tile_water_f02', 'tile_water_f03', 'tile_water_edge',
    'tile_water_edge_n', 'tile_water_edge_e', 'tile_water_edge_s',
    'tile_water_edge_w', 'tile_water_corner_ne', 'tile_water_corner_se',
    'tile_water_corner_sw', 'tile_water_corner_nw', 'tile_canal_ns',
    'tile_canal_ew', 'prop_canal_segment_ns', 'prop_canal_segment_ew',
    'fx_canal_flow_f00', 'fx_canal_flow_f01', 'fx_canal_flow_f02',
    'fx_canal_flow_f03']);
  if (r4.has(assetId)) return `${DISPLAY_R2}/r4_${assetId}.png`;
  if (r3.has(assetId)) return `${DISPLAY_R2}/r3_${assetId}.png`;
  if (r2.has(assetId)) return `${DISPLAY_R2}/r2_${assetId}.png`;
  return `${ASSETS}/${assetId}.png`;
}

export function worldLifeUrl(assetName: string): string {
  // HD cat tour art and world-life canvases live in world/; tiles live in assets.
  return `${WORLD}/${assetName}.png`;
}

/** Authoritative tiles referenced by the farm renderer. */
export const TILE = {
  waterFrames: ['tile_water_f00', 'tile_water_f01', 'tile_water_f02',
    'tile_water_f03'],
  waterEdge: 'tile_water_edge',
  waterEdgeN: 'tile_water_edge_n',
  waterEdgeE: 'tile_water_edge_e',
  waterEdgeS: 'tile_water_edge_s',
  waterEdgeW: 'tile_water_edge_w',
  waterCornerNE: 'tile_water_corner_ne',
  waterCornerSE: 'tile_water_corner_se',
  waterCornerSW: 'tile_water_corner_sw',
  waterCornerNW: 'tile_water_corner_nw',
  stonePath: 'tile_stone_path',
  canalNS: 'tile_canal_ns',
  canalEW: 'tile_canal_ew',
  canalFlowFrames: ['fx_canal_flow_f00', 'fx_canal_flow_f01',
    'fx_canal_flow_f02', 'fx_canal_flow_f03'],
  grass: ['tile_grass', 'tile_grass_a', 'tile_grass_b', 'tile_grass_c'],
  tilled: 'tile_tilled_r2',
  tilledWatered: 'tile_tilled_watered_r2',
  propCanalEW: 'prop_canal_segment_ew',
  propCanalNS: 'prop_canal_segment_ns',
  propStonePath: 'prop_stone_path',
};

/** Character sheet metadata: 4 columns x 4 rows, rows down/left/right/up. */
export type SheetId =
  | 'char_player_walk' | 'char_water_apprentice_walk'
  | 'char_seed_steward_walk' | 'char_creek_warden_walk'
  | 'char_neighbor_hearsay_walk' | 'char_neighbor_storyteller_walk'
  | 'char_neighbor_evidence_walk' | 'char_neighbor_consensus_walk'
  | 'char_player_action_hoe' | 'char_player_action_watering_can'
  | 'char_player_action_harvest_glove';

export const SHEET_FRAME_W = 32;
export const SHEET_FRAME_H = 48;
export const SHEET_COLS = 4;
export const SHEET_ROWS = 4;
export const FRAME_ROW: Record<'down' | 'left' | 'right' | 'up', number> = {
  down: 0, left: 1, right: 2, up: 3,
};

export const NPC_SHEETS: Record<string, SheetId> = {
  apprentice: 'char_water_apprentice_walk',
  steward: 'char_seed_steward_walk',
  warden: 'char_creek_warden_walk',
  hearsay: 'char_neighbor_hearsay_walk',
  storyteller: 'char_neighbor_storyteller_walk',
  evidence: 'char_neighbor_evidence_walk',
  consensus: 'char_neighbor_consensus_walk',
};

export const ACTION_SHEET: Record<'hoe' | 'water' | 'harvest', SheetId> = {
  hoe: 'char_player_action_hoe',
  water: 'char_player_action_watering_can',
  harvest: 'char_player_action_harvest_glove',
};

export const FX = {
  targetValid: ['fx_target_valid_f00', 'fx_target_valid_f01'],
  targetInvalid: ['fx_target_invalid_f00', 'fx_target_invalid_f01'],
  waterSplash: ['fx_water_splash_f00', 'fx_water_splash_f01',
    'fx_water_splash_f02', 'fx_water_splash_f03'],
  harvest: ['fx_harvest_f00', 'fx_harvest_f01', 'fx_harvest_f02',
    'fx_harvest_f03'],
};
