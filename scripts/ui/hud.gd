## Persistent edge-anchored UI: level + XP, the unlockable land size, a quick
## "new task" action, a live task list and a transient toast line.
##
## Reads GameState for display and emits signals for intent — it never mutates
## game state itself.
class_name HudPanel
extends Control

signal new_task_requested
signal task_selected(task_id: String)

const TOAST_SECONDS := 3.5
const MAX_LIST_ROWS := 12

@onready var level_label: Label = $TopLeft/Box/LevelLabel
@onready var xp_bar: ProgressBar = $TopLeft/Box/XPBar
@onready var land_label: Label = $TopLeft/Box/LandLabel
@onready var toast_label: Label = $Toast
@onready var task_list: VBoxContainer = $TaskListPanel/Box/Scroll/TaskList
@onready var count_label: Label = $TaskListPanel/Box/CountLabel

var _toast_tween: Tween


func _ready() -> void:
	toast_label.modulate.a = 0.0
	$NewTaskButton.pressed.connect(func() -> void: new_task_requested.emit())
	rebuild_task_list()


func refresh(_state: Node = null) -> void:
	level_label.text = "Level %d" % GameState.level
	land_label.text = "Land %dx%d  ·  %s" % [
		GameState.grid_size,
		GameState.grid_size,
		_styles_text(),
	]
	xp_bar.max_value = XpSystem.xp_step_cost(GameState.level)
	xp_bar.value = XpSystem.get_level_progress(GameState.xp, GameState.level) * xp_bar.max_value
	xp_bar.tooltip_text = "%d / %d XP to level %d" % [
		GameState.xp,
		XpSystem.xp_for_level(GameState.level + 1),
		GameState.level + 1,
	]
	rebuild_task_list()


func _styles_text() -> String:
	var names := []
	for type_id in XpSystem.unlocked_building_types(GameState.level):
		names.append(BuildingCatalog.get_display_name(type_id))
	return ", ".join(names) if not names.is_empty() else "No styles yet"


## Rebuild the compact task list. Rows are cheap Controls, so a full rebuild
## keeps things simple and always in sync.
func rebuild_task_list() -> void:
	for child in task_list.get_children():
		child.queue_free()

	var tasks := GameState.get_tasks_sorted()
	count_label.text = "Tasks (%d)" % tasks.size()
	var shown := 0
	var now := GameState.now_unix()
	for task in tasks:
		if shown >= MAX_LIST_ROWS:
			break
		shown += 1
		task_list.add_child(_make_row(task, now))
	if tasks.is_empty():
		var empty := Label.new()
		empty.text = "Tap a tile to create your first task."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.custom_minimum_size = Vector2(190, 0)
		task_list.add_child(empty)


func _make_row(task: TaskData, now: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var button := Button.new()
	button.text = task.title
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.pressed.connect(func() -> void: task_selected.emit(task.id))
	box.add_child(button)

	var progress := ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 1.0
	progress.step = 0.001
	progress.value = ProgressSystem.get_progress(task, now)
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(0, 6)
	box.add_child(progress)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 11)
	var percent := int(round(progress.value * 100.0))
	if task.completed:
		status.text = "Complete  ·  %d%%" % percent
		status.modulate = Color(0.55, 0.9, 0.55)
	elif ProgressSystem.is_overdue(task, now):
		status.text = ProgressSystem.format_days_remaining(task, now)
		status.modulate = Color(0.95, 0.55, 0.5)
	else:
		status.text = "%d%%  ·  %s" % [percent, ProgressSystem.format_days_remaining(task, now)]
		status.modulate = Color(0.8, 0.82, 0.86)
	box.add_child(status)

	return panel


## Show a transient message along the bottom edge.
func flash(message: String) -> void:
	toast_label.text = message
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_SECONDS)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.8)
