# Metropolis

A real-world task/project tracker disguised as a pixel-art isometric city-builder game. The task tracker is the *engine*; the growing city is the *reward*.

> **Status: Design phase.** Core game design and technical conventions are locked in (see docs below). No playable code yet — this repo currently holds planning documents only.

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

## Docs

- **[`AGENTS.md`](./AGENTS.md)** — binding technical rules and conventions: platform choice, hardware constraints, gameplay systems, project structure, coding conventions, and the first-demo art asset plan. Read this before writing or reviewing any code.
- **[`VISION.md`](./VISION.md)** — the design/creative vision this project is building toward: what the game feels like, how the land and buildings work, the visual direction.

## Getting started (once code exists)

1. Install [Godot Engine](https://godotengine.org/download) (stable 4.x, standard/non-.NET build).
2. Clone this repo and open `project.godot` in the Godot editor.
3. Run the project from the editor to test on desktop; use **Project > Export** with the Android export template to build an APK.

Exporting to Android additionally requires the Android SDK command-line tools and a JDK — see Godot's [Android export docs](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) for setup.

## Development environment

Actively developed on modest hardware (a Surface Go 2, 8GB RAM) — see `AGENTS.md` §3 for the specific constraints this places on asset size, rendering choices, and testing workflow.

## License

[GNU GPLv3](./LICENSE).
