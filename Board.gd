class_name Board
extends Control

enum BuildingType {
	NONE,
	PARK,
	FACTORY,
	ROAD,
	OFFICE,
	SKYSCRAPER,
	DOWNTOWN,
	SHOPS,
	RESIDENTIAL,
	SCHOOL,
	HOSPITAL,
	FARM,
	HARBOR,
	STADIUM,
	WAREHOUSE,
	HOTEL,
	MARKET,
}

enum TerrainType {
	OPEN,
	WATER,
	MOUNTAIN,
	RUINS,
}

## Continuous height field (0..1). Water/mountains are derived from thresholds.
const ELEV_WATER := 0.34
const ELEV_MOUNTAIN := 0.68
## World-space Y scale for elevation above the water line.
const ELEV_WORLD_SCALE := 3.2

const GRID_WIDTH := 48
const GRID_HEIGHT := 28
const TILE_PX := 32.0
const MAX_HISTORY := 64
const TILE_ANIM_INTERVAL := 1.0 / 30.0 ## Smooth redraw cadence for water crossfades.
## Pitch camera down only (no left/right tilt): foreshorten ground rows.
## Actual foreshortening may relax toward 1.0 so the map fills leftover vertical space.
const VIEW_Y_SCALE := 0.64
## Buildings/tall terrain stand up against the foreshortened ground.
## Facades use 32×64 sheets (aspect ~2) so height stays near 2 cells.
const ELEVATION_HEIGHT := 2.15
const TERRAIN_ELEVATION := 1.35
const ZOOM_MIN := 1.0
const ZOOM_MAX := 5.0
const ZOOM_STEP := 1.12
const DOF_ZOOM_START := 1.35
const ANIM_FRAME_MODULO := 16

## Actor sizes as fractions of ONE cell — chunky Beat Cop street cast.
const NPC_W := 0.28
const NPC_H := 0.48
const CAR_W := 0.62
const CAR_H := 0.40
const BIKE_W := 0.32
const BIKE_H := 0.42
const BUS_W := 0.82
const BUS_H := 0.46
const EMOTE_W := 0.22
const TERRAIN_COLORS := {
	TerrainType.OPEN: Color("1f2230"),
	TerrainType.WATER: Color("2a6f9e"),
	TerrainType.MOUNTAIN: Color("6a635c"),
	TerrainType.RUINS: Color("8a6b4a"),
}

const TERRAIN_INFLUENCE_COLORS := {
	TerrainType.WATER: Color("3d8fbf"),
	TerrainType.MOUNTAIN: Color("8a8178"),
	TerrainType.RUINS: Color("b08960"),
}

const TERRAIN_INFLUENCE_RADIUS := {
	TerrainType.WATER: 2,
	TerrainType.MOUNTAIN: 2,
	TerrainType.RUINS: 1,
}

const FEATURE_TERRAINS: Array[TerrainType] = [
	TerrainType.WATER,
	TerrainType.MOUNTAIN,
	TerrainType.RUINS,
]

const BUILDING_COLORS := {
	BuildingType.NONE: Color("1f2230"),
	BuildingType.PARK: Color("3dbf5c"),
	BuildingType.FACTORY: Color("7a7488"),
	BuildingType.ROAD: Color("c49a52"),
	BuildingType.OFFICE: Color("3f84d6"),
	BuildingType.SKYSCRAPER: Color("4a5678"),
	BuildingType.DOWNTOWN: Color("d4453a"),
	BuildingType.SHOPS: Color("e09a28"),
	BuildingType.RESIDENTIAL: Color("e07050"),
	BuildingType.SCHOOL: Color("2fbfc8"),
	BuildingType.HOSPITAL: Color("f0f4f8"),
	BuildingType.FARM: Color("8fbf2e"),
	BuildingType.HARBOR: Color("1f6f9e"),
	BuildingType.STADIUM: Color("d63a6a"),
	BuildingType.WAREHOUSE: Color("8a7355"),
	BuildingType.HOTEL: Color("b06ad8"),
	BuildingType.MARKET: Color("e85a3c"),
}

const OUTER_SINGLE_COLORS := {
	BuildingType.PARK: Color("7ee89a"),
	BuildingType.FACTORY: Color("a59fba"),
	BuildingType.ROAD: Color("e0bc78"),
	BuildingType.OFFICE: Color("84b8f5"),
	BuildingType.SKYSCRAPER: Color("8a96b8"),
	BuildingType.DOWNTOWN: Color("f08a7e"),
	BuildingType.SHOPS: Color("f5c56a"),
	BuildingType.RESIDENTIAL: Color("f0a888"),
	BuildingType.SCHOOL: Color("7ad8de"),
	BuildingType.HOSPITAL: Color("e8eef4"),
	BuildingType.FARM: Color("b8dc6a"),
	BuildingType.HARBOR: Color("5a9ec0"),
	BuildingType.STADIUM: Color("e8789a"),
	BuildingType.WAREHOUSE: Color("b4a080"),
	BuildingType.HOTEL: Color("d4a8ee"),
	BuildingType.MARKET: Color("f49078"),
}

const BUILDING_FOOTPRINTS := {
	# 1×1 brush cells; adjacent same-type cells merge into one building_id.
	BuildingType.PARK: Vector2i(1, 1),
	BuildingType.FACTORY: Vector2i(1, 1),
	BuildingType.ROAD: Vector2i(1, 1),
	BuildingType.OFFICE: Vector2i(1, 1),
	BuildingType.SKYSCRAPER: Vector2i(1, 1),
	BuildingType.DOWNTOWN: Vector2i(1, 1),
	BuildingType.SHOPS: Vector2i(1, 1),
	BuildingType.RESIDENTIAL: Vector2i(1, 1),
	BuildingType.SCHOOL: Vector2i(1, 1),
	BuildingType.HOSPITAL: Vector2i(1, 1),
	BuildingType.FARM: Vector2i(1, 1),
	BuildingType.HARBOR: Vector2i(1, 1),
	BuildingType.STADIUM: Vector2i(1, 1),
	BuildingType.WAREHOUSE: Vector2i(1, 1),
	BuildingType.HOTEL: Vector2i(1, 1),
	BuildingType.MARKET: Vector2i(1, 1),
}

const PLACEABLE_TYPES: Array[BuildingType] = [
	BuildingType.PARK,
	BuildingType.FACTORY,
	BuildingType.ROAD,
	BuildingType.OFFICE,
	BuildingType.SKYSCRAPER,
	BuildingType.DOWNTOWN,
	BuildingType.SHOPS,
	BuildingType.RESIDENTIAL,
	BuildingType.SCHOOL,
	BuildingType.HOSPITAL,
	BuildingType.FARM,
	BuildingType.HARBOR,
	BuildingType.STADIUM,
	BuildingType.WAREHOUSE,
	BuildingType.HOTEL,
	BuildingType.MARKET,
]

## Buildings that must sit next to specific terrain (Chebyshev adjacency).
## any_of: footprint must touch at least one listed terrain type.
## none_of: footprint must not touch any listed terrain type.
const PLACEMENT_RULES := {
	BuildingType.HARBOR: {
		"any_of": [TerrainType.WATER],
	},
	BuildingType.FARM: {
		"none_of": [TerrainType.MOUNTAIN, TerrainType.RUINS],
	},
	BuildingType.HOTEL: {
		"any_of": [TerrainType.MOUNTAIN, TerrainType.RUINS],
	},
	BuildingType.WAREHOUSE: {
		"any_of": [TerrainType.WATER],
	},
}

## Building pairs that must not touch (Chebyshev adjacency) — pollution, noise, safety.
const HAZARD_PAIRS: Array[Dictionary] = [
	{
		"a": BuildingType.FACTORY,
		"b": BuildingType.RESIDENTIAL,
		"name": "Toxic Neighbors",
		"desc": "Factory next to homes",
	},
	{
		"a": BuildingType.FACTORY,
		"b": BuildingType.SCHOOL,
		"name": "School Smog Risk",
		"desc": "Factory next to school",
	},
	{
		"a": BuildingType.FACTORY,
		"b": BuildingType.HOSPITAL,
		"name": "Clinic Contamination",
		"desc": "Factory next to hospital",
	},
	{
		"a": BuildingType.FACTORY,
		"b": BuildingType.PARK,
		"name": "Polluted Greens",
		"desc": "Factory next to park",
	},
	{
		"a": BuildingType.FACTORY,
		"b": BuildingType.FARM,
		"name": "Crop Contamination",
		"desc": "Factory next to farm",
	},
	{
		"a": BuildingType.WAREHOUSE,
		"b": BuildingType.RESIDENTIAL,
		"name": "Truck Route Hazard",
		"desc": "Warehouse next to homes",
	},
	{
		"a": BuildingType.WAREHOUSE,
		"b": BuildingType.SCHOOL,
		"name": "Loading Zone Risk",
		"desc": "Warehouse next to school",
	},
	{
		"a": BuildingType.STADIUM,
		"b": BuildingType.RESIDENTIAL,
		"name": "Crowd Noise",
		"desc": "Stadium next to homes",
	},
	{
		"a": BuildingType.STADIUM,
		"b": BuildingType.HOSPITAL,
		"name": "Emergency Chokepoint",
		"desc": "Stadium next to hospital",
	},
	{
		"a": BuildingType.HARBOR,
		"b": BuildingType.SCHOOL,
		"name": "Dockside Danger",
		"desc": "Harbor next to school",
	},
	{
		"a": BuildingType.HARBOR,
		"b": BuildingType.RESIDENTIAL,
		"name": "Industrial Waterfront",
		"desc": "Harbor next to homes",
	},
]

## Shared brush rotation (R toggles while painting / hovering).
static var active_brush_rotated := false

const OVERLAP_RECIPES: Array[Dictionary] = [
	# Existing
	{
		"id": "park_park",
		"name": "Forest",
		"desc": "Two separate Parks",
		"color": Color("1f6b35"),
		"requires": [{"type": BuildingType.PARK, "min": 2}],
	},
	{
		"id": "factory_road",
		"name": "Parking",
		"desc": "Factory + Road",
		"color": Color("4a4e58"),
		"requires": [
			{"type": BuildingType.FACTORY, "min": 1},
			{"type": BuildingType.ROAD, "min": 1},
		],
	},
	{
		"id": "office_shops",
		"name": "Commercial District",
		"desc": "Office + Shops",
		"color": Color("5a4fd0"),
		"requires": [
			{"type": BuildingType.OFFICE, "min": 1},
			{"type": BuildingType.SHOPS, "min": 1},
		],
	},
	{
		"id": "downtown_skyscraper",
		"name": "City Core",
		"desc": "Downtown + Skyscraper",
		"color": Color("6a2f8e"),
		"requires": [
			{"type": BuildingType.DOWNTOWN, "min": 1},
			{"type": BuildingType.SKYSCRAPER, "min": 1},
		],
	},
	# Residential edges
	{
		"id": "residential_park",
		"name": "Playground",
		"desc": "Residential + Park",
		"color": Color("7ad45a"),
		"requires": [
			{"type": BuildingType.RESIDENTIAL, "min": 1},
			{"type": BuildingType.PARK, "min": 1},
		],
	},
	{
		"id": "residential_shops",
		"name": "Corner Store Strip",
		"desc": "Residential + Shops",
		"color": Color("d88848"),
		"requires": [
			{"type": BuildingType.RESIDENTIAL, "min": 1},
			{"type": BuildingType.SHOPS, "min": 1},
		],
	},
	{
		"id": "residential_school",
		"name": "School Walkways",
		"desc": "Residential + School",
		"color": Color("5cb8c0"),
		"requires": [
			{"type": BuildingType.RESIDENTIAL, "min": 1},
			{"type": BuildingType.SCHOOL, "min": 1},
		],
	},
	{
		"id": "residential_factory",
		"name": "Industrial Buffer",
		"desc": "Residential + Factory",
		"color": Color("5c5850"),
		"requires": [
			{"type": BuildingType.RESIDENTIAL, "min": 1},
			{"type": BuildingType.FACTORY, "min": 1},
		],
	},
	{
		"id": "residential_downtown",
		"name": "Townhouses",
		"desc": "Residential + Downtown",
		"color": Color("c06050"),
		"requires": [
			{"type": BuildingType.RESIDENTIAL, "min": 1},
			{"type": BuildingType.DOWNTOWN, "min": 1},
		],
	},
	# Farm edges
	{
		"id": "farm_residential",
		"name": "Market Gardens",
		"desc": "Farm + Residential",
		"color": Color("6aaa28"),
		"requires": [
			{"type": BuildingType.FARM, "min": 1},
			{"type": BuildingType.RESIDENTIAL, "min": 1},
		],
	},
	{
		"id": "farm_market",
		"name": "Produce Yards",
		"desc": "Farm + Market",
		"color": Color("c4a020"),
		"requires": [
			{"type": BuildingType.FARM, "min": 1},
			{"type": BuildingType.MARKET, "min": 1},
		],
	},
	# Harbor / waterfront
	{
		"id": "harbor_shops",
		"name": "Boardwalk",
		"desc": "Harbor + Shops",
		"color": Color("2f8fb0"),
		"requires": [
			{"type": BuildingType.HARBOR, "min": 1},
			{"type": BuildingType.SHOPS, "min": 1},
		],
	},
	{
		"id": "harbor_warehouse",
		"name": "Docks",
		"desc": "Harbor + Warehouse",
		"color": Color("3a5568"),
		"requires": [
			{"type": BuildingType.HARBOR, "min": 1},
			{"type": BuildingType.WAREHOUSE, "min": 1},
		],
	},
	{
		"id": "harbor_park",
		"name": "Waterfront Promenade",
		"desc": "Harbor + Park",
		"color": Color("1f8a7a"),
		"requires": [
			{"type": BuildingType.HARBOR, "min": 1},
			{"type": BuildingType.PARK, "min": 1},
		],
	},
	# Stadium / events
	{
		"id": "stadium_road",
		"name": "Event Parking",
		"color": Color("6a4858"),
		"desc": "Stadium + Road",
		"requires": [
			{"type": BuildingType.STADIUM, "min": 1},
			{"type": BuildingType.ROAD, "min": 1},
		],
	},
	{
		"id": "stadium_shops",
		"name": "Entertainment Row",
		"desc": "Stadium + Shops",
		"color": Color("e04078"),
		"requires": [
			{"type": BuildingType.STADIUM, "min": 1},
			{"type": BuildingType.SHOPS, "min": 1},
		],
	},
	# Civic / services
	{
		"id": "hospital_road",
		"name": "Emergency Access",
		"desc": "Hospital + Road",
		"color": Color("a8b8c8"),
		"requires": [
			{"type": BuildingType.HOSPITAL, "min": 1},
			{"type": BuildingType.ROAD, "min": 1},
		],
	},
	{
		"id": "school_park",
		"name": "Sports Fields",
		"desc": "School + Park",
		"color": Color("3a9a58"),
		"requires": [
			{"type": BuildingType.SCHOOL, "min": 1},
			{"type": BuildingType.PARK, "min": 1},
		],
	},
	{
		"id": "warehouse_road",
		"name": "Loading Bays",
		"desc": "Warehouse + Road",
		"color": Color("7a6048"),
		"requires": [
			{"type": BuildingType.WAREHOUSE, "min": 1},
			{"type": BuildingType.ROAD, "min": 1},
		],
	},
	{
		"id": "hotel_downtown",
		"name": "Tourist Strip",
		"desc": "Hotel + Downtown",
		"color": Color("9a4aaa"),
		"requires": [
			{"type": BuildingType.HOTEL, "min": 1},
			{"type": BuildingType.DOWNTOWN, "min": 1},
		],
	},
	{
		"id": "office_park",
		"name": "Civic Plaza",
		"desc": "Office + Park",
		"color": Color("3aaa9a"),
		"requires": [
			{"type": BuildingType.OFFICE, "min": 1},
			{"type": BuildingType.PARK, "min": 1},
		],
	},
	{
		"id": "market_road",
		"name": "Street Market",
		"desc": "Market + Road",
		"color": Color("e07020"),
		"requires": [
			{"type": BuildingType.MARKET, "min": 1},
			{"type": BuildingType.ROAD, "min": 1},
		],
	},
	{
		"id": "downtown_shops",
		"name": "Pedestrian Mall",
		"desc": "Downtown + Shops",
		"color": Color("c05038"),
		"requires": [
			{"type": BuildingType.DOWNTOWN, "min": 1},
			{"type": BuildingType.SHOPS, "min": 1},
		],
	},
]

signal history_changed(can_undo: bool, can_redo: bool)
signal town_chatter(message: String)
signal day_phase_changed(phase_name: String)

const DAY_LENGTH_SEC := 12.0 * 60.0 ## Full day/night cycle length.

enum DayPhase {
	NIGHT,
	DAWN,
	DAY,
	DUSK,
}

var inner_cells: Array = []
var building_ids: Array = []
var land_mask: Array = []
var terrain_cells: Array = []
var elevation_cells: Array = [] ## float 0..1 per cell
var building_radii: Dictionary = {}
var outer_influences: Array = []
var terrain_influences: Array = []
var next_building_id := 1
var shape_seed: int = 0
var hovered_cell: Vector2i = Vector2i(-1, -1)
var ghost_type: BuildingType = BuildingType.NONE
var ghost_rotated := false
var ghost_valid := false
var is_drag_erasing := false
var is_brush_painting := false
var erase_stroke_started := false
var paint_stroke_started := false
var last_erase_cell: Vector2i = Vector2i(-999, -999)
var last_paint_cell: Vector2i = Vector2i(-999, -999)
var undo_stack: Array = []
var redo_stack: Array = []
var hover_info_cell: Vector2i = Vector2i(-1, -1)
var gamepad_active := false
var _tile_anim_timer := 0.0
var _tile_anim_phase := 0.0
var _tile_anim_frame := 0
var _cell_size := TILE_PX * 2.0
var _view_y_scale := VIEW_Y_SCALE
var citizen_sim: CitizenSim = CitizenSim.new()
var vehicle_sim: VehicleSim = VehicleSim.new()
var view_zoom := 1.0
var view_pan := Vector2.ZERO
## 0–3: Beat Cop camera orbit in 90° steps (0 ≈ SE, 1 ≈ SW, 2 ≈ NW, 3 ≈ NE).
var view_yaw_quarter := 0
var _is_panning := false
var _pan_last := Vector2.ZERO
## 0 = midnight, 0.25 = dawn, 0.5 = noon, 0.75 = dusk
var day_time := 0.32
var _last_day_phase: DayPhase = DayPhase.DAY
var _day_light_timer := 0.0
var door_timers: Dictionary = {} ## building_id -> seconds remaining open
var bus_stop_cells: Array[Vector2i] = []
var _cached_day_modulate := Color.WHITE
var town_world ## TownWorld3D instance (loaded at runtime to avoid class_name cycles)
var _world_viewport: SubViewport
var _world_host: SubViewportContainer
var _world_dirty := true
var _world_dirty_timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = TEXTURE_FILTER_NEAREST
	TileLibrary.ensure_ready()
	citizen_sim.setup(self)
	vehicle_sim.setup(self)
	if not citizen_sim.chatter.is_connected(_on_citizen_chatter):
		citizen_sim.chatter.connect(_on_citizen_chatter)
	if not vehicle_sim.chatter.is_connected(_on_citizen_chatter):
		vehicle_sim.chatter.connect(_on_citizen_chatter)
	_initialize_grids()
	_setup_3d_view()
	generate_board_shape()
	_update_cell_size()
	hovered_cell = _find_nearest_buildable(Vector2i(floori(GRID_WIDTH / 2.0), floori(GRID_HEIGHT / 2.0)))
	_last_day_phase = get_day_phase()
	_cached_day_modulate = day_modulate()
	_emit_history_changed()
	_mark_world_dirty()


func _setup_3d_view() -> void:
	_world_host = SubViewportContainer.new()
	_world_host.name = "WorldHost"
	_world_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world_host.stretch = true
	_world_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world_host.texture_filter = TEXTURE_FILTER_NEAREST
	add_child(_world_host)
	_world_viewport = SubViewport.new()
	_world_viewport.name = "WorldViewport"
	_world_viewport.own_world_3d = true
	_world_viewport.transparent_bg = false
	_world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_world_viewport.msaa_3d = Viewport.MSAA_2X
	_world_host.add_child(_world_viewport)
	town_world = (load("res://TownWorld3D.gd") as GDScript).new()
	town_world.name = "TownWorld"
	_world_viewport.add_child(town_world)
	town_world.setup(self)


func _mark_world_dirty() -> void:
	_world_dirty = true
	_world_dirty_timer = 0.0


func _flush_world_rebuild() -> void:
	if town_world == null:
		return
	if _world_dirty:
		town_world.rebuild()
		_world_dirty = false
		_world_dirty_timer = 0.0


func _process(delta: float) -> void:
	_tile_anim_phase += delta * TileLibrary.ANIM_FPS
	_tile_anim_frame = int(_tile_anim_phase) % ANIM_FRAME_MODULO
	_tile_anim_timer += delta

	day_time = fposmod(day_time + delta / DAY_LENGTH_SEC, 1.0)
	var phase := get_day_phase()
	if phase != _last_day_phase:
		_last_day_phase = phase
		day_phase_changed.emit(day_phase_name(phase))

	_day_light_timer += delta
	if _day_light_timer >= 0.35:
		_day_light_timer = 0.0
		_cached_day_modulate = day_modulate()

	if citizen_sim != null:
		citizen_sim.tick(delta)
	if vehicle_sim != null:
		vehicle_sim.tick(delta)
	_tick_doors(delta)

	if town_world != null:
		if _world_dirty:
			_world_dirty_timer += delta
			var can_rebuild := (not is_brush_painting and not is_drag_erasing) or _world_dirty_timer >= 0.07
			if can_rebuild:
				town_world.rebuild()
				_world_dirty = false
				_world_dirty_timer = 0.0
		town_world.sync_frame()


func _on_citizen_chatter(message: String) -> void:
	town_chatter.emit(message)


func get_day_phase() -> DayPhase:
	# Midnight→dawn→noon→dusk→midnight
	if day_time < 0.22 or day_time >= 0.88:
		return DayPhase.NIGHT
	if day_time < 0.30:
		return DayPhase.DAWN
	if day_time < 0.70:
		return DayPhase.DAY
	return DayPhase.DUSK


func day_phase_name(phase: DayPhase = DayPhase.DAY) -> String:
	var p := phase
	# Default arg can't easily mean "current"; callers pass get_day_phase() usually.
	match p:
		DayPhase.NIGHT:
			return "Night"
		DayPhase.DAWN:
			return "Dawn"
		DayPhase.DUSK:
			return "Dusk"
		_:
			return "Day"


func is_night() -> bool:
	return get_day_phase() == DayPhase.NIGHT


func is_daytime() -> bool:
	var phase := get_day_phase()
	return phase == DayPhase.DAY or phase == DayPhase.DAWN


func day_clock_label() -> String:
	# Map 0..1 onto a 24h clock starting at midnight.
	var minutes_total := int(day_time * 24.0 * 60.0)
	var hours := int(minutes_total / 60.0) % 24
	var mins := minutes_total % 60
	return "%02d:%02d" % [hours, mins]


func day_modulate() -> Color:
	var t := day_time
	if t < 0.22: # deep night → late night
		return Color(0.42, 0.48, 0.78).lerp(Color(0.38, 0.44, 0.72), t / 0.22)
	if t < 0.30: # dawn
		var u := (t - 0.22) / 0.08
		return Color(0.55, 0.5, 0.75).lerp(Color(1.0, 0.82, 0.7), u)
	if t < 0.48: # morning
		var u := (t - 0.30) / 0.18
		return Color(1.0, 0.9, 0.8).lerp(Color(1, 1, 1), u)
	if t < 0.62: # midday
		return Color(1, 1, 1)
	if t < 0.70: # afternoon warm
		var u := (t - 0.62) / 0.08
		return Color(1, 1, 1).lerp(Color(1.0, 0.92, 0.82), u)
	if t < 0.80: # dusk
		var u := (t - 0.70) / 0.10
		return Color(1.0, 0.85, 0.68).lerp(Color(0.85, 0.55, 0.55), u)
	# evening → night
	var u2 := (t - 0.80) / 0.20
	return Color(0.75, 0.5, 0.58).lerp(Color(0.42, 0.48, 0.78), u2)


func day_overlay_alpha() -> float:
	match get_day_phase():
		DayPhase.NIGHT:
			return 0.34
		DayPhase.DAWN:
			return 0.08
		DayPhase.DUSK:
			return 0.16
		_:
			return 0.0


func _update_cell_size() -> void:
	if size.x < 1.0 or size.y < 1.0:
		_cell_size = TILE_PX * 2.0
		_view_y_scale = VIEW_Y_SCALE
		return
	# Prefer filling width; relax foreshortening so leftover vertical space is used.
	var width_fit := size.x / float(GRID_WIDTH)
	var height_fit := size.y / (float(GRID_HEIGHT) * VIEW_Y_SCALE)
	if width_fit <= height_fit:
		_cell_size = maxf(TILE_PX, floorf(width_fit))
		var filled_y := size.y / maxf(1.0, float(GRID_HEIGHT) * _cell_size)
		_view_y_scale = clampf(filled_y, VIEW_Y_SCALE, 1.0)
	else:
		_cell_size = maxf(TILE_PX, floorf(height_fit))
		_view_y_scale = VIEW_Y_SCALE


func _row_height() -> float:
	return _cell_size * _view_y_scale


func _cell_screen_pos(x: int, y: int, origin: Vector2) -> Vector2:
	return origin + Vector2(float(x) * _cell_size, float(y) * _row_height())


func _ground_rect(x: int, y: int, origin: Vector2) -> Rect2:
	return Rect2(_cell_screen_pos(x, y, origin), Vector2(_cell_size, _row_height()))


func _ground_rect_f(fx: float, fy: float, origin: Vector2) -> Rect2:
	return Rect2(
		origin + Vector2(fx * _cell_size, fy * _row_height()),
		Vector2(_cell_size, _row_height())
	)


func _elevated_rect(x: int, y: int, height_factor: float, origin: Vector2) -> Rect2:
	var ground := _ground_rect(x, y, origin)
	var height := _cell_size * height_factor
	# Edge-to-edge so neighboring facades abut (no grass gutters between lots).
	return Rect2(
		Vector2(ground.position.x, ground.position.y + ground.size.y - height),
		Vector2(ground.size.x, height)
	)


func _building_height_factor(building_type: BuildingType) -> float:
	# Rough city-block scale in world units (CELL ≈ one lot tile).
	match building_type:
		BuildingType.SKYSCRAPER:
			return 7.2
		BuildingType.DOWNTOWN:
			return 4.8
		BuildingType.HOTEL:
			return 4.2
		BuildingType.OFFICE:
			return 3.6
		BuildingType.HOSPITAL:
			return 2.8
		BuildingType.SCHOOL:
			return 2.4
		BuildingType.FACTORY:
			return 2.6
		BuildingType.WAREHOUSE:
			return 2.2
		BuildingType.STADIUM:
			return 2.5
		BuildingType.SHOPS, BuildingType.MARKET:
			return 1.6
		BuildingType.RESIDENTIAL:
			return 1.8
		BuildingType.HARBOR:
			return 1.9
		BuildingType.PARK, BuildingType.FARM:
			return 0.8
		_:
			return ELEVATION_HEIGHT


func _building_bounds(building_id: int) -> Rect2i:
	var min_x := GRID_WIDTH
	var min_y := GRID_HEIGHT
	var max_x := -1
	var max_y := -1
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if building_ids[y][x] != building_id:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _is_building_frontage(cell: Vector2i, building_id: int) -> bool:
	# Southern edge of the lot (or any cell with no same-building neighbor south).
	var below := cell + Vector2i(0, 1)
	if not _is_in_bounds(below):
		return true
	return building_ids[below.y][below.x] != building_id


func building_door_cell(building_id: int) -> Vector2i:
	var bounds := _building_bounds(building_id)
	if bounds.size.x <= 0:
		return Vector2i(-1, -1)
	return Vector2i(
		bounds.position.x + int(bounds.size.x / 2.0),
		bounds.position.y + bounds.size.y - 1
	)


func building_approach_cell(building_id: int) -> Vector2i:
	var door := building_door_cell(building_id)
	if door.x < 0:
		return Vector2i(-1, -1)
	for d: Vector2i in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		var cand: Vector2i = door + d
		if not _is_in_bounds(cand):
			continue
		if terrain_cells[cand.y][cand.x] != TerrainType.OPEN:
			continue
		var inner: BuildingType = inner_cells[cand.y][cand.x]
		if inner == BuildingType.NONE or inner == BuildingType.ROAD:
			return cand
	return Vector2i(-1, -1)


func open_door(building_id: int, duration: float = 1.1) -> void:
	if building_id <= 0:
		return
	door_timers[building_id] = maxf(float(door_timers.get(building_id, 0.0)), duration)


func is_door_open(building_id: int) -> bool:
	return float(door_timers.get(building_id, 0.0)) > 0.0


func _tick_doors(delta: float) -> void:
	if door_timers.is_empty():
		return
	var dead: Array = []
	for bid in door_timers.keys():
		door_timers[bid] = float(door_timers[bid]) - delta
		if float(door_timers[bid]) <= 0.0:
			dead.append(bid)
	for bid in dead:
		door_timers.erase(bid)


func clear_bus_stops() -> void:
	bus_stop_cells.clear()


func register_bus_stop(cell: Vector2i) -> void:
	if not bus_stop_cells.has(cell):
		bus_stop_cells.append(cell)


func nearest_bus_stop_road(from: Vector2i) -> Vector2i:
	# Find a road cell adjacent to a bus stop, closest to `from`.
	var best := Vector2i(-1, -1)
	var best_d := 999999
	for stop in bus_stop_cells:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var road: Vector2i = stop + d
			if not _is_in_bounds(road):
				continue
			if inner_cells[road.y][road.x] != BuildingType.ROAD:
				continue
			var dist := absi(road.x - from.x) + absi(road.y - from.y)
			if dist < best_d:
				best_d = dist
				best = road
	return best


func _actor_rect(ground: Rect2, width_frac: float, height_frac: float) -> Rect2:
	var sprite_w := _cell_size * width_frac
	var sprite_h := _cell_size * height_frac
	return Rect2(
		Vector2(
			ground.position.x + (ground.size.x - sprite_w) * 0.5,
			ground.position.y + ground.size.y - sprite_h
		),
		Vector2(sprite_w, sprite_h)
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_cell_size()
	elif what == NOTIFICATION_DRAG_END:
		pass


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		gamepad_active = false

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, ZOOM_STEP)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.0 / ZOOM_STEP)
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = mb.pressed
			_pan_last = mb.position
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var cell := _cell_from_mouse(mb.position)
			if not gamepad_active and _is_in_bounds(cell):
				hovered_cell = cell
			if mb.pressed:
				is_brush_painting = true
				paint_stroke_started = false
				last_paint_cell = Vector2i(-999, -999)
				_try_paint(cell)
			else:
				is_brush_painting = false
				paint_stroke_started = false
			_refresh_ghost_at_hover()
			queue_redraw()
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			var cell := _cell_from_mouse(mb.position)
			if mb.pressed:
				is_drag_erasing = true
				erase_stroke_started = false
				last_erase_cell = Vector2i(-999, -999)
				if _is_buildable(cell):
					_try_erase(cell)
			else:
				is_drag_erasing = false
				erase_stroke_started = false
			queue_redraw()
			accept_event()
			return

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _is_panning and view_zoom > 1.001:
			var delta := mm.position - _pan_last
			_pan_last = mm.position
			view_pan += delta / view_zoom
			_clamp_pan()
			queue_redraw()
			accept_event()
			return
		if not gamepad_active:
			var hover := _cell_from_mouse(mm.position)
			if _is_in_bounds(hover):
				hovered_cell = hover
				_refresh_ghost_at_hover()
		_update_hover_tooltip(mm.position)
		if is_brush_painting:
			_try_paint(_cell_from_mouse(mm.position))
		if is_drag_erasing:
			var cell := _cell_from_mouse(mm.position)
			if _is_buildable(cell):
				_try_erase(cell)
		queue_redraw()


func _zoom_at(screen_pos: Vector2, factor: float) -> void:
	var world_before := _screen_to_world(screen_pos)
	view_zoom = clampf(view_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(view_zoom, ZOOM_MIN):
		view_pan = Vector2.ZERO
	else:
		# Keep the world point under the cursor stable.
		var center := size * 0.5
		view_pan = (screen_pos - center) / view_zoom + center - world_before
		_clamp_pan()
	queue_redraw()


func zoom_by(factor: float) -> void:
	_zoom_at(size * 0.5, factor)


func pan_by(delta_screen: Vector2) -> void:
	if view_zoom <= 1.001:
		return
	view_pan += delta_screen / view_zoom
	_clamp_pan()
	queue_redraw()


func rotate_view_yaw(steps: int = 1) -> void:
	view_yaw_quarter = posmod(view_yaw_quarter + steps, 4)
	_mark_world_dirty()


func view_yaw_radians() -> float:
	return deg_to_rad(float(view_yaw_quarter) * 90.0)


func _clamp_pan() -> void:
	if view_zoom <= 1.001:
		view_pan = Vector2.ZERO
		return
	var world_size := Vector2(GRID_WIDTH * _cell_size, GRID_HEIGHT * _row_height())
	var max_pan := world_size * 0.22 * (view_zoom - 1.0)
	view_pan = view_pan.clamp(-max_pan, max_pan)


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var center := size * 0.5
	return (screen_pos - center) / view_zoom - view_pan + center


func _world_to_screen(world_pos: Vector2) -> Vector2:
	var center := size * 0.5
	return (world_pos + view_pan - center) * view_zoom + center


func _world_to_screen_rect(world_rect: Rect2) -> Rect2:
	var tl := _world_to_screen(world_rect.position)
	var br := _world_to_screen(world_rect.position + world_rect.size)
	return Rect2(tl, br - tl)


func _focus_cell() -> Vector2i:
	if _is_in_bounds(hovered_cell):
		return hovered_cell
	var origin := _grid_origin()
	var center_world := _screen_to_world(size * 0.5)
	var local := center_world - origin
	return Vector2i(
		clampi(floori(local.x / _cell_size), 0, GRID_WIDTH - 1),
		clampi(floori(local.y / _row_height()), 0, GRID_HEIGHT - 1)
	)


func _dof_strength(cell: Vector2i) -> float:
	if view_zoom < DOF_ZOOM_START:
		return 0.0
	var focus := _focus_cell()
	var dist := float(maxi(absi(cell.x - focus.x), absi(cell.y - focus.y)))
	# Tighter focus as zoom increases — distant tiles soften more.
	var zoom_t := clampf((view_zoom - DOF_ZOOM_START) / (ZOOM_MAX - DOF_ZOOM_START), 0.0, 1.0)
	var start := lerpf(3.0, 1.5, zoom_t)
	var range_cells := lerpf(12.0, 5.0, zoom_t)
	return clampf((dist - start) / range_cells, 0.0, 1.0)


func _refresh_ghost_at_hover() -> void:
	if ghost_type == BuildingType.NONE or not _is_in_bounds(hovered_cell):
		ghost_valid = false
		return
	ghost_rotated = active_brush_rotated
	ghost_valid = _is_footprint_valid(hovered_cell, ghost_type, ghost_rotated)


func _can_drop_data(_at_position: Vector2, _data: Variant) -> bool:
	return false


func _drop_data(_at_position: Vector2, _data: Variant) -> void:
	pass


func _draw() -> void:
	# Rendering is handled by TownWorld3D inside the SubViewport.
	pass


func _cell_adjacent_to_road(cell: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _is_road_cell(cell + d):
			return true
	return false



func _water_mask(cell: Vector2i) -> int:
	var mask := 0
	if _is_water_like(cell + Vector2i(0, -1)):
		mask |= TileLibrary.MASK_N
	if _is_water_like(cell + Vector2i(1, 0)):
		mask |= TileLibrary.MASK_E
	if _is_water_like(cell + Vector2i(0, 1)):
		mask |= TileLibrary.MASK_S
	if _is_water_like(cell + Vector2i(-1, 0)):
		mask |= TileLibrary.MASK_W
	return mask


func _terrain_mask(cell: Vector2i, terrain: TerrainType) -> int:
	var mask := 0
	if _same_terrain(cell + Vector2i(0, -1), terrain):
		mask |= TileLibrary.MASK_N
	if _same_terrain(cell + Vector2i(1, 0), terrain):
		mask |= TileLibrary.MASK_E
	if _same_terrain(cell + Vector2i(0, 1), terrain):
		mask |= TileLibrary.MASK_S
	if _same_terrain(cell + Vector2i(-1, 0), terrain):
		mask |= TileLibrary.MASK_W
	return mask


func _road_mask(cell: Vector2i) -> int:
	var mask := 0
	if _is_road_cell(cell + Vector2i(0, -1)):
		mask |= TileLibrary.MASK_N
	if _is_road_cell(cell + Vector2i(1, 0)):
		mask |= TileLibrary.MASK_E
	if _is_road_cell(cell + Vector2i(0, 1)):
		mask |= TileLibrary.MASK_S
	if _is_road_cell(cell + Vector2i(-1, 0)):
		mask |= TileLibrary.MASK_W
	return mask


## Road topology for paint + traffic.
## style: 0 one-way, 1 two-way, 2 crossing, 3 roundabout, 4 corner/stub
## flow: travel dir 0=S 1=W 2=E 3=N (-1 if free)
## lane_side: for two-way, 0=twin east/south, 1=twin west/north, -1=n/a
func road_info(cell: Vector2i) -> Dictionary:
	if not _is_road_cell(cell):
		return {"style": -1, "flow": -1, "mask": 0, "dual": false, "lane_side": -1}
	var mask := _road_mask(cell)
	var has_n := (mask & TileLibrary.MASK_N) != 0
	var has_e := (mask & TileLibrary.MASK_E) != 0
	var has_s := (mask & TileLibrary.MASK_S) != 0
	var has_w := (mask & TileLibrary.MASK_W) != 0
	var arms := int(has_n) + int(has_e) + int(has_s) + int(has_w)
	var ns := has_n or has_s
	var ew := has_e or has_w

	if _is_roundabout_cell(cell):
		return {
			"style": 3,
			"flow": _roundabout_flow(cell),
			"mask": mask,
			"dual": false,
			"lane_side": -1,
		}

	# Parallel twin first — 2-wide corridors have 3 neighbors and must not become crossings.
	var ns_twin := _parallel_twin_side(cell, true) # 0=east, 1=west, -1=none
	var ew_twin := _parallel_twin_side(cell, false) # 0=south, 1=north, -1=none
	if ns_twin >= 0 and ew_twin < 0:
		# NS two-way, unless a real perpendicular road joins (not the twin).
		if _has_foreign_cross(cell, true, ns_twin):
			return {"style": 2, "flow": -1, "mask": mask, "dual": false, "lane_side": -1}
		var flow_ns := 0 if ns_twin == 0 else 3
		return {"style": 1, "flow": flow_ns, "mask": mask, "dual": true, "lane_side": ns_twin}
	if ew_twin >= 0 and ns_twin < 0:
		if _has_foreign_cross(cell, false, ew_twin):
			return {"style": 2, "flow": -1, "mask": mask, "dual": false, "lane_side": -1}
		var flow_ew := 2 if ew_twin == 0 else 1
		return {"style": 1, "flow": flow_ew, "mask": mask, "dual": true, "lane_side": ew_twin}

	if arms >= 3:
		return {"style": 2, "flow": -1, "mask": mask, "dual": false, "lane_side": -1}

	if arms == 2 and ns and ew:
		return {"style": 4, "flow": -1, "mask": mask, "dual": false, "lane_side": -1}

	var north_south := ns and not ew
	var flow := _one_way_flow(has_n, has_e, has_s, has_w, north_south)
	return {"style": 0, "flow": flow, "mask": mask, "dual": false, "lane_side": -1}


func _one_way_flow(has_n: bool, has_e: bool, has_s: bool, has_w: bool, north_south: bool) -> int:
	var arms := int(has_n) + int(has_e) + int(has_s) + int(has_w)
	if arms <= 1:
		if has_n:
			return 3
		if has_s:
			return 0
		if has_e:
			return 2
		if has_w:
			return 1
		return 0
	if north_south:
		return 0
	return 2


func _parallel_twin_side(cell: Vector2i, north_south: bool) -> int:
	# Side-adjacent road that runs the same axis → the other half of a two-way.
	var self_mask := _road_mask(cell)
	if north_south:
		var self_ns := ((self_mask & TileLibrary.MASK_N) != 0) or ((self_mask & TileLibrary.MASK_S) != 0)
		if _is_axis_twin_neighbor(cell + Vector2i(1, 0), true, self_ns):
			return 0
		if _is_axis_twin_neighbor(cell + Vector2i(-1, 0), true, self_ns):
			return 1
	else:
		var self_ew := ((self_mask & TileLibrary.MASK_E) != 0) or ((self_mask & TileLibrary.MASK_W) != 0)
		if _is_axis_twin_neighbor(cell + Vector2i(0, 1), false, self_ew):
			return 0
		if _is_axis_twin_neighbor(cell + Vector2i(0, -1), false, self_ew):
			return 1
	return -1


func _is_axis_twin_neighbor(cell: Vector2i, north_south: bool, self_has_axis: bool) -> bool:
	if not _is_road_cell(cell):
		return false
	var nm := _road_mask(cell)
	var t_ns := int((nm & TileLibrary.MASK_N) != 0) + int((nm & TileLibrary.MASK_S) != 0)
	var t_ew := int((nm & TileLibrary.MASK_E) != 0) + int((nm & TileLibrary.MASK_W) != 0)
	if north_south:
		if t_ns >= 1:
			return true
		# Perpendicular spur into an NS road is not a twin.
		if self_has_axis and t_ns == 0 and t_ew >= 1:
			return false
		# Two-wide seed: neither cell has length yet.
		return not self_has_axis and t_ns == 0 and t_ew <= 1
	if t_ew >= 1:
		return true
	if self_has_axis and t_ew == 0 and t_ns >= 1:
		return false
	return not self_has_axis and t_ew == 0 and t_ns <= 1


func _is_same_axis_corridor(cell: Vector2i, north_south: bool) -> bool:
	if not _is_road_cell(cell):
		return false
	var nm := _road_mask(cell)
	var t_ns := int((nm & TileLibrary.MASK_N) != 0) + int((nm & TileLibrary.MASK_S) != 0)
	var t_ew := int((nm & TileLibrary.MASK_E) != 0) + int((nm & TileLibrary.MASK_W) != 0)
	if north_south:
		return t_ns >= 1
	return t_ew >= 1


func _has_foreign_cross(cell: Vector2i, north_south_dual: bool, twin_side: int) -> bool:
	# True when a perpendicular road joins this dual cell (not just the twin).
	if north_south_dual:
		# Twin is east (0) or west (1). A foreign EW link is the opposite side, or
		# an EW-running neighbor on the twin side beyond a junction — use non-twin E/W.
		if twin_side == 0 and _is_road_cell(cell + Vector2i(-1, 0)):
			if not _is_same_axis_corridor(cell + Vector2i(-1, 0), true):
				return true
		if twin_side == 1 and _is_road_cell(cell + Vector2i(1, 0)):
			if not _is_same_axis_corridor(cell + Vector2i(1, 0), true):
				return true
		# Also: north/south neighbor that is predominantly EW (incoming cross street).
		for d: Vector2i in [Vector2i(0, -1), Vector2i(0, 1)]:
			var n: Vector2i = cell + d
			if not _is_road_cell(n):
				continue
			if _is_same_axis_corridor(n, false) and not _is_same_axis_corridor(n, true):
				return true
		return false
	# EW dual — twin south (0) or north (1).
	if twin_side == 0 and _is_road_cell(cell + Vector2i(0, -1)):
		if not _is_same_axis_corridor(cell + Vector2i(0, -1), false):
			return true
	if twin_side == 1 and _is_road_cell(cell + Vector2i(0, 1)):
		if not _is_same_axis_corridor(cell + Vector2i(0, 1), false):
			return true
	for d2: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0)]:
		var n2: Vector2i = cell + d2
		if not _is_road_cell(n2):
			continue
		if _is_same_axis_corridor(n2, true) and not _is_same_axis_corridor(n2, false):
			return true
	return false


func _is_roundabout_cell(cell: Vector2i) -> bool:
	if not _is_road_cell(cell):
		return false
	var ring := _road_component_cells(cell, 20)
	return _component_is_roundabout(ring)


func _component_is_roundabout(ring: Array[Vector2i]) -> bool:
	if ring.size() < 4 or ring.size() > 16:
		return false
	var min_x := 999
	var min_y := 999
	var max_x := -999
	var max_y := -999
	var ring_cells: Dictionary = {}
	for c in ring:
		ring_cells[c] = true
		min_x = mini(min_x, c.x)
		min_y = mini(min_y, c.y)
		max_x = maxi(max_x, c.x)
		max_y = maxi(max_y, c.y)
	if max_x - min_x < 2 or max_y - min_y < 2:
		return false
	# Prefer ring-like: most cells degree 2; allow a couple of feeder T-junctions.
	var corners := 0
	var high_degree := 0
	for c in ring:
		var m := _road_mask(c)
		var arms := 0
		for bit in [TileLibrary.MASK_N, TileLibrary.MASK_E, TileLibrary.MASK_S, TileLibrary.MASK_W]:
			if (m & bit) != 0:
				arms += 1
		if arms >= 3:
			high_degree += 1
		var c_ns := ((m & TileLibrary.MASK_N) != 0) or ((m & TileLibrary.MASK_S) != 0)
		var c_ew := ((m & TileLibrary.MASK_E) != 0) or ((m & TileLibrary.MASK_W) != 0)
		if arms == 2 and c_ns and c_ew:
			corners += 1
	if corners < 3 or high_degree > 2:
		return false
	for y in range(min_y + 1, max_y):
		for x in range(min_x + 1, max_x):
			if not ring_cells.has(Vector2i(x, y)):
				return true
	return false


func _road_component_cells(start: Vector2i, limit: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen: Dictionary = {}
	var stack: Array[Vector2i] = [start]
	seen[start] = true
	while not stack.is_empty() and out.size() < limit:
		var c: Vector2i = stack.pop_back()
		out.append(c)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or not _is_road_cell(n):
				continue
			seen[n] = true
			stack.append(n)
	# If we hit the limit, component is likely a big network — not a roundabout.
	if out.size() >= limit:
		return []
	return out


func _roundabout_flow(cell: Vector2i) -> int:
	# Counter-clockwise around the island (keep-right / US-style).
	var ring := _road_component_cells(cell, 20)
	if ring.is_empty():
		return 2
	var cx := 0.0
	var cy := 0.0
	for c in ring:
		cx += float(c.x)
		cy += float(c.y)
	cx /= float(ring.size())
	cy /= float(ring.size())
	var rx := float(cell.x) - cx
	var rz := float(cell.y) - cy
	# CCW tangent in (x, z=+south): (rz, rx) → west at north rim.
	var tx := rz
	var tz := rx
	if absf(tx) >= absf(tz):
		return 2 if tx > 0.0 else 1
	return 0 if tz > 0.0 else 3


func road_allows_step(from: Vector2i, to: Vector2i) -> bool:
	if not _is_road_cell(to):
		return false
	var delta := to - from
	if absi(delta.x) + absi(delta.y) != 1:
		return false
	var info: Dictionary = road_info(from)
	var style: int = int(info.get("style", -1))
	var flow: int = int(info.get("flow", -1))
	# Crossings / corners: free.
	if style == 2 or style == 4 or flow < 0:
		return true
	# Two-way corridor: either direction along the road axis.
	if style == 1:
		if flow == 0 or flow == 3:
			return delta.x == 0
		return delta.y == 0
	# One-way / roundabout: only with traffic.
	match flow:
		0:
			return delta == Vector2i(0, 1)
		1:
			return delta == Vector2i(-1, 0)
		2:
			return delta == Vector2i(1, 0)
		3:
			return delta == Vector2i(0, -1)
	return true


func _same_terrain(cell: Vector2i, terrain: TerrainType) -> bool:
	if not _is_in_bounds(cell) or not land_mask[cell.y][cell.x]:
		return false
	return terrain_cells[cell.y][cell.x] == terrain


func _is_road_cell(cell: Vector2i) -> bool:
	if not _is_in_bounds(cell) or not land_mask[cell.y][cell.x]:
		return false
	return inner_cells[cell.y][cell.x] == BuildingType.ROAD


func _is_water_like(cell: Vector2i) -> bool:
	if not _is_in_bounds(cell):
		return true # off-map ocean / void reads as water
	if not land_mask[cell.y][cell.x]:
		return true
	return terrain_cells[cell.y][cell.x] == TerrainType.WATER


func _water_needs_shore(cell: Vector2i, neighbor_delta: Vector2i) -> bool:
	return not _is_water_like(cell + neighbor_delta)


func clear_grid() -> void:
	if _grid_is_empty():
		return
	_push_undo_snapshot()
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			inner_cells[y][x] = BuildingType.NONE
			building_ids[y][x] = 0
	building_radii.clear()
	_recalculate_outer_influences()
	if citizen_sim != null:
		citizen_sim.clear()
	if vehicle_sim != null:
		vehicle_sim.clear()
		town_chatter.emit("The streets emptied.")
	if vehicle_sim != null:
		vehicle_sim.clear()
	_mark_world_dirty()

func generate_board_shape(p_seed: int = -1) -> void:
	shape_seed = randi() if p_seed < 0 else p_seed
	_generate_elevation_map(shape_seed)
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			inner_cells[y][x] = BuildingType.NONE
			building_ids[y][x] = 0
	building_radii.clear()
	next_building_id = 1
	undo_stack.clear()
	redo_stack.clear()
	_recalculate_outer_influences()
	_recalculate_terrain_influences()
	if citizen_sim != null:
		citizen_sim.clear()
	if vehicle_sim != null:
		vehicle_sim.clear()
	hovered_cell = _find_nearest_buildable(Vector2i(floori(GRID_WIDTH / 2.0), floori(GRID_HEIGHT / 2.0)))
	if ghost_type != BuildingType.NONE:
		ghost_valid = _is_footprint_valid(hovered_cell, ghost_type, ghost_rotated)
	_emit_history_changed()
	_mark_world_dirty()


func undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(_clone_state())
	_restore_state(undo_stack.pop_back())
	_emit_history_changed()
	_mark_world_dirty()


func redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(_clone_state())
	_restore_state(redo_stack.pop_back())
	_emit_history_changed()
	_mark_world_dirty()


func can_undo() -> bool:
	return not undo_stack.is_empty()


func can_redo() -> bool:
	return not redo_stack.is_empty()


func toggle_drag_rotation() -> void:
	# Kept name for Main.gd; rotates the active brush ghost.
	rotate_gamepad_selection()


func set_gamepad_selection(building_type: BuildingType) -> void:
	ghost_type = building_type
	ghost_rotated = active_brush_rotated
	if ghost_type == BuildingType.NONE:
		ghost_valid = false
		hover_info_cell = Vector2i(-999, -999)
		return
	if not _is_in_bounds(hovered_cell):
		hovered_cell = _find_nearest_buildable(Vector2i(floori(GRID_WIDTH / 2.0), floori(GRID_HEIGHT / 2.0)))
	if not _is_footprint_valid(hovered_cell, ghost_type, ghost_rotated):
		hovered_cell = _find_nearest_valid_placement(hovered_cell, ghost_type, ghost_rotated)
	ghost_valid = _is_footprint_valid(hovered_cell, ghost_type, ghost_rotated)
	hover_info_cell = Vector2i(-999, -999)
	queue_redraw()


func rotate_gamepad_selection() -> void:
	if ghost_type == BuildingType.NONE:
		return
	var old_rotated := ghost_rotated
	ghost_rotated = not ghost_rotated
	active_brush_rotated = ghost_rotated
	if _is_in_bounds(hovered_cell):
		hovered_cell = _anchor_after_rotation(hovered_cell, ghost_type, old_rotated, ghost_rotated)
	if not _is_footprint_valid(hovered_cell, ghost_type, ghost_rotated):
		hovered_cell = _find_nearest_valid_placement(hovered_cell, ghost_type, ghost_rotated)
	ghost_valid = _is_footprint_valid(hovered_cell, ghost_type, ghost_rotated)
	hover_info_cell = Vector2i(-999, -999)
	queue_redraw()


## Keep the footprint's geometric center stable when swapping WxH <-> HxW.
func _anchor_after_rotation(
	cell: Vector2i,
	building_type: BuildingType,
	old_rotated: bool,
	new_rotated: bool
) -> Vector2i:
	var old_fp := type_footprint(building_type, old_rotated)
	var new_fp := type_footprint(building_type, new_rotated)
	if old_fp == new_fp:
		return cell
	var center := Vector2(cell) + Vector2(old_fp) * 0.5
	var anchored := Vector2i(
		roundi(center.x - float(new_fp.x) * 0.5),
		roundi(center.y - float(new_fp.y) * 0.5)
	)
	anchored.x = clampi(anchored.x, 0, maxi(0, GRID_WIDTH - new_fp.x))
	anchored.y = clampi(anchored.y, 0, maxi(0, GRID_HEIGHT - new_fp.y))
	return anchored


func move_gamepad_cursor(delta: Vector2i) -> void:
	gamepad_active = true
	var target := hovered_cell + delta
	target.x = clampi(target.x, 0, GRID_WIDTH - 1)
	target.y = clampi(target.y, 0, GRID_HEIGHT - 1)
	hovered_cell = target
	if ghost_type != BuildingType.NONE:
		ghost_valid = _is_footprint_valid(hovered_cell, ghost_type, ghost_rotated)
	queue_redraw()


func place_gamepad_selection() -> void:
	begin_gamepad_paint()


func erase_gamepad_cell() -> void:
	begin_gamepad_erase()


func begin_gamepad_paint() -> void:
	if ghost_type == BuildingType.NONE:
		return
	gamepad_active = true
	is_brush_painting = true
	paint_stroke_started = false
	last_paint_cell = Vector2i(-999, -999)
	_try_paint(hovered_cell)


func continue_gamepad_paint() -> void:
	if not is_brush_painting:
		return
	_try_paint(hovered_cell)


func end_gamepad_paint() -> void:
	if not is_brush_painting:
		return
	is_brush_painting = false
	paint_stroke_started = false
	_flush_world_rebuild()
	ghost_valid = _is_footprint_valid(hovered_cell, ghost_type, ghost_rotated)


func begin_gamepad_erase() -> void:
	gamepad_active = true
	is_drag_erasing = true
	erase_stroke_started = false
	last_erase_cell = Vector2i(-999, -999)
	if _is_buildable(hovered_cell):
		_try_erase(hovered_cell)


func continue_gamepad_erase() -> void:
	if not is_drag_erasing:
		return
	if _is_buildable(hovered_cell):
		_try_erase(hovered_cell)


func end_gamepad_erase() -> void:
	if not is_drag_erasing:
		return
	is_drag_erasing = false
	erase_stroke_started = false
	_flush_world_rebuild()


static func type_name(building_type: BuildingType) -> String:
	match building_type:
		BuildingType.PARK:
			return "Park"
		BuildingType.FACTORY:
			return "Factory"
		BuildingType.ROAD:
			return "Road"
		BuildingType.OFFICE:
			return "Office"
		BuildingType.SKYSCRAPER:
			return "Skyscraper"
		BuildingType.DOWNTOWN:
			return "Downtown"
		BuildingType.SHOPS:
			return "Shops"
		BuildingType.RESIDENTIAL:
			return "Residential"
		BuildingType.SCHOOL:
			return "School"
		BuildingType.HOSPITAL:
			return "Hospital"
		BuildingType.FARM:
			return "Farm"
		BuildingType.HARBOR:
			return "Harbor"
		BuildingType.STADIUM:
			return "Stadium"
		BuildingType.WAREHOUSE:
			return "Warehouse"
		BuildingType.HOTEL:
			return "Hotel"
		BuildingType.MARKET:
			return "Market"
		_:
			return "None"


static func type_color(building_type: BuildingType) -> Color:
	return BUILDING_COLORS[building_type]


static func type_footprint(building_type: BuildingType, rotated: bool = false) -> Vector2i:
	var footprint: Vector2i = BUILDING_FOOTPRINTS.get(building_type, Vector2i(1, 1)) as Vector2i
	if rotated:
		return Vector2i(footprint.y, footprint.x)
	return footprint


static func type_outer_radius(building_type: BuildingType, _rotated: bool = false) -> int:
	# Base ring; merged lots refresh radius from actual bounds after stamp.
	match building_type:
		BuildingType.ROAD:
			return 1
		BuildingType.PARK, BuildingType.FARM:
			return 2
		BuildingType.SKYSCRAPER, BuildingType.DOWNTOWN, BuildingType.STADIUM:
			return 3
		_:
			return 2


static func recipe_list() -> Array[Dictionary]:
	return OVERLAP_RECIPES


static func terrain_name(terrain: TerrainType) -> String:
	match terrain:
		TerrainType.WATER:
			return "Lowland Water"
		TerrainType.MOUNTAIN:
			return "Highland Peak"
		TerrainType.RUINS:
			return "Ancient Ruins"
		_:
			return "Open Land"


static func terrain_list() -> Array[Dictionary]:
	return [
		{"type": TerrainType.WATER, "name": "Lowlands / Water", "desc": "Elevation below waterline · Harbor & Warehouse must touch shore", "color": TERRAIN_COLORS[TerrainType.WATER]},
		{"type": TerrainType.MOUNTAIN, "name": "Highlands / Peak", "desc": "Elevation above treeline · Hotel can touch peaks · Farm cannot", "color": TERRAIN_COLORS[TerrainType.MOUNTAIN]},
		{"type": TerrainType.RUINS, "name": "Ancient Ruins", "desc": "Unplayable · Hotel can touch ruins · Farm cannot", "color": TERRAIN_COLORS[TerrainType.RUINS]},
	]


static func placement_rule_text(building_type: BuildingType) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if PLACEMENT_RULES.has(building_type):
		var rule: Dictionary = PLACEMENT_RULES[building_type]
		if rule.has("any_of"):
			var names: PackedStringArray = PackedStringArray()
			for terrain in rule["any_of"]:
				names.append(_terrain_short_name(terrain as TerrainType))
			parts.append("near %s" % " / ".join(names))
		if rule.has("none_of"):
			var names: PackedStringArray = PackedStringArray()
			for terrain in rule["none_of"]:
				names.append(_terrain_short_name(terrain as TerrainType))
			parts.append("away from %s" % " / ".join(names))
	var avoid := _hazard_avoid_short_names(building_type)
	if not avoid.is_empty():
		parts.append("avoid %s" % " / ".join(avoid))
	return " · ".join(parts)


static func hazard_list() -> Array[Dictionary]:
	return HAZARD_PAIRS


static func _hazard_avoid_short_names(building_type: BuildingType) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for other in _hazard_banned_types(building_type):
		names.append(_building_short_name(other))
	return names


static func _hazard_banned_types(building_type: BuildingType) -> Array[BuildingType]:
	var banned: Array[BuildingType] = []
	for pair in HAZARD_PAIRS:
		var a: BuildingType = pair["a"] as BuildingType
		var b: BuildingType = pair["b"] as BuildingType
		if a == building_type and not banned.has(b):
			banned.append(b)
		elif b == building_type and not banned.has(a):
			banned.append(a)
	return banned


static func _building_short_name(building_type: BuildingType) -> String:
	match building_type:
		BuildingType.RESIDENTIAL:
			return "homes"
		BuildingType.SCHOOL:
			return "schools"
		BuildingType.HOSPITAL:
			return "hospitals"
		BuildingType.PARK:
			return "parks"
		BuildingType.FARM:
			return "farms"
		BuildingType.FACTORY:
			return "factories"
		BuildingType.WAREHOUSE:
			return "warehouses"
		BuildingType.STADIUM:
			return "stadiums"
		BuildingType.HARBOR:
			return "harbors"
		_:
			return type_name(building_type).to_lower()


static func _terrain_short_name(terrain: TerrainType) -> String:
	match terrain:
		TerrainType.WATER:
			return "water"
		TerrainType.MOUNTAIN:
			return "mountains"
		TerrainType.RUINS:
			return "ruins"
		_:
			return "open land"


func _initialize_grids() -> void:
	inner_cells.clear()
	building_ids.clear()
	land_mask.clear()
	terrain_cells.clear()
	elevation_cells.clear()
	outer_influences.clear()
	terrain_influences.clear()
	building_radii.clear()
	next_building_id = 1
	for y in GRID_HEIGHT:
		var inner_row: Array = []
		var id_row: Array = []
		var land_row: Array = []
		var terrain_row: Array = []
		var elev_row: Array = []
		var outer_row: Array = []
		var terrain_inf_row: Array = []
		for x in GRID_WIDTH:
			inner_row.append(BuildingType.NONE)
			id_row.append(0)
			land_row.append(true)
			terrain_row.append(TerrainType.OPEN)
			elev_row.append(0.5)
			outer_row.append(_make_empty_influence_counts())
			terrain_inf_row.append(_make_empty_terrain_influences())
		inner_cells.append(inner_row)
		building_ids.append(id_row)
		land_mask.append(land_row)
		terrain_cells.append(terrain_row)
		elevation_cells.append(elev_row)
		outer_influences.append(outer_row)
		terrain_influences.append(terrain_inf_row)


func elevation_at(cell: Vector2i) -> float:
	if not _is_in_bounds(cell):
		return 0.0
	return float(elevation_cells[cell.y][cell.x])


## Ground surface Y in TownWorld3D units (water line ≈ 0).
func ground_height(cell: Vector2i) -> float:
	var e := elevation_at(cell)
	if e < ELEV_WATER:
		return (e - ELEV_WATER) * ELEV_WORLD_SCALE * 0.55
	return (e - ELEV_WATER) / maxf(1.0 - ELEV_WATER, 0.001) * ELEV_WORLD_SCALE


func elev_delta(a: Vector2i, b: Vector2i) -> float:
	return elevation_at(a) - elevation_at(b)


func _generate_elevation_map(p_seed: int) -> void:
	var base := FastNoiseLite.new()
	base.seed = p_seed
	base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	base.frequency = 0.055
	base.fractal_type = FastNoiseLite.FRACTAL_FBM
	base.fractal_octaves = 4

	var detail := FastNoiseLite.new()
	detail.seed = p_seed + 77
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail.frequency = 0.14

	var ridge := FastNoiseLite.new()
	ridge.seed = p_seed + 191
	ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ridge.frequency = 0.09

	var ruins_noise := FastNoiseLite.new()
	ruins_noise.seed = p_seed + 53
	ruins_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	ruins_noise.frequency = 0.18

	var center := Vector2(GRID_WIDTH * 0.5, GRID_HEIGHT * 0.5)
	var max_dist := center.length()

	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var pos := Vector2(x + 0.5, y + 0.5)
			var radial := 1.0 - (pos.distance_to(center) / max_dist)
			# Edges fall to ocean; interior gets hills/peaks.
			var n := base.get_noise_2d(float(x), float(y)) * 0.55
			n += detail.get_noise_2d(float(x), float(y)) * 0.18
			var peak := absf(ridge.get_noise_2d(float(x), float(y)))
			n += peak * peak * 0.35
			var elev := clampf(radial * 0.72 + n * 0.55 + 0.18, 0.0, 1.0)
			elevation_cells[y][x] = elev
			land_mask[y][x] = true

	_sync_terrain_from_elevation()
	# Sparse ruins only on buildable midland.
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if terrain_cells[y][x] != TerrainType.OPEN:
				continue
			if ruins_noise.get_noise_2d(float(x), float(y)) > 0.64:
				terrain_cells[y][x] = TerrainType.RUINS
	_ensure_connected_buildable_land()


func _sync_terrain_from_elevation() -> void:
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var e: float = float(elevation_cells[y][x])
			if e < ELEV_WATER:
				terrain_cells[y][x] = TerrainType.WATER
			elif e > ELEV_MOUNTAIN:
				terrain_cells[y][x] = TerrainType.MOUNTAIN
			else:
				terrain_cells[y][x] = TerrainType.OPEN


func _generate_land_mask(_p_seed: int) -> void:
	# Kept as no-op stub; elevation map owns island shape now.
	pass


func _generate_terrain_features(p_seed: int) -> void:
	_generate_elevation_map(p_seed)


func _fill_void_as_terrain(p_seed: int) -> void:
	## Replace dark off-map cutouts with ocean water and mountain mass.
	var mountain_noise := FastNoiseLite.new()
	mountain_noise.seed = p_seed + 311
	mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mountain_noise.frequency = 0.09

	var original_land: Dictionary = {}
	var voids: Array[Vector2i] = []
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var cell := Vector2i(x, y)
			if land_mask[y][x]:
				original_land[cell] = true
			else:
				voids.append(cell)

	for cell in voids:
		land_mask[cell.y][cell.x] = true
		var near_land := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				if original_land.has(cell + Vector2i(dx, dy)):
					near_land = true
					break
			if near_land:
				break

		var mn := mountain_noise.get_noise_2d(float(cell.x), float(cell.y))
		if near_land:
			# Coastline / lake edge around the playable island.
			terrain_cells[cell.y][cell.x] = TerrainType.WATER
		elif mn > 0.18:
			terrain_cells[cell.y][cell.x] = TerrainType.MOUNTAIN
		else:
			terrain_cells[cell.y][cell.x] = TerrainType.WATER
	_fill_void_as_terrain(p_seed)


func _grow_feature_blobs(feature: TerrainType, passes: int) -> void:
	for _pass in passes:
		var copy := _clone_grid(terrain_cells)
		for y in GRID_HEIGHT:
			for x in GRID_WIDTH:
				if not land_mask[y][x] or copy[y][x] != TerrainType.OPEN:
					continue
				var feature_neighbors := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var ncell := Vector2i(x + dx, y + dy)
						if not _is_land(ncell):
							continue
						if copy[ncell.y][ncell.x] == feature:
							feature_neighbors += 1
				if feature_neighbors >= 3:
					terrain_cells[y][x] = feature


func _ensure_connected_buildable_land() -> void:
	# Keep the largest connected OPEN landmass so placement stays possible.
	var visited: Array = []
	for y in GRID_HEIGHT:
		var row: Array = []
		for x in GRID_WIDTH:
			row.append(false)
		visited.append(row)

	var best_cells: Array[Vector2i] = []
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if not _is_buildable(Vector2i(x, y)) or visited[y][x]:
				continue
			var component := _flood_buildable(Vector2i(x, y), visited)
			if component.size() > best_cells.size():
				best_cells = component

	if best_cells.is_empty():
		# Fallback: clear features from a central patch.
		var cx := floori(GRID_WIDTH / 2.0)
		var cy := floori(GRID_HEIGHT / 2.0)
		for y in range(cy - 3, cy + 4):
			for x in range(cx - 4, cx + 5):
				var cell := Vector2i(x, y)
				if _is_land(cell):
					terrain_cells[y][x] = TerrainType.OPEN
					best_cells.append(cell)

	var keep := {}
	for cell in best_cells:
		keep[cell] = true

	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if not land_mask[y][x]:
				continue
			if terrain_cells[y][x] != TerrainType.OPEN:
				continue
			if not keep.has(Vector2i(x, y)):
				# Convert stranded open pockets into mountains so they don't look like dead playable holes.
				terrain_cells[y][x] = TerrainType.MOUNTAIN


func _flood_buildable(start: Vector2i, visited: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var stack: Array[Vector2i] = [start]
	visited[start.y][start.x] = true
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		result.append(cell)
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + offset
			if not _is_buildable(next) or visited[next.y][next.x]:
				continue
			visited[next.y][next.x] = true
			stack.append(next)
	return result


func _ensure_connected_landmass() -> void:
	# Keep the largest connected land component so the board stays playable.
	var visited: Array = []
	for y in GRID_HEIGHT:
		var row: Array = []
		for x in GRID_WIDTH:
			row.append(false)
		visited.append(row)

	var best_cells: Array[Vector2i] = []
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if not land_mask[y][x] or visited[y][x]:
				continue
			var component := _flood_land(Vector2i(x, y), visited)
			if component.size() > best_cells.size():
				best_cells = component

	if best_cells.is_empty():
		# Rare fallback: carve a central island if noise produced nothing.
		var cx := floori(GRID_WIDTH / 2.0)
		var cy := floori(GRID_HEIGHT / 2.0)
		for y in range(cy - 4, cy + 5):
			for x in range(cx - 6, cx + 7):
				if _is_in_bounds(Vector2i(x, y)):
					best_cells.append(Vector2i(x, y))

	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			land_mask[y][x] = false
	for cell in best_cells:
		land_mask[cell.y][cell.x] = true

	# Soften tiny holes / jagged edges with a light majority pass.
	var copy := _clone_grid(land_mask)
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var land_neighbors := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx := x + dx
					var ny := y + dy
					if not _is_in_bounds(Vector2i(nx, ny)):
						continue
					if copy[ny][nx]:
						land_neighbors += 1
			if copy[y][x]:
				land_mask[y][x] = land_neighbors >= 2
			else:
				land_mask[y][x] = land_neighbors >= 6


func _flood_land(start: Vector2i, visited: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var stack: Array[Vector2i] = [start]
	visited[start.y][start.x] = true
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		result.append(cell)
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + offset
			if not _is_in_bounds(next):
				continue
			if visited[next.y][next.x] or not land_mask[next.y][next.x]:
				continue
			visited[next.y][next.x] = true
			stack.append(next)
	return result


func _stamp_building(start_x: int, start_y: int, building_type: BuildingType, _rotated: bool) -> void:
	if building_type == BuildingType.NONE:
		return
	var cell := Vector2i(start_x, start_y)
	if not _is_buildable(cell):
		return

	# Roads stay per-cell (no mega-merge) so traffic/recipes stay sane.
	if building_type == BuildingType.ROAD:
		var road_id := next_building_id
		next_building_id += 1
		inner_cells[start_y][start_x] = BuildingType.ROAD
		building_ids[start_y][start_x] = road_id
		building_radii[road_id] = 1
		_recalculate_outer_influences()
		if citizen_sim != null:
			citizen_sim.on_town_changed(cell, building_type, true)
		if vehicle_sim != null:
			vehicle_sim.on_town_changed(cell, building_type, true)
		_mark_world_dirty()
		return

	# Paint one cell, then union with orthogonal same-type neighbors.
	var prev_id: int = building_ids[start_y][start_x]
	var prev_type: BuildingType = inner_cells[start_y][start_x]

	var merge_ids: Array[int] = []
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cell + d
		if not _is_in_bounds(n):
			continue
		if inner_cells[n.y][n.x] != building_type:
			continue
		var nid: int = building_ids[n.y][n.x]
		if nid != 0 and not merge_ids.has(nid):
			merge_ids.append(nid)

	var building_id: int
	if merge_ids.is_empty():
		building_id = next_building_id
		next_building_id += 1
	else:
		building_id = merge_ids[0]
		for i in range(1, merge_ids.size()):
			_reassign_building_id(merge_ids[i], building_id)

	inner_cells[start_y][start_x] = building_type
	building_ids[start_y][start_x] = building_id
	_refresh_building_radius(building_id, building_type)

	# If we overwrote a different building, split/cleanup the old ID.
	if prev_id != 0 and prev_id != building_id and prev_type != BuildingType.NONE:
		if prev_type == BuildingType.ROAD or not _building_id_exists(prev_id):
			building_radii.erase(prev_id)
		else:
			_split_building_components(prev_id, prev_type)

	_recalculate_outer_influences()
	if citizen_sim != null:
		citizen_sim.on_town_changed(cell, building_type, true)
	if vehicle_sim != null:
		vehicle_sim.on_town_changed(cell, building_type, true)
	_mark_world_dirty()


func _reassign_building_id(from_id: int, to_id: int) -> void:
	if from_id == 0 or to_id == 0 or from_id == to_id:
		return
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if building_ids[y][x] == from_id:
				building_ids[y][x] = to_id
	building_radii.erase(from_id)


func _refresh_building_radius(building_id: int, building_type: BuildingType) -> void:
	var bounds := _building_bounds(building_id)
	if bounds.size.x <= 0:
		building_radii.erase(building_id)
		return
	var base := type_outer_radius(building_type)
	var grown := maxi(base, mini(bounds.size.x, bounds.size.y))
	building_radii[building_id] = clampi(grown, 1, 5)


func _try_paint(cell: Vector2i) -> void:
	if ghost_type == BuildingType.NONE:
		return
	if cell == last_paint_cell:
		return
	last_paint_cell = cell
	if not _is_in_bounds(cell):
		return
	hovered_cell = cell
	ghost_rotated = active_brush_rotated
	if not _is_footprint_valid(cell, ghost_type, ghost_rotated):
		ghost_valid = false
		return
	ghost_valid = true
	if not paint_stroke_started:
		_push_undo_snapshot()
		paint_stroke_started = true
	_stamp_building(cell.x, cell.y, ghost_type, ghost_rotated)
	ghost_valid = _is_footprint_valid(hovered_cell, ghost_type, ghost_rotated)


func _try_erase(cell: Vector2i) -> void:
	if cell == last_erase_cell:
		return
	last_erase_cell = cell
	if not _is_buildable(cell):
		return
	if inner_cells[cell.y][cell.x] == BuildingType.NONE:
		return
	if not erase_stroke_started:
		_push_undo_snapshot()
		erase_stroke_started = true
	var erased_type: BuildingType = inner_cells[cell.y][cell.x]
	var erased_id: int = building_ids[cell.y][cell.x]
	inner_cells[cell.y][cell.x] = BuildingType.NONE
	building_ids[cell.y][cell.x] = 0
	if erased_id != 0:
		if erased_type == BuildingType.ROAD or not _building_id_exists(erased_id):
			building_radii.erase(erased_id)
		else:
			_split_building_components(erased_id, erased_type)
	_recalculate_outer_influences()
	if citizen_sim != null:
		citizen_sim.on_town_changed(cell, erased_type, false)
	if vehicle_sim != null:
		vehicle_sim.on_town_changed(cell, erased_type, false)
	_mark_world_dirty()


func _split_building_components(building_id: int, building_type: BuildingType) -> void:
	# After punching a hole, re-ID each orthogonal component.
	var cells: Array[Vector2i] = []
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if building_ids[y][x] == building_id:
				cells.append(Vector2i(x, y))
	if cells.is_empty():
		building_radii.erase(building_id)
		return
	var visited: Dictionary = {}
	var first := true
	for start in cells:
		if visited.has(start):
			continue
		var component: Array[Vector2i] = []
		var stack: Array[Vector2i] = [start]
		visited[start] = true
		while not stack.is_empty():
			var c: Vector2i = stack.pop_back()
			component.append(c)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if visited.has(n):
					continue
				if not _is_in_bounds(n):
					continue
				if building_ids[n.y][n.x] != building_id:
					continue
				visited[n] = true
				stack.append(n)
		var keep_id := building_id if first else next_building_id
		if not first:
			next_building_id += 1
			for c2 in component:
				building_ids[c2.y][c2.x] = keep_id
		first = false
		_refresh_building_radius(keep_id, building_type)


func _building_id_exists(building_id: int) -> bool:
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if building_ids[y][x] == building_id:
				return true
	return false


func _recalculate_outer_influences() -> void:
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var counts: Dictionary = outer_influences[y][x]
			for building_type in PLACEABLE_TYPES:
				counts[building_type] = {}

	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var inner_type: BuildingType = inner_cells[y][x]
			if inner_type == BuildingType.NONE:
				continue
			var source_id: int = building_ids[y][x]
			if source_id == 0:
				continue
			var radius: int = int(building_radii.get(source_id, 1))
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if dx == 0 and dy == 0:
						continue
					if maxi(absi(dx), absi(dy)) > radius:
						continue
					var tx := x + dx
					var ty := y + dy
					if not _is_buildable(Vector2i(tx, ty)):
						continue
					# A building should not influence its own footprint cells.
					if building_ids[ty][tx] == source_id:
						continue
					var id_set: Dictionary = outer_influences[ty][tx][inner_type]
					id_set[source_id] = true


func _recalculate_terrain_influences() -> void:
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var flags: Dictionary = terrain_influences[y][x]
			for terrain in FEATURE_TERRAINS:
				flags[terrain] = false

	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if not land_mask[y][x]:
				continue
			var terrain: TerrainType = terrain_cells[y][x]
			if terrain == TerrainType.OPEN:
				continue
			var radius: int = int(TERRAIN_INFLUENCE_RADIUS.get(terrain, 1))
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if maxi(absi(dx), absi(dy)) > radius:
						continue
					var tx := x + dx
					var ty := y + dy
					if not _is_buildable(Vector2i(tx, ty)):
						continue
					terrain_influences[ty][tx][terrain] = true


func _resolve_outer_result(x: int, y: int) -> Dictionary:
	var counts: Dictionary = outer_influences[y][x]
	var type_counts := {}
	for building_type in PLACEABLE_TYPES:
		type_counts[building_type] = (counts[building_type] as Dictionary).size()

	var result: Dictionary = {}
	var matched_recipe := _find_matching_recipe(type_counts)
	if not matched_recipe.is_empty():
		result = {
			"color": matched_recipe["color"],
			"name": matched_recipe["name"],
			"detail": matched_recipe["desc"],
			"recipe_id": matched_recipe["id"],
		}
	else:
		var contributing_types: Array[BuildingType] = []
		for building_type in PLACEABLE_TYPES:
			if type_counts[building_type] > 0:
				contributing_types.append(building_type)

		if contributing_types.is_empty():
			result = {
				"color": BUILDING_COLORS[BuildingType.NONE],
				"name": "Empty",
				"detail": "No outer influence",
			}
		elif contributing_types.size() == 1:
			var only_type: BuildingType = contributing_types[0]
			result = {
				"color": OUTER_SINGLE_COLORS[only_type],
				"name": "%s Influence" % type_name(only_type),
				"detail": "Outer ring from nearby %s" % type_name(only_type).to_lower(),
				"influence_type": only_type,
			}
		else:
			var mixed := Color(0, 0, 0, 1)
			var names: PackedStringArray = PackedStringArray()
			for building_type in contributing_types:
				mixed += OUTER_SINGLE_COLORS[building_type]
				names.append(type_name(building_type))
			mixed /= float(contributing_types.size())
			result = {
				"color": mixed,
				"name": "Mixed Influence",
				"detail": " + ".join(names),
			}

	# Soft terrain adjacency tint + labels (hooks for future building+terrain recipes).
	var nearby_terrain := _nearby_terrain_names(x, y)
	if not nearby_terrain.is_empty():
		var tint := _terrain_tint_for_cell(x, y)
		var base_color: Color = result["color"]
		result["color"] = base_color.lerp(tint, 0.28)
		result["detail"] = "%s · Near %s" % [result["detail"], ", ".join(nearby_terrain)]
		result["nearby_terrain"] = nearby_terrain

	return result


func _find_matching_recipe(type_counts: Dictionary) -> Dictionary:
	for recipe in OVERLAP_RECIPES:
		if _recipe_requirements_met(recipe, type_counts):
			return recipe
	return {}


func _recipe_requirements_met(recipe: Dictionary, type_counts: Dictionary) -> bool:
	if not recipe.has("requires"):
		return false
	var requirements: Array = recipe["requires"]
	for requirement in requirements:
		var building_type: BuildingType = requirement["type"] as BuildingType
		var minimum: int = int(requirement.get("min", 1))
		var present: int = int(type_counts.get(building_type, 0))
		if present < minimum:
			return false
	return true


func _nearby_terrain_names(x: int, y: int) -> PackedStringArray:
	var flags: Dictionary = terrain_influences[y][x]
	var names: PackedStringArray = PackedStringArray()
	for terrain in FEATURE_TERRAINS:
		if flags[terrain]:
			names.append(terrain_name(terrain))
	return names


func _terrain_tint_for_cell(x: int, y: int) -> Color:
	var flags: Dictionary = terrain_influences[y][x]
	var tint := Color(0, 0, 0, 1)
	var count := 0
	for terrain in FEATURE_TERRAINS:
		if flags[terrain]:
			tint += TERRAIN_INFLUENCE_COLORS[terrain]
			count += 1
	if count == 0:
		return BUILDING_COLORS[BuildingType.NONE]
	return tint / float(count)


func _grid_origin() -> Vector2:
	var total_size := Vector2(GRID_WIDTH * _cell_size, GRID_HEIGHT * _row_height())
	return (size - total_size) * 0.5


func _cell_from_mouse(mouse_position: Vector2) -> Vector2i:
	if town_world != null and _world_viewport != null:
		var cell: Vector2i = town_world.screen_to_cell(mouse_position, Vector2(_world_viewport.size))
		if cell.x >= 0:
			return cell
	var world := _screen_to_world(mouse_position)
	var local := world - _grid_origin()
	return Vector2i(floori(local.x / _cell_size), floori(local.y / _row_height()))


func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT


func _is_land(cell: Vector2i) -> bool:
	return _is_in_bounds(cell) and land_mask[cell.y][cell.x]


func _is_buildable(cell: Vector2i) -> bool:
	return _is_land(cell) and terrain_cells[cell.y][cell.x] == TerrainType.OPEN


func _is_footprint_valid(cell: Vector2i, building_type: BuildingType, rotated: bool) -> bool:
	if not _is_buildable(cell):
		return false
	var footprint := type_footprint(building_type, rotated)
	for dy in footprint.y:
		for dx in footprint.x:
			if not _is_buildable(Vector2i(cell.x + dx, cell.y + dy)):
				return false
	if not _placement_rules_met(cell, footprint, building_type):
		return false
	if _hazard_conflict_type(cell, footprint, building_type) != BuildingType.NONE:
		return false
	return true


func _placement_rules_met(origin: Vector2i, footprint: Vector2i, building_type: BuildingType) -> bool:
	if not PLACEMENT_RULES.has(building_type):
		return true
	var rule: Dictionary = PLACEMENT_RULES[building_type]
	if rule.has("any_of"):
		var matched := false
		for terrain in rule["any_of"]:
			if _footprint_touches_terrain(origin, footprint, terrain as TerrainType):
				matched = true
				break
		if not matched:
			return false
	if rule.has("none_of"):
		for terrain in rule["none_of"]:
			if _footprint_touches_terrain(origin, footprint, terrain as TerrainType):
				return false
	return true


func _hazard_conflict_type(origin: Vector2i, footprint: Vector2i, building_type: BuildingType) -> BuildingType:
	var banned := _hazard_banned_types(building_type)
	if banned.is_empty():
		return BuildingType.NONE

	var footprint_cells: Dictionary = {}
	for dy in footprint.y:
		for dx in footprint.x:
			footprint_cells[Vector2i(origin.x + dx, origin.y + dy)] = true

	for cell in footprint_cells.keys():
		for ny in range(-1, 2):
			for nx in range(-1, 2):
				if nx == 0 and ny == 0:
					continue
				var neighbor: Vector2i = cell + Vector2i(nx, ny)
				if footprint_cells.has(neighbor):
					continue
				if not _is_buildable(neighbor):
					continue
				var existing: BuildingType = inner_cells[neighbor.y][neighbor.x]
				if banned.has(existing):
					return existing
	return BuildingType.NONE


func _footprint_touches_terrain(origin: Vector2i, footprint: Vector2i, terrain: TerrainType) -> bool:
	for dy in footprint.y:
		for dx in footprint.x:
			var cell := Vector2i(origin.x + dx, origin.y + dy)
			for ny in range(-1, 2):
				for nx in range(-1, 2):
					if nx == 0 and ny == 0:
						continue
					var neighbor := Vector2i(cell.x + nx, cell.y + ny)
					if not _is_in_bounds(neighbor):
						continue
					if not land_mask[neighbor.y][neighbor.x]:
						continue
					if terrain_cells[neighbor.y][neighbor.x] == terrain:
						return true
	return false


func placement_failure_reason(cell: Vector2i, building_type: BuildingType, rotated: bool = false) -> String:
	if not _is_in_bounds(cell) or not _is_land(cell):
		return "Off the map"
	var footprint := type_footprint(building_type, rotated)
	for dy in footprint.y:
		for dx in footprint.x:
			var check := Vector2i(cell.x + dx, cell.y + dy)
			if not _is_buildable(check):
				return "Needs clear open land"
	if not _placement_rules_met(cell, footprint, building_type):
		var terrain_text := ""
		if PLACEMENT_RULES.has(building_type):
			var rule: Dictionary = PLACEMENT_RULES[building_type]
			var parts: PackedStringArray = PackedStringArray()
			if rule.has("any_of"):
				var names: PackedStringArray = PackedStringArray()
				for terrain in rule["any_of"]:
					names.append(_terrain_short_name(terrain as TerrainType))
				parts.append("near %s" % " / ".join(names))
			if rule.has("none_of"):
				var names: PackedStringArray = PackedStringArray()
				for terrain in rule["none_of"]:
					names.append(_terrain_short_name(terrain as TerrainType))
				parts.append("away from %s" % " / ".join(names))
			terrain_text = " · ".join(parts)
		return "Must be %s" % terrain_text
	var conflict := _hazard_conflict_type(cell, footprint, building_type)
	if conflict != BuildingType.NONE:
		return "Hazard: too close to %s" % type_name(conflict)
	return ""

func _is_valid_drag_data(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("building_type"):
		return false
	var building_type: BuildingType = data["building_type"] as BuildingType
	return PLACEABLE_TYPES.has(building_type)


func _make_empty_influence_counts() -> Dictionary:
	var counts := {}
	for building_type in PLACEABLE_TYPES:
		counts[building_type] = {}
	return counts


func _make_empty_terrain_influences() -> Dictionary:
	var flags := {}
	for terrain in FEATURE_TERRAINS:
		flags[terrain] = false
	return flags


func _chebyshev_to_rect(tx: int, ty: int, start: Vector2i, footprint: Vector2i) -> int:
	var clamped_x := clampi(tx, start.x, start.x + footprint.x - 1)
	var clamped_y := clampi(ty, start.y, start.y + footprint.y - 1)
	return maxi(absi(tx - clamped_x), absi(ty - clamped_y))


func _update_hover_tooltip(mouse_position: Vector2) -> void:
	var cell := _cell_from_mouse(mouse_position)
	if cell == hover_info_cell:
		return
	hover_info_cell = cell

	if not _is_in_bounds(cell):
		tooltip_text = ""
		return
	if not _is_land(cell):
		tooltip_text = "Unmapped cell"
		return

	var terrain: TerrainType = terrain_cells[cell.y][cell.x]
	if terrain != TerrainType.OPEN:
		tooltip_text = "%s\nUnplayable terrain\nUsed by placement rules (Harbor→water, Hotel→mountain/ruins, Farm away from mountain/ruins)." % terrain_name(terrain)
		return

	var result := _resolve_outer_result(cell.x, cell.y)
	var inner_type: BuildingType = inner_cells[cell.y][cell.x]
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Outer: %s" % result["name"])
	lines.append(str(result["detail"]))
	if inner_type != BuildingType.NONE:
		lines.append("Inner: %s" % type_name(inner_type))
	else:
		lines.append("Inner: empty")
	if ghost_type != BuildingType.NONE and not ghost_valid:
		var reason := placement_failure_reason(cell, ghost_type, ghost_rotated)
		if not reason.is_empty():
			lines.append("Cannot place: %s" % reason)
	tooltip_text = "\n".join(lines)


func _push_undo_snapshot() -> void:
	undo_stack.append(_clone_state())
	if undo_stack.size() > MAX_HISTORY:
		undo_stack.pop_front()
	redo_stack.clear()
	_emit_history_changed()


func _clone_state() -> Dictionary:
	return {
		"inner": _clone_grid(inner_cells),
		"ids": _clone_grid(building_ids),
		"radii": building_radii.duplicate(),
		"next_id": next_building_id,
	}


func _clone_grid(source: Array) -> Array:
	var copy: Array = []
	for y in GRID_HEIGHT:
		var row: Array = []
		for x in GRID_WIDTH:
			row.append(source[y][x])
		copy.append(row)
	return copy


func _restore_state(snapshot: Dictionary) -> void:
	var inner_snapshot: Array = snapshot["inner"]
	var id_snapshot: Array = snapshot["ids"]
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			inner_cells[y][x] = inner_snapshot[y][x]
			building_ids[y][x] = id_snapshot[y][x]
	building_radii = (snapshot["radii"] as Dictionary).duplicate()
	next_building_id = snapshot["next_id"]
	_recalculate_outer_influences()
	if citizen_sim != null:
		citizen_sim.clear()
	if citizen_sim != null:
		citizen_sim.clear()
	if vehicle_sim != null:
		vehicle_sim.clear()


func _grid_is_empty() -> bool:
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if inner_cells[y][x] != BuildingType.NONE:
				return false
	return true


func _emit_history_changed() -> void:
	history_changed.emit(can_undo(), can_redo())


func _find_nearest_buildable(start: Vector2i) -> Vector2i:
	if _is_buildable(start):
		return start
	for radius in range(1, maxi(GRID_WIDTH, GRID_HEIGHT)):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var candidate := start + Vector2i(dx, dy)
				if _is_buildable(candidate):
					return candidate
	return Vector2i(clampi(start.x, 0, GRID_WIDTH - 1), clampi(start.y, 0, GRID_HEIGHT - 1))


func _find_nearest_valid_placement(start: Vector2i, building_type: BuildingType, rotated: bool) -> Vector2i:
	if _is_footprint_valid(start, building_type, rotated):
		return start
	for radius in range(1, maxi(GRID_WIDTH, GRID_HEIGHT)):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var candidate := start + Vector2i(dx, dy)
				if _is_footprint_valid(candidate, building_type, rotated):
					return candidate
	return start
