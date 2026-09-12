'use client';

// Q08 journey mini-scenes: native-equivalent presentation layer mirroring
// StoryJourneySceneController/View (normalized coordinates, eased stepping,
// slide-along collisions, anchor highlight within interaction radius,
// checkpoint -> exit -> next scene; final exit settles homecoming).
import { useEffect, useState } from 'react';
import {
  JOURNEY_ANCHORS,
  JOURNEY_ANCHOR_STYLE,
  JOURNEY_PLAYER,
  JOURNEY_SCENES,
  type JourneySceneDef,
} from '@/content/r22-journey';

const STEP = 0.05;
const INTERACTION_RADIUS = 0.1;
const clamp = (v: number, min: number, max: number) =>
  Math.min(max, Math.max(min, v));

export type JourneySceneLayerProps = {
  checkpoint: number; // 0..3 persisted story.journeyCheckpoint
  onAdvance: () => void;
  onAbandon: () => void;
  onSettle: () => boolean;
  onClose: () => void;
};

const sceneForCheckpoint = (checkpoint: number) => {
  const idx = checkpoint >= 3 ? 2 : clamp(checkpoint, 0, 2);
  return { idx, resolved: checkpoint >= 3 };
};
const entryOf = (scene: JourneySceneDef) => {
  const anchor = JOURNEY_ANCHORS.find((a) => a.id === scene.entryAnchorId);
  return { x: anchor?.x ?? 0.5, y: anchor?.y ?? 0.5 };
};
const anchorsOf = (sceneId: string) =>
  JOURNEY_ANCHORS.filter((a) => a.scene === sceneId);
const blocked = (scene: JourneySceneDef, x: number, y: number) =>
  scene.collisions.some(
    ([minX, minY, maxX, maxY]) =>
      x >= minX && x <= maxX && y >= minY && y <= maxY,
  );

export function JourneySceneLayer({
  checkpoint,
  onAdvance,
  onAbandon,
  onSettle,
  onClose,
}: JourneySceneLayerProps) {
  const boot = sceneForCheckpoint(checkpoint);
  const [sceneIdx, setSceneIdx] = useState(boot.idx);
  const [resolved, setResolved] = useState(boot.resolved);
  const [player, setPlayer] = useState(() => entryOf(JOURNEY_SCENES[boot.idx]));
  const scene = JOURNEY_SCENES[sceneIdx];
  const anchors = anchorsOf(scene.id);

  const goScene = (next: number, settled: boolean) => {
    setSceneIdx(next);
    setPlayer(entryOf(JOURNEY_SCENES[next]));
    setResolved(settled);
  };

  const highlightId = (() => {
    let best: { id: string; d: number } | null = null;
    for (const anchor of anchors) {
      if (anchor.purpose !== 'entry' && anchor.purpose !== 'exit' && anchor.purpose !== 'interaction') continue;
      const d = Math.hypot(anchor.x - player.x, anchor.y - player.y);
      if (d <= INTERACTION_RADIUS && (!best || d < best.d)) best = { id: anchor.id, d };
    }
    return best?.id ?? null;
  })();

  const highlighted = anchors.find((a) => a.id === highlightId) ?? null;

  const prompt = !highlighted
    ? '方向键或 WASD 移动 · Esc 返回'
    : highlighted.purpose === 'exit'
      ? resolved
        ? '已到出口 · 空格离开本段'
        : '先查看检查点，再从这里离开。'
      : highlighted.purpose === 'entry'
        ? '已到入口 · 空格返回上一段'
        : resolved
          ? '检查点已确认'
          : '检查点 · 空格查看';

  const tryMove = (dx: number, dy: number) => {
    setPlayer((p) => {
      const nx = clamp(p.x + dx, 0.02, 0.98);
      const ny = clamp(p.y + dy, 0.02, 0.98);
      if (!blocked(scene, nx, ny)) return { x: nx, y: ny };
      if (!blocked(scene, nx, p.y)) return { x: nx, y: p.y };
      if (!blocked(scene, p.x, ny)) return { x: p.x, y: ny };
      return p;
    });
  };

  const interact = () => {
    if (!highlighted) return;
    if (highlighted.purpose === 'interaction') {
      // A scene's checkpoint may only advance when it is the one awaiting
      // confirmation (checkpoint === sceneIdx); revisiting an older scene
      // never re-advances the domain checkpoint.
      if (!resolved && checkpoint === sceneIdx) {
        setResolved(true);
        onAdvance();
      }
      return;
    }
    if (highlighted.purpose === 'entry') {
      if (sceneIdx > 0) goScene(sceneIdx - 1, false);
      return;
    }
    if (highlighted.purpose === 'exit') {
      // Exit unlocks once this scene's checkpoint is confirmed (resolved),
      // or when it was already completed in an earlier session
      // (checkpoint > sceneIdx, e.g. revisiting an old scene via its entry).
      if (!resolved && checkpoint <= sceneIdx) return;
      if (sceneIdx >= 2) {
        const ok = onSettle();
        if (ok) onClose();
      } else {
        goScene(sceneIdx + 1, false);
      }
    }
  };

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      const key = event.key.toLowerCase();
      if (key === 'escape') {
        event.preventDefault();
        onClose();
        return;
      }
      if (key === ' ' || key === 'e') {
        event.preventDefault();
        interact();
        return;
      }
      const dirs: Record<string, [number, number]> = {
        w: [0, -1],
        arrowup: [0, -1],
        s: [0, 1],
        arrowdown: [0, 1],
        a: [-1, 0],
        arrowleft: [-1, 0],
        d: [1, 0],
        arrowright: [1, 0],
      };
      const dir = dirs[key];
      if (dir) {
        event.preventDefault();
        tryMove(dir[0] * STEP, dir[1] * STEP);
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  });

  const pad = (dir: [number, number], label: string) => (
    <button
      type="button"
      aria-label={label}
      onClick={() => tryMove(dir[0] * STEP, dir[1] * STEP)}
    >
      {label}
    </button>
  );

  return (
    <section className="journey-layer" aria-label="雾岭旅程">
      <header className="journey-header">
        <strong>旅程 · {scene.name}</strong>
        <span className="journey-dot" aria-hidden="true">
          {JOURNEY_SCENES.findIndex((s) => s.id === scene.id) + 1} / 3
        </span>
        <div className="journey-actions">
          <button type="button" className="abandon" onClick={() => {
            onAbandon();
            onClose();
          }}>
            放弃远行
          </button>
          <button type="button" className="close" onClick={onClose}>
            返回
          </button>
        </div>
      </header>
      <div className="journey-stage">
        {scene.collisions.map(([minX, minY, maxX, maxY]) => (
          <i
            key={`${minX}-${minY}`}
            className="journey-collision"
            style={{
              left: `${minX * 100}%`,
              top: `${minY * 100}%`,
              width: `${(maxX - minX) * 100}%`,
              height: `${(maxY - minY) * 100}%`,
            }}
          />
        ))}
        {anchors.map((anchor) => {
          const meta = JOURNEY_ANCHOR_STYLE[anchor.purpose];
          const isHot = highlightId === anchor.id;
          return (
            <div
              key={anchor.id}
              className={`journey-anchor ${isHot ? 'hot' : ''}`}
              style={{ left: `${anchor.x * 100}%`, top: `${anchor.y * 100}%` }}
              aria-label={`${meta.label} ${anchor.id}`}
            >
              <i style={{ background: meta.color }} />
              {meta.label ? <span>{meta.label}</span> : null}
            </div>
          );
        })}
        <div
          className="journey-player"
          style={{ left: `${player.x * 100}%`, top: `${player.y * 100}%` }}
          aria-label={`玩家位置 ${player.x.toFixed(2)}, ${player.y.toFixed(2)}`}
        >
          <i style={{ background: JOURNEY_PLAYER.fill }} />
          <span>新</span>
        </div>
        <div className="journey-prompt">{prompt}</div>
        <div className="journey-pad">
          {pad([0, -1], '向上')}
          {pad([-1, 0], '向左')}
          <button type="button" aria-label="查看或确认" onClick={interact}>
            确认
          </button>
          {pad([1, 0], '向右')}
          {pad([0, 1], '向下')}
        </div>
      </div>
    </section>
  );
}
