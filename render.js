// render.js
// Reads tasks from state.js, draws the 5x5 isometric grid using
// progress.js's calculations, and wires up click interactions.
//
// This file is deliberately just glue: it contains no progress math and no
// direct localStorage calls beyond what state.js exposes. Every "what
// should this look like" decision already lives in progress.js — this file
// only turns those answers into DOM elements.

const GRID_SIZE = 5;
const TILE_SIZE = 90; // px — spacing between tile centers on the grid

const STAGE_COLORS = {
  foundation: { top: "#B4B2A9", front: "#888780", right: "#5F5E5A" },
  construction: { top: "#EF9F27", front: "#D85A30", right: "#993C1D" },
  complete: { top: "#5DCAA5", front: "#1D9E75", right: "#0F6E56" },
};

/** Finds the task occupying a given grid cell, or null if the cell is empty. */
function taskAtPosition(tasks, col, row) {
  return (
    tasks.find(
      (t) => t.gridPosition.col === col && t.gridPosition.row === row
    ) || null
  );
}

/** Builds one tile's DOM (ground square + building, if occupied). */
function buildTileElement(col, row, task) {
  const tile = document.createElement("div");
  tile.className = "tile";

  // Center the grid: with GRID_SIZE=5, columns/rows 0-4 map to
  // offsets -2..+2 around the middle, in TILE_SIZE steps.
  const x = (col - (GRID_SIZE - 1) / 2) * TILE_SIZE;
  const y = (row - (GRID_SIZE - 1) / 2) * TILE_SIZE;
  tile.style.transform = `translate3d(${x}px, ${y}px, 0)`;

  const ground = document.createElement("div");
  ground.className = "tile-ground " + (task ? "occupied" : "empty");
  ground.style.width = TILE_SIZE + "px";
  ground.style.height = TILE_SIZE + "px";
  ground.style.left = -(TILE_SIZE / 2) + "px";
  ground.style.top = -(TILE_SIZE / 2) + "px";
  tile.appendChild(ground);

  if (task) {
    const height = getBuildingHeight(task.progress);
    // A task should never actually be in "empty" stage once it exists —
    // this fallback just guards against bad data during development.
    const stage = task.stage === "empty" ? "foundation" : task.stage;
    const colors = STAGE_COLORS[stage] || STAGE_COLORS.foundation;
    const w = TILE_SIZE * 0.55;
    const hw = w / 2;

    const front = document.createElement("div");
    front.className = "face";
    front.style.width = w + "px";
    front.style.height = height + "px";
    front.style.left = -hw + "px";
    front.style.top = -(height / 2) + "px";
    front.style.background = colors.front;
    front.style.transform = `translateZ(${hw}px)`;

    const right = document.createElement("div");
    right.className = "face";
    right.style.width = w + "px";
    right.style.height = height + "px";
    right.style.left = -hw + "px";
    right.style.top = -(height / 2) + "px";
    right.style.background = colors.right;
    right.style.transform = `rotateY(90deg) translateZ(${hw}px)`;

    const top = document.createElement("div");
    top.className = "face";
    top.style.width = w + "px";
    top.style.height = w + "px";
    top.style.left = -hw + "px";
    top.style.top = -hw + "px";
    top.style.background = colors.top;
    top.style.transform = `rotateX(90deg) translateZ(${height / 2}px)`;

    tile.appendChild(front);
    tile.appendChild(right);
    tile.appendChild(top);

    if (isOverdue(task)) {
      // Hook only — the actual cracks/dust visual is a separate TASKS.md item.
      tile.classList.add("overdue");
    }
  }

  tile.addEventListener("click", () => handleTileClick(col, row, task));
  return tile;
}

/** Clears and redraws the entire grid from current task data. */
function renderGrid() {
  const world = document.getElementById("world");
  world.innerHTML = "";
  const tasks = loadTasks();

  for (let row = 0; row < GRID_SIZE; row++) {
    for (let col = 0; col < GRID_SIZE; col++) {
      const task = taskAtPosition(tasks, col, row);
      world.appendChild(buildTileElement(col, row, task));
    }
  }
}

/**
 * Handles a tap on a tile.
 *
 * Empty tile -> quick-add a task. A real "add task" modal with duration/
 * subtask/priority fields is still on TASKS.md; this uses prompt() as a
 * placeholder so the full create-to-complete loop is testable today.
 *
 * Occupied tile -> advance its progress by one unit (one day, one subtask,
 * or full completion for a 1-day task) and re-render.
 */
function handleTileClick(col, row, task) {
  if (!task) {
    const title = prompt("New task/project name:");
    if (!title) return;
    addTask({ title, gridPosition: { col, row }, durationDays: 1 });
    renderGrid();
    return;
  }

  const updates = advanceProgress(task);
  updateTask(task.id, updates);
  renderGrid();
}

document.addEventListener("DOMContentLoaded", renderGrid);
