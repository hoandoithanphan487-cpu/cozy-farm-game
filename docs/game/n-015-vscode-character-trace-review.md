# N-015-VSCODE-CHAR-TRACE-01 Codex independent review

- Reviewer: Codex / 🧱 tech
- Downstream check: 🛡️ quality
- Date: 2026-08-25
- Gate status: `APPROVED`
- Parent task: N-015 remains `active / PENDING`

## Scope reviewed

- `docs/game/n-015-runtime-consumer-matrix.json`
- `scripts/validate-n015-consumer-matrix.py`
- `macos/CreekSprout/CreekSproutTests/N015RuntimeConsumerMatrixTests.swift`
- `docs/game/n-015-vscode-character-trace-handoff.md`
- `artifacts/integration/n-015-vscode-character-trace/**`

Production Swift, runtime/HD PNGs, character-generation inputs, the map contract, audio, gameplay data, save schema and stable IDs were outside this package and were not changed by the accepted work.

## Evidence inspected and independently reproduced

1. Dependency preflight: N-015 is `active / PENDING`; N-006, N-009, N-010, N-013 and D0-002 are `accepted / APPROVED`; DEC-031 through DEC-035 exist.
2. Consumer validator: independent run `PASS`, 132 assets, 132 integrated, 132 resolved, provenance 104 N-006 / 8 N-003 / 19 N-015 character / 1 DEC-033.
3. Character runtime validator: independent run `PASS`, 19/19 processed assets byte-identical to runtime output.
4. Runtime audit: independent `--require-all-consumers` run `overall_pass: true`; 132/132, 0 missing, 0 extra, 0 hash/dimension/PNG failures, 0 unreferenced.
5. Frozen map contract: independent `--contract-only` run `PASS`; 2 maps, 5 buildings, 30 layers, 23 reachable targets, 1 save relocation rule; contract SHA-256 remains `328c1afd542464353058e47370373b19e5ca003ac6b49496b00ef2c2e723fd51`.
6. Submitted xcresults were read directly: focused 27/27 and full 385/385, with 0 failed, 0 skipped and 0 expected failures.
7. Codex clean reruns produced new xcresults:
   - focused: `/tmp/n015-codex-character-trace-review-focused/Logs/Test/Run-CreekSprout-2026.08.25_01-14-43--0700.xcresult` — 27/27/0/0;
   - full: `/tmp/n015-codex-character-trace-review-full/Logs/Test/Run-CreekSprout-2026.08.25_01-15-12--0700.xcresult` — 385/385/0/0.
8. The six submitted authoritative subprocess mutations were inspected and independently exercised by the focused rerun. Codex added four separate mutations; all returned exit 1 with parseable `FAIL` JSON:
   - remove the character manifest from `generated_from`;
   - change `char_player.png` to `planned`;
   - change a character override scope from `runtime` to `concept`;
   - replace a character override filename with a non-character asset.
9. Deterministic refresh: rebuilding the matrix into `/tmp` produced a byte-identical file (`cmp` exit 0).
10. Real-App evidence static audit remains 17/17, and the earlier live route plus HD-character-info screenshot remain the player-visible evidence.

## Review findings

- The new manifest is a real fourth authoritative source, not a filename heuristic.
- Override resolution order is explicit and correct: N-006 base → N-003 override → N-015 character override → DEC-033 addition.
- The validator recomputes PNG IHDR, RGBA type, size and SHA-256 for all 132 final assets, and fails closed when the authoritative consumer audit fails.
- The 19-file set is constrained to 8 idle, 8 walk and 3 player action assets; the matrix cannot silently reclassify another asset into the override set.
- The new negative XCTest cases invoke the same Python validator with isolated temporary JSON files; they do not synthesize success locally or ignore subprocess exit codes.
- The submitted file-boundary report cannot prove content deltas for files that were already untracked because `git status` remains `??`; this is a limitation of the dirty-worktree baseline, not a blocker. Independent contract regeneration, full hash validation and production runtime audits cover the accepted package behavior.
- Two existing test-source warnings (`var` could be `let`) remain non-blocking and do not affect production Swift or the gate result.

## Gate result

`APPROVED`

Acceptance gaps: none for `N-015-VSCODE-CHAR-TRACE-01`.

This approval closes the stale consumer-provenance and 19-hash traceability gap. It does not self-sign Product Owner visual acceptance and does not start N-016.

Next gate: Product Owner performs the final visual judgment on N-015 character R1. If `APPROVED`, the director may mark N-015 `accepted / APPROVED`, unblock N-016 dependency preflight, and begin the original file-based audio task.

