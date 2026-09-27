## The catalogue of building styles a task can be represented by.
##
## Pure data + pure selection logic. Building "type" is derived from real task
## metadata (size/scope) and never gates whether a task can be created.
class_name BuildingCatalog
extends RefCounted

## Path of each construction stage sprite, in stage order.
const STAGE_TEXTURES := {
	"house": [
		"res://assets/sprites/buildings/house_stage0.png",
		"res://assets/sprites/buildings/house_stage1.png",
		"res://assets/sprites/buildings/house_stage2.png",
	],
	"workshop": [
		"res://assets/sprites/buildings/workshop_stage0.png",
		"res://assets/sprites/buildings/workshop_stage1.png",
		"res://assets/sprites/buildings/workshop_stage2.png",
	],
}

const BUILDINGS := {
	"house": {
		"display_name": "Cottage",
		"description": "Short tasks and single-day errands.",
		"min_level": 1,
		"size": 1,
		"min_days": 0,
		"min_subtasks": 0,
	},
	"workshop": {
		"display_name": "Workshop",
		"description": "Long projects and multi-step work.",
		"min_level": 2,
		"size": 1,
		"min_days": 7,
		"min_subtasks": 5,
	},
}

const DEFAULT_TYPE := "house"

const OVERDUE_DECAL := "res://assets/sprites/buildings/overdue_decal.png"
const VILLAGER_SHEET := "res://assets/sprites/characters/villager.png"
const PARTICLE_DOT := "res://assets/sprites/effects/dot.png"

const DECOR_TEXTURES := {
	"bush": "res://assets/sprites/props/bush.png",
	"rock": "res://assets/sprites/props/rock_cluster.png",
	"tree": "res://assets/sprites/props/tree.png",
}


static func has_type(type_id: String) -> bool:
	return BUILDINGS.has(type_id)


static func get_entry(type_id: String) -> Dictionary:
	return BUILDINGS.get(type_id, BUILDINGS[DEFAULT_TYPE])


static func get_display_name(type_id: String) -> String:
	return String(get_entry(type_id)["display_name"])


static func get_size(type_id: String) -> int:
	return int(get_entry(type_id)["size"])


static func get_min_level(type_id: String) -> int:
	return int(get_entry(type_id)["min_level"])


static func get_stage_textures(type_id: String) -> Array:
	return STAGE_TEXTURES.get(type_id, STAGE_TEXTURES[DEFAULT_TYPE])


static func get_stage_texture_path(type_id: String, stage: int) -> String:
	var textures := get_stage_textures(type_id)
	var index := clampi(stage, 0, textures.size() - 1)
	return String(textures[index])


## Which building a task turns into.
##
## Bigger / longer-running work earns a bigger, more elaborate building, and
## higher levels unlock further styles. If the "big" style is not unlocked yet
## the task still gets a building — it just gets the smaller one.
static func select_type(task: TaskData, level: int) -> String:
	if task == null:
		return DEFAULT_TYPE
	return select_type_for(ProgressSystem.get_duration_days(task), task.get_subtask_count(), level)


## Same decision, but from raw numbers — used for previews before a task exists.
static func select_type_for(duration_days: float, subtask_count: int, level: int) -> String:
	var min_days := int(BUILDINGS["workshop"]["min_days"])
	var min_subtasks := int(BUILDINGS["workshop"]["min_subtasks"])
	var long_running := min_days > 0 and duration_days >= float(min_days)
	var many_steps := min_subtasks > 0 and subtask_count >= min_subtasks
	var preferred := "workshop" if (long_running or many_steps) else DEFAULT_TYPE
	if level >= get_min_level(preferred):
		return preferred
	return DEFAULT_TYPE
