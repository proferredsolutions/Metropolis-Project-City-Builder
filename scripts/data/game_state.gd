## The single source of truth for the player's city: every task, the XP/level
## progression and the unlocked land.
##
## Autoloaded as `GameState`. Emits signals so the visual layer (buildings, HUD)
## stays decoupled from the tracker logic — see AGENTS.md §6.
extends Node

signal tasks_loaded
signal task_added(task: TaskData)
signal task_updated(task: TaskData)
signal task_removed(task_id: String)
signal task_completed(task: TaskData)
signal xp_changed(xp: int, level: int)
signal level_up(level: int)
signal grid_changed(grid_size: int)

## task id -> TaskData
var tasks: Dictionary = {}
## Vector2i -> terrain id. Generated once for the whole world so that terrain
## under an existing building never shifts when new land unlocks.
var terrain: Dictionary = {}
## Vector2i -> task id, for anything occupying a tile.
var occupied: Dictionary = {}

var xp: int = 0
var level: int = 1
var grid_size: int = GridSystem.MIN_GRID_SIZE


func _ready() -> void:
	terrain = GridSystem.generate_starter_terrain(GridSystem.MAX_GRID_SIZE)
	load_game()


func now_unix() -> int:
	return int(Time.get_unix_time_from_system())


# --------------------------------------------------------------------------- #
# Persistence
# --------------------------------------------------------------------------- #
func load_game() -> void:
	var data: Dictionary = SaveManager.load_data()
	if data.is_empty():
		tasks_loaded.emit()
		return

	xp = int(data.get("xp", 0))
	level = XpSystem.get_level_for_xp(xp)
	grid_size = clampi(int(data.get("grid_size", GridSystem.MIN_GRID_SIZE)), GridSystem.MIN_GRID_SIZE, GridSystem.MAX_GRID_SIZE)

	tasks.clear()
	occupied.clear()
	for raw in data.get("tasks", []):
		if raw is Dictionary:
			var task := TaskData.from_dict(raw)
			if task.id.is_empty():
				continue
			tasks[task.id] = task
			for cell in GridSystem.footprint(task.cell, task.size):
				occupied[cell] = task.id

	tasks_loaded.emit()
	xp_changed.emit(xp, level)
	grid_changed.emit(grid_size)


func save() -> void:
	var serialized := []
	for task in tasks.values():
		serialized.append((task as TaskData).to_dict())
	SaveManager.save_data({
		"xp": xp,
		"level": level,
		"grid_size": grid_size,
		"tasks": serialized,
	})


func reset() -> void:
	tasks.clear()
	occupied.clear()
	xp = 0
	level = 1
	grid_size = GridSystem.MIN_GRID_SIZE
	SaveManager.clear_save()
	tasks_loaded.emit()
	xp_changed.emit(xp, level)
	grid_changed.emit(grid_size)


# --------------------------------------------------------------------------- #
# Queries
# --------------------------------------------------------------------------- #
func get_task(task_id: String) -> TaskData:
	return tasks.get(task_id, null)


func get_task_at_cell(cell: Vector2i) -> TaskData:
	var task_id: String = occupied.get(cell, "")
	return get_task(task_id) if not task_id.is_empty() else null


## Every task, ordered for display: unfinished first, then by cell.
func get_tasks_sorted() -> Array[TaskData]:
	var list: Array[TaskData] = []
	for task in tasks.values():
		list.append(task)
	list.sort_custom(func(a: TaskData, b: TaskData) -> bool:
		if a.completed != b.completed:
			return not a.completed
		if a.cell.y != b.cell.y:
			return a.cell.y < b.cell.y
		return a.cell.x < b.cell.x)
	return list


func get_terrain(cell: Vector2i) -> int:
	return int(terrain.get(cell, GridSystem.Terrain.GRASS))


func can_place_at(cell: Vector2i, size: int) -> bool:
	return GridSystem.can_place(cell, size, grid_size, terrain, occupied)


## First free, buildable tile — used by the HUD "New task" button.
func find_free_cell(size: int = 1) -> Vector2i:
	for y in grid_size:
		for x in grid_size:
			var cell := Vector2i(x, y)
			if can_place_at(cell, size):
				return cell
	return Vector2i(-1, -1)


# --------------------------------------------------------------------------- #
# Mutations
# --------------------------------------------------------------------------- #
func create_task(
	title: String,
	cell: Vector2i,
	description: String = "",
	due_unix: int = 0,
	subtask_titles: Array = []
) -> TaskData:
	var trimmed := title.strip_edges()
	if trimmed.is_empty():
		return null

	var size := 1
	var building_type := BuildingCatalog.select_type_for(_duration_days_for(due_unix), subtask_titles.size(), level)
	size = BuildingCatalog.get_size(building_type)
	if not can_place_at(cell, size):
		return null

	var task := TaskData.create(trimmed, cell, building_type, now_unix())
	task.description = description
	task.due_unix = due_unix
	for sub in subtask_titles:
		task.add_subtask(String(sub))

	tasks[task.id] = task
	for c in GridSystem.footprint(cell, task.size):
		occupied[c] = task.id

	save()
	task_added.emit(task)
	return task


## Planned duration in days for a task that does not exist yet.
func _duration_days_for(due_unix: int) -> float:
	if due_unix <= 0:
		return 0.0
	return float(due_unix - now_unix()) / float(ProgressSystem.DAY_SECONDS)


## Applies any of "title", "description", "due_unix" from `changes`.
func update_task(task_id: String, changes: Dictionary) -> TaskData:
	var task := get_task(task_id)
	if task == null:
		return null
	if changes.has("title"):
		var new_title := String(changes["title"]).strip_edges()
		if not new_title.is_empty():
			task.title = new_title
	if changes.has("description"):
		task.description = String(changes["description"])
	if changes.has("due_unix"):
		task.due_unix = int(changes["due_unix"])
	save()
	task_updated.emit(task)
	return task


## Replaces the subtask list, keeping the done flag of any subtask that stays.
func set_subtasks(task_id: String, titles: Array) -> TaskData:
	var task := get_task(task_id)
	if task == null:
		return null
	var done_flags := []
	for sub in task.subtasks:
		done_flags.append(bool(sub.get("done", false)))

	task.subtasks = []
	for i in titles.size():
		var sub_title := String(titles[i]).strip_edges()
		if sub_title.is_empty():
			continue
		task.add_subtask(sub_title)
		if i < done_flags.size():
			task.set_subtask_done(task.subtasks.size() - 1, done_flags[i])

	_after_change(task)
	return task


func set_subtask_done(task_id: String, index: int, done: bool) -> TaskData:
	var task := get_task(task_id)
	if task == null:
		return null
	task.set_subtask_done(index, done)
	_after_change(task)
	return task


func toggle_subtask(task_id: String, index: int) -> TaskData:
	var task := get_task(task_id)
	if task == null:
		return null
	task.set_subtask_done(index, not bool(task.subtasks[index].get("done", false)))
	_after_change(task)
	return task


func complete_task(task_id: String) -> TaskData:
	var task := get_task(task_id)
	if task == null:
		return null
	task.mark_completed(now_unix())
	_after_change(task, true)
	return task


## Un-completing a task keeps the building; it just starts growing again.
func reopen_task(task_id: String) -> TaskData:
	var task := get_task(task_id)
	if task == null:
		return null
	task.completed = false
	task.completed_unix = 0
	task.xp_awarded = true  # XP for this task has already been banked.
	for i in task.subtasks.size():
		task.subtasks[i]["done"] = false
	save()
	task_updated.emit(task)
	return task


func delete_task(task_id: String) -> void:
	var task := get_task(task_id)
	if task == null:
		return
	for c in GridSystem.footprint(task.cell, task.size):
		if occupied.get(c, "") == task_id:
			occupied.erase(c)
	tasks.erase(task_id)
	save()
	task_removed.emit(task_id)


func _after_change(task: TaskData, force_complete := false) -> void:
	if task.is_finished() and not task.completed and not force_complete:
		task.mark_completed(now_unix())
	var just_finished := task.completed
	if just_finished and not task.xp_awarded:
		task.xp_awarded = true
		_add_xp(XpSystem.xp_for_task(task))
	save()
	if just_finished:
		task_completed.emit(task)
	task_updated.emit(task)


func _add_xp(amount: int) -> void:
	xp = maxi(xp + amount, 0)
	var new_level := XpSystem.get_level_for_xp(xp)
	var leveled_up := new_level > level
	level = new_level

	# Land grows purely as a level-up reward.
	var new_grid_size := XpSystem.grid_size_for_level(level)
	if new_grid_size != grid_size:
		grid_size = new_grid_size
		grid_changed.emit(grid_size)
	if leveled_up:
		level_up.emit(level)
	xp_changed.emit(xp, level)
