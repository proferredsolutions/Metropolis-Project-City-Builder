## XP, levels and the cosmetic-only unlocks they grant.
##
## Pure functions only. Nothing here can gate task tracking — levels only ever
## unlock more land, more building styles and decorations.
class_name XpSystem
extends RefCounted


## XP earned for finishing a task. Scales with real scope: subtasks, planned
## duration and footprint size.
static func xp_for_task(task: TaskData) -> int:
	if task == null:
		return 0
	var xp := 20
	xp += 15 * task.get_subtask_count()
	xp += 15 * maxi(task.size - 1, 0)
	var days := int(ProgressSystem.get_duration_days(task))
	xp += 2 * clampi(days, 0, 30)
	return xp


## Total XP required to *reach* `level` (level 1 starts at 0 XP).
static func xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	var total := 0
	for l in range(2, level + 1):
		total += 100 * (l - 1)
	return total


## XP needed to go from `level` to `level + 1`.
static func xp_step_cost(level: int) -> int:
	return 100 * maxi(level, 1)


## The level a given lifetime XP total corresponds to.
static func get_level_for_xp(xp: int) -> int:
	var level := 1
	while xp_for_level(level + 1) <= xp and level < 99:
		level += 1
	return level


## Progress through the current level, 0.0 - 1.0.
static func get_level_progress(xp: int, level: int) -> float:
	var floor_xp := xp_for_level(level)
	var cost := xp_step_cost(level)
	if cost <= 0:
		return 0.0
	return clampf(float(xp - floor_xp) / float(cost), 0.0, 1.0)


## How much of the map is unlocked at a given level. Land only ever grows as a
## level-up reward; it is never purchasable.
static func grid_size_for_level(level: int) -> int:
	return clampi(GridSystem.MIN_GRID_SIZE + (level - 1), GridSystem.MIN_GRID_SIZE, GridSystem.MAX_GRID_SIZE)


## Decoration props unlocked so far, in unlock order.
const DECOR_UNLOCKS := [
	{"level": 1, "id": "bush", "name": "Bushes"},
	{"level": 2, "id": "rock", "name": "Rock clusters"},
	{"level": 3, "id": "tree", "name": "Trees"},
]

static func unlocked_decor_ids(level: int) -> Array:
	var ids := []
	for entry in DECOR_UNLOCKS:
		if level >= int(entry["level"]):
			ids.append(String(entry["id"]))
	return ids


## Building styles available at a level, newest last.
static func unlocked_building_types(level: int) -> Array:
	var types := []
	for key in BuildingCatalog.BUILDINGS.keys():
		if level >= int(BuildingCatalog.BUILDINGS[key]["min_level"]):
			types.append(String(key))
	types.sort()
	return types
