'use client';
/* oxlint-disable next/no-img-element, react/react-compiler, jsx-a11y/media-has-caption, jsx-a11y/label-has-associated-control, typescript/no-meaningless-void-operator */

import {
  Archive,
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  ArrowUp,
  BookOpenText,
  Box,
  Coins,
  CookingPot,
  Download,
  Droplets,
  Hammer,
  Hand,
  Heart,
  HelpCircle,
  Home,
  Moon,
  Music,
  PackageOpen,
  Pause,
  PawPrint,
  RotateCcw,
  Save,
  Shovel,
  Sparkles,
  Sprout,
  Upload,
  Volume2,
  Wheat,
  X,
} from 'lucide-react';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import { ScrollArea } from '@/components/ui/scroll-area';
import { Slider } from '@/components/ui/slider';
import { Switch } from '@/components/ui/switch';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import {
  speakerNeedsTravel,
  speakerTargetOnMap,
  speakerTargets,
} from '@/content/r22-story-anchors';
import { CanvasWorld } from '@/runtime/canvas-world';
import type { ToolEvent } from '@/runtime/canvas-world';
import { JourneySceneLayer } from '@/runtime/journey-layer';
import { GalleryLayer } from '@/runtime/gallery-layer';
import type { PreRevealRecall } from '@/runtime/gallery-layer';
import { BrowserSaveStore } from '@/persistence/save-store';
import type { SaveMeta } from '@/persistence/save-store';
import { indexedDbBackend } from '@/persistence/idb';
import { gameValidator } from '@/persistence/validator';
import {
  CHOICE_LABELS,
  CRAFTS,
  CROPS,
  GATHER_ANCHORS,
  ITEM_NAMES,
  MAPS,
  NPC_NAMES,
  PROCESSING,
  advanceStory,
  applyTool,
  buySeeds,
  careAnimal,
  catShopSellAnimal,
  catShopSellCrop,
  completeJourneyCheckpoint,
  countInventory,
  craft,
  createNewGame,
  gather,
  movePlayer,
  objective,
  parseGame,
  placeCrafted,
  processItem,
  selectSeed,
  selectTool,
  shipAll,
  sleep,
  talkToNpc,
  travel,
  morningReport,
  type CropId,
  type Direction,
  type GameState,
  type ItemId,
  type Tool,
} from '@/lib/full-game';

const STORAGE_KEY = 'creek-sprout-full-web-v3';
const SETTINGS_KEY = 'creek-sprout-web-settings-v1';
const ACTIVE_KEY = 'creek-sprout-active-campaign-v1';
const A = '/full-assets/assets';
const W = '/full-assets/world';
type Panel =
  | 'journal'
  | 'inventory'
  | 'craft'
  | 'herd'
  | 'settings'
  | 'help'
  | 'shop'
  | null;
type StoryLine = {
  id: string;
  speaker: string;
  annotation: string | null;
  text: string;
  condition: string;
  origin: string;
};
type StoryStage = {
  id: string;
  label: string;
  choices: string[];
  lines: StoryLine[];
};
type StoryArc = { id: string; title: string; stages: StoryStage[] };
type StoryPayload = {
  source_sha256: string;
  manuscript_line_count: number;
  stories: StoryArc[];
};
type WebSettings = {
  music: boolean;
  musicVolume: number;
  reducedMotion: boolean;
};
const DEFAULT_SETTINGS: WebSettings = {
  music: true,
  musicVolume: 0.35,
  reducedMotion: false,
};
const TOOL_META: Array<{
  id: Tool;
  label: string;
  key: string;
  icon: typeof Shovel;
  asset?: string;
}> = [
  {
    id: 'hoe',
    label: '锄头',
    key: '1',
    icon: Shovel,
    asset: `${A}/tool_hoe.png`,
  },
  { id: 'seed', label: '播种', key: '2', icon: Sprout },
  {
    id: 'water',
    label: '浇水',
    key: '3',
    icon: Droplets,
    asset: `${A}/tool_watering_can.png`,
  },
  {
    id: 'harvest',
    label: '收获',
    key: '4',
    icon: Wheat,
    asset: `${A}/tool_harvest_glove.png`,
  },
  { id: 'hand', label: '交互', key: 'E', icon: Hand },
];
const STAGE_LABELS: Record<string, string> = {
  benefit: '获益',
  warningOne: '预警一',
  warningTwo: '预警二',
  eruption: '爆发',
  departureConfirmation: '出发确认',
  climax: '雾岭营救',
  aftermath: '善后',
  revealCallback: '揭露回看',
  discovery: '发现账簿',
  interrupt: '被打断',
  playerIntent: '你的回应',
  turningPoint: '揭露转折',
  confrontationOpen: '当面对质',
  allEvil: '真相',
  lastFarmAction: '最后的选择',
  graduation: '毕业',
};
const PORTRAITS: Record<string, string> = {
  waterApprentice:
    '/full-assets/portraits/portrait_water_apprentice_clean_v01.png',
  seedSteward: '/full-assets/portraits/portrait_seed_steward_clean_v01.png',
  creekWarden: '/full-assets/portraits/portrait_creek_warden_clean_v01.png',
  neighborHearsay:
    '/full-assets/portraits/portrait_neighbor_hearsay_clean_v01.png',
  neighborStoryteller:
    '/full-assets/portraits/portrait_neighbor_storyteller_clean_v01.png',
  neighborEvidence:
    '/full-assets/portraits/portrait_neighbor_evidence_clean_v01.png',
  neighborConsensus:
    '/full-assets/portraits/portrait_neighbor_consensus_clean_v01.png',
  catShopBlack: `${W}/wl_cat_black_r2.png`,
  catShopCalico: `${W}/wl_cat_calico_r2.png`,
  catShopRagdoll: `${W}/wl_cat_ragdoll_r2.png`,
};
const SWIFT_CHOICES: Record<string, string> = {
  fieldFirst: 'field_first',
  reedFirst: 'reed_first',
  inspectFirst: 'inspect_first',
  cutTest: 'cut_test',
  traceRumor: 'trace_rumor',
  protectInventory: 'protect_inventory',
  parallelCrop: 'parallel_crop',
  publishMissingPage: 'publish_missing_page',
  publicOrder: 'public',
  noSide: 'no_side',
  tradeUnion: 'trade_union',
  oldWaterway: 'old_waterway',
  takeLedger: 'take_ledger',
  keepReading: 'keep_reading',
  closeLedger: 'close_ledger',
  returnTitles: 'return_titles',
  whyMe: 'why_me',
  anyTruth: 'any_truth',
  breakTitles: 'break_titles',
};

function lineMatches(line: StoryLine, choice: string | null) {
  if (line.condition === '.always') return true;
  if (line.condition.includes('selectedAction'))
    return choice ? line.condition.includes(choice) : false;
  if (!choice) return false;
  const match = line.condition.match(/\.([A-Za-z]+)[,)]/);
  const expected = match ? (SWIFT_CHOICES[match[1]] ?? match[1]) : '';
  if (line.condition.includes('romanceTender(true)'))
    return choice === 'love' || choice === 'tender';
  if (line.condition.includes('romanceTender(false)'))
    return choice === 'friend';
  return expected === choice;
}

export default function HomePage() {
  const [game, setGame] = useState<GameState>(() => createNewGame());
  const [hydrated, setHydrated] = useState(false);
  const [panel, setPanel] = useState<Panel>(null);
  const [storyData, setStoryData] = useState<StoryPayload | null>(null);
  const [storyOpen, setStoryOpen] = useState(false);
  // Speaker whose lines the open story card is showing (null = wrap-up card).
  const [activeStorySpeaker, setActiveStorySpeaker] = useState<string | null>(null);
  const [lineIndex, setLineIndex] = useState(0);
  const [storyChoice, setStoryChoice] = useState<string | null>(null);
  const [settings, setSettings] = useState<WebSettings>(DEFAULT_SETTINGS);
  const [saveFlash, setSaveFlash] = useState('本机自动存档');
  const [slotMeta, setSlotMeta] = useState<Record<string, SaveMeta>>({});
  const [audioReady, setAudioReady] = useState(false);
  const [reportOpen, setReportOpen] = useState(false);
  const [journeyOpen, setJourneyOpen] = useState(false);
  const [galleryOpen, setGalleryOpen] = useState(false);
  const prevDayRef = useRef(0);
  const fileInput = useRef<HTMLInputElement>(null);
  const audioRef = useRef<HTMLAudioElement>(null);
  const storeRef = useRef<BrowserSaveStore | null>(null);
  if (!storeRef.current) storeRef.current = new BrowserSaveStore(indexedDbBackend(), gameValidator);
  const saveStore = storeRef.current;
  const autoSaveTimer = useRef<number | null>(null);
  const prevStoryRef = useRef<GameState['story'] | null>(null);

  useEffect(() => {
    const restore = async () => {
      // Parity-review mode: `?fresh=1` renders the untouched new-game state
      // (player 7,6 / day 1 / clear weather) and never reads or writes any
      // save slot, so the page can be compared against the native reference
      // frame without disturbing the player's own campaign.
      const fresh = new URLSearchParams(window.location.search).has('fresh');
      let restored: GameState | null = null;
      if (!fresh) {
        const activeCampaign = window.localStorage.getItem(ACTIVE_KEY);
        try {
          if (activeCampaign) {
            const loaded = await saveStore.loadSlot(activeCampaign, 'auto', 0);
            if (loaded) {
              const parsed = parseGame(loaded.payload);
              if (parsed) restored = parsed;
            }
          }
        } catch {
          /* fall through to legacy mirror */
        }
        if (!restored) restored = parseGame(window.localStorage.getItem(STORAGE_KEY));
      }
      if (restored) {
        setGame({ ...restored, message: '已恢复这台浏览器上的正式存档。' });
        prevStoryRef.current = restored.story;
      } else if (fresh) {
        setGame((current) => ({
          ...current,
          message: '校对模式：未读写存档，画面与本地初始状态一致。',
        }));
      }
      try {
        setSettings({
          ...DEFAULT_SETTINGS,
          ...JSON.parse(window.localStorage.getItem(SETTINGS_KEY) ?? '{}'),
        });
      } catch {
        /* safe defaults */
      }
      fetch('/full-assets/story.json')
        .then(async (response) => (await response.json()) as StoryPayload)
        .then(setStoryData)
        .catch(() => setStoryData(null));
      setHydrated(true);
    };
    void restore();
  }, [saveStore]);

  // Automatic save: IndexedDB (primary) + tiny localStorage mirror (recovery
  // aid only). Progress never depends on localStorage alone.
  useEffect(() => {
    if (!hydrated) return;
    // Parity-review mode never persists, the campaign stays untouched on disk.
    if (new URLSearchParams(window.location.search).has('fresh')) return;
    const payload = JSON.stringify(game);
    window.localStorage.setItem(STORAGE_KEY, payload);
    window.localStorage.setItem(ACTIVE_KEY, game.campaignId);
    if (autoSaveTimer.current !== null) window.clearTimeout(autoSaveTimer.current);
    autoSaveTimer.current = window.setTimeout(() => {
      saveStore
        .save(payload, 'auto', 0)
        .then(() => {
          setSaveFlash('已自动保存');
          const timeout = window.setTimeout(() => setSaveFlash('本机自动存档'), 1100);
          autoSaveTimer.current = null;
          return () => window.clearTimeout(timeout);
        })
        .catch((error: unknown) => {
          setSaveFlash('自动存档失败，保留本机镜像');
          void error;
        });
    }, 500);
    return () => {
      if (autoSaveTimer.current !== null) window.clearTimeout(autoSaveTimer.current);
    };
  }, [game, hydrated, saveStore]);

  // Morning crop report opens when a sleep settles into a new day.
  useEffect(() => {
    if (!hydrated) return;
    if (
      prevDayRef.current < game.day &&
      (game.message.startsWith('新的一天开始了') ||
        game.message.startsWith('细雨替你润湿'))
    ) {
      setReportOpen(true);
    }
    prevDayRef.current = game.day;
  }, [game.day, game.message, hydrated]);

  // Story protection points: Q08 mission_current & Q09 pre_reveal writes land
  // before/at their exact transitions (mirrors native coordinator kinds).
  useEffect(() => {
    if (!hydrated) return;
    const prev = prevStoryRef.current;
    prevStoryRef.current = game.story;
    if (!prev) return;
    const enteredQ08Journey =
      game.story.arcIndex === 7 && prev.arcIndex === 7 &&
      game.story.journeyCheckpoint > prev.journeyCheckpoint;
    const q09Discovery =
      game.story.arcIndex === 8 && prev.arcIndex !== 8;
    const preReveal = !prev.preRevealSave && game.story.preRevealSave;
    if (enteredQ08Journey) {
      void saveStore
        .save(JSON.stringify(game), 'mission_current', 0)
        .catch(() => undefined);
    }
    if (q09Discovery || preReveal) {
      void saveStore
        .save(JSON.stringify(game), 'pre_reveal', 0)
        .catch(() => undefined);
    }
  }, [game, hydrated, saveStore]);

  useEffect(() => {
    if (hydrated)
      window.localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
  }, [settings, hydrated]);
  useEffect(() => {
    const audio = audioRef.current;
    if (!audio) return;
    audio.volume = settings.musicVolume;
    if (!settings.music || !audioReady) {
      audio.pause();
      return;
    }
    audio.src =
      game.map === 'farm'
        ? '/full-assets/music/music_farm_today_is_a_good_day_v01.mp3'
        : '/full-assets/music/music_creek_bouncy_steps_v01.mp3';
    audio.play().catch(() => undefined);
  }, [audioReady, game.map, settings.music, settings.musicVolume]);

  const update = useCallback((action: (state: GameState) => GameState) => {
    setAudioReady(true);
    setGame((current) => action(current));
  }, []);
  const move = useCallback(
    (direction: Direction) => {
      // Native contract: stepping onto the map exit travels between maps.
      const delta: Record<Direction, [number, number]> = {
        up: [0, 1],
        down: [0, -1],
        left: [-1, 0],
        right: [1, 0],
      };
      const [dx, dy] = delta[direction];
      const exit = MAPS[game.map].exit;
      if (
        game.player.x + dx === exit.x &&
        game.player.y + dy === exit.y
      ) {
        update(travel);
        return;
      }
      update((state) => movePlayer(state, direction));
    },
    [game.map, game.player.x, game.player.y, update],
  );
  const arc = storyData?.stories[game.story.arcIndex] ?? null;
  const stage = arc?.stages[game.story.stageIndex] ?? null;
  const choiceKey = arc && stage ? `${arc.id}:${game.story.stageIndex}` : '';
  const savedChoice = choiceKey ? game.story.choices[choiceKey] : null;
  const effectiveChoice = storyChoice ?? savedChoice ?? null;
  const report = hydrated ? morningReport(game) : null;
  // A stage is told by its speakers in order: the player has to find each one
  // instead of reading one mixed ensemble scene.
  const stageSpeakers = useMemo(() => {
    const list: string[] = [];
    for (const line of stage?.lines ?? []) {
      if (line.speaker && !list.includes(line.speaker)) list.push(line.speaker);
    }
    return list;
  }, [stage]);
  const speakerChoiceKey = (speaker: string) =>
    `${arc?.id ?? ''}:${game.story.stageIndex}:speaker:${speaker}`;
  const pendingSpeaker =
    stageSpeakers.find(
      (speaker) => !game.story.choices[speakerChoiceKey(speaker)],
    ) ?? null;
  const pendingTarget = pendingSpeaker
    ? speakerTargetOnMap(pendingSpeaker, game.map as 'farm' | 'market')
    : null;
  const pendingIsNarration = !!pendingSpeaker && !speakerNeedsTravel(pendingSpeaker);
  // Wrap-up card (every speaker already talked to) shows no lines at all: the
  // stage is told person by person, never as one mixed ensemble scene.
  const visibleLines = useMemo(
    () =>
      activeStorySpeaker === null && pendingSpeaker === null
        ? []
        : (stage?.lines ?? []).filter(
            (line) =>
              (!activeStorySpeaker || line.speaker === activeStorySpeaker) &&
              lineMatches(line, effectiveChoice),
          ),
    [activeStorySpeaker, effectiveChoice, pendingSpeaker, stage],
  );
  const activeLine =
    visibleLines[Math.min(lineIndex, Math.max(visibleLines.length - 1, 0))];
  const storyAtEnd = lineIndex >= Math.max(visibleLines.length - 1, 0);
  const openStoryFor = (speaker: string | null) => {
    setActiveStorySpeaker(speaker);
    setLineIndex(0);
    setStoryChoice(null);
    setStoryOpen(true);
    setAudioReady(true);
  };
  const finishStage = () => {
    if (!arc || !stage) return;
    if (
      arc.id === 'q08' &&
      stage.id === 'climax' &&
      game.story.journeyCheckpoint < 3
    ) {
      setGame((state) => ({
        ...state,
        message: '先在雾岭旅程页完成三个检查点。',
      }));
      setStoryOpen(false);
      setPanel('journal');
      return;
    }
    update((state) =>
      advanceStory(
        state,
        arc.id,
        arc.stages.length,
        effectiveChoice ?? undefined,
      ),
    );
    setStoryOpen(false);
    setActiveStorySpeaker(null);
    setLineIndex(0);
    setStoryChoice(null);
  };
  // One speaker finished: remember it on the story record and point the player
  // at whoever the stage still needs.
  const finishSpeaker = () => {
    if (!arc || !activeStorySpeaker) return;
    const speaker = activeStorySpeaker;
    const remaining = stageSpeakers.filter(
      (s) => s !== speaker && !game.story.choices[speakerChoiceKey(s)],
    );
    const next = remaining[0] ?? null;
    const npcName = NPC_NAMES[speaker] ?? speaker;
    let tip = '这一幕已经说完，按 F 收尾。';
    if (next) {
      const target = speakerTargets(next)[0];
      tip = target
        ? `已与${npcName}交谈。下一步：去${target.map === 'farm' ? '农场' : '集市'}找${target.label}。`
        : `已与${npcName}交谈。按 F 继续。`;
    }
    update((state) => ({
      ...state,
      story: {
        ...state.story,
        choices: { ...state.story.choices, [speakerChoiceKey(speaker)]: '1' },
      },
      message: tip,
    }));
    setStoryOpen(false);
    setActiveStorySpeaker(null);
    setLineIndex(0);
  };
  const storyHintText = pendingSpeaker
    ? pendingTarget
      ? `当前该找：${pendingTarget.label}（${pendingTarget.map === 'farm' ? '农场' : '集市'} ${pendingTarget.x},${pendingTarget.y}）——走到面前按 E 交谈，或按 F 查看指引。`
      : '当前待读旁白：按 F 直接阅读。'
    : '这一幕的在场人物都已交谈完毕：按 F 收尾。';
  // Native performAction order: a pending story beat is handled before tools.
  // Here that means: standing next to the speaker the stage is waiting for
  // opens their dialogue; anywhere else the key keeps farming.
  const act = useCallback(() => {
    if (pendingSpeaker && pendingTarget) {
      const adjacent =
        Math.abs(pendingTarget.x - game.player.x) +
          Math.abs(pendingTarget.y - game.player.y) <=
        1;
      if (adjacent) {
        // Carrying the repaired sluice back to the apprentice settles the quest
        // before the next story beat, exactly like the native report turn-in.
        if (
          pendingTarget.npcId === 'apprentice' &&
          game.quest.canalPlaced &&
          !game.quest.canalReported
        ) {
          update((state) => talkToNpc(state, 'apprentice'));
          return;
        }
        openStoryFor(pendingSpeaker);
        return;
      }
    }
    // Native gatherIfPossible(): an adjacent, still-available gather node takes
    // the interact key before any tool is used.
    const gatherNode = GATHER_ANCHORS.find((node) => {
      if (node.map !== game.map) return false;
      if (
        Math.abs(node.x - game.player.x) + Math.abs(node.y - game.player.y) > 1
      )
        return false;
      const gatheredKey = `${game.map}:${node.id}`;
      if (game.gathered.includes(gatheredKey)) return false;
      if (game.map === 'farm' && game.gathered.includes(node.id)) return false;
      if (node.unlockAfterWatershed && game.watershed < 20) return false;
      return true;
    });
    if (gatherNode) {
      update((state) => gather(state, gatherNode.id));
      return;
    }
    update(applyTool);
  }, [
    update,
    pendingSpeaker,
    pendingTarget,
    game.player.x,
    game.player.y,
    game.map,
    game.gathered,
    game.watershed,
    game.quest,
  ]);
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      if (event.repeat) return;
      const key = event.key.toLowerCase();
      // Esc: journey layer first, then gallery, story, report, settings.
      if (key === 'escape') {
        if (journeyOpen) {
          setJourneyOpen(false);
          return;
        }
        if (galleryOpen) {
          setGalleryOpen(false);
          return;
        }
        if (storyOpen) {
          setStoryOpen(false);
          return;
        }
        if (reportOpen) {
          setReportOpen(false);
          return;
        }
        if (!panel) setPanel('settings');
        return;
      }
      // Native performAction(): while the dialogue card is open the interact
      // key reads the next line, then closes the speaker (or finishes the
      // stage once every speaker has been talked to).
      if (storyOpen) {
        if (key === 'e' || key === ' ' || key === 'enter') {
          event.preventDefault();
          if (!storyAtEnd) {
            setLineIndex((value) => value + 1);
          } else if (activeStorySpeaker) {
            finishSpeaker();
          } else if (stage && stage.choices.length > 0 && !effectiveChoice) {
            // A stage intent still needs to be chosen with the on-screen buttons.
          } else {
            finishStage();
          }
        }
        return;
      }
      if (panel || journeyOpen || galleryOpen) return;
      // F: story guide key. Narrative lines read directly; a resident speaker
      // either starts the dialogue when the hero already stands next to them,
      // or tells the player exactly who to find and where.
      if (key === 'f') {
        event.preventDefault();
        if (!storyData || !arc || !stage) {
          setGame((state) => ({
            ...state,
            message: storyData ? '主线已经全部完成。' : '剧情数据正在载入。',
          }));
          return;
        }
        if (!pendingSpeaker) {
          openStoryFor(null);
          return;
        }
        const adjacent =
          !!pendingTarget &&
          Math.abs(pendingTarget.x - game.player.x) +
            Math.abs(pendingTarget.y - game.player.y) ===
            1;
        if (pendingIsNarration || adjacent) {
          openStoryFor(pendingSpeaker);
          return;
        }
        const target = pendingTarget ?? speakerTargets(pendingSpeaker)[0];
        setGame((state) => ({
          ...state,
          message: target
            ? `下一步：去${target.map === 'farm' ? '农场' : '集市'}找${target.label}（${target.x},${target.y}），走到面前按 E 交谈。`
            : '按 F 继续。',
        }));
        return;
      }
      const directions: Record<string, Direction> = {
        w: 'up',
        arrowup: 'up',
        s: 'down',
        arrowdown: 'down',
        a: 'left',
        arrowleft: 'left',
        d: 'right',
        arrowright: 'right',
      };
      if (directions[key]) {
        event.preventDefault();
        move(directions[key]);
        return;
      }
      if (['1', '2', '3', '4'].includes(key)) {
        update((state) => selectTool(state, TOOL_META[Number(key) - 1].id));
        return;
      }
      if (key === 'e' || key === ' ') {
        event.preventDefault();
        act();
      }
      if (key === 'b') {
        setPanel('inventory');
        return;
      }
      if (key === 'c') {
        setPanel('craft');
        return;
      }
      if (key === 'm') {
        setPanel('herd');
        return;
      }
      if (key === 'j') {
        setPanel('journal');
        return;
      }
      // R: reopen the morning crop report from the farm (native reopen key).
      if (key === 'r' && game.map === 'farm') {
        setReportOpen(true);
        return;
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [
    act,
    move,
    panel,
    storyOpen,
    reportOpen,
    journeyOpen,
    galleryOpen,
    game.map,
    game.story,
    game.player.x,
    game.player.y,
    storyData,
    update,
    lineIndex,
    activeStorySpeaker,
    storyAtEnd,
  ]);

  const handlePresence = (presenceId: string) => {
    if (presenceId.startsWith('gather:')) {
      update((state) => gather(state, presenceId.slice('gather:'.length)));
      return;
    }
    // Talking to the person the current stage is waiting for raises the story
    // beat; other residents keep their regular small talk.
    if (pendingSpeaker && pendingTarget && pendingTarget.npcId === presenceId) {
      if (
        presenceId === 'apprentice' &&
        game.quest.canalPlaced &&
        !game.quest.canalReported
      ) {
        update((state) => talkToNpc(state, presenceId));
        return;
      }
      openStoryFor(pendingSpeaker);
      return;
    }
    if (presenceId === 'cat-shop') {
      if (pendingSpeaker && pendingTarget?.npcId === 'cat-shop') {
        openStoryFor(pendingSpeaker);
        return;
      }
      if (game.map === 'market') setPanel('shop');
      return;
    }
    update((state) => talkToNpc(state, presenceId));
  };
  // Action animation events: mirror native action sheets from domain results.
  const prevGameRef = useRef<GameState>(game);
  const [toolEvent, setToolEvent] = useState<ToolEvent | null>(null);
  useEffect(() => {
    const prev = prevGameRef.current;
    prevGameRef.current = game;
    if (prev.updatedAt === game.updatedAt) return;
    const message = game.message;
    let kind: ToolEvent['kind'] | null = null;
    if (message.startsWith('泥土松开了')) kind = 'hoe';
    else if (message.startsWith('水慢慢渗进')) kind = 'water';
    else if (message.startsWith('收获了')) kind = 'harvest';
    if (kind) setToolEvent({ kind, at: Date.now() });
  }, [game]);
  const resetGame = () => {
    if (window.confirm('确定重新开始当前浏览器农场？建议先导出存档。')) {
      setGame(createNewGame());
      setPanel(null);
    }
  };

  const exportSave = () => {
    const blob = new Blob([JSON.stringify(game, null, 2)], {
      type: 'application/json',
    });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `溪谷新芽-${game.campaignId}-day${game.day}.json`;
    link.click();
    URL.revokeObjectURL(url);
  };

  const refreshSlots = async () => {
    try {
      const generations = await saveStore.listSlots(game.campaignId);
      const summary: Record<string, SaveMeta> = {};
      for (const generation of generations) {
        const key = `${generation.meta.kind}:${generation.meta.slotIndex}`;
        if (!summary[key]) summary[key] = generation.meta;
      }
      setSlotMeta(summary);
    } catch {
      /* IndexedDB unavailable */
    }
  };
  useEffect(() => {
    if (panel === 'settings' && hydrated) {
      void (async () => {
        try {
          const generations = await saveStore.listSlots(game.campaignId);
          const summary: Record<string, SaveMeta> = {};
          for (const generation of generations) {
            const key = `${generation.meta.kind}:${generation.meta.slotIndex}`;
            if (!summary[key]) summary[key] = generation.meta;
          }
          setSlotMeta(summary);
        } catch {
          /* IndexedDB unavailable */
        }
      })();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- refreshSlots is
    // intentionally re-run only when the panel or campaign state changes.
  }, [panel, hydrated, saveStore, game.campaignId, game.day]);
  const saveToManualSlot = (index: number) => {
    void (async () => {
      const existing = await saveStore.loadSlot(game.campaignId, 'manual', index);
      if (
        existing &&
        !window.confirm(
          `手动槽 ${index + 1} 已存有第 ${existing.generation.meta.day} 天存档，确定覆盖？`,
        )
      )
        return;
      await saveStore.save(JSON.stringify(game), 'manual', index);
      setSaveFlash(`已保存到手动槽 ${index + 1}`);
      void refreshSlots();
    })().catch(() => setSaveFlash('手动保存失败'));
  };
  const loadFromManualSlot = (index: number) => {
    void (async () => {
      const loaded = await saveStore.loadSlot(game.campaignId, 'manual', index);
      if (!loaded) {
        setSaveFlash(`手动槽 ${index + 1} 没有存档`);
        return;
      }
      const parsed = parseGame(loaded.payload);
      if (!parsed) {
        setSaveFlash('存档损坏或版本过旧，已保留当前进度');
        return;
      }
      setGame({ ...parsed, message: `已读取手动槽 ${index + 1}（第 ${parsed.day} 天）` });
      setPanel(null);
    })().catch(() => setSaveFlash('读取手动槽失败'));
  };
  // Q08 journey: abandon rolls back to the earliest mission snapshot; return
  // settles exactly once and is marked on the story record. Both report
  // success so the journey layer can close itself.
  const abandonJourney = (): boolean => {
    let accepted = false;
    void (async () => {
      const generations = await saveStore.listSlots(game.campaignId);
      const missions = generations
        .filter((g) => g.meta.kind === 'mission_current')
        .sort((a, b) => a.meta.createdAt.localeCompare(b.meta.createdAt));
      const snapshot = missions[0];
      if (!snapshot) {
        setSaveFlash('没有找到可回退的旅程保护档');
        return;
      }
      const parsed = parseGame(snapshot.payload);
      if (!parsed || !window.confirm('放弃当前雾岭旅程并回到出发前保护档？')) return;
      accepted = true;
      setGame({ ...parsed, message: '已放弃远行，回到出发前的溪谷（保护档回滚）。' });
      setPanel(null);
    })().catch(() => setSaveFlash('放弃旅程失败'));
    return accepted;
  };
  const settleHomecoming = (): boolean => {
    const returnedKey = 'q08:returned';
    if (game.story.journeyCheckpoint < 3) {
      setSaveFlash('先完成雾岭三处检查点');
      return false;
    }
    if (game.story.choices[returnedKey]) {
      setSaveFlash('返乡结算已完成一次，不会重复到账');
      return false;
    }
    if (!window.confirm('猫猫公主已在灰栅边界，确认完成返乡结算（仅一次）？')) return false;
    setGame((state) => ({
      ...state,
      story: {
        ...state.story,
        choices: { ...state.story.choices, [returnedKey]: '1' },
      },
      message: '返乡结算完成，猫猫公主回家了。旅程不会重复结算。',
    }));
    setPanel(null);
    return true;
  };
  const overwriteImport = async (file: File) => {
    const imported = parseGame(await file.text());
    if (!imported) {
      setGame((state) => ({
        ...state,
        message: '导入失败：存档无效，当前进度没有改变。',
      }));
      return;
    }
    if (!window.confirm('导入将替换当前浏览器进度，确定继续？')) return;
    setGame({ ...imported, message: '存档导入成功。' });
    setPanel(null);
  };

  return (
    <main
      className={`formal-game ${settings.reducedMotion ? 'reduce-motion' : ''}`}
      onPointerDown={() => setAudioReady(true)}
    >
      <audio ref={audioRef} loop preload="metadata" />
      <div className="game-shell">
        <CanvasWorld
          game={game}
          settings={{ reducedMotion: settings.reducedMotion }}
          toolEvent={toolEvent}
          onActCell={(x, y, direction) => {
            void x;
            void y;
            update((state) =>
              applyTool({ ...state, player: { ...state.player, direction } }),
            );
          }}
          onPresence={handlePresence}
          onTravel={() => update(travel)}
        />
        <div className="hud hud-left">
          <img className="clock-icon" src={`${A}/ui_time.png`} alt="" />
          <div className="hud-copy">
            <div className="calendar-row">
              <strong>{MAPS[game.map].name}</strong>
              <span>
                第{game.day}天 {String(game.hour).padStart(2, '0')}:
                {String(game.minute).padStart(2, '0')}
              </span>
              <span className="weather">
                <img src={`${A}/ui_weather.png`} alt="" />
                {game.weather}
              </span>
            </div>
            <div className="objective">
              <b>目标</b>
              <span>{objective(game)}</span>
            </div>
          </div>
        </div>
        <div className="hud hud-right">
          <div className="vital">
            <img src={`${A}/ui_stamina.png`} alt="体力" />
            <strong>{game.stamina}/100</strong>
          </div>
          <div className="vital">
            <img src={`${A}/ui_currency.png`} alt="溪票" />
            <strong>{game.coins}</strong>
          </div>
        </div>
        <div className="quick-rail">
          <button onClick={() => setPanel('journal')} aria-label="剧情与任务">
            <BookOpenText />
          </button>
          <button onClick={() => setPanel('inventory')} aria-label="背包">
            <PackageOpen />
            <i>{countInventory(game)}</i>
          </button>
          <button onClick={() => setPanel('craft')} aria-label="制作与加工">
            <Hammer />
          </button>
          <button onClick={() => setPanel('herd')} aria-label="畜牧">
            <PawPrint />
          </button>
          <button onClick={() => setPanel('settings')} aria-label="暂停与设置">
            <Pause />
          </button>
        </div>
        <div className="toast">
          <span>{game.message}</span>
          <small>
            <Save /> {saveFlash}
          </small>
        </div>
        <div className="toolbelt">
          {TOOL_META.filter((slot) => slot.id !== 'hand').map(
            ({ id, label, key, icon: Icon, asset }) => {
              const selected = game.selectedTool === id;
              const iconUrl =
                id === 'seed'
                  ? `${A}/crop_${game.selectedSeed}.png`
                  : asset;
              return (
                <button
                  key={id}
                  className={selected ? 'slot selected' : 'slot'}
                  onClick={() => update((state) => selectTool(state, id))}
                  title={`${label} · ${key}`}
                >
                  <img
                    className="slot-base"
                    src={`${A}/${selected ? 'ui_slot_selected' : 'ui_slot'}.png`}
                    alt=""
                  />
                  {iconUrl ? (
                    <img
                      className={id === 'seed' ? 'slot-icon crop' : 'slot-icon'}
                      src={iconUrl}
                      alt=""
                    />
                  ) : (
                    <Icon />
                  )}
                  <kbd>{key}</kbd>
                </button>
              );
            },
          )}
        </div>
        <div className="dpad">
          <button onClick={() => move('up')} aria-label="向上">
            <ArrowUp />
          </button>
          <button onClick={() => move('left')} aria-label="向左">
            <ArrowLeft />
          </button>
          <button onClick={act} aria-label="使用工具">
            <Hand />
          </button>
          <button onClick={() => move('right')} aria-label="向右">
            <ArrowRight />
          </button>
          <button onClick={() => move('down')} aria-label="向下">
            <ArrowDown />
          </button>
        </div>
      </div>
      <Dialog
        open={panel !== null}
        onOpenChange={(open) => {
          if (!open) setPanel(null);
        }}
      >
        <DialogContent
          className="game-dialog max-h-[88vh] max-w-[900px] overflow-hidden p-0"
          showCloseButton={false}
        >
          <div className="dialog-top">
            <div>
              <span>溪谷手册</span>
              <strong>{panelTitle(panel)}</strong>
            </div>
            <button onClick={() => setPanel(null)}>
              <X />
            </button>
          </div>
          <ScrollArea className="max-h-[calc(88vh-68px)]">
            <div className="dialog-body">
              {panel === 'journal' && (
                <Journal
                  game={game}
                  arc={arc}
                  stage={stage}
                  storyData={storyData}
                  openStory={() => openStoryFor(pendingSpeaker)}
                  storyHint={storyHintText}
                  onEnterJourney={() => {
                    setPanel(null);
                    setJourneyOpen(true);
                  }}
                  onOpenGallery={() => {
                    setPanel(null);
                    setGalleryOpen(true);
                  }}
                  onAbandonJourney={abandonJourney}
                  onSettleHomecoming={settleHomecoming}
                />
              )}
              {panel === 'inventory' && (
                <Inventory game={game} update={update} />
              )}
              {panel === 'craft' && <Crafting game={game} update={update} />}
              {panel === 'herd' && <Herd game={game} update={update} />}
              {panel === 'shop' && <CatShop game={game} update={update} />}
              {panel === 'settings' && (
                <PauseSettings
                  game={game}
                  settings={settings}
                  setSettings={setSettings}
                  exportSave={exportSave}
                  importSave={overwriteImport}
                  fileInput={fileInput}
                  resetGame={resetGame}
                  setPanel={setPanel}
                  update={update}
                  slotMeta={slotMeta}
                  onSaveSlot={saveToManualSlot}
                  onLoadSlot={loadFromManualSlot}
                />
              )}
              {panel === 'help' && <Help />}
            </div>
          </ScrollArea>
        </DialogContent>
      </Dialog>
      {storyOpen && arc && stage ? (
        <div className="story-layer">
          <button
            type="button"
            className="story-dimmer"
            aria-label="稍后继续"
            onClick={() => setStoryOpen(false)}
          />
          <section className="story-card" aria-label="剧情对话">
            <div className="story-header">
              <span className="stage-chip">
                Q{String(game.story.arcIndex + 1).padStart(2, '0')} ·{' '}
                {STAGE_LABELS[stage.label] ?? stage.id}
              </span>
              <span className="page-count">
                {visibleLines.length
                  ? `${Math.min(lineIndex + 1, visibleLines.length)} / ${visibleLines.length}`
                  : stage.choices.length > 0
                    ? '选择意图'
                    : '收尾'}
              </span>
            </div>
            {activeLine ? (
              <div className="story-line">
                <div className="line-portrait">
                  {PORTRAITS[activeLine.speaker] ? (
                    <img
                      src={PORTRAITS[activeLine.speaker]}
                      alt={NPC_NAMES[activeLine.speaker] ?? activeLine.speaker}
                    />
                  ) : (
                    <span>
                      {(NPC_NAMES[activeLine.speaker] ?? activeLine.speaker).slice(0, 1)}
                    </span>
                  )}
                </div>
                <div className="line-copy">
                  <div className="speaker">
                    {NPC_NAMES[activeLine.speaker] ?? activeLine.speaker}
                    {activeLine.annotation ? (
                      <em> · {activeLine.annotation}</em>
                    ) : null}
                  </div>
                  <p>{activeLine.text}</p>
                </div>
              </div>
            ) : null}
            {storyAtEnd && stage.choices.length > 0 && !effectiveChoice ? (
              <div className="story-intents">
                <span className="intent-label">选择行动</span>
                {stage.choices.map((choice) => (
                  <button
                    key={choice}
                    onClick={() => {
                      setStoryChoice(choice);
                      setLineIndex(0);
                    }}
                  >
                    <span>{CHOICE_LABELS[choice] ?? choice}</span>
                  </button>
                ))}
              </div>
            ) : null}
            <footer className="story-footer">
              {activeStorySpeaker ? (
                storyAtEnd ? (
                  <button className="primary" onClick={finishSpeaker}>
                    结束对话
                  </button>
                ) : (
                  <button
                    className="primary"
                    onClick={() => setLineIndex((value) => value + 1)}
                  >
                    继续
                  </button>
                )
              ) : storyAtEnd && stage.choices.length > 0 && !effectiveChoice ? (
                <span className="footer-hint">先选择一种行动</span>
              ) : storyAtEnd ? (
                <button className="primary" onClick={finishStage}>
                  完成这一幕
                </button>
              ) : (
                <button
                  className="primary"
                  onClick={() => setLineIndex((value) => value + 1)}
                >
                  继续
                </button>
              )}
              <button
                className="ghost"
                onClick={() => {
                  setStoryOpen(false);
                  setActiveStorySpeaker(null);
                }}
              >
                稍后继续
              </button>
            </footer>
          </section>
        </div>
      ) : storyOpen ? (
        <div className="story-layer">
          <section className="story-card">
            <p className="load-fail">剧情数据正在载入，请稍后重试。</p>
          </section>
        </div>
      ) : null}
      {reportOpen && report ? (
        <div className="report-layer">
          <button
            type="button"
            className="report-dimmer"
            aria-label="关闭晨间保苗报告"
            onClick={() => setReportOpen(false)}
          />
          <section className="report-card" aria-label="晨间保苗报告">
            <header className="report-header">
              <div>
                <h2>我先看看今天的田</h2>
                <p>
                  第 {report.day} 天 · 天气：{report.weather}
                </p>
              </div>
              <button
                className="report-close"
                onClick={() => setReportOpen(false)}
              >
                关闭 [Esc]
              </button>
            </header>
            <div
              className={
                report.required.length
                  ? 'report-safety warn'
                  : 'report-safety safe'
              }
            >
              <strong>{report.safetyMessage}</strong>
              {report.required.length ? (
                <p>
                  保住危险作物预计至少需要 {report.minimumStamina} 点体力；若连建议地块也照料，共需 {report.fullCareStamina} 点。
                </p>
              ) : (
                <p>今天没有必须处理的作物，无需为保苗消耗体力。</p>
              )}
            </div>
            <div className="report-sections">
              <section>
                <h3>必须 · 今晚不处理会枯萎</h3>
                {report.required.length ? (
                  <ul>
                    {report.required.map((entry) => (
                      <li key={entry.cell}>
                        {entry.crop} · {entry.cell} · {entry.note}
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="report-empty">没有必须处理的地块。</p>
                )}
              </section>
              <section>
                <h3>建议 · 今天不处理只会暂停成长</h3>
                {report.recommended.length ? (
                  <ul>
                    {report.recommended.map((entry) => (
                      <li key={entry.cell}>
                        {entry.crop} · {entry.cell} · {entry.note}
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="report-empty">没有建议浇水的地块。</p>
                )}
              </section>
              <section>
                <h3>已经成熟 · 可按自己的安排收获</h3>
                {report.mature.length ? (
                  <ul>
                    {report.mature.map((entry) => (
                      <li key={entry.cell}>
                        {entry.crop} · {entry.cell} · {entry.note}
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="report-empty">今天没有新成熟的作物。</p>
                )}
              </section>
              <section>
                <h3>已有照料覆盖</h3>
                {report.covered.length ? (
                  <ul>
                    {report.covered.map((entry) => (
                      <li key={entry.cell}>
                        {entry.crop} · {entry.cell} · {entry.note}
                      </li>
                    ))}
                  </ul>
                ) : (
                  <p className="report-empty">今天没有雨水、水渠或托管覆盖。</p>
                )}
              </section>
            </div>
            <footer className="report-footer">
              关闭后可用 [R] 再次打开；报告只读取当前农田，不会改动作物。
            </footer>
          </section>
        </div>
      ) : null}
      {journeyOpen ? (
        <JourneySceneLayer
          checkpoint={game.story.journeyCheckpoint}
          onAdvance={() => update(completeJourneyCheckpoint)}
          onAbandon={() => {
            abandonJourney();
            setJourneyOpen(false);
          }}
          onSettle={() => settleHomecoming()}
          onClose={() => setJourneyOpen(false)}
        />
      ) : null}
      {galleryOpen ? (
        <GalleryLayer
          unlocked={game.story.completedArcs.length >= 10}
          ending={game.story.ending}
          onRecall={async (): Promise<PreRevealRecall | null> => {
            try {
              const loaded = await saveStore.loadSlot(
                game.campaignId,
                'pre_reveal',
                0,
              );
              if (!loaded) return null;
              const parsed = parseGame(loaded.payload);
              if (!parsed) return null;
              return {
                day: parsed.day,
                mapDisplayName: MAPS[parsed.map].name,
                standing: parsed.standing,
                balance: parsed.coins,
                growingCropCount: Object.values(parsed.plots).filter(
                  (p) => p.crop,
                ).length,
              };
            } catch {
              return null;
            }
          }}
          onClose={() => setGalleryOpen(false)}
        />
      ) : null}
    </main>
  );
}

function panelTitle(panel: Panel) {
  return (
    (
      {
        journal: '任务与主剧情',
        inventory: '背包与种源',
        craft: '制作、加工与放置',
        herd: '农场动物',
        settings: '暂停与设置',
        help: '操作说明',
        shop: '溪火猫食铺',
      } as Record<string, string>
    )[panel ?? ''] ?? ''
  );
}

// P0-1: the legacy DOM/CSS puzzle-map renderer (`World`) was removed in this
// session; the world is drawn only by runtime/canvas-world.tsx on one canvas.


function Journal({
  game,
  arc,
  stage,
  storyData,
  openStory,
  storyHint,
  onEnterJourney,
  onOpenGallery,
  onAbandonJourney,
  onSettleHomecoming,
}: {
  game: GameState;
  arc: StoryArc | null;
  stage: StoryStage | null;
  storyData: StoryPayload | null;
  openStory: () => void;
  storyHint: string;
  onEnterJourney: () => void;
  onOpenGallery: () => void;
  onAbandonJourney: () => void;
  onSettleHomecoming: () => boolean;
}) {
  return (
    <Tabs defaultValue="main">
      <TabsList>
        <TabsTrigger value="main">当前任务</TabsTrigger>
        <TabsTrigger value="story">十段主剧情</TabsTrigger>
        <TabsTrigger value="journey">雾岭旅程</TabsTrigger>
        <TabsTrigger value="records">进度记录</TabsTrigger>
      </TabsList>
      <TabsContent value="main" className="panel-section">
        <h3>让旧水渠再次流动</h3>
        <p>
          采集溪木与苔石，制作水渠接片并安放；之后向集市水工学徒回报。主线不依赖社交风评。
        </p>
        <div className="quest-steps">
          <span className={game.gathered.length >= 2 ? 'done' : ''}>
            采集材料
          </span>
          <span className={game.quest.canalPlaced ? 'done' : ''}>
            安放接片 +12
          </span>
          <span className={game.quest.canalReported ? 'done' : ''}>
            回报修复 +8
          </span>
        </div>
        <div className="stat-grid">
          <Stat label="水脉" value={`${game.watershed}/20`} />
          <Stat label="风评" value={game.standing} />
          <Stat
            label="集市告示"
            value={game.quest.noticeRead ? '已读' : '未读'}
          />
        </div>
      </TabsContent>
      <TabsContent value="story" className="panel-section">
        <div className="story-heading">
          <div>
            <small>
              当前章节 Q{String(game.story.arcIndex + 1).padStart(2, '0')}
            </small>
            <h3>{arc?.title ?? '载入中'}</h3>
            <p>
              {stage
                ? (STAGE_LABELS[stage.label] ?? stage.id)
                : '正在读取 236 条正式对白'}
            </p>
          </div>
          <Button onClick={openStory} disabled={!storyData}>
            <BookOpenText />
            进入剧情
          </Button>
        </div>
        <p className="footer-hint">{storyHint}</p>
        <div className="arc-grid">
          {storyData?.stories.map((item, index) => (
            <div
              key={item.id}
              className={
                index < game.story.arcIndex ||
                game.story.completedArcs.includes(item.id)
                  ? 'complete'
                  : index === game.story.arcIndex
                    ? 'current'
                    : ''
              }
            >
              <b>Q{String(index + 1).padStart(2, '0')}</b>
              <span>{item.title}</span>
              {game.story.completedArcs.includes(item.id) ? (
                <strong>完成</strong>
              ) : null}
            </div>
          ))}
        </div>
      </TabsContent>
      <TabsContent value="journey" className="panel-section">
        <h3>《雾岭失踪的猫猫公主》</h3>
        <p>
          Q08
          使用可中断、无战斗、无作物和经济损失的三段旅程。检查点与主存档一起写入伴随档；放弃时回退到出发前保护档。
        </p>
        <div className="journey-map">
          {['旧水路', '雾岭岔路', '灰栅农场'].map((name, index) => (
            <div
              key={name}
              className={game.story.journeyCheckpoint > index ? 'done' : ''}
            >
              <Sparkles />
              <b>{name}</b>
              <small>
                {game.story.journeyCheckpoint > index
                  ? '已确认'
                  : index === game.story.journeyCheckpoint &&
                      game.story.journeyCheckpoint < 3
                    ? '进行中'
                    : '待抵达'}
              </small>
            </div>
          ))}
        </div>
        <div className="large-actions">
          <Button
            onClick={onEnterJourney}
            disabled={!!game.story.choices['q08:returned']}
          >
            <Sparkles />
            进入雾岭旅程
          </Button>
        </div>
        <div className="large-actions">
          <Button
            variant="outline"
            disabled={game.story.journeyCheckpoint === 0}
            onClick={onAbandonJourney}
          >
            <RotateCcw />
            放弃旅程并回退保护档
          </Button>
          <Button
            disabled={
              game.story.journeyCheckpoint < 3 ||
              !!game.story.choices['q08:returned']
            }
            onClick={onSettleHomecoming}
          >
            <Sparkles />
            {game.story.choices['q08:returned']
              ? '返乡已结算（不重复）'
              : '确认返乡 · exactly-once'}
          </Button>
        </div>
      </TabsContent>
      <TabsContent value="records" className="panel-section">
        <div className="stat-grid">
          <Stat
            label="正式对白"
            value={
              storyData ? `${storyData.manuscript_line_count} 条` : '载入中'
            }
          />
          <Stat
            label="已完成剧情"
            value={`${game.story.completedArcs.length}/10`}
          />
          <Stat
            label="揭露保护点"
            value={game.story.preRevealSave ? '已建立' : '未触发'}
          />
          <Stat
            label="结局"
            value={
              game.story.ending === 'water'
                ? '最后浇水'
                : game.story.ending === 'leave'
                  ? '离开农场'
                  : '未毕业'
            }
          />
        </div>
        <div className="large-actions">
          <Button onClick={onOpenGallery}>
            <Sparkles />
            结局画廊
          </Button>
        </div>
      </TabsContent>
    </Tabs>
  );
}

function Inventory({
  game,
  update,
}: {
  game: GameState;
  update: (action: (state: GameState) => GameState) => void;
}) {
  const items = Object.entries(game.inventory).filter(
    ([, qty]) => (qty ?? 0) > 0,
  );
  return (
    <div className="panel-section">
      <h3>溪谷行囊</h3>
      <div className="inventory-grid">
        {items.map(([id, qty]) => (
          <div key={id}>
            <img src={itemAsset(id)} alt="" />
            <span>{ITEM_NAMES[id] ?? id}</span>
            <b>×{qty}</b>
          </div>
        ))}
      </div>
      <h3>选择种源</h3>
      <div className="seed-grid">
        {(Object.keys(CROPS) as CropId[]).map((crop) => (
          <button
            key={crop}
            className={game.selectedSeed === crop ? 'selected' : ''}
            onClick={() => update((state) => selectSeed(state, crop))}
          >
            <img src={`${A}/crop_${crop}.png`} alt="" />
            <b>{CROPS[crop].name}</b>
            <small>种子 ×{game.inventory[`${crop}_seed`] ?? 0}</small>
          </button>
        ))}
      </div>
      <h3>种源棚补给</h3>
      <div className="seed-grid compact">
        {(Object.keys(CROPS) as CropId[]).map((crop) => (
          <button
            key={crop}
            onClick={() => update((state) => buySeeds(state, crop))}
          >
            <Coins />
            <b>{CROPS[crop].seedName} ×4</b>
            <small>
              {Math.max(12, Math.floor(CROPS[crop].price * 0.45))} 溪票
            </small>
          </button>
        ))}
      </div>
      <div className="panel-actions">
        <Button onClick={() => update(shipAll)}>
          <Coins />
          结算出售箱全部货物
        </Button>
      </div>
    </div>
  );
}

function Crafting({
  game,
  update,
}: {
  game: GameState;
  update: (action: (state: GameState) => GameState) => void;
}) {
  return (
    <Tabs defaultValue="craft">
      <TabsList>
        <TabsTrigger value="craft">制作</TabsTrigger>
        <TabsTrigger value="process">木蜜灶台</TabsTrigger>
        <TabsTrigger value="place">放置</TabsTrigger>
      </TabsList>
      <TabsContent value="craft" className="recipe-list">
        {CRAFTS.map((recipe) => (
          <article key={recipe.id}>
            <img src={itemAsset(recipe.id)} alt="" />
            <div>
              <h4>{recipe.name}</h4>
              <p>
                {Object.entries(recipe.needs)
                  .map(
                    ([id, qty]) =>
                      `${ITEM_NAMES[id]} ${game.inventory[id as ItemId] ?? 0}/${qty}`,
                  )
                  .join(' · ')}
              </p>
            </div>
            <Button onClick={() => update((state) => craft(state, recipe.id))}>
              制作
            </Button>
          </article>
        ))}
      </TabsContent>
      <TabsContent value="process" className="recipe-list">
        {PROCESSING.map((recipe) => (
          <article key={recipe.id}>
            <CookingPot />
            <div>
              <h4>{recipe.name}</h4>
              <p>
                {ITEM_NAMES[recipe.input]} ×1 → {recipe.price} 溪票基准
              </p>
            </div>
            <Button
              onClick={() => update((state) => processItem(state, recipe.id))}
            >
              加工
            </Button>
          </article>
        ))}
      </TabsContent>
      <TabsContent value="place" className="recipe-list">
        {CRAFTS.map((recipe) => (
          <article key={recipe.id}>
            <Box />
            <div>
              <h4>{recipe.name}</h4>
              <p>
                背包 {game.inventory[recipe.id as ItemId] ?? 0} · 已放置{' '}
                {game.placed[recipe.id] ?? 0}
              </p>
            </div>
            <Button
              onClick={() => update((state) => placeCrafted(state, recipe.id))}
            >
              安放
            </Button>
          </article>
        ))}
      </TabsContent>
    </Tabs>
  );
}

function Herd({
  game,
  update,
}: {
  game: GameState;
  update: (action: (state: GameState) => GameState) => void;
}) {
  return (
    <div className="panel-section">
      <div className="story-heading">
        <div>
          <small>每日温和照料</small>
          <h3>农场动物</h3>
          <p>没有伤病与死亡；保护期内不能供货交接。</p>
        </div>
        <Button variant="outline" onClick={() => update(sleep)}>
          <Moon />
          睡到明天
        </Button>
      </div>
      <div className="animal-grid">
        {game.animals.map((animal) => (
          <article key={animal.id}>
            <img src={`${W}/wl_farm_${animal.kind}.png`} alt="" />
            <div>
              <h4>{animal.name}</h4>
              <p>
                {animal.kind === 'cow'
                  ? '溪谷奶牛'
                  : animal.kind === 'sheep'
                    ? '雾绒羊'
                    : '坡角山羊'}{' '}
                · {animal.age} 日龄
              </p>
              <span>
                照料 {animal.careDays} 天 ·{' '}
                {animal.protected ? '保护中' : '可自主决定交接'}
              </span>
            </div>
            <Button
              onClick={() => update((state) => careAnimal(state, animal.id))}
              disabled={animal.caredDay === game.day}
            >
              <Heart />
              {animal.caredDay === game.day ? '今日已照料' : '照料'}
            </Button>
          </article>
        ))}
      </div>
    </div>
  );
}

function CatShop({
  game,
  update,
}: {
  game: GameState;
  update: (action: (state: GameState) => GameState) => void;
}) {
  const cropIds = Object.keys(CROPS) as CropId[];
  const rotation = [
    cropIds[(game.day - 1) % cropIds.length],
    cropIds[(game.day + 1) % cropIds.length],
  ];
  return (
    <div className="panel-section cat-shop">
      <div className="shop-banner">
        <img src={`${W}/wl_cat_bbq_shop_r3.png`} alt="溪火猫食铺" />
        <div>
          <small>今日公开收购</small>
          <h3>溪火猫食铺</h3>
          <p>即时支付；错过当日需求没有惩罚。</p>
        </div>
      </div>
      <h3>轮换作物</h3>
      <div className="recipe-list">
        {rotation.map((crop) => (
          <article key={crop}>
            <img src={`${A}/crop_${crop}.png`} alt="" />
            <div>
              <h4>{CROPS[crop].name}</h4>
              <p>持有 {game.inventory[crop] ?? 0} · 每日上限 6 · 110% 价</p>
            </div>
            <Button
              onClick={() => update((state) => catShopSellCrop(state, crop))}
            >
              交付
            </Button>
          </article>
        ))}
      </div>
      <h3>合格动物供货</h3>
      <div className="recipe-list">
        {game.animals.map((animal) => (
          <article key={animal.id}>
            <PawPrint />
            <div>
              <h4>{animal.name}</h4>
              <p>
                {animal.protected ? '保护期未结束' : '可进行非暴力抽象交接'}
              </p>
            </div>
            <Button
              variant="outline"
              disabled={animal.protected}
              onClick={() => {
                if (
                  window.confirm(
                    `确认把 ${animal.name} 交由猫店接收？这个操作会从农场移除它。`,
                  )
                )
                  update((state) => catShopSellAnimal(state, animal.id));
              }}
            >
              二次确认
            </Button>
          </article>
        ))}
      </div>
    </div>
  );
}

function PauseSettings({
  game,
  settings,
  setSettings,
  exportSave,
  importSave,
  fileInput,
  resetGame,
  setPanel,
  update,
  slotMeta,
  onSaveSlot,
  onLoadSlot,
}: {
  game: GameState;
  settings: WebSettings;
  setSettings: (value: WebSettings) => void;
  exportSave: () => void;
  importSave: (file: File) => Promise<void>;
  fileInput: React.RefObject<HTMLInputElement | null>;
  resetGame: () => void;
  setPanel: (panel: Panel) => void;
  update: (action: (state: GameState) => GameState) => void;
  slotMeta: Record<string, SaveMeta>;
  onSaveSlot: (index: number) => void;
  onLoadSlot: (index: number) => void;
}) {
  const slotLine = (kind: string, index = 0) => {
    const meta = slotMeta[`${kind}:${index}`];
    return meta
      ? `第 ${meta.day} 天 · ${meta.updatedAt.slice(5, 16).replace('T', ' ')}`
      : '空';
  };
  return (
    <div className="settings-layout">
      <section>
        <h3>继续游玩</h3>
        <div className="large-actions">
          <Button onClick={() => setPanel(null)}>
            <Home />
            返回游戏
          </Button>
          <Button variant="outline" onClick={() => update(sleep)}>
            <Moon />
            睡到明天
          </Button>
          <Button variant="outline" onClick={() => setPanel('help')}>
            <HelpCircle />
            操作说明
          </Button>
        </div>
      </section>
      <section>
        <h3>声音与显示</h3>
        <label className="setting-row">
          <span>
            <Music />
            纯净 BGM<small>农场与集市各自的已选音乐</small>
          </span>
          <Switch
            checked={settings.music}
            onCheckedChange={(music) => setSettings({ ...settings, music })}
          />
        </label>
        <label className="setting-slider">
          <span>
            <Volume2 />
            音乐音量
          </span>
          <Slider
            value={[settings.musicVolume * 100]}
            onValueChange={(value) => {
              const raw = Array.isArray(value) ? value[0] : value;
              setSettings({ ...settings, musicVolume: (raw ?? 35) / 100 });
            }}
          />
        </label>
        <label className="setting-row">
          <span>
            <Sparkles />
            减少动态效果<small>停止角色浮动和提示呼吸</small>
          </span>
          <Switch
            checked={settings.reducedMotion}
            onCheckedChange={(reducedMotion) =>
              setSettings({ ...settings, reducedMotion })
            }
          />
        </label>
      </section>
      <section>
        <h3>存档</h3>
        <p className="muted">
          campaign {game.campaignId} · 第 {game.day} 天 ·{' '}
          {game.updatedAt.slice(0, 19).replace('T', ' ')}
        </p>
        <div className="slot-list">
          <div className="slot-row">
            <span>
              <b>自动槽</b>
              <small>{slotLine('auto')}</small>
            </span>
            <em>持续备份</em>
          </div>
          {[0, 1, 2].map((index) => (
            <div className="slot-row" key={index}>
              <span>
                <b>手动槽 {index + 1}</b>
                <small>{slotLine('manual', index)}</small>
              </span>
              <Button size="sm" variant="outline" onClick={() => onLoadSlot(index)}>
                读取
              </Button>
              <Button size="sm" onClick={() => onSaveSlot(index)}>
                保存
              </Button>
            </div>
          ))}
          <div className="slot-row quiet">
            <span>
              <b>Q08 旅程伴随档</b>
              <small>{slotLine('mission_current')}</small>
            </span>
            <em>检查点写入</em>
          </div>
          <div className="slot-row quiet">
            <span>
              <b>Q09 揭露前保护档</b>
              <small>{slotLine('pre_reveal')}</small>
            </span>
            <em>首行前写入</em>
          </div>
        </div>
        <p className="muted">进度保存在本机 IndexedDB；localStorage 仅作恢复镜像与设置。</p>
        <div className="large-actions">
          <Button variant="outline" onClick={exportSave}>
            <Download />
            导出 JSON
          </Button>
          <Button variant="outline" onClick={() => fileInput.current?.click()}>
            <Upload />
            导入 JSON
          </Button>
          <input
            ref={fileInput}
            className="sr-only"
            type="file"
            accept="application/json,.json"
            onChange={(event) => {
              const file = event.target.files?.[0];
              if (file) importSave(file).catch(() => undefined);
              event.target.value = '';
            }}
          />
          <Button variant="destructive" onClick={resetGame}>
            <RotateCcw />
            重新开始本档
          </Button>
        </div>
      </section>
    </div>
  );
}

function Help() {
  return (
    <div className="panel-section help-grid">
      <article>
        <ArrowUp />
        <h3>移动与换图</h3>
        <p>
          WASD、方向键或右下方向盘移动。走到地图边缘的出口箭头即可前往另一张图；点一下出口也可换图。
        </p>
      </article>
      <article>
        <Shovel />
        <h3>农务</h3>
        <p>
          1–4
          切换锄头、种子、浇水壶和收获手套；E/空格对前方使用。点击相邻农田也可操作。
        </p>
      </article>
      <article>
        <BookOpenText />
        <h3>面板与剧情</h3>
        <p>
          B 背包 · C 制作加工 · M 畜牧 · J 任务与主剧情 · Esc 暂停与设置。
          Q01–Q10 剧情、选项、雾岭检查点、揭露保护点与结局都会自动保存。
        </p>
      </article>
      <article>
        <Archive />
        <h3>保存与晨报</h3>
        <p>浏览器自动保存；睡醒会显示晨间保苗报告，农场中按 R 可再次打开。暂停页可导出 JSON；导入无效文件不会覆盖当前进度。</p>
      </article>
    </div>
  );
}
function Stat({ label, value }: { label: string; value: string | number }) {
  return (
    <div className="stat">
      <small>{label}</small>
      <strong>{value}</strong>
    </div>
  );
}
function itemAsset(id: string) {
  if (id.endsWith('_seed')) return `${A}/crop_${id.replace('_seed', '')}.png`;
  if (Object.hasOwn(CROPS, id)) return `${A}/crop_${id}.png`;
  const map: Record<string, string> = {
    creek_wood: 'gather_creek_wood_r2.png',
    moss_stone: 'gather_moss_stone_r2.png',
    reed_fiber: 'gather_reed_fiber_r2.png',
    canal_segment: 'prop_canal_segment_ew.png',
    rain_barrel: 'prop_rain_barrel_r2.png',
    wooden_crate: 'prop_wooden_crate_r2.png',
    compost_rack: 'prop_compost_bin_r2.png',
    woodhoney_hearth: 'prop_woodhoney_hearth_r2.png',
  };
  return map[id] ? `${A}/${map[id]}` : `${A}/ui_slot.png`;
}
