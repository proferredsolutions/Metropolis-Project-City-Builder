## The tracker data model: one real-world task/project, plus everything the city
## needs to draw it as a building.
##
## Deliberately a plain RefCounted with an explicit `to_dict`/`from_dict` pair so
## the whole save file is human-readable JSON (see SaveManager).
class_name TaskData
extends RefCounted

var id: String = ""
var title: String = ""
var description: String = ""
## Unix timestamp the task was created — the baseline for time-based progress.
var start_unix: int = 0
## Unix timestamp the task is due, or 0 for "no deadline".
var due_unix: int = 0
## Array of {"title": String, "done": bool}
var subtasks: Array[Dictionary] = []
var completed: bool = false
var completed_unix: int = 0
## Grid placement.
var cell: Vector2i = Vector2i.ZERO
var size: int = 1
## Which building style this task is drawn as.
var building_type: String = BuildingCatalog.DEFAULT_TYPE
## Set once the completion XP has been granted, so XP is never double-awarded.
var xp_awarded: bool = false


static func create(
	title: String,
	cell: Vector2i,
	building_type: String = BuildingCatalog.DEFAULT_TYPE,
	now_unix: int = 0
) -> TaskData:
	var task := TaskData.new()
	task.id = _generate_id(now_unix)
	task.title = title
	task.cell = cell
	task.size = BuildingCatalog.get_size(building_type)
	task.building_type = building_type
	task.start_unix = now_unix
	return task


static func _generate_id(now_unix: int) -> String:
	return "%d-%d" % [now_unix, Time.get_ticks_usec() % 1000000]


func get_subtask_count() -> int:
	return subtasks.size()


func get_completed_subtask_count() -> int:
	var done := 0
	for sub in subtasks:
		if bool(sub.get("done", false)):
			done += 1
	return done


func add_subtask(sub_title: String) -> void:
	if sub_title.strip_edges().is_empty():
		return
	subtasks.append({"title": sub_title.strip_edges(), "done": false})


func set_subtask_done(index: int, done: bool) -> void:
	if index < 0 or index >= subtasks.size():
		return
	subtasks[index]["done"] = done


## A task counts as finished when the user says so — or when every subtask is done.
func is_finished() -> bool:
	if completed:
		return true
	if get_subtask_count() > 0 and get_completed_subtask_count() == get_subtask_count():
		return true
	return false


func mark_completed(now_unix: int) -> void:
	completed = true
	completed_unix = now_unix
	for i in subtasks.size():
		subtasks[i]["done"] = true


func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"description": description,
		"start_unix": start_unix,
		"due_unix": due_unix,
		"subtasks": subtasks.duplicate(true),
		"completed": completed,
		"completed_unix": completed_unix,
		"cell_x": cell.x,
		"cell_y": cell.y,
		"size": size,
		"building_type": building_type,
		"xp_awarded": xp_awarded,
	}


static func from_dict(data: Dictionary) -> TaskData:
	var task := TaskData.new()
	task.id = String(data.get("id", ""))
	task.title = String(data.get("title", "Untitled task"))
	task.description = String(data.get("description", ""))
	task.start_unix = int(data.get("start_unix", 0))
	task.due_unix = int(data.get("due_unix", 0))
	task.completed = bool(data.get("completed", false))
	task.completed_unix = int(data.get("completed_unix", 0))
	task.cell = Vector2i(int(data.get("cell_x", 0)), int(data.get("cell_y", 0)))
	task.size = int(data.get("size", 1))
	task.building_type = String(data.get("building_type", BuildingCatalog.DEFAULT_TYPE))
	task.xp_awarded = bool(data.get("xp_awarded", false))
	task.subtasks = []
	for raw in data.get("subtasks", []):
		if raw is Dictionary:
			task.subtasks.append({
				"title": String(raw.get("title", "")),
				"done": bool(raw.get("done", false)),
			})
	return task
