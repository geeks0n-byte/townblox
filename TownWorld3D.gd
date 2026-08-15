extends Node3D

## Orthographic faux-3D town: extruded pixel buildings + Sprite3D actors (Beat Cop depth, 2D art).
## Loaded via Board at runtime (not class_name) to avoid GDScript circular type deps with Board.

const CELL := 1.0
const GROUND_Y := 0.0
const WATER_SURFACE_Y := -0.02
const ACTOR_Y := 0.55
const CLIFF_STEP := 0.48 ## World-Y drop that becomes a cliff face instead of a slope.


var board: Board
var camera: Camera3D
var sun: DirectionalLight3D
var fill_light: DirectionalLight3D
var env_node: WorldEnvironment
var ground_root: Node3D
var water_root: Node3D
var facade_root: Node3D
var prop_root: Node3D
var actor_root: Node3D
var ghost_root: Node3D
var lamp_root: Node3D

var _ground_meshes: Dictionary = {} # Vector2i -> MeshInstance3D (water surface for anim)
var _water_frame_cache: Dictionary = {} # Vector2i -> int
var _citizen_sprites: Array = []
var _vehicle_sprites: Array = []
var _lamp_lights: Array = []
var _mat_cache: Dictionary = {} # key -> StandardMaterial3D
var _tree_tex: Texture2D
var _focus := Vector3.ZERO
var _cam_dist := 32.0
var _cam_yaw := 0.0
var _ghost_key := ""
var _last_water_sync_frame := -1
var _build_base_y := 0.0
var _rock_mat: StandardMaterial3D
var _cliff_mat: StandardMaterial3D
var _snow_mat: StandardMaterial3D
var _water_shader_mat: ShaderMaterial
var _bed_mat: StandardMaterial3D
var _door_meshes: Dictionary = {} # building_id -> MeshInstance3D


func setup(p_board: Board) -> void:
	board = p_board
	_tree_tex = _bake_tree_tex()
	_build_rig()
	rebuild()


static func _camera_supports_dof() -> bool:
	# Camera DOF blur requires Forward+ or Mobile; project defaults to GL Compatibility.
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))
	return method != "gl_compatibility"


func _build_rig() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18.0
	camera.near = 0.05
	camera.far = 250.0
	camera.current = true
	if _camera_supports_dof():
		var attrs := CameraAttributesPractical.new()
		attrs.dof_blur_far_enabled = true
		attrs.dof_blur_near_enabled = false
		attrs.dof_blur_amount = 0.08
		attrs.dof_blur_far_distance = 40.0
		attrs.dof_blur_far_transition = 18.0
		camera.attributes = attrs
	add_child(camera)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_blur = 0.8
	sun.rotation_degrees = Vector3(-52, 42, 0)
	add_child(sun)

	fill_light = DirectionalLight3D.new()
	fill_light.name = "Fill"
	fill_light.light_energy = 0.18
	fill_light.light_color = Color(0.45, 0.52, 0.62)
	fill_light.rotation_degrees = Vector3(-18, -130, 0)
	add_child(fill_light)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.28, 0.38, 0.52)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.47, 0.52)
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.82
	env.tonemap_white = 1.35
	env.fog_enabled = true
	env.fog_light_color = Color(0.38, 0.48, 0.62)
	env.fog_density = 0.006
	env.fog_aerial_perspective = 0.42
	env_node = WorldEnvironment.new()
	env_node.environment = env
	add_child(env_node)

	ground_root = Node3D.new()
	ground_root.name = "Ground"
	add_child(ground_root)
	water_root = Node3D.new()
	water_root.name = "Water"
	add_child(water_root)
	facade_root = Node3D.new()
	facade_root.name = "Facades"
	add_child(facade_root)
	prop_root = Node3D.new()
	prop_root.name = "Props"
	add_child(prop_root)
	actor_root = Node3D.new()
	actor_root.name = "Actors"
	add_child(actor_root)
	ghost_root = Node3D.new()
	ghost_root.name = "Ghost"
	add_child(ghost_root)
	lamp_root = Node3D.new()
	lamp_root.name = "Lamps"
	add_child(lamp_root)

	_rock_mat = _solid_mat(Color("6e6a62"))
	_cliff_mat = _solid_mat(Color("4a4640"))
	_snow_mat = _solid_mat(Color("e8eef4"))
	_water_shader_mat = _make_water_shader_mat()
	_bed_mat = _make_bed_mat()

	_focus = Vector3(Board.GRID_WIDTH * 0.5, 0.0, Board.GRID_HEIGHT * 0.5)
	_update_camera()


func rebuild() -> void:
	if board == null:
		return
	_clear_children(ground_root)
	_clear_children(water_root)
	_clear_children(facade_root)
	_clear_children(prop_root)
	_clear_children(lamp_root)
	_ground_meshes.clear()
	_water_frame_cache.clear()
	_lamp_lights.clear()
	_mat_cache.clear()
	_door_meshes.clear()
	board.clear_bus_stops()
	_rock_mat = _solid_mat(Color("6e6a62"))
	_cliff_mat = _solid_mat(Color("4a4640"))
	_snow_mat = _solid_mat(Color("e8eef4"))
	_water_shader_mat = _make_water_shader_mat()
	_ghost_key = ""
	_last_water_sync_frame = -1

	var water_cells: Array[Vector2i] = []
	for y in Board.GRID_HEIGHT:
		for x in Board.GRID_WIDTH:
			var cell := Vector2i(x, y)
			if board.terrain_cells[y][x] == Board.TerrainType.WATER:
				water_cells.append(cell)
			else:
				_spawn_land_surface(cell)

	_build_water_body(water_cells)
	_spawn_buildings()
	_spawn_props()
	_update_day_look()
	_update_camera()
	_force_ghost_rebuild()


func sync_frame() -> void:
	if board == null:
		return
	_update_day_look()
	_sync_water_frames()
	_sync_doors()
	_sync_actors()
	_sync_ghost()
	_update_camera()


func _sync_doors() -> void:
	for bid in _door_meshes.keys():
		var door: MeshInstance3D = _door_meshes[bid]
		if door == null or not is_instance_valid(door):
			continue
		var open := board.is_door_open(int(bid))
		door.material_override = _make_mat(TileLibrary.door_tex(open), true)


func screen_to_cell(local_pos: Vector2, viewport_size: Vector2) -> Vector2i:
	if camera == null or viewport_size.x < 1.0 or viewport_size.y < 1.0:
		return Vector2i(-1, -1)
	var from := camera.project_ray_origin(local_pos)
	var dir := camera.project_ray_normal(local_pos)
	if absf(dir.y) < 0.0001:
		return Vector2i(-1, -1)
	# First hit the waterline plane, then refine with that cell's surface height.
	var t := (GROUND_Y - from.y) / dir.y
	if t < 0.0:
		return Vector2i(-1, -1)
	var hit := from + dir * t
	var cx := floori(hit.x / CELL)
	var cy := floori(hit.z / CELL)
	if cx < 0 or cy < 0 or cx >= Board.GRID_WIDTH or cy >= Board.GRID_HEIGHT:
		return Vector2i(-1, -1)
	var cell := Vector2i(cx, cy)
	var hy := board.ground_height(cell)
	if board.terrain_cells[cy][cx] == Board.TerrainType.WATER:
		hy = WATER_SURFACE_Y
	t = (hy - from.y) / dir.y
	if t >= 0.0:
		hit = from + dir * t
		cx = floori(hit.x / CELL)
		cy = floori(hit.z / CELL)
		if cx >= 0 and cy >= 0 and cx < Board.GRID_WIDTH and cy < Board.GRID_HEIGHT:
			cell = Vector2i(cx, cy)
	return cell


func _update_camera() -> void:
	if camera == null or board == null:
		return
	var zoom := maxf(board.view_zoom, 1.0)
	camera.size = clampf(20.0 / zoom, 3.8, 26.0)
	# Keep ~45° side angle until near max zoom; yaw 0 only at max zoom.
	var yaw_blend := clampf((zoom - (Board.ZOOM_MAX - 0.4)) / 0.4, 0.0, 1.0)
	yaw_blend = yaw_blend * yaw_blend * (3.0 - 2.0 * yaw_blend)
	var auto_yaw := lerpf(deg_to_rad(45.0), 0.0, yaw_blend)
	var target_yaw: float = board.view_yaw_radians() + auto_yaw
	var dt := get_process_delta_time()
	_cam_yaw = lerp_angle(_cam_yaw, target_yaw, 1.0 - exp(-dt * 10.0))
	var pitch := deg_to_rad(54.0)

	# Stable look target from pan only — does not chase the brush cursor.
	var map_center := Vector3(Board.GRID_WIDTH * 0.5, 0.0, Board.GRID_HEIGHT * 0.5)
	var forward_xz := Vector3(sin(_cam_yaw), 0.0, cos(_cam_yaw))
	var right := Vector3(forward_xz.z, 0.0, -forward_xz.x)
	var pan := (right * (-board.view_pan.x) + forward_xz * (-board.view_pan.y)) * 0.05
	var target_focus := map_center + pan
	_focus = _focus.lerp(target_focus, 1.0 - exp(-dt * 14.0))

	var offset := Vector3(
		sin(_cam_yaw) * cos(pitch),
		sin(pitch),
		cos(_cam_yaw) * cos(pitch)
	) * (_cam_dist / sqrt(zoom))
	camera.global_position = _focus + offset
	camera.look_at(_focus, Vector3.UP)
	var attrs := camera.attributes as CameraAttributesPractical
	if attrs != null:
		var dof_t := clampf((zoom - 1.4) / 2.5, 0.0, 1.0)
		attrs.dof_blur_far_enabled = dof_t > 0.05
		attrs.dof_blur_amount = lerpf(0.0, 0.12, dof_t)
		attrs.dof_blur_far_distance = lerpf(55.0, 22.0, dof_t)
		attrs.dof_blur_far_transition = lerpf(25.0, 10.0, dof_t)


func _spawn_ground_cell(cell: Vector2i) -> void:
	var terrain: Board.TerrainType = board.terrain_cells[cell.y][cell.x]
	if terrain == Board.TerrainType.WATER:
		return
	_spawn_land_surface(cell)


func _corner_y(gx: int, gz: int) -> float:
	var sum := 0.0
	var n := 0
	for dz in [-1, 0]:
		for dx in [-1, 0]:
			var c := Vector2i(gx + dx, gz + dz)
			if board._is_in_bounds(c):
				sum += board.ground_height(c)
				n += 1
	return sum / maxf(float(n), 1.0)


func _water_depth_at(cell: Vector2i) -> float:
	return clampf((Board.ELEV_WATER - board.elevation_at(cell)) / maxf(Board.ELEV_WATER, 0.001), 0.0, 1.0)


func _water_shore_at(cell: Vector2i) -> float:
	var shore := 0.0
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cell + d
		if not board._is_in_bounds(n) or board.terrain_cells[n.y][n.x] != Board.TerrainType.WATER:
			shore = 1.0
			break
	# Soften with diagonals a bit so corners foam too.
	if shore < 0.5:
		for d: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var n2: Vector2i = cell + d
			if not board._is_in_bounds(n2) or board.terrain_cells[n2.y][n2.x] != Board.TerrainType.WATER:
				shore = 0.55
				break
	return shore


func _build_water_body(cells: Array[Vector2i]) -> void:
	if cells.is_empty():
		return
	var bed_st := SurfaceTool.new()
	bed_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var surf_st := SurfaceTool.new()
	surf_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for cell in cells:
		var x0 := float(cell.x) * CELL
		var x1 := float(cell.x + 1) * CELL
		var z0 := float(cell.y) * CELL
		var z1 := float(cell.y + 1) * CELL
		var depth := _water_depth_at(cell)
		var shore := _water_shore_at(cell)
		var bed_y := board.ground_height(cell) - 0.06
		# Slightly dish deeper water.
		bed_y -= depth * 0.18

		var bed_col := Color("152a3c").lerp(Color("071018"), depth)
		_st_flat_quad(bed_st, x0, x1, z0, z1, bed_y, bed_col)

		var col := Color(depth, shore, 0.0, 1.0)
		_st_flat_quad(surf_st, x0, x1, z0, z1, WATER_SURFACE_Y, col)

	bed_st.generate_normals()
	surf_st.generate_normals()

	var bed_mi := MeshInstance3D.new()
	bed_mi.mesh = bed_st.commit()
	bed_mi.material_override = _bed_mat
	bed_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_root.add_child(bed_mi)

	var surf_mi := MeshInstance3D.new()
	surf_mi.mesh = surf_st.commit()
	surf_mi.material_override = _water_shader_mat
	surf_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_root.add_child(surf_mi)


func _st_flat_quad(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float, y: float, col: Color) -> void:
	var a := Vector3(x0, y, z0)
	var b := Vector3(x1, y, z0)
	var c := Vector3(x1, y, z1)
	var d := Vector3(x0, y, z1)
	st.set_color(col)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_color(col)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(b)
	st.set_color(col)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)
	st.set_color(col)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_color(col)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)
	st.set_color(col)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(d)


func _make_water_shader_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://water.gdshader")
	mat.set_shader_parameter("shallow_color", Color(0.28, 0.62, 0.78, 0.72))
	mat.set_shader_parameter("deep_color", Color(0.05, 0.16, 0.30, 0.94))
	mat.set_shader_parameter("foam_color", Color(0.86, 0.96, 1.0, 0.88))
	mat.set_shader_parameter("wave_height", 0.05)
	mat.set_shader_parameter("wave_scale", 0.6)
	mat.set_shader_parameter("wave_speed", 0.9)
	mat.set_shader_parameter("sparkle_strength", 0.4)
	mat.set_shader_parameter("metallic_amount", 0.45)
	mat.set_shader_parameter("roughness_amount", 0.16)
	return mat


func _make_bed_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 1.0
	mat.metallic = 0.0
	return mat


func _spawn_land_surface(cell: Vector2i) -> void:
	var x0 := float(cell.x) * CELL
	var x1 := float(cell.x + 1) * CELL
	var z0 := float(cell.y) * CELL
	var z1 := float(cell.y + 1) * CELL
	var y00 := _corner_y(cell.x, cell.y)
	var y10 := _corner_y(cell.x + 1, cell.y)
	var y11 := _corner_y(cell.x + 1, cell.y + 1)
	var y01 := _corner_y(cell.x, cell.y + 1)
	var ymin := minf(minf(y00, y10), minf(y01, y11))
	var ymax := maxf(maxf(y00, y10), maxf(y01, y11))
	var terrain: Board.TerrainType = board.terrain_cells[cell.y][cell.x]
	var is_mountain := terrain == Board.TerrainType.MOUNTAIN
	var steep := (ymax - ymin) >= CLIFF_STEP or (is_mountain and _cell_wants_cliff(cell))

	var tex := _ground_tex_for(cell)
	if steep:
		# Plateau top + cliff skirts — reads as a mountain/cliff block.
		var hy := board.ground_height(cell)
		_add_quad_mesh(
			ground_root,
			Vector3(x0, hy, z0),
			Vector3(x1, hy, z0),
			Vector3(x1, hy, z1),
			Vector3(x0, hy, z1),
			_snow_mat if hy > Board.ELEV_WORLD_SCALE * 0.72 else _make_mat(tex, false)
		)
		_spawn_cliff_skirts(cell, hy)
	else:
		var top_mat := _make_mat(tex, false)
		if is_mountain:
			top_mat = _rock_mat
			if ymax > Board.ELEV_WORLD_SCALE * 0.7:
				top_mat = _snow_mat
		_add_quad_mesh(
			ground_root,
			Vector3(x0, y00, z0),
			Vector3(x1, y10, z0),
			Vector3(x1, y11, z1),
			Vector3(x0, y01, z1),
			top_mat
		)
		_spawn_slope_drop_faces(cell, y00, y10, y11, y01)


func _cell_wants_cliff(cell: Vector2i) -> bool:
	var e := board.elevation_at(cell)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cell + d
		if not board._is_in_bounds(n):
			return true
		if e - board.elevation_at(n) > 0.14:
			return true
	# Deterministic mix: some mountain cells stay as slopes.
	return posmod(cell.x * 13 + cell.y * 29, 5) != 0


func _spawn_cliff_skirts(cell: Vector2i, hy: float) -> void:
	var x0 := float(cell.x) * CELL
	var x1 := float(cell.x + 1) * CELL
	var z0 := float(cell.y) * CELL
	var z1 := float(cell.y + 1) * CELL
	var dirs := [
		{"d": Vector2i(0, -1), "a": Vector3(x0, hy, z0), "b": Vector3(x1, hy, z0)},
		{"d": Vector2i(0, 1), "a": Vector3(x1, hy, z1), "b": Vector3(x0, hy, z1)},
		{"d": Vector2i(-1, 0), "a": Vector3(x0, hy, z1), "b": Vector3(x0, hy, z0)},
		{"d": Vector2i(1, 0), "a": Vector3(x1, hy, z0), "b": Vector3(x1, hy, z1)},
	]
	for entry in dirs:
		var n: Vector2i = cell + entry["d"]
		var bottom := WATER_SURFACE_Y - 0.15
		if board._is_in_bounds(n):
			if board.terrain_cells[n.y][n.x] == Board.TerrainType.WATER:
				bottom = WATER_SURFACE_Y - 0.05
			else:
				bottom = board.ground_height(n)
		if hy - bottom < CLIFF_STEP * 0.55:
			continue
		var a: Vector3 = entry["a"]
		var b: Vector3 = entry["b"]
		_add_quad_mesh(
			ground_root,
			a,
			b,
			Vector3(b.x, bottom, b.z),
			Vector3(a.x, bottom, a.z),
			_cliff_mat
		)


func _spawn_slope_drop_faces(cell: Vector2i, y00: float, y10: float, y11: float, y01: float) -> void:
	# Fill gaps where a neighbor sits much lower (steep slope edge → mini-cliff).
	var x0 := float(cell.x) * CELL
	var x1 := float(cell.x + 1) * CELL
	var z0 := float(cell.y) * CELL
	var z1 := float(cell.y + 1) * CELL
	_maybe_edge_drop(cell, Vector2i(0, -1), Vector3(x0, y00, z0), Vector3(x1, y10, z0))
	_maybe_edge_drop(cell, Vector2i(0, 1), Vector3(x1, y11, z1), Vector3(x0, y01, z1))
	_maybe_edge_drop(cell, Vector2i(-1, 0), Vector3(x0, y01, z1), Vector3(x0, y00, z0))
	_maybe_edge_drop(cell, Vector2i(1, 0), Vector3(x1, y10, z0), Vector3(x1, y11, z1))


func _maybe_edge_drop(cell: Vector2i, dir: Vector2i, a: Vector3, b: Vector3) -> void:
	var n := cell + dir
	var bottom_a := a.y
	var bottom_b := b.y
	if board._is_in_bounds(n):
		if board.terrain_cells[n.y][n.x] == Board.TerrainType.WATER:
			bottom_a = WATER_SURFACE_Y - 0.08
			bottom_b = WATER_SURFACE_Y - 0.08
		else:
			# Match neighbor edge corners roughly.
			var nx0 := n.x if dir.x <= 0 else n.x + 1
			var nz0 := n.y if dir.y <= 0 else n.y + 1
			if dir.x != 0:
				bottom_a = _corner_y(nx0, cell.y + (1 if a.z > float(cell.y) * CELL + 0.5 else 0))
				bottom_b = _corner_y(nx0, cell.y + (1 if b.z > float(cell.y) * CELL + 0.5 else 0))
			else:
				bottom_a = _corner_y(cell.x + (1 if a.x > float(cell.x) * CELL + 0.5 else 0), nz0)
				bottom_b = _corner_y(cell.x + (1 if b.x > float(cell.x) * CELL + 0.5 else 0), nz0)
	else:
		bottom_a = WATER_SURFACE_Y - 0.2
		bottom_b = WATER_SURFACE_Y - 0.2
	if minf(a.y - bottom_a, b.y - bottom_b) < CLIFF_STEP * 0.65:
		return
	_add_quad_mesh(
		ground_root,
		a,
		b,
		Vector3(b.x, bottom_b, b.z),
		Vector3(a.x, bottom_a, a.z),
		_cliff_mat
	)


func _spawn_water_cell(_cell: Vector2i) -> void:
	pass


func _add_quad_mesh(parent: Node3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_uv(Vector2(1, 0))
	st.add_vertex(b)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)
	st.set_uv(Vector2(0, 0))
	st.add_vertex(a)
	st.set_uv(Vector2(1, 1))
	st.add_vertex(c)
	st.set_uv(Vector2(0, 1))
	st.add_vertex(d)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


func _water_mat(_tex: Texture2D, _depth_t: float) -> StandardMaterial3D:
	return _solid_mat(Color("2a6f9e"))


func _ground_tex_for(cell: Vector2i) -> Texture2D:
	var x := cell.x
	var y := cell.y
	var terrain: Board.TerrainType = board.terrain_cells[y][x]
	if terrain == Board.TerrainType.WATER:
		return TileLibrary.water_auto_tex(board._water_mask(cell), board._tile_anim_frame % TileLibrary.WATER_FRAMES)
	if terrain == Board.TerrainType.MOUNTAIN:
		return TileLibrary.mountain_auto_tex(board._terrain_mask(cell, Board.TerrainType.MOUNTAIN))
	if terrain == Board.TerrainType.RUINS:
		return TileLibrary.open_tex((x * 3 + y) % 4)
	var inner: Board.BuildingType = board.inner_cells[y][x]
	if inner == Board.BuildingType.ROAD:
		var info: Dictionary = board.road_info(cell)
		return TileLibrary.road_style_tex(
			int(info.get("mask", 0)),
			int(info.get("style", 1)),
			int(info.get("flow", -1)),
			int(info.get("lane_side", -1))
		)
	if inner == Board.BuildingType.PARK or inner == Board.BuildingType.FARM:
		return TileLibrary.building_tex(inner, (x + y) % maxi(1, TileLibrary.building_frame_count(inner)))
	if inner != Board.BuildingType.NONE:
		return TileLibrary.sidewalk_tex((x + y) % 2)
	var result := board._resolve_outer_result(x, y)
	var recipe_id: String = str(result.get("recipe_id", ""))
	if not recipe_id.is_empty():
		return TileLibrary.recipe_tex(recipe_id)
	if result.has("influence_type"):
		return TileLibrary.influence_tex(result["influence_type"] as Board.BuildingType)
	return TileLibrary.open_tex((x * 3 + y * 7) % 4)


func _spawn_buildings() -> void:
	var seen: Dictionary = {}
	for y in Board.GRID_HEIGHT:
		for x in Board.GRID_WIDTH:
			if not board.land_mask[y][x]:
				continue
			var terrain: Board.TerrainType = board.terrain_cells[y][x]
			if terrain == Board.TerrainType.MOUNTAIN:
				_spawn_block(Vector2i(x, y), TileLibrary.mountain_auto_tex(board._terrain_mask(Vector2i(x, y), Board.TerrainType.MOUNTAIN)), 1.55)
				continue
			if terrain == Board.TerrainType.RUINS:
				_spawn_block(
					Vector2i(x, y),
					TileLibrary.ruins_auto_tex(board._terrain_mask(Vector2i(x, y), Board.TerrainType.RUINS), board._tile_anim_frame),
					1.2
				)
				continue
			if terrain != Board.TerrainType.OPEN:
				continue
			var bid: int = board.building_ids[y][x]
			if bid == 0 or seen.has(bid):
				continue
			var inner: Board.BuildingType = board.inner_cells[y][x]
			if inner == Board.BuildingType.NONE or inner == Board.BuildingType.ROAD:
				continue
			seen[bid] = true
			if inner == Board.BuildingType.PARK or inner == Board.BuildingType.FARM:
				_spawn_park_props(bid, inner)
				continue
			_spawn_building_volume(bid, inner)


func _spawn_building_volume(building_id: int, building_type: Board.BuildingType) -> void:
	var bounds := board._building_bounds(building_id)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return
	var h := board._building_height_factor(building_type) * CELL
	var w := float(bounds.size.x) * CELL
	var d := float(bounds.size.y) * CELL
	var cx := (bounds.position.x + bounds.size.x * 0.5) * CELL
	var cz := (bounds.position.y + bounds.size.y * 0.5) * CELL
	var wall := _wall_color(building_type)
	var roof_col := _roof_color(building_type)

	# Solid body for volume + soft shadow casting.
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(w * 0.94, h * 0.98, d * 0.94)
	body.mesh = body_mesh
	body.material_override = _solid_mat(wall.darkened(0.12))
	body.position = Vector3(cx, h * 0.49, cz)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	facade_root.add_child(body)

	# Pixel facades on all four sides so 90° POV orbits stay Beat Cop–readable.
	var south_y := bounds.position.y + bounds.size.y - 1
	var north_y := bounds.position.y
	var east_x := bounds.position.x + bounds.size.x - 1
	var west_x := bounds.position.x
	for dx in bounds.size.x:
		_spawn_facade_cell(
			Vector2i(bounds.position.x + dx, south_y),
			building_type,
			h,
			Vector3((bounds.position.x + dx + 0.5) * CELL, h * 0.5, (south_y + 1.0) * CELL - 0.01),
			Vector3(0, 180, 0)
		)
		_spawn_facade_cell(
			Vector2i(bounds.position.x + dx, north_y),
			building_type,
			h,
			Vector3((bounds.position.x + dx + 0.5) * CELL, h * 0.5, north_y * CELL + 0.01),
			Vector3(0, 0, 0)
		)
	for dy in bounds.size.y:
		_spawn_facade_cell(
			Vector2i(east_x, bounds.position.y + dy),
			building_type,
			h,
			Vector3((east_x + 1.0) * CELL - 0.01, h * 0.5, (bounds.position.y + dy + 0.5) * CELL),
			Vector3(0, -90, 0)
		)
		_spawn_facade_cell(
			Vector2i(west_x, bounds.position.y + dy),
			building_type,
			h,
			Vector3(west_x * CELL + 0.01, h * 0.5, (bounds.position.y + dy + 0.5) * CELL),
			Vector3(0, 90, 0)
		)

	# Flat roof slab + thin parapet for silhouette.
	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(w * 0.98, 0.1, d * 0.98)
	roof.mesh = roof_mesh
	roof.material_override = _solid_mat(roof_col)
	roof.position = Vector3(cx, h, cz)
	facade_root.add_child(roof)

	var parapet := MeshInstance3D.new()
	var parapet_mesh := BoxMesh.new()
	parapet_mesh.size = Vector3(w * 1.0, 0.14, d * 1.0)
	parapet.mesh = parapet_mesh
	parapet.material_override = _solid_mat(roof_col.darkened(0.18))
	parapet.position = Vector3(cx, h + 0.08, cz)
	facade_root.add_child(parapet)

	# Soft ground shadow blob under the lot.
	var shadow := MeshInstance3D.new()
	var shadow_mesh := PlaneMesh.new()
	shadow_mesh.size = Vector2(w * 1.05, d * 1.05)
	shadow.mesh = shadow_mesh
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0, 0, 0, 0.28)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = shadow_mat
	shadow.position = Vector3(cx, _build_base_y + 0.015, cz)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	facade_root.add_child(shadow)


func _spawn_facade_cell(
	cell: Vector2i,
	building_type: Board.BuildingType,
	height: float,
	pos: Vector3,
	rot_deg: Vector3
) -> void:
	var frames := TileLibrary.building_frame_count(building_type)
	var frame := (board._tile_anim_frame + cell.x * 2 + cell.y) % maxi(1, frames)
	var tex := TileLibrary.building_tex(building_type, frame)
	var face := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(CELL * 1.02, height)
	face.mesh = q
	face.material_override = _make_mat(tex, true)
	face.position = pos
	face.rotation_degrees = rot_deg
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	facade_root.add_child(face)


func _spawn_park_props(building_id: int, building_type: Board.BuildingType) -> void:
	for y in Board.GRID_HEIGHT:
		for x in Board.GRID_WIDTH:
			if board.building_ids[y][x] != building_id:
				continue
			var roll := posmod(x * 13 + y * 19 + building_id, 5)
			if building_type == Board.BuildingType.FARM and roll > 1:
				continue
			if building_type == Board.BuildingType.PARK and roll > 2:
				continue
			var spr := Sprite3D.new()
			spr.texture = _tree_tex
			spr.pixel_size = 0.055 if building_type == Board.BuildingType.PARK else 0.045
			spr.shaded = true
			spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
			spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			spr.position = Vector3(
				(x + 0.35 + (roll % 3) * 0.15) * CELL,
				0.55,
				(y + 0.4 + (roll % 2) * 0.2) * CELL
			)
			prop_root.add_child(spr)


func _spawn_block(cell: Vector2i, tex: Texture2D, height: float) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL * 0.96, height * CELL, CELL * 0.96)
	mi.mesh = mesh
	mi.material_override = _make_mat(tex, false)
	mi.position = Vector3((cell.x + 0.5) * CELL, height * CELL * 0.5, (cell.y + 0.5) * CELL)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	facade_root.add_child(mi)


func _spawn_props() -> void:
	var bus_stops_spawned := 0
	for y in Board.GRID_HEIGHT:
		for x in Board.GRID_WIDTH:
			if board.terrain_cells[y][x] != Board.TerrainType.OPEN:
				continue
			var cell := Vector2i(x, y)
			var inner: Board.BuildingType = board.inner_cells[y][x]
			if inner == Board.BuildingType.ROAD:
				continue
			if inner == Board.BuildingType.PARK or inner == Board.BuildingType.FARM:
				continue
			# Bus stops on sidewalks beside roads near civic/commercial lots.
			if (
				inner == Board.BuildingType.NONE
				and board._cell_adjacent_to_road(cell)
				and bus_stops_spawned < 8
				and _wants_bus_stop(cell)
			):
				_spawn_prop(cell, TileLibrary.PropKind.BUS_STOP)
				board.register_bus_stop(cell)
				bus_stops_spawned += 1
				continue
			var roll := posmod(x * 17 + y * 29, 11)
			if roll > 3:
				continue
			var near_road := board._cell_adjacent_to_road(cell)
			var on_lot := inner != Board.BuildingType.NONE
			if on_lot:
				var bid: int = board.building_ids[y][x]
				if bid != 0 and board._is_building_frontage(cell, bid):
					continue
			elif not near_road and roll != 0:
				continue
			var kind: TileLibrary.PropKind = [
				TileLibrary.PropKind.LAMP,
				TileLibrary.PropKind.HYDRANT,
				TileLibrary.PropKind.TRASH,
				TileLibrary.PropKind.NEWSSTAND,
			][roll % 4]
			if near_road and roll == 0:
				kind = TileLibrary.PropKind.LAMP
			_spawn_prop(cell, kind)


func _wants_bus_stop(cell: Vector2i) -> bool:
	# Prefer stops near shops / schools / offices / downtown.
	for d: Vector2i in [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2),
	]:
		var n: Vector2i = cell + d
		if not board._is_in_bounds(n):
			continue
		var t: Board.BuildingType = board.inner_cells[n.y][n.x]
		if t in [
			Board.BuildingType.SHOPS,
			Board.BuildingType.MARKET,
			Board.BuildingType.SCHOOL,
			Board.BuildingType.OFFICE,
			Board.BuildingType.DOWNTOWN,
			Board.BuildingType.HOSPITAL,
			Board.BuildingType.HOTEL,
		]:
			return posmod(cell.x * 7 + cell.y * 11, 5) == 0
	return false


func _spawn_prop(cell: Vector2i, kind: TileLibrary.PropKind) -> void:
	var gy := board.ground_height(cell)
	var spr := Sprite3D.new()
	spr.texture = TileLibrary.prop_tex(kind)
	spr.pixel_size = 0.045
	spr.shaded = true
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.position = Vector3(
		(cell.x + 0.5) * CELL,
		gy + (
			0.55 if kind == TileLibrary.PropKind.LAMP
			else (0.42 if kind == TileLibrary.PropKind.BUS_STOP else 0.28)
		),
		(cell.y + 0.5) * CELL
	)
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	prop_root.add_child(spr)
	if kind == TileLibrary.PropKind.LAMP:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.85, 0.45)
		light.light_energy = 0.0
		light.omni_range = 3.4
		light.shadow_enabled = false
		light.position = Vector3((cell.x + 0.5) * CELL, gy + 1.45, (cell.y + 0.5) * CELL)
		lamp_root.add_child(light)
		_lamp_lights.append(light)


func _sync_water_frames() -> void:
	# Water animation is driven by water.gdshader TIME uniforms.
	pass


func _sync_actors() -> void:
	var citizens: Array = board.citizen_sim.citizens if board.citizen_sim != null else []
	var vehicles: Array = board.vehicle_sim.vehicles if board.vehicle_sim != null else []
	_ensure_sprite_pool(_citizen_sprites, citizens.size(), true)
	_ensure_sprite_pool(_vehicle_sprites, vehicles.size(), false)
	for i in _citizen_sprites.size():
		var spr: Sprite3D = _citizen_sprites[i]
		if i >= citizens.size():
			spr.visible = false
			continue
		var citizen: Dictionary = citizens[i]
		var vis: Vector2 = citizen.get("visual", Vector2(citizen["cell"]))
		spr.visible = not bool(citizen.get("inside", false))
		spr.texture = TileLibrary.citizen_tex(
			_sprite_view_dir(int(citizen.get("dir", 0))),
			int(citizen.get("walk_frame", 0)),
			int(citizen.get("outfit", 0))
		)
		spr.position = Vector3((vis.x + 0.5) * CELL, board.ground_height(Vector2i(floori(vis.x), floori(vis.y))) + ACTOR_Y * 0.65, (vis.y + 0.5) * CELL)
		spr.pixel_size = 0.028
		spr.offset = Vector2(0, -4)
	for i in _vehicle_sprites.size():
		var spr: Sprite3D = _vehicle_sprites[i]
		if i >= vehicles.size():
			spr.visible = false
			continue
		var vehicle: Dictionary = vehicles[i]
		var vis: Vector2 = vehicle.get("visual", Vector2(vehicle["cell"]))
		var kind: int = int(vehicle.get("kind", TileLibrary.VehicleKind.CAR))
		spr.visible = true
		spr.texture = TileLibrary.vehicle_tex(
			kind as TileLibrary.VehicleKind,
			_sprite_view_dir(int(vehicle.get("dir", 0))),
			int(vehicle.get("walk_frame", 0))
		)
		spr.modulate = vehicle.get("paint", Color.WHITE) if kind == TileLibrary.VehicleKind.CAR else Color.WHITE
		spr.position = Vector3((vis.x + 0.5) * CELL, board.ground_height(Vector2i(floori(vis.x), floori(vis.y))) + 0.22, (vis.y + 0.5) * CELL)
		match kind:
			TileLibrary.VehicleKind.BUS:
				spr.pixel_size = 0.042
			TileLibrary.VehicleKind.BIKE:
				spr.pixel_size = 0.032
			_:
				spr.pixel_size = 0.036


## Map world movement dir (0=S 1=W 2=E 3=N) into camera-relative sprite frame.
func _sprite_view_dir(world_dir: int) -> int:
	# Movement yaw in XZ: S=0, W=+90°, E=-90°, N=180°. Toward-camera ≈ _cam_yaw.
	var move_yaws: Array[float] = [0.0, PI * 0.5, -PI * 0.5, PI]
	var move_yaw: float = move_yaws[clampi(world_dir, 0, 3)]
	var rel := angle_difference(_cam_yaw, move_yaw)
	if rel > -PI * 0.25 and rel <= PI * 0.25:
		return 0 # front (toward camera)
	if rel > PI * 0.25 and rel <= PI * 0.75:
		return 1 # left profile
	if rel < -PI * 0.25 and rel >= -PI * 0.75:
		return 2 # right profile
	return 3 # back


func _ensure_sprite_pool(pool: Array, count: int, is_citizen: bool) -> void:
	while pool.size() < count:
		var spr := Sprite3D.new()
		spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		spr.shaded = true
		spr.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spr.pixel_size = 0.032 if is_citizen else 0.045
		spr.centered = true
		actor_root.add_child(spr)
		pool.append(spr)


func _sync_ghost() -> void:
	var key := "%s:%s:%s:%s" % [
		board.ghost_type,
		board.hovered_cell,
		board.ghost_rotated,
		board.ghost_valid,
	]
	if key == _ghost_key:
		return
	_ghost_key = key
	_force_ghost_rebuild()


func _force_ghost_rebuild() -> void:
	_clear_children(ghost_root)
	if board.ghost_type == Board.BuildingType.NONE or not board._is_in_bounds(board.hovered_cell):
		return
	var footprint := Board.type_footprint(board.ghost_type, board.ghost_rotated)
	var tint := Color(0.35, 1.0, 0.85, 0.42) if board.ghost_valid else Color(1.0, 0.28, 0.28, 0.38)
	var base_y := board.ground_height(board.hovered_cell)
	for dy in footprint.y:
		for dx in footprint.x:
			var cell := board.hovered_cell + Vector2i(dx, dy)
			if not board._is_in_bounds(cell):
				continue
			var gy := board.ground_height(cell)
			var mi := MeshInstance3D.new()
			var mesh := PlaneMesh.new()
			mesh.size = Vector2(CELL * 0.92, CELL * 0.92)
			mi.mesh = mesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = tint
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mi.material_override = mat
			mi.position = Vector3((cell.x + 0.5) * CELL, gy + 0.05, (cell.y + 0.5) * CELL)
			ghost_root.add_child(mi)
	if board.ghost_type == Board.BuildingType.ROAD or board.ghost_type == Board.BuildingType.PARK or board.ghost_type == Board.BuildingType.FARM:
		return
	var h := board._building_height_factor(board.ghost_type) * CELL
	var w := float(footprint.x) * CELL
	var d := float(footprint.y) * CELL
	var cx := (board.hovered_cell.x + footprint.x * 0.5) * CELL
	var cz := (board.hovered_cell.y + footprint.y * 0.5) * CELL
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(w * 0.9, h * 0.95, d * 0.9)
	body.mesh = body_mesh
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = tint
	body_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body.material_override = body_mat
	body.position = Vector3(cx, base_y + h * 0.48, cz)
	ghost_root.add_child(body)
	var tex := TileLibrary.building_tex(board.ghost_type, 0)
	for dx in footprint.x:
		var cell := Vector2i(board.hovered_cell.x + dx, board.hovered_cell.y + footprint.y - 1)
		if not board._is_in_bounds(cell):
			continue
		var mi := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(CELL * 0.95, h)
		mi.mesh = mesh
		var mat := _make_mat(tex, true).duplicate() as StandardMaterial3D
		mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = mat
		mi.position = Vector3((cell.x + 0.5) * CELL, base_y + h * 0.5, (cell.y + 1.0) * CELL)
		mi.rotation_degrees = Vector3(0, 180, 0)
		ghost_root.add_child(mi)


func _update_day_look() -> void:
	if env_node == null or board == null:
		return
	var phase := board.get_day_phase()
	var bg := Color(0.28, 0.38, 0.52)
	var amb := Color(0.45, 0.47, 0.52)
	var fog := Color(0.38, 0.48, 0.62)
	var sun_e := 0.78
	var fill_e := 0.18
	var lamp_e := 0.0
	match phase:
		Board.DayPhase.DAWN:
			bg = Color(0.52, 0.34, 0.30)
			amb = Color(0.62, 0.48, 0.42)
			fog = Color(0.58, 0.40, 0.36)
			sun_e = 0.62
			fill_e = 0.14
			lamp_e = 0.3
		Board.DayPhase.DUSK:
			bg = Color(0.58, 0.28, 0.24)
			amb = Color(0.58, 0.36, 0.34)
			fog = Color(0.55, 0.32, 0.30)
			sun_e = 0.48
			fill_e = 0.12
			lamp_e = 0.75
		Board.DayPhase.NIGHT:
			bg = Color(0.05, 0.07, 0.14)
			amb = Color(0.22, 0.28, 0.5)
			fog = Color(0.08, 0.1, 0.2)
			sun_e = 0.12
			fill_e = 0.06
			lamp_e = 1.5
		_:
			pass
	env_node.environment.background_color = bg
	env_node.environment.ambient_light_color = amb
	env_node.environment.fog_light_color = fog
	sun.light_energy = sun_e
	sun.light_color = board.day_modulate()
	fill_light.light_energy = fill_e
	for light in _lamp_lights:
		light.light_energy = lamp_e


func _wall_color(building_type: Board.BuildingType) -> Color:
	match building_type:
		Board.BuildingType.FACTORY, Board.BuildingType.WAREHOUSE:
			return Color("7a756c")
		Board.BuildingType.OFFICE, Board.BuildingType.SKYSCRAPER:
			return Color("5a6687")
		Board.BuildingType.DOWNTOWN, Board.BuildingType.HOTEL:
			return Color("9a5a48")
		Board.BuildingType.SHOPS, Board.BuildingType.MARKET:
			return Color("c8bca8")
		Board.BuildingType.RESIDENTIAL:
			return Color("e08a6a")
		Board.BuildingType.HOSPITAL:
			return Color("e8e8ec")
		Board.BuildingType.SCHOOL:
			return Color("6ec1c7")
		Board.BuildingType.STADIUM:
			return Color("c44d6a")
		Board.BuildingType.HARBOR:
			return Color("3d7ea6")
		_:
			return Color("e8dcc8")


func _roof_color(building_type: Board.BuildingType) -> Color:
	match building_type:
		Board.BuildingType.SKYSCRAPER, Board.BuildingType.OFFICE:
			return Color("3a4558")
		Board.BuildingType.DOWNTOWN, Board.BuildingType.SHOPS:
			return Color("c4453a")
		Board.BuildingType.RESIDENTIAL:
			return Color("c4453a")
		Board.BuildingType.HOTEL:
			return Color("7a3aa0")
		Board.BuildingType.HOSPITAL:
			return Color("d8dee4")
		Board.BuildingType.SCHOOL:
			return Color("2a9a9a")
		Board.BuildingType.FACTORY, Board.BuildingType.WAREHOUSE:
			return Color("5a564e")
		Board.BuildingType.MARKET:
			return Color("e85a3c")
		Board.BuildingType.STADIUM:
			return Color("8a3a4a")
		Board.BuildingType.HARBOR:
			return Color("4a6a7a")
		_:
			return Color("5a564e")


func _make_mat(tex: Texture2D, transparent: bool) -> StandardMaterial3D:
	var key := "%s:%s" % [str(tex.get_rid()), transparent]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.9
	mat.metallic = 0.0
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.1
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = mat
	return mat


func _solid_mat(color: Color) -> StandardMaterial3D:
	var key := "solid:%s" % str(color)
	if _mat_cache.has(key):
		return _mat_cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.92
	_mat_cache[key] = mat
	return mat


func _bake_tree_tex() -> Texture2D:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Trunk
	for y in range(16, 23):
		for x in range(7, 9):
			img.set_pixel(x, y, Color("6a4a28"))
	# Canopy blobs
	_tree_blob(img, 8, 10, 5, Color("2d6b38"))
	_tree_blob(img, 5, 12, 4, Color("3d8f4a"))
	_tree_blob(img, 11, 12, 4, Color("3d8f4a"))
	_tree_blob(img, 8, 7, 4, Color("5cb86a"))
	return ImageTexture.create_from_image(img)


func _tree_blob(img: Image, cx: int, cy: int, r: int, color: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				img.set_pixel(x, y, color)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
