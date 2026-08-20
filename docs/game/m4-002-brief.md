# Studio task: M4-002 生成 macOS arm64 候选包并执行回归与离线烟雾

**Status:** planned / PENDING → 开工后登记 active / PENDING（DEC-015 精简合同）
**Role contract:** 专项负责人 📦 release；部门质量负责人 🛡️ quality；实现负责人 Cursor / 📦 release；最终独立验收 Hermes / 🛡️ quality（按 DEC-015 仅保留一次部门门禁 + 一次独立质量门禁）
**合同依据:** `platform-acceptance-plan.md`（M4 发布候选完整夹具：安装、离线启动、输入、保存读取、VS-0 烟雾；证据根 `artifacts/acceptance/<candidate-build-id>/macos-arm64/<run-id>/`）、DEC-012（仅 macOS arm64 发行与验收范围）

## 1. 玩家结果

玩家获得一个可离线交付的 macOS arm64 候选包（Release 构建 + 本地安装包）。在参考设备（M4 MacBook Air / 16 GB / macOS 26.5.2）上**断开所有可路由网络**后，从本地安装包完成安装、启动游戏、创建新游戏、键鼠输入、保存/读取与 VS-0 烟雾路径全部可用；每步有截图/HUD/存档 JSON 证据，构建身份与 SHA-256 可追溯。候选包可被后续 A0-001 验收直接使用。

## 2. 实现边界

### In scope

1. **Release 构建**：`xcodebuild -configuration Release -destination 'platform=macOS,arch=arm64'` 构建 CreekSprout.app，0 编译警告/错误；记录构建身份（Xcode 版本、构建时间、产物路径）与产物 SHA-256。
2. **本地安装包制作**：将 Release 产物打包为可分发的本地安装形式（zip 或 dmg，实现者选定并在交付中说明理由）；签名保持 Xcode 默认（adhoc），**如实记录** `codesign --verify` 与 `spctl --assess` 结果，不伪造「公证通过」。
3. **离线安装与启动**：断开所有可路由网络接口（Wi-Fi 及有线，记录 `networksetup`/`route` 证据）后，从本地安装包安装（安装方式如实记录，如解压至 /Applications），启动游戏进入新游戏界面。
4. **输入、存读与 VS-0 烟雾**：键鼠移动/交互/背包/保存键可用；保存→完全退出→重启→读取状态一致；VS-0 主路径回归：新游戏→收获 3 株→投入→174 结算（余额 894）→农耕三步→交谈→保存→重启读取→睡眠结算不重复到账。
5. **证据包**：按 `platform-acceptance-plan.md` 生成 `artifacts/acceptance/<candidate-build-id>/macos-arm64/<run-id>/`：`manifest.md`（候选构建版本、构建 ID、SHA-256、测试日期/时区、测试人员、测试平台、网络状态）+ 截图/HUD 转储/存档 JSON 样本/安装与启动日志。
6. **回归基线引用**：不重复 clean test（DEC-015）；以 M4-001 权威 228/0/0（`artifacts/integration/m4-001-xcode/TestResults-M4-001-revise.xcresult`）为单元回归基线，候选包阶段以运行烟雾为决定性回归证据。

### Out of scope（红线，禁止实现）

- ❌ 不新增/修改玩法、内容、经济、UI 或领域逻辑；不改 `ContentID.swift`、`ContentValidator.swift` 稳定 ID 与校验规则。
- ❌ 不修改 PRD、TDD、`docs/game/project-ledger.md`、既有 brief/prompt、既有证据文件。
- ❌ 不自我 `APPROVED`，不修改任务状态。
- ❌ 不做 Apple Developer ID 签名/公证/App Store 上架（如 PO 后续需要，另立任务）。
- ❌ 不通过移除隔离属性（`xattr -cr`）、临时重签名或版本升级来掩盖或伪造安装/签名证据（延续 RSK-004 红线精神：`spctl` 结果如实记录，adhoc 开发包被 `rejected` 属预期并如实声明）。
- ❌ 不 `git commit`、不 `git reset`、不删除工作区未提交内容。
- ❌ 不复制任何受保护的任务、地图、对白、视觉或音频表达。

## 3. 文件边界

| 工具 | 可修改 | 不得触碰 |
|---|---|---|
| Cursor（📦 release 实现） | `macos/CreekSprout/CreekSprout.xcodeproj/project.pbxproj` **仅限候选包构建所需的最小签名/打包配置**（如 CODE_SIGN_IDENTITY/打包脚本引用，须逐处声明理由）；`scripts/` 新增候选包构建/打包脚本（如 `build-m4-002-candidate.sh`） | 源码 `Content/`、`Domain/`、`Persistence/`、`ContentView.swift`、`FarmScene.swift`、测试；`docs/game/project-ledger.md`、PRD/TDD、既有 brief/prompt/证据 |
| Hermes | 只读独立验收（构建取证、离线烟雾复核、证据包核对、AC 判定） | 源码、工程配置、台账状态修改、自行批准 |

## 4. 可观察验收条件（10 条）

- **AC-1 Release 构建**：Release/arm64 构建成功，0 编译警告/错误；产物 CreekSprout.app 存在，构建身份与 SHA-256 已记录。
- **AC-2 本地安装包**：候选包（zip/dmg）生成成功，可从本地解压/挂载安装；安装方式与 spctl/codesign 结果如实记录（adhoc 被 rejected 属预期，不伪造）。
- **AC-3 离线证据**：烟雾全程断网，`manifest.md` 记录网络状态（Wi-Fi 关闭/路由表无可路由接口）。
- **AC-4 离线安装**：断网状态下从本地安装包完成安装（如实记录安装路径与方式）。
- **AC-5 离线启动**：断网启动候选包，进入新游戏界面，无网络依赖报错。
- **AC-6 输入**：键鼠移动/交互/背包/保存键在候选包中可用（截图/HUD 转储）。
- **AC-7 存读**：保存→完全退出→重启→读取，游戏状态与保存时一致（存档 JSON 对比）。
- **AC-8 VS-0 回归**：新游戏→收获 3 株→投入→174 结算（余额 894）→农耕三步→交谈→保存→重启读取→睡眠结算不重复到账（回归 M2/M4 已验收行为）。
- **AC-9 证据包**：`artifacts/acceptance/<candidate-build-id>/macos-arm64/<run-id>/` 含 manifest.md（字段完整）+ 截图/日志/存档样本；候选构建版本与 SHA-256 可追溯。
- **AC-10 边界与原创性**：无源码越界改动（仅声明的最小 pbxproj/脚本）；`git diff --check` exit 0；候选包内容全部来自已验收的原创实现，无受保护表达。

## 5. 一条完整烟雾路径（锁定路径，逐项取证）

| # | 操作 | 预期证据 |
|---|---|---|
| 1 | Release 构建 + 产物 SHA-256 记录 | 构建日志、`shasum -a 256` 输出 |
| 2 | 制作本地安装包（zip/dmg） | 安装包文件 + `codesign --verify` / `spctl --assess` 原始输出 |
| 3 | 断开所有可路由网络（Wi-Fi 关闭） | `networksetup -getairportpower en0` 为 Off / 路由表无默认路由 |
| 4 | 从本地安装包安装 | 安装日志/路径记录（如 `/Applications/CreekSprout.app`） |
| 5 | 启动候选包，新游戏 | 启动日志 + 截图：第 1 天 06:30、余额 720、背包 16 格、种子×8 |
| 6 | 键鼠移动至 (4,1)/(5,1)/(6,1) 收获 3 株 | 截图/HUD：背包雾萝卜×3 |
| 7 | 投入出售箱 | HUD：待结算 3 |
| 8 | 睡眠结算 | HUD/存档：174 溪票、余额 894；再读档重试不重复到账 |
| 9 | 保存 → 完全退出 → 重启 → 读取 | 存档 JSON 前后一致（diff 无意外差异） |
| 10 | 恢复网络，汇总证据包 | `manifest.md` + 全部截图/日志/JSON 落盘于验收证据目录 |

## 6. Cursor 交付格式（DEC-015 单轮精简交接）

1. **变更文件清单**：新增/修改文件路径（预期仅 `scripts/` 脚本与声明的最小 pbxproj），逐处声明理由。
2. **候选包产物**：安装包路径 + Release 构建原始日志（退出码、0 警告）+ 产物 SHA-256。
3. **离线烟雾证据**：第 5 节每步截图或 HUD 文本 + 存档 JSON 样本 + `manifest.md`。
4. **`git diff --check` 退出 0** 输出；声明未修改文件清单（源码/PRD/TDD/台账/brief/证据）。
5. **决策与假设**：安装包形式选择（zip/dmg）、安装路径、签名结果如实记录（含 spctl rejected 的预期声明）。
6. **风险与遗留**：已知安装/分发限制（如无公证需右键打开）、非阻断项。
7. **红线确认**：声明未改源码语义、未移除隔离属性/重签名/升级、未触碰台账与文档。

**不要求**：重复 clean test、长报告、冗余截图、非阻断打磨。

## 7. Hermes 验收格式（🛡️ Quality 独立门禁）

1. **构建取证复核**：独立运行/复核 Release 构建与候选包制作命令，核对产物 SHA-256 与交付一致；0 警告。
2. **独立离线烟雾**：断网状态下独立安装→启动→新游戏→输入→存读→VS-0 路径（新游戏→174/894→重启读取一致）；逐步截图或 HUD 文本 + 存档 JSON 取证；全程断网证据。
3. **逐条 AC-1~10 判定**：PASS/FAIL + 证据引用（精简表）。
4. **边界与回归核对**：文件边界（basename 比较工作区变更 vs 交付清单）、`git diff --check`、spctl/codesign 结果如实性、既有 228/0/0 基线引用正确性。
5. **门禁结论**：返回 `APPROVED | REVISE | BLOCKED`；通过后由 🎬 director 依 📦 release + 🛡️ quality 门禁将 M4-002 登记为 `accepted / APPROVED`，G4「发行候选与性能达标」退出门禁达成。

---

## Gate status（合同阶段）

- **审查人角色 A**：🧱 tech（Engineering & Pipeline Lead）——技术可行性审查（跨部门，独立于 📦 release 专项与 🛡️ quality 质量门禁）
- **审查要点 A**：打包流程可执行（zip/dmg 均可行，adhoc 签名如实记录不阻塞）；离线验证方法可操作（`networksetup` 断网 + 路由表证据）；证据包字段与 `platform-acceptance-plan.md` 一致；不重复 clean test 符合 DEC-015。
- **审查结论 A：APPROVED**（无技术阻断；候选包构建/离线烟雾路径在 RSK-004 关闭后工具链齐备）
- **审查人角色 B**：🌱 design（Design & Player Experience Lead）——规则复核（跨部门）
- **审查要点 B**：玩家路径完整（安装→启动→新游戏→输入→存读→VS-0 闭环）；无障碍/UX 不回归（引用 M4-001/D0-002 已验收行为，本任务不触碰）；原创性边界（候选包内容全部来自已验收原创实现）；安装体验如实声明（无公证需右键打开的已知限制写入交付）。
- **审查结论 B：APPROVED**（无规则问题）
- **下一负责人：📦 release 专项实现 / Cursor**（随后经 🛡️ quality 独立验收）
