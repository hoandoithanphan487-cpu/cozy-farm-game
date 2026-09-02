# N-015 VSCode 基础包技术审查

- 审查日期：2026-08-23
- 工作包：`N-015-VSCODE-FDN-01`
- 专项负责人：VSCode / 🛠️ tools
- 部门质量负责人：🧱 tech
- 交叉复核：🛡️ quality（顺序执行，避免自我批准）
- 当前门禁结论：`APPROVED`（r4；以下 R1–R4 保留为历史审查记录）

## 已确认通过的部分

1. 交付文件均位于 DEC-034 允许边界内；未发现 VSCode 修改生产 Swift、正式 Assets、既有测试、Xcode 工程或项目台账。
2. 当前消费者矩阵覆盖 132/132 个正式 PNG；当前验证运行结果为 `PASS`，来源计数为 `119 / 12 / 1`，运行时状态为 `integrated=53 / blocked=30 / planned=49`。
3. 独立复跑新增契约测试为 10/10 通过；已有完整 xcresult 显示 284/284 通过、0 失败、0 跳过。
4. `git diff --check` 通过；当前矩阵中的文件集合、PNG 尺寸、哈希和已接入引用与现有审计结果一致。

以上结论仅证明“当前生成出的矩阵数据看起来一致”，尚不足以证明验证器能够拦截错误消费者契约。

## 阻断接收的问题

### R1 — 验证器会放过逐文件来源和消费者被篡改

独立负向测试在 `/private/tmp/n015-matrix-mutated.json` 中同时做了两项修改：

- 交换 `building_farm_house_base.png` 与 `char_creek_warden.png` 的 `provenance`，保持 `119 / 12 / 1` 汇总计数不变；
- 将 `char_creek_warden_walk.png` 的 `planned_consumer` 改为 `DefinitelyNotARealConsumer`。

运行：

```text
python3 scripts/validate-n015-consumer-matrix.py --matrix /private/tmp/n015-matrix-mutated.json
```

实际仍返回 `PASS`、`failures=0`、退出码 0。原因是验证器只核对来源汇总计数，以及消费者字段是否非空/枚举是否合法，没有从 manifest 和消费者合同推导并逐文件核对期望值。这使“132 项消费者矩阵与批准来源、消费者契约一致”的核心验收目标无法被证明。

### R2 — 矩阵再生成依赖被 Git 忽略的脚本

交接文档要求后续在已解析引用变化后运行：

```text
artifacts/integration/n-015-vscode-foundation/generate-matrix.py
```

但 `artifacts/` 受 `.gitignore` 规则忽略。该生成器不是可持续的仓库基础设施；Codex 在 B2–B5 增加真实消费者后，追踪中的矩阵会立即产生漂移，而追踪中的验证器没有刷新/写入矩阵的模式。

## 必须返工的验收条件

1. 在已获准的追踪脚本 `scripts/validate-n015-consumer-matrix.py` 中加入确定性矩阵生成/刷新模式，例如 `--refresh-matrix`；交接流程不得依赖被忽略的生成器。
2. 从 N-003/N-006 manifests 与新增木蜜灶台记录推导每个文件的期望 `provenance`，逐行严格比较，不能只比较汇总计数。
3. 将分类、批次、触发状态、fallback 和 `planned_consumer` 的逐文件/逐族规则固化到追踪代码，并逐行验证。未知消费者名称、错误批次或交换标签必须失败。
4. 补充负向契约测试，至少覆盖“来源标签互换但汇总不变”和“虚构消费者字符串”两种情况，并证明验证器返回非零。
5. 返工后重新提交：验证器 PASS、新增聚焦测试全绿、完整 XCTest 不回归、`git diff --check` 通过，并更新 handoff 与隔离证据。

## 门禁与后续

🧱 tech 门禁：`REVISE`。

N-015 保持 `active / PENDING`。Codex 的核心运行时与美术线可继续处理零文件交集的工作，但在以上问题关闭前，不接收该 VSCode 基础包，也不将其作为后续全量接入的权威证明。

## r2 返工复闸

- 复闸日期：2026-08-23
- 🧱 tech 结论：`REVISE`
- 🛡️ quality 交叉复核：`REVISE`

### 已关闭的首轮问题

1. `--refresh-matrix` 已并入追踪中的验证器；独立复跑前后矩阵 SHA-256 均为 `e203b6250c03d8d54e8a96b7ea80a7a9464f15657e1c0717f330a423788237ed`，确认逐字节幂等。
2. provenance、category、planned_consumer、trigger_state、fallback、batch 已按文件/家族规则逐行比较。
3. 独立定向 XCTest 14/14 通过，四个负向用例实际执行并拒绝来源交换、虚构消费者、错误 batch 和错误 category。
4. 权威全量 xcresult `Test-CreekSprout-2026.08.23_22-42-56--0700.xcresult` 为 288/288/0/0；当前验证器为 `PASS failures=0`，矩阵仍为 132 项、状态 53/30/49。

### R3 — 缺失必填字段时验证器崩溃，未返回约定 JSON

独立负向复核从临时矩阵第一条记录删除 `provenance` 后运行：

```text
python3 scripts/validate-n015-consumer-matrix.py \
  --matrix /private/tmp/n015-missing-field-review.json
```

实际结果为退出码 1、stdout 0 字节，stderr 是 `KeyError: 'provenance'` traceback。`validate()` 已记录“缺失必填字段”，但 `main()` 随后在构建 summary 时使用 `a["provenance"]`、`a["category"]`、`a["runtime_status"]` 直接索引，导致 `finish()` 无法输出 `result=FAIL` 的 JSON。

这违反原工作包的两项明确要求：验证字段完整性，以及失败时向 stdout 输出简洁 JSON 并逐项列出错误。自动化调用方目前只能看到进程崩溃，无法取得可解析的失败报告。

### 最小收尾条件

1. summary 构建必须容忍非对象记录和缺失/错误类型字段；验证失败也必须进入 `finish()`。
2. 对可解析但合同无效的矩阵，stdout 必须始终是可解析 JSON，包含 `result=FAIL`、非零 `failures` 和能定位 filename/字段的 `errors`，同时退出非零。
3. 新增“删除必填字段”负向 XCTest；不能只断言退出非零，还必须解析 stdout，并断言报告为 `FAIL` 且包含对应字段错误。建议同时让现有四个负向测试验证可解析 `FAIL`，避免以 traceback 假阳性通过。
4. 更新 handoff 后重跑验证器、定向 XCTest、完整 XCTest 与 `git diff --check`。文件边界保持 DEC-034 不变。

上述 R3 关闭前，`N-015-VSCODE-FDN-01` 仍不接收；N-015 本体继续 `active / PENDING`。

## r3 返工复闸

- 复闸日期：2026-08-23
- 🧱 tech 结论：`REVISE`
- 🛡️ quality 交叉复核：`REVISE`

### 已关闭的 r2 问题

1. 独立 CLI 复核确认：删除 `provenance` 后 stdout 是可解析 JSON，`result=FAIL`、`failures=3`，错误包含缺失字段与具体 filename，退出码 1，stderr 为空。
2. 正常 validator 为 `PASS failures=0`；独立定向 XCTest 15/15 通过。
3. 权威全量 xcresult `Test-CreekSprout-2026.08.23_23-16-08--0700.xcresult` 为 289/289/0/0。
4. App Sandbox 内无法通过 `python3`/xcrun shim 启动验证器的环境限制已如实披露；Swift 侧五项负向合同测试可作为矩阵合同回归，但不冒充 Python CLI 自动化测试。

### R4 — sandbox fallback 会把权威审计失败改写为成功

r3 在 `run_audit()` 中新增了 `audit_in_process()`：只要权威审计 subprocess 返回非零，就忽略其失败结果，改用一份复制的消费者扫描算法，并无条件返回 `overall_pass: True`。

独立模拟 `scripts/audit-runtime-art-integration.py` 返回退出码 1、`overall_pass=false` 后，`run_audit()` 实际返回：

```text
simulated_authoritative_exit=1
returned_overall_pass=True
fallback_reason=authoritative audit failed
resolved_count=53
```

这会吞掉真实审计故障，也违反原工作包“调用现有审计结果，不得复制一份容易漂移的手工算法”的要求。该 fallback 对已披露的 XCTest 沙箱限制也没有实际帮助：沙箱中 Python 验证器本身无法启动，因此不会进入 Python 内部的 fallback；当前 XCTest 已改用 Swift 进程内合同检查。

### 最终最小收尾条件

1. 删除 `audit_in_process()` 及其复制算法。
2. `run_audit()` 的 subprocess 只要无法启动、返回非零、stdout 非法或报告 `overall_pass != true`，验证器必须输出可解析 `FAIL` JSON 并退出非零；不得合成成功报告。
3. 保留已通过的 `build_summary()` 健壮性、五项 Swift 负向合同测试和 `--refresh-matrix`，不要重做矩阵。
4. handoff 明确区分“Swift 等价合同测试”与“沙箱外 Python CLI 负向夹具”，并把测试文件纳入证明中的旧 `284` 更正为 `289`，写出精确 xcresult 路径而非通配描述。
5. 重跑正常 validator、审计失败模拟、缺字段 CLI、定向 15 项、完整 289+ 项和 `git diff --check`。

R4 关闭后即可再次请求最终复闸；不增加新的玩家、美术、音频或生产代码要求。

## r4 最终复闸

- 复闸日期：2026-08-23
- 🧱 tech 结论：`APPROVED`
- 审查对象：VSCode / 🛠️ tools 的独立基础包；与后续 Codex 生产实现无文件交集，因此不存在自我批准。

### 独立确认

1. `audit_in_process()` 与复制的消费者审计算法已删除；`run_audit()` 只调用 `scripts/audit-runtime-art-integration.py`。
2. 独立故障注入覆盖无法启动、非零退出、stdout 非 JSON、`overall_pass != true`；四种情况均输出可解析 `FAIL` JSON、退出 1，且没有合成成功报告。
3. 删除矩阵第一项 `provenance` 后，CLI 输出可解析 `FAIL` JSON（failures=3，字段定位明确）并退出 1，无 traceback。
4. 正常 validator 为 `PASS failures=0`，资产 132，来源 119/12/1，状态 53/30/49。
5. 定向 xcresult `artifacts/integration/n-015-codex-runtime/vscode-gate/TestResults-N015-VSCode-r4-targeted.xcresult` 的权威汇总为 15/15/0/0。
6. 全量 xcresult `artifacts/integration/n-015-codex-runtime/vscode-gate/TestResults-N015-VSCode-r4-full.xcresult` 的权威汇总为 289/289/0/0。
7. r4 文件 SHA-256 已写入 `artifacts/integration/n-015-codex-runtime/preflight/baseline.md`；未发现 VSCode 越过 DEC-034 文件边界。

### 门禁结论

`APPROVED`。Codex 可以接收矩阵基础包，并在生产消费者变化后按 handoff 运行确定性 `--refresh-matrix`。本批准不代表 B2、B3、HUD、建筑或 N-015 已完成。
