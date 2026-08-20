# M4-002 最终离线验收前脚本加固 Prompt（Cursor / VS Code Agent）

> 本 Prompt 由 Product Owner 要求、🛡️ quality（Hermes）基于现有脚本与证据独立复核后整理。
>
> **本轮任务只加固离线验收夹具并完成无断网的静态/预检验证。不得执行最终离线烟雾。** 只有 Product Owner 后续明确说出「可以断网了」，才允许另行执行真实断网阶段。

## 0. Studio 任务路由

- **Task ID:** M4-002
- **Department:** 🛡️ Quality & Delivery / 📦 Build & Release
- **Specialist owner:** 📦 `release`（Cursor / VS Code Agent）
- **Department quality owner:** 🛡️ `quality`
- **Downstream reviewer:** 🛡️ `quality`（Hermes，跨部门独立复核）
- **当前门禁:** `PENDING`
- **禁止自我批准:** 你不得返回 `APPROVED`，不得修改任务状态或项目台账。

## 1. 任务一句话

加固 `scripts/run-m4-002-offline-smoke.sh` 与 `scripts/drive-m4-002-vs0-smoke.py`，解决以下四类正式离线验收风险：

1. 最终离线运行必须使用新的 run-id，不能覆盖 r7 在线预演证据；
2. 未真正断开所有可路由网络时必须 fail-closed，不能只警告后继续；
3. 成功、失败或中断时都必须恢复到运行前的网络状态；
4. 清空测试槽前必须备份现有 CreekSprout 存档，并在成功、失败或中断后恢复原状态。

本轮完成代码加固、静态检查和 `PREFLIGHT_ONLY=1` 无副作用预检后停止，等待 🛡️ quality 复核。**不要关闭 Wi-Fi，不要启动 GUI 自动化，不要执行最终离线安装/烟雾。**

## 2. 当前状态（以下事实已由 🛡️ quality 独立核实，不得重新猜测）

### 2.1 已完成且有效的证据

- 候选构建 ID：`m4-002-candidate-macos-20260820T015427Z`
- 历史在线预演 run-id：`20260820T015500Z`
- 候选 zip：
  `artifacts/acceptance/m4-002-candidate-macos-20260820T015427Z/macos-arm64/20260820T015500Z/build/CreekSprout-m4-002-macos-arm64.zip`
- 候选 zip SHA-256：
  `dd05b103021c0c1d448970bb57751163dcb3afb349c513e761535acf323a93da`
- 可执行文件 SHA-256：
  `2de4e15912dc0e80c13f384f1d6f2f601357b9b4351428cbe495ecf8997e4159`
- Release 构建已成功，0 编译 warning/error；`codesign --verify` 通过；`spctl` 对 adhoc 包返回 rejected，属于预期策略结果，已如实记录。
- 权威在线预演日志：
  `artifacts/acceptance/m4-002-candidate-macos-20260820T015427Z/macos-arm64/20260820T015500Z/logs/online-dry-run-r7.log`
- r7 包含 `not valid for AC-3`、`ax_trusted=True`、窗口焦点/键盘自检、完整 VS-0、174/894、存读一致和末行 `DRIVE_OK`。
- r7 是驱动稳定性证据，**不能替代 AC-3～8 的正式离线证据**。
- 当前 `manifest.md` 仍为 `PARTIAL / PENDING`；M4-002 总门禁仍为 `PENDING`。

### 2.2 已核实的四个脚本风险

#### 风险 A：固定 run-id 会覆盖历史证据

当前 `scripts/run-m4-002-offline-smoke.sh`：

- 第 6～9 行把 `RUN_ID` 默认固定为 `20260820T015500Z`；
- zip 来源又绑定到本次 `EVIDENCE/build/`；
- 改天直接运行会覆盖 r7 的 HUD、截图、存档和离线日志，且目录时间与实际测试日期不一致。

#### 风险 B：断网检查不是硬门禁

当前脚本在发现默认路由后只输出：

`WARN: default route still present; recording honestly`

随后仍继续安装和烟雾。

历史 `offline/network-disabled.txt` 已证明：Wi-Fi 虽为 Off，但仍存在：

- `utun4` 的分段 IPv4 路由；
- `utun0`～`utun3` 的 IPv6 default 路由。

因此「Wi-Fi Off」不能单独证明 AC-3。正式离线运行前必须识别有线网络、VPN、代理/Network Extension 隧道及其他可路由接口；若仍有有效网络路径，必须停止测试。

#### 风险 C：异常时可能无法恢复 Wi-Fi

当前脚本只在正常执行到末尾时调用：

`networksetup -setairportpower "$WIFI_IF" on`

安装阶段处于 `set -e`。zip 缺失、`ditto` 失败、脚本异常或收到 SIGINT/SIGTERM 时，可能在恢复网络前退出。

#### 风险 D：驱动会删除现有存档但没有自动备份/恢复

`drive-m4-002-vs0-smoke.py` 的 `reset_saves()` 会删除沙盒与非沙盒候选目录中的：

- `slot_manual_1/2/3`；
- `slot_auto`；
- legacy `slot_0`；
- 相关 `.json`、`.backup`、`.tmp`；
- `hud-latest.txt` / `hud-compact-latest.txt`。

当前正式执行路径在 `reset_saves()` 前没有可靠的自动备份与失败恢复。

## 3. 本轮允许的工作阶段

### Phase A：立即执行——代码加固与无副作用验证

允许：

1. 阅读现有 brief、脚本和历史证据；
2. 修改两个允许文件；
3. 增加 `PREFLIGHT_ONLY=1` 无副作用预检模式；
4. 运行 shell/Python 语法检查；
5. 运行 `PREFLIGHT_ONLY=1`；
6. 运行 `git diff --check`；
7. 提交交接报告给 🛡️ quality。

### Phase B：本轮禁止——GUI 在线预演

即使设置 `SKIP_NETWORK=1`，完整驱动仍会启动 CreekSprout、抢占窗口焦点并注入键盘。**本轮不得自行执行。**

只有 Product Owner 另行明确允许 GUI 自动化后，才可运行在线预演。

### Phase C：本轮绝对禁止——真实断网验收

以下操作全部留待 Product Owner 后续明确说「可以断网了」：

- 关闭 Wi-Fi；
- 禁用有线网络或 VPN/代理隧道；
- 从 zip 执行正式离线安装；
- 离线启动 CreekSprout；
- 离线运行完整 VS-0；
- 把 M4-002 标记为完成或 APPROVED。

## 4. 文件边界

### 允许修改

- `scripts/run-m4-002-offline-smoke.sh`
- `scripts/drive-m4-002-vs0-smoke.py`

如确有必要，可在 `scripts/` 新增**一个最小、专用于上述两脚本的测试/辅助文件**，但必须先在交接中说明为什么无法在两个现有脚本内安全完成。不得新增通用框架。

### 允许新建的非最终证据

- 新的 preflight 报告；
- 新 run-id 下的 `manifest.md` 骨架或预检日志；
- 必须明确标记：`PREFLIGHT_ONLY / network unchanged / not valid for AC-3`。

### 严禁修改或覆盖

- `Content/`、`Domain/`、`Persistence/`；
- `ContentView.swift`、`FarmScene.swift`；
- 所有测试源码；
- `CreekSprout.xcodeproj/project.pbxproj`；
- PRD、TDD、`docs/game/project-ledger.md`；
- `docs/game/m4-002-brief.md`；
- 既有 prompt；
- 既有 `20260820T015500Z` 证据目录中的任何文件；
- 既有 r6/r7 日志、HUD、截图、存档、manifest 和 handoff。

## 5. 必须实现的脚本加固

### 5.1 新 run-id 与候选包来源解耦

实现时必须满足以下行为：

1. 把「候选包来源」与「本次运行证据目录」拆开：
   - 推荐环境变量：`SOURCE_RUN_ID`、`SOURCE_EVIDENCE` 或 `SOURCE_ZIP`；
   - `SOURCE_ZIP` 默认可指向已核实的历史候选 zip；
   - `RUN_ID` 只代表本次测试，不再代表候选包来源。
2. 未显式传 `RUN_ID` 时，默认用当前 UTC 生成新的 run-id，例如：
   `YYYYMMDDTHHMMSSZ`。
3. 新 run 目录必须是新的、空的目录；若目标目录已存在且非空，默认非 0 退出，不得静默覆盖。
4. 从不可变来源读取候选 zip，并在新 run 中记录或复制：
   - zip；
   - `build/identity.txt`；
   - 候选 zip SHA-256；
   - 可执行 SHA-256；
   - 原始候选 build-id / source run-id。
5. 在安装前重新计算 zip SHA-256，并严格比对：
   `dd05b103021c0c1d448970bb57751163dcb3afb349c513e761535acf323a93da`
6. 哈希不一致时立即失败；不得继续安装。
7. 不得修改、移动或删除来源证据目录。

### 5.2 `PREFLIGHT_ONLY=1` 无副作用模式

新增并实现：

```bash
PREFLIGHT_ONLY=1 bash scripts/run-m4-002-offline-smoke.sh
```

该模式必须：

- 只读核对候选 zip、哈希、来源 identity、目标 run-id 与目标路径；
- 显示检测到的 Wi-Fi 硬件端口、当前 Wi-Fi 状态、物理网络接口、VPN/utun/路由摘要；
- 检查 Python 驱动、`networksetup`、`netstat`、`route`、`ditto`、`shasum` 等依赖是否存在；
- 检查沙盒与非沙盒存档目录是否存在，并输出「将备份的文件数/路径」，但不得复制、删除或改写存档；
- 检查 `/Applications/CreekSprout.app` 是否已存在，并记录现状，但不得删除或覆盖；
- 不关闭 Wi-Fi；
- 不改 VPN/有线网络；
- 不安装 app；
- 不启动 CreekSprout；
- 不注入键盘；
- 不调用 `reset_saves()`；
- 不修改旧证据；
- 输出明确标记：`PREFLIGHT_ONLY_OK` 或 `PREFLIGHT_ONLY_FAIL`；
- 输出明确免责声明：`network unchanged; not valid for AC-3`。

### 5.3 断网必须 fail-closed

正式模式（无 `SKIP_NETWORK`、无 `PREFLIGHT_ONLY`）必须：

1. 自动识别 Wi-Fi 硬件端口；保留 `WIFI_IF` 覆盖能力，但不得盲目假定所有机器都是 `en0`。
2. 关闭前记录：
   - `networksetup -getairportpower`；
   - `networksetup -listallhardwareports`；
   - `networksetup -listallnetworkservices`；
   - `scutil --nwi`；
   - `ifconfig`；
   - IPv4/IPv6 路由表；
   - 默认路由查询结果。
3. 关闭 Wi-Fi 后重新采样上述证据。
4. 检测以下阻断条件：
   - Wi-Fi 仍为 On；
   - 活跃有线接口仍有可路由地址；
   - VPN/代理/Network Extension 的 `utun*` 仍存在默认路由或覆盖互联网地址空间的分段路由；
   - IPv4 或 IPv6 仍有实际可用默认路径；
   - 有效联网探针仍成功。
5. 网络探针必须有严格短超时，并记录原始输出。至少同时包含：
   - 一个 DNS/HTTPS 探针；
   - 一个不依赖 DNS 的 IP/TCP 探针。
6. 离线通过条件：上述联网探针均失败，且没有仍可用的物理/VPN 路径。
7. 任一阻断条件成立时：
   - 输出 `NETWORK_ISOLATION_FAIL`；
   - 保存完整网络证据；
   - 不执行安装；
   - 不启动游戏；
   - 恢复原网络状态；
   - 非 0 退出。
8. 不得只打印 WARN 后继续。
9. 不得自动退出、杀死或重配置未知 VPN/代理应用；只能明确列出阻断接口/路由，并要求 Product Owner 手动处理后重试。

### 5.4 网络恢复 trap

实现幂等清理函数，并覆盖正常、失败和中断路径：

1. 运行前记录 Wi-Fi 原始状态：On 或 Off。
2. 只恢复脚本实际改变过的状态：
   - 原来 On、脚本关掉 → 结束时恢复 On；
   - 原来 Off → 结束时保持 Off，不得擅自打开。
3. 对 `EXIT`、`INT`、`TERM` 安装 trap。
4. trap 必须：
   - 保留原始退出码；
   - 尝试退出 CreekSprout；
   - 恢复网络原始状态；
   - 生成 `offline/network-restored.txt`；
   - 明确打印恢复成功或失败；
   - 幂等，重复调用不会破坏状态。
5. `OFFLINE_SMOKE_OK` 只能在：
   - 驱动 exit 0；
   - 证据齐备；
   - 网络恢复成功之后输出。
6. 若恢复失败，最终必须非 0 退出，并给出人工恢复命令。

### 5.5 存档备份与恢复

正式烟雾会清空测试槽，因此必须实现原状态保护：

1. 在调用 `reset_saves()` 前处理两个候选目录：
   - `~/Library/Containers/com.fengyifan.CreekSprout/Data/Library/Application Support/CreekSprout/`
   - `~/Library/Application Support/CreekSprout/`
2. 将运行前状态备份到本次新证据目录，例如：
   `saves/pre-drive-backup/`。
3. 备份必须保留：
   - 目录来源；
   - 文件相对路径；
   - 文件大小；
   - SHA-256；
   - 备份时间；
   - 原目录不存在或为空的事实。
4. 备份失败时不得调用 `reset_saves()`。
5. 正式烟雾产生的测试存档必须先复制进证据目录，再恢复玩家原始存档。
6. 成功、驱动失败、Python 异常、SIGINT、SIGTERM 时都要尝试恢复原存档状态。
7. 若原目录运行前不存在，恢复时应回到「不存在」；若运行前为空，应回到「为空」。
8. 恢复后重新计算关键文件 SHA-256，与备份清单比对；不一致时输出 `SAVE_RESTORE_FAIL` 并非 0 退出。
9. 不得把测试生成的槽文件混入玩家原存档。
10. 不得删除 `settings.json`、性能导出或其他不属于本烟雾重置范围的用户文件。

### 5.6 已安装 App 的保护

当前脚本直接执行：

`rm -rf /Applications/CreekSprout.app`

加固后必须：

1. 安装前检查该路径是否存在；
2. 记录已安装版本和可执行 SHA-256；
3. 若与候选包相同，可如实记录后重装；
4. 若不同，不得直接不可逆删除；应先建立可恢复备份，或停止并要求 Product Owner 决定；
5. 无论采用哪种策略，都必须在 handoff 中说明。

## 6. 正式离线运行的锁定分支（本轮只实现，不执行）

后续获得 Product Owner 明确授权后，正式流程必须按以下顺序运行：

1. 创建全新 run-id，核对来源候选 zip 与 SHA-256；
2. 备份现有存档和既有 `/Applications/CreekSprout.app` 状态；
3. 记录 `network-before`；
4. 关闭 Wi-Fi；由 Product Owner 手动关闭被识别出的有线/VPN/代理路径；
5. 运行断网硬门禁；不满足则停止；
6. 从本地 zip 安装到 `/Applications/CreekSprout.app`；
7. 离线启动，验证第 1 天、720 溪票、背包 1/16、种子×8；
8. 验证窗口焦点、Accessibility 和键盘移动；
9. 收获 3 株 → 背包雾萝卜×3；
10. 投入出售箱 → 待结算 3；
11. 翻土 → 播种 → 浇水；
12. 与水工学徒交谈；
13. 保存 → 完全退出 → 重启 → 读取；
14. `reload-consistency.json` 必须为 `mismatches: []`；
15. 首次睡眠：结算 174、余额 894；
16. 读档后再次睡眠：余额仍 894、结算历史合计仍 174；
17. 复制最终 HUD、截图、日志和测试存档到新 run 证据目录；
18. 恢复原存档、原 App 状态和原网络状态；
19. 生成 `network-restored.txt`；
20. 由 🛡️ quality 独立复核，Cursor 不得自我 APPROVED。

## 7. 本轮加固验收条件

本轮不是 M4-002 最终验收；本轮只判断脚本是否安全进入未来离线窗口。

必须全部满足：

- **H-1** 新 run-id 与来源 zip 已解耦，默认不覆盖已有目录；
- **H-2** 来源候选 zip SHA-256 会在安装前强校验；
- **H-3** `PREFLIGHT_ONLY=1` 无网络、安装、GUI、存档副作用；
- **H-4** 网络隔离不成立时硬失败，不继续安装；
- **H-5** 能识别并报告物理接口、IPv4/IPv6、VPN/utun 和联网探针结果；
- **H-6** EXIT/INT/TERM 均有网络恢复 trap，恢复原始状态而不是无条件开 Wi-Fi；
- **H-7** 存档在 reset 前备份，成功/失败/中断后恢复并校验；
- **H-8** 已安装 App 不再被无保护地不可逆删除；
- **H-9** r7 和 `20260820T015500Z` 旧证据零改动；
- **H-10** 无源码、pbxproj、台账、brief、既有 prompt 越界修改；
- **H-11** shell/Python 静态检查通过；
- **H-12** `git diff --check` exit 0；
- **H-13** 本轮没有关闭 Wi-Fi、没有运行 GUI 自动化、没有执行最终离线烟雾；
- **H-14** 门禁仍为 `PENDING`，下一负责人为 🛡️ quality。

## 8. 本轮必须执行的验证（不得执行更多）

按顺序执行并保留原始输出：

1. Shell 语法：

   ```bash
   bash -n scripts/run-m4-002-offline-smoke.sh
   ```

2. Python 纯语法编译（不要留下 `__pycache__`）：

   ```bash
   python3 - <<'PY'
   from pathlib import Path
   path = Path('scripts/drive-m4-002-vs0-smoke.py')
   compile(path.read_text(encoding='utf-8'), str(path), 'exec')
   print('PYTHON_SYNTAX_OK')
   PY
   ```

3. 无副作用预检：

   ```bash
   PREFLIGHT_ONLY=1 bash scripts/run-m4-002-offline-smoke.sh
   ```

   必须确认输出包含：

   - `PREFLIGHT_ONLY_OK`；
   - `network unchanged; not valid for AC-3`；
   - 来源 zip 与预期 SHA-256 一致；
   - 新 run 目标不会覆盖 `20260820T015500Z`；
   - 存档只列出、未删除；
   - App 只检查、未覆盖；
   - Wi-Fi 状态前后不变；
   - CreekSprout 未启动。

4. 边界检查：

   ```bash
   git diff --check
   git status --short
   ```

5. 对旧证据目录生成修改前后文件清单/mtime 或哈希核对，证明：

   `artifacts/acceptance/m4-002-candidate-macos-20260820T015427Z/macos-arm64/20260820T015500Z/`

   在本轮零改动。

## 9. 红线（Do Not）

- ❌ 本轮不得运行无 `SKIP_NETWORK` 的正式脚本；
- ❌ 本轮不得关闭 Wi-Fi、修改 VPN、有线网络或网络服务；
- ❌ 本轮不得启动 CreekSprout 或注入键盘；
- ❌ 未获 Product Owner 单独授权，不得运行完整 `SKIP_NETWORK=1` GUI 预演；
- ❌ 不得改游戏源码、测试、pbxproj；
- ❌ 不得改 PRD、TDD、台账、brief、既有 prompt；
- ❌ 不得覆盖、重命名、移动或删除 r7 和旧 run 证据；
- ❌ 不得移除隔离属性（`xattr -cr`）、重签名、升级版本或伪造 `spctl` 结果；
- ❌ 不得自动关闭未知 VPN/代理应用；检测到时应报告并停止；
- ❌ 不得 `git commit`、`git reset`、`git clean` 或删除工作区既有修改；
- ❌ 不得自我 `APPROVED`，不得修改 M4-002 状态；
- ❌ 不得把 preflight 或在线预演称为 AC-3 离线证据。

## 10. 交付物

1. 修改后的脚本路径；
2. 每个修改点的「风险 → 实现 → 失败行为」说明；
3. H-1～H-14 验收映射表；
4. `bash -n` 原始结果；
5. `PYTHON_SYNTAX_OK` 原始结果；
6. `PREFLIGHT_ONLY=1` 原始日志路径与摘要；
7. 旧 `20260820T015500Z` 证据零改动证明；
8. `git diff --check` exit 0；
9. `git status --short` 中本轮新增/修改文件归属说明；
10. 正式离线运行命令模板，但不得执行；
11. 已知限制、未解决项与下一负责人。

## 11. 强制回复格式（必须逐项回答，缺项视为未完成）

```text
A. 范围确认
- Phase A：确认 / 不确认
- 本轮不执行 Phase B、Phase C：确认 / 不确认
- 红线逐条确认；任一不确认项说明原因

B. 独立核实结果
- 候选 zip 路径与 SHA-256
- r7 路径与 DRIVE_OK
- 当前四类风险是否复现/确认

C. 修改清单
- 每个文件：路径
- 每处修改：风险 → 实现 → 失败行为
- 是否新增辅助文件；如有，说明必要性

D. 加固验收映射
- H-1～H-14：逐条 PASS / FAIL
- 每条对应代码位置与证据路径

E. 验证原始结果
- bash -n：退出码与输出
- Python syntax：退出码与输出
- PREFLIGHT_ONLY：退出码、日志路径、关键标记
- git diff --check：退出码
- git status --short：本轮文件归属

F. 零副作用证明
- Wi-Fi 前后状态一致
- 未改变 VPN/有线网络
- CreekSprout 未启动
- 存档未删除/改写
- /Applications/CreekSprout.app 未删除/覆盖
- 旧 20260820T015500Z 证据零改动

G. 正式离线命令模板（只展示，不执行）
- 新 RUN_ID 生成方式
- SOURCE_ZIP / SOURCE_EVIDENCE 来源
- 正式命令
- 网络隔离失败、驱动失败、恢复失败时各自行为

H. 门禁与下一负责人
- 本轮不得写 APPROVED
- M4-002 保持 PENDING
- 请求 🛡️ quality（Hermes）独立复核脚本加固
- 等待 Product Owner 后续明确说「可以断网了」
```

## 12. 停止条件

出现以下任一情况，立即停止并返回 `BLOCKED` 或明确的未完成项，不得绕过：

- 无法在不覆盖旧证据的情况下建立新 run；
- 无法可靠恢复原网络状态；
- 无法在 reset 前备份并在异常后恢复存档；
- 需要修改游戏源码、pbxproj、台账或 brief 才能继续；
- `PREFLIGHT_ONLY=1` 产生了任何网络、GUI、安装或存档副作用；
- 发现候选 zip SHA-256 与权威值不一致；
- 发现其他进程正在修改目标脚本或旧证据目录。

完成 Phase A 后停止，按第 11 节 A～H 回复，等待 🛡️ quality 与 Product Owner 的下一步指令。
