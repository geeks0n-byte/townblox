extends RefCounted

## Beat Cop urban HUD tokens — asphalt greys, brick/amber accents (no neon teal).
## Preload this script (avoid class_name circular/reg timing issues).

const ASPHALT := Color("1a1c22")
const ASPHALT_DK := Color("101218")
const ASPHALT_LT := Color("2a2e38")
const CURB := Color("3a3e48")
const BRICK := Color("9a5a48")
const AMBER := Color("e0a040")
const AMBER_DIM := Color("a87830")
const PAPER := Color("e8e0d4")
const MUTED := Color("9a968c")
const DANGER := Color("c4453a")
const OK := Color("6a9a6a")

static var _display_font: Font
static var _ui_font: Font


static func display_font() -> Font:
	if _display_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI Semibold", "Arial Black", "Impact"])
		_display_font = f
	return _display_font


static func ui_font() -> Font:
	if _ui_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Segoe UI", "Candara", "Tahoma", "Arial"])
		_ui_font = f
	return _ui_font


static func panel_style(accent: Color = CURB, fill: Color = ASPHALT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = accent
	s.set_border_width_all(1)
	s.set_corner_radius_all(0)
	s.content_margin_left = 8
	s.content_margin_top = 6
	s.content_margin_right = 8
	s.content_margin_bottom = 6
	return s


static func button_style(border: Color, fill: Color = ASPHALT_LT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(0)
	s.content_margin_left = 12
	s.content_margin_top = 6
	s.content_margin_right = 12
	s.content_margin_bottom = 6
	return s


static func apply_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", button_style(AMBER_DIM))
	btn.add_theme_stylebox_override("hover", button_style(AMBER, Color("32281c")))
	btn.add_theme_stylebox_override("pressed", button_style(BRICK, ASPHALT_DK))
	btn.add_theme_stylebox_override("disabled", button_style(CURB, ASPHALT_DK))
	btn.add_theme_font_override("font", ui_font())
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", PAPER)
	btn.add_theme_color_override("font_hover_color", AMBER)
	btn.add_theme_color_override("font_pressed_color", PAPER)
	btn.add_theme_color_override("font_disabled_color", MUTED)


static func apply_label(label: Label, display: bool = false, size: int = 14, color: Color = PAPER) -> void:
	label.add_theme_font_override("font", display_font() if display else ui_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
