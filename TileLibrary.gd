class_name TileLibrary
extends RefCounted

## Bakes 16x16 nearest-neighbor pixel tiles for terrain, buildings, and recipes.

const TILE := 16
const TEX_SCALE := 2 ## Ground/actor bakes upscale for sharper zoom.
const ACTOR_W := 20
const ACTOR_H := 28 ## Compact readable walker.
const FACADE_W := 48
const FACADE_H := 80 ## Wider/taller street walls for readable storefronts.
const ANIM_FPS := 14.0
const WATER_FRAMES := 16
const WALK_FRAMES := 8
const PROP_FRAMES := 4
const BAKE_VERSION := 11
const VEHICLE_W := 40
const VEHICLE_H := 24
const CITIZEN_OUTFITS := 6

enum PropKind {
	LAMP,
	HYDRANT,
	TRASH,
	NEWSSTAND,
	BUS_STOP,
}

## Beat Cop–leaning urban palette (warm brick, dirty asphalt, neon accents).
const C_OUTLINE := Color("1a1c24")
const C_GRASS := Color("3d8f4a")
const C_GRASS_DK := Color("2d6b38")
const C_GRASS_LT := Color("5cb86a")
const C_DIRT := Color("6b5340")
const C_SAND := Color("c4a86a")
const C_STONE := Color("7a756c")
const C_STONE_DK := Color("5a564e")
const C_STONE_LT := Color("9a958c")
const C_WATER_1 := Color("2a6f9e")
const C_WATER_2 := Color("3480b0")
const C_WATER_3 := Color("3d8fbf")
const C_WATER_4 := Color("2f78a8")
const C_WATER_HL := Color("7ec8e8")
const C_ROOF_RED := Color("c4453a")
const C_ROOF_BLUE := Color("3f6aaa")
const C_ROOF_TEAL := Color("2a9a9a")
const C_WALL := Color("e8dcc8")
const C_WALL_DK := Color("c8bca8")
const C_WOOD := Color("8a6238")
const C_SMOKE := Color("c8c8d0")
const C_GOLD := Color("e0b040")
const C_PINK := Color("e8789a")
const C_PURPLE := Color("9a5ac8")
const C_WHITE := Color("f0f4f8")
const C_BLACK := Color("12141a")
const C_SIDEWALK := Color("8a8e96")
const C_SIDEWALK_DK := Color("6a6e76")
const C_SIDEWALK_LT := Color("a4a8b0")
const C_FACADE_TRIM := Color("2a2c34")
const C_BRICK := Color("9a5a48")
const C_BRICK_DK := Color("7a4034")
const C_BRICK_LT := Color("b87060")
const C_ASPHALT := Color("4a4e56")
const C_ASPHALT_DK := Color("3a3e46")
const C_NEON := Color("40e0c0")
const C_AWNING_R := Color("c4453a")
const C_AWNING_Y := Color("e0b040")

static var _baked := false
static var _bake_version_loaded := -1
static var _open: Texture2D
static var _open_variants: Array = [] # Array[Texture2D]
static var _sidewalk: Array = [] # Array[Texture2D]
static var _buildings: Dictionary = {} # BuildingType -> Array[Texture2D]
static var _terrain: Dictionary = {} # TerrainType -> Array[Texture2D]
static var _recipes: Dictionary = {} # String -> Texture2D
static var _influence: Dictionary = {} # BuildingType -> Texture2D
static var _citizens: Dictionary = {} # dir -> Array[Texture2D] (2 walk frames)
static var _emotes: Dictionary = {} # name -> Texture2D
static var _water_auto: Dictionary = {} # mask -> Array[Texture2D]
static var _mountain_auto: Dictionary = {} # mask -> Texture2D
static var _ruins_auto: Dictionary = {} # mask -> Array[Texture2D]
static var _road_auto: Dictionary = {} # mask -> Texture2D (legacy fallback)
static var _road_styled: Dictionary = {} # packed key -> Texture2D
static var _vehicles: Dictionary = {} # kind -> Array[Array[Texture2D]] dir -> frames
static var _props: Dictionary = {} # PropKind -> Texture2D
static var _doors: Array = [] # [closed, open]
static var _side_wall: Texture2D

## 4-neighbor bitmask: N=1 E=2 S=4 W=8
const MASK_N := 1
const MASK_E := 2
const MASK_S := 4
const MASK_W := 8

enum VehicleKind {
	CAR,
	BIKE,
	BUS,
}


static func ensure_ready() -> void:
	if _baked and _bake_version_loaded == BAKE_VERSION:
		return
	_bake_all()
	_baked = true
	_bake_version_loaded = BAKE_VERSION


static func anim_frame(frame_count: int = 4) -> int:
	if frame_count <= 1:
		return 0
	return int(Time.get_ticks_msec() / 1000.0 * ANIM_FPS) % frame_count


static func open_tex(variant: int = 0) -> Texture2D:
	ensure_ready()
	if _open_variants.is_empty():
		return _open
	return _open_variants[posmod(variant, _open_variants.size())]


static func sidewalk_tex(variant: int = 0) -> Texture2D:
	ensure_ready()
	if _sidewalk.is_empty():
		return _open
	return _sidewalk[posmod(variant, _sidewalk.size())]


static func building_tex(building_type: Board.BuildingType, frame: int = -1) -> Texture2D:
	ensure_ready()
	var frames: Array = _buildings.get(building_type, [])
	if frames.is_empty():
		return _open
	if frame < 0:
		frame = anim_frame(frames.size())
	return frames[clampi(frame, 0, frames.size() - 1)]


static func building_frame_count(building_type: Board.BuildingType) -> int:
	ensure_ready()
	var frames: Array = _buildings.get(building_type, [])
	return maxi(frames.size(), 1)


static func terrain_tex(terrain: Board.TerrainType, frame: int = -1) -> Texture2D:
	ensure_ready()
	if terrain == Board.TerrainType.OPEN:
		return _open
	var frames: Array = _terrain.get(terrain, [])
	if frames.is_empty():
		return _open
	if frame < 0:
		frame = anim_frame(frames.size())
	return frames[clampi(frame, 0, frames.size() - 1)]


static func terrain_frame_count(terrain: Board.TerrainType) -> int:
	ensure_ready()
	if terrain == Board.TerrainType.OPEN:
		return 1
	var frames: Array = _terrain.get(terrain, [])
	return maxi(frames.size(), 1)


static func water_auto_tex(mask: int, frame: int = 0) -> Texture2D:
	ensure_ready()
	var frames: Array = _water_auto.get(mask & 15, _terrain.get(Board.TerrainType.WATER, []))
	if frames.is_empty():
		return _open
	return frames[posmod(frame, frames.size())]


static func mountain_auto_tex(mask: int) -> Texture2D:
	ensure_ready()
	return _mountain_auto.get(mask & 15, terrain_tex(Board.TerrainType.MOUNTAIN, 0))


static func ruins_auto_tex(mask: int, frame: int = 0) -> Texture2D:
	ensure_ready()
	var frames: Array = _ruins_auto.get(mask & 15, _terrain.get(Board.TerrainType.RUINS, []))
	if frames.is_empty():
		return _open
	return frames[posmod(frame, frames.size())]


static func road_auto_tex(mask: int) -> Texture2D:
	ensure_ready()
	return _road_auto.get(mask & 15, building_tex(Board.BuildingType.ROAD, 0))


## style: 0 one-way, 1 two-way, 2 crossing, 3 roundabout, 4 corner
## flow: 0=S 1=W 2=E 3=N ; lane_side: -1/0/1
static func road_style_tex(mask: int, style: int, flow: int = -1, lane_side: int = -1) -> Texture2D:
	ensure_ready()
	var key := _road_style_key(mask, style, flow, lane_side)
	if _road_styled.has(key):
		return _road_styled[key]
	return road_auto_tex(mask)


static func _road_style_key(mask: int, style: int, flow: int, lane_side: int) -> int:
	return (mask & 15) | ((clampi(style, 0, 7) & 7) << 4) | ((clampi(flow + 1, 0, 4) & 7) << 7) | ((clampi(lane_side + 1, 0, 2) & 3) << 10)


static func vehicle_tex(kind: VehicleKind, dir: int, frame: int = 0) -> Texture2D:
	ensure_ready()
	var dirs: Array = _vehicles.get(kind, [])
	if dirs.is_empty():
		return _open
	var frames: Array = dirs[clampi(dir, 0, dirs.size() - 1)]
	if frames.is_empty():
		return _open
	return frames[posmod(frame, frames.size())]


static func recipe_tex(recipe_id: String) -> Texture2D:
	ensure_ready()
	if _recipes.has(recipe_id):
		return _recipes[recipe_id]
	return _open


static func influence_tex(building_type: Board.BuildingType) -> Texture2D:
	ensure_ready()
	if _influence.has(building_type):
		return _influence[building_type]
	return _open


## dir: 0=down, 1=left, 2=right, 3=up
static func citizen_tex(dir: int, frame: int = -1, outfit: int = 0) -> Texture2D:
	ensure_ready()
	var outfits: Array = _citizens.get(clampi(dir, 0, 3), [])
	if outfits.is_empty():
		return _open
	var frames: Array = outfits[clampi(outfit, 0, outfits.size() - 1)]
	if frames.is_empty():
		return _open
	if frame < 0:
		frame = anim_frame(frames.size())
	return frames[clampi(frame, 0, frames.size() - 1)]


static func emote_tex(emote_name: String) -> Texture2D:
	ensure_ready()
	if _emotes.has(emote_name):
		return _emotes[emote_name]
	return _emotes.get("!", _open)


static func prop_tex(kind: PropKind) -> Texture2D:
	ensure_ready()
	return _props.get(kind, _open)


static func door_tex(open: bool = false) -> Texture2D:
	ensure_ready()
	if _doors.size() < 2:
		return _open
	return _doors[1 if open else 0]


static func side_wall_tex() -> Texture2D:
	ensure_ready()
	return _side_wall if _side_wall != null else _open


static func _bake_all() -> void:
	_open_variants = [
		_tex(_bake_open(0)),
		_tex(_bake_open(1)),
		_tex(_bake_open(2)),
		_tex(_bake_open(3)),
	]
	_open = _open_variants[0]
	_sidewalk = [_tex(_bake_sidewalk(0)), _tex(_bake_sidewalk(1))]

	_water_auto.clear()
	_mountain_auto.clear()
	_ruins_auto.clear()
	_road_auto.clear()
	_road_styled.clear()
	for mask in 16:
		var water_frames: Array = []
		for frame in WATER_FRAMES:
			water_frames.append(_tex(_bake_water_mask(mask, frame)))
		_water_auto[mask] = water_frames
		_mountain_auto[mask] = _tex(_bake_mountain_mask(mask))
		var ruin_frames: Array = []
		for frame in PROP_FRAMES:
			ruin_frames.append(_tex(_bake_ruins_mask(mask, frame)))
		_ruins_auto[mask] = ruin_frames
		_road_auto[mask] = _tex(_bake_road_mask(mask))

	_terrain[Board.TerrainType.WATER] = _water_auto[15]
	_terrain[Board.TerrainType.MOUNTAIN] = [_mountain_auto[0]]
	_terrain[Board.TerrainType.RUINS] = _ruins_auto[0]

	_buildings[Board.BuildingType.PARK] = [_tex(_bake_park())]
	var factory_frames: Array = []
	var harbor_frames: Array = []
	for frame in PROP_FRAMES:
		factory_frames.append(_tex(_bake_factory(frame)))
		harbor_frames.append(_tex(_bake_harbor(frame)))
	_buildings[Board.BuildingType.FACTORY] = factory_frames
	_buildings[Board.BuildingType.ROAD] = [_road_auto[10]] # E+W default
	_buildings[Board.BuildingType.OFFICE] = [_tex(_bake_office())]
	_buildings[Board.BuildingType.SKYSCRAPER] = [
		_tex(_bake_skyscraper(0)),
		_tex(_bake_skyscraper(1)),
		_tex(_bake_skyscraper(2)),
		_tex(_bake_skyscraper(3)),
	]
	_buildings[Board.BuildingType.DOWNTOWN] = [_tex(_bake_downtown())]
	_buildings[Board.BuildingType.SHOPS] = [_tex(_bake_shops())]
	_buildings[Board.BuildingType.RESIDENTIAL] = [_tex(_bake_house())]
	_buildings[Board.BuildingType.SCHOOL] = [_tex(_bake_school())]
	_buildings[Board.BuildingType.HOSPITAL] = [_tex(_bake_hospital())]
	_buildings[Board.BuildingType.FARM] = [_tex(_bake_farm())]
	_buildings[Board.BuildingType.HARBOR] = harbor_frames
	_buildings[Board.BuildingType.STADIUM] = [_tex(_bake_stadium())]
	_buildings[Board.BuildingType.WAREHOUSE] = [_tex(_bake_warehouse())]
	_buildings[Board.BuildingType.HOTEL] = [_tex(_bake_hotel())]
	_buildings[Board.BuildingType.MARKET] = [_tex(_bake_market())]

	for building_type in _buildings.keys():
		_influence[building_type] = _tex(_bake_influence(building_type as Board.BuildingType))

	_recipes["park_park"] = _tex(_bake_recipe_forest())
	_recipes["factory_road"] = _tex(_bake_recipe_parking())
	_recipes["office_shops"] = _tex(_bake_recipe_commercial())
	_recipes["downtown_skyscraper"] = _tex(_bake_recipe_city_core())
	_recipes["residential_park"] = _tex(_bake_recipe_playground())
	_recipes["residential_shops"] = _tex(_bake_recipe_corner())
	_recipes["residential_school"] = _tex(_bake_recipe_path())
	_recipes["residential_factory"] = _tex(_bake_recipe_smog())
	_recipes["residential_downtown"] = _tex(_bake_recipe_townhouses())
	_recipes["farm_residential"] = _tex(_bake_recipe_gardens())
	_recipes["farm_market"] = _tex(_bake_recipe_produce())
	_recipes["harbor_shops"] = _tex(_bake_recipe_boardwalk())
	_recipes["harbor_warehouse"] = _tex(_bake_recipe_docks())
	_recipes["harbor_park"] = _tex(_bake_recipe_promenade())
	_recipes["stadium_road"] = _tex(_bake_recipe_event_lot())
	_recipes["stadium_shops"] = _tex(_bake_recipe_entertainment())
	_recipes["hospital_road"] = _tex(_bake_recipe_emergency())
	_recipes["school_park"] = _tex(_bake_recipe_fields())
	_recipes["warehouse_road"] = _tex(_bake_recipe_loading())
	_recipes["hotel_downtown"] = _tex(_bake_recipe_tourist())
	_recipes["office_park"] = _tex(_bake_recipe_plaza())
	_recipes["market_road"] = _tex(_bake_recipe_street_market())
	_recipes["downtown_shops"] = _tex(_bake_recipe_mall())

	_bake_citizens()
	_emotes["heart"] = _tex(_bake_emote_heart())
	_emotes["sweat"] = _tex(_bake_emote_sweat())
	_emotes["anger"] = _tex(_bake_emote_anger())
	_emotes["cheer"] = _tex(_bake_emote_cheer())
	_emotes["!"] = _tex(_bake_emote_bang())
	_emotes["sleep"] = _tex(_bake_emote_sleep())
	_bake_vehicles()
	_bake_props()


static func _bake_citizens() -> void:
	_citizens.clear()
	for dir in 4:
		var outfits: Array = []
		for outfit in CITIZEN_OUTFITS:
			var frames: Array = []
			for frame in WALK_FRAMES:
				frames.append(_tex(_bake_citizen(dir, frame, outfit)))
			outfits.append(frames)
		_citizens[dir] = outfits


static func _outfit_colors(outfit: int) -> Dictionary:
	match posmod(outfit, CITIZEN_OUTFITS):
		1:
			return {"shirt": Color("d4453a"), "pants": Color("2a3040"), "hair": Color("1a1a1a"), "accent": C_GOLD}
		2:
			return {"shirt": Color("e8dcc8"), "pants": Color("3a4560"), "hair": Color("c4a86a"), "accent": C_ROOF_BLUE}
		3:
			return {"shirt": Color("2a9a7a"), "pants": Color("4a3a28"), "hair": Color("6a5040"), "accent": C_WHITE}
		4:
			return {"shirt": Color("7a5ac8"), "pants": Color("2a2e38"), "hair": Color("2a1a10"), "accent": C_PINK}
		5:
			return {"shirt": Color("e0a040"), "pants": Color("4a3a28"), "hair": Color("c8b070"), "accent": C_BRICK}
		_:
			return {"shirt": Color("3f84d6"), "pants": Color("3a4560"), "hair": Color("6a5040"), "accent": C_NEON}


static func _bake_citizen(dir: int, frame: int, outfit: int = 0) -> Image:
	var img := _img_actor()
	img.fill(Color(0, 0, 0, 0))
	var colors := _outfit_colors(outfit)
	var skin := Color("f0c4a0")
	var shirt: Color = colors["shirt"]
	var pants: Color = colors["pants"]
	var hair: Color = colors["hair"]
	var accent: Color = colors["accent"]
	var cycle := [0, 1, 2, 1, 0, -1, -2, -1]
	var stride: int = cycle[posmod(frame, WALK_FRAMES)]
	var bob := 1 if absi(stride) >= 2 else 0
	var y0 := 1 - bob
	var cx := 8
	_rect(img, cx - 3, 26, 7, 2, Color(0, 0, 0, 0.3))
	match dir:
		1: # left
			_rect(img, cx - 2, y0 + 1, 6, 5, hair)
			_rect(img, cx - 2, y0 + 4, 5, 4, skin)
			_px(img, cx - 2, y0 + 6, C_BLACK)
			_rect(img, cx - 3, y0 + 8, 7, 7, shirt)
			_rect(img, cx - 4, y0 + 10 + stride, 2, 4, skin)
			_rect(img, cx + 3, y0 + 10 - stride, 2, 4, shirt.darkened(0.15))
			_rect(img, cx - 2, y0 + 15 + stride, 3, 8, pants)
			_rect(img, cx + 1, y0 + 15 - stride, 3, 8, pants)
			_rect(img, cx - 2, y0 + 23 + mini(stride, 0), 3, 2, C_BLACK)
			_rect(img, cx + 1, y0 + 23 + mini(-stride, 0), 3, 2, C_BLACK)
		2: # right
			_rect(img, cx - 2, y0 + 1, 6, 5, hair)
			_rect(img, cx - 1, y0 + 4, 5, 4, skin)
			_px(img, cx + 2, y0 + 6, C_BLACK)
			_rect(img, cx - 2, y0 + 8, 7, 7, shirt)
			_rect(img, cx + 4, y0 + 10 + stride, 2, 4, skin)
			_rect(img, cx - 3, y0 + 10 - stride, 2, 4, shirt.darkened(0.15))
			_rect(img, cx - 2, y0 + 15 - stride, 3, 8, pants)
			_rect(img, cx + 1, y0 + 15 + stride, 3, 8, pants)
			_rect(img, cx - 2, y0 + 23 + mini(-stride, 0), 3, 2, C_BLACK)
			_rect(img, cx + 1, y0 + 23 + mini(stride, 0), 3, 2, C_BLACK)
		3: # up
			_rect(img, cx - 3, y0 + 1, 8, 6, hair)
			_rect(img, cx - 3, y0 + 8, 8, 7, shirt)
			_rect(img, cx - 4, y0 + 10, 2, 4, skin)
			_rect(img, cx + 4, y0 + 10, 2, 4, skin)
			_rect(img, cx - 3, y0 + 15 + stride, 3, 8, pants)
			_rect(img, cx + 1, y0 + 15 - stride, 3, 8, pants)
			_rect(img, cx - 3, 25, 3, 2, C_BLACK)
			_rect(img, cx + 1, 25, 3, 2, C_BLACK)
		_: # down
			_rect(img, cx - 3, y0 + 1, 8, 3, hair)
			_rect(img, cx - 3, y0 + 3, 8, 5, skin)
			_px(img, cx - 1, y0 + 5, C_BLACK)
			_px(img, cx + 2, y0 + 5, C_BLACK)
			_px(img, cx, y0 + 7, Color("d08070"))
			_rect(img, cx - 3, y0 + 8, 8, 7, shirt)
			_rect(img, cx - 1, y0 + 10, 4, 2, accent)
			_rect(img, cx - 4, y0 + 10 + stride, 2, 5, skin)
			_rect(img, cx + 4, y0 + 10 - stride, 2, 5, skin)
			_rect(img, cx - 3, y0 + 15 + stride, 3, 8, pants)
			_rect(img, cx + 1, y0 + 15 - stride, 3, 8, pants)
			_rect(img, cx - 3, y0 + 23 + mini(stride, 0), 3, 2, C_BLACK)
			_rect(img, cx + 1, y0 + 23 + mini(-stride, 0), 3, 2, C_BLACK)
	return img


static func _bake_emote_heart() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	_px(img, 5, 5, C_PINK)
	_px(img, 6, 4, C_PINK)
	_px(img, 7, 5, C_PINK)
	_px(img, 8, 4, C_PINK)
	_px(img, 9, 5, C_PINK)
	_px(img, 6, 6, C_PINK)
	_px(img, 7, 7, C_PINK)
	_px(img, 8, 6, C_PINK)
	return img


static func _bake_emote_sweat() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	_px(img, 8, 3, C_WATER_HL)
	_px(img, 8, 4, C_WATER_HL)
	_px(img, 7, 5, C_WATER_3)
	return img


static func _bake_emote_anger() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 5, 5, 6, 5, Color("e04040"))
	_px(img, 6, 6, C_WHITE)
	_px(img, 9, 6, C_WHITE)
	_px(img, 7, 8, C_WHITE)
	return img


static func _bake_emote_cheer() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	_px(img, 8, 3, C_GOLD)
	_px(img, 7, 4, C_GOLD)
	_px(img, 9, 4, C_GOLD)
	_px(img, 6, 5, C_GOLD)
	_px(img, 10, 5, C_GOLD)
	return img


static func _bake_emote_bang() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 7, 3, 2, 6, C_GOLD)
	_rect(img, 7, 11, 2, 2, C_GOLD)
	return img


static func _bake_emote_sleep() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	_px(img, 5, 6, C_WATER_HL)
	_px(img, 6, 5, C_WATER_HL)
	_px(img, 8, 4, C_WHITE)
	_px(img, 9, 3, C_WHITE)
	_px(img, 10, 4, C_WHITE)
	return img


static func _bake_vehicles() -> void:
	_vehicles.clear()
	for kind in [VehicleKind.CAR, VehicleKind.BIKE, VehicleKind.BUS]:
		var dirs: Array = []
		for dir in 4:
			var frames: Array = []
			for frame in WALK_FRAMES:
				frames.append(_tex(_bake_vehicle(kind, dir, frame)))
			dirs.append(frames)
		_vehicles[kind] = dirs


static func _img_vehicle() -> Image:
	return Image.create(VEHICLE_W, VEHICLE_H, false, Image.FORMAT_RGBA8)


static func _bake_vehicle(kind: VehicleKind, dir: int, frame: int) -> Image:
	var img := _img_vehicle()
	img.fill(Color(0, 0, 0, 0))
	var body := Color("c8c8c8")
	var cabin := Color("2a4058")
	var glass := Color("7ec8e8")
	var trim := C_GOLD
	var wheel := C_BLACK
	match kind:
		VehicleKind.BIKE:
			body = Color("2a2e38")
			cabin = Color("e8b090")
			trim = C_NEON
		VehicleKind.BUS:
			body = Color("e8b84a")
			cabin = Color("2a5080")
			glass = Color("9ad4f0")
			trim = C_ROOF_RED
		_:
			pass
	var bounce := 1 if frame % 2 == 0 else 0
	var rolling := frame % 2 == 0
	match kind:
		VehicleKind.BUS:
			_bake_bus_shape(img, dir, body, cabin, glass, trim, wheel, bounce, rolling)
		VehicleKind.BIKE:
			_bake_bike_shape(img, dir, body, cabin, trim, wheel, bounce, rolling)
		_:
			_bake_car_shape(img, dir, body, cabin, glass, trim, wheel, bounce, rolling)
	return img


static func _bake_car_shape(
	img: Image, dir: int, body: Color, cabin: Color, glass: Color, trim: Color, wheel: Color, bounce: int, rolling: bool
) -> void:
	match dir:
		1: # left
			_rect(img, 3, 9 + bounce, 32, 8, body)
			_rect(img, 10, 5 + bounce, 18, 6, cabin)
			_rect(img, 12, 6 + bounce, 14, 4, glass)
			_rect(img, 3, 11 + bounce, 5, 4, trim)
			_px(img, 4, 12 + bounce, C_AWNING_Y)
			_rect(img, 8, 17, 5, 4, wheel)
			_rect(img, 26, 17, 5, 4, wheel)
			if rolling:
				_px(img, 9, 18, C_STONE_LT)
				_px(img, 27, 18, C_STONE_LT)
			if bounce == 0:
				_px(img, 36, 13, C_SMOKE)
		2: # right
			_rect(img, 5, 9 + bounce, 32, 8, body)
			_rect(img, 12, 5 + bounce, 18, 6, cabin)
			_rect(img, 14, 6 + bounce, 14, 4, glass)
			_rect(img, 32, 11 + bounce, 5, 4, trim)
			_px(img, 35, 12 + bounce, C_AWNING_Y)
			_rect(img, 8, 17, 5, 4, wheel)
			_rect(img, 26, 17, 5, 4, wheel)
			if rolling:
				_px(img, 9, 18, C_STONE_LT)
				_px(img, 27, 18, C_STONE_LT)
			if bounce == 0:
				_px(img, 3, 13, C_SMOKE)
		3: # up
			_rect(img, 13, 2 + bounce, 14, 16, body)
			_rect(img, 14, 4 + bounce, 12, 6, cabin)
			_rect(img, 15, 5 + bounce, 10, 4, glass)
			_rect(img, 13, 2 + bounce, 14, 2, trim)
			_rect(img, 13, 17, 4, 4, wheel)
			_rect(img, 23, 17, 4, 4, wheel)
		_: # down
			_rect(img, 13, 2 + bounce, 14, 16, body)
			_rect(img, 14, 10 + bounce, 12, 6, cabin)
			_rect(img, 15, 11 + bounce, 10, 4, glass)
			_rect(img, 13, 16 + bounce, 14, 2, trim)
			_px(img, 15, 17 + bounce, C_AWNING_Y)
			_px(img, 24, 17 + bounce, C_AWNING_Y)
			_rect(img, 13, 17, 4, 4, wheel)
			_rect(img, 23, 17, 4, 4, wheel)


static func _bake_bus_shape(
	img: Image, dir: int, body: Color, _cabin: Color, glass: Color, trim: Color, wheel: Color, bounce: int, rolling: bool
) -> void:
	match dir:
		1, 2:
			var x0 := 2 if dir == 1 else 3
			_rect(img, x0, 5 + bounce, 35, 12, body)
			_rect(img, x0 + 2, 6 + bounce, 30, 5, glass)
			for wx in range(x0 + 4, x0 + 30, 5):
				_px(img, wx, 8 + bounce, C_FACADE_TRIM)
			_rect(img, x0 if dir == 1 else x0 + 30, 8 + bounce, 5, 4, trim)
			_rect(img, x0 + 4, 17, 5, 4, wheel)
			_rect(img, x0 + 15, 17, 5, 4, wheel)
			_rect(img, x0 + 26, 17, 5, 4, wheel)
			if rolling:
				_px(img, x0 + 5, 18, C_STONE_LT)
		_:
			_rect(img, 10, 1 + bounce, 20, 18, body)
			_rect(img, 11, 3 + bounce, 18, 14, glass)
			for wy in range(4, 16, 3):
				_px(img, 12, wy + bounce, C_FACADE_TRIM)
				_px(img, 26, wy + bounce, C_FACADE_TRIM)
			_rect(img, 10, 1 + bounce, 20, 2, trim)
			_rect(img, 11, 18, 5, 4, wheel)
			_rect(img, 24, 18, 5, 4, wheel)


static func _bake_bike_shape(
	img: Image, dir: int, body: Color, cabin: Color, trim: Color, wheel: Color, bounce: int, rolling: bool
) -> void:
	match dir:
		1, 2:
			var mid := 14
			_rect(img, mid - 6, 11 + bounce, 12, 3, body)
			_rect(img, mid - 2, 6 + bounce, 4, 6, cabin)
			_px(img, mid - 1, 5 + bounce, Color("2a2e38"))
			_rect(img, mid - 7, 14, 3, 3, wheel)
			_rect(img, mid + 4, 14, 3, 3, wheel)
			if rolling:
				_px(img, mid - 6, 15, trim)
		_:
			_rect(img, 14, 6 + bounce, 4, 8, body)
			_rect(img, 14, 4 + bounce, 4, 3, cabin)
			_px(img, 15, 3 + bounce, Color("2a2e38"))
			_rect(img, 13, 14, 3, 3, wheel)
			_rect(img, 16, 14, 3, 3, wheel)


static func _bake_props() -> void:
	_props.clear()
	_props[PropKind.LAMP] = _tex(_bake_prop_lamp())
	_props[PropKind.HYDRANT] = _tex(_bake_prop_hydrant())
	_props[PropKind.TRASH] = _tex(_bake_prop_trash())
	_props[PropKind.NEWSSTAND] = _tex(_bake_prop_newsstand())
	_props[PropKind.BUS_STOP] = _tex(_bake_prop_bus_stop())
	_doors = [_tex(_bake_door(false)), _tex(_bake_door(true))]
	_side_wall = _tex(_bake_side_wall())


static func _bake_prop_bus_stop() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	# Pole + shelter
	_rect(img, 7, 2, 2, 12, C_STONE_DK)
	_rect(img, 3, 2, 10, 2, Color("3f84d6"))
	_rect(img, 3, 4, 1, 6, Color("3f84d6"))
	_rect(img, 12, 4, 1, 6, Color("3f84d6"))
	_rect(img, 4, 4, 8, 5, Color(0.7, 0.85, 0.95, 0.55))
	_rect(img, 5, 10, 6, 2, C_STONE)
	_px(img, 8, 1, C_ROOF_RED) # route badge
	_rect(img, 4, 14, 8, 2, C_SIDEWALK_DK)
	return img


static func _bake_door(open: bool) -> Image:
	var img := Image.create(16, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if open:
		# Door swung inward — dark opening + edge
		_rect(img, 1, 2, 14, 24, C_BLACK)
		_rect(img, 1, 2, 3, 24, C_WOOD.darkened(0.25))
		_px(img, 3, 14, C_GOLD)
		_outline_rect(img, 1, 2, 14, 24, C_FACADE_TRIM)
	else:
		_rect(img, 2, 2, 12, 24, C_WOOD)
		_outline_rect(img, 2, 2, 12, 24, C_FACADE_TRIM)
		_rect(img, 4, 4, 8, 8, Color("3a4558"))
		_px(img, 11, 16, C_GOLD)
		_px(img, 10, 16, C_GOLD)
	return img


static func _bake_side_wall() -> Image:
	var img := _img_facade()
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 0, 2, FACADE_W, 70, Color("6a655c"))
	for y in range(8, 64, 8):
		_rect(img, 4, y, FACADE_W - 8, 1, Color("5a564e"))
	for x in range(6, FACADE_W - 6, 10):
		for y in range(12, 58, 14):
			_rect(img, x, y, 5, 4, Color("2a3348"))
			_outline_rect(img, x, y, 5, 4, C_FACADE_TRIM)
	_rect(img, 0, 72, FACADE_W, 8, C_SIDEWALK)
	return img


static func _bake_prop_lamp() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 7, 4, 2, 10, C_STONE_DK)
	_rect(img, 5, 2, 6, 3, C_STONE)
	_rect(img, 6, 1, 4, 2, C_AWNING_Y)
	_px(img, 7, 0, C_GOLD)
	_px(img, 8, 0, C_GOLD)
	_rect(img, 6, 14, 4, 2, C_SIDEWALK_DK)
	return img


static func _bake_prop_hydrant() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 6, 8, 4, 6, C_ROOF_RED)
	_rect(img, 5, 10, 2, 2, C_ROOF_RED)
	_rect(img, 9, 10, 2, 2, C_ROOF_RED)
	_rect(img, 7, 6, 2, 3, C_STONE_LT)
	_px(img, 7, 14, C_BLACK)
	_px(img, 8, 14, C_BLACK)
	return img


static func _bake_prop_trash() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 5, 8, 6, 6, C_STONE_DK)
	_rect(img, 5, 7, 6, 2, C_STONE)
	_px(img, 6, 9, C_GRASS_DK)
	_px(img, 9, 11, C_ROOF_RED)
	_px(img, 7, 14, C_BLACK)
	_px(img, 8, 14, C_BLACK)
	return img


static func _bake_prop_newsstand() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 3, 7, 10, 7, C_WOOD)
	_rect(img, 3, 5, 10, 3, C_ROOF_BLUE)
	_rect(img, 4, 8, 3, 4, C_WHITE)
	_rect(img, 9, 8, 3, 4, C_PINK)
	_outline_rect(img, 3, 5, 10, 9, C_FACADE_TRIM)
	_px(img, 4, 14, C_BLACK)
	_px(img, 12, 14, C_BLACK)
	return img


static func _tex(img: Image) -> Texture2D:
	# Upscale small procedural tiles with nearest-neighbor for crisp zoom.
	var w := img.get_width()
	var h := img.get_height()
	if TEX_SCALE > 1 and (
		(w == TILE and h == TILE)
		or (w == ACTOR_W and h == ACTOR_H)
		or (w == VEHICLE_W and h == VEHICLE_H)
	):
		var big := img.duplicate()
		big.resize(w * TEX_SCALE, h * TEX_SCALE, Image.INTERPOLATE_NEAREST)
		return ImageTexture.create_from_image(big)
	return ImageTexture.create_from_image(img)


static func _img() -> Image:
	return Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)


static func _img_actor() -> Image:
	return Image.create(ACTOR_W, ACTOR_H, false, Image.FORMAT_RGBA8)


static func _img_facade() -> Image:
	return Image.create(FACADE_W, FACADE_H, false, Image.FORMAT_RGBA8)


static func _fill(img: Image, color: Color) -> void:
	img.fill(color)


static func _px(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, color)


static func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, color)


static func _outline_rect(img: Image, x: int, y: int, w: int, h: int, color: Color = C_OUTLINE) -> void:
	for xx in range(x, x + w):
		_px(img, xx, y, color)
		_px(img, xx, y + h - 1, color)
	for yy in range(y, y + h):
		_px(img, x, yy, color)
		_px(img, x + w - 1, yy, color)


static func _frame(_image: Image) -> void:
	# Intentionally empty: full-tile outlines read as a grid.
	# Buildings keep local shape outlines via _outline_rect instead.
	pass


static func _bake_open(variant: int = 0) -> Image:
	# Living lot grass with tufts, wear paths, and tiny blooms.
	var img := _img()
	_fill(img, C_GRASS)
	for y in TILE:
		for x in TILE:
			var n := (x + y * 3 + variant * 5) % 7
			if n == 0:
				_px(img, x, y, C_GRASS_DK)
			elif (x * 2 + y + variant) % 11 == 0:
				_px(img, x, y, C_GRASS_LT)
			elif variant == 2 and (x + y * 2) % 13 == 0:
				_px(img, x, y, Color("4a9a55"))
			elif (x + y * 5 + variant) % 17 == 0:
				_px(img, x, y, Color("6bb86a"))
	# Soft worn footpath streaks
	if variant == 1 or variant == 3:
		for i in 5:
			var px := 4 + i + (variant % 2)
			var py := 10 + (i % 3)
			_px(img, px, py, C_DIRT)
			_px(img, px, mini(15, py + 1), Color("5a7a40"))
	# Tiny flower clusters
	if variant % 2 == 0:
		_px(img, 3 + variant, 4, C_PINK)
		_px(img, 10, 7 + variant, C_GOLD)
		_px(img, 12, 3, C_WHITE)
	else:
		_px(img, 3 + variant, 12, C_DIRT)
		_px(img, 4 + variant, 12, C_DIRT)
		_px(img, 8, 5, Color("e8789a"))
	return img


static func _bake_ruins_mask(mask: int, frame: int) -> Image:
	var img := _img()
	_fill(img, C_DIRT)
	for y in TILE:
		for x in TILE:
			if (x * 3 + y + mask) % 8 == 0:
				_px(img, x, y, C_STONE_DK)
	# Pillars / walls grow toward connected neighbors.
	_rect(img, 5, 6, 3, 8, C_STONE)
	_rect(img, 9, 8, 3, 6, C_STONE_DK)
	if (mask & MASK_N) != 0:
		_rect(img, 6, 0, 4, 7, C_STONE)
	if (mask & MASK_S) != 0:
		_rect(img, 5, 10, 6, 6, C_STONE_DK)
	if (mask & MASK_W) != 0:
		_rect(img, 0, 7, 6, 5, C_STONE)
	if (mask & MASK_E) != 0:
		_rect(img, 10, 7, 6, 5, C_STONE_DK)
	# Twinkling relic glints
	if frame % 2 == 1:
		_px(img, 6, 5, C_GOLD)
		_px(img, 11, 9, C_GOLD)
	elif frame == 2:
		_px(img, 7, 4, C_GOLD)
	return img


static func _bake_water_mask(mask: int, frame: int) -> Image:
	var img := _img()
	var abyss := Color("0c2438")
	var deep := Color("163a58")
	var mid_a := Color("1f5a82")
	var mid_b := Color("2a6f9e")
	var mid_c := Color("3488b8")
	var foam := Color("a8dff0")
	var spark := Color("d0f2ff")
	var phase := posmod(frame, WATER_FRAMES)
	var mids: Array[Color] = [
		mid_a, mid_b, mid_c, mid_b, mid_a, Color("246890"), mid_c, mid_b,
		mid_c, mid_a, mid_b, Color("246890"), mid_c, mid_b, mid_a, mid_b,
	]
	var mid: Color = mids[phase]
	_fill(img, mid)
	# Depth bands + caustic-ish noise.
	for y in TILE:
		for x in TILE:
			var wave := posmod(x * 3 + y * 5 + phase * 2, 13)
			var swirl := posmod(x * 7 - y * 4 + phase * 3, 17)
			if wave <= 1:
				_px(img, x, y, deep)
			elif wave == 2:
				_px(img, x, y, abyss)
			elif wave == 6:
				_px(img, x, y, mid_a)
			elif swirl == 0:
				_px(img, x, y, Color("1a4e74"))
			elif swirl == 8:
				_px(img, x, y, mid_c)
	# Traveling sparkle ripples.
	for i in 9:
		var sx := posmod(1 + i * 2 + phase, TILE)
		var sy := posmod(2 + i * 3 + int(phase * 1.5), TILE)
		if ((mask & MASK_N) != 0 or sy > 1) and ((mask & MASK_S) != 0 or sy < 14):
			if ((mask & MASK_W) != 0 or sx > 1) and ((mask & MASK_E) != 0 or sx < 14):
				_px(img, sx, sy, spark if (i + phase) % 3 == 0 else Color("6ec4e0"))
				if (i + phase) % 4 == 0 and sx + 1 < TILE:
					_px(img, sx + 1, sy, foam)
	# Shore foam on exposed edges.
	if (mask & MASK_N) == 0:
		for x in TILE:
			_px(img, x, 0, mid_a)
			if (x + phase) % 2 == 0:
				_px(img, x, 1, foam)
			elif (x + phase) % 3 == 0:
				_px(img, x, 1, Color("7ec8e8"))
			if (x + phase * 2) % 5 == 0:
				_px(img, x, 2, Color("5aa8c8"))
	if (mask & MASK_S) == 0:
		for x in TILE:
			_px(img, x, 15, mid_a)
			if (x + phase) % 2 == 1:
				_px(img, x, 14, foam)
			if (x + phase) % 4 == 0:
				_px(img, x, 13, Color("6ab0c8"))
	if (mask & MASK_W) == 0:
		for y in TILE:
			_px(img, 0, y, mid_a)
			if (y + phase) % 2 == 0:
				_px(img, 1, y, foam)
	if (mask & MASK_E) == 0:
		for y in TILE:
			_px(img, 15, y, mid_a)
			if (y + phase) % 2 == 1:
				_px(img, 14, y, foam)
	return img


static func _bake_mountain_mask(mask: int) -> Image:
	var img := _img()
	_fill(img, C_STONE_DK)
	# Connected mass: plateau body with mottled rock.
	for y in range(2, 14):
		for x in range(2, 14):
			var c := C_STONE if (x + y) % 3 != 0 else C_STONE_DK
			if (x * 5 + y * 3) % 11 == 0:
				c = C_STONE_LT
			_px(img, x, y, c)
	# Peak / snow only on northern exposure (or fully isolated).
	if (mask & MASK_N) == 0:
		for y in range(1, 7):
			var half := maxi(1, 6 - y)
			for x in range(8 - half, 8 + half):
				var c := C_STONE_LT if y < 4 else C_STONE
				if y < 3 and absi(x - 8) < 2:
					c = C_WHITE
				_px(img, x, y, c)
		if mask == 0:
			# Lone peak â€” taller silhouette.
			_px(img, 8, 1, C_WHITE)
			_px(img, 7, 2, C_WHITE)
			_px(img, 9, 2, C_WHITE)
			_px(img, 8, 0, Color("e8eef4"))
	else:
		# Ridge continuing north.
		for x in range(5, 11):
			_px(img, x, 0, C_STONE)
			_px(img, x, 1, C_STONE_LT)
	if (mask & MASK_S) == 0:
		for x in TILE:
			_px(img, x, 14, C_STONE_DK)
			_px(img, x, 15, Color("3a3834"))
		# Cliff striations
		for x in range(3, 13, 2):
			_px(img, x, 13, Color("2e2c28"))
	else:
		for x in range(4, 12):
			_px(img, x, 15, C_STONE)
	if (mask & MASK_W) == 0:
		for y in TILE:
			_px(img, 0, y, Color("3a3834"))
			_px(img, 1, y, C_STONE_DK)
	else:
		for y in range(3, 13):
			_px(img, 0, y, C_STONE)
	if (mask & MASK_E) == 0:
		for y in TILE:
			_px(img, 15, y, Color("3a3834"))
			_px(img, 14, y, C_STONE_DK)
	else:
		for y in range(3, 13):
			_px(img, 15, y, C_STONE)
	return img


static func _bake_road_mask(mask: int) -> Image:
	# Dual-lane asphalt: yellow center dashes, white edge lines, curbs, zebra at junctions.
	var img := _img()
	var has_n := (mask & MASK_N) != 0
	var has_e := (mask & MASK_E) != 0
	var has_s := (mask & MASK_S) != 0
	var has_w := (mask & MASK_W) != 0
	_fill(img, C_ASPHALT)
	for y in TILE:
		for x in TILE:
			if (x * 3 + y * 5 + mask) % 11 == 0:
				_px(img, x, y, C_ASPHALT_DK)
			elif (x + y * 2 + mask) % 17 == 0:
				_px(img, x, y, Color("52565e"))
	var arms := int(has_n) + int(has_e) + int(has_s) + int(has_w)
	var ns := has_n or has_s
	var ew := has_e or has_w
	var yellow := C_AWNING_Y
	var white := C_WHITE
	var zebra := C_SIDEWALK_LT
	if arms >= 3:
		# Intersection plate
		_rect(img, 4, 4, 8, 8, C_ASPHALT_DK)
		if has_n:
			for y in range(0, 4, 2):
				_rect(img, 5, y, 6, 1, zebra)
		if has_s:
			for y in range(12, 16, 2):
				_rect(img, 5, y, 6, 1, zebra)
		if has_w:
			for x in range(0, 4, 2):
				_rect(img, x, 5, 1, 6, zebra)
		if has_e:
			for x in range(12, 16, 2):
				_rect(img, x, 5, 1, 6, zebra)
		# Manhole
		_rect(img, 7, 7, 2, 2, C_STONE_DK)
		_px(img, 7, 7, C_STONE)
		_px(img, 8, 8, C_STONE)
	elif ns and not ew:
		# North-south dual carriageway
		for y in TILE:
			_px(img, 1, y, white)
			_px(img, 14, y, white)
		for y in range(1, 15, 3):
			_rect(img, 7, y, 2, 2, yellow)
		# Lane wear
		for y in range(2, 14, 4):
			_px(img, 4, y, C_ASPHALT_DK)
			_px(img, 11, y, C_ASPHALT_DK)
	elif ew and not ns:
		# East-west dual carriageway
		for x in TILE:
			_px(img, x, 1, white)
			_px(img, x, 14, white)
		for x in range(1, 15, 3):
			_rect(img, x, 7, 2, 2, yellow)
		for x in range(2, 14, 4):
			_px(img, x, 4, C_ASPHALT_DK)
			_px(img, x, 11, C_ASPHALT_DK)
	else:
		# Corner / T stub — curve the centerline
		_rect(img, 5, 5, 6, 6, C_ASPHALT_DK)
		if has_n or has_s:
			for y in range(1, 15, 3):
				_rect(img, 7, y, 2, 1, yellow)
		if has_e or has_w:
			for x in range(1, 15, 3):
				_rect(img, x, 7, 1, 2, yellow)
		_px(img, 7, 7, yellow)
		_px(img, 8, 8, yellow)
	# Concrete curbs on open edges
	if not has_n:
		for x in TILE:
			_px(img, x, 0, C_SIDEWALK)
			_px(img, x, 1, C_SIDEWALK_DK)
	if not has_s:
		for x in TILE:
			_px(img, x, 15, C_SIDEWALK)
			_px(img, x, 14, C_SIDEWALK_DK)
	if not has_w:
		for y in TILE:
			_px(img, 0, y, C_SIDEWALK)
			_px(img, 1, y, C_SIDEWALK_DK)
	if not has_e:
		for y in TILE:
			_px(img, 15, y, C_SIDEWALK)
			_px(img, 14, y, C_SIDEWALK_DK)
	return img


static func _bake_sidewalk(variant: int = 0) -> Image:
	# Slabbed Brooklyn sidewalk with curb lip.
	var img := _img()
	_fill(img, C_SIDEWALK)
	for y in range(0, TILE, 4):
		for x in range(0, TILE, 4):
			var shade := C_SIDEWALK_LT if (int((x + y) / 4.0) + variant) % 2 == 0 else C_SIDEWALK
			_rect(img, x, y, 4, 4, shade)
			_outline_rect(img, x, y, 4, 4, C_SIDEWALK_DK)
	for x in TILE:
		_px(img, x, 15, C_FACADE_TRIM)
		if x % 2 == variant % 2:
			_px(img, x, 14, C_SIDEWALK_DK)
	# Occasional stain / gum
	if variant % 2 == 0:
		_px(img, 5, 7, C_SIDEWALK_DK)
		_px(img, 11, 4, Color("6a5a48"))
	return img


## Transparent street facade: horizontal bands survive vertical stretch (Beat Cop storefronts).
static func _facade_start(wall: Color) -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 0, 1, TILE, 13, wall)
	for y in range(2, 13):
		_px(img, 0, y, C_FACADE_TRIM)
		_px(img, 15, y, C_FACADE_TRIM)
	_rect(img, 0, 14, TILE, 2, C_SIDEWALK)
	_px(img, 0, 14, C_FACADE_TRIM)
	_px(img, 15, 14, C_FACADE_TRIM)
	return img


static func _facade_brick(img: Image, y0: int = 2, y1: int = 7) -> void:
	for y in range(y0, y1):
		for x in range(1, 15):
			var brick := C_BRICK if ((x + (y % 2) * 2) % 4) < 2 else C_BRICK_LT
			if y % 2 == 0 and x % 4 == 0:
				brick = C_BRICK_DK
			_px(img, x, y, brick)
		_px(img, 0, y, C_FACADE_TRIM)
		_px(img, 15, y, C_FACADE_TRIM)


static func _facade_awning(img: Image, y: int = 7, a: Color = C_AWNING_R, b: Color = C_AWNING_Y) -> void:
	for x in range(1, 15):
		_px(img, x, y, a if x % 2 == 0 else b)
		_px(img, x, y + 1, a if x % 2 == 0 else b)
	_px(img, 0, y, C_FACADE_TRIM)
	_px(img, 15, y, C_FACADE_TRIM)


static func _facade_storefront(img: Image, door_x: int = 7) -> void:
	# Big glass panes + recessed door — reads as Beat Cop ground floor.
	_rect(img, 1, 9, 5, 4, Color("6a90a8"))
	_rect(img, 10, 9, 5, 4, Color("6a90a8"))
	_outline_rect(img, 1, 9, 5, 4, C_FACADE_TRIM)
	_outline_rect(img, 10, 9, 5, 4, C_FACADE_TRIM)
	_px(img, 2, 10, C_NEON)
	_px(img, 12, 10, C_GOLD)
	_rect(img, door_x, 10, 2, 4, C_WOOD)
	_px(img, door_x + 1, 12, C_GOLD)


static func _facade_windows(img: Image, rows: Array, cols: Array, lit: Color = C_WATER_HL, dark: Color = Color("2a3348")) -> void:
	for yi in rows.size():
		for xi in cols.size():
			var c := lit if (xi + yi) % 2 == 0 else dark
			_rect(img, int(cols[xi]), int(rows[yi]), 2, 2, c)
			_outline_rect(img, int(cols[xi]), int(rows[yi]), 2, 2, C_FACADE_TRIM)


static func _facade_door(img: Image, x: int = 7, color: Color = C_WOOD) -> void:
	_rect(img, x, 10, 2, 4, color)
	_px(img, x + 1, 12, C_GOLD)


static func _facade_roof_flat(img: Image, color: Color, y: int = 1) -> void:
	_rect(img, 0, y, TILE, 2, color)
	_outline_rect(img, 0, y, TILE, 2, C_FACADE_TRIM)


static func _facade_sign(img: Image, text_color: Color = C_NEON) -> void:
	_rect(img, 3, 6, 10, 2, C_BLACK)
	_px(img, 5, 6, text_color)
	_px(img, 7, 6, text_color)
	_px(img, 9, 6, text_color)
	_px(img, 11, 6, text_color)


static func _bake_park() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 0, 10, TILE, 6, C_GRASS)
	_rect(img, 7, 6, 2, 8, C_WOOD)
	_rect(img, 4, 3, 8, 5, C_GRASS_LT)
	_px(img, 5, 4, C_GRASS_DK)
	_px(img, 10, 5, C_GRASS_DK)
	_px(img, 8, 6, C_GRASS)
	_rect(img, 1, 12, 3, 2, C_SIDEWALK_LT)
	_rect(img, 12, 12, 3, 2, C_SIDEWALK_LT)
	_rect(img, 0, 14, TILE, 2, C_SIDEWALK)
	return img


static func _bake_factory(frame: int) -> Image:
	var img := _facade_start(C_STONE)
	_facade_roof_flat(img, C_STONE_DK, 1)
	_facade_brick(img, 3, 8)
	_rect(img, 3, 0, 3, 4, C_STONE_DK)
	_rect(img, 10, 1, 3, 3, C_STONE_DK)
	var smoke_y := posmod(frame, PROP_FRAMES)
	_px(img, 4, smoke_y, C_SMOKE)
	_px(img, 5, maxi(0, smoke_y - 1), Color("d8d8e0"))
	_px(img, 11, smoke_y, C_SMOKE)
	_facade_windows(img, [4, 6], [2, 6, 11], C_GOLD if frame % 2 == 0 else Color("2a3348"), Color("2a3348"))
	_rect(img, 5, 10, 6, 4, C_BLACK) # loading bay
	_outline_rect(img, 5, 10, 6, 4, C_FACADE_TRIM)
	return img


static func _bake_skyscraper(frame: int = 0) -> Image:
	var img := _facade_start(Color("4a5678"))
	_facade_roof_flat(img, Color("3a4558"), 1)
	_px(img, 8, 0, C_ROOF_RED if frame % 2 == 0 else C_WHITE)
	for y in range(3, 10, 2):
		for x in [2, 5, 8, 11]:
			var lit := (int((x + y) / 2.0) + frame) % 3 != 0
			_rect(img, x, y, 2, 1, C_GOLD if lit else Color("2a3348"))
	_facade_storefront(img, 7)
	return img


static func _bake_harbor(frame: int) -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	var water_phase: Color = [C_WATER_1, C_WATER_2, C_WATER_3, C_WATER_2][posmod(frame, PROP_FRAMES)]
	_rect(img, 0, 10, TILE, 6, water_phase)
	_rect(img, 0, 8, TILE, 3, C_WOOD)
	_outline_rect(img, 0, 8, TILE, 3, Color("5a4028"))
	_rect(img, 2, 3, 6, 6, C_STONE)
	_outline_rect(img, 2, 3, 6, 6, C_FACADE_TRIM)
	_px(img, 10, 6 + (frame % 2), C_WATER_HL)
	_px(img, 13, 7 + posmod(frame, 2), C_WATER_HL)
	return img


static func _bake_office() -> Image:
	var img := _facade_start(Color("5a6a88"))
	_facade_roof_flat(img, Color("3a4a68"), 1)
	_facade_windows(img, [3, 5], [2, 5, 8, 11])
	_facade_awning(img, 7, C_ROOF_BLUE, C_SIDEWALK_LT)
	_facade_storefront(img, 7)
	return img


static func _bake_downtown() -> Image:
	var img := _facade_start(C_BRICK)
	_facade_brick(img, 2, 7)
	_facade_roof_flat(img, C_STONE_DK, 1)
	_facade_sign(img, C_NEON)
	_facade_awning(img, 8, C_AWNING_R, C_AWNING_Y)
	_facade_storefront(img, 7)
	return img


static func _bake_shops() -> Image:
	var img := _facade_start(C_WALL)
	_facade_roof_flat(img, C_GOLD, 1)
	_facade_windows(img, [3], [2, 11], C_GOLD, Color("2a3348"))
	_facade_sign(img, C_GOLD)
	_facade_awning(img, 7, C_AWNING_R, C_WHITE)
	_facade_storefront(img, 7)
	return img


static func _bake_house() -> Image:
	# Brownstone stoop look.
	var img := _facade_start(C_BRICK)
	_facade_brick(img, 2, 9)
	for x in range(0, 16):
		var roof_y := 1 + int(absi(x - 8) / 4.0)
		_px(img, x, roof_y, C_ROOF_RED)
	_facade_windows(img, [4, 6], [2, 11], C_WATER_HL, Color("2a3348"))
	_rect(img, 6, 10, 4, 4, C_WOOD) # stoop door
	_px(img, 8, 12, C_GOLD)
	_rect(img, 5, 13, 6, 1, C_STONE_LT) # stoop step
	return img


static func _bake_school() -> Image:
	var img := _facade_start(C_WALL)
	_facade_roof_flat(img, C_ROOF_TEAL, 1)
	_rect(img, 6, 0, 4, 3, C_ROOF_TEAL)
	_rect(img, 7, 1, 2, 2, C_GOLD)
	_facade_windows(img, [3, 5], [2, 5, 9, 12])
	_facade_awning(img, 7, C_ROOF_TEAL, C_WHITE)
	_facade_door(img, 7, C_WOOD)
	_rect(img, 1, 10, 5, 3, Color("6a90a8"))
	_rect(img, 10, 10, 5, 3, Color("6a90a8"))
	return img


static func _bake_hospital() -> Image:
	var img := _facade_start(C_WHITE)
	_facade_roof_flat(img, Color("d8dee4"), 1)
	_rect(img, 7, 3, 2, 5, Color("e04040"))
	_rect(img, 5, 5, 6, 2, Color("e04040"))
	_facade_windows(img, [3, 8], [2, 12], C_WATER_HL, Color("c8d0d8"))
	_facade_awning(img, 9, C_WHITE, Color("e04040"))
	_facade_door(img, 7, Color("808890"))
	return img


static func _bake_farm() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	_fill(img, C_DIRT)
	for y in range(4, 14, 2):
		_rect(img, 0, y, TILE, 1, C_GRASS_LT)
	_rect(img, 11, 3, 4, 5, C_WOOD)
	_outline_rect(img, 11, 3, 4, 5, C_FACADE_TRIM)
	_rect(img, 0, 14, TILE, 2, C_SIDEWALK_DK)
	return img


static func _bake_stadium() -> Image:
	var img := _facade_start(C_STONE)
	_facade_roof_flat(img, C_STONE_DK, 1)
	_rect(img, 2, 4, 12, 5, C_GRASS_LT)
	_outline_rect(img, 2, 4, 12, 5, C_FACADE_TRIM)
	_px(img, 8, 6, C_PINK)
	_facade_awning(img, 9, C_PINK, C_AWNING_Y)
	_facade_door(img, 7, C_BLACK)
	return img


static func _bake_warehouse() -> Image:
	var img := _facade_start(C_STONE_LT)
	_facade_roof_flat(img, C_STONE_DK, 1)
	_facade_brick(img, 3, 7)
	_rect(img, 5, 8, 6, 6, C_BLACK)
	_outline_rect(img, 5, 8, 6, 6, C_FACADE_TRIM)
	_facade_windows(img, [4], [2, 12], C_GOLD, Color("2a3348"))
	return img


static func _bake_hotel() -> Image:
	var img := _facade_start(Color("6a4a78"))
	_facade_roof_flat(img, Color("7a3aa0"), 1)
	_facade_windows(img, [3, 5], [2, 5, 9, 12], C_GOLD, Color("4a2060"))
	_facade_sign(img, C_GOLD)
	_facade_awning(img, 8, C_PURPLE, C_GOLD)
	_facade_storefront(img, 7)
	_rect(img, 6, 12, 4, 2, C_GOLD) # canopy
	return img


static func _bake_market() -> Image:
	var img := _facade_start(C_WALL_DK)
	_facade_roof_flat(img, Color("e85a3c"), 1)
	_facade_awning(img, 6, C_AWNING_Y, C_AWNING_R)
	_rect(img, 1, 9, 6, 4, C_GOLD)
	_rect(img, 9, 9, 6, 4, C_GRASS_LT)
	_outline_rect(img, 1, 9, 6, 4, C_FACADE_TRIM)
	_outline_rect(img, 9, 9, 6, 4, C_FACADE_TRIM)
	_facade_door(img, 7, C_WOOD)
	return img


static func _bake_road() -> Image:
	return _bake_road_mask(MASK_E | MASK_W)


static func _bake_water(frame: int) -> Image:
	return _bake_water_mask(15, frame)


static func _bake_mountain() -> Image:
	return _bake_mountain_mask(0)


static func _bake_ruins(frame: int) -> Image:
	return _bake_ruins_mask(0, frame)


static func _bake_influence(building_type: Board.BuildingType) -> Image:
	var img := _bake_open()
	var tint: Color = Board.OUTER_SINGLE_COLORS.get(building_type, C_GRASS_LT)
	tint.a = 1.0
	for y in range(1, 15):
		for x in range(1, 15):
			if (x + y) % 2 == 0:
				var mix := img.get_pixel(x, y).lerp(tint, 0.45)
				_px(img, x, y, mix)
	_frame(img)
	return img


static func _bake_recipe_forest() -> Image:
	var img := _bake_open()
	_rect(img, 3, 9, 2, 5, C_WOOD)
	_rect(img, 1, 4, 6, 6, C_GRASS_DK)
	_rect(img, 10, 10, 2, 4, C_WOOD)
	_rect(img, 8, 5, 6, 6, C_GRASS)
	_frame(img)
	return img


static func _bake_recipe_parking() -> Image:
	var img := _img()
	_fill(img, C_STONE_DK)
	_rect(img, 2, 3, 4, 10, C_STONE)
	_rect(img, 8, 3, 4, 10, C_STONE)
	_rect(img, 3, 5, 2, 2, C_ROOF_BLUE)
	_rect(img, 9, 8, 2, 2, C_ROOF_RED)
	_frame(img)
	return img


static func _bake_recipe_commercial() -> Image:
	var img := _img()
	_fill(img, C_GRASS_DK)
	_rect(img, 2, 4, 6, 10, Color("4a7ab8"))
	_rect(img, 9, 7, 5, 7, C_GOLD)
	_outline_rect(img, 2, 4, 6, 10)
	_outline_rect(img, 9, 7, 5, 7)
	_frame(img)
	return img


static func _bake_recipe_city_core() -> Image:
	var img := _img()
	_fill(img, C_STONE_DK)
	_rect(img, 2, 4, 5, 10, Color("4a5678"))
	_rect(img, 8, 1, 5, 13, Color("5a3a78"))
	_outline_rect(img, 2, 4, 5, 10)
	_outline_rect(img, 8, 1, 5, 13)
	_frame(img)
	return img


static func _bake_recipe_playground() -> Image:
	var img := _bake_open()
	_rect(img, 3, 4, 1, 8, C_WOOD)
	_rect(img, 12, 4, 1, 8, C_WOOD)
	_rect(img, 3, 4, 10, 1, C_WOOD)
	_rect(img, 6, 8, 4, 1, C_GOLD)
	_frame(img)
	return img


static func _bake_recipe_corner() -> Image:
	var img := _bake_open()
	_rect(img, 3, 6, 10, 8, C_WALL)
	_rect(img, 3, 4, 10, 3, C_GOLD)
	_outline_rect(img, 3, 6, 10, 8)
	_frame(img)
	return img


static func _bake_recipe_path() -> Image:
	var img := _bake_open()
	for i in 8:
		var y := 10 - int(i / 2.0)
		_px(img, 3 + i, y, C_SAND)
		_px(img, 4 + i, y, C_SAND)
	_frame(img)
	return img


static func _bake_recipe_smog() -> Image:
	var img := _bake_open()
	_rect(img, 2, 8, 5, 6, C_STONE)
	for p in [[6, 4], [8, 3], [10, 5], [9, 7], [12, 4]]:
		_px(img, p[0], p[1], C_SMOKE)
		_px(img, p[0] + 1, p[1] + 1, Color(C_SMOKE.r, C_SMOKE.g, C_SMOKE.b, 0.7))
	_frame(img)
	return img


static func _bake_recipe_townhouses() -> Image:
	var img := _bake_open()
	_rect(img, 2, 7, 5, 7, C_WALL)
	_rect(img, 8, 7, 5, 7, C_WALL_DK)
	_rect(img, 2, 5, 5, 3, C_ROOF_RED)
	_rect(img, 8, 5, 5, 3, C_ROOF_BLUE)
	_frame(img)
	return img


static func _bake_recipe_gardens() -> Image:
	var img := _img()
	_fill(img, C_DIRT)
	for x in range(2, 14, 3):
		_rect(img, x, 4, 2, 8, C_GRASS_LT)
		_px(img, x, 3, C_GRASS)
	_frame(img)
	return img


static func _bake_recipe_produce() -> Image:
	var img := _bake_open()
	_rect(img, 3, 6, 4, 4, C_WOOD)
	_rect(img, 8, 5, 4, 4, C_WOOD)
	_rect(img, 6, 9, 4, 4, C_GOLD)
	_frame(img)
	return img


static func _bake_recipe_boardwalk() -> Image:
	var img := _img()
	_fill(img, C_WATER_2)
	for y in range(4, 13, 3):
		_rect(img, 1, y, 14, 2, C_WOOD)
	_frame(img)
	return img


static func _bake_recipe_docks() -> Image:
	var img := _img()
	_fill(img, C_WATER_1)
	_rect(img, 2, 9, 12, 3, C_WOOD)
	_rect(img, 10, 3, 2, 8, C_STONE)
	_rect(img, 6, 3, 6, 1, C_STONE_LT)
	_frame(img)
	return img


static func _bake_recipe_promenade() -> Image:
	var img := _img()
	_fill(img, C_WATER_3)
	_rect(img, 1, 10, 14, 3, C_WOOD)
	_rect(img, 7, 4, 2, 4, C_WOOD)
	_rect(img, 5, 2, 6, 4, C_GRASS_LT)
	_frame(img)
	return img


static func _bake_recipe_event_lot() -> Image:
	var img := _img()
	_fill(img, C_STONE_DK)
	for y in range(3, 13, 3):
		_rect(img, 2, y, 12, 1, C_STONE)
		_rect(img, 5, y + 1, 6, 1, C_PINK)
	_frame(img)
	return img


static func _bake_recipe_entertainment() -> Image:
	var img := _bake_open()
	_rect(img, 3, 5, 10, 8, C_PINK)
	_outline_rect(img, 3, 5, 10, 8)
	_px(img, 8, 3, C_GOLD)
	_px(img, 7, 4, C_GOLD)
	_px(img, 9, 4, C_GOLD)
	_frame(img)
	return img


static func _bake_recipe_emergency() -> Image:
	var img := _img()
	_fill(img, C_STONE)
	_rect(img, 0, 6, 16, 4, C_WHITE)
	_rect(img, 7, 4, 2, 8, Color("e04040"))
	_rect(img, 5, 7, 6, 2, Color("e04040"))
	_frame(img)
	return img


static func _bake_recipe_fields() -> Image:
	var img := _bake_open()
	_outline_rect(img, 2, 3, 12, 10, C_WHITE)
	_rect(img, 8, 3, 1, 10, C_WHITE)
	_outline_rect(img, 6, 6, 4, 4, C_WHITE)
	_frame(img)
	return img


static func _bake_recipe_loading() -> Image:
	var img := _img()
	_fill(img, C_STONE_DK)
	_rect(img, 2, 5, 7, 8, C_STONE_LT)
	_rect(img, 10, 7, 4, 3, C_GOLD)
	_px(img, 14, 8, C_GOLD)
	_frame(img)
	return img


static func _bake_recipe_tourist() -> Image:
	var img := _bake_open()
	_rect(img, 3, 4, 5, 10, C_PURPLE)
	_rect(img, 9, 6, 5, 8, C_ROOF_RED)
	_rect(img, 5, 2, 3, 2, C_GOLD)
	_frame(img)
	return img


static func _bake_recipe_plaza() -> Image:
	var img := _img()
	_fill(img, C_SAND)
	_outline_rect(img, 2, 2, 12, 12, C_STONE)
	_px(img, 8, 8, C_GRASS_LT)
	_outline_rect(img, 5, 5, 6, 6, C_STONE_LT)
	_frame(img)
	return img


static func _bake_recipe_street_market() -> Image:
	var img := _img()
	_fill(img, C_STONE)
	_rect(img, 2, 4, 5, 4, Color("e85a3c"))
	_rect(img, 9, 6, 5, 4, C_GOLD)
	_rect(img, 5, 10, 6, 3, C_WOOD)
	_frame(img)
	return img


static func _bake_recipe_mall() -> Image:
	var img := _img()
	_fill(img, C_STONE_DK)
	_rect(img, 1, 7, 14, 2, C_SAND)
	_rect(img, 2, 3, 5, 4, C_WALL)
	_rect(img, 9, 3, 5, 4, C_GOLD)
	_frame(img)
	return img
