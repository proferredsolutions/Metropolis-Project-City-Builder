## The auto-fading grid highlight drawn when a tile is tapped.
##
## Lives in world space over the TileMap; `show_at` is called on tap, and the
## highlight fades itself out if no further action follows.
class_name GridHighlight
extends Node2D

const FADE_SECONDS := 2.5
const COLOR_VALID := Color(0.45, 0.85, 0.5, 0.9)
const COLOR_INVALID := Color(0.9, 0.4, 0.35, 0.9)

var _cell: Vector2i = Vector2i.ZERO
var _size: int = 1
var _alpha: float = 0.0
var _color: Color = COLOR_VALID
var _tween: Tween


func _ready() -> void:
	z_index = 5
	set_process(true)


## Show the grid over `cell` for `size` tiles. Restarts the fade timer.
func show_at(cell: Vector2i, size: int = 1, valid: bool = true) -> void:
	_cell = cell
	_size = maxi(size, 1)
	_color = COLOR_VALID if valid else COLOR_INVALID
	_alpha = 1.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(FADE_SECONDS)
	_tween.tween_property(self, "_alpha", 0.0, 0.6)
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01:
		return
	var color := _color
	color.a *= _alpha
	for dy in _size:
		for dx in _size:
			_draw_tile(GridSystem.cell_to_world(Vector2i(_cell.x + dx, _cell.y + dy)), color)


func _draw_tile(centre: Vector2, color: Color) -> void:
	var half := GridSystem.TILE_SIZE * 0.5
	var points := PackedVector2Array([
		centre + Vector2(0, -half.y),
		centre + Vector2(half.x, 0),
		centre + Vector2(0, half.y),
		centre + Vector2(-half.x, 0),
	])
	# Soft fill so the tile under the finger is obvious.
	var fill := color
	fill.a *= 0.18
	draw_colored_polygon(points, fill)
	draw_polyline(points + PackedVector2Array([points[0]]), color, 2.0)
