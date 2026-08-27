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
- [x] `index.html` — app shell; loads `state.js` then `progress.js` then
      render/UI scripts in order
- [x] `base.css` — resets, page layout, typography
- [x] `isometric.css` — world tilt (`rotateX(55deg) rotateZ(45deg)`) and
      cube-face styling for grid tiles and buildings (roofs, windows, crane animations)
- [x] `ui.css` — HUD styling (XP bar, level badge, stats, modals, task cards)
- [x] `render.js` — reads tasks via `loadTasks()`, draws the 5x5 isometric
      grid, handles single tile re-rendering, HUD updates, and task lists
- [x] "Add task" form/modal — tapping an empty tile opens a modal (title,
      details, scale/priority, duration, subtasks, due date); on submit, calls
      `addTask()`
- [x] Tap-to-advance interaction — tapping an occupied tile opens the Task Inspector
      modal to advance progress, check off subtasks, or demolish buildings
- [x] Overdue visual pass — warning badge and red border highlights driven by `isOverdue()`
- [x] XP + leveling system — track total XP, compute level & level progress,
      persist level state via task rewards

## Later / v2 ideas
- [ ] Grid expansion as a level-up reward (currently fixed at 5x5)
- [ ] Building size/type variety driven by task priority or duration
      (small hut for a quick task vs. a cathedral for a big project)
- [ ] Optional lightweight backend (e.g. Flask) for cross-device sync, only
      if local-only storage becomes a real limitation
