## Headless unit tests for the pure logic layer.
##
## Run from the repository root:
##     godot --headless --path . --script res://tests/test_runner.gd
##
## Only scene-tree-independent code is tested here (see AGENTS.md §5) — which is
## exactly the progress / XP / grid math the city is drawn from.
extends SceneTree

const DAY := 86400

var _passed: int = 0
var _failed: int = 0
var _current: String = ""


func _init() -> void:
	print("Metropolis unit tests")
	print("---------------------")

	test_grid_math()
	test_grid_placement()
	test_starter_terrain()
	test_progress_subtasks()
	test_progress_time()
	test_progress_stages()
	test_overdue()
	test_xp_curve()
	test_xp_for_task()
	test_unlocks()
	test_building_selection()
	test_task_data_round_trip()

	print("---------------------")
	print("%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# --------------------------------------------------------------------------- #
# Assertions
# --------------------------------------------------------------------------- #
func _suite(name: String) -> void:
	_current = name
	print("\n%s" % name)


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % message)
	else:
		_failed += 1
		printerr("  FAIL [%s] %s" % [_current, message])


func _check_eq(actual: Variant, expected: Variant, message: String) -> void:
	_check(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _check_near(actual: float, expected: float, message: String, tolerance: float = 0.001) -> void:
	_check(absf(actual - expected) <= tolerance, "%s (expected ~%s, got %s)" % [message, str(expected), str(actual)])


func _make_task(title: String = "Task", days: float = 0.0, subtasks: int = 0) -> TaskData:
	var task := TaskData.new()
	task.title = title
	task.start_unix = 1_000_000
	task.due_unix = 1_000_000 + int(days * DAY)
	for i in subtasks:
		task.add_subtask("step %d" % i)
	return task


# --------------------------------------------------------------------------- #
# Tests
# --------------------------------------------------------------------------- #
func test_grid_math() -> void:
	_suite("GridSystem: isometric coordinates")
	_check_eq(GridSystem.cell_to_world(Vector2i(0, 0)), Vector2(0, 16), "origin cell centre is one half-tile down")
	_check_eq(GridSystem.cell_to_world(Vector2i(1, 0)), Vector2(32, 32), "east neighbour")
	_check_eq(GridSystem.cell_to_world(Vector2i(0, 1)), Vector2(-32, 32), "south neighbour")
	_check_eq(GridSystem.cell_to_world(Vector2i(2, 3)), Vector2(-32, 96), "diagonal neighbour")

	var all_match := true
	for x in 6:
		for y in 6:
			for cell in [Vector2i(x, y), Vector2i(x, y) + Vector2i(3, 2)]:
				var centre := GridSystem.cell_to_world(cell)
				if GridSystem.world_to_cell(centre) != cell:
					all_match = false
				# Points inside the 2:1 diamond must resolve to the same cell.
				for offset in [Vector2(0, -7), Vector2(10, 0), Vector2(-10, 0), Vector2(0, 7), Vector2(12, 8)]:
					if GridSystem.world_to_cell(centre + offset) != cell:
						all_match = false
	_check(all_match, "world/cell round trip for every cell and interior point")

	_check_eq(GridSystem.footprint(Vector2i(1, 1), 2).size(), 4, "2x2 footprint covers 4 cells")
	_check(GridSystem.is_inside(Vector2i(4, 4), 5), "top-right corner of a 5x5 plot is inside")
	_check(not GridSystem.is_inside(Vector2i(5, 0), 5), "cell outside the plot is rejected")


func test_grid_placement() -> void:
	_suite("GridSystem: placement rules")
	var terrain := {Vector2i(0, 0): GridSystem.Terrain.GRASS}
	var occupied := {}

	_check(GridSystem.can_place(Vector2i(0, 0), 1, 5, terrain, occupied), "empty buildable tile is placeable")
	_check(not GridSystem.can_place(Vector2i(0, 0), 1, 5, {Vector2i(0, 0): GridSystem.Terrain.WATER}, {}), "water is not buildable")
	_check(not GridSystem.can_place(Vector2i(0, 0), 1, 5, {Vector2i(0, 0): GridSystem.Terrain.ROCK}, {}), "rock is not buildable")
	_check(GridSystem.can_place(Vector2i(0, 0), 1, 5, {Vector2i(0, 0): GridSystem.Terrain.FOREST}, {}), "forest is buildable")
	_check(not GridSystem.can_place(Vector2i(0, 0), 1, 5, terrain, {Vector2i(0, 0): "abc"}), "occupied tile is rejected")
	_check(not GridSystem.can_place(Vector2i(5, 0), 1, 5, terrain, {}), "tile past the plot edge is rejected")
	_check(not GridSystem.can_place(Vector2i(4, 0), 2, 5, terrain, {}), "footprint must fit inside the plot")


func test_starter_terrain() -> void:
	_suite("GridSystem: starter terrain")
	var terrain := GridSystem.generate_starter_terrain(GridSystem.MAX_GRID_SIZE)
	_check_eq(terrain.size(), GridSystem.MAX_GRID_SIZE * GridSystem.MAX_GRID_SIZE, "every world cell has terrain")
	_check(terrain[Vector2i(0, 1)] == GridSystem.Terrain.WATER, "pond contains water")
	_check_eq(GridSystem.generate_starter_terrain(8)[Vector2i(0, 1)], GridSystem.Terrain.WATER, "terrain generation is deterministic")
	_check(GridSystem.TERRAIN_NAMES.size() == GridSystem.TILE_COORDS.size(), "every terrain has a name and an atlas tile")
	_check(not GridSystem.is_decoratable(GridSystem.Terrain.WATER), "water gets no decoration props")


func test_progress_subtasks() -> void:
	_suite("ProgressSystem: subtask-driven progress")
	var now := 1_000_000
	var task := _make_task("Project", 0.0, 4)
	_check_near(ProgressSystem.get_progress(task, now), 0.0, "no subtasks done means no progress")

	task.set_subtask_done(0, true)
	task.set_subtask_done(1, true)
	_check_near(ProgressSystem.get_progress(task, now), 0.5, "2 of 4 subtasks done is 50%")

	task.mark_completed(now)
	_check_near(ProgressSystem.get_progress(task, now), 1.0, "a completed task is always 100%")
	_check(task.is_finished(), "all subtasks done means finished")
	_check_near(ProgressSystem.get_progress_increment(0.25, 0.5), 0.25, "progress increment is positive")
	_check_near(ProgressSystem.get_progress_increment(0.5, 0.25), 0.0, "progress never goes backwards")


func test_progress_time() -> void:
	_suite("ProgressSystem: deadline-driven progress")
	var start := 1_000_000
	var task := _make_task("Multi-day", 10.0)
	_check_near(ProgressSystem.get_duration_days(task), 10.0, "duration comes from start/due")

	_check_near(ProgressSystem.get_progress(task, start), 0.0, "no time elapsed means no progress")
	_check_near(ProgressSystem.get_progress(task, start + 5 * DAY), 0.5, "half the time means half built")
	_check_near(
		ProgressSystem.get_progress(task, start + 99 * DAY),
		ProgressSystem.TIME_PROGRESS_CEILING,
		"time alone never finishes a building"
	)

	var undated := _make_task("Someday", 0.0)
	undated.due_unix = 0
	_check_near(ProgressSystem.get_progress(undated, start + 50 * DAY), 0.0, "no deadline means no time-based progress")

	var no_start := _make_task("Backdated", 3.0)
	no_start.start_unix = 0
	_check_near(ProgressSystem.get_progress(no_start, start), 0.0, "missing start date means no time-based progress")


func test_progress_stages() -> void:
	_suite("ProgressSystem: construction stages")
	_check_eq(ProgressSystem.get_visual_stage(0.0), 0, "foundation at 0%")
	_check_eq(ProgressSystem.get_visual_stage(0.33), 0, "still foundation at 33%")
	_check_eq(ProgressSystem.get_visual_stage(0.34), 1, "mid-construction past 34%")
	_check_eq(ProgressSystem.get_visual_stage(0.66), 1, "still mid-construction at 66%")
	_check_eq(ProgressSystem.get_visual_stage(0.67), 2, "complete past 67%")
	_check_eq(ProgressSystem.get_visual_stage(1.0), 2, "finished task is complete")

	_check_near(ProgressSystem.get_building_height(0.0), 0.35, "foundation is short")
	_check_near(ProgressSystem.get_building_height(1.0), 1.0, "finished building is full height")
	var monotonic := true
	var previous := -1.0
	for i in 101:
		var height := ProgressSystem.get_building_height(float(i) / 100.0)
		if height < previous:
			monotonic = false
		previous = height
	_check(monotonic, "building height grows smoothly, never shrinks")


func test_overdue() -> void:
	_suite("ProgressSystem: overdue is visual only")
	var start := 1_000_000
	var task := _make_task("Slipping", 3.0)

	_check(not ProgressSystem.is_overdue(task, start + DAY), "not overdue before the deadline")
	_check(ProgressSystem.is_overdue(task, start + 4 * DAY), "overdue after the deadline")
	_check_eq(ProgressSystem.get_days_remaining(task, start + 2 * DAY), 1, "one day left")
	_check(ProgressSystem.get_days_remaining(task, start + 5 * DAY) < 0, "days remaining goes negative")
	_check(ProgressSystem.format_days_remaining(task, start + 5 * DAY).contains("overdue"), "overdue tasks say so")

	# Being overdue must never block progress.
	_check(ProgressSystem.get_progress(task, start + 4 * DAY) > 0.0, "an overdue task can still progress")

	task.mark_completed(start + 5 * DAY)
	_check(not ProgressSystem.is_overdue(task, start + 9 * DAY), "completed tasks are never overdue")


func test_xp_curve() -> void:
	_suite("XpSystem: level curve")
	_check_eq(XpSystem.xp_for_level(1), 0, "level 1 starts at 0 XP")
	_check(XpSystem.xp_for_level(2) > 0, "level 2 needs XP")
	_check(XpSystem.xp_for_level(5) > XpSystem.xp_for_level(4), "later levels cost more")
	_check_eq(XpSystem.get_level_for_xp(0), 1, "0 XP is level 1")
	_check_eq(XpSystem.get_level_for_xp(XpSystem.xp_for_level(4)), 4, "level boundary is exact")
	_check_eq(XpSystem.get_level_for_xp(XpSystem.xp_for_level(4) - 1), 3, "one XP short is the previous level")
	_check_near(XpSystem.get_level_progress(XpSystem.xp_for_level(2), 2), 0.0, "level progress starts empty")
	_check_near(XpSystem.get_level_progress(XpSystem.xp_for_level(3), 2), 1.0, "level progress is full at the next level")


func test_xp_for_task() -> void:
	_suite("XpSystem: task reward")
	var small := _make_task("Errand", 0.0, 0)
	var medium := _make_task("Week project", 7.0, 3)
	_check(XpSystem.xp_for_task(medium) > XpSystem.xp_for_task(small), "bigger tasks are worth more XP")
	_check(XpSystem.xp_for_task(small) > 0, "every completed task is worth something")
	_check_eq(XpSystem.xp_for_task(null), 0, "no task means no XP")


func test_unlocks() -> void:
	_suite("XpSystem: cosmetic-only unlocks")
	_check_eq(XpSystem.grid_size_for_level(1), GridSystem.MIN_GRID_SIZE, "new players start small")
	_check(XpSystem.grid_size_for_level(5) > XpSystem.grid_size_for_level(1), "land grows with level")
	_check(XpSystem.grid_size_for_level(99) <= GridSystem.MAX_GRID_SIZE, "land growth is capped")
	_check_eq(XpSystem.unlocked_decor_ids(1), ["bush"], "level 1 has one decoration")
	_check(XpSystem.unlocked_decor_ids(9).size() > XpSystem.unlocked_decor_ids(1).size(), "decorations unlock over time")
	_check(XpSystem.unlocked_building_types(1).size() < XpSystem.unlocked_building_types(9).size(), "styles unlock over time")
	for type_id in XpSystem.unlocked_building_types(1):
		_check_eq(XpSystem.unlocked_building_types(1).count(type_id), 1, "%s is only listed once" % type_id)


func test_building_selection() -> void:
	_suite("BuildingCatalog: task -> building")
	var short := _make_task("Errand", 2.0, 1)
	var long := _make_task("Migration", 21.0, 0)
	var stepwise := _make_task("Checklist", 0.0, 6)

	_check_eq(BuildingCatalog.select_type(short, 9), "house", "short tasks become cottages")
	_check_eq(BuildingCatalog.select_type(long, 9), "workshop", "long projects become workshops")
	_check_eq(BuildingCatalog.select_type(stepwise, 9), "workshop", "many-step tasks become workshops")
	_check_eq(BuildingCatalog.select_type(long, 1), "house", "locked styles fall back to the cottage")
	_check_eq(BuildingCatalog.select_type_for(21.0, 0, 1), "house", "fallback also applies to raw previews")

	for type_id in BuildingCatalog.STAGE_TEXTURES.keys():
		var stages: Array = BuildingCatalog.STAGE_TEXTURES[type_id]
		_check_eq(stages.size(), ProgressSystem.STAGE_COUNT, "%s has one sprite per stage" % type_id)
		for path in stages:
			_check(ResourceLoader.exists(path), "stage sprite exists: %s" % path)
	_check(ResourceLoader.exists(BuildingCatalog.OVERDUE_DECAL), "overdue decal exists")
	_check(ResourceLoader.exists(BuildingCatalog.VILLAGER_SHEET), "villager sheet exists")
	_check(ResourceLoader.exists(BuildingCatalog.PARTICLE_DOT), "particle dot exists")
	for path in BuildingCatalog.DECOR_TEXTURES.values():
		_check(ResourceLoader.exists(path), "decoration sprite exists: %s" % path)


func test_task_data_round_trip() -> void:
	_suite("TaskData: serialisation")
	var task := _make_task("Ship it", 5.0, 2)
	task.description = "with tests"
	task.cell = Vector2i(3, 4)
	task.building_type = "workshop"
	task.size = 1
	task.add_subtask("  padded  ")
	task.set_subtask_done(0, true)
	task.due_unix = 1_000_000 + 5 * DAY
	task.xp_awarded = true

	var restored := TaskData.from_dict(task.to_dict())
	_check_eq(restored.id, task.id, "id survives")
	_check_eq(restored.title, task.title, "title survives")
	_check_eq(restored.description, task.description, "description survives")
	_check_eq(restored.cell, task.cell, "cell survives")
	_check_eq(restored.due_unix, task.due_unix, "deadline survives")
	_check_eq(restored.building_type, task.building_type, "building type survives")
	_check_eq(restored.get_subtask_count(), task.get_subtask_count(), "subtask count survives")
	_check_eq(restored.get_completed_subtask_count(), 1, "subtask state survives")
	_check_eq(restored.subtasks[2]["title"], "padded", "subtask titles are trimmed")
	_check(restored.xp_awarded, "xp award flag survives")
	_check(TaskData.from_dict({}).title == "Untitled task", "empty data still yields a usable task")
