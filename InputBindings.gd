class_name InputBindings
extends Node

## Configures InputMap for keyboard + multiple gamepad layouts (Xbox / DualSense).

const ACTION_MOVE_LEFT := "tb_move_left"
const ACTION_MOVE_RIGHT := "tb_move_right"
const ACTION_MOVE_UP := "tb_move_up"
const ACTION_MOVE_DOWN := "tb_move_down"
const ACTION_PLACE := "tb_place"
const ACTION_ERASE := "tb_erase"
const ACTION_ROTATE := "tb_rotate"
const ACTION_PREV_BUILDING := "tb_prev_building"
const ACTION_NEXT_BUILDING := "tb_next_building"
const ACTION_CLEAR := "tb_clear"
const ACTION_NEW_SHAPE := "tb_new_shape"
const ACTION_UNDO := "tb_undo"
const ACTION_REDO := "tb_redo"
const ACTION_ZOOM_IN := "tb_zoom_in"
const ACTION_ZOOM_OUT := "tb_zoom_out"
const ACTION_PAN_LEFT := "tb_pan_left"
const ACTION_PAN_RIGHT := "tb_pan_right"
const ACTION_PAN_UP := "tb_pan_up"
const ACTION_PAN_DOWN := "tb_pan_down"

enum PadProfile {
	XBOX,
	SONY,
}

signal profile_changed(profile: PadProfile, device_name: String)

var active_profile: PadProfile = PadProfile.XBOX
var active_device_name := "None"


func _ready() -> void:
	_ensure_actions()
	_bind_keyboard()
	_bind_shared_gamepad()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh_connected_profile()


func get_move_vector() -> Vector2:
	return Input.get_vector(ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT, ACTION_MOVE_UP, ACTION_MOVE_DOWN, 0.45)


func get_pan_vector() -> Vector2:
	return Input.get_vector(ACTION_PAN_LEFT, ACTION_PAN_RIGHT, ACTION_PAN_UP, ACTION_PAN_DOWN, 0.35)


func get_zoom_axis() -> float:
	# Positive = zoom in, negative = zoom out (triggers / keys).
	var zoom_in := Input.get_action_strength(ACTION_ZOOM_IN)
	var zoom_out := Input.get_action_strength(ACTION_ZOOM_OUT)
	return zoom_in - zoom_out


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_connected_profile()


func _refresh_connected_profile() -> void:
	var devices := Input.get_connected_joypads()
	if devices.is_empty():
		active_device_name = "None"
		_apply_profile(PadProfile.XBOX)
		return

	var device_id: int = devices[0]
	active_device_name = Input.get_joy_name(device_id)
	var profile := _detect_profile(active_device_name)
	_apply_profile(profile)


func _detect_profile(device_name: String) -> PadProfile:
	var n := device_name.to_lower()
	if (
		"dualsense" in n
		or "dualshock" in n
		or "ps5" in n
		or "ps4" in n
		or "playstation" in n
		or n == "wireless controller"
	):
		return PadProfile.SONY
	return PadProfile.XBOX


func _apply_profile(profile: PadProfile) -> void:
	active_profile = profile
	_clear_joy_events_from_actions()
	_bind_shared_gamepad()
	match profile:
		PadProfile.SONY:
			_bind_sony_face_buttons()
		_:
			_bind_xbox_face_buttons()
	profile_changed.emit(active_profile, active_device_name)


func _ensure_actions() -> void:
	for action in [
		ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT, ACTION_MOVE_UP, ACTION_MOVE_DOWN,
		ACTION_PLACE, ACTION_ERASE, ACTION_ROTATE,
		ACTION_PREV_BUILDING, ACTION_NEXT_BUILDING,
		ACTION_CLEAR, ACTION_NEW_SHAPE, ACTION_UNDO, ACTION_REDO,
		ACTION_ZOOM_IN, ACTION_ZOOM_OUT,
		ACTION_PAN_LEFT, ACTION_PAN_RIGHT, ACTION_PAN_UP, ACTION_PAN_DOWN,
	]:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.35)


func _clear_joy_events_from_actions() -> void:
	for action in [
		ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT, ACTION_MOVE_UP, ACTION_MOVE_DOWN,
		ACTION_PLACE, ACTION_ERASE, ACTION_ROTATE,
		ACTION_PREV_BUILDING, ACTION_NEXT_BUILDING,
		ACTION_CLEAR, ACTION_NEW_SHAPE,
		ACTION_ZOOM_IN, ACTION_ZOOM_OUT,
		ACTION_PAN_LEFT, ACTION_PAN_RIGHT, ACTION_PAN_UP, ACTION_PAN_DOWN,
	]:
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				InputMap.action_erase_event(action, event)


func _bind_keyboard() -> void:
	_add_key(ACTION_MOVE_LEFT, KEY_A)
	_add_key(ACTION_MOVE_LEFT, KEY_LEFT)
	_add_key(ACTION_MOVE_RIGHT, KEY_D)
	_add_key(ACTION_MOVE_RIGHT, KEY_RIGHT)
	_add_key(ACTION_MOVE_UP, KEY_W)
	_add_key(ACTION_MOVE_UP, KEY_UP)
	_add_key(ACTION_MOVE_DOWN, KEY_S)
	_add_key(ACTION_MOVE_DOWN, KEY_DOWN)
	_add_key(ACTION_PLACE, KEY_ENTER)
	_add_key(ACTION_PLACE, KEY_SPACE)
	_add_key(ACTION_ERASE, KEY_DELETE)
	_add_key(ACTION_ERASE, KEY_BACKSPACE)
	_add_key(ACTION_ROTATE, KEY_R)
	_add_key(ACTION_PREV_BUILDING, KEY_Q)
	_add_key(ACTION_NEXT_BUILDING, KEY_E)
	_add_key(ACTION_CLEAR, KEY_C)
	_add_key(ACTION_NEW_SHAPE, KEY_N)
	_add_key(ACTION_ZOOM_IN, KEY_EQUAL)
	_add_key(ACTION_ZOOM_IN, KEY_KP_ADD)
	_add_key(ACTION_ZOOM_OUT, KEY_MINUS)
	_add_key(ACTION_ZOOM_OUT, KEY_KP_SUBTRACT)


func _bind_shared_gamepad() -> void:
	# D-pad (same indices on Xbox + DualSense when using SDL mapping)
	_add_joy_button(ACTION_MOVE_LEFT, JOY_BUTTON_DPAD_LEFT)
	_add_joy_button(ACTION_MOVE_RIGHT, JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button(ACTION_MOVE_UP, JOY_BUTTON_DPAD_UP)
	_add_joy_button(ACTION_MOVE_DOWN, JOY_BUTTON_DPAD_DOWN)

	# Left stick
	_add_joy_axis(ACTION_MOVE_LEFT, JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis(ACTION_MOVE_RIGHT, JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis(ACTION_MOVE_UP, JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis(ACTION_MOVE_DOWN, JOY_AXIS_LEFT_Y, 1.0)

	# Right stick pans the zoomed view
	_add_joy_axis(ACTION_PAN_LEFT, JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_axis(ACTION_PAN_RIGHT, JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_axis(ACTION_PAN_UP, JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_axis(ACTION_PAN_DOWN, JOY_AXIS_RIGHT_Y, 1.0)

	# Triggers zoom (LT out / RT in)
	_add_joy_axis(ACTION_ZOOM_OUT, JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_joy_axis(ACTION_ZOOM_IN, JOY_AXIS_TRIGGER_RIGHT, 1.0)

	# Shoulders / menu (stable across Xbox + DualSense SDL)
	_add_joy_button(ACTION_PREV_BUILDING, JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button(ACTION_NEXT_BUILDING, JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button(ACTION_CLEAR, JOY_BUTTON_BACK)
	_add_joy_button(ACTION_NEW_SHAPE, JOY_BUTTON_START)


func _bind_xbox_face_buttons() -> void:
	_add_joy_button(ACTION_PLACE, JOY_BUTTON_A)
	_add_joy_button(ACTION_ERASE, JOY_BUTTON_X)
	_add_joy_button(ACTION_ROTATE, JOY_BUTTON_Y)


func _bind_sony_face_buttons() -> void:
	# Godot/SDL maps DualSense Cross/Square/Triangle to A/X/Y when recognized.
	_add_joy_button(ACTION_PLACE, JOY_BUTTON_A) # Cross
	_add_joy_button(ACTION_ERASE, JOY_BUTTON_X) # Square
	_add_joy_button(ACTION_ROTATE, JOY_BUTTON_Y) # Triangle

func _add_key(action: String, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	_add_event_unique(action, event)


func _add_joy_button(action: String, button_index: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index as JoyButton
	_add_event_unique(action, event)


func _add_joy_axis(action: String, axis: JoyAxis, axis_value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	_add_event_unique(action, event)


func _add_event_unique(action: String, event: InputEvent) -> void:
	for existing in InputMap.action_get_events(action):
		if existing == null:
			continue
		if existing is InputEventKey and event is InputEventKey:
			if (existing as InputEventKey).physical_keycode == (event as InputEventKey).physical_keycode:
				return
		elif existing is InputEventJoypadButton and event is InputEventJoypadButton:
			if (existing as InputEventJoypadButton).button_index == (event as InputEventJoypadButton).button_index:
				return
		elif existing is InputEventJoypadMotion and event is InputEventJoypadMotion:
			var a := existing as InputEventJoypadMotion
			var b := event as InputEventJoypadMotion
			if a.axis == b.axis and is_equal_approx(a.axis_value, b.axis_value):
				return
	InputMap.action_add_event(action, event)


func profile_label() -> String:
	match active_profile:
		PadProfile.SONY:
			return "DualSense/PlayStation"
		_:
			return "Xbox/Generic"
