class_name IconSwatch
extends Control

enum IconKind {
	BUILDING,
	TERRAIN,
	RECIPE,
}

@export var icon_kind: IconKind = IconKind.BUILDING
@export var building_type: int = 0
@export var terrain_type: int = 0
@export var recipe_id: String = ""
@export var fill_color: Color = Color("1f2230")

var _anim_timer := 0.0


func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	TileLibrary.ensure_ready()


func _process(delta: float) -> void:
	if icon_kind == IconKind.TERRAIN:
		var terrain := terrain_type as Board.TerrainType
		if TileLibrary.terrain_frame_count(terrain) > 1:
			_anim_timer += delta
			if _anim_timer >= 1.0 / TileLibrary.ANIM_FPS:
				_anim_timer = 0.0
				queue_redraw()
	elif icon_kind == IconKind.BUILDING:
		var building := building_type as Board.BuildingType
		if TileLibrary.building_frame_count(building) > 1:
			_anim_timer += delta
			if _anim_timer >= 1.0 / TileLibrary.ANIM_FPS:
				_anim_timer = 0.0
				queue_redraw()


func setup_building(type_value: int, color: Color) -> void:
	TileLibrary.ensure_ready()
	icon_kind = IconKind.BUILDING
	building_type = type_value
	fill_color = color
	set_process(TileLibrary.building_frame_count(type_value as Board.BuildingType) > 1)
	queue_redraw()


func setup_terrain(type_value: int, color: Color) -> void:
	TileLibrary.ensure_ready()
	icon_kind = IconKind.TERRAIN
	terrain_type = type_value
	fill_color = color
	set_process(TileLibrary.terrain_frame_count(type_value as Board.TerrainType) > 1)
	queue_redraw()


func setup_recipe(id_value: String, color: Color) -> void:
	TileLibrary.ensure_ready()
	icon_kind = IconKind.RECIPE
	recipe_id = id_value
	fill_color = color
	set_process(false)
	queue_redraw()


func _draw() -> void:
	TileLibrary.ensure_ready()
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.08, 0.09, 0.12), true)
	var tex: Texture2D = null
	match icon_kind:
		IconKind.BUILDING:
			tex = TileLibrary.building_tex(building_type as Board.BuildingType)
		IconKind.TERRAIN:
			tex = TileLibrary.terrain_tex(terrain_type as Board.TerrainType)
		IconKind.RECIPE:
			tex = TileLibrary.recipe_tex(recipe_id)
	if tex != null:
		var pad := 2.0
		var inner := rect.grow(-pad)
		var side := minf(inner.size.x, inner.size.y)
		var dest := Rect2(inner.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))
		draw_texture_rect(tex, dest, false)
	draw_rect(rect, Color(0.05, 0.06, 0.08, 0.9), false, 2.0)
