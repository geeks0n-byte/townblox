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

const GRID_WIDTH := 48
const GRID_HEIGHT := 28
const TILE_PX := 16.0
const MAX_HISTORY := 64
const TILE_ANIM_INTERVAL := 1.0 / TileLibrary.ANIM_FPS
## Pitch camera down only (no left/right tilt): foreshorten ground rows.
## Actual foreshortening may relax toward 1.0 so the map fills leftover vertical space.
const VIEW_Y_SCALE := 0.58
## Buildings/tall terrain stand up against the foreshortened ground.
const ELEVATION_HEIGHT := 1.35
const TERRAIN_ELEVATION := 1.05
const ZOOM_MIN := 1.0
const ZOOM_MAX := 4.0
const ZOOM_STEP := 1.12
const DOF_ZOOM_START := 1.25
const ANIM_FRAME_MODULO := 8

## Street-level actor sizes as fractions of cell width (shared baseline at cell bottom).
## Tuned so NPCs, cars, and facades read together when zoomed in (Beat Cop-ish).
const NPC_W := 0.42
const NPC_H := 0.82
const CAR_W := 0.84
const CAR_H := 0.52
const BIKE_W := 0.56
const BIKE_H := 0.50
const BUS_W := 0.96
const BUS_H := 0.60
const EMOTE_W := 0.36

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
	BuildingType.PARK: Vector2i(2, 2),
	BuildingType.FACTORY: Vector2i(3, 2),
	BuildingType.ROAD: Vector2i(1, 1),
	BuildingType.OFFICE: Vector2i(2, 2),
	BuildingType.SKYSCRAPER: Vector2i(2, 3),
	BuildingType.DOWNTOWN: Vector2i(3, 3),
	BuildingType.SHOPS: Vector2i(2, 1),
	BuildingType.RESIDENTIAL: Vector2i(2, 2),
	BuildingType.SCHOOL: Vector2i(2, 2),
	BuildingType.HOSPITAL: Vector2i(3, 2),
	BuildingType.FARM: Vector2i(3, 2),
	BuildingType.HARBOR: Vector2i(3, 2),
	BuildingType.STADIUM: Vector2i(3, 3),
	BuildingType.WAREHOUSE: Vector2i(3, 2),
	BuildingType.HOTEL: Vector2i(2, 2),
	BuildingType.MARKET: Vector2i(2, 1),
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

## Shared during an active palette drag so R can rotate before drop.
static var active_drag_rotated := false

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
var erase_stroke_started := false
var last_erase_cell: Vector2i = Vector2i(-999, -999)
var undo_stack: Array = []
var redo_stack: Array = []
var hover_info_cell: Vector2i = Vector2i(-1, -1)
var gamepad_active := false
var _tile_anim_timer := 0.0
var _tile_anim_frame := 0
var _cell_size := TILE_PX * 2.0
var _view_y_scale := VIEW_Y_SCALE
var citizen_sim: CitizenSim = CitizenSim.new()
var vehicle_sim: VehicleSim = VehicleSim.new()
var view_zoom := 1.0
var view_pan := Vector2.ZERO
var _is_panning := false
var _pan_last := Vector2.ZERO
## 0 = midnight, 0.25 = dawn, 0.5 = noon, 0.75 = dusk
var day_time := 0.32
var _last_day_phase: DayPhase = DayPhase.DAY


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = TEXTURE_FILTER_NEAREST
	TileLibrary.ensure_ready()
	citizen_sim.setup(self)
	vehicle_sim.setup(self)
	if not citizen_sim.chatter.is_connected(_on_citizen_chatter):
		citizen_sim.chatter.connect(_on_citizen_chatter)
	if not vehicle_sim.chatter.is_connected(_on_citizen_chatter):
		vehicle_sim.chatter.connect(_on_citizen_chatter)
	_initialize_grids()
	generate_board_shape()
	_update_cell_size()
	hovered_cell = _find_nearest_buildable(Vector2i(floori(GRID_WIDTH / 2.0), floori(GRID_HEIGHT / 2.0)))
	_last_day_phase = get_day_phase()
	_emit_history_changed()
	queue_redraw()


func _process(delta: float) -> void:
	var need_redraw := false
	_tile_anim_timer += delta
	if _tile_anim_timer >= TILE_ANIM_INTERVAL:
		_tile_anim_timer = 0.0
		_tile_anim_frame = (_tile_anim_frame + 1) % ANIM_FRAME_MODULO
		need_redraw = true

	day_time = fposmod(day_time + delta / DAY_LENGTH_SEC, 1.0)
	var phase := get_day_phase()
	if phase != _last_day_phase:
		_last_day_phase = phase
		day_phase_changed.emit(day_phase_name(phase))
		need_redraw = true

	if citizen_sim != null:
		citizen_sim.tick(delta)
		if not citizen_sim.citizens.is_empty():
			need_redraw = true
	if vehicle_sim != null:
		vehicle_sim.tick(delta)
		if not vehicle_sim.vehicles.is_empty():
			need_redraw = true
	# Lighting drifts continuously through the 12-minute day.
	need_redraw = true
	if need_redraw:
		queue_redraw()


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


func _elevated_rect(x: int, y: int, height_factor: float, origin: Vector2) -> Rect2:
	var ground := _ground_rect(x, y, origin)
	var height := _cell_size * height_factor
	# Edge-to-edge so neighboring facades abut (no grass gutters between lots).
	return Rect2(
		Vector2(ground.position.x, ground.position.y + ground.size.y - height),
		Vector2(ground.size.x, height)
	)


func _building_height_factor(building_type: BuildingType) -> float:
	match building_type:
		BuildingType.SKYSCRAPER:
			return 2.05
		BuildingType.DOWNTOWN, BuildingType.HOTEL, BuildingType.OFFICE:
			return 1.65
		BuildingType.HOSPITAL, BuildingType.SCHOOL, BuildingType.FACTORY, BuildingType.WAREHOUSE:
			return 1.45
		BuildingType.STADIUM:
			return 1.35
		BuildingType.SHOPS, BuildingType.MARKET, BuildingType.RESIDENTIAL, BuildingType.HARBOR:
			return 1.25
		BuildingType.PARK, BuildingType.FARM:
			return 1.05
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


func _facade_rect(bounds: Rect2i, height_factor: float, origin: Vector2) -> Rect2:
	var tl := _cell_screen_pos(bounds.position.x, bounds.position.y, origin)
	var br := _cell_screen_pos(bounds.position.x + bounds.size.x, bounds.position.y + bounds.size.y, origin)
	var ground := Rect2(tl, br - tl)
	# Slightly taller for deeper lots so the block reads as a street wall.
	var depth_boost := 1.0 + 0.12 * float(maxi(0, bounds.size.y - 1))
	var height := _cell_size * height_factor * depth_boost
	return Rect2(
		Vector2(ground.position.x, ground.position.y + ground.size.y - height),
		Vector2(ground.size.x, height)
	)


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
		queue_redraw()
	elif what == NOTIFICATION_DRAG_END:
		ghost_type = BuildingType.NONE
		ghost_rotated = false
		ghost_valid = false
		hovered_cell = Vector2i(-1, -1)
		active_drag_rotated = false
		queue_redraw()


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
		# Keep DoF focus aligned with cursor when using mouse (gamepad owns hover).
		if not gamepad_active:
			var hover := _cell_from_mouse(mm.position)
			if _is_in_bounds(hover):
				hovered_cell = hover
		_update_hover_tooltip(mm.position)
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


func _clamp_pan() -> void:
	if view_zoom <= 1.001:
		view_pan = Vector2.ZERO
		return
	var world_size := Vector2(GRID_WIDTH * _cell_size, GRID_HEIGHT * _row_height())
	var max_pan := world_size * 0.35 * (view_zoom - 1.0)
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


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not _is_valid_drag_data(data):
		return false

	ghost_type = data["building_type"] as BuildingType
	ghost_rotated = active_drag_rotated
	hovered_cell = _cell_from_mouse(at_position)
	ghost_valid = _is_footprint_valid(hovered_cell, ghost_type, ghost_rotated)
	queue_redraw()
	# Keep accepting while dragging so the ghost updates; drop itself enforces validity.
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _is_valid_drag_data(data):
		return

	var cell := _cell_from_mouse(at_position)
	var building_type := data["building_type"] as BuildingType
	var rotated := active_drag_rotated
	if not _is_footprint_valid(cell, building_type, rotated):
		return

	_push_undo_snapshot()
	_stamp_building(cell.x, cell.y, building_type, rotated)
	ghost_type = BuildingType.NONE
	ghost_rotated = false
	ghost_valid = false
	hovered_cell = Vector2i(-1, -1)
	active_drag_rotated = false
	queue_redraw()


func _draw() -> void:
	var origin := _grid_origin()
	# Pass 1: foreshortened ground / water / roads / influence (back to front).
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var cell := Vector2i(x, y)
			# Slight overlap hides foreshortened seams (living map, not graph paper).
			var cell_rect := _ground_rect(x, y, origin).grow(0.6)
			var terrain: TerrainType = terrain_cells[y][x]
			if not land_mask[y][x]:
				_draw_water_cell(cell_rect, cell, true)
				continue

			if terrain == TerrainType.WATER:
				_draw_water_cell(cell_rect, cell, false)
				continue

			if terrain == TerrainType.MOUNTAIN or terrain == TerrainType.RUINS:
				_draw_tile_world(cell_rect, TileLibrary.open_tex((x * 3 + y) % 4), cell)
				continue

			var inner_type: BuildingType = inner_cells[y][x]
			if inner_type == BuildingType.ROAD:
				_draw_tile_world(cell_rect, TileLibrary.road_auto_tex(_road_mask(cell)), cell)
				continue
			if inner_type != BuildingType.NONE:
				# Sidewalk lot under every building — continuous street base.
				_draw_tile_world(cell_rect, TileLibrary.sidewalk_tex((x + y) % 2), cell)
				continue

			var result := _resolve_outer_result(x, y)
			var recipe_id: String = str(result.get("recipe_id", ""))
			if not recipe_id.is_empty():
				_draw_tile_world(cell_rect, TileLibrary.recipe_tex(recipe_id), cell)
			elif result.has("influence_type"):
				_draw_tile_world(cell_rect, TileLibrary.influence_tex(result["influence_type"] as BuildingType), cell)
			else:
				_draw_tile_world(cell_rect, TileLibrary.open_tex((x * 3 + y * 7) % 4), cell)
				if str(result.get("name", "")) == "Mixed Influence":
					var mixed := _world_to_screen_rect(cell_rect)
					var dof := _dof_strength(cell)
					draw_rect(mixed, Color(0.25, 0.2, 0.35, 0.22 * (1.0 - dof * 0.4)), true)

	# Pass 2: tall sprites — mountains/ruins + one facade per building id.
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if not land_mask[y][x]:
				continue
			var cell := Vector2i(x, y)
			var terrain: TerrainType = terrain_cells[y][x]
			if terrain == TerrainType.MOUNTAIN:
				_draw_tile_world(
					_elevated_rect(x, y, TERRAIN_ELEVATION, origin),
					TileLibrary.mountain_auto_tex(_terrain_mask(cell, TerrainType.MOUNTAIN)),
					cell
				)
				continue
			if terrain == TerrainType.RUINS:
				_draw_tile_world(
					_elevated_rect(x, y, TERRAIN_ELEVATION * 0.85, origin),
					TileLibrary.ruins_auto_tex(_terrain_mask(cell, TerrainType.RUINS), _tile_anim_frame),
					cell
				)
				continue
			if terrain != TerrainType.OPEN:
				continue

	_draw_building_facades(origin)
	_draw_citizens(origin)
	_draw_vehicles(origin)
	_draw_ghost_preview(origin)
	_draw_day_overlay()


func _draw_building_facades(origin: Vector2) -> void:
	var drawn: Dictionary = {}
	# Back-to-front by southern edge so nearer facades cover farther ones.
	var entries: Array[Dictionary] = []
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if not land_mask[y][x]:
				continue
			if terrain_cells[y][x] != TerrainType.OPEN:
				continue
			var building_id: int = building_ids[y][x]
			if building_id == 0 or drawn.has(building_id):
				continue
			var inner_type: BuildingType = inner_cells[y][x]
			if inner_type == BuildingType.NONE or inner_type == BuildingType.ROAD:
				continue
			drawn[building_id] = true
			var bounds := _building_bounds(building_id)
			if bounds.size.x <= 0:
				continue
			entries.append({
				"id": building_id,
				"type": inner_type,
				"bounds": bounds,
				"sort_y": bounds.position.y + bounds.size.y,
			})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["sort_y"]) < int(b["sort_y"])
	)
	for entry in entries:
		var bounds: Rect2i = entry["bounds"]
		var building_type: BuildingType = entry["type"]
		var facade := _facade_rect(bounds, _building_height_factor(building_type), origin)
		var anchor := Vector2i(bounds.position.x, bounds.position.y + bounds.size.y - 1)
		var shadow := _world_to_screen_rect(facade.grow(1.0))
		draw_rect(shadow, Color(0.05, 0.05, 0.08, 0.32 * (1.0 - _dof_strength(anchor) * 0.5)), true)
		var b_frames := TileLibrary.building_frame_count(building_type)
		_draw_tile_world(
			facade,
			TileLibrary.building_tex(building_type, _tile_anim_frame % b_frames),
			anchor
		)


func _draw_water_cell(cell_rect: Rect2, cell: Vector2i, _ocean: bool) -> void:
	# Seamless water body with neighbor-aware shore foam; anim phase by cell.
	var mask := _water_mask(cell)
	var frame := (_tile_anim_frame + cell.x * 3 + cell.y * 5) % TileLibrary.WATER_FRAMES
	# Tiny sink so water sits slightly under grass lips without per-cell basins.
	var sunk := cell_rect.grow(0.4)
	sunk.position.y += _row_height() * 0.06
	draw_rect(_world_to_screen_rect(cell_rect.grow(0.8)), Color(0.12, 0.28, 0.4, 1.0), true)
	_draw_tile_world(sunk, TileLibrary.water_auto_tex(mask, frame), cell)


func _draw_vehicles(origin: Vector2) -> void:
	if vehicle_sim == null:
		return
	for vehicle in vehicle_sim.get_sorted_for_draw():
		var cell: Vector2i = vehicle["cell"]
		if not _is_in_bounds(cell):
			continue
		var ground := _ground_rect(cell.x, cell.y, origin)
		var kind: int = int(vehicle.get("kind", TileLibrary.VehicleKind.CAR))
		var w_frac := CAR_W
		var h_frac := CAR_H
		match kind:
			TileLibrary.VehicleKind.BUS:
				w_frac = BUS_W
				h_frac = BUS_H
			TileLibrary.VehicleKind.BIKE:
				w_frac = BIKE_W
				h_frac = BIKE_H
		var dest := _actor_rect(ground, w_frac, h_frac)
		_draw_tile_world(
			dest,
			TileLibrary.vehicle_tex(
				kind as TileLibrary.VehicleKind,
				int(vehicle.get("dir", 0)),
				int(vehicle.get("walk_frame", 0))
			),
			cell
		)


func _draw_day_overlay() -> void:
	var alpha := day_overlay_alpha()
	if alpha <= 0.001:
		return
	var night := Color(0.05, 0.08, 0.2, alpha)
	if get_day_phase() == DayPhase.DUSK:
		night = Color(0.35, 0.12, 0.1, alpha)
	elif get_day_phase() == DayPhase.DAWN:
		night = Color(0.55, 0.35, 0.25, alpha)
	draw_rect(Rect2(Vector2.ZERO, size), night, true)


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


func _draw_citizens(origin: Vector2) -> void:
	if citizen_sim == null:
		return
	for citizen in citizen_sim.get_sorted_for_draw():
		var cell: Vector2i = citizen["cell"]
		if not _is_in_bounds(cell):
			continue
		var ground := _ground_rect(cell.x, cell.y, origin)
		var dest := _actor_rect(ground, NPC_W, NPC_H)
		var dir: int = int(citizen.get("dir", 0))
		var frame: int = int(citizen.get("walk_frame", 0))
		_draw_tile_world(dest, TileLibrary.citizen_tex(dir, frame), cell)
		var emote_name := str(citizen.get("emote", ""))
		if not emote_name.is_empty():
			var bubble := Rect2(
				Vector2(dest.position.x + dest.size.x * 0.2, dest.position.y - _cell_size * EMOTE_W),
				Vector2(_cell_size * EMOTE_W, _cell_size * EMOTE_W)
			)
			var bubble_screen := _world_to_screen_rect(bubble.grow(1.0))
			draw_rect(bubble_screen, Color(0.05, 0.05, 0.08, 0.55), true)
			_draw_tile_world(bubble, TileLibrary.emote_tex(emote_name), cell)


func _draw_tile_world(rect: Rect2, texture: Texture2D, cell: Vector2i, tint: Color = Color.WHITE) -> void:
	var screen_rect := _world_to_screen_rect(rect)
	var dof := _dof_strength(cell)
	var m := tint * day_modulate()
	m = m.darkened(dof * 0.32)
	m.a *= 1.0 - dof * 0.28
	if texture == null:
		draw_rect(screen_rect, Color(0.2, 0.22, 0.28, m.a), true)
		return
	if dof > 0.06:
		var blur := dof * (1.1 + view_zoom * 0.55)
		var soft := Color(m.r, m.g, m.b, m.a * 0.18)
		for offset in [
			Vector2(blur, 0),
			Vector2(-blur, 0),
			Vector2(0, blur * 0.85),
			Vector2(0, -blur * 0.85),
			Vector2(blur * 0.65, blur * 0.65),
			Vector2(-blur * 0.65, -blur * 0.65),
			Vector2(blur * 0.65, -blur * 0.65),
			Vector2(-blur * 0.65, blur * 0.65),
		]:
			draw_texture_rect(texture, Rect2(screen_rect.position + offset, screen_rect.size), false, soft)
	draw_texture_rect(texture, screen_rect, false, m)


func _draw_tile(rect: Rect2, texture: Texture2D, tint: Color = Color.WHITE) -> void:
	# Legacy helper for non-world-space draws (unused by main path).
	if texture == null:
		draw_rect(rect, Color(0.2, 0.22, 0.28), true)
		return
	draw_texture_rect(texture, rect, false, tint)


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
		town_chatter.emit("The streets emptied.")
	if vehicle_sim != null:
		vehicle_sim.clear()
	queue_redraw()

func generate_board_shape(p_seed: int = -1) -> void:
	shape_seed = randi() if p_seed < 0 else p_seed
	_generate_land_mask(shape_seed)
	_generate_terrain_features(shape_seed)
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
	queue_redraw()


func undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(_clone_state())
	_restore_state(undo_stack.pop_back())
	_emit_history_changed()
	queue_redraw()


func redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(_clone_state())
	_restore_state(redo_stack.pop_back())
	_emit_history_changed()
	queue_redraw()


func can_undo() -> bool:
	return not undo_stack.is_empty()


func can_redo() -> bool:
	return not redo_stack.is_empty()


func toggle_drag_rotation() -> void:
	if not get_viewport().gui_is_dragging():
		return
	var old_rotated := active_drag_rotated
	active_drag_rotated = not active_drag_rotated
	ghost_rotated = active_drag_rotated
	if ghost_type != BuildingType.NONE and _is_in_bounds(hovered_cell):
		hovered_cell = _anchor_after_rotation(hovered_cell, ghost_type, old_rotated, ghost_rotated)
		ghost_valid = _is_footprint_valid(hovered_cell, ghost_type, ghost_rotated)
	queue_redraw()


func set_gamepad_selection(building_type: BuildingType) -> void:
	gamepad_active = true
	ghost_type = building_type
	if not _is_footprint_valid(hovered_cell, ghost_type, ghost_rotated):
		hovered_cell = _find_nearest_valid_placement(hovered_cell, ghost_type, ghost_rotated)
	ghost_valid = _is_footprint_valid(hovered_cell, ghost_type, ghost_rotated)
	hover_info_cell = Vector2i(-999, -999)
	queue_redraw()


func rotate_gamepad_selection() -> void:
	if ghost_type == BuildingType.NONE:
		return
	gamepad_active = true
	var old_rotated := ghost_rotated
	ghost_rotated = not ghost_rotated
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
	if ghost_type == BuildingType.NONE:
		return
	gamepad_active = true
	if not _is_footprint_valid(hovered_cell, ghost_type, ghost_rotated):
		return
	_push_undo_snapshot()
	_stamp_building(hovered_cell.x, hovered_cell.y, ghost_type, ghost_rotated)
	ghost_valid = _is_footprint_valid(hovered_cell, ghost_type, ghost_rotated)


func erase_gamepad_cell() -> void:
	gamepad_active = true
	erase_stroke_started = false
	last_erase_cell = Vector2i(-999, -999)
	if _is_buildable(hovered_cell):
		_try_erase(hovered_cell)
	erase_stroke_started = false


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


static func type_outer_radius(building_type: BuildingType, rotated: bool = false) -> int:
	var footprint := type_footprint(building_type, rotated)
	return mini(footprint.x, footprint.y)


static func recipe_list() -> Array[Dictionary]:
	return OVERLAP_RECIPES


static func terrain_name(terrain: TerrainType) -> String:
	match terrain:
		TerrainType.WATER:
			return "Water Reservoir"
		TerrainType.MOUNTAIN:
			return "Mountain"
		TerrainType.RUINS:
			return "Ancient Ruins"
		_:
			return "Open Land"


static func terrain_list() -> Array[Dictionary]:
	return [
		{"type": TerrainType.WATER, "name": "Water Reservoir", "desc": "Unplayable · Harbor & Warehouse must touch water", "color": TERRAIN_COLORS[TerrainType.WATER]},
		{"type": TerrainType.MOUNTAIN, "name": "Mountain", "desc": "Unplayable · Hotel can touch mountains · Farm cannot", "color": TERRAIN_COLORS[TerrainType.MOUNTAIN]},
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
	outer_influences.clear()
	terrain_influences.clear()
	building_radii.clear()
	next_building_id = 1
	for y in GRID_HEIGHT:
		var inner_row: Array = []
		var id_row: Array = []
		var land_row: Array = []
		var terrain_row: Array = []
		var outer_row: Array = []
		var terrain_inf_row: Array = []
		for x in GRID_WIDTH:
			inner_row.append(BuildingType.NONE)
			id_row.append(0)
			land_row.append(true)
			terrain_row.append(TerrainType.OPEN)
			outer_row.append(_make_empty_influence_counts())
			terrain_inf_row.append(_make_empty_terrain_influences())
		inner_cells.append(inner_row)
		building_ids.append(id_row)
		land_mask.append(land_row)
		terrain_cells.append(terrain_row)
		outer_influences.append(outer_row)
		terrain_influences.append(terrain_inf_row)


func _generate_land_mask(p_seed: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = p_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.085
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3

	var center := Vector2(GRID_WIDTH * 0.5, GRID_HEIGHT * 0.5)
	var max_dist := center.length()

	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			var pos := Vector2(x + 0.5, y + 0.5)
			var radial := 1.0 - (pos.distance_to(center) / max_dist)
			var n := noise.get_noise_2d(float(x), float(y)) # -1..1
			var score := radial * 1.15 + n * 0.45
			land_mask[y][x] = score > 0.42

	_ensure_connected_landmass()


func _generate_terrain_features(p_seed: int) -> void:
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			terrain_cells[y][x] = TerrainType.OPEN

	var water_noise := FastNoiseLite.new()
	water_noise.seed = p_seed + 17
	water_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	water_noise.frequency = 0.12

	var mountain_noise := FastNoiseLite.new()
	mountain_noise.seed = p_seed + 91
	mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mountain_noise.frequency = 0.11

	var ruins_noise := FastNoiseLite.new()
	ruins_noise.seed = p_seed + 53
	ruins_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	ruins_noise.frequency = 0.18

	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			if not land_mask[y][x]:
				continue
			var wn := water_noise.get_noise_2d(float(x), float(y))
			var mn := mountain_noise.get_noise_2d(float(x), float(y))
			var rn := ruins_noise.get_noise_2d(float(x), float(y))

			# Priority: water lakes, then mountains, then sparse ruins.
			if wn > 0.48:
				terrain_cells[y][x] = TerrainType.WATER
			elif mn > 0.52:
				terrain_cells[y][x] = TerrainType.MOUNTAIN
			elif rn > 0.62:
				terrain_cells[y][x] = TerrainType.RUINS

	_grow_feature_blobs(TerrainType.WATER, 1)
	_grow_feature_blobs(TerrainType.MOUNTAIN, 1)
	_ensure_connected_buildable_land()
	_fill_void_as_terrain(p_seed)


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


func _stamp_building(start_x: int, start_y: int, building_type: BuildingType, rotated: bool) -> void:
	if building_type == BuildingType.NONE:
		return

	var building_id := next_building_id
	next_building_id += 1
	var footprint := type_footprint(building_type, rotated)
	building_radii[building_id] = mini(footprint.x, footprint.y)

	for dy in footprint.y:
		for dx in footprint.x:
			var tx := start_x + dx
			var ty := start_y + dy
			if not _is_buildable(Vector2i(tx, ty)):
				continue
			inner_cells[ty][tx] = building_type
			building_ids[ty][tx] = building_id

	_recalculate_outer_influences()
	if citizen_sim != null:
		citizen_sim.on_town_changed(Vector2i(start_x, start_y), building_type, true)
	if vehicle_sim != null:
		vehicle_sim.on_town_changed(Vector2i(start_x, start_y), building_type, true)
	queue_redraw()


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
	if erased_id != 0 and not _building_id_exists(erased_id):
		building_radii.erase(erased_id)
	_recalculate_outer_influences()
	if citizen_sim != null:
		citizen_sim.on_town_changed(cell, erased_type, false)
	if vehicle_sim != null:
		vehicle_sim.on_town_changed(cell, erased_type, false)
	queue_redraw()


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


func _draw_ghost_preview(origin: Vector2) -> void:
	if ghost_type == BuildingType.NONE or not _is_in_bounds(hovered_cell):
		return

	var footprint := type_footprint(ghost_type, ghost_rotated)
	var radius := type_outer_radius(ghost_type, ghost_rotated)
	var valid_mod := Color(1, 1, 1, 0.55)
	var invalid_mod := Color(1, 0.35, 0.35, 0.5)
	var outer_mod := Color(1, 1, 1, 0.28) if ghost_valid else Color(1, 0.35, 0.35, 0.22)

	for dy in range(-radius, footprint.y + radius):
		for dx in range(-radius, footprint.x + radius):
			var tx := hovered_cell.x + dx
			var ty := hovered_cell.y + dy
			var cell := Vector2i(tx, ty)
			if not _is_in_bounds(cell):
				continue

			var is_inner := dx >= 0 and dx < footprint.x and dy >= 0 and dy < footprint.y
			var dist := _chebyshev_to_rect(tx, ty, hovered_cell, footprint)
			if not is_inner and dist > radius:
				continue
			if not is_inner and not _is_buildable(cell):
				continue

			var cell_rect := _ground_rect(tx, ty, origin)
			if is_inner:
				if ghost_type == BuildingType.ROAD:
					_draw_tile_world(
						cell_rect,
						TileLibrary.road_auto_tex(_road_mask(cell)),
						cell,
						valid_mod if ghost_valid else invalid_mod
					)
				else:
					_draw_tile_world(
						cell_rect,
						TileLibrary.sidewalk_tex((tx + ty) % 2),
						cell,
						valid_mod if ghost_valid else invalid_mod
					)
			else:
				_draw_tile_world(cell_rect, TileLibrary.influence_tex(ghost_type), cell, outer_mod)

			var border_alpha := (0.9 if is_inner else 0.45)
			var border_color := Color(1, 1, 1, border_alpha) if ghost_valid else Color(1, 0.3, 0.3, border_alpha)
			var screen_rect := _world_to_screen_rect(cell_rect)
			draw_rect(screen_rect, Color(0, 0, 0, border_alpha), false, 3.0 if is_inner else 2.0)
			draw_rect(screen_rect, border_color, false, 2.0 if is_inner else 1.0)

	# One ghost facade spanning the footprint (matches placed buildings).
	if ghost_type != BuildingType.ROAD:
		var bounds := Rect2i(hovered_cell.x, hovered_cell.y, footprint.x, footprint.y)
		var facade := _facade_rect(bounds, _building_height_factor(ghost_type), origin)
		_draw_tile_world(
			facade,
			TileLibrary.building_tex(ghost_type, _tile_anim_frame % TileLibrary.building_frame_count(ghost_type)),
			hovered_cell,
			valid_mod if ghost_valid else invalid_mod
		)

	if gamepad_active and _is_in_bounds(hovered_cell):
		var cursor_rect := _world_to_screen_rect(_ground_rect(hovered_cell.x, hovered_cell.y, origin))
		draw_rect(cursor_rect, Color(0, 0, 0, 0.9), false, 4.0)
		draw_rect(cursor_rect, Color(1, 1, 1, 1), false, 2.0)


func _chebyshev_to_rect(tx: int, ty: int, start: Vector2i, footprint: Vector2i) -> int:
	var clamped_x := clampi(tx, start.x, start.x + footprint.x - 1)
	var clamped_y := clampi(ty, start.y, start.y + footprint.y - 1)
	return maxi(absi(tx - clamped_x), absi(ty - clamped_y))


func _update_hover_tooltip(mouse_position: Vector2) -> void:
	if get_viewport().gui_is_dragging():
		tooltip_text = ""
		return

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
