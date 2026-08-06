class_name TileLibrary
extends RefCounted

## Bakes 16x16 nearest-neighbor pixel tiles for terrain, buildings, and recipes.

const TILE := 16
const ANIM_FPS := 10.0
const WATER_FRAMES := 8
const WALK_FRAMES := 4
const PROP_FRAMES := 4

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
const C_SIDEWALK := Color("7a7e88")
const C_SIDEWALK_DK := Color("5e626c")
const C_SIDEWALK_LT := Color("9498a2")
const C_FACADE_TRIM := Color("2a2c34")

static var _baked := false
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
static var _road_auto: Dictionary = {} # mask -> Texture2D
static var _vehicles: Dictionary = {} # kind -> Array[Array[Texture2D]] dir -> frames

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
	if _baked:
		return
	_bake_all()
	_baked = true


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
static func citizen_tex(dir: int, frame: int = -1) -> Texture2D:
	ensure_ready()
	var frames: Array = _citizens.get(clampi(dir, 0, 3), [])
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
	_bake_vehicles()
	_emotes["heart"] = _tex(_bake_emote_heart())
	_emotes["sweat"] = _tex(_bake_emote_sweat())
	_emotes["anger"] = _tex(_bake_emote_anger())
	_emotes["cheer"] = _tex(_bake_emote_cheer())
	_emotes["!"] = _tex(_bake_emote_bang())
	_emotes["sleep"] = _tex(_bake_emote_sleep())


static func _bake_citizens() -> void:
	for dir in 4:
		var frames: Array = []
		for frame in WALK_FRAMES:
			frames.append(_tex(_bake_citizen(dir, frame)))
		_citizens[dir] = frames


static func _bake_citizen(dir: int, frame: int) -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	var skin := Color("e8b090")
	var shirt := Color("3f84d6") if dir % 2 == 0 else Color("d4453a")
	var pants := Color("3a4560")
	var hair := Color("6a5040")
	# Feet anchored at bottom of 16px canvas so scale matches vehicles/facades.
	var cycle := [0, 1, 0, -1]
	var leg_off: int = cycle[posmod(frame, WALK_FRAMES)]
	var bob := 1 if frame == 1 or frame == 3 else 0
	var base_y := 2 - bob
	_rect(img, 6, 5 + base_y, 4, 5, shirt)
	_rect(img, 6, 3 + base_y, 4, 3, skin)
	_px(img, 7, 4 + base_y, C_BLACK)
	_px(img, 9, 4 + base_y, C_BLACK)
	match dir:
		1: # left
			_rect(img, 5, 6 + base_y, 2, 2, skin)
			_rect(img, 6, 10 + base_y, 2, 4, pants)
			_rect(img, 8, 10 + base_y + leg_off, 2, 4 - absi(leg_off), pants)
			_px(img, 6, 14, C_BLACK)
			_px(img, 9, 14 + mini(leg_off, 0), C_BLACK)
			_rect(img, 6, 2 + base_y, 4, 2, hair)
		2: # right
			_rect(img, 9, 6 + base_y, 2, 2, skin)
			_rect(img, 6, 10 + base_y + leg_off, 2, 4 - absi(leg_off), pants)
			_rect(img, 8, 10 + base_y, 2, 4, pants)
			_px(img, 6, 14 + mini(leg_off, 0), C_BLACK)
			_px(img, 9, 14, C_BLACK)
			_rect(img, 6, 2 + base_y, 4, 2, hair)
		3: # up
			_rect(img, 6, 2 + base_y, 4, 3, hair)
			_rect(img, 6, 10 + base_y, 2, 4, pants)
			_rect(img, 8, 10 + base_y + leg_off, 2, 4 - absi(leg_off), pants)
			_px(img, 6, 14, C_BLACK)
			_px(img, 9, 14 + mini(leg_off, 0), C_BLACK)
		_: # down
			_rect(img, 6, 2 + base_y, 4, 2, hair)
			_rect(img, 6, 10 + base_y, 2, 4 - absi(leg_off), pants)
			_rect(img, 8, 10 + base_y + leg_off, 2, 4 - absi(leg_off), pants)
			_px(img, 7, 14, C_BLACK)
			_px(img, 9, 14 + mini(leg_off, 0), C_BLACK)
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


static func _bake_vehicle(kind: VehicleKind, dir: int, frame: int) -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	var body := Color("d4453a")
	var accent := C_GOLD
	match kind:
		VehicleKind.BIKE:
			body = Color("2a2e38")
			accent = C_WATER_HL
		VehicleKind.BUS:
			body = Color("3f84d6")
			accent = C_GOLD
		_:
			body = Color("d4453a") if dir % 2 == 0 else Color("e09a28")
	var bob: int = [0, 1, 0, 1][posmod(frame, WALK_FRAMES)]
	# Wheels sit on the bottom row so ground baseline matches NPCs.
	match dir:
		1: # left
			_rect(img, 2, 8 + bob, 12, 5, body)
			_rect(img, 2, 9 + bob, 3, 2, accent)
			_px(img, 4, 14, C_BLACK)
			_px(img, 5, 14, C_BLACK)
			_px(img, 11, 14, C_BLACK)
			_px(img, 12, 14, C_BLACK)
			if frame % 2 == 0:
				_px(img, 1, 10 + bob, C_WATER_HL)
		2: # right
			_rect(img, 2, 8 + bob, 12, 5, body)
			_rect(img, 11, 9 + bob, 3, 2, accent)
			_px(img, 4, 14, C_BLACK)
			_px(img, 5, 14, C_BLACK)
			_px(img, 11, 14, C_BLACK)
			_px(img, 12, 14, C_BLACK)
			if frame % 2 == 0:
				_px(img, 14, 10 + bob, C_WATER_HL)
		3: # up
			_rect(img, 5, 3 + bob, 6, 11, body)
			_rect(img, 5, 3 + bob, 6, 2, accent)
			_px(img, 5, 14, C_BLACK)
			_px(img, 6, 14, C_BLACK)
			_px(img, 9, 14, C_BLACK)
			_px(img, 10, 14, C_BLACK)
		_: # down
			_rect(img, 5, 3 + bob, 6, 11, body)
			_rect(img, 5, 12 + bob, 6, 2, accent)
			_px(img, 5, 14, C_BLACK)
			_px(img, 6, 14, C_BLACK)
			_px(img, 9, 14, C_BLACK)
			_px(img, 10, 14, C_BLACK)
	if kind == VehicleKind.BUS:
		match dir:
			1, 2:
				_rect(img, 2, 7 + bob, 12, 6, body)
				for wx in range(4, 13, 2):
					_px(img, wx, 9 + bob, C_WATER_HL)
			_:
				_rect(img, 4, 2 + bob, 8, 12, body)
				for wy in range(4, 12, 2):
					_px(img, 5, wy + bob, C_WATER_HL)
					_px(img, 10, wy + bob, C_WATER_HL)
	elif kind == VehicleKind.BIKE:
		match dir:
			1, 2:
				_rect(img, 4, 9 + bob, 8, 3, body)
				_px(img, 4, 14, C_BLACK)
				_px(img, 11, 14, C_BLACK)
			_:
				_rect(img, 7, 5 + bob, 2, 8, body)
				_px(img, 7, 14, C_BLACK)
				_px(img, 8, 14, C_BLACK)
	return img


static func _tex(img: Image) -> Texture2D:
	var texture := ImageTexture.create_from_image(img)
	return texture


static func _img() -> Image:
	return Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)


static func _fill(img: Image, color: Color) -> void:
	img.fill(color)


static func _px(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= TILE or y >= TILE:
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
				_px(img, x, y, Color("6bb86a")) # tiny flower/tuft
	# Soft dirt patches for variety
	if variant % 2 == 1:
		_px(img, 3 + variant, 12, C_DIRT)
		_px(img, 4 + variant, 12, C_DIRT)
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
	var deep := Color("1e4f72")
	var mid_a := Color("2a6f9e")
	var mid_b := Color("3480b0")
	var mid_c := Color("3d8fbf")
	var phase := posmod(frame, WATER_FRAMES)
	var mid: Color = [mid_a, mid_b, mid_c, mid_b, mid_a, Color("2f78a8"), mid_c, mid_b][phase]
	_fill(img, mid)
	# Soft drifting depth bands â€” seamless across neighbors.
	for y in TILE:
		for x in TILE:
			var wave := posmod(x * 3 + y * 5 + phase * 2, 11)
			if wave == 0 or wave == 1:
				_px(img, x, y, deep)
			elif wave == 5:
				_px(img, x, y, mid_a)
			elif wave == 8:
				_px(img, x, y, Color("245f88"))
	# Traveling sparkle ripples (offset by frame for smoothness).
	for i in 7:
		var sx := posmod(1 + i * 2 + phase, TILE)
		var sy := posmod(2 + i * 3 + int(phase * 1.5), TILE)
		if ((mask & MASK_N) != 0 or sy > 1) and ((mask & MASK_S) != 0 or sy < 14):
			if ((mask & MASK_W) != 0 or sx > 1) and ((mask & MASK_E) != 0 or sx < 14):
				_px(img, sx, sy, C_WATER_HL if (i + phase) % 2 == 0 else Color("5aa8c8"))
	# Shore foam only on exposed edges â€” shimmer by frame.
	if (mask & MASK_N) == 0:
		for x in TILE:
			_px(img, x, 0, mid_a)
			if (x + phase) % 2 == 0:
				_px(img, x, 1, Color("7ec8e8"))
			elif (x + phase) % 3 == 0:
				_px(img, x, 1, Color("6ab0c8"))
	if (mask & MASK_S) == 0:
		for x in TILE:
			_px(img, x, 15, mid_a)
			if (x + phase) % 2 == 1:
				_px(img, x, 14, Color("7ec8e8"))
	if (mask & MASK_W) == 0:
		for y in TILE:
			_px(img, 0, y, mid_a)
			if (y + phase) % 2 == 0:
				_px(img, 1, y, Color("6ab0c8"))
	if (mask & MASK_E) == 0:
		for y in TILE:
			_px(img, 15, y, mid_a)
			if (y + phase) % 2 == 1:
				_px(img, 14, y, Color("6ab0c8"))
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
	var img := _img()
	_fill(img, Color("3a3d46"))
	var asphalt := C_STONE
	var line := C_GOLD
	var has_n := (mask & MASK_N) != 0
	var has_e := (mask & MASK_E) != 0
	var has_s := (mask & MASK_S) != 0
	var has_w := (mask & MASK_W) != 0
	# Always a center pad so stubs look like road ends.
	_rect(img, 5, 5, 6, 6, asphalt)
	if has_n or (not has_e and not has_w and not has_s):
		_rect(img, 5, 0, 6, 8, asphalt)
	if has_s or (not has_e and not has_w and not has_n):
		_rect(img, 5, 8, 6, 8, asphalt)
	if has_w or (not has_n and not has_s and not has_e):
		_rect(img, 0, 5, 8, 6, asphalt)
	if has_e or (not has_n and not has_s and not has_w):
		_rect(img, 8, 5, 8, 6, asphalt)
	if has_n and has_s and not has_e and not has_w:
		for y in range(1, 15, 3):
			_rect(img, 7, y, 2, 2, line)
	elif has_e and has_w and not has_n and not has_s:
		for x in range(1, 15, 3):
			_rect(img, x, 7, 2, 2, line)
	elif has_n or has_s or has_e or has_w:
		_px(img, 7, 7, line)
		_px(img, 8, 7, line)
		_px(img, 7, 8, line)
		_px(img, 8, 8, line)
	return img


static func _bake_sidewalk(variant: int = 0) -> Image:
	var img := _img()
	_fill(img, C_SIDEWALK)
	for y in TILE:
		for x in TILE:
			if (x + y + variant) % 5 == 0:
				_px(img, x, y, C_SIDEWALK_DK)
			elif (x * 2 + y + variant) % 9 == 0:
				_px(img, x, y, C_SIDEWALK_LT)
	# Curb line toward street (bottom of foreshortened cell)
	for x in TILE:
		_px(img, x, 15, C_FACADE_TRIM)
		if x % 2 == variant % 2:
			_px(img, x, 14, C_SIDEWALK_DK)
	return img


## Transparent street facade: edge-to-edge walls so neighboring lots abut cleanly.
static func _facade_start(wall: Color) -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 0, 3, TILE, 11, wall)
	_outline_rect(img, 0, 3, TILE, 11, C_FACADE_TRIM)
	# Shared sidewalk lip in the sprite (matches lot sidewalk below).
	_rect(img, 0, 14, TILE, 2, C_SIDEWALK)
	_px(img, 0, 14, C_FACADE_TRIM)
	_px(img, 15, 14, C_FACADE_TRIM)
	return img


static func _facade_windows(img: Image, rows: Array, cols: Array, lit: Color = C_WATER_HL, dark: Color = Color("2a3348")) -> void:
	for yi in rows.size():
		for xi in cols.size():
			var c := lit if (xi + yi) % 2 == 0 else dark
			_rect(img, int(cols[xi]), int(rows[yi]), 2, 2, c)


static func _facade_door(img: Image, x: int = 7, color: Color = C_WOOD) -> void:
	_rect(img, x, 10, 2, 4, color)
	_px(img, x + 1, 12, C_GOLD)


static func _facade_roof_flat(img: Image, color: Color, y: int = 2) -> void:
	_rect(img, 0, y, TILE, 2, color)
	_outline_rect(img, 0, y, TILE, 2, C_FACADE_TRIM)


static func _bake_park() -> Image:
	var img := _img()
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 0, 10, TILE, 6, C_GRASS)
	_rect(img, 7, 8, 2, 6, C_WOOD)
	_rect(img, 4, 4, 8, 6, C_GRASS_LT)
	_px(img, 5, 5, C_GRASS_DK)
	_px(img, 10, 6, C_GRASS_DK)
	_px(img, 8, 7, C_GRASS)
	_rect(img, 1, 12, 3, 2, C_SIDEWALK_LT) # path stub
	_rect(img, 12, 12, 3, 2, C_SIDEWALK_LT)
	return img


static func _bake_factory(frame: int) -> Image:
	var img := _facade_start(C_STONE)
	_facade_roof_flat(img, C_STONE_DK, 2)
	_rect(img, 3, 0, 3, 4, C_STONE_DK) # stack
	_rect(img, 10, 1, 3, 3, C_STONE_DK)
	var smoke_y := posmod(frame, PROP_FRAMES)
	_px(img, 4, smoke_y, C_SMOKE)
	_px(img, 5, maxi(0, smoke_y - 1), Color("d8d8e0"))
	_px(img, 11, smoke_y, C_SMOKE)
	_facade_windows(img, [5, 8], [2, 6, 11], C_GOLD if frame % 2 == 0 else Color("2a3348"), Color("2a3348"))
	_rect(img, 6, 11, 4, 3, C_BLACK) # bay door
	return img


static func _bake_skyscraper(frame: int = 0) -> Image:
	var img := _facade_start(Color("4a5678"))
	_facade_roof_flat(img, Color("3a4558"), 1)
	_px(img, 8, 0, C_WHITE)
	if frame % 2 == 0:
		_px(img, 8, 0, C_ROOF_RED)
	for y in range(4, 13, 2):
		for x in [2, 5, 8, 11]:
			var lit := (int((x + y) / 2.0) + frame) % 3 != 0
			_rect(img, x, y, 2, 1, C_GOLD if lit else Color("2a3348"))
	_facade_door(img, 7, C_STONE_DK)
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
	var img := _facade_start(Color("4a7ab8"))
	_facade_roof_flat(img, Color("3a5a88"), 2)
	_facade_windows(img, [5, 8], [2, 5, 8, 11])
	_facade_door(img, 7, Color("2a3a58"))
	return img


static func _bake_downtown() -> Image:
	var img := _facade_start(C_WALL)
	_rect(img, 0, 3, 5, 11, C_ROOF_RED)
	_rect(img, 5, 3, 6, 11, Color("5a6687"))
	_rect(img, 11, 3, 5, 11, C_WALL_DK)
	_outline_rect(img, 0, 3, TILE, 11, C_FACADE_TRIM)
	_facade_roof_flat(img, C_STONE_DK, 2)
	_facade_windows(img, [5, 8], [1, 6, 12], C_GOLD, Color("2a3348"))
	_facade_door(img, 6, C_WOOD)
	_facade_door(img, 12, C_WOOD)
	return img


static func _bake_shops() -> Image:
	var img := _facade_start(C_WALL)
	_facade_roof_flat(img, C_GOLD, 2)
	_rect(img, 1, 7, 6, 4, C_WATER_HL) # display window
	_rect(img, 9, 7, 6, 4, C_WATER_HL)
	_outline_rect(img, 1, 7, 6, 4, C_FACADE_TRIM)
	_outline_rect(img, 9, 7, 6, 4, C_FACADE_TRIM)
	_facade_door(img, 7, C_ROOF_RED)
	_px(img, 3, 5, C_ROOF_RED)
	_px(img, 12, 5, C_ROOF_BLUE)
	return img


static func _bake_house() -> Image:
	var img := _facade_start(C_WALL)
	# Pitched roof silhouette across full width
	for x in range(0, 16):
		var roof_y := 2 + int(absi(x - 8) / 3.0)
		_px(img, x, roof_y, C_ROOF_RED)
		_px(img, x, roof_y + 1, C_ROOF_RED)
	_facade_windows(img, [6], [2, 11])
	_facade_door(img, 7, C_WOOD)
	_px(img, 3, 8, C_WATER_HL)
	_px(img, 12, 8, C_WATER_HL)
	return img


static func _bake_school() -> Image:
	var img := _facade_start(C_WALL)
	_facade_roof_flat(img, C_ROOF_TEAL, 2)
	_rect(img, 6, 0, 4, 3, C_ROOF_TEAL)
	_rect(img, 7, 1, 2, 2, C_GOLD)
	_facade_windows(img, [5, 8], [2, 5, 9, 12])
	_facade_door(img, 7, C_WOOD)
	return img


static func _bake_hospital() -> Image:
	var img := _facade_start(C_WHITE)
	_facade_roof_flat(img, Color("d8dee4"), 2)
	_rect(img, 7, 5, 2, 6, Color("e04040"))
	_rect(img, 5, 7, 6, 2, Color("e04040"))
	_facade_windows(img, [5, 10], [2, 12], C_WATER_HL, Color("c8d0d8"))
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
	_facade_roof_flat(img, C_STONE_DK, 2)
	_rect(img, 2, 5, 12, 6, C_GRASS_LT)
	_outline_rect(img, 2, 5, 12, 6, C_FACADE_TRIM)
	_px(img, 8, 7, C_PINK)
	_facade_door(img, 7, C_BLACK)
	return img


static func _bake_warehouse() -> Image:
	var img := _facade_start(C_STONE_LT)
	_facade_roof_flat(img, C_STONE_DK, 2)
	_rect(img, 5, 8, 6, 6, C_BLACK)
	_outline_rect(img, 5, 8, 6, 6, C_FACADE_TRIM)
	_facade_windows(img, [5], [2, 12], C_GOLD, Color("2a3348"))
	return img


static func _bake_hotel() -> Image:
	var img := _facade_start(C_PURPLE)
	_facade_roof_flat(img, Color("7a3aa0"), 2)
	_rect(img, 6, 12, 4, 2, C_GOLD)
	_facade_windows(img, [5, 8], [2, 5, 9, 12], C_GOLD, Color("4a2060"))
	_facade_door(img, 7, C_GOLD)
	return img


static func _bake_market() -> Image:
	var img := _facade_start(C_WALL_DK)
	_facade_roof_flat(img, Color("e85a3c"), 2)
	_rect(img, 1, 7, 6, 4, C_GOLD)
	_rect(img, 9, 7, 6, 4, C_GRASS_LT)
	_outline_rect(img, 1, 7, 6, 4, C_FACADE_TRIM)
	_outline_rect(img, 9, 7, 6, 4, C_FACADE_TRIM)
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
