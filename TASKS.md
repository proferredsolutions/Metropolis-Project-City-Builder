# Metropolis — Build Order Backlog

## Done
- [x] `AGENT.md` — project conventions, rules, and architecture decisions
- [x] `TASKS.md` — this file
- [x] `state.js` — task data model + CRUD via `localStorage`
      (`createTask`, `loadTasks`, `saveTasks`, `addTask`, `getTask`,
      `updateTask`, `deleteTask`)
- [x] `progress.js` — pure functions turning task data into visual state
      (`getProgressIncrement`, `getVisualStage`, `getBuildingHeight`,
      `advanceProgress`, `getXPReward`, `isOverdue`) — tested with 13
      passing assertions against the worked examples from design

## Up Next
- [ ] `index.html` — app shell; loads `state.js` then `progress.js` then
      render/UI scripts in order
- [ ] `base.css` — resets, page layout, typography
- [ ] `isometric.css` — world tilt (`rotateX(55deg) rotateZ(45deg)`) and
      cube-face styling for grid tiles and buildings
- [ ] `render.js` — reads tasks via `loadTasks()`, draws the 5x5 isometric
      grid, and redraws a single tile whenever its task updates
- [ ] "Add task" form/modal — tapping an empty tile opens a form (title,
      details, duration or subtasks, due date, priority); on submit, calls
      `addTask()`
- [ ] Tap-to-advance interaction — tapping a mid-construction building
      marks the next day/subtask complete via `advanceProgress()`; tapping
      a completed building shows its details
- [ ] Overdue visual pass — cracks/dust overlay driven by `isOverdue()`
- [ ] XP + leveling system — track total XP, define level thresholds,
      persist current level in `localStorage`
- [ ] Level-up unlock system — new building skins and special decorative
      buildings tied to level, purely cosmetic
- [ ] `ui.css` — HUD styling (XP bar, level badge, "add task" modal)

## Later / v2 ideas
- [ ] Grid expansion as a level-up reward (currently fixed at 5x5)
- [ ] Building size/type variety driven by task priority or duration
      (small hut for a quick task vs. a cathedral for a big project)
- [ ] Optional lightweight backend (e.g. Flask) for cross-device sync, only
      if local-only storage becomes a real limitation
