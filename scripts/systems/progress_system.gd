## Converts real-world task state into the numbers the city is drawn from.
##
## Pure functions only — no scene tree access — so the whole progress model is
## unit testable (see tests/test_runner.gd).
class_name ProgressSystem
extends RefCounted

const DAY_SECONDS := 86400

## Number of construction stages a building has (foundation / mid / complete).
const STAGE_COUNT := 3

## A time-driven task never *looks* finished on its own: only the user finishing
## the task completes the building. This is the ceiling for elapsed-time progress.
const TIME_PROGRESS_CEILING := 0.99


## How far along the task really is, 0.0 - 1.0.
##
## - completed tasks are always 1.0
## - tasks with subtasks are driven by `completed_subtasks / total_subtasks`
## - multi-day tasks without subtasks are driven by `days_elapsed / duration_days`
## - everything else is 0.0 until it is done
static func get_progress(task: TaskData, now_unix: int = 0) -> float:
	if task == null:
		return 0.0
	if task.completed:
		return 1.0

	var total_subtasks := task.get_subtask_count()
	if total_subtasks > 0:
		return clampf(float(task.get_completed_subtask_count()) / float(total_subtasks), 0.0, 1.0)

	var duration := get_duration_days(task)
	if duration > 0.0 and task.start_unix > 0:
		var elapsed_days := float(now_unix - task.start_unix) / float(DAY_SECONDS)
		return clampf(elapsed_days / duration, 0.0, TIME_PROGRESS_CEILING)

	return 0.0


## How much *new* real progress happened, never negative.
static func get_progress_increment(previous: float, current: float) -> float:
	return maxf(0.0, current - previous)


## Which construction-stage sprite to show for a given progress value.
static func get_visual_stage(progress: float) -> int:
	if progress <= 0.0:
		return 0
	if progress < 0.34:
		return 0
	if progress < 0.67:
		return 1
	return 2


## Smooth building height so construction grows continuously instead of snapping
## between stages. Returns 0.35 (foundation) - 1.0 (finished).
static func get_building_height(progress: float) -> float:
	var t := clampf(progress, 0.0, 1.0)
	return 0.35 + 0.65 * t


## Whole days between start and due date, or 0.0 when the task has no deadline.
static func get_duration_days(task: TaskData) -> float:
	if task == null or task.start_unix <= 0 or task.due_unix <= task.start_unix:
		return 0.0
	return float(task.due_unix - task.start_unix) / float(DAY_SECONDS)


## Overdue is a *visual* state only — it never blocks or removes anything.
static func is_overdue(task: TaskData, now_unix: int) -> bool:
	if task == null or task.completed:
		return false
	if task.due_unix <= 0:
		return false
	return now_unix > task.due_unix


## Days until the deadline. Negative once overdue.
static func get_days_remaining(task: TaskData, now_unix: int) -> int:
	if task == null or task.due_unix <= 0:
		return -1
	return int(floor(float(task.due_unix - now_unix) / float(DAY_SECONDS)))


static func format_days_remaining(task: TaskData, now_unix: int) -> String:
	if task == null or task.due_unix <= 0:
		return "No deadline"
	if task.completed:
		return "Completed"
	var days := get_days_remaining(task, now_unix)
	if days < 0:
		return "%d day(s) overdue" % abs(days)
	if days == 0:
		return "Due today"
	return "%d day(s) left" % days
