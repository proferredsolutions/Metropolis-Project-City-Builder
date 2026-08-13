// progress.js
// Pure functions that turn a task's raw data into visual construction state.
//
// "Pure function" means: same input always produces the same output, and it
// never reads or writes anything outside itself (no localStorage, no DOM).
// That matters here specifically because these functions ARE the game
// design rules — getProgressIncrement() alone encodes all three of your
// task-type behaviors (1-day / multi-day / subtasks) in one formula. Keeping
// it pure means you can test "does a 4-day project really give 25% per day?"
// by calling the function directly with a fake task object — no browser,
// no localStorage, no UI required.

/**
 * How much % progress ONE unit of work is worth for this task.
 * A "unit" is: one subtask checked off, OR one day marked done
 * (for multi-day tasks with no subtasks), OR the whole task at once
 * (for simple 1-day tasks — one tap starts it, one tap finishes it).
 *
 * Examples:
 *   4-day project, no subtasks   -> 100 / 4  = 25   (each day = +25%)
 *   project with 10 subtasks     -> 100 / 10 = 10   (each subtask = +10%)
 *   simple 1-day task            -> 100              (one tap = done)
 */
function getProgressIncrement(task) {
  if (task.subtasks && task.subtasks.length > 0) {
    return 100 / task.subtasks.length;
  }
  if (task.durationDays > 1) {
    return 100 / task.durationDays;
  }
  return 100;
}

/**
 * Converts a 0-100 progress number into one of three visual stages.
 * "construction" covers the entire 1-99 range — the hammer-icon-overhead
 * stage — while the actual height is handled separately by
 * getBuildingHeight() so the building still visibly grows within that range.
 */
function getVisualStage(progress) {
  if (progress <= 0) return "empty";
  if (progress >= 100) return "complete";
  return "construction";
}

/**
 * Smoothly interpolates building height (in px) from progress %.
 * Deliberately NOT bucketed by stage — a 24%-done building is visibly
 * shorter than a 76%-done one, even though both show the same hammer icon.
 * That's what gives the grid real depth without adding extra states.
 */
function getBuildingHeight(progress) {
  const MIN_HEIGHT = 10; // px — bare foundation stub
  const MAX_HEIGHT = 54; // px — fully built
  const clamped = Math.max(0, Math.min(100, progress));
  return MIN_HEIGHT + (MAX_HEIGHT - MIN_HEIGHT) * (clamped / 100);
}

/**
 * Applies ONE unit of progress — one subtask checked, one day marked
 * complete, or the single tap-to-finish for a 1-day task — and returns
 * the resulting progress/stage/completedAt fields.
 *
 * Deliberately does NOT save anything. The caller (your UI code) decides
 * when to persist, using state.js's updateTask(task.id, advanceProgress(task)).
 * This keeps progress.js testable in isolation and keeps "calculate" and
 * "persist" as two separate, single-purpose steps.
 */
function advanceProgress(task) {
  const increment = getProgressIncrement(task);
  const nextProgress = Math.min(100, task.progress + increment);
  return {
    progress: nextProgress,
    stage: getVisualStage(nextProgress),
    completedAt: nextProgress >= 100 ? new Date().toISOString() : null,
  };
}

/**
 * XP reward for finishing a task. Scales with task size — subtask count
 * or day count, whichever the task actually uses — so a quick 1-day task
 * gives less XP than a sprawling multi-day project. This is what the
 * leveling/badge system reads from.
 */
function getXPReward(task) {
  const XP_PER_UNIT = 10;
  const units =
    task.subtasks && task.subtasks.length > 0
      ? task.subtasks.length
      : task.durationDays;
  return units * XP_PER_UNIT;
}

/**
 * Overdue check — visual only, per the "stress-free" design decision.
 * This never blocks or slows progress; it just tells the UI to render
 * cracks/dust on that building. A completed task is never "overdue".
 */
function isOverdue(task) {
  if (!task.dueDate || task.stage === "complete") return false;
  return new Date() > new Date(task.dueDate);
}
