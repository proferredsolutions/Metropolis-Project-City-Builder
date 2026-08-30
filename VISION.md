# Metropolis — Game & App Vision

*(Rewritten to match the current technical plan: Godot Engine / GDScript, native Android target, no CSS/DOM/web rendering anywhere. See `AGENTS.md` for the binding technical rules — this document is the design vision that `AGENTS.md` implements.)*

## What it is

Metropolis is a task/project tracker skinned as a visually rich, isometric-style city-builder game. The task tracker is the real product; the city is the reward layer built on top of it. Every task or project the user creates becomes a specific type of building, placed on a specific tile of land.

## The land and the grid

The playable area is underlaid by a **tile grid** (implemented as a Godot `TileMap`). The grid isn't normally visible — it appears as a highlight overlay when the player taps a tile, when placing a building, or when repositioning one, and fades out automatically if no further action follows.

Each building or road occupies a minimum of one tile; larger buildings occupy more than one, based on the size/scope of the task they represent.

The terrain itself is not flat — it has rolling hills, occasional rock formations, waterways, lakes, and forest patches, giving the landscape depth and texture rather than a plain checkerboard. Terrain type constrains what can be built where (for example, a tile that's water can't host a standard building), the same way normal city-builder placement rules work.

**Land size grows with progress.** A new player does not start with the full map — they start with a small, manageable plot (a modest starting grid, roughly in the 5×5–8×8 range). As the player levels up by completing real tasks, more of the surrounding land unlocks and becomes buildable, and the city grows outward over time. The eventual full map can be substantially larger, but expansion is always earned, never available all at once.

## Turning tasks into buildings

To create a task, the player taps an open tile. This brings up the grid highlight on that tile along with a "Create Task/Project" prompt. Selecting it opens the task creation form — name, date, description, and the other standard task fields. Confirming creation:

- Places a building on that tile.
- Starts a **construction animation** (small worker/"villager" sprites visibly building it) rather than instantly completing it — the building can't just be created and immediately finished.
- Determines the building's **type and expected size** based on the task's length/scope and the player's current level, so bigger or longer tasks produce bigger or more elaborate buildings, and higher-level players have access to a wider variety of building styles.

As the player makes **real-world progress** on the task (not app-opens, not elapsed time alone), the building visibly grows through construction stages. Completing the task completes the building's construction, with a distinct completion animation.

## Overdue tasks

If a task goes overdue, the building shows a **purely visual** neglected state (cracks, dust, dimmed appearance, etc.). This is a visual cue only — it never freezes progress, never removes the task or building, and never introduces a fail state. The player can resume progress at any time and the visual reverts once the task is back on track or completed.

## XP, levels, and unlocks

Completing tasks earns XP, scaled to the task's size/complexity. Leveling up unlocks:
- New cosmetic building styles and skins.
- Decorative extras (trees, statues, small landmark structures).
- Additional buildable land (see "The land and the grid" above).

Leveling and unlocks are **strictly cosmetic and content-based** — they never change how task-tracking works, never gate core functionality, and never introduce competitive or failure mechanics.

## The main view and controls

Opening the app puts the player directly into an open view of their landscape — no separate "menu screen" standing between the player and their city. From there:

- **Pan** around the landscape with a finger drag.
- **Pinch to zoom** in for detail or out for a wide view of the whole city.
- **Tap a tile** to bring up the grid highlight and either place a new task/building (if empty) or view/edit the existing task's details (if occupied).
- Any persistent UI (menus, buttons, HUD elements) is anchored along the screen edges, out of the way of the main landscape view, and does not interrupt the sense of looking at an actual place.

## Visual style

**Direction: simplified pixel-art / low-detail 2D isometric style** — not the painted, near-photorealistic look of big-budget city-builder references, but a charming, readable pixel-art (or flat, minimally-shaded 2D) aesthetic that's realistic for one developer to actually produce and for the target hardware to run smoothly.

What this looks like in practice:
- **Tile-based terrain**: grass, dirt path, water, forest, and hill tiles as a modest pixel-art tileset, with terrain "flavor" (rocks, bushes, water) as small decorative sprites scattered on top of base tiles rather than hand-painted per-scene detail.
- **Modular buildings**: each building type built from a small number of reusable pixel-art pieces (base shape + roof + a couple of decorative extras) so that palette swaps and part-swaps can produce visual variety without drawing every building from scratch.
- **Lightweight character animation**: a handful of simple villager sprite sheets (walk cycle, build/work cycle) reused across many instances, rather than unique individually-animated crowds — small moving figures near an under-construction building are enough to sell "it's being built" without needing dozens of unique animations.
- **Simple, cheap effects**: a small chimney-smoke puff or dust-cloud using Godot's lightweight 2D particle system, used sparingly, rather than dense atmospheric effects layered across the whole scene.
- Distinct but simple **construction**, **completion**, and (where relevant) **decay/overdue** visual states per building — achievable as a handful of sprite frames or a short scale/reveal animation, not a full cinematic sequence.
- A sense of depth via layered terrain tiles (hills as raised/shaded tiles, water as a distinct lower layer) rather than true 3D geometry or painted shading.

This keeps the "toylike, rewarding city that grows" feeling from the original reference image, while keeping the actual art production and runtime performance realistic for a solo developer on modest hardware. Fidelity can always increase later (better tilesets, more sprite variety) without changing the underlying grid/building/progress systems.

## Guiding principle

The task tracker must always function correctly and reliably regardless of game state, level, or unlocks. The game layer exists to make real progress feel rewarding to look at — it should never become a gate, a distraction, or a source of pressure on top of the user's actual tasks.

---

*Deliverables for the current phase: core game/app design (this document + `AGENTS.md`), initial project structure in Godot, a basic asset plan, and a runnable minimal demo (small fixed grid, one or two building types, manual task creation and progress, no terrain generation yet).*
