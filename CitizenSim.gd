class_name CitizenSim
extends RefCounted

## Rule-based town citizens that spawn from homes and react to the city.

signal chatter(message: String)

enum Mood {
	JOYFUL,
	OK,
	UPSET,
	FLEEING,
}

const MAX_CITIZENS := 32
const STEP_INTERVAL := 0.38
const EMOTE_DURATION := 1.2
const MOOD_RADIUS := 4
const DIR_DOWN := 0
const DIR_LEFT := 1
const DIR_RIGHT := 2
const DIR_UP := 3

var board: Board
var citizens: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _chatter_cooldown := 0.0
var _last_phase: int = -1


func setup(p_board: Board) -> void:
	board = p_board
	_rng.randomize()
	clear()
	_last_phase = -1


func clear() -> void:
	citizens.clear()


func tick(delta: float) -> void:
	if board == null:
		return
	_chatter_cooldown = maxf(0.0, _chatter_cooldown - delta)
	_cull_orphans()
	_maybe_spawn_from_homes()
	_react_to_day_phase()

	var night := board.is_night()
	for citizen in citizens:
		citizen["emote_timer"] = float(citizen.get("emote_timer", 0.0)) - delta
		if float(citizen["emote_timer"]) <= 0.0:
			citizen["emote"] = ""
		citizen["step_timer"] = float(citizen.get("step_timer", 0.0)) - delta
		_update_mood(citizen)
		if float(citizen["step_timer"]) > 0.0:
			continue
		# Night: linger / sleep near homes; day keeps normal pace.
		var pace := STEP_INTERVAL * (1.55 if night else 1.0)
		if night and _near_home(citizen) and _rng.randf() < 0.55:
			_set_emote(citizen, "sleep")
			citizen["step_timer"] = pace * _rng.randf_range(1.2, 2.0)
			continue
		citizen["step_timer"] = pace * _rng.randf_range(0.75, 1.2)
		_step_citizen(citizen)
		citizen["walk_frame"] = (int(citizen.get("walk_frame", 0)) + 1) % TileLibrary.WALK_FRAMES

	var i := citizens.size() - 1
	while i >= 0:
		if bool(citizens[i].get("remove", false)):
			citizens.remove_at(i)
		i -= 1


func on_town_changed(cell: Vector2i, building_type: Board.BuildingType, placed: bool) -> void:
	if board == null:
		return
	if placed:
		match building_type:
			Board.BuildingType.RESIDENTIAL:
				_spawn_near(cell, 2)
				_react_burst("heart", "New neighbors moved in.")
			Board.BuildingType.HOTEL, Board.BuildingType.DOWNTOWN:
				if _rng.randf() < 0.55:
					_spawn_near(cell, 1)
					_react_burst("cheer", "Visitors noticed the new %s." % Board.type_name(building_type))
			Board.BuildingType.PARK, Board.BuildingType.SCHOOL, Board.BuildingType.HOSPITAL, Board.BuildingType.MARKET:
				_react_near(cell, "cheer", _civic_line(building_type), 5)
			Board.BuildingType.FACTORY, Board.BuildingType.WAREHOUSE, Board.BuildingType.HARBOR, Board.BuildingType.STADIUM:
				_react_near(cell, "anger", _hazard_line(building_type), 5)
			_:
				pass
	else:
		_cull_orphans()
		if building_type == Board.BuildingType.RESIDENTIAL:
			_react_burst("!", "Homes were cleared — some folks are leaving.")
			_make_nearby_flee(cell, 4)


func get_sorted_for_draw() -> Array[Dictionary]:
	var sorted: Array[Dictionary] = citizens.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["cell"].y) < int(b["cell"].y)
	)
	return sorted


## Snapshot for HUD: count, capacity, overall mood label / emote / color.
func get_town_mood_report() -> Dictionary:
	var count := citizens.size()
	if count == 0:
		return {
			"count": 0,
			"capacity": MAX_CITIZENS,
			"mood": Mood.OK,
			"label": "Quiet",
			"emote": "",
			"color": Color(0.72, 0.76, 0.82),
		}

	var total := 0.0
	var fleeing := 0
	for citizen in citizens:
		match int(citizen.get("mood", Mood.OK)):
			Mood.JOYFUL:
				total += 2.0
			Mood.OK:
				total += 1.0
			Mood.UPSET:
				total -= 1.0
			Mood.FLEEING:
				total -= 2.5
				fleeing += 1
			_:
				total += 1.0

	var avg := total / float(count)
	var mood := Mood.OK
	var label := "Content"
	var emote := "cheer"
	var color := Color(0.7, 0.85, 0.55)
	if fleeing >= maxi(1, ceili(count * 0.35)) or avg < -1.1:
		mood = Mood.FLEEING
		label = "Fleeing"
		emote = "!"
		color = Color(0.92, 0.42, 0.38)
	elif avg >= 1.35:
		mood = Mood.JOYFUL
		label = "Joyful"
		emote = "heart"
		color = Color(0.9, 0.55, 0.68)
	elif avg >= 0.35:
		mood = Mood.OK
		label = "Content"
		emote = "cheer"
		color = Color(0.7, 0.85, 0.55)
	elif avg >= -0.75:
		mood = Mood.UPSET
		label = "Uneasy"
		emote = "sweat"
		color = Color(0.9, 0.78, 0.4)
	else:
		mood = Mood.UPSET
		label = "Upset"
		emote = "anger"
		color = Color(0.9, 0.5, 0.35)

	return {
		"count": count,
		"capacity": MAX_CITIZENS,
		"mood": mood,
		"label": label,
		"emote": emote,
		"color": color,
	}


func _maybe_spawn_from_homes() -> void:
	if citizens.size() >= MAX_CITIZENS:
		return
	# Soft population pressure from housing capacity.
	var homes := _count_buildings(Board.BuildingType.RESIDENTIAL)
	var hotels := _count_buildings(Board.BuildingType.HOTEL)
	var downtown := _count_buildings(Board.BuildingType.DOWNTOWN)
	var capacity := mini(MAX_CITIZENS, homes * 2 + hotels + downtown / 2)
	if citizens.size() >= capacity:
		return
	var spawn_chance := 0.08
	if board.is_night():
		spawn_chance = 0.015
	elif board.get_day_phase() == Board.DayPhase.DAWN:
		spawn_chance = 0.12
	if _rng.randf() > spawn_chance:
		return
	var home := _random_building_cell(Board.BuildingType.RESIDENTIAL)
	if home.x < 0 and hotels > 0:
		home = _random_building_cell(Board.BuildingType.HOTEL)
	if home.x < 0:
		return
	_spawn_near(home, 1)


func _spawn_near(anchor: Vector2i, count: int) -> void:
	for _i in count:
		if citizens.size() >= MAX_CITIZENS:
			return
		var spot := _find_spawn_cell(anchor)
		if spot.x < 0:
			return
		citizens.append({
			"cell": spot,
			"target": spot,
			"dir": DIR_DOWN,
			"walk_frame": 0,
			"mood": Mood.OK,
			"emote": "",
			"emote_timer": 0.0,
			"step_timer": _rng.randf_range(0.0, STEP_INTERVAL),
			"home": anchor,
		})


func _find_spawn_cell(anchor: Vector2i) -> Vector2i:
	for radius in range(1, 6):
		var options: Array[Vector2i] = []
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := anchor + Vector2i(dx, dy)
				if _is_walkable(cell) and not _occupied(cell):
					options.append(cell)
		if not options.is_empty():
			return options[_rng.randi_range(0, options.size() - 1)]
	return Vector2i(-1, -1)


func _cull_orphans() -> void:
	var kept: Array[Dictionary] = []
	for citizen in citizens:
		var home: Vector2i = citizen["home"]
		if _is_housing_cell(home) or _has_any_housing():
			# Retarget home if original erased but other homes exist.
			if not _is_housing_cell(home):
				var new_home := _random_building_cell(Board.BuildingType.RESIDENTIAL)
				if new_home.x < 0:
					new_home = _random_building_cell(Board.BuildingType.HOTEL)
				if new_home.x < 0:
					continue
				citizen["home"] = new_home
				citizen["mood"] = Mood.UPSET
				_set_emote(citizen, "sweat")
			kept.append(citizen)
	citizens = kept


func _update_mood(citizen: Dictionary) -> void:
	if int(citizen["mood"]) == Mood.FLEEING:
		return
	var cell: Vector2i = citizen["cell"]
	var score := 0
	var saw_hazard := false
	var saw_joy := false
	for dy in range(-MOOD_RADIUS, MOOD_RADIUS + 1):
		for dx in range(-MOOD_RADIUS, MOOD_RADIUS + 1):
			var n := cell + Vector2i(dx, dy)
			if not board._is_in_bounds(n) or not board.land_mask[n.y][n.x]:
				continue
			if board.terrain_cells[n.y][n.x] != Board.TerrainType.OPEN:
				continue
			var inner: Board.BuildingType = board.inner_cells[n.y][n.x]
			match inner:
				Board.BuildingType.PARK, Board.BuildingType.SCHOOL, Board.BuildingType.HOSPITAL, Board.BuildingType.MARKET:
					score += 2
					saw_joy = true
				Board.BuildingType.SHOPS, Board.BuildingType.RESIDENTIAL:
					score += 1
				Board.BuildingType.FACTORY, Board.BuildingType.WAREHOUSE:
					score -= 3
					saw_hazard = true
				Board.BuildingType.HARBOR, Board.BuildingType.STADIUM:
					score -= 2
					saw_hazard = true
				_:
					pass
			var result: Dictionary = board._resolve_outer_result(n.x, n.y)
			var recipe_id := str(result.get("recipe_id", ""))
			if recipe_id in ["park_park", "residential_park", "school_park", "office_park", "harbor_park"]:
				score += 2
				saw_joy = true
			elif recipe_id in ["residential_factory", "factory_road"]:
				score -= 2
				saw_hazard = true

	var previous: int = int(citizen["mood"])
	var next_mood := Mood.OK
	if board.is_night() and not _near_home(citizen):
		score -= 2
	elif board.get_day_phase() == Board.DayPhase.DAWN:
		score += 1
	if score >= 4:
		next_mood = Mood.JOYFUL
	elif score <= -3:
		next_mood = Mood.UPSET
	citizen["mood"] = next_mood

	if next_mood == Mood.UPSET and previous != Mood.UPSET:
		_set_emote(citizen, "anger" if saw_hazard else "sweat")
		if _chatter_cooldown <= 0.0:
			_emit_chatter("Citizens are unhappy with nearby industry.")
	elif next_mood == Mood.JOYFUL and previous != Mood.JOYFUL:
		_set_emote(citizen, "heart" if saw_joy else "cheer")

	if next_mood == Mood.UPSET and score <= -6 and _rng.randf() < 0.15:
		citizen["mood"] = Mood.FLEEING
		_set_emote(citizen, "!")
		citizen["target"] = _edge_target(cell)


func _step_citizen(citizen: Dictionary) -> void:
	var cell: Vector2i = citizen["cell"]
	var mood: int = int(citizen["mood"])

	if mood == Mood.FLEEING:
		if not _is_in_map_interior(cell):
			citizen["remove"] = true
			return
		_step_toward(citizen, citizen["target"])
		return

	var target: Vector2i = citizen["target"]
	if target == cell or not _is_walkable(target) or _rng.randf() < 0.12:
		target = _pick_target(citizen)
		citizen["target"] = target

	_step_toward(citizen, target)


func _pick_target(citizen: Dictionary) -> Vector2i:
	var cell: Vector2i = citizen["cell"]
	var mood: int = int(citizen["mood"])
	var goals: Array[Board.BuildingType] = [] as Array[Board.BuildingType]

	# Night: head home / hotel. Dawn: parks & shops. Day uses mood goals.
	if board.is_night():
		goals.assign([
			Board.BuildingType.RESIDENTIAL,
			Board.BuildingType.HOTEL,
			Board.BuildingType.DOWNTOWN,
		])
	elif board.get_day_phase() == Board.DayPhase.DAWN:
		goals.assign([
			Board.BuildingType.PARK,
			Board.BuildingType.MARKET,
			Board.BuildingType.SHOPS,
			Board.BuildingType.SCHOOL,
		])
	elif board.get_day_phase() == Board.DayPhase.DUSK:
		goals.assign([
			Board.BuildingType.RESIDENTIAL,
			Board.BuildingType.SHOPS,
			Board.BuildingType.HOTEL,
			Board.BuildingType.PARK,
		])
	else:
		match mood:
			Mood.JOYFUL:
				goals.assign([
					Board.BuildingType.PARK,
					Board.BuildingType.SHOPS,
					Board.BuildingType.MARKET,
					Board.BuildingType.SCHOOL,
				])
			Mood.UPSET:
				goals.assign([
					Board.BuildingType.PARK,
					Board.BuildingType.HOSPITAL,
					Board.BuildingType.RESIDENTIAL,
				])
			_:
				goals.assign([
					Board.BuildingType.ROAD,
					Board.BuildingType.SHOPS,
					Board.BuildingType.PARK,
					Board.BuildingType.MARKET,
					Board.BuildingType.SCHOOL,
					Board.BuildingType.OFFICE,
				])

	for building_type in goals:
		var goal_cell := _random_building_cell(building_type)
		if goal_cell.x < 0:
			continue
		var near := _find_spawn_cell(goal_cell)
		if near.x >= 0:
			return near

	# Random roam nearby.
	for _try in 12:
		var cand := cell + Vector2i(_rng.randi_range(-5, 5), _rng.randi_range(-5, 5))
		if _is_walkable(cand):
			return cand
	return cell


func _step_toward(citizen: Dictionary, target: Vector2i) -> void:
	var cell: Vector2i = citizen["cell"]
	if cell == target:
		return
	var deltas: Array[Vector2i] = []
	var dx := clampi(target.x - cell.x, -1, 1)
	var dy := clampi(target.y - cell.y, -1, 1)
	if dx != 0:
		deltas.append(Vector2i(dx, 0))
	if dy != 0:
		deltas.append(Vector2i(0, dy))
	# Prefer roads when choosing among options.
	deltas.shuffle()
	deltas.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _road_score(cell + a) > _road_score(cell + b)
	)

	for delta in deltas:
		var next: Vector2i = cell + delta
		if not _is_walkable(next) or _occupied(next, citizen):
			continue
		citizen["cell"] = next
		citizen["dir"] = _dir_from_delta(delta)
		return

	# Sidestep if blocked.
	for delta in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var next: Vector2i = cell + delta
		if _is_walkable(next) and not _occupied(next, citizen):
			citizen["cell"] = next
			citizen["dir"] = _dir_from_delta(delta)
			return


func _road_score(cell: Vector2i) -> int:
	if not board._is_in_bounds(cell):
		return -1
	if board.inner_cells[cell.y][cell.x] == Board.BuildingType.ROAD:
		return 2
	return 0


func _dir_from_delta(delta: Vector2i) -> int:
	if delta.x < 0:
		return DIR_LEFT
	if delta.x > 0:
		return DIR_RIGHT
	if delta.y < 0:
		return DIR_UP
	return DIR_DOWN


func _is_walkable(cell: Vector2i) -> bool:
	if not board._is_buildable(cell):
		return false
	var inner: Board.BuildingType = board.inner_cells[cell.y][cell.x]
	return inner == Board.BuildingType.NONE or inner == Board.BuildingType.ROAD


func _occupied(cell: Vector2i, except: Dictionary = {}) -> bool:
	for citizen in citizens:
		if except == citizen:
			continue
		if citizen["cell"] == cell:
			return true
	return false


func _is_housing_cell(cell: Vector2i) -> bool:
	if not board._is_in_bounds(cell):
		return false
	var t: Board.BuildingType = board.inner_cells[cell.y][cell.x]
	return t == Board.BuildingType.RESIDENTIAL or t == Board.BuildingType.HOTEL or t == Board.BuildingType.DOWNTOWN


func _has_any_housing() -> bool:
	return (
		_count_buildings(Board.BuildingType.RESIDENTIAL) > 0
		or _count_buildings(Board.BuildingType.HOTEL) > 0
		or _count_buildings(Board.BuildingType.DOWNTOWN) > 0
	)


func _count_buildings(building_type: Board.BuildingType) -> int:
	var seen: Dictionary = {}
	var count := 0
	for y in Board.GRID_HEIGHT:
		for x in Board.GRID_WIDTH:
			if board.inner_cells[y][x] != building_type:
				continue
			var id: int = board.building_ids[y][x]
			if id == 0 or seen.has(id):
				continue
			seen[id] = true
			count += 1
	return count


func _random_building_cell(building_type: Board.BuildingType) -> Vector2i:
	var options: Array[Vector2i] = []
	for y in Board.GRID_HEIGHT:
		for x in Board.GRID_WIDTH:
			if board.inner_cells[y][x] == building_type:
				options.append(Vector2i(x, y))
	if options.is_empty():
		return Vector2i(-1, -1)
	return options[_rng.randi_range(0, options.size() - 1)]


func _edge_target(from: Vector2i) -> Vector2i:
	var edges: Array[Vector2i] = [
		Vector2i(from.x, 0),
		Vector2i(from.x, Board.GRID_HEIGHT - 1),
		Vector2i(0, from.y),
		Vector2i(Board.GRID_WIDTH - 1, from.y),
	]
	var best := edges[0]
	var best_d := 9999
	for edge in edges:
		var d := absi(edge.x - from.x) + absi(edge.y - from.y)
		if d < best_d:
			best_d = d
			best = edge
	return best


func _is_in_map_interior(cell: Vector2i) -> bool:
	return cell.x > 0 and cell.y > 0 and cell.x < Board.GRID_WIDTH - 1 and cell.y < Board.GRID_HEIGHT - 1


func _set_emote(citizen: Dictionary, emote_name: String) -> void:
	citizen["emote"] = emote_name
	citizen["emote_timer"] = EMOTE_DURATION


func _near_home(citizen: Dictionary) -> bool:
	var cell: Vector2i = citizen["cell"]
	var home: Vector2i = citizen.get("home", cell)
	if absi(cell.x - home.x) + absi(cell.y - home.y) <= 3:
		return true
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var n := cell + Vector2i(dx, dy)
			if not board._is_in_bounds(n):
				continue
			var inner: Board.BuildingType = board.inner_cells[n.y][n.x]
			if inner == Board.BuildingType.RESIDENTIAL or inner == Board.BuildingType.HOTEL:
				return true
	return false


func _react_to_day_phase() -> void:
	var phase := int(board.get_day_phase())
	if phase == _last_phase:
		return
	_last_phase = phase
	match phase:
		Board.DayPhase.NIGHT:
			_react_burst("sleep", "Night falls — townsfolk head home.")
			for citizen in citizens:
				if int(citizen["mood"]) != Mood.FLEEING:
					var home_spot := _find_spawn_cell(citizen.get("home", citizen["cell"]))
					if home_spot.x >= 0:
						citizen["target"] = home_spot
		Board.DayPhase.DAWN:
			_react_burst("cheer", "Dawn — the town wakes up.")
		Board.DayPhase.DAY:
			_emit_chatter("Daytime bustle returns.")
		Board.DayPhase.DUSK:
			_react_burst("sweat", "Dusk settles in — shops wind down.")


func _react_burst(emote_name: String, message: String) -> void:
	for citizen in citizens:
		if _rng.randf() < 0.55:
			_set_emote(citizen, emote_name)
	_emit_chatter(message)


func _react_near(cell: Vector2i, emote_name: String, message: String, radius: int) -> void:
	var any := false
	for citizen in citizens:
		var c: Vector2i = citizen["cell"]
		if maxi(absi(c.x - cell.x), absi(c.y - cell.y)) <= radius:
			_set_emote(citizen, emote_name)
			any = true
	if any:
		_emit_chatter(message)


func _make_nearby_flee(cell: Vector2i, radius: int) -> void:
	for citizen in citizens:
		var c: Vector2i = citizen["cell"]
		if maxi(absi(c.x - cell.x), absi(c.y - cell.y)) <= radius:
			citizen["mood"] = Mood.FLEEING
			citizen["target"] = _edge_target(c)
			_set_emote(citizen, "!")


func _emit_chatter(message: String) -> void:
	if _chatter_cooldown > 0.0:
		return
	_chatter_cooldown = 2.4
	chatter.emit(message)


func _civic_line(building_type: Board.BuildingType) -> String:
	match building_type:
		Board.BuildingType.PARK:
			return "Kids love the new park."
		Board.BuildingType.SCHOOL:
			return "Families are glad a school opened."
		Board.BuildingType.HOSPITAL:
			return "Relief — a hospital is nearby."
		Board.BuildingType.MARKET:
			return "The market stalls are buzzing."
		_:
			return "Townsfolk like the new civic building."


func _hazard_line(building_type: Board.BuildingType) -> String:
	match building_type:
		Board.BuildingType.FACTORY:
			return "Smog near the homes…"
		Board.BuildingType.WAREHOUSE:
			return "Heavy trucks worry the neighbors."
		Board.BuildingType.HARBOR:
			return "Dock noise carries inland."
		Board.BuildingType.STADIUM:
			return "Crowd noise keeps people up."
		_:
			return "Some citizens look uneasy."
