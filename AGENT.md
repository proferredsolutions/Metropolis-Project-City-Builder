# Agent Instructions for Metropolis-Project-City-Builder

## Overview
Metropolis is a task/project tracker skinned as an isometric city-builder
game. Each task or project becomes a specific type of building on a specific section of terrain/land. (playing area) the terrain/playing area is overlayed by a invisible grid system that appears only when selecting a specific area when creating a project or task, or when moving buildings around.(each building, road etc takes up minimum one grid worth of land, for larger buildings etc they may take up more then one grid.) the terrain isnt flat but has hills, mountains, valleys, waterways, forests, etc so normal rules would apply (where buildings etc can be placed according to the terrain.) when first starting out maybe the app starts by creating a random or pre-made/pre-fixed terrain, scenery etc,    The whole land area could take up about 50x50 on smaller side or 100x100 plus grid squares. an idea is for when 1st starting out that maybe the new user only gets to use a certain amount like a 5x5 grid as starting point instead of having the whole land available right-away and then as the player/user completes tasks/buildings every so many levels, or points it unlocks the playing area size (the grid expands/playing area gets bigger an bigger as you progress, unlock it or level up. As you
make real-world progress on a task, its building visibly grows through
construction stages; completing it finishes the building. XP and a
level/badge system reward real effort with cosmetic unlocks (new building
styles, decorative extras) — never with gameplay-mechanic changes. There is
no currency, no failure state, and no time pressure beyond a purely visual
overdue marker. The goal is a lightweight app that makes real task-tracking
feel visually rewarding without becoming stressful.


## Project Structure
- `state.js` — task data model + `localStorage` persistence (CRUD only, no
  calculation logic)
- `progress.js` — pure functions that turn task data into visual state:
  `getProgressIncrement`, `getVisualStage`, `getBuildingHeight`,
  `advanceProgress`, `getXPReward`, `isOverdue`
- `index.html` — app shell; loads `state.js` then `progress.js` then future
  UI/render scripts via plain `<script>` tags, in that order
- `base.css` — resets, typography, page layout
- `isometric.css` — the world's isometric tilt and cube-face styling for
  buildings and grid tiles
- `ui.css` — HUD elements: XP bar, level badge, "add task" modal
- `AGENT.md` — this file
- `TASKS.md` — build-order backlog

## Code Style & Conventions
- Vanilla JavaScript (ES2020+), no frameworks, no npm packages, no build
  tooling of any kind
- Plain `function name() {}` declarations, no ES modules — files are loaded
  via ordinary `<script src="...">` tags, so load order in `index.html`
  matters and later files can call earlier files' functions directly
- Immutable-style updates via object spread (`{ ...task, ...updates }`)
  rather than direct mutation
- Favor pure functions wherever the logic allows it — `progress.js` is the
  reference example: no DOM access, no `localStorage` access, same input
  always produces the same output
- `crypto.randomUUID()` for all generated IDs — no UUID library needed
- Comments should explain *why* a piece of code exists or works the way it
  does, not just restate what it does — this codebase is also a learning
  reference

## Rules & Constraints
- No npm, no bundler, no build step — the app must run by opening
  `index.html` directly or serving the folder statically
- No backend/server for v1 — `localStorage` is the only persistence layer
- No WebGL or 3D libraries (e.g. Three.js) — the isometric look comes
  entirely from CSS 3D transforms (`perspective`, `transform-style:
  preserve-3d`, `rotateX`/`rotateY`/`translateZ`)
- The grid is fixed at 5x5 (25 task slots) for v1 — do not implement
  dynamic grid resizing yet; that is a documented v2 idea
- Overdue tasks get a **visual-only** penalty (cracks/dust on that
  building) — progress must never freeze, slow, or reset because a task is
  overdue
- Leveling and badges are **cosmetic only** — they must never gate or
  block core functionality like adding or completing tasks

## Development Workflow
- Single main branch is fine at this early, solo-project stage
- Commit after each working, tested unit of work (e.g. "Add progress.js
  with tests") rather than large, mixed commits
- Update `TASKS.md` in the same commit as the work it tracks, so the
  backlog stays trustworthy

## Testing Requirements
- Pure functions (all of `progress.js`, and future files following the
  same pattern) should be spot-checked with a quick `node -e` script
  before being wired into the UI — no formal test framework needed at
  this scale, but write and run real assertions, not just "it looks right"
- After wiring a feature into the UI, manually verify in-browser with at
  least three cases: a 1-day task, a multi-day task with no subtasks, and
  a task with subtasks — confirm progress increments match the formulas
  in `progress.js`

## Key Patterns to Follow
- `getProgressIncrement(task)` is the single source of truth for "how
  much is one unit of work worth" — never re-derive this math elsewhere
- Visual stage and building height are **derived** from `progress`, never
  stored as independent state that could drift out of sync
- XP and overdue status are also calculated on demand from task data, not
  manually set or cached
- `state.js` owns persistence; `progress.js` owns calculation. UI/render
  code is the glue: read with `loadTasks()`, compute with `progress.js`,
  write with `updateTask()`

## Things to Avoid
- Don't introduce a build step (webpack, Vite, etc.) unless a concrete
  need arises — this project is intentionally build-tool-free
- Don't let `progress.js` (or its successors) touch `localStorage` or the
  DOM directly — keep calculation functions pure and testable in isolation
- Don't add currency, failure states, or punishing mechanics — this breaks
  the explicit "stress-free" design goal
- Don't hardcode the grid size (5) in more than one place, even though
  it's fixed for now — makes the future v2 grid-expansion feature much
  easier

## Integration Points
- `state.js` <-> `progress.js`: `state.js` stores the task object;
  `progress.js` computes derived values from it; UI code connects them,
  typically via `updateTask(task.id, advanceProgress(task))`
- `progress.js` <-> rendering: future render code calls
  `getVisualStage()`/`getBuildingHeight()` per task to decide what to draw
  on the grid

## Performance Considerations
- Target hardware is resource-constrained (limited RAM, integrated
  graphics) — CSS 3D transforms are GPU-composited and cheap; prefer CSS
  transitions/animations over JavaScript-driven per-frame animation loops
- DOM node count should stay low: 25 grid tiles max at v1, each building
  built from ~3 face `div`s, so worst case is roughly 75-100 nodes total —
  trivial for any modern browser, even on modest hardware

## Security Considerations
- All data is local (`localStorage`) — no authentication, no network
  calls, no user data ever leaves the browser
- If task titles/details are ever rendered via `innerHTML`, sanitize or
  prefer `textContent` instead, to avoid self-inflicted XSS from pasted
  text
