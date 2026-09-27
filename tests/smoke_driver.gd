## End-to-end smoke test: runs the real main scene and drives it the way a
## player would — create a task, tick subtasks, finish it, edit, delete, reload.
##
## Run from the repository root:
##     godot --headless --path . res://tests/smoke.tscn
##
## Exits with a non-zero status if any check fails.
extends Node

var _passed: int = 0
var _failed: int = 0
var _main: Node


func _ready() -> void:
	_main = get_parent().get_node("Main")
	_run()


func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("  ok   %s" % message)
	else:
		_failed += 1
		printerr("  FAIL %s" % message)


func _check_eq(actual: Variant, expected: Variant, message: String) -> void:
	_check(actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _settle(frames: int = 3) -> void:
	for i in frames:
		await get_tree().process_frame


func _building_count() -> int:
	return _main.get("_buildings").size()


func _run() -> void:
	print("Metropolis smoke test")
	print("---------------------")
	await _settle(5)

	var start_cells := _building_count()
	_check_eq(start_cells, 0, "a fresh city has no buildings")
	_check(_main.grid.tilemap.get_used_cells(0).size() > 0, "terrain is drawn on boot")
	_check(_main.grid.decor.get_child_count() > 0, "decoration props are scattered")

	# --- creating a task through the real UI path ------------------------- #
	var cell := GameState.find_free_cell(1)
	_check(cell.x >= 0, "there is a free tile to build on")
	_check(_main.creation_panel.open_at(cell), "creation form opens on a free tile")
	_main.creation_panel.title_edit.text = "Smoke test task"
	_main.creation_panel.description_edit.text = "created by the smoke test"
	_main.creation_panel.duration_option.select(2)
	_main.creation_panel.subtasks_edit.text = "first, second, third"
	await _settle()
	_main.creation_panel._on_create_pressed()
	await _settle()

	_check_eq(GameState.tasks.size(), 1, "submitting the form creates a task")
	var task: TaskData = GameState.get_tasks_sorted()[0]
	_check_eq(task.title, "Smoke test task", "task title is stored")
	_check_eq(task.get_subtask_count(), 3, "subtasks are parsed from the form")
	_check(task.due_unix > 0, "deadline is stored")
	_check_eq(_building_count(), 1, "a building appears for the task")
	_check(GameState.get_task_at_cell(cell) == task, "the building occupies the tapped tile")
	var building_spawn: Node = _main.get("_buildings")[task.id]
	_check_eq(building_spawn.position, GridSystem.cell_to_world(cell), "the building is anchored to its tile centre")

	# --- progress --------------------------------------------------------- #
	_check_near_progress(task, 0.0, "a new task starts unbuilt")
	GameState.set_subtask_done(task.id, 0, true)
	GameState.set_subtask_done(task.id, 1, true)
	await _settle()
	_check_near_progress(task, 2.0 / 3.0, "subtask progress moves the building")
	var building: Node = _main.get("_buildings")[task.id]
	_check(building.stage_sprite.texture != null, "building shows a construction sprite")
	_check(building.villager.visible, "a villager works on the unfinished building")

	GameState.set_subtask_done(task.id, 2, true)
	await _settle()
	_check(task.completed, "finishing every subtask completes the task")
	_check(GameState.xp > 0, "completing a task awards XP")
	_check_eq(GameState.get_task_at_cell(cell), task, "the building stays on its tile")
	await _settle()
	_check(not building.villager.visible, "the villager leaves once construction is done")
	_check(building.smoke.emitting, "chimney smoke starts on the finished building")

	# --- levels and land --------------------------------------------------- #
	var land_before := GameState.grid_size
	_check_eq(land_before, XpSystem.grid_size_for_level(GameState.level), "land matches the level reward")

	# --- the detail panel --------------------------------------------------- #
	_main.detail_panel.open_task(task.id)
	await _settle()
	_check(_main.detail_panel.visible, "detail panel opens for a tapped building")
	_check_eq(_main.detail_panel.title_label.text, task.title, "detail panel shows the task")

	# --- editing an existing task ------------------------------------------ #
	_check(not _main.creation_panel.open_for_edit(task), "a finished task cannot be edited")
	GameState.reopen_task(task.id)
	await _settle()
	_check(not task.completed, "reopening a task puts it back under construction")
	_check(task.xp_awarded, "reopening does not refund or re-award XP")
	_main._on_edit_requested(task.id)
	await _settle()
	_check(_main.creation_panel.visible, "the edit form opens for an existing task")
	_check_eq(_main.creation_panel.title_edit.text, task.title, "the form is pre-filled")
	_main.creation_panel.title_edit.text = "Smoke test task (edited)"
	_main.creation_panel.subtasks_edit.text = "first, second, third, fourth"
	_main.creation_panel._on_create_pressed()
	await _settle()
	_check_eq(GameState.get_task(task.id).title, "Smoke test task (edited)", "editing updates the title")
	_check_eq(GameState.get_task(task.id).get_subtask_count(), 4, "editing updates the subtasks")
	_check_eq(GameState.get_task(task.id).get_completed_subtask_count(), 0, "editing does not invent progress")
	_check(not GameState.get_task(task.id).completed, "the task stays open after an edit")
	_check(not _main.creation_panel.visible, "the form closes after saving")
	_check_eq(_building_count(), 1, "the building stays on its tile after an edit")
	_main.detail_panel.close()

	# --- persistence -------------------------------------------------------- #
	GameState.save()
	var saved_count := GameState.tasks.size()
	GameState.load_game()
	await _settle()
	_check_eq(GameState.tasks.size(), saved_count, "tasks survive a save/load round trip")
	_check_eq(GameState.get_tasks_sorted()[0].title, task.title, "task data survives a reload")
	_check_eq(_building_count(), saved_count, "buildings are rebuilt from the save file")

	# --- deletion ----------------------------------------------------------- #
	GameState.delete_task(task.id)
	await _settle()
	_check_eq(GameState.tasks.size(), 0, "deleting a task removes it")
	_check_eq(_building_count(), 0, "deleting a task removes its building")
	_check(GameState.can_place_at(cell, 1), "the tile is buildable again")

	# --- an invalid placement is refused ------------------------------------ #
	var water_cell := _find_water_cell()
	if water_cell.x >= 0:
		_check(not GameState.can_place_at(water_cell, 1), "water cannot be built on")
		_check(GameState.create_task("Nope", water_cell) == null, "creating a task on water is refused")
		_check(not _main.creation_panel.open_at(water_cell), "the form refuses to open on water")

	GameState.reset()
	await _settle()
	_check_eq(GameState.tasks.size(), 0, "reset clears the city")
	_check_eq(GameState.level, 1, "reset returns to level 1")

	print("---------------------")
	print("%d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check_near_progress(task: TaskData, expected: float, message: String) -> void:
	var actual := ProgressSystem.get_progress(task, GameState.now_unix())
	_check(absf(actual - expected) <= 0.01, "%s (expected ~%s, got %s)" % [message, str(expected), str(actual)])


func _find_water_cell() -> Vector2i:
	for y in GameState.grid_size:
		for x in GameState.grid_size:
			var cell := Vector2i(x, y)
			if GameState.get_terrain(cell) == GridSystem.Terrain.WATER:
				return cell
	return Vector2i(-1, -1)
