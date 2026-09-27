## Task detail panel: the tracker's real home. Progress, subtasks, deadline and
## completion live here — the building outside is just the reward layer.
class_name TaskDetailPanel
extends Control

signal changed(task_id: String)
signal deleted(task_id: String)
signal edit_requested(task_id: String)
signal closed

const CONFIRM_SECONDS := 3.0

@onready var title_label: Label = $Dim/Center/Panel/Box/TitleLabel
@onready var meta_label: Label = $Dim/Center/Panel/Box/MetaLabel
@onready var progress_bar: ProgressBar = $Dim/Center/Panel/Box/ProgressBar
@onready var progress_label: Label = $Dim/Center/Panel/Box/ProgressLabel
@onready var subtask_box: VBoxContainer = $Dim/Center/Panel/Box/SubtaskBox
@onready var description_label: Label = $Dim/Center/Panel/Box/DescriptionLabel
@onready var edit_button: Button = $Dim/Center/Panel/Box/Buttons/EditButton
@onready var reopen_button: Button = $Dim/Center/Panel/Box/Buttons/ReopenButton
@onready var complete_button: Button = $Dim/Center/Panel/Box/Buttons/CompleteButton
@onready var delete_button: Button = $Dim/Center/Panel/Box/Buttons/DeleteButton
@onready var close_button: Button = $Dim/Center/Panel/Box/Buttons/CloseButton

var _task_id: String = ""
var _confirm_tween: Tween


func _ready() -> void:
	visible = false
	edit_button.pressed.connect(func() -> void: edit_requested.emit(_task_id))
	reopen_button.pressed.connect(_on_reopen_pressed)
	complete_button.pressed.connect(_on_complete_pressed)
	delete_button.pressed.connect(_on_delete_pressed)
	close_button.pressed.connect(func() -> void: close())
	$Dim.gui_input.connect(_on_dim_input)


func open_task(task_id: String) -> void:
	if task_id.is_empty():
		return
	_task_id = task_id
	visible = true
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _refresh() -> void:
	var task := GameState.get_task(_task_id)
	if task == null:
		close()
		return

	var now := GameState.now_unix()
	title_label.text = task.title
	meta_label.text = "%s  ·  tile %d,%d  ·  %s" % [
		BuildingCatalog.get_display_name(task.building_type),
		task.cell.x,
		task.cell.y,
		ProgressSystem.format_days_remaining(task, now),
	]
	if ProgressSystem.is_overdue(task, now):
		meta_label.modulate = Color(0.95, 0.6, 0.55)
	elif task.completed:
		meta_label.modulate = Color(0.6, 0.92, 0.6)
	else:
		meta_label.modulate = Color(0.85, 0.87, 0.92)

	var progress := ProgressSystem.get_progress(task, now)
	progress_bar.value = progress
	progress_label.text = "%d%% built" % int(round(progress * 100.0))

	description_label.text = task.description if not task.description.is_empty() else "No description."
	description_label.visible = true

	for child in subtask_box.get_children():
		child.queue_free()
	if task.subtasks.is_empty():
		var hint := Label.new()
		hint.text = "No subtasks — this building grows as the deadline passes."
		hint.modulate = Color(0.7, 0.72, 0.78)
		subtask_box.add_child(hint)
	else:
		for i in task.subtasks.size():
			subtask_box.add_child(_make_subtask(task, i))

	edit_button.disabled = task.completed
	reopen_button.visible = task.completed
	complete_button.disabled = task.completed
	reset_delete_confirm()


func _make_subtask(task: TaskData, index: int) -> Control:
	var check := CheckBox.new()
	check.text = String(task.subtasks[index].get("title", ""))
	check.button_pressed = bool(task.subtasks[index].get("done", false))
	check.toggled.connect(func(pressed: bool) -> void:
		GameState.set_subtask_done(task.id, index, pressed)
		changed.emit(task.id))
	return check


func _on_complete_pressed() -> void:
	if GameState.complete_task(_task_id) != null:
		changed.emit(_task_id)
		_refresh()


func _on_reopen_pressed() -> void:
	if GameState.reopen_task(_task_id) != null:
		changed.emit(_task_id)
		_refresh()


func _on_delete_pressed() -> void:
	if delete_button.text != "Really delete?":
		delete_button.text = "Really delete?"
		if _confirm_tween != null and _confirm_tween.is_valid():
			_confirm_tween.kill()
		_confirm_tween = create_tween()
		_confirm_tween.tween_interval(CONFIRM_SECONDS)
		_confirm_tween.tween_callback(reset_delete_confirm)
		return
	GameState.delete_task(_task_id)
	deleted.emit(_task_id)
	close()


func reset_delete_confirm() -> void:
	delete_button.text = "Delete"


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
