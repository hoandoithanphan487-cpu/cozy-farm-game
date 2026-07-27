# Original cozy farm-game blueprint

## Contents

1. Product promise
2. Design pillars
3. Familiarity and originality
4. Core loop
5. MVP vertical slice
6. System contracts
7. Beginner-safe production choices

## Product promise

Create a low-pressure 2D farm-life game where the player restores a small place, shapes a home, forms relationships, and gradually unlocks a wider world. Let routine create comfort and changing seasons create anticipation.

## Design pillars

### 🌾 Care becomes visible

Player actions should visibly improve land, home, relationships, and community. Prefer persistent, readable change over abstract score growth.

### 🕰️ Gentle choices under time

The day creates meaningful prioritization, but failure should redirect rather than punish harshly. Avoid irreversible traps and excessive grind.

### 🏡 A place with its own identity

Use a new setting, culture, ecology, architecture, cast, conflicts, and rituals. Let the game’s differentiator influence mechanics rather than exist only in lore.

## Familiarity and originality

Use a “purpose → redesign” process:

| Familiar purpose | Original redesign prompts |
|---|---|
| Daily planning | What local event, weather, ecology, or community need changes today’s priorities? |
| Crop progression | What is distinctive about soil, climate, pollination, water, magic, or technology here? |
| Town relationships | How do characters change the shared place, not just fill heart meters? |
| Seasonal anticipation | What original rituals, migrations, markets, or environmental shifts mark time? |
| Exploration reward | What knowledge, materials, routes, or relationships open new play styles? |
| Farm expansion | What choices make two players’ farms function differently? |

Require at least one mechanical differentiator in the first vertical slice. Examples: ecological restoration, rooftop farming, floating islands, tea cultivation, spirit-assisted irrigation, or a traveling village. Treat these only as prompts; select or invent one with the Product Owner.

## Core loop

```text
Observe needs and opportunities
        ↓
Choose a short plan for the day
        ↓
Farm / gather / craft / build / socialize / explore
        ↓
Receive tactile feedback and persistent change
        ↓
Sell, trade, learn, or contribute
        ↓
Unlock new choices, stories, and spaces
        ↺
```

Design each system to serve at least two parts of the loop. A system that only adds content volume should wait.

## MVP vertical slice

Target a 10–15 minute playable loop:

1. Wake, read one clear goal, and inspect weather/time.
2. Prepare soil, plant, water, and advance crop state.
3. Gather one nearby resource and craft one useful item.
4. Meet one character whose need connects farming to the world.
5. Harvest, sell or deliver, receive visible progression, and save.
6. Reload and confirm the changed state persists.

Suggested content ceiling:

- 2 small connected maps;
- 3–5 crops;
- 3–5 items/recipes;
- 2–3 characters;
- 1 quest;
- 1 building or tool upgrade;
- 1 weather state beyond clear;
- 1 original differentiating mechanic.

## System contracts

For every system, define:

- player inputs and feedback;
- state machine and transitions;
- time/stamina/resource costs;
- data schema and content IDs;
- interactions with inventory, economy, quests, world, and save data;
- edge cases and cancellation behavior;
- accessibility and input considerations;
- debug inspection;
- acceptance and regression tests.

Prefer stable IDs and versioned save data from the first playable build.

## Beginner-safe production choices

- Choose one engine and finish a vertical slice before evaluating alternatives.
- Start with a simple grid and deterministic simulation.
- Make content data-driven, but build editors only after raw data authoring becomes painful.
- Use placeholder art and audio to test scale, timing, and feedback early.
- Avoid multiplayer, procedural worlds, complex combat, and fully simulated NPC schedules in the first slice.
- Add automated tests around pure rules: crop growth, inventory transactions, crafting, economy, quest conditions, and save migration.
- Keep a short manual smoke path for player feel and rendering.
