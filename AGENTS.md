# AGENTS.md — Metropolis

> **Status: SUPERSEDES all prior AGENT.md versions.**
> The previous plan (vanilla HTML/CSS/JS, DOM-based isometric grid, localStorage, fixed 5×5 board, browser target) is **retired**. Metropolis is now a **native Android game built in Godot Engine**, with no CSS, no DOM, and no browser rendering involved anywhere in the stack. If any old file references `state.js`, `index.html`, `base.css`, `isometric.css`, or `ui.css`, treat those as historical/deleted — they are not part of the current build.

---

## 1. What Metropolis Is

Metropolis is a real-world task/project tracker disguised as an isometric city-builder game. The task tracker is the *engine*; the city is the *reward*.

- Every task or project the user creates becomes a **building** placed on a **grid tile**.
- Real-world progress on the task (not time, not app engagement) drives the building's visible construction stage.
- Completing a task finishes the building's construction.
- XP and levels unlock **cosmetic** variety only — new building skins, decorations, and (eventually) more playable land. They never change how tasks work or gate task-tracking functionality.
- There is **no failure state** and **no time pressure**. An overdue task shows a purely visual marker (cracks, dust, a "needs attention" cue) — it never blocks progress, deletes anything, or punishes the user mechanically.

The guiding design principle: **task-tracking must always work identically regardless of game state.** The game is a skin and a reward layer on top of a reliable tracker, never a gate in front of one.

---

## 2. Target Platform & Engine

| Layer | Choice | Why |
|---|---|---|
| Engine | **Godot Engine** (latest stable 4.x) | Free, open source, far lighter on disk/RAM than Android Studio + emulator, and has first-class 2D/isometric tooling (TileMap, AnimatedSprite2D, Y-sort) built in. |
| Language | **GDScript** | Godot's native scripting language — no separate compiler toolchain to install, tightly integrated with the editor, easiest to iterate on with limited hardware. |
| Rendering | Godot's own 2D renderer (via `TileMap` + sprites) | Explicitly **not** CSS, **not** DOM, **not** a WebView. Metropolis renders as a real 2D/pseudo-isometric game scene, not a styled web page. |
| Target output | **Android APK/AAB** via Godot's Android export templates | This is a mobile game first. Desktop export may be added later for the developer's own testing convenience, but Android is the shipping target. |
| Persistence | Godot's `user://` file API (JSON via `FileAccess`) | Functionally the same role `localStorage` played in the old plan — simple local file-based save data, no backend, no database server. |

### Explicit non-goals for the stack
- No HTML, CSS, or DOM elements anywhere in the render path.
- No WebView-wrapped web app (Capacitor/Cordova) — this was considered and rejected.
- No native Kotlin/Java + libGDX — rejected due to Android Studio's heavy resource footprint on the dev machine.
- No backend server, no user accounts, no network sync (for now). Everything is local to the device.

---

## 3. Development Hardware Constraints

The developer's machine is a **Microsoft Surface Go 2**: 8GB RAM, ~58GB free storage, modest CPU, running **Ubuntu 26.04**. This is not a hypothetical constraint — it's the actual daily dev environment, so:

- Keep the Godot project lightweight. Avoid importing large uncompressed texture sets; prefer compressed/atlased sprite sheets.
- Avoid 3D nodes, real-time shadows, or post-processing effects that lean on GPU headroom the machine doesn't have.
- Prefer 2D isometric-*style* art (flat sprites arranged to look isometric) over true 3D models — this keeps both the art pipeline and runtime performance manageable.
- Test frequently on-device or via Godot's lightweight remote debug rather than relying on a heavy Android emulator, which is likely to strain 8GB of RAM.
- Keep the exported APK size reasonable — compress art assets, avoid bundling unused engine modules.

---

## 4. Core Gameplay Systems

### 4.1 The Grid & Terrain
- The playable area is a grid of tiles. **Start small** — a modest starting plot (e.g. 5×5 to 8×8 tiles) rather than the full eventual map, so new users aren't overwhelmed.
- The grid expands as a **level-up reward**, not something the user can purchase or rush. More completed tasks → more unlocked land.
- Terrain is not flat — hills, water, forest tiles, etc. are part of the visual landscape and can constrain where certain building types are placed (e.g. no building directly on water).
- Buildings occupy a minimum of 1 tile; larger buildings (bigger/longer tasks or projects) occupy more.

### 4.2 Tasks → Buildings
- Creating a task = placing a building on a chosen tile.
- The building's **type/style** is influenced by task size, duration, or category — bigger or longer-running tasks yield bigger or more elaborate buildings.
- The building's **construction stage** is driven by real progress, not by opening the app or by elapsed time:
  - Projects with subtasks: progress = `completed_subtasks / total_subtasks`.
  - Multi-day tasks without subtasks: progress = `days_elapsed / total_duration_days`.
  - Simple one-day tasks: effectively 0% → 100% on completion.
- Construction height/visual completeness should scale **smoothly** with progress percentage — no jarring stage-snapping.
- Completing the task finishes the building's construction animation.

### 4.3 Overdue Tasks
- Overdue = **visual-only** state. A building shows a distinct "neglected" visual treatment (cracks, dust, dimmed lighting, etc.).
- Overdue status never freezes progress, deletes the task, or blocks other actions. The user can always keep working on it and the visual reverts once it's back on track or completed.

### 4.4 XP & Leveling
- XP is earned by completing real tasks; XP scale should reflect task size/complexity (bigger tasks = more XP).
- Levels unlock:
  - New cosmetic building styles/skins.
  - Decorative extras (trees, statues, special one-off structures).
  - Grid/land expansion (see 4.1).
- Leveling **never** changes core mechanics, never gates the ability to create/edit/complete tasks, and never introduces a fail state.

### 4.5 Camera & Input
- Pan around the landscape via touch drag.
- Pinch to zoom in/out.
- Tapping a tile shows a brief grid-highlight overlay (auto-fades if no further action is taken) and, if empty, offers a "Create Task/Project" action; if occupied, shows the building's task details.

---

## 5. Project Structure (Godot conventions)

```
metropolis/
├── project.godot
├── scenes/
│   ├── main/                # Root game scene, camera rig, UI overlay
│   ├── grid/                # Grid/terrain scene(s), tile placement logic
│   ├── buildings/           # Building scene templates, per-stage variants
│   └── ui/                  # Task creation forms, task detail panels, HUD
├── scripts/
│   ├── data/                # Task/project data model, save/load (GDScript classes)
│   ├── systems/             # Progress calculation, XP/leveling, grid unlock logic
│   └── ui/                  # UI-facing controller scripts
├── assets/
│   ├── sprites/
│   │   ├── terrain/
│   │   ├── buildings/
│   │   └── ui/
│   └── audio/
└── AGENTS.md
```

- Keep game logic (progress math, XP curves, grid-unlock thresholds) in plain GDScript classes under `scripts/systems/`, separate from any node/scene-specific code — these should be unit-testable pure functions wherever possible (mirrors the old `progress.js` intent: `get_progress_increment`, `get_visual_stage`, `get_building_height`, now as GDScript equivalents).
- Task data (the actual tracker content: name, description, due date, subtasks, status) lives in `scripts/data/` as a serializable Resource or plain Dictionary structure, saved/loaded via `user://` JSON — this is the direct successor to the old `state.js` module.

---

## 6. Coding Conventions

- **GDScript style:** follow Godot's official style guide — `snake_case` for variables/functions, `PascalCase` for class/node names, tabs for indentation (Godot default).
- Prefer **signals** for decoupling systems (e.g. task completed → emit signal → building scene listens and plays completion animation) rather than tight coupling between the tracker logic and the visual layer. This keeps the "task tracker is the engine, city is the skin" separation clean and testable.
- Pure logic functions (progress %, XP totals, unlock thresholds) should not depend on the scene tree — they take data in, return data out, so they can be tested independently of the running game.
- No external plugins/addons unless there's a strong, specific reason — keep the addon list short given the hardware constraints on build/import times.

---

## 7. Art Asset Plan — First Playable Demo

Goal: the smallest set of pixel-art assets needed to prove out the core loop (create task → building appears → progress grows it → completing it finishes it), in the simplified style defined in `VISION.md`. Nothing here requires more than a handful of sprites — that's intentional.

### 7.1 Terrain tileset
One small tileset, imported as a single `TileSet` resource in Godot:
- Grass (base tile)
- Dirt / path (for a simple road or walkway between buildings)
- Water (edge + fill, so a small pond/river reads correctly)
- Hill/rock (a raised or textured tile to break up flat grass)
- *(Optional for the demo, can wait)* forest-edge tile

**Count: ~5–6 tiles.** These can be a single 16×16 or 32×32 pixel-per-tile set (pick one size and stay consistent project-wide — this becomes your base grid unit in Godot's `TileMap`).

### 7.2 Decorative scatter sprites
A handful of small non-interactive props to place on top of terrain tiles for visual texture:
- 1 bush
- 1 rock cluster
- 1 tree

**Count: 3 sprites.** These don't need animation for the demo.

### 7.3 Buildings
**2 building types** is enough to prove the system (e.g. a small "house"-style building for short tasks, a larger "workshop"-style building for multi-day projects). Each needs **3 construction-stage sprites**:
1. Foundation / just-started (minimal structure, maybe scaffolding)
2. Mid-construction (partial walls/roof)
3. Complete (full building)

**Count: 2 buildings × 3 stages = 6 sprites.**

Additionally:
- **1 overdue overlay** — a small cracks/dust decal sprite that layers on top of any building stage rather than being baked into separate "overdue" versions of every stage. This keeps the asset count from multiplying.

### 7.4 Villager (construction worker)
- **1 sprite sheet**: an idle pose + a short walk cycle (4–6 frames is plenty). Reused for every "villager" shown near an under-construction building — they don't need to be unique individuals.

### 7.5 UI
Minimal icon set for the demo:
- "Create Task" button/icon
- Confirm/checkmark icon
- Close/cancel icon

**Count: 3 icons.** Plain Godot `Control` nodes (buttons, labels, text fields) handle the rest of the task-creation form — no custom art needed there for the demo.

### 7.6 Effects
- 1 small square/dot texture used with Godot's built-in `GPUParticles2D`/`CPUParticles2D` node to fake chimney smoke or a construction "dust puff." No hand-animated smoke sprite needed — the particle node handles motion/fade on its own.

### 7.7 Demo asset checklist (summary)
| Category | Item | Count |
|---|---|---|
| Terrain | Tileset (grass, path, water, hill) | ~5 tiles |
| Decoration | Bush, rock, tree | 3 sprites |
| Buildings | 2 types × 3 stages | 6 sprites |
| Buildings | Overdue overlay decal | 1 sprite |
| Characters | Villager idle + walk sheet | 1 sheet |
| UI | Create / confirm / cancel icons | 3 icons |
| Effects | Particle dot texture | 1 texture |

Everything beyond this list (additional building types, richer terrain variety, unique villagers, ambient animation) belongs to later passes once the core loop is proven — see `VISION.md` for the longer-term direction and Section 9 below for open questions still to settle.

---

## 8. Out of Scope (for now)

- Multiplayer, cloud sync, or user accounts.
- In-app purchases or any monetization affecting gameplay.
- Any mechanic where the game state can block or gate real task-tracking functionality.
- 3D rendering, real-time lighting/shadows, or shader-heavy effects.
- Web/desktop builds as a primary target (Android is primary; desktop export may be a convenience-only side effect of using Godot).

---

## 9. Open Questions / Decisions Still Needed

- Exact starting grid size (proposal: 5×5 or similar small footprint — to be confirmed once first playable build exists).
- Exact XP curve and level thresholds.
- Whether building "type" is chosen automatically from task metadata or offered as a user choice at creation time.
- Terrain generation approach: hand-authored starter map vs. procedural generation for expanded land.
