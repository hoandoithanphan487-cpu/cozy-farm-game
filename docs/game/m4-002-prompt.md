# M4-002 Cursor 开工 Prompt（粘贴给 Cursor / Codex）

> 本文件是 `docs/game/m4-002-brief.md` 的执行版。Cursor 是唯一实现负责人；完成后经 🛡️ quality 独立验收（Hermes），任何人不得自行 APPROVED。本任务**不做任何源码功能改动**，只做候选包构建/打包/离线烟雾取证。

## 1. 任务一句话

在现有 Xcode + Swift + SpriteKit 工程（CreekSprout）上生成 macOS arm64 **发布候选包**：Release 构建（0 警告）→ 制作本地安装包（zip/dmg）→ 断网安装/启动/输入/存读/VS-0 烟雾回归 → 按 `platform-acceptance-plan.md` 产出证据包。不新增功能，不改源码语义。

## 2. 当前状态（独立核实过的事实，证据路径见括号）

- 工程在 `macos/CreekSprout/CreekSprout.xcodeproj`，scheme `CreekSprout`，macOS arm64 / Xcode 26.6 / macOS 26.5.2；参考设备 M4 MacBook Air / 16 GB（`docs/game/platform-acceptance-plan.md`）。
- M4-001 已 `accepted / APPROVED`（台账 `docs/game/project-ledger.md`）：性能达标（p95 2.11ms/p99 5.06ms、切图 p95 5.46ms、RSS 稳定）、多槽存档、D0 UX 修复与无障碍补充完成；单元回归权威基线 **228/228 passed、0 failed、0 skipped、0 编译警告**，证据 `artifacts/integration/m4-001-xcode/TestResults-M4-001-revise.xcresult` + `hermes-gate-report.md`。本任务**不重复 clean test**（DEC-015），引用该基线。
- 发行范围：仅 macOS arm64（DEC-012）；候选包验收合同 `docs/game/platform-acceptance-plan.md`（M4 发布候选完整夹具：安装、离线启动、输入、保存读取、VS-0 烟雾；证据根 `artifacts/acceptance/<candidate-build-id>/macos-arm64/<run-id>/`，每 run 一份 `manifest.md`）。
- 本机签名/信任服务已恢复（RSK-004 resolved，2026-08-19）：`codesign --verify` 可用；本机 adhoc 开发包被 `spctl` 判 `rejected` 属**正常策略评估**（无 Developer ID/公证），必须如实记录，不得移除隔离属性/重签名/升级来伪造安装证据。
- `artifacts/acceptance/` 现有目录仅 `m0-001-bootstrap`（Godot 时代历史）；候选包证据根由本任务创建。无任何 M4-002 文件/产物已存在（特性缺失探针通过）。
- 工作区现状：git 工作树含 M4-001 及更早的未提交修改（历史累积，正常）；本任务不得 `git commit`，在其上增量工作。

## 3. 实现边界

### 必须做（In scope）

1. **Release 构建**：
   ```text
   xcodebuild -project macos/CreekSprout/CreekSprout.xcodeproj -scheme CreekSprout \
     -configuration Release -destination 'platform=macOS,arch=arm64' \
     -derivedDataPath /tmp/creeksprout-m4-002 build
   ```
   0 编译警告/错误；记录构建身份（Xcode 版本、时间、产物路径）与 `shasum -a 256` 产物哈希。
2. **本地安装包**：Release 产物打包为 zip 或 dmg（选定后说明理由）；记录 `codesign --verify --deep --strict` 与 `spctl --assess` 原始输出（adhoc rejected 属预期，如实声明）。
3. **离线烟雾**：关闭 Wi-Fi（`networksetup -setairportpower en0 off`，记录 `networksetup -getairportpower en0` 与 `netstat -rn` 无默认路由为断网证据）→ 从本地安装包安装 → 启动 → 新游戏 → 键鼠输入 → 保存 → 完全退出 → 重启 → 读取（状态一致）→ VS-0 路径：收获 3 株 → 投入 → 174 结算（余额 894）→ 农耕三步 → 交谈 → 睡眠结算不重复到账。
4. **证据包**：`artifacts/acceptance/<candidate-build-id>/macos-arm64/<run-id>/` 下 `manifest.md`（候选构建版本、构建 ID、SHA-256、测试日期/时区、测试人员、测试平台、网络状态）+ 截图/HUD 转储/存档 JSON/安装与启动日志。
5. **最小工程配置**：如候选包构建确需 pbxproj 签名/打包配置，逐处声明理由（预期仅 `CODE_SIGN_IDENTITY` 类或打包脚本引用）。

### 禁止做（Out of scope / 红线，Do Not）

- ❌ 不改 PRD、TDD、`docs/game/project-ledger.md`、既有 brief/prompt、既有证据文件。
- ❌ 不自我 `APPROVED`，不修改任务状态，不宣称验收通过。
- ❌ 不改任何源码语义（`Content/`、`Domain/`、`Persistence/`、`ContentView.swift`、`FarmScene.swift`、测试）；不改 `ContentID.swift`/`ContentValidator.swift`。
- ❌ 不新增玩法/内容/经济/UI/无障碍功能（M4-001 及以前已全部完成）。
- ❌ 不做 Apple Developer ID 签名/公证/App Store 上架。
- ❌ 不通过移除隔离属性（`xattr -cr`）、临时重签名或升级版本伪造/掩盖安装与签名证据；`spctl` 结果如实记录。
- ❌ 不 `git commit`、不 `git reset`、不删除工作区未提交内容。
- ❌ 不复制任何受保护的任务、地图、对白、视觉或音频表达。

## 4. 可观察验收（全部需证据，对应 brief AC-1~10）

1. **Release 构建**成功，0 编译警告/错误；产物存在，构建身份 + SHA-256 已记录。
2. **本地安装包**生成（zip/dmg），安装方式与 codesign/spctl 结果如实记录。
3. **全程断网**证据（Wi-Fi off + 无默认路由）在 manifest.md 与命令日志中。
4. **离线安装**完成（如实记录安装路径/方式）。
5. **离线启动**进入新游戏界面，无网络依赖报错。
6. **键鼠输入**可用（移动/交互/背包/保存键，截图或 HUD 转储）。
7. **存读一致**：保存→完全退出→重启→读取，存档 JSON 前后一致。
8. **VS-0 回归**：174/894 结算、重启不重复到账、农耕三步/交谈可走通。
9. **证据包**字段完整（manifest.md + 截图/日志/存档），候选构建版本与 SHA-256 可追溯。
10. 无源码越界改动；`git diff --check` exit 0；未复制受保护表达。

## 5. 一条烟雾路径（锁定路径，逐项取证）

Release 构建 + SHA-256 → 制作安装包（codesign/spctl 原始输出）→ 断网（Wi-Fi off + 路由表证据）→ 本地安装 → 启动 + 新游戏（720/16 格/种子×8 截图）→ 移动收获 3 株 → 投入（待结算 3）→ 睡眠（174/894）→ 重启读取一致性 → 恢复网络 → 证据包落盘（manifest.md + 全部证据）。

## 6. 交付格式（全部放入候选包证据目录）

1. `cursor-handoff.md`：outcome、变更文件清单（每文件一句 + 理由；预期仅 scripts/ 与最小 pbxproj）、验收映射表（10 条逐条 → 证据文件）、已知限制（如无公证需右键打开）、下一负责人。
2. 候选包产物路径 + Release 构建原始日志 + 产物 SHA-256 + 安装包 SHA-256。
3. `manifest.md` + 离线烟雾每步截图/HUD 转储/存档 JSON/命令日志。
4. `git diff --check` 退出 0 输出；未修改文件清单（源码/PRD/TDD/台账/brief/证据）。
5. 决策与假设：安装包形式、安装路径、签名结果如实记录（含 spctl rejected 声明）。
6. 风险与遗留：安装/分发限制、非阻断项。

## 7. 回复格式（必须逐项确认，缺项视为未完成）

```
A. 范围确认：本任务 in scope 与红线逐条「确认 / 不确认」；不确认项说明原因。
B. 当前基线核验：228/228 权威基线（TestResults-M4-001-revise.xcresult）已引用；确认不重复 clean test。
C. 交付清单：第 6 节各文件路径 + 状态（已生成/未生成）。
D. 构建与打包结果：退出码、0 警告、产物 SHA-256、codesign/spctl 原始输出摘要。
E. 验收映射：10 条验收逐条 → 证据文件；未达标条目明确声明 REVISE 待办。
F. 风险与红线声明：声明未触碰任何红线（含未移除隔离属性/未重签名/未升级）。
G. 下一负责人：🛡️ quality（Hermes）独立验收。
```

完成后将本文件与 `docs/game/m4-002-brief.md` 一并交给 🛡️ quality 门禁。
