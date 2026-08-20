# M4-002 驱动脚本修复指令(在线预演全绿 → 再安排离线窗口)

> 由 🛡️ quality(Hermes)独立核查 2026-08-19 晚交付后发出。Cursor 只允许修改驱动脚本与编排脚本;不得触碰源码/pbxproj/台账/brief/证据。修复后先 `SKIP_NETWORK=1` 在线预演跑到全绿,再预约中午离线窗口。

## 1. 任务一句话

修复 `scripts/drive-m4-002-vs0-smoke.py`(及必要时 `scripts/run-m4-002-offline-smoke.sh`),使 `SKIP_NETWORK=1 bash scripts/run-m4-002-offline-smoke.sh` 在线预演**完整跑通**:新游戏 → 收获 3 株 → 投入 → 农耕三步 → 交谈 → 保存 → 完全退出重启读取 → 睡眠 174/894 → 再次读取不重复到账,全程无 DRIVE_FAIL。

## 2. 当前状态(独立核实的失败证据,勿重新猜测)

三次在线预演全部失败,失败点与日志位置(`artifacts/acceptance/m4-002-candidate-macos-20260820T015427Z/macos-arm64/20260820T015500Z/logs/`):

| run | 失败 | 日志 |
|---|---|---|
| r1 | `DRIVE_FAIL: save-before-quit.json missing` | `online-dry-run.log` |
| r2 | `DRIVE_FAIL: seeds x8: missing '雾萝卜种子×8'` | `online-dry-run-r2.log` |
| r3 | `DRIVE_FAIL: pos (5,2) timed out`(HUD 玩家停在 (5,5)) | `online-dry-run-r3.log` |

另有 `offline-smoke-final.log` / `offline-smoke-retry.log` 均含 `WARN: default route still present`(未达 AC-3 断网标准,暂不采信)。`offline-install.log`/`offline-launch.txt` 实为 r3 同 run 产物。

**注意**:此前表述「约 12 秒跑通收获→投入→农耕→交谈」无日志支持,按证据原则不予采信;请不要继续引用该说法。

## 3. 根因候选与修复建议(按优先级)

1. **CGEvent 注入未生效 / 窗口焦点(最可能,对应 r3)**:
   - `activate()` 用 osascript 激活后,**未验证 CreekSprout 是否前台**。建议:激活后用 `CGWindowListCopyWindowInfo` 校验前台窗口 owner 含 CreekSprout;必要时点击窗口中心一次再注入按键(SpriteKit 常见:仅 activate 不接收键盘)。
   - 检测辅助功能权限:若终端/宿主无 Accessibility 权限,CGEventPost 静默失败。建议在脚本开头做一次「注入 w 后读 HUD 位置是否变化」的自检,失败即打印明确诊断(当前 HUD 全文)而非盲等。
2. **HUD 竞态(对应 r2)**:
   - `launch_app()` 的 `wait_hud` 只等「溪票」出现即返回,可能读到旧会话残留快照。建议:等待「溪票 720」+「第 1 天」+「当前目标:收获 3 株成熟雾萝卜」三者齐备才算新游戏;`reset_saves()` 后删除 `hud-latest.txt` 并等待其重新生成;`killall` 后确认进程消失再 `open`。
3. **走位盲等(对应 r3)**:
   - `walk_to_pos` 每步读 HUD 但**不检查位置是否随按键变化**。建议:连续 3 次按键后位置无变化即 raise,异常信息带当前 HUD 全文与已按方向序列;`max_steps` 保持 16 但尽早失败给出诊断。
4. **存读产物缺失(对应 r1)**:
   - `copy_save("save-before-quit.json")` 在「保存成功」后找不到文件。建议:核对游戏实际写档路径(沙盒 `~/Library/Containers/com.fengyifan.CreekSprout/...` 下 `slot_manual_1.json`)与脚本 `SAVE_DIR` 常量是否一致;保存后轮询等待文件出现(带超时)再拷贝。

## 4. 修复边界(红线,Do Not)

- ❌ 只改 `scripts/drive-m4-002-vs0-smoke.py` 与 `scripts/run-m4-002-offline-smoke.sh`;不得改任何源码(`Content/`/`Domain/`/`Persistence/`/`ContentView.swift`/`FarmScene.swift`/测试)、`project.pbxproj`。
- ❌ 不得修改 PRD、TDD、`docs/game/project-ledger.md`、既有 brief/prompt、既有证据文件(含 manifest.md 的 PARTIAL 表述,由 🛡️ quality 在验收后统一更新)。
- ❌ 不自我 APPROVED,不修改任务状态。
- ❌ 不得移除隔离属性/重签名/升级来绕过签名证据要求;`SKIP_NETWORK=1` 预演日志必须保留 `not valid for AC-3` 标注。
- ❌ 不 `git commit`、不删除工作区未提交内容。

## 5. 验收标准(全绿定义)

`SKIP_NETWORK=1 bash scripts/run-m4-002-offline-smoke.sh` 输出含以下全部证据(截图/HUD 转储/存档 JSON 各就位):
- 新游戏 HUD 断言通过(720 / 16 格 / 种子×8 / 教学目标)
- 收获 3 株 → 背包雾萝卜×3;投入 → 待结算 3
- 农耕三步(翻土/播种/浇水)HUD 就位;交谈完成
- 保存成功 → `save-before-quit.json` 存在
- 完全退出 → 重启 → 读取成功 → 状态一致(`reload-consistency.json` 无意外差异)
- 睡眠结算 174 / 余额 894;再次读取重试不重复到账
- 结束无 `DRIVE_FAIL` / `RuntimeError`

## 6. 交付格式

1. 修复后的两个脚本路径 + 变更点清单(每处一句:现象 → 修复)。
2. 全绿预演日志(新 run,如 `logs/online-dry-run-r4.log`)+ 全部 HUD 转储/截图/存档样本,放回同一证据目录(新 run-id 或追加到 20260820T015500Z,二选一并在 handoff 声明)。
3. `git diff --check` exit 0;声明未修改文件清单。
4. 待办:中午离线窗口执行 `bash scripts/run-m4-002-offline-smoke.sh`(不带 SKIP_NETWORK),完成后由 🛡️ quality 独立复核并统一更新 manifest/台账。

## 7. 回复格式(必须逐项确认,缺项视为未完成)

```
A. 修复点确认：4 类根因逐条「修复 / 未修复 / 不需要」+ 每处实现方式一句话。
B. 全绿证据：r4 日志路径 + 各步骤 PASS 计数 + 174/894 与存读一致性确认。
C. 红线声明：未动源码/pbxproj/台账/brief/证据；未移除隔离属性/重签名。
D. 离线窗口就绪声明：脚本可直接 `bash scripts/run-m4-002-offline-smoke.sh`（不带 SKIP_NETWORK）执行。
E. 下一负责人：🛡️ quality（Hermes）复核全绿证据并安排离线验收。
```
