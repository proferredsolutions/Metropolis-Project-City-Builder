## Renders the terrain TileMap plus unlocked decoration props, and owns the
## auto-fading tap highlight.
##
## Purely a view: it reads terrain/occupancy from GameState and never mutates it.
class_name CityGrid
extends Node2D

const TILESET := preload("res://assets/sprites/terrain/terrain_tileset.tres")
const LAYER_TERRAIN := 0
const SOURCE_ID := 0
const DECOR_CHANCE := 0.3
const DECOR_SCALE := 1.0

@onready var tilemap: TileMap = $TileMap
@onready var decor: Node2D = $Decor
@onready var highlight: GridHighlight = $Highlight

var _grid_size: int = GridSystem.MIN_GRID_SIZE
var _decor_ids: Array = ["bush"]


func _ready() -> void:
	tilemap.tile_set = TILESET
	highlight.queue_redraw()


## Redraw terrain for the unlocked area and re-scatter decoration.
func rebuild(grid_size: int, terrain: Dictionary, decor_ids: Array, occupied: Dictionary) -> void:
	_grid_size = grid_size
	_decor_ids = decor_ids
	tilemap.clear()
	for y in grid_size:
		for x in grid_size:
			var cell := Vector2i(x, y)
			var terrain_id := int(terrain.get(cell, GridSystem.Terrain.GRASS))
			var atlas_coords: Vector2i = GridSystem.TILE_COORDS[terrain_id]
			tilemap.set_cell(LAYER_TERRAIN, cell, SOURCE_ID, atlas_coords)
	_rebuild_decor(terrain, occupied)


func _rebuild_decor(terrain: Dictionary, occupied: Dictionary) -> void:
	for child in decor.get_children():
		child.queue_free()
	if _decor_ids.is_empty():
		return
	for y in _grid_size:
		for x in _grid_size:
			var cell := Vector2i(x, y)
			if occupied.has(cell):
				continue
			var terrain_id := int(terrain.get(cell, GridSystem.Terrain.GRASS))
			if not GridSystem.is_decoratable(terrain_id):
				continue
			if _roll(cell) >= DECOR_CHANCE:
				continue
			var decor_id := String(_decor_ids[int(_roll(cell + Vector2i(7, 13)) * 997.0) % _decor_ids.size()])
			_add_prop(decor_id, cell)


## Stable pseudo-random value in 0.0 - 1.0 for a cell, so the same city always
## decorates itself the same way.
func _roll(cell: Vector2i) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cell)
	return rng.randf()


func _add_prop(decor_id: String, cell: Vector2i) -> void:
	var path: String = BuildingCatalog.DECOR_TEXTURES.get(decor_id, "")
	if path.is_empty():
		return
	var texture: Texture2D = load(path)
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2(DECOR_SCALE, DECOR_SCALE)
	# Props are drawn bottom-aligned on their tile's centre.
	sprite.offset = Vector2(0, -texture.get_height() * 0.5)
	var jitter := Vector2(_roll(cell + Vector2i(3, 5)) * 10.0 - 5.0, _roll(cell + Vector2i(9, 2)) * 4.0 - 2.0)
	sprite.position = GridSystem.cell_to_world(cell) + jitter
	decor.add_child(sprite)


func show_highlight(cell: Vector2i, size: int = 1, valid: bool = true) -> void:
	highlight.show_at(cell, size, valid)
