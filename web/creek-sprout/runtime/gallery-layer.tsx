'use client';

// Ending gallery: native-equivalent presentation mirroring StoryGalleryView
// (black .72 backdrop, 720pt centered scroll, white .07 section cards with
// copper titles). Contents map onto web state honestly: keepsake/ledger/
// annotation collections do not exist in this build and render their empty
// states; the pre-reveal protection snapshot is read from the IndexedDB
// pre_reveal kind and shown without overwriting the live campaign.
import { useState, type ReactNode } from 'react';

export type PreRevealRecall = {
  day: number;
  mapDisplayName: string;
  standing: number;
  balance: number;
  growingCropCount: number;
};

export type GalleryLayerProps = {
  unlocked: boolean;
  ending: 'water' | 'leave' | null;
  onRecall: () => Promise<PreRevealRecall | null>;
  onClose: () => void;
};

const endingLabel = (ending: 'water' | 'leave' | null) => {
  if (ending === 'water') return '最后浇一次水 · 留在溪谷';
  if (ending === 'leave') return '从码头离开 · 远行';
  return '毕业结果尚未记录';
};

export function GalleryLayer({
  unlocked,
  ending,
  onRecall,
  onClose,
}: GalleryLayerProps) {
  const [recall, setRecall] = useState<PreRevealRecall | null>(null);
  const [recalling, setRecalling] = useState(false);
  const recallNow = async () => {
    setRecalling(true);
    try {
      const result = await onRecall();
      if (result) setRecall(result);
    } finally {
      setRecalling(false);
    }
  };

  const sectionCard = (
    title: string,
    children: ReactNode,
  ) => (
    <section className="gallery-card-block">
      <h3>{title}</h3>
      {children}
    </section>
  );
  const emptyLine = (text: string) => <p className="gallery-empty">{text}</p>;

  return (
    <div className="gallery-layer" aria-label="结局画廊">
      <div className="gallery-inner">
        <header className="gallery-header">
          <h2>结局画廊</h2>
          <button type="button" onClick={onClose}>
            关闭
          </button>
        </header>
        {unlocked ? (
          <>
            {sectionCard(
              '毕业结果',
              <p className="gallery-line">
                {ending ? endingLabel(ending) : '尚未记录毕业行动。'}
              </p>,
            )}
            {sectionCard(
              '英雄牌与合照',
              emptyLine('还没有英雄牌或合照。'),
            )}
            {sectionCard('账簿页（0）', emptyLine('没有发现的账簿页。'))}
            {sectionCard('分支批注（0）', emptyLine('没有发现的分支批注。'))}
            {sectionCard(
              '揭露前保护存档',
              recall ? (
                <div className="gallery-recall">
                  <p>
                    第 {recall.day} 天 · {recall.mapDisplayName} · 风评{' '}
                    {recall.standing} · 溪票 {recall.balance}
                  </p>
                  <p className="gallery-muted">
                    位置 {recall.mapDisplayName} · 生长中作物{' '}
                    {recall.growingCropCount} 格
                  </p>
                </div>
              ) : (
                <div>
                  {emptyLine('保护档尚未读取。毕业后的画廊可以安全回看揭露前的农场状态。')}
                  <button
                    type="button"
                    className="gallery-recall-button"
                    disabled={recalling}
                    onClick={recallNow}
                  >
                    {recalling ? '读取中…' : '读取揭露前保护档'}
                  </button>
                </div>
              ),
            )}
          </>
        ) : (
          <section className="gallery-card-block">
            <h3 className="locked">画廊尚未解锁</h3>
            <p className="gallery-empty">
              完成 Q09–Q10 的揭露与毕业行动后，这里会展示账簿页、分支批注、
              英雄牌、合照与毕业结果。
            </p>
          </section>
        )}
      </div>
    </div>
  );
}
