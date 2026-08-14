---
name: project-ledger
description: Maintain the auditable project ledger for the cozy farm game. Use when starting, reporting, reviewing, accepting, blocking, or completing any tracked game phase, milestone, feature, content, engineering, QA, build, or release task; use it for a daily brief that reports progress, the next ready task, and a visual phase status; also use whenever cozy-farm-game-studio requires its project-ledger workflow.
---

# Project Ledger

Maintain [docs/game/project-ledger.md](../../docs/game/project-ledger.md) as the sole current register for the project's planned phases, tracked tasks, department gates, evidence, and follow-ups. Treat the user as Product Owner and preserve the ledger's stable task IDs and history.

## Daily brief

When the user asks for `每日简报`, `项目简报`, or an equivalent daily-status request, re-read the complete ledger and produce a read-only report. Do not change a task status, create a task, or append a change-log entry merely because the user requested a brief.

Return exactly these three items, in order:

1. **Current progress** — render one compact text progress bar and a count. Calculate `accepted ÷ all tasks except deferred`, round the percentage to the nearest whole number, and use at most 10 blocks. State the active task count only when it is nonzero.
2. **Best next task** — select exactly one `planned` task that passes the dependency preflight. Rank candidates by the earliest phase in the phase overview, then by the task's dependency-unblocking value, then by task ID. Give its ID, a one-sentence description, and its owner. Never recommend a task with an unresolved dependency. If no task is ready, say `当前没有可启动的开发任务` and name the single most immediate blocking task or Product Owner decision instead.
3. **Project structure status** — emit one Mermaid `flowchart LR` in phase-overview order. Each node must include the phase ID, phase name, and actual ledger status. Use `✅` for `accepted`, `🔄` for `active`, `⛔` for `blocked`, `⏳` for `planned`, and `◌` for `deferred`; label the active phase or phases as `current`. Do not infer status from dates or from a task in another phase.

Keep the brief factual and compact. Use the ledger as the only status source; list a missing or contradictory field as a blocker rather than guessing.

## Required workflow

1. At task intake, read the complete ledger and the task's source artifacts (for example PRD, TDD, implementation, tests, or build reports). Do not rely on a prior conversation summary.
2. Find the applicable task by ID. If the requested work has no task, add one under the correct phase before development, with a stable ID, owner, dependencies, acceptance criteria, and initial `planned` status.
3. Run the mandatory dependency preflight before marking the task `active` or performing implementation, content production, configuration changes, integration, or downstream handoff. Every listed task dependency must exist and be `accepted`; every external dependency or Product Owner decision must be explicitly resolved in the ledger. Missing, `planned`, `active`, `revise`, `blocked`, or unapproved `deferred` dependencies fail this preflight.
4. If preflight fails, do not start development. Update only the target task to `blocked` with gate `BLOCKED`; record the blocking task IDs or decision, the required next owner, and a change-log entry. Report the block and stop, except for read-only diagnosis needed to clarify the dependency.
5. Permit an exception only when the Product Owner explicitly authorizes it. Record a decision ID naming the target task, blocked dependencies, narrowly bounded non-dependent work, and expiry/review condition. Link that decision from the task evidence before marking it `active`.
6. When preflight passes, update only that task to `active`, record the current date, scope, and any newly discovered dependency or risk. Do not change other task statuses by inference.
7. On handoff, record changed artifacts and raw evidence: commands and results, test reports, screenshots, build identifiers, save samples, or review links. Use `REVISE` or `BLOCKED` when that is the actual gate outcome.
8. Change a task to `accepted` only after its required department gate is explicitly `APPROVED` and independent quality evidence satisfies its acceptance criteria. For cross-department work, record each required approval. A task with missing evidence remains `active` or `revise`.
9. After a successful acceptance update, update the phase status only if every task in that phase is `accepted` or explicitly `deferred`; otherwise leave the phase active. Append a concise entry to the ledger change log.

## Ledger rules

- Use exactly: `planned`, `active`, `revise`, `blocked`, `accepted`, or `deferred` for status; use exactly `PENDING`, `APPROVED`, `REVISE`, `BLOCKED`, or `N/A` for gates.
- Keep scope, requirements, evidence, and gate result factual. Never invent a command result, approval, date, or completed artifact.
- Preserve `Task ID`; do not renumber existing rows. Add new tasks with the next available prefix/number for the matching phase.
- Put durable scope, risk, or schedule decisions in the Decisions section; put actionable impediments in Risks & dependencies.
- Update the ledger with `apply_patch`. Re-read the edited task row and change-log entry before reporting completion.
- If `project-ledger.md` is missing, create it from the project baseline before starting the task; if its status conflicts with the actual repository evidence, flag the discrepancy to the Product Owner instead of silently correcting history.

## Cozy Farm Game Studio integration

When this skill is invoked from `cozy-farm-game-studio`, also follow that studio's role assignment, approval contract, originality boundary, and department-gate rules. The studio's specialist submission supplies the ledger evidence; the relevant department lead's explicit gate result determines the ledger status.

## Completion report

State the task ID, ledger status, gate result, evidence recorded, changed ledger sections, and the next owner. Do not claim project or phase completion merely because a task was implemented.
