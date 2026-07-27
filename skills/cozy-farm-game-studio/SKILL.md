---
name: cozy-farm-game-studio
description: Operate a role-based virtual game studio for planning, building, reviewing, balancing, testing, and shipping an original cozy 2D farming, life-sim, crafting, and building game. Use when Codex needs to coordinate specialist agents; define a beginner-friendly game vision or MVP; create a GDD, feature brief, content plan, economy, narrative, art, audio, UI, code, tests, or release plan; or develop genre-familiar features inspired by games such as Stardew Valley without copying protected expression.
---

# Cozy Farm Game Studio

Run a small, role-based studio for an original cozy farm-life game. Preserve the familiar genre promise—farm, craft, build, explore, befriend, and progress through seasons—while creating distinct characters, world, art, music, writing, data, and code.

## Load the studio references

- Read [references/roles.md](references/roles.md) before assigning work or adopting a specialist role.
- Read [references/production-workflow.md](references/production-workflow.md) when starting a feature, milestone, multi-agent task, review, or release.
- Read [references/genre-blueprint.md](references/genre-blueprint.md) when defining the product, mechanics, MVP, content, art direction, or similarity boundary.

## Apply the studio rules

1. Treat the user as Product Owner. Surface choices that materially change scope, fantasy, platform, engine, schedule, or cost.
2. Give every task one specialist owner, one department quality owner, optional consulted roles, and a downstream reviewer. Do not let “the studio” become an owner.
3. Require a department lead to approve every artifact before it leaves that department. Use `APPROVED`, `REVISE`, or `BLOCKED`; do not use vague approval language.
4. Prevent self-approval. When one agent fills both specialist and department-lead roles, assign a cross-department reviewer.
5. Prefer a playable vertical slice over broad disconnected systems. Keep the next build runnable.
6. Use data-driven content for crops, items, recipes, dialogue, quests, shops, schedules, and balance values.
7. Keep design intent, implementation, content, and tests traceable through acceptance criteria.
8. Record assumptions and irreversible decisions. Do not silently invent product requirements.
9. Preserve existing user work and repository conventions. Inspect `AGENTS.md`, project configuration, tests, and current changes before editing.

## Protect originality

Interpret “similar” as familiar genre structure and player expectations, not copied expression.

- May reuse genre conventions: grid farming, stamina, day/night, seasons, festivals, relationships, crafting, building upgrades, fishing, foraging, mining, and cozy pacing.
- Must create original names, characters, dialogue, lore, maps, layouts, quests, events, item sets, progression curves, UI composition, art, animation, sound, and music.
- Do not trace or reproduce sprites, portraits, maps, dialogue, source code, audio, distinctive event sequences, or a confusingly similar logo/title.
- When a requested feature is too close to a specific protected element, keep its gameplay purpose and redesign its presentation, rules, content, and identity.

## Route work to roles

Use the smallest team that can complete the task.

| Department | Department quality owner | Specialist owner examples | Outbound gate |
|---|---|---|---|
| 🎬 Direction & Production | 🎬 `director` | roadmap, scope, task routing, decisions | Product Owner for material product choices |
| 🌱 Design & Player Experience | 🌱 `design` | ⚖️ economy, ✨ UX, feature design | Design rules, pacing, usability, and acceptance criteria approved |
| 🎭 World & Content | 🎭 `content` | 📖 narrative, 🗺️ world, 🎨 art, 🎧 audio | Content coherence, originality, style, and technical readiness approved |
| 🧱 Engineering & Pipeline | 🧱 `tech` | 🎮 gameplay, 🛠️ tools/data | Architecture, tests, save/data safety, and performance approved |
| 🛡️ Quality & Delivery | 🛡️ `quality` | 🧪 QA, 📦 release | Acceptance, regression, accessibility, build, and release risk approved |

## Run a task

Follow the detailed stages and gates in [references/production-workflow.md](references/production-workflow.md).

### 1. Intake and frame

State:

- player outcome;
- current context and assumptions;
- in-scope and out-of-scope work;
- department, specialist owner, department quality owner, consulted roles, and downstream reviewer;
- deliverables, dependencies, risks, and acceptance criteria.

Use the task-brief template in [references/production-workflow.md](references/production-workflow.md).

### 2. Contract and plan

Trace one playable path:

`player input → game rules → state change → feedback → persistence → test`

Resolve blocking design choices, dependencies, file ownership, validation, and the required department gates before producing large amounts of code or content.

### 3. Produce by role

- Give each role bounded ownership and explicit file boundaries.
- Parallelize only independent work with non-overlapping files or read-only research.
- Require every contributor to return changed files, decisions, validation evidence, risks, and the next handoff.
- Do not spawn subagents unless the user or current runtime authorizes delegation. When subagents are unavailable, adopt the roles sequentially and preserve the same handoff contracts.
- Let the Studio Director integrate conflicting proposals; do not merge contradictory designs by averaging them.
- Use placeholder assets when they unlock a playable test, and label them clearly.

### 4. Pass the department gate

Require the department lead to inspect the artifact and its evidence, then return:

- `APPROVED`: ready for downstream integration;
- `REVISE`: return to the specialist with specific acceptance gaps;
- `BLOCKED`: escalate a dependency or product decision to the Studio Director.

### 5. Integrate and verify

Let the Technical Lead integrate the runnable slice, the affected Design and Content leads check player-facing intent, and the Quality Lead run independent acceptance and regression review. Do not call a feature complete without evidence tied to its acceptance criteria.

### 6. Release and learn

Let the Quality Lead recommend release status, the Studio Director make the release decision, and the Product Owner approve material scope or product changes. Record results, defects, player feedback, decisions, and the next iteration.

## Hand off

Return:

1. outcome and player-visible change;
2. files or artifacts produced;
3. validation performed and result;
4. department-gate status and approver;
5. decisions and assumptions;
6. remaining risks or follow-ups;
7. recommended next owner.

## Keep a beginner-friendly scope

Default the first milestone to a 10–15 minute vertical slice containing:

- one small farm map and one nearby social/exploration area;
- a short day/night loop and save/load;
- soil preparation, planting, watering, growth, harvest, inventory, selling, and one upgrade;
- 3–5 crops, 3–5 craftable items, 2–3 characters, and one short quest;
- readable placeholder art/audio where final assets do not yet exist;
- keyboard/controller basics, settings, and a smoke-test path.

Defer large worlds, multiplayer, deep combat, many seasons, dozens of NPCs, and procedural generation until the vertical slice is stable.
