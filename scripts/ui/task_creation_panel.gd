## Task/project creation form.
##
## Opens over a tapped tile. Emits `submitted` with the raw form data; the root
## scene decides whether the task can actually be created.
class_name TaskCreationPanel
extends Control

signal submitted(data: Dictionary)
signal changed(task_id: String)
signal closed

## Days -> label. 0 means "no deadline" (progress then only moves via subtasks).
const DURATION_OPTIONS := [
	{"days": 0, "label": "No deadline"},
	{"days": 1, "label": "1 day"},
	{"days": 3, "label": "3 days"},
	{"days": 7, "label": "1 week"},
	{"days": 14, "label": "2 weeks"},
	{"days": 30, "label": "1 month"},
]

@onready var title_edit: LineEdit = $Dim/Center/Panel/Box/TitleEdit
@onready var description_edit: TextEdit = $Dim/Center/Panel/Box/DescriptionEdit
@onready var duration_option: OptionButton = $Dim/Center/Panel/Box/DurationOption
@onready var subtasks_edit: LineEdit = $Dim/Center/Panel/Box/SubtasksEdit
@onready var preview_label: Label = $Dim/Center/Panel/Box/PreviewLabel
@onready var status_label: Label = $Dim/Center/Panel/Box/StatusLabel
@onready var create_button: Button = $Dim/Center/Panel/Box/Buttons/CreateButton
@onready var cancel_button: Button = $Dim/Center/Panel/Box/Buttons/CancelButton

var _cell: Vector2i = Vector2i.ZERO
var _editing_id: String = ""


func _ready() -> void:
	visible = false
	for i in DURATION_OPTIONS.size():
		duration_option.add_item(String(DURATION_OPTIONS[i]["label"]), i)
	duration_option.select(0)
	create_button.pressed.connect(_on_create_pressed)
	cancel_button.pressed.connect(func() -> void: close())
	$Dim.gui_input.connect(_on_dim_input)
	title_edit.text_submitted.connect(func(_text: String) -> void: _on_create_pressed())
	title_edit.text_changed.connect(func(_text: String) -> void: _update_preview())
	subtasks_edit.text_changed.connect(func(_text: String) -> void: _update_preview())
	duration_option.item_selected.connect(func(_index: int) -> void: _update_preview())


## Returns false when the tile cannot host a building, so the caller can explain.
func open_at(cell: Vector2i) -> bool:
	if not GameState.can_place_at(cell, 1):
		return false
	_editing_id = ""
	_cell = cell
	visible = true
	title_edit.text = ""
	description_edit.text = ""
	subtasks_edit.text = ""
	duration_option.select(0)
	create_button.text = "Create"
	show_error("")
	_update_preview()
	title_edit.grab_focus()
	return true


## Edit mode: the building stays exactly where it is, only the task data changes.
func open_for_edit(task: TaskData) -> bool:
	# Finished tasks are read-only until they are reopened, so the building and
	# the task data can never disagree about progress.
	if task == null or task.completed:
		return false
	_editing_id = task.id
	_cell = task.cell
	visible = true
	title_edit.text = task.title
	description_edit.text = task.description
	subtasks_edit.text = ", ".join(_subtask_titles(task))
	duration_option.select(_duration_index(task))
	create_button.text = "Save"
	show_error("")
	_update_preview()
	title_edit.grab_focus()
	return true


func _subtask_titles(task: TaskData) -> Array:
	var titles := []
	for sub in task.subtasks:
		titles.append(String(sub.get("title", "")))
	return titles


## Index of the deadline option that matches the task, or 0 ("no deadline").
func _duration_index(task: TaskData) -> int:
	if task.due_unix <= 0:
		return 0
	var days := int(ceil(float(task.due_unix - GameState.now_unix()) / float(ProgressSystem.DAY_SECONDS)))
	for i in DURATION_OPTIONS.size():
		if int(DURATION_OPTIONS[i]["days"]) == days:
			return i
	return 0


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func show_error(message: String) -> void:
	status_label.text = message
	status_label.visible = not message.is_empty()


func get_due_unix() -> int:
	var days := int(DURATION_OPTIONS[duration_option.selected]["days"])
	if days <= 0:
		return 0
	return GameState.now_unix() + days * ProgressSystem.DAY_SECONDS


func get_subtask_titles() -> Array:
	var titles := []
	for part in subtasks_edit.text.split(",", false):
		var trimmed := part.strip_edges()
		if not trimmed.is_empty():
			titles.append(trimmed)
	return titles


func _update_preview() -> void:
	if not _editing_id.is_empty():
		preview_label.text = "Edits apply to the existing building on tile %d,%d" % [_cell.x, _cell.y]
		return
	var subtasks := get_subtask_titles()
	var type_id := BuildingCatalog.select_type_for(
		float(int(DURATION_OPTIONS[duration_option.selected]["days"])), subtasks.size(), GameState.level
	)
	var size := BuildingCatalog.get_size(type_id)
	preview_label.text = "%s  ·  %d tile(s)  ·  tile %d,%d  ·  %s" % [
		BuildingCatalog.get_display_name(type_id),
		size,
		_cell.x,
		_cell.y,
		GridSystem.terrain_name(GameState.get_terrain(_cell)),
	]


func _on_create_pressed() -> void:
	var title := title_edit.text.strip_edges()
	if title.is_empty():
		show_error("Give the task a name first.")
		title_edit.grab_focus()
		return
	if not _editing_id.is_empty():
		_save_edit(title)
		return

	submitted.emit({
		"title": title,
		"description": description_edit.text.strip_edges(),
		"cell": _cell,
		"due_unix": get_due_unix(),
		"subtasks": get_subtask_titles(),
	})


func _save_edit(title: String) -> void:
	var task_id := _editing_id
	GameState.update_task(task_id, {
		"title": title,
		"description": description_edit.text.strip_edges(),
		"due_unix": get_due_unix(),
	})
	GameState.set_subtasks(task_id, get_subtask_titles())
	_editing_id = ""
	changed.emit(task_id)
	close()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		close()
