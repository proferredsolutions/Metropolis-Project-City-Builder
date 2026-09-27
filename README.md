# Metropolis

A real-world task/project tracker disguised as a pixel-art isometric city-builder game. The task tracker is the *engine*; the growing city is the *reward*.

> **Status: playable first slice.** The core loop works end to end: create a task on a tile, a building appears under construction, real progress on the task grows it, finishing the task finishes the building, and XP unlocks more land and styles. See [What's in the demo](#whats-in-the-demo).

## The idea

Every task or project you create becomes a building on a small plot of land. Real progress on the task — not app opens, not time pressure — grows the building through construction stages. Finish the task, finish the building. Level up over time and unlock more land, new building styles, and decorations — all cosmetic, never gameplay-gating. Overdue tasks get a purely visual "needs attention" marker (cracks, dust) and nothing more; there's no fail state.

## Tech stack

| Layer | Choice |
|---|---|
| Engine | [Godot Engine](https://godotengine.org/) (stable 4.x) |
| Language | GDScript |
| Rendering | Godot's native 2D renderer (`TileMap` + sprites) — no HTML/CSS/DOM |
| Target | Native Android (APK/AAB via Godot's Android export) |
| Persistence | Local file storage via Godot's `user://` API (JSON), no backend |
| Art style | Simplified pixel-art / low-detail 2D isometric |

## What's in the demo

- **Tap-to-build** — tap a free tile to open the task form; tap a building to open its details.
- **Two building types** — a Cottage for short tasks, a Workshop for long or multi-step ones. The type is derived from real task metadata, and falls back to the Cottage (never to "no building") when the style isn't unlocked yet.
- **Real progress drives construction** — subtask completion drives stage progression directly; a task with only a deadline grows as the days pass, but time alone never finishes a building.
- **Villagers** — a worker sprite walks the site while a building is under construction; chimney smoke starts when it's done.
- **Overdue is cosmetic** — a cracks/dust decal fades in over the building and reverts as soon as the task is back on track or complete. Nothing is blocked, deleted or punished.
- **XP, levels, land** — completing tasks earns XP scaled to their size; levels unlock the Workshop style, more decoration props and more buildable land (5×5 → up to 12×12).
- **Pan / pinch / tap** — drag to pan, pinch or scroll to zoom, tap to select.
- **Auto-save** — everything is written to `user://metropolis_save.json` as readable JSON; there is no backend and no account.

### Controls

| Input | Action |
|---|---|
| Drag / arrow-free touch drag | Pan the city |
| Pinch / mouse wheel | Zoom in and out |
| Tap a free tile | Create a task there |
| Tap a building | Open the task's details |
| **New Task** button | Create a task on the first free tile |

## Getting started

1. Install [Godot Engine](https://godotengine.org/download) (stable 4.3, standard/non-.NET build).
2. Clone this repo and open `project.godot` in the Godot editor, or run it directly:
   ```bash
   godot --path .                      # play
   godot --headless --path . --import # (re)import assets
   ```
3. To build an APK: **Project > Export** with the Android export template. Exporting to Android additionally requires the Android SDK command-line tools and a JDK — see Godot's [Android export docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html).

## Project structure

```
metropolis/
├── project.godot
├── scenes/
│   ├── main/main.tscn            # Root scene: camera rig, world, UI layer
│   ├── grid/city_grid.tscn       # TileMap + decoration props + tap highlight
│   ├── buildings/building.tscn   # One building: stage sprite, villager, smoke, decal
│   └── ui/                       # HUD, task creation form, task detail panel
├── scripts/
│   ├── data/                     # TaskData model, save manager, GameState (autoloads)
│   ├── systems/                  # Pure logic: progress, XP/levels, grid, building catalog
│   └── ui/                       # View controllers + main scene controller
├── assets/sprites/               # Generated pixel art (see tools/)
├── tests/                        # Headless unit tests + scene smoke test
└── tools/generate_assets.py      # Regenerates every sprite and the TileSet
```

Game logic lives in plain classes under `scripts/systems/` and never touches the scene tree, so the progress/XP/grid math is unit testable on its own. The view layer talks to it through signals (`GameState` → buildings, HUD, panels).

## Tests

```bash
godot --headless --path . --script res://tests/test_runner.gd  # pure logic
godot --headless --path . res://tests/smoke.tscn              # full scene, headless
```

Both print a `passed / failed` summary and exit non-zero on failure; CI runs them on every push.

## Regenerating the art

All sprites are generated procedurally from a single palette, with no image libraries required:

```bash
python3 tools/generate_assets.py
```

This rewrites the terrain tileset (+ its `TileSet` resource), the props, the building stages, the villager sheet, the UI icons and the particle dot.

## Docs

- **[`AGENTS.md`](./AGENTS.md)** — binding technical rules and conventions: platform choice, hardware constraints, gameplay systems, project structure, coding conventions, and the first-demo art asset plan. Read this before writing or reviewing any code.
- **[`VISION.md`](./VISION.md)** — the design/creative vision this project is building toward: what the game feels like, how the land and buildings work, the visual direction.

## Development environment

Actively developed on modest hardware (a Surface Go 2, 8GB RAM) — see `AGENTS.md` §3 for the specific constraints this places on asset size, rendering choices, and testing workflow.

## License

[GNU GPLv3](./LICENSE).
