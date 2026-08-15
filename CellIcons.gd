class_name CellIcons
extends RefCounted

## Shared geometric icons for buildings, terrain, and overlap recipes.


static func draw_building(canvas: CanvasItem, cell_rect: Rect2, building_type: Board.BuildingType, ink: Color = Color(1, 1, 1, 0.7)) -> void:
	var c := cell_rect.get_center()
	var s := minf(cell_rect.size.x, cell_rect.size.y)
	match building_type:
		Board.BuildingType.PARK:
			_tree(canvas, c, s * 0.28, ink)
		Board.BuildingType.FACTORY:
			_factory(canvas, c, s, ink)
		Board.BuildingType.ROAD:
			_road(canvas, c, s, ink)
		Board.BuildingType.OFFICE:
			_office(canvas, c, s, ink)
		Board.BuildingType.SKYSCRAPER:
			_skyscraper(canvas, c, s, ink)
		Board.BuildingType.DOWNTOWN:
			_downtown(canvas, c, s, ink)
		Board.BuildingType.SHOPS:
			_shops(canvas, c, s, ink)
		Board.BuildingType.RESIDENTIAL:
			_house(canvas, c, s, ink)
		Board.BuildingType.SCHOOL:
			_school(canvas, c, s, ink)
		Board.BuildingType.HOSPITAL:
			_cross(canvas, c, s * 0.22, ink)
		Board.BuildingType.FARM:
			_farm(canvas, c, s, ink)
		Board.BuildingType.HARBOR:
			_anchor(canvas, c, s, ink)
		Board.BuildingType.STADIUM:
			_stadium(canvas, c, s, ink)
		Board.BuildingType.WAREHOUSE:
			_warehouse(canvas, c, s, ink)
		Board.BuildingType.HOTEL:
			_hotel(canvas, c, s, ink)
		Board.BuildingType.MARKET:
			_market(canvas, c, s, ink)
		_:
			pass


static func draw_terrain(canvas: CanvasItem, cell_rect: Rect2, terrain: Board.TerrainType, ink: Color = Color(0.95, 0.95, 0.95, 0.55)) -> void:
	var c := cell_rect.get_center()
	var s := minf(cell_rect.size.x, cell_rect.size.y)
	match terrain:
		Board.TerrainType.WATER:
			_water(canvas, c, s, ink)
		Board.TerrainType.MOUNTAIN:
			_mountain(canvas, c, s, ink)
		Board.TerrainType.RUINS:
			_ruins(canvas, c, s, ink)
		_:
			pass


static func draw_recipe(canvas: CanvasItem, cell_rect: Rect2, recipe_id: String, ink: Color = Color(1, 1, 1, 0.55)) -> void:
	var c := cell_rect.get_center()
	var s := minf(cell_rect.size.x, cell_rect.size.y)
	match recipe_id:
		"park_park":
			_tree(canvas, c + Vector2(-s * 0.14, 0), s * 0.18, ink)
			_tree(canvas, c + Vector2(s * 0.14, s * 0.04), s * 0.16, ink)
		"factory_road":
			_parking(canvas, c, s, ink)
		"office_shops":
			_bag(canvas, c, s, ink)
		"downtown_skyscraper":
			_city_core(canvas, c, s, ink)
		"residential_park":
			_swing(canvas, c, s, ink)
		"residential_shops":
			_awning(canvas, c, s, ink)
		"residential_school":
			_path(canvas, c, s, ink)
		"residential_factory":
			_smog(canvas, c, s, ink)
		"residential_downtown":
			_townhouse(canvas, c, s, ink)
		"farm_residential":
			_crops(canvas, c, s, ink)
		"farm_market":
			_crates(canvas, c, s, ink)
		"harbor_shops":
			_boardwalk(canvas, c, s, ink)
		"harbor_warehouse":
			_crane(canvas, c, s, ink)
		"harbor_park":
			_promenade(canvas, c, s, ink)
		"stadium_road":
			_event_lot(canvas, c, s, ink)
		"stadium_shops":
			_star(canvas, c, s * 0.28, ink)
		"hospital_road":
			_siren(canvas, c, s, ink)
		"school_park":
			_sports_field(canvas, c, s, ink)
		"warehouse_road":
			_loading(canvas, c, s, ink)
		"hotel_downtown":
			_suitcase(canvas, c, s, ink)
		"office_park":
			_plaza(canvas, c, s, ink)
		"market_road":
			_stall(canvas, c, s, ink)
		"downtown_shops":
			_mall(canvas, c, s, ink)
		_:
			_dot(canvas, c, s * 0.08, ink)


static func _tree(canvas: CanvasItem, c: Vector2, r: float, ink: Color) -> void:
	canvas.draw_circle(c + Vector2(0, -r * 0.2), r, ink)
	canvas.draw_rect(Rect2(c + Vector2(-r * 0.15, r * 0.35), Vector2(r * 0.3, r * 0.55)), ink)


static func _factory(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	var w := s * 0.42
	var h := s * 0.28
	canvas.draw_rect(Rect2(c + Vector2(-w * 0.5, -h * 0.1), Vector2(w, h)), ink, false, 1.5)
	canvas.draw_rect(Rect2(c + Vector2(-w * 0.35, -h * 0.85), Vector2(s * 0.08, h * 0.8)), ink)
	canvas.draw_rect(Rect2(c + Vector2(w * 0.1, -h * 0.7), Vector2(s * 0.08, h * 0.65)), ink)


static func _road(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_line(c + Vector2(-s * 0.3, 0), c + Vector2(s * 0.3, 0), ink, 2.0)
	for i in 3:
		var x := -s * 0.18 + i * s * 0.18
		canvas.draw_line(c + Vector2(x, -s * 0.06), c + Vector2(x + s * 0.08, -s * 0.06), ink, 1.5)


static func _office(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	var box := Rect2(c - Vector2(s * 0.18, s * 0.22), Vector2(s * 0.36, s * 0.44))
	canvas.draw_rect(box, ink, false, 1.5)
	for row in 3:
		for col in 2:
			var p := box.position + Vector2(s * 0.07 + col * s * 0.14, s * 0.07 + row * s * 0.12)
			canvas.draw_rect(Rect2(p, Vector2(s * 0.06, s * 0.06)), ink)


static func _skyscraper(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.1, -s * 0.28), Vector2(s * 0.2, s * 0.5)), ink, false, 1.5)
	canvas.draw_line(c + Vector2(0, -s * 0.28), c + Vector2(0, -s * 0.38), ink, 1.5)


static func _downtown(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.28, -s * 0.05), Vector2(s * 0.16, s * 0.28)), ink, false, 1.2)
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.22), Vector2(s * 0.16, s * 0.45)), ink, false, 1.2)
	canvas.draw_rect(Rect2(c + Vector2(s * 0.12, -s * 0.1), Vector2(s * 0.14, s * 0.33)), ink, false, 1.2)


static func _shops(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	_awning(canvas, c, s, ink)
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.2, 0), Vector2(s * 0.4, s * 0.22)), ink, false, 1.2)


static func _house(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	var tip := c + Vector2(0, -s * 0.28)
	var left := c + Vector2(-s * 0.22, -s * 0.05)
	var right := c + Vector2(s * 0.22, -s * 0.05)
	canvas.draw_colored_polygon(PackedVector2Array([tip, left, right]), ink)
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.16, -s * 0.02), Vector2(s * 0.32, s * 0.24)), ink, false, 1.2)


static func _school(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.18, -s * 0.08), Vector2(s * 0.36, s * 0.28)), ink, false, 1.2)
	canvas.draw_line(c + Vector2(0, -s * 0.08), c + Vector2(0, -s * 0.3), ink, 1.5)
	canvas.draw_rect(Rect2(c + Vector2(0, -s * 0.3), Vector2(s * 0.16, s * 0.1)), ink)


static func _cross(canvas: CanvasItem, c: Vector2, arm: float, ink: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-arm * 0.35, -arm), Vector2(arm * 0.7, arm * 2.0)), ink)
	canvas.draw_rect(Rect2(c + Vector2(-arm, -arm * 0.35), Vector2(arm * 2.0, arm * 0.7)), ink)


static func _farm(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	for i in 3:
		var y := -s * 0.12 + i * s * 0.12
		canvas.draw_line(c + Vector2(-s * 0.25, y), c + Vector2(s * 0.25, y), ink, 1.4)
	canvas.draw_rect(Rect2(c + Vector2(s * 0.08, -s * 0.28), Vector2(s * 0.16, s * 0.2)), ink, false, 1.2)


static func _anchor(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_circle(c + Vector2(0, -s * 0.16), s * 0.07, ink, false, 1.5)
	canvas.draw_line(c + Vector2(0, -s * 0.1), c + Vector2(0, s * 0.18), ink, 1.8)
	canvas.draw_arc(c + Vector2(0, s * 0.08), s * 0.16, PI * 0.15, PI * 0.85, 10, ink, 1.6)
	canvas.draw_line(c + Vector2(-s * 0.14, -s * 0.02), c + Vector2(s * 0.14, -s * 0.02), ink, 1.5)


static func _stadium(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	_ellipse_outline(canvas, c, Vector2(s * 0.28, s * 0.16), ink, 1.6)
	_ellipse_outline(canvas, c, Vector2(s * 0.16, s * 0.08), ink, 1.2)


static func _ellipse_outline(canvas: CanvasItem, center: Vector2, radii: Vector2, ink: Color, width: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 24:
		var a := float(i) * TAU / 24.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	pts.append(pts[0])
	canvas.draw_polyline(pts, ink, width)

static func _warehouse(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.24, -s * 0.14), Vector2(s * 0.48, s * 0.32)), ink, false, 1.5)
	canvas.draw_line(c + Vector2(-s * 0.24, -s * 0.14), c + Vector2(0, -s * 0.28), ink, 1.4)
	canvas.draw_line(c + Vector2(s * 0.24, -s * 0.14), c + Vector2(0, -s * 0.28), ink, 1.4)


static func _hotel(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.2, -s * 0.2), Vector2(s * 0.4, s * 0.4)), ink, false, 1.4)
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.12, 0.0), Vector2(s * 0.24, s * 0.1)), ink)
	canvas.draw_line(c + Vector2(-s * 0.12, -s * 0.08), c + Vector2(s * 0.12, -s * 0.08), ink, 1.3)


static func _market(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	_awning(canvas, c + Vector2(0, -s * 0.05), s * 0.9, ink)
	canvas.draw_circle(c + Vector2(-s * 0.1, s * 0.12), s * 0.05, ink)
	canvas.draw_circle(c + Vector2(s * 0.1, s * 0.12), s * 0.05, ink)


static func _water(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_circle(c + Vector2(-s * 0.16, s * 0.06), s * 0.1, ink)
	canvas.draw_circle(c + Vector2(s * 0.18, -s * 0.08), s * 0.08, Color(ink.r, ink.g, ink.b, ink.a * 0.75))
	canvas.draw_arc(c + Vector2(0, s * 0.05), s * 0.2, PI * 1.1, PI * 1.9, 8, ink, 1.4)


static func _mountain(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	var tip := c + Vector2(0, -s * 0.28)
	var left := c + Vector2(-s * 0.3, s * 0.22)
	var right := c + Vector2(s * 0.3, s * 0.22)
	canvas.draw_colored_polygon(PackedVector2Array([tip, left, right]), ink)


static func _ruins(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.22, -s * 0.18), Vector2(s * 0.1, s * 0.36)), ink, false, 1.4)
	canvas.draw_rect(Rect2(c + Vector2(s * 0.08, -s * 0.08), Vector2(s * 0.1, s * 0.26)), ink, false, 1.4)
	canvas.draw_line(c + Vector2(-s * 0.22, -s * 0.18), c + Vector2(-s * 0.05, -s * 0.28), ink, 1.3)


static func _parking(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.18, -s * 0.2), Vector2(s * 0.12, s * 0.4)), ink, false, 1.4)
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.18, -s * 0.2), Vector2(s * 0.28, s * 0.14)), ink, false, 1.4)


static func _bag(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.14, -s * 0.05), Vector2(s * 0.28, s * 0.24)), ink, false, 1.4)
	canvas.draw_arc(c + Vector2(0, -s * 0.05), s * 0.1, PI, PI * 2.0, 8, ink, 1.3)


static func _city_core(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	_skyscraper(canvas, c + Vector2(-s * 0.12, 0), s * 0.85, ink)
	_skyscraper(canvas, c + Vector2(s * 0.12, s * 0.04), s * 0.7, ink)


static func _swing(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_line(c + Vector2(-s * 0.2, -s * 0.2), c + Vector2(-s * 0.2, s * 0.15), ink, 1.4)
	canvas.draw_line(c + Vector2(s * 0.2, -s * 0.2), c + Vector2(s * 0.2, s * 0.15), ink, 1.4)
	canvas.draw_line(c + Vector2(-s * 0.2, -s * 0.2), c + Vector2(s * 0.2, -s * 0.2), ink, 1.4)
	canvas.draw_line(c + Vector2(-s * 0.08, -s * 0.05), c + Vector2(s * 0.08, -s * 0.05), ink, 1.6)


static func _awning(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	var tip := c + Vector2(0, -s * 0.22)
	var left := c + Vector2(-s * 0.24, 0)
	var right := c + Vector2(s * 0.24, 0)
	canvas.draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(ink.r, ink.g, ink.b, ink.a * 0.85))


static func _path(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_line(c + Vector2(-s * 0.25, s * 0.1), c + Vector2(s * 0.25, -s * 0.1), ink, 2.0)
	canvas.draw_circle(c + Vector2(-s * 0.12, s * 0.05), s * 0.04, ink)
	canvas.draw_circle(c + Vector2(s * 0.12, -s * 0.05), s * 0.04, ink)


static func _smog(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_circle(c + Vector2(-s * 0.12, 0), s * 0.1, Color(ink.r, ink.g, ink.b, ink.a * 0.5))
	canvas.draw_circle(c + Vector2(s * 0.08, -s * 0.08), s * 0.12, Color(ink.r, ink.g, ink.b, ink.a * 0.45))
	canvas.draw_circle(c + Vector2(s * 0.02, s * 0.1), s * 0.08, Color(ink.r, ink.g, ink.b, ink.a * 0.4))


static func _townhouse(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	_house(canvas, c + Vector2(-s * 0.14, 0), s * 0.7, ink)
	_house(canvas, c + Vector2(s * 0.14, 0), s * 0.7, ink)


static func _crops(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	for i in 4:
		var x := -s * 0.2 + i * s * 0.13
		canvas.draw_line(c + Vector2(x, s * 0.16), c + Vector2(x, -s * 0.1), ink, 1.3)
		canvas.draw_circle(c + Vector2(x, -s * 0.14), s * 0.035, ink)


static func _boardwalk(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	for i in 3:
		var y := -s * 0.12 + i * s * 0.12
		canvas.draw_line(c + Vector2(-s * 0.25, y), c + Vector2(s * 0.25, y), ink, 1.5)


static func _crane(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_line(c + Vector2(-s * 0.05, s * 0.2), c + Vector2(-s * 0.05, -s * 0.25), ink, 1.8)
	canvas.draw_line(c + Vector2(-s * 0.05, -s * 0.25), c + Vector2(s * 0.25, -s * 0.25), ink, 1.8)
	canvas.draw_line(c + Vector2(s * 0.25, -s * 0.25), c + Vector2(s * 0.25, -s * 0.05), ink, 1.4)


static func _star(canvas: CanvasItem, c: Vector2, r: float, ink: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 5:
		var a := -PI * 0.5 + i * TAU / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
		var b := a + TAU / 10.0
		pts.append(c + Vector2(cos(b), sin(b)) * r * 0.45)
	canvas.draw_colored_polygon(pts, ink)


static func _suitcase(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.18, -s * 0.08), Vector2(s * 0.36, s * 0.24)), ink, false, 1.4)
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.16), Vector2(s * 0.16, s * 0.08)), ink, false, 1.2)


static func _plaza(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_circle(c, s * 0.08, ink)
	canvas.draw_arc(c, s * 0.2, 0, TAU, 16, ink, 1.3)


static func _mall(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_line(c + Vector2(-s * 0.25, 0), c + Vector2(s * 0.25, 0), ink, 2.0)
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.22, -s * 0.16), Vector2(s * 0.16, s * 0.14)), ink, false, 1.2)
	canvas.draw_rect(Rect2(c + Vector2(s * 0.06, -s * 0.16), Vector2(s * 0.16, s * 0.14)), ink, false, 1.2)


static func _dot(canvas: CanvasItem, c: Vector2, r: float, ink: Color) -> void:
	canvas.draw_circle(c, r, ink)


static func _crates(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.22, -s * 0.02), Vector2(s * 0.18, s * 0.18)), ink, false, 1.3)
	canvas.draw_rect(Rect2(c + Vector2(0.0, -s * 0.12), Vector2(s * 0.18, s * 0.18)), ink, false, 1.3)
	canvas.draw_rect(Rect2(c + Vector2(s * 0.04, s * 0.04), Vector2(s * 0.18, s * 0.16)), ink, false, 1.3)


static func _promenade(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	_boardwalk(canvas, c + Vector2(0, s * 0.08), s * 0.85, ink)
	_tree(canvas, c + Vector2(0, -s * 0.12), s * 0.12, ink)


static func _event_lot(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	for i in 3:
		var y := -s * 0.16 + i * s * 0.14
		canvas.draw_line(c + Vector2(-s * 0.22, y), c + Vector2(s * 0.22, y), ink, 1.4)
		canvas.draw_rect(Rect2(c + Vector2(-s * 0.1, y - s * 0.05), Vector2(s * 0.2, s * 0.08)), ink, false, 1.1)


static func _siren(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	_cross(canvas, c + Vector2(0, s * 0.04), s * 0.14, ink)
	canvas.draw_arc(c + Vector2(0, -s * 0.12), s * 0.12, PI * 1.15, PI * 1.85, 6, ink, 1.4)


static func _sports_field(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.24, -s * 0.16), Vector2(s * 0.48, s * 0.32)), ink, false, 1.4)
	canvas.draw_line(c + Vector2(0, -s * 0.16), c + Vector2(0, s * 0.16), ink, 1.2)
	canvas.draw_circle(c, s * 0.07, ink, false, 1.2)


static func _loading(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.24, -s * 0.1), Vector2(s * 0.28, s * 0.22)), ink, false, 1.4)
	canvas.draw_line(c + Vector2(s * 0.04, 0), c + Vector2(s * 0.24, 0), ink, 1.6)
	canvas.draw_line(c + Vector2(s * 0.24, 0), c + Vector2(s * 0.16, -s * 0.08), ink, 1.4)
	canvas.draw_line(c + Vector2(s * 0.24, 0), c + Vector2(s * 0.16, s * 0.08), ink, 1.4)


static func _stall(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	_awning(canvas, c + Vector2(0, -s * 0.06), s * 0.85, ink)
	canvas.draw_line(c + Vector2(-s * 0.18, s * 0.02), c + Vector2(-s * 0.18, s * 0.18), ink, 1.4)
	canvas.draw_line(c + Vector2(s * 0.18, s * 0.02), c + Vector2(s * 0.18, s * 0.18), ink, 1.4)
	canvas.draw_line(c + Vector2(-s * 0.2, s * 0.18), c + Vector2(s * 0.2, s * 0.18), ink, 1.4)


static func _crates(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.22, -s * 0.02), Vector2(s * 0.18, s * 0.18)), ink, false, 1.3)
	canvas.draw_rect(Rect2(c + Vector2(0.0, -s * 0.12), Vector2(s * 0.18, s * 0.18)), ink, false, 1.3)
	canvas.draw_rect(Rect2(c + Vector2(s * 0.04, s * 0.04), Vector2(s * 0.18, s * 0.16)), ink, false, 1.3)


static func _promenade(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	_boardwalk(canvas, c + Vector2(0, s * 0.08), s * 0.85, ink)
	_tree(canvas, c + Vector2(0, -s * 0.12), s * 0.12, ink)


static func _event_lot(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	for i in 3:
		var y := -s * 0.16 + i * s * 0.14
		canvas.draw_line(c + Vector2(-s * 0.22, y), c + Vector2(s * 0.22, y), ink, 1.4)
		canvas.draw_rect(Rect2(c + Vector2(-s * 0.1, y - s * 0.05), Vector2(s * 0.2, s * 0.08)), ink, false, 1.1)


static func _siren(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	_cross(canvas, c + Vector2(0, s * 0.04), s * 0.14, ink)
	canvas.draw_arc(c + Vector2(0, -s * 0.12), s * 0.12, PI * 1.15, PI * 1.85, 6, ink, 1.4)


static func _sports_field(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.24, -s * 0.16), Vector2(s * 0.48, s * 0.32)), ink, false, 1.4)
	canvas.draw_line(c + Vector2(0, -s * 0.16), c + Vector2(0, s * 0.16), ink, 1.2)
	canvas.draw_circle(c, s * 0.07, ink, false, 1.2)


static func _loading(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	canvas.draw_rect(Rect2(c + Vector2(-s * 0.24, -s * 0.1), Vector2(s * 0.28, s * 0.22)), ink, false, 1.4)
	canvas.draw_line(c + Vector2(s * 0.04, 0), c + Vector2(s * 0.24, 0), ink, 1.6)
	canvas.draw_line(c + Vector2(s * 0.24, 0), c + Vector2(s * 0.16, -s * 0.08), ink, 1.4)
	canvas.draw_line(c + Vector2(s * 0.24, 0), c + Vector2(s * 0.16, s * 0.08), ink, 1.4)


static func _stall(canvas: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	_awning(canvas, c + Vector2(0, -s * 0.06), s * 0.85, ink)
	canvas.draw_line(c + Vector2(-s * 0.18, s * 0.02), c + Vector2(-s * 0.18, s * 0.18), ink, 1.4)
	canvas.draw_line(c + Vector2(s * 0.18, s * 0.02), c + Vector2(s * 0.18, s * 0.18), ink, 1.4)
	canvas.draw_line(c + Vector2(-s * 0.2, s * 0.18), c + Vector2(s * 0.2, s * 0.18), ink, 1.4)
