class_name PaletteItem
extends PanelContainer

const ICON_SWATCH_SCENE := preload("res://IconSwatch.tscn")
const TILE_SIZE := Vector2(112, 92)

@export var style_normal: StyleBoxFlat
@export var style_selected: StyleBoxFlat

var building_type: int = 0
var is_selected := false

@onready var swatch: IconSwatch = $Content/Swatch
@onready var name_label: Label = $Content/NameLabel
@onready var size_label: Label = $Content/SizeLabel


func _ready() -> void:
	custom_minimum_size = TILE_SIZE
	size = TILE_SIZE
	clip_contents = true


func setup(type_value: int, type_label: String, type_color: Color, footprint: Vector2i) -> void:
	building_type = type_value
	custom_minimum_size = TILE_SIZE
	size = TILE_SIZE
	swatch.setup_building(type_value, type_color)
	name_label.text = type_label
	var outer_radius := mini(footprint.x, footprint.y)
	size_label.text = "%dx%d · o%d" % [footprint.x, footprint.y, outer_radius]
	var rule_text := Board.placement_rule_text(type_value as Board.BuildingType)
	tooltip_text = type_label if rule_text.is_empty() else "%s\n%s" % [type_label, rule_text]
	set_selected(is_selected)


func set_selected(selected: bool) -> void:
	is_selected = selected
	var style := style_selected if selected and style_selected != null else style_normal
	if style != null:
		add_theme_stylebox_override("panel", style)


func _get_drag_data(_at_position: Vector2) -> Variant:
	Board.active_brush_rotated = false

	var preview := PanelContainer.new()
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.1, 0.11, 0.14, 0.96)
	preview_style.set_border_width_all(2)
	preview_style.border_color = Color(0.95, 0.85, 0.4, 1)
	preview_style.set_corner_radius_all(0)
	preview_style.content_margin_left = 8
	preview_style.content_margin_right = 8
	preview_style.content_margin_top = 8
	preview_style.content_margin_bottom = 8
	preview.add_theme_stylebox_override("panel", preview_style)

	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 8)
	preview.add_child(preview_row)

	var preview_swatch := ICON_SWATCH_SCENE.instantiate() as IconSwatch
	preview_swatch.custom_minimum_size = Vector2(32, 32)
	preview_swatch.setup_building(building_type, Board.type_color(building_type as Board.BuildingType))
	preview_row.add_child(preview_swatch)

	var label := Label.new()
	label.text = "%s  (R rotate)" % Board.type_name(building_type as Board.BuildingType)
	preview_row.add_child(label)

	set_drag_preview(preview)
	return {"building_type": building_type}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var main := get_tree().current_scene
		if main != null and main.has_method("select_building_type"):
			main.select_building_type(building_type)
