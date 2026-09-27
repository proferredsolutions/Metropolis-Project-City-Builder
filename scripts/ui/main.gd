## Root scene controller: owns the camera rig, the input model (pan / pinch /
## tap) and the wiring between the tracker (GameState) and the city view.
extends Node2D

const BUILDING_SCENE := preload("res://scenes/buildings/building.tscn")

const ZOOM_MIN := 0.75
const ZOOM_MAX := 3.0
const ZOOM_DEFAULT := 1.75
const ZOOM_WHEEL_STEP := 0.12
const TAP_MAX_DISTANCE := 14.0
const PINCH_SENSITIVITY := 400.0
const REFRESH_INTERVAL := 1.0

@onready var world: Node2D = $World
@onready var grid: CityGrid = $World/CityGrid
@onready var camera: Camera2D = $Camera
@onready var hud: HudPanel = $UI/HUD
@onready var creation_panel: TaskCreationPanel = $UI/TaskCreationPanel
@onready var detail_panel: TaskDetailPanel = $UI/TaskDetailPanel

var _buildings: Dictionary = {}
var _refresh_timer: float = 0.0
var _dragging: bool = false
var _drag_distance: float = 0.0
var _touch_points: Dictionary = {}
var _pinch_reference: float = 0.0


func _ready() -> void:
	camera.zoom = Vector2.ONE * ZOOM_DEFAULT
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0

	GameState.tasks_loaded.connect(_on_tasks_loaded)
	GameState.task_added.connect(_on_task_added)
	GameState.task_updated.connect(func(_task: TaskData) -> void: _refresh_buildings())
	GameState.task_completed.connect(func(_task: TaskData) -> void: _refresh_buildings())
	GameState.task_removed.connect(_on_task_removed)
	GameState.grid_changed.connect(_on_grid_changed)
	GameState.level_up.connect(_on_level_up)

	creation_panel.submitted.connect(_on_task_submitted)
	creation_panel.changed.connect(_on_task_edited)
	creation_panel.closed.connect(_on_panel_closed)
	detail_panel.edit_requested.connect(_on_edit_requested)
	detail_panel.changed.connect(func(_task_id: String) -> void: _sync_buildings())
	detail_panel.deleted.connect(_on_task_removed)
	detail_panel.closed.connect(_on_panel_closed)
	hud.new_task_requested.connect(_on_new_task_requested)
	hud.task_selected.connect(_on_task_selected)

	_on_tasks_loaded()
	_focus_grid()


# --------------------------------------------------------------------------- #
# Frame loop
# --------------------------------------------------------------------------- #
func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_INTERVAL:
		_refresh_timer = 0.0
		_refresh_buildings()


# --------------------------------------------------------------------------- #
# Input: pan, pinch/wheel zoom, tap
# --------------------------------------------------------------------------- #
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_points[touch.index] = touch.position
		else:
			_touch_points.erase(touch.index)
		_update_pinch()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_touch_points[drag.index] = drag.position
		_update_pinch()
		return

	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom_by(ZOOM_WHEEL_STEP)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom_by(-ZOOM_WHEEL_STEP)
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_dragging = true
				_drag_distance = 0.0
			else:
				var was_tap := _dragging and _drag_distance <= TAP_MAX_DISTANCE
				_dragging = false
				if was_tap:
					_on_tap(_screen_to_world(button.position))
		return

	# While pinching, ignore the emulated single-pointer drag.
	if event is InputEventMouseMotion and _dragging and _touch_points.size() < 2:
		var motion := event as InputEventMouseMotion
		_drag_distance += motion.relative.length()
		camera.position -= motion.relative / camera.zoom.x


func _update_pinch() -> void:
	if _touch_points.size() < 2:
		_pinch_reference = 0.0
		return
	var positions := _touch_points.values()
	var distance := (positions[0] as Vector2).distance_to(positions[1] as Vector2)
	if _pinch_reference <= 0.0:
		_pinch_reference = distance
		return
	if distance > 0.0:
		_zoom_by((distance - _pinch_reference) / PINCH_SENSITIVITY)
	_pinch_reference = distance


func _zoom_by(delta: float) -> void:
	var level := clampf(camera.zoom.x + delta, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2.ONE * level


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _on_tap(world_pos: Vector2) -> void:
	if creation_panel.visible or detail_panel.visible:
		_on_panel_closed()
		return

	var cell := GridSystem.world_to_cell(world_pos)
	if not GridSystem.is_inside(cell, GameState.grid_size):
		return

	var task := GameState.get_task_at_cell(cell)
	if task != null:
		grid.show_highlight(cell, task.size, true)
		detail_panel.open_task(task.id)
		return

	if GameState.can_place_at(cell, 1):
		grid.show_highlight(cell, 1, true)
		if not creation_panel.open_at(cell):
			hud.flash("That tile cannot be built on (%s)." % GridSystem.terrain_name(GameState.get_terrain(cell)))
	else:
		grid.show_highlight(cell, 1, false)
		hud.flash("That tile is already taken or not buildable.")


# --------------------------------------------------------------------------- #
# City building sync
# --------------------------------------------------------------------------- #
func _on_tasks_loaded() -> void:
	_rebuild_city()
	hud.refresh(GameState)


func _on_task_added(_task: TaskData) -> void:
	_sync_buildings()
	hud.refresh(GameState)


func _on_task_removed(_task_id: String) -> void:
	_sync_buildings()
	hud.refresh(GameState)


func _on_task_submitted(data: Dictionary) -> void:
	var task := GameState.create_task(
		String(data.get("title", "")),
		data.get("cell", Vector2i.ZERO),
		String(data.get("description", "")),
		int(data.get("due_unix", 0)),
		data.get("subtasks", [])
	)
	if task == null:
		creation_panel.show_error("Could not create that task on the selected tile.")
		return
	_on_panel_closed()
	_sync_buildings()
	hud.refresh(GameState)
	grid.show_highlight(task.cell, task.size, true)
	hud.flash("Task \u201c%s\u201d is under construction." % task.title)


func _on_edit_requested(task_id: String) -> void:
	var task := GameState.get_task(task_id)
	if task == null:
		return
	_on_panel_closed()
	if creation_panel.open_for_edit(task):
		hud.flash("Editing \u201c%s\u201d." % task.title)
	elif task.completed:
		hud.flash("Reopen the task before editing it.")


func _on_task_edited(task_id: String) -> void:
	_sync_buildings()
	hud.refresh(GameState)
	hud.flash("Task updated.")


func _on_panel_closed() -> void:
	creation_panel.close()
	detail_panel.close()


func _on_new_task_requested() -> void:
	var cell := GameState.find_free_cell(1)
	if cell.x < 0:
		hud.flash("No free land left — finish a task to unlock more.")
		return
	_on_panel_closed()
	_focus_cell(cell)
	grid.show_highlight(cell, 1, true)
	creation_panel.open_at(cell)


func _on_task_selected(task_id: String) -> void:
	var task := GameState.get_task(task_id)
	if task == null:
		return
	_on_panel_closed()
	_focus_cell(task.cell)
	grid.show_highlight(task.cell, task.size, true)
	detail_panel.open_task(task_id)


func _on_grid_changed(grid_size: int) -> void:
	_rebuild_city()
	hud.refresh(GameState)
	hud.flash("Land unlocked! Your city is now %dx%d." % [grid_size, grid_size])


func _on_level_up(level: int) -> void:
	hud.flash("Level %d reached — new styles and land unlocked." % level)


func _rebuild_city() -> void:
	grid.rebuild(GameState.grid_size, GameState.terrain, XpSystem.unlocked_decor_ids(GameState.level), GameState.occupied)
	_sync_buildings()
	hud.refresh(GameState)


func _refresh_buildings() -> void:
	var now := GameState.now_unix()
	for building in _buildings.values():
		(building as Building).refresh(now)


func _sync_buildings() -> void:
	var seen := {}
	for task in GameState.tasks.values():
		var typed: TaskData = task
		seen[typed.id] = true
		if not _buildings.has(typed.id):
			var building: Building = BUILDING_SCENE.instantiate()
			world.add_child(building)
			building.setup(typed)
			_buildings[typed.id] = building
	for task_id in _buildings.keys():
		if not seen.has(task_id):
			(_buildings[task_id] as Building).queue_free()
			_buildings.erase(task_id)


# --------------------------------------------------------------------------- #
# Camera helpers
# --------------------------------------------------------------------------- #
func _focus_grid() -> void:
	_focus_cell(Vector2i(GameState.grid_size / 2, GameState.grid_size / 2))


func _focus_cell(cell: Vector2i) -> void:
	var target := GridSystem.cell_to_world(cell)
	var tween := create_tween()
	tween.tween_property(camera, "position", target, 0.35).set_trans(Tween.TRANS_CUBIC)

