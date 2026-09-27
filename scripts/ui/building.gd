## One building on the map = one real-world task.
##
## The building never decides anything: it reads the task through GameState and
## renders whatever ProgressSystem says. Progress drives the construction stage
## sprite, the height, the villager working on it and the overdue decal.
class_name Building
extends Node2D

## Point inside the 64x64 building art that sits on the tile centre.
const FOOT_OFFSET := Vector2(0, -26)
const STAGE_FADE := 0.35
const VILLAGER_FRAMES := 5
const VILLAGER_FPS := 5.0
const COMPLETE_POP := 1.12

@onready var stage_sprite: Sprite2D = $Stage
@onready var overdue_sprite: Sprite2D = $Overdue
@onready var villager: Sprite2D = $Villager
@onready var smoke: CPUParticles2D = $Smoke

var task_id: String = ""
var _was_complete: bool = false
var _anim_time: float = 0.0


func _ready() -> void:
	stage_sprite.offset = FOOT_OFFSET
	overdue_sprite.offset = FOOT_OFFSET
	overdue_sprite.texture = load(BuildingCatalog.OVERDUE_DECAL)
	overdue_sprite.visible = false
	villager.texture = load(BuildingCatalog.VILLAGER_SHEET)
	villager.hframes = VILLAGER_FRAMES
	villager.vframes = 1
	villager.offset = Vector2(-4, -8)
	villager.visible = false
	smoke.texture = load(BuildingCatalog.PARTICLE_DOT)
	smoke.emitting = false
	smoke.local_coords = false


## Attach this building to a task and place it on the map.
func setup(task: TaskData) -> void:
	task_id = task.id
	position = GridSystem.cell_to_world(task.cell)
	stage_sprite.texture = load(BuildingCatalog.get_stage_texture_path(task.building_type, 0))
	overdue_sprite.texture = load(BuildingCatalog.OVERDUE_DECAL)
	villager.texture = load(BuildingCatalog.VILLAGER_SHEET)
	smoke.texture = load(BuildingCatalog.PARTICLE_DOT)
	smoke.position = _smoke_origin(task.building_type)
	refresh(GameState.now_unix(), true)


func _process(delta: float) -> void:
	if not villager.visible:
		return
	_anim_time += delta
	var frame := int(_anim_time * VILLAGER_FPS) % VILLAGER_FRAMES
	villager.frame = frame
	# Small patrol so the worker reads as "busy" rather than frozen.
	villager.position.x = 10.0 + sin(_anim_time * 2.4) * 7.0


## Re-read the task and update every visual. Called on change and on a slow timer.
func refresh(now_unix: int, immediate: bool = false) -> void:
	var task := GameState.get_task(task_id)
	if task == null:
		queue_free()
		return

	var progress := ProgressSystem.get_progress(task, now_unix)
	var stage := ProgressSystem.get_visual_stage(progress)
	var is_complete := progress >= 1.0

	var texture_path := BuildingCatalog.get_stage_texture_path(task.building_type, stage)
	if stage_sprite.texture == null or stage_sprite.texture.resource_path != texture_path:
		stage_sprite.texture = load(texture_path)

	var target_height := ProgressSystem.get_building_height(progress)
	if immediate:
		stage_sprite.scale = Vector2(1.0, target_height)
	else:
		var tween := create_tween()
		tween.tween_property(stage_sprite, "scale", Vector2(1.0, target_height), STAGE_FADE)

	# Under construction => a villager is on site. Done => smoke instead.
	var under_construction := progress > 0.0 and not is_complete
	if villager.visible != under_construction:
		villager.visible = under_construction
	smoke.emitting = is_complete

	overdue_sprite.visible = ProgressSystem.is_overdue(task, now_unix) and not is_complete
	if overdue_sprite.visible:
		overdue_sprite.modulate = Color(1.0, 1.0, 1.0, 0.55 + 0.15 * sin(float(Time.get_ticks_msec()) * 0.003))

	if is_complete and not _was_complete:
		_play_completion()
	_was_complete = is_complete


func _play_completion() -> void:
	var tween := create_tween()
	tween.tween_property(stage_sprite, "scale", Vector2(1.0, COMPLETE_POP), 0.12)
	tween.tween_property(stage_sprite, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	smoke.restart()


func _smoke_origin(building_type: String) -> Vector2:
	match building_type:
		"workshop":
			return FOOT_OFFSET + Vector2(14, -32)
		_:
			return FOOT_OFFSET + Vector2(0, -26)
