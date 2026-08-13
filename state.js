// state.js
// Task data model + localStorage persistence for Metropolis.
//
// Design note: every function here either READS or WRITES localStorage,
// nothing else. Calculation logic (progress %, XP, visual stage) lives in
// progress.js instead. Keeping "what is the data" separate from "what does
// the data mean visually" makes both files easier to test and reason about
// on their own.

const STORAGE_KEY = "metropolis_tasks";

/**
 * Builds a new task object with sensible defaults.
 * Does NOT save it — call addTask() for that.
 *
 * @param {Object} input - raw fields from the "add task" form
 * @param {string} input.title
 * @param {string} [input.details]
 * @param {{col:number,row:number}} input.gridPosition - which land tile this occupies
 * @param {number} [input.durationDays=1]
 * @param {string[]} [input.subtasks] - plain subtask names; converted to objects here
 * @param {string|null} [input.dueDate] - ISO date string
 * @param {"low"|"normal"|"high"} [input.priority="normal"]
 * @returns {Object} a fully-formed task, ready to save
 */
function createTask(input) {
  return {
    id: crypto.randomUUID(),
    title: input.title,
    details: input.details || "",
    gridPosition: input.gridPosition, // { col, row } — which land tile this occupies
    durationDays: input.durationDays || 1,
    subtasks: (input.subtasks || []).map((name) => ({
      id: crypto.randomUUID(),
      name,
      completed: false,
    })),
    dueDate: input.dueDate || null,
    priority: input.priority || "normal", // "low" | "normal" | "high" — drives building size/type

    // Everything below is progress state, calculated/updated by progress.js
    // but stored here so it survives a page reload.
    progress: 0, // 0-100
    stage: "empty", // "empty" | "foundation" | "construction" | "complete"
    startedAt: null,
    completedAt: null,
    createdAt: new Date().toISOString(),
  };
}

/** Loads all tasks from localStorage. Returns [] if none exist yet or data is corrupted. */
function loadTasks() {
  const raw = localStorage.getItem(STORAGE_KEY);
  if (!raw) return [];
  try {
    return JSON.parse(raw);
  } catch (err) {
    console.error("Metropolis: corrupted task data in localStorage, resetting.", err);
    return [];
  }
}

/** Persists the full tasks array back to localStorage. */
function saveTasks(tasks) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(tasks));
}

/**
 * Creates a task, saves it, and returns it — the one function the
 * "add task" form actually needs to call.
 */
function addTask(input) {
  const tasks = loadTasks();
  const task = createTask(input);
  tasks.push(task);
  saveTasks(tasks);
  return task;
}

/** Finds a single task by id. Returns null if not found. */
function getTask(id) {
  return loadTasks().find((t) => t.id === id) || null;
}

/**
 * Updates a task by id using an immutable-style spread merge — we never
 * mutate the existing task object directly, we build a new one and swap
 * it into the array. This avoids a whole class of "I changed the object
 * but forgot to save" bugs.
 *
 * @param {string} id
 * @param {Object} updates - fields to overwrite, e.g. { progress: 25, stage: "construction" }
 * @returns {Object|null} the updated task, or null if no task had that id
 */
function updateTask(id, updates) {
  const tasks = loadTasks();
  const index = tasks.findIndex((t) => t.id === id);
  if (index === -1) return null;

  tasks[index] = { ...tasks[index], ...updates };
  saveTasks(tasks);
  return tasks[index];
}

/** Deletes a task by id. Returns true if a task was actually removed. */
function deleteTask(id) {
  const tasks = loadTasks();
  const next = tasks.filter((t) => t.id !== id);
  saveTasks(next);
  return next.length !== tasks.length;
}
