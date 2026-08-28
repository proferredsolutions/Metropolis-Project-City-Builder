// render.js
// Reads tasks from state.js, draws the 5x5 isometric grid using
// progress.js's calculations, and wires up HUD & modal UI interactions.

const GRID_SIZE = 5;
const TILE_SIZE = 90; // px — spacing between tile centers on the grid

const STAGE_COLORS = {
  foundation: { top: "#B4B2A9", front: "#888780", right: "#5F5E5A" },
  construction: { top: "#EF9F27", front: "#D85A30", right: "#993C1D" },
  complete: { top: "#5DCAA5", front: "#1D9E75", right: "#0F6E56" },
};

// Priority building color overrides for visual variety
const PRIORITY_COLORS = {
  high: { top: "#f39c12", front: "#e67e22", right: "#d35400" },
  low: { top: "#3498db", front: "#2980b9", right: "#1f618d" },
};

// Selected position for the "Add Task" modal
let pendingGridPos = null;
let activeTaskModalId = null;

/** Finds the task occupying a given grid cell, or null if the cell is empty. */
function taskAtPosition(tasks, col, row) {
  return (
    tasks.find(
      (t) => t.gridPosition.col === col && t.gridPosition.row === row
    ) || null
  );
}

/** Calculates total earned XP across all completed and partially completed tasks. */
function calculateTotalXP(tasks) {
  return tasks.reduce((total, task) => {
    const reward = getXPReward(task);
    return total + Math.floor((task.progress / 100) * reward);
  }, 0);
}

/** Calculates current Level and current Level progress from total XP. */
function getLevelInfo(totalXP) {
  // Level threshold: 100 XP per level
  const XP_PER_LEVEL = 100;
  const level = Math.floor(totalXP / XP_PER_LEVEL) + 1;
  const xpInCurrentLevel = totalXP % XP_PER_LEVEL;
  return { level, xpInCurrentLevel, xpForNextLevel: XP_PER_LEVEL };
}

/**
 * Updates HUD header elements (Level, XP bar, completed count, active count).
 * Accepts an optional pre-loaded `tasks` array to avoid redundant localStorage
 * reads and JSON deserialization when called during render sweeps.
 */
function updateHUD(tasks = loadTasks()) {
  const totalXP = calculateTotalXP(tasks);
  const { level, xpInCurrentLevel, xpForNextLevel } = getLevelInfo(totalXP);

  const levelValEl = document.getElementById("hud-level-val");
  const xpValEl = document.getElementById("hud-xp-val");
  const xpFillEl = document.getElementById("hud-xp-fill");
  const completedValEl = document.getElementById("hud-completed-val");
  const activeValEl = document.getElementById("hud-active-val");

  if (levelValEl) levelValEl.textContent = level;
  if (xpValEl) xpValEl.textContent = `${xpInCurrentLevel} / ${xpForNextLevel} XP`;
  if (xpFillEl) xpFillEl.style.width = `${(xpInCurrentLevel / xpForNextLevel) * 100}%`;

  const completedTasks = tasks.filter((t) => t.stage === "complete").length;
  const activeTasks = tasks.filter((t) => t.stage !== "complete").length;

  if (completedValEl) completedValEl.textContent = completedTasks;
  if (activeValEl) activeValEl.textContent = activeTasks;
}

/** Builds one tile's DOM element. */
function buildTileElement(col, row, task) {
  const tile = document.createElement("div");
  tile.className = "tile";
  tile.dataset.col = col;
  tile.dataset.row = row;

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
    const stage = task.stage === "empty" ? "foundation" : task.stage;

    // Choose color set based on priority or stage
    let colors = STAGE_COLORS[stage] || STAGE_COLORS.foundation;
    if (stage === "complete" && PRIORITY_COLORS[task.priority]) {
      colors = PRIORITY_COLORS[task.priority];
    }

    const w = TILE_SIZE * 0.55;
    const hw = w / 2;

    const front = document.createElement("div");
    front.className = "face windows";
    front.style.width = w + "px";
    front.style.height = height + "px";
    front.style.left = -hw + "px";
    front.style.top = -(height / 2) + "px";
    front.style.background = colors.front;
    front.style.transform = `translateZ(${hw}px)`;

    const right = document.createElement("div");
    right.className = "face windows";
    right.style.width = w + "px";
    right.style.height = height + "px";
    right.style.left = -hw + "px";
    right.style.top = -(height / 2) + "px";
    right.style.background = colors.right;
    right.style.transform = `rotateY(90deg) translateZ(${hw}px)`;

    const top = document.createElement("div");
    top.className = "face roof";
    top.style.width = w + "px";
    top.style.height = w + "px";
    top.style.left = -hw + "px";
    top.style.top = -hw + "px";
    top.style.background = colors.top;
    top.style.transform = `rotateX(90deg) translateZ(${height / 2}px)`;

    tile.appendChild(front);
    tile.appendChild(right);
    tile.appendChild(top);

    if (stage === "construction") {
      const crane = document.createElement("div");
      crane.className = "construction-crane";
      crane.textContent = "🏗️";
      tile.appendChild(crane);
    }

    if (isOverdue(task)) {
      tile.classList.add("overdue");
    }
  }

  tile.addEventListener("click", () => handleTileClick(col, row, task));
  return tile;
}

/** Renders or updates a single tile at (col, row). */
function renderTileAt(col, row) {
  const world = document.getElementById("world");
  if (!world) return;

  // Single loadTasks call passed through to helper functions to avoid redundant reads
  const tasks = loadTasks();
  const task = taskAtPosition(tasks, col, row);
  const newTile = buildTileElement(col, row, task);

  const existingTile = world.querySelector(`[data-col="${col}"][data-row="${row}"]`);
  if (existingTile) {
    world.replaceChild(newTile, existingTile);
  } else {
    world.appendChild(newTile);
  }

  updateHUD(tasks);
  renderTaskList(tasks);
}

/** Clears and redraws the entire grid. */
function renderGrid() {
  const world = document.getElementById("world");
  if (!world) return;
  world.innerHTML = "";

  // Single loadTasks call passed through to helper functions to avoid redundant reads
  const tasks = loadTasks();

  for (let row = 0; row < GRID_SIZE; row++) {
    for (let col = 0; col < GRID_SIZE; col++) {
      const task = taskAtPosition(tasks, col, row);
      world.appendChild(buildTileElement(col, row, task));
    }
  }

  updateHUD(tasks);
  renderTaskList(tasks);
}

/**
 * Renders the list of active tasks in the sidebar panel.
 * Accepts an optional pre-loaded `tasks` array to avoid redundant localStorage
 * reads and JSON deserialization when called during render sweeps.
 */
function renderTaskList(tasks = loadTasks()) {
  const listEl = document.getElementById("sidebar-task-list");
  if (!listEl) return;
  if (tasks.length === 0) {
    listEl.innerHTML = `<div style="color: #82908a; font-size: 0.8rem; text-align: center; padding: 12px;">No active buildings. Click an empty plot on the grid to build one!</div>`;
    return;
  }

  listEl.innerHTML = "";
  tasks.forEach((task) => {
    const item = document.createElement("div");
    item.className = "task-item";
    item.onclick = () => openTaskInspectorModal(task.id);

    const info = document.createElement("div");
    info.className = "task-item-info";

    const title = document.createElement("span");
    title.className = "task-item-title";
    title.textContent = task.title;

    const meta = document.createElement("span");
    meta.className = "task-item-meta";
    meta.textContent = `Plot (${task.gridPosition.col}, ${task.gridPosition.row}) • ${Math.round(task.progress)}% built`;

    info.appendChild(title);
    info.appendChild(meta);

    const badge = document.createElement("span");
    badge.className = `task-item-badge badge-${task.priority}`;
    badge.textContent = task.priority;

    item.appendChild(info);
    item.appendChild(badge);
    listEl.appendChild(item);
  });
}

/** Tile click handler. */
function handleTileClick(col, row, task) {
  if (!task) {
    openAddTaskModal(col, row);
  } else {
    openTaskInspectorModal(task.id);
  }
}

/** Modal Management */
function openAddTaskModal(col, row) {
  pendingGridPos = { col, row };
  const modal = document.getElementById("add-task-modal");
  if (!modal) return;

  document.getElementById("task-title-input").value = "";
  document.getElementById("task-details-input").value = "";
  document.getElementById("task-duration-input").value = "1";
  document.getElementById("task-subtasks-input").value = "";
  document.getElementById("task-due-input").value = "";
  setPriorityOption("normal");

  modal.classList.remove("hidden");
}

function closeAddTaskModal() {
  const modal = document.getElementById("add-task-modal");
  if (modal) modal.classList.add("hidden");
  pendingGridPos = null;
}

function setPriorityOption(priority) {
  document.querySelectorAll(".radio-option").forEach((opt) => {
    opt.classList.toggle("selected", opt.dataset.priority === priority);
  });
}

function handleAddTaskSubmit(e) {
  e.preventDefault();
  if (!pendingGridPos) return;

  const title = document.getElementById("task-title-input").value.trim();
  if (!title) return;

  const details = document.getElementById("task-details-input").value.trim();
  const durationDays = parseInt(document.getElementById("task-duration-input").value, 10) || 1;
  const rawSubtasks = document.getElementById("task-subtasks-input").value;
  const subtasks = rawSubtasks
    ? rawSubtasks.split(",").map((s) => s.trim()).filter(Boolean)
    : [];
  const dueDate = document.getElementById("task-due-input").value || null;

  const selectedPriorityEl = document.querySelector(".radio-option.selected");
  const priority = selectedPriorityEl ? selectedPriorityEl.dataset.priority : "normal";

  addTask({
    title,
    details,
    gridPosition: pendingGridPos,
    durationDays,
    subtasks,
    dueDate,
    priority,
  });

  const { col, row } = pendingGridPos;
  closeAddTaskModal();
  renderTileAt(col, row);
}

/** Task Inspector Modal */
function openTaskInspectorModal(taskId) {
  const task = getTask(taskId);
  if (!task) return;

  activeTaskModalId = taskId;
  const modal = document.getElementById("inspector-modal");
  if (!modal) return;

  document.getElementById("inspector-title").textContent = task.title;
  document.getElementById("inspector-details").textContent = task.details || "No details provided.";
  document.getElementById("inspector-meta").textContent = `Plot (${task.gridPosition.col}, ${task.gridPosition.row}) • Duration: ${task.durationDays} day(s) • Priority: ${task.priority}`;
  document.getElementById("inspector-progress-text").textContent = `${Math.round(task.progress)}% Complete (${task.stage.toUpperCase()})`;

  const subtaskListEl = document.getElementById("inspector-subtasks");
  subtaskListEl.innerHTML = "";

  if (task.subtasks && task.subtasks.length > 0) {
    task.subtasks.forEach((st) => {
      const item = document.createElement("div");
      item.className = "subtask-item";

      const checkbox = document.createElement("input");
      checkbox.type = "checkbox";
      checkbox.checked = st.completed;
      checkbox.onchange = (e) => toggleSubtask(task.id, st.id, e.target.checked);

      const label = document.createElement("span");
      label.textContent = st.name;
      if (st.completed) label.style.textDecoration = "line-through";

      item.appendChild(checkbox);
      item.appendChild(label);
      subtaskListEl.appendChild(item);
    });
  } else {
    subtaskListEl.innerHTML = `<div style="color: #82908a; font-size: 0.8rem;">Daily progress mode</div>`;
  }

  const advanceBtn = document.getElementById("inspector-advance-btn");
  if (task.stage === "complete") {
    advanceBtn.disabled = true;
    advanceBtn.textContent = "Fully Constructed!";
  } else {
    advanceBtn.disabled = false;
    advanceBtn.textContent = "⚡ Advance Work Progress";
  }

  modal.classList.remove("hidden");
}

function closeTaskInspectorModal() {
  const modal = document.getElementById("inspector-modal");
  if (modal) modal.classList.add("hidden");
  activeTaskModalId = null;
}

function toggleSubtask(taskId, subtaskId, isChecked) {
  const task = getTask(taskId);
  if (!task) return;

  const nextSubtasks = task.subtasks.map((st) =>
    st.id === subtaskId ? { ...st, completed: isChecked } : st
  );

  const completedCount = nextSubtasks.filter((st) => st.completed).length;
  const newProgress = Math.min(100, Math.round((completedCount / nextSubtasks.length) * 100));

  updateTask(taskId, {
    subtasks: nextSubtasks,
    progress: newProgress,
    stage: getVisualStage(newProgress),
    completedAt: newProgress >= 100 ? new Date().toISOString() : null,
  });

  renderTileAt(task.gridPosition.col, task.gridPosition.row);
  openTaskInspectorModal(taskId); // Refresh modal view
}

function handleAdvanceProgressClick() {
  if (!activeTaskModalId) return;
  const task = getTask(activeTaskModalId);
  if (!task) return;

  const updates = advanceProgress(task);
  updateTask(task.id, updates);

  renderTileAt(task.gridPosition.col, task.gridPosition.row);
  if (updates.progress >= 100) {
    closeTaskInspectorModal();
  } else {
    openTaskInspectorModal(task.id);
  }
}

function handleDemolishTaskClick() {
  if (!activeTaskModalId) return;
  const task = getTask(activeTaskModalId);
  if (!task) return;

  if (confirm(`Demolish building "${task.title}"?`)) {
    const { col, row } = task.gridPosition;
    deleteTask(task.id);
    closeTaskInspectorModal();
    renderTileAt(col, row);
  }
}

document.addEventListener("DOMContentLoaded", () => {
  renderGrid();

  // Wire radio buttons
  document.querySelectorAll(".radio-option").forEach((opt) => {
    opt.addEventListener("click", () => setPriorityOption(opt.dataset.priority));
  });

  // Wire Add Task Form
  const addForm = document.getElementById("add-task-form");
  if (addForm) addForm.addEventListener("submit", handleAddTaskSubmit);

  const closeAddBtn = document.getElementById("close-add-modal");
  if (closeAddBtn) closeAddBtn.addEventListener("click", closeAddTaskModal);

  const cancelAddBtn = document.getElementById("cancel-add-modal");
  if (cancelAddBtn) cancelAddBtn.addEventListener("click", closeAddTaskModal);

  // Wire Inspector Modal
  const closeInspectorBtn = document.getElementById("close-inspector-modal");
  if (closeInspectorBtn) closeInspectorBtn.addEventListener("click", closeTaskInspectorModal);

  const advanceBtn = document.getElementById("inspector-advance-btn");
  if (advanceBtn) advanceBtn.addEventListener("click", handleAdvanceProgressClick);

  const demolishBtn = document.getElementById("inspector-demolish-btn");
  if (demolishBtn) demolishBtn.addEventListener("click", handleDemolishTaskClick);
});
