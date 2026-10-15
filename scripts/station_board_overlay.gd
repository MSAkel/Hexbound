class_name StationBoardOverlay
extends Node2D

## Station dressing drawn in map space, between the dashed base hexes and the seated cards.
## Meal slots get a warm fill. A locked second slot is darker and carries a padlock.
## Typed stations tint their regular spots in the type colour. Station events animate here.

const MEAL_SLOT_FILL := Color(0.92, 0.32, 0.36, 0.34)
const MEAL_SLOT_LOCKED_FILL := Color(0.16, 0.1, 0.08, 0.55)
const STATION_TINT_ALPHA := 0.13
## Extra alpha at full flash strength.
const FLASH_ALPHA := 0.35
const LOCK_COLOR := Color(1.0, 0.82, 0.55, 0.9)
const LOCK_SHADOW := Color(0, 0, 0, 0.45)
## Rounded square matching the base tile, inset so the tile border stays visible.
const HEX_INSET := 0.9

var _map: HexTileMap
var _hex_points := PackedVector2Array()
## Running animations, keyed station -> 0..1 progress. Entries exist only while a tween runs.
## Flash brightens a station on type change or level up.
var _flash := {}
## Type tint fade-in. A typed station with no entry draws at full tint.
var _tint_fade := {}
## Padlock break on the second Meal slot.
var _lock_break := {}


func setup(map: HexTileMap) -> void:
	_map = map
	var half := float(HexTileMap.HEX_TEXTURE_SIZE.x) * 0.5 * HEX_INSET
	_hex_points = HexShape.rounded_square(Vector2.ZERO, half)
	EventBus.station_type_changed.connect(_on_station_type_changed)
	EventBus.station_leveled_up.connect(_on_station_leveled_up)
	EventBus.meal_slot_unlocked.connect(_on_meal_slot_unlocked)


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	if _map == null or _map.map_data.is_empty():
		return
	for segment_index in _map.get_segment_count():
		_draw_station(segment_index)


func _draw_station(segment_index: int) -> void:
	var station_type := StationManager.get_station_type(segment_index)
	var flash := float(_flash.get(segment_index, 0.0))
	for hex: Hex in _map.get_hexes_in_segment(segment_index):
		var center := _cell_center(hex.coordinates)
		var meal_slot_index := _map.get_meal_slot_index(hex.coordinates)
		if meal_slot_index >= 0:
			_draw_meal_slot(segment_index, meal_slot_index, center, flash)
		elif station_type != null:
			var color := station_type.color
			color.a = STATION_TINT_ALPHA * float(_tint_fade.get(segment_index, 1.0)) + FLASH_ALPHA * flash
			_draw_hex(center, color)


func _draw_meal_slot(segment_index: int, meal_slot_index: int, center: Vector2, flash: float) -> void:
	var fill := MEAL_SLOT_FILL
	fill.a += FLASH_ALPHA * 0.7 * flash
	if not StationManager.is_meal_slot_unlocked(segment_index, meal_slot_index):
		_draw_hex(center, MEAL_SLOT_LOCKED_FILL)
		_draw_lock(center, 0.0)
	elif meal_slot_index > 0 and _lock_break.has(segment_index):
		var progress := float(_lock_break[segment_index])
		_draw_hex(center, MEAL_SLOT_LOCKED_FILL.lerp(fill, progress))
		_draw_lock(center, progress)
	else:
		_draw_hex(center, fill)


func _draw_hex(center: Vector2, color: Color) -> void:
	if color.a <= 0.0:
		return
	var points := PackedVector2Array()
	for point: Vector2 in _hex_points:
		points.append(center + point)
	draw_colored_polygon(points, color)


## Padlock built from primitives. progress > 0 shakes, lifts the shackle, and fades it out.
func _draw_lock(center: Vector2, progress: float) -> void:
	var alpha := 1.0 - clampf((progress - 0.45) / 0.55, 0.0, 1.0)
	if alpha <= 0.0:
		return
	var shake := sin(progress * 60.0) * 3.0 * (1.0 - progress) if progress > 0.0 else 0.0
	var origin := center + Vector2(shake, 4.0)
	var body := Rect2(origin + Vector2(-13, -4), Vector2(26, 20))
	var lift := -10.0 * clampf(progress * 2.0, 0.0, 1.0)
	var lock_color := LOCK_COLOR
	lock_color.a *= alpha
	var shadow := LOCK_SHADOW
	shadow.a *= alpha
	draw_rect(Rect2(body.position + Vector2(2, 2), body.size), shadow)
	draw_arc(origin + Vector2(0, -4 + lift), 9.0, PI, TAU, 16, lock_color, 4.0, true)
	draw_rect(body, lock_color)
	draw_circle(origin + Vector2(0, 5), 3.0, MEAL_SLOT_LOCKED_FILL)


func _cell_center(coords: Vector2i) -> Vector2:
	return _map.base_layer.position + _map.base_layer.map_to_local(coords)


#region --- Station animations ---

func _on_station_type_changed(segment_index: int, _type_id: String) -> void:
	if GameManager.skip_presentation:
		queue_redraw()
		return
	_animate(_flash, segment_index, 1.0, 0.0, 0.9)
	_animate(_tint_fade, segment_index, 0.0, 1.0, 0.9)


func _on_station_leveled_up(segment_index: int, _level: int) -> void:
	if GameManager.skip_presentation:
		return
	_animate(_flash, segment_index, 0.8, 0.0, 0.6)


func _on_meal_slot_unlocked(segment_index: int) -> void:
	if GameManager.skip_presentation:
		queue_redraw()
		return
	_animate(_lock_break, segment_index, 0.0, 1.0, 0.75)
	_spawn_unlock_burst(segment_index)


## Tweens track[segment_index] from one value to another, redrawing each step, then drops the entry.
func _animate(track: Dictionary, segment_index: int, from: float, to: float, duration: float) -> void:
	var tween := create_tween()
	tween.tween_method(
		func(value: float) -> void:
			track[segment_index] = value
			queue_redraw(),
		from,
		to,
		duration / maxf(GameManager.game_speed, 0.01)
	)
	tween.tween_callback(
		func() -> void:
			track.erase(segment_index)
			queue_redraw()
	)


## Spark burst from the unlocked slot, reusing the trigger link particles.
func _spawn_unlock_burst(segment_index: int) -> void:
	var meal_coords := _map.get_meal_slot_coords(segment_index)
	if meal_coords.size() < 2:
		return
	var center := _cell_center(meal_coords[1])
	TriggerLinkBurst.spawn(self, center + Vector2(0, -30), center + Vector2(0, 10))
	TriggerLinkBurst.spawn(self, center + Vector2(-30, 0), center + Vector2(30, 0))

#endregion --- Station animations ---
