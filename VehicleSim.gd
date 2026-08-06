class_name VehicleSim
extends RefCounted

## Road traffic: cars, motorbikes, and buses on ROAD cells.
## Future: trains on rails, ships on water routes.

signal chatter(message: String)

const MAX_VEHICLES := 14
const STEP_CAR := 0.22
const STEP_BIKE := 0.16
const STEP_BUS := 0.34

var board: Board
var vehicles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _chatter_cooldown := 0.0


func setup(p_board: Board) -> void:
	board = p_board
	_rng.randomize()
	clear()


func clear() -> void:
	vehicles.clear()


func tick(delta: float) -> void:
	if board == null:
		return
	_chatter_cooldown = maxf(0.0, _chatter_cooldown - delta)
	_cull_orphans()
	_maybe_spawn()

	# Night traffic thins out; dawn/dusk stay busy.
	var night := board.is_night()
	for vehicle in vehicles:
		vehicle["step_timer"] = float(vehicle.get("step_timer", 0.0)) - delta
		if float(vehicle["step_timer"]) > 0.0:
			continue
		if night and _rng.randf() < 0.45:
			vehicle["step_timer"] = 0.4
			continue
		vehicle["step_timer"] = _step_interval(int(vehicle["kind"])) * _rng.randf_range(0.85, 1.15)
		_step_vehicle(vehicle)
		vehicle["walk_frame"] = (int(vehicle.get("walk_frame", 0)) + 1) % TileLibrary.WALK_FRAMES

	var i := vehicles.size() - 1
	while i >= 0:
		if bool(vehicles[i].get("remove", false)):
			vehicles.remove_at(i)
		i -= 1


func on_town_changed(_cell: Vector2i, building_type: Board.BuildingType, placed: bool) -> void:
	if not placed:
		_cull_orphans()
		return
	if building_type == Board.BuildingType.ROAD and vehicles.size() < 3:
		_maybe_spawn(true)
	elif building_type in [
		Board.BuildingType.FACTORY,
		Board.BuildingType.WAREHOUSE,
		Board.BuildingType.HARBOR,
		Board.BuildingType.DOWNTOWN,
		Board.BuildingType.MARKET,
	]:
		_maybe_spawn(true)


func get_sorted_for_draw() -> Array[Dictionary]:
	var sorted: Array[Dictionary] = vehicles.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["cell"].y) < int(b["cell"].y)
	)
	return sorted


func _step_interval(kind: int) -> float:
	match kind:
		TileLibrary.VehicleKind.BIKE:
			return STEP_BIKE
		TileLibrary.VehicleKind.BUS:
			return STEP_BUS
		_:
			return STEP_CAR


func _maybe_spawn(force: bool = false) -> void:
	if vehicles.size() >= MAX_VEHICLES:
		return
	var road_count := _count_roads()
	if road_count < 3:
		return
	var capacity := mini(MAX_VEHICLES, 2 + int(road_count / 6.0))
	if vehicles.size() >= capacity:
		return
	if not force and _rng.randf() > (0.12 if not board.is_night() else 0.03):
		return
	var start := _random_road_cell()
	if start.x < 0:
		return
	if _occupied(start):
		return
	var kind := _pick_kind()
	vehicles.append({
		"cell": start,
		"target": _pick_road_destination(start),
		"dir": 0,
		"kind": kind,
		"walk_frame": 0,
		"step_timer": _rng.randf_range(0.05, 0.4),
		"remove": false,
	})
	if _chatter_cooldown <= 0.0 and _rng.randf() < 0.25:
		_chatter_cooldown = 5.0
		match kind:
			TileLibrary.VehicleKind.BUS:
				chatter.emit("A bus rolled onto the avenue.")
			TileLibrary.VehicleKind.BIKE:
				chatter.emit("Motorbikes zip between the lanes.")
			_:
				chatter.emit("Traffic is picking up.")


func _pick_kind() -> int:
	var roll := _rng.randf()
	if roll < 0.18:
		return TileLibrary.VehicleKind.BUS
	if roll < 0.42:
		return TileLibrary.VehicleKind.BIKE
	return TileLibrary.VehicleKind.CAR


func _step_vehicle(vehicle: Dictionary) -> void:
	var cell: Vector2i = vehicle["cell"]
	if not _is_road(cell):
		vehicle["remove"] = true
		return
	var target: Vector2i = vehicle["target"]
	if target == cell or not _is_road(target) or _rng.randf() < 0.08:
		target = _pick_road_destination(cell)
		vehicle["target"] = target

	var deltas: Array[Vector2i] = []
	var dx := clampi(target.x - cell.x, -1, 1)
	var dy := clampi(target.y - cell.y, -1, 1)
	if dx != 0:
		deltas.append(Vector2i(dx, 0))
	if dy != 0:
		deltas.append(Vector2i(0, dy))
	deltas.shuffle()

	for delta in deltas:
		var next: Vector2i = cell + delta
		if not _is_road(next) or _occupied(next, vehicle):
			continue
		vehicle["cell"] = next
		vehicle["dir"] = _dir_from_delta(delta)
		return

	# Wander along any open road edge.
	var neighbors: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	neighbors.shuffle()
	for delta in neighbors:
		var next: Vector2i = cell + delta
		if _is_road(next) and not _occupied(next, vehicle):
			vehicle["cell"] = next
			vehicle["dir"] = _dir_from_delta(delta)
			return


func _pick_road_destination(from: Vector2i) -> Vector2i:
	for _try in 20:
		var cand := _random_road_cell()
		if cand.x >= 0 and cand != from:
			return cand
	return from


func _cull_orphans() -> void:
	var kept: Array[Dictionary] = []
	for vehicle in vehicles:
		if _is_road(vehicle["cell"]):
			kept.append(vehicle)
	vehicles = kept


func _count_roads() -> int:
	var n := 0
	for y in Board.GRID_HEIGHT:
		for x in Board.GRID_WIDTH:
			if board.inner_cells[y][x] == Board.BuildingType.ROAD:
				n += 1
	return n


func _random_road_cell() -> Vector2i:
	var cells: Array[Vector2i] = []
	for y in Board.GRID_HEIGHT:
		for x in Board.GRID_WIDTH:
			if board.inner_cells[y][x] == Board.BuildingType.ROAD:
				cells.append(Vector2i(x, y))
	if cells.is_empty():
		return Vector2i(-1, -1)
	return cells[_rng.randi_range(0, cells.size() - 1)]


func _is_road(cell: Vector2i) -> bool:
	if not board._is_in_bounds(cell):
		return false
	if not board.land_mask[cell.y][cell.x]:
		return false
	return board.inner_cells[cell.y][cell.x] == Board.BuildingType.ROAD


func _occupied(cell: Vector2i, except: Dictionary = {}) -> bool:
	for vehicle in vehicles:
		if except == vehicle:
			continue
		if vehicle["cell"] == cell:
			return true
	return false


func _dir_from_delta(delta: Vector2i) -> int:
	if delta.x < 0:
		return 1
	if delta.x > 0:
		return 2
	if delta.y < 0:
		return 3
	return 0
