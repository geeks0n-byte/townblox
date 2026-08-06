extends Control

const PALETTE_ITEM_SCENE := preload("res://PaletteItem.tscn")
const ICON_SWATCH_SCENE := preload("res://IconSwatch.tscn")

const STICK_DEADZONE := 0.45
const STICK_INITIAL_DELAY := 0.28
const STICK_REPEAT_DELAY := 0.1

const PROMPT_KEYBOARD := "WASD/Arrows move · Space/Enter place · Del erase · R rotate · Wheel/+- zoom · MMB pan · Q/E building · C clear · N new map · Ctrl+Z/Y undo/redo"
const PROMPT_GAMEPAD_XBOX := "Stick/D-pad move · LT/RT zoom · Right stick pan · LB/RB building · A place · X erase · Y rotate · Back clear · Start new map"
const PROMPT_GAMEPAD_SONY := "Stick/D-pad move · L2/R2 zoom · Right stick pan · L1/R1 building · ✕ place · □ erase · △ rotate · Create clear · Options new map"

const BOTTOM_PROMPT_KEYBOARD := "Buildings  ·  drag onto board  ·  Wheel/+- zoom  ·  MMB pan  ·  R / Q-E"
const BOTTOM_PROMPT_GAMEPAD_XBOX := "Buildings  ·  LB/RB select  ·  LT/RT zoom  ·  A place  ·  Y rotate"
const BOTTOM_PROMPT_GAMEPAD_SONY := "Buildings  ·  L1/R1 select  ·  L2/R2 zoom  ·  ✕ place  ·  △ rotate"

enum InputMode {
	KEYBOARD_MOUSE,
	GAMEPAD,
}

@onready var board: Board = $Layout/Middle/BoardFrame/Board
@onready var input_bindings: InputBindings = $InputBindings
@onready var palette_list: HBoxContainer = $Layout/BottomBar/BottomMargin/BottomVBox/PaletteScroll/PaletteList
@onready var recipe_list: VBoxContainer = $Layout/Middle/SidePanel/Margin/SideVBox/RecipeScroll/RecipeList
@onready var terrain_list: VBoxContainer = $Layout/Middle/SidePanel/Margin/SideVBox/TerrainScroll/TerrainList
@onready var hazard_list: VBoxContainer = $Layout/Middle/SidePanel/Margin/SideVBox/HazardScroll/HazardList
@onready var clear_button: Button = $Layout/TopBar/ClearButton
@onready var new_shape_button: Button = $Layout/TopBar/NewShapeButton
@onready var undo_button: Button = $Layout/TopBar/UndoButton
@onready var redo_button: Button = $Layout/TopBar/RedoButton
@onready var prompt_label: Label = $Layout/TopBar/PromptLabel
@onready var bottom_title: Label = $Layout/BottomBar/BottomMargin/BottomVBox/BottomTitle
@onready var chatter_label: Label = $Layout/StatusRow/ChatterLabel
@onready var citizen_count_label: Label = $Layout/StatusRow/CitizenStatus/CitizenCountLabel
@onready var citizen_mood_label: Label = $Layout/StatusRow/CitizenStatus/CitizenMoodLabel
@onready var mood_icon: TextureRect = $Layout/StatusRow/CitizenStatus/MoodIcon
@onready var day_clock_label: Label = $Layout/StatusRow/CitizenStatus/DayClockLabel

var selected_building_index := 0
var input_mode: InputMode = InputMode.KEYBOARD_MOUSE
var stick_held_dir := Vector2i.ZERO
var stick_repeat_timer := 0.0
var stick_moved_once := false
var _last_citizen_count := -1
var _last_citizen_mood_label := ""
var _last_day_clock := ""


func _ready() -> void:
	TileLibrary.ensure_ready()
	_build_palette()
	_build_recipes()
	_build_terrain_legend()
	_build_hazards()
	_on_history_changed(board.can_undo(), board.can_redo())
	_apply_building_selection()
	if input_bindings != null:
		input_bindings.profile_changed.connect(_on_pad_profile_changed)
	if board != null and not board.day_phase_changed.is_connected(_on_day_phase_changed):
		board.day_phase_changed.connect(_on_day_phase_changed)
	_refresh_prompts()
	_refresh_citizen_status(true)
	_refresh_day_clock(true)


func _process(delta: float) -> void:
	_update_action_cursor(delta)
	_poll_action_buttons()
	_poll_camera_controls(delta)
	_refresh_citizen_status()
	_refresh_day_clock()


func _input(event: InputEvent) -> void:
	_detect_input_device(event)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_Z and event.shift_pressed:
			board.redo()
			get_viewport().set_input_as_handled()
			return
		if event.ctrl_pressed and event.keycode == KEY_Z:
			board.undo()
			get_viewport().set_input_as_handled()
			return
		if event.ctrl_pressed and event.keycode == KEY_Y:
			board.redo()
			get_viewport().set_input_as_handled()


func _poll_action_buttons() -> void:
	if Input.is_action_just_pressed(InputBindings.ACTION_PLACE):
		board.place_gamepad_selection()
	if Input.is_action_just_pressed(InputBindings.ACTION_ERASE):
		board.erase_gamepad_cell()
	if Input.is_action_just_pressed(InputBindings.ACTION_ROTATE):
		if get_viewport().gui_is_dragging():
			board.toggle_drag_rotation()
		else:
			board.rotate_gamepad_selection()
	if Input.is_action_just_pressed(InputBindings.ACTION_PREV_BUILDING):
		_cycle_gamepad_building(-1)
	if Input.is_action_just_pressed(InputBindings.ACTION_NEXT_BUILDING):
		_cycle_gamepad_building(1)
	if Input.is_action_just_pressed(InputBindings.ACTION_CLEAR):
		board.clear_grid()
	if Input.is_action_just_pressed(InputBindings.ACTION_NEW_SHAPE):
		board.generate_board_shape()


func _poll_camera_controls(delta: float) -> void:
	if board == null or input_bindings == null:
		return
	var zoom_axis := input_bindings.get_zoom_axis()
	if absf(zoom_axis) > 0.12:
		# Continuous zoom while triggers / +/- held.
		var factor := pow(Board.ZOOM_STEP, zoom_axis * delta * 4.5)
		board.zoom_by(factor)
	var pan := input_bindings.get_pan_vector()
	if pan.length_squared() > 0.01 and board.view_zoom > 1.001:
		board.pan_by(pan * delta * 420.0)


func _build_palette() -> void:
	for child in palette_list.get_children():
		child.queue_free()

	for building_type in Board.PLACEABLE_TYPES:
		var item := PALETTE_ITEM_SCENE.instantiate() as PaletteItem
		palette_list.add_child(item)
		item.setup(
			building_type,
			Board.type_name(building_type),
			Board.type_color(building_type),
			Board.type_footprint(building_type)
		)
	_refresh_palette_selection()


func select_building_type(building_type: int) -> void:
	var index := Board.PLACEABLE_TYPES.find(building_type as Board.BuildingType)
	if index < 0:
		return
	selected_building_index = index
	_apply_building_selection()


func _apply_building_selection() -> void:
	board.set_gamepad_selection(Board.PLACEABLE_TYPES[selected_building_index])
	_refresh_palette_selection()


func _refresh_palette_selection() -> void:
	if palette_list == null:
		return
	var selected_type: Board.BuildingType = Board.PLACEABLE_TYPES[selected_building_index]
	for child in palette_list.get_children():
		if child is PaletteItem:
			var item := child as PaletteItem
			item.set_selected(item.building_type == selected_type)
			if item.is_selected:
				_ensure_palette_item_visible(item)


func _ensure_palette_item_visible(item: Control) -> void:
	var scroll := palette_list.get_parent() as ScrollContainer
	if scroll == null:
		return
	var item_left := item.position.x
	var item_right := item_left + item.size.x
	var view_left := scroll.scroll_horizontal
	var view_right := view_left + scroll.size.x
	if item_left < view_left:
		scroll.scroll_horizontal = int(item_left)
	elif item_right > view_right:
		scroll.scroll_horizontal = int(item_right - scroll.size.x)


func _build_recipes() -> void:
	for child in recipe_list.get_children():
		child.queue_free()

	for recipe in Board.recipe_list():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		recipe_list.add_child(row)

		var swatch := ICON_SWATCH_SCENE.instantiate() as IconSwatch
		swatch.custom_minimum_size = Vector2(28, 22)
		swatch.setup_recipe(str(recipe["id"]), recipe["color"])
		row.add_child(swatch)

		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		label.text = "%s\n%s" % [recipe["name"], recipe["desc"]]
		label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9, 1))
		row.add_child(label)


func _build_terrain_legend() -> void:
	for child in terrain_list.get_children():
		child.queue_free()

	for terrain in Board.terrain_list():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		terrain_list.add_child(row)

		var swatch := ICON_SWATCH_SCENE.instantiate() as IconSwatch
		swatch.custom_minimum_size = Vector2(28, 22)
		swatch.setup_terrain(int(terrain["type"]), terrain["color"])
		row.add_child(swatch)

		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		label.text = "%s\n%s" % [terrain["name"], terrain["desc"]]
		label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9, 1))
		row.add_child(label)


func _build_hazards() -> void:
	for child in hazard_list.get_children():
		child.queue_free()

	for hazard in Board.hazard_list():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		hazard_list.add_child(row)

		var swatch_a := ICON_SWATCH_SCENE.instantiate() as IconSwatch
		swatch_a.custom_minimum_size = Vector2(22, 18)
		var type_a: Board.BuildingType = hazard["a"] as Board.BuildingType
		swatch_a.setup_building(type_a, Board.type_color(type_a))
		row.add_child(swatch_a)

		var swatch_b := ICON_SWATCH_SCENE.instantiate() as IconSwatch
		swatch_b.custom_minimum_size = Vector2(22, 18)
		var type_b: Board.BuildingType = hazard["b"] as Board.BuildingType
		swatch_b.setup_building(type_b, Board.type_color(type_b))
		row.add_child(swatch_b)

		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 12)
		label.text = "%s\n%s" % [hazard["name"], hazard["desc"]]
		label.add_theme_color_override("font_color", Color(0.9, 0.72, 0.72, 1))
		row.add_child(label)


func _on_clear_pressed() -> void:
	board.clear_grid()


func _on_new_shape_pressed() -> void:
	board.generate_board_shape()


func _on_undo_pressed() -> void:
	board.undo()


func _on_redo_pressed() -> void:
	board.redo()


func _on_history_changed(can_undo_now: bool, can_redo_now: bool) -> void:
	if undo_button == null or redo_button == null:
		return
	undo_button.disabled = not can_undo_now
	redo_button.disabled = not can_redo_now


func _on_town_chatter(message: String) -> void:
	if chatter_label != null:
		chatter_label.text = message
	_refresh_citizen_status(true)


func _refresh_citizen_status(force: bool = false) -> void:
	if board == null or board.citizen_sim == null:
		return
	if citizen_count_label == null or citizen_mood_label == null:
		return
	var report: Dictionary = board.citizen_sim.get_town_mood_report()
	var count: int = int(report.get("count", 0))
	var mood_text: String = str(report.get("label", "Quiet"))
	if not force and count == _last_citizen_count and mood_text == _last_citizen_mood_label:
		return
	_last_citizen_count = count
	_last_citizen_mood_label = mood_text

	var capacity: int = int(report.get("capacity", CitizenSim.MAX_CITIZENS))
	citizen_count_label.text = "Citizens  %d / %d" % [count, capacity]
	citizen_mood_label.text = mood_text
	citizen_mood_label.add_theme_color_override("font_color", report.get("color", Color(0.72, 0.76, 0.82)) as Color)

	if mood_icon != null:
		var emote_name := str(report.get("emote", ""))
		if emote_name.is_empty():
			mood_icon.texture = null
			mood_icon.modulate = Color(1, 1, 1, 0.35)
		else:
			mood_icon.texture = TileLibrary.emote_tex(emote_name)
			mood_icon.modulate = Color.WHITE


func _refresh_day_clock(force: bool = false) -> void:
	if board == null or day_clock_label == null:
		return
	var clock := "%s  %s" % [board.day_phase_name(board.get_day_phase()), board.day_clock_label()]
	if not force and clock == _last_day_clock:
		return
	_last_day_clock = clock
	day_clock_label.text = clock
	match board.get_day_phase():
		Board.DayPhase.NIGHT:
			day_clock_label.add_theme_color_override("font_color", Color(0.65, 0.75, 0.95))
		Board.DayPhase.DAWN:
			day_clock_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.55))
		Board.DayPhase.DUSK:
			day_clock_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.45))
		_:
			day_clock_label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55))


func _on_day_phase_changed(phase_name: String) -> void:
	_refresh_day_clock(true)
	if chatter_label != null and not phase_name.is_empty():
		# Keep chatter if citizens already spoke; otherwise note the shift.
		pass


func _on_pad_profile_changed(_profile: InputBindings.PadProfile, _device_name: String) -> void:
	_refresh_prompts()


func _cycle_gamepad_building(step: int) -> void:
	selected_building_index = (selected_building_index + step) % Board.PLACEABLE_TYPES.size()
	if selected_building_index < 0:
		selected_building_index += Board.PLACEABLE_TYPES.size()
	_apply_building_selection()


func _detect_input_device(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		_set_input_mode(InputMode.KEYBOARD_MOUSE)
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length_squared() > 4.0:
			_set_input_mode(InputMode.KEYBOARD_MOUSE)
	elif event is InputEventJoypadButton:
		_set_input_mode(InputMode.GAMEPAD)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= STICK_DEADZONE:
			_set_input_mode(InputMode.GAMEPAD)


func _set_input_mode(mode: InputMode) -> void:
	if input_mode == mode:
		return
	input_mode = mode
	_refresh_prompts()


func _refresh_prompts() -> void:
	if prompt_label == null or bottom_title == null:
		return
	if input_mode == InputMode.GAMEPAD:
		var is_sony := input_bindings != null and input_bindings.active_profile == InputBindings.PadProfile.SONY
		if is_sony:
			prompt_label.text = PROMPT_GAMEPAD_SONY
			bottom_title.text = BOTTOM_PROMPT_GAMEPAD_SONY
		else:
			prompt_label.text = PROMPT_GAMEPAD_XBOX
			bottom_title.text = BOTTOM_PROMPT_GAMEPAD_XBOX
	else:
		prompt_label.text = PROMPT_KEYBOARD
		bottom_title.text = BOTTOM_PROMPT_KEYBOARD


func _update_action_cursor(delta: float) -> void:
	var stick := Input.get_vector(
		InputBindings.ACTION_MOVE_LEFT,
		InputBindings.ACTION_MOVE_RIGHT,
		InputBindings.ACTION_MOVE_UP,
		InputBindings.ACTION_MOVE_DOWN,
		STICK_DEADZONE
	)

	var dir := Vector2i.ZERO
	if stick.x <= -STICK_DEADZONE:
		dir.x = -1
	elif stick.x >= STICK_DEADZONE:
		dir.x = 1
	if stick.y <= -STICK_DEADZONE:
		dir.y = -1
	elif stick.y >= STICK_DEADZONE:
		dir.y = 1

	if dir == Vector2i.ZERO:
		stick_held_dir = Vector2i.ZERO
		stick_repeat_timer = 0.0
		stick_moved_once = false
		return

	if _is_gamepad_move_active():
		_set_input_mode(InputMode.GAMEPAD)
	else:
		_set_input_mode(InputMode.KEYBOARD_MOUSE)

	if dir != stick_held_dir:
		stick_held_dir = dir
		stick_repeat_timer = 0.0
		stick_moved_once = false
		board.move_gamepad_cursor(dir)
		stick_moved_once = true
		stick_repeat_timer = STICK_INITIAL_DELAY
		return

	stick_repeat_timer -= delta
	if stick_repeat_timer > 0.0:
		return

	board.move_gamepad_cursor(dir)
	stick_repeat_timer = STICK_REPEAT_DELAY if stick_moved_once else STICK_INITIAL_DELAY
	stick_moved_once = true


func _is_gamepad_move_active() -> bool:
	for device_id in Input.get_connected_joypads():
		var sample := Vector2(
			Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
		)
		if sample.length() >= STICK_DEADZONE:
			return true
		if Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_LEFT) \
			or Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_RIGHT) \
			or Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_UP) \
			or Input.is_joy_button_pressed(device_id, JOY_BUTTON_DPAD_DOWN):
			return true
	return false
