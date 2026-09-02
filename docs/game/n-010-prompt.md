# N-010 执行 Prompt（复制给 Codex）

你是《溪谷新芽》的 🧱 tech / gameplay 执行者，执行 N-010 完整全身立绘运行时渲染层。Product Owner 已批准 `DEC-030`：N-007 保持 `revise / REVISE`，仅将高清立绘运行时缺口有界转由 N-010 承接。你不是最终质量批准人，Hermes 负责独立门禁。

## 开工预检

1. 读取 `AGENTS.md`、工作室角色与流程参考、`skills/project-ledger/SKILL.md`、`docs/game/project-ledger.md`、`docs/game/n-010-brief.md`、`docs/game/n-008-brief.md`。
2. 核对 N-009 为 `accepted / APPROVED`，确认 8 张 processed 立绘、manifest、SHA-256 与 PO/content/Hermes 证据存在。
3. 核对主台账存在 DEC-030；没有 DEC-030 时停止并返回 `BLOCKED`。
4. N-007 仍为 `REVISE` 不再阻止本任务，但只允许执行本 Prompt 与 brief 规定的范围。

## 实现要求

- 从 N-009 processed 层建立独立 presentation 资源映射，不覆盖地图 `32×48` sprite。
- 对话卡与角色信息页共用同一映射服务。
- 保证 1:1 立绘等比缩放，头顶到鞋底完整可见。
- 缺失文件、未知 ID、加载失败均安全回退，不崩溃、不阻断对话。
- 保留 HUD 默认收起与 `H` 展开/收起。
- 不把映射写入存档，不改领域规则、地图、碰撞、经济或玩法。

## 锁定烟雾路径

新游戏 → 走到水工学徒 → 触发对话并截图 → 打开角色信息页并截图 → 再验证至少两名不同职业角色 → 模拟缺失一张立绘并截图安全回退 → 保存 → 完全退出 → 重启 → 读取 → 再次对话确认展示一致。

## 交付格式

Outcome:
Changed artifacts:
Validation evidence:
Decisions and assumptions:
Risks and follow-ups:
Requested department gate: 请 Hermes 返回 `APPROVED | REVISE | BLOCKED`；Codex 不自签。

若任何实现需要触碰禁止文件、改变玩法或超出 DEC-030，立即停止并返回 `BLOCKED`。
