extends Camera2D

@export var velocity: int = 15
@export var zoom_speed: float = 0.02

var mouse_wheel_scrolling_up := false
var mouse_wheel_scrolling_down := false

# Map boundaries
var left_boundary: float
var right_boundary: float
var top_boundary: float
var bottom_boundary: float

# Map ref
var map = HexTileMap

func _ready() -> void:
	var maps = get_tree().get_nodes_in_group("hex_map_group")
	if maps.size() > 0:
		map = maps[0] as HexTileMap
	left_boundary = to_global(map.map_to_local(Vector2i(0,0))).x + 50
	right_boundary = to_global(map.map_to_local(Vector2i(map.width,0))).x - 50 
	top_boundary = to_global(map.map_to_local(Vector2i(0,0))).y + 50 
	bottom_boundary = to_global(map.map_to_local(Vector2i(0, map.height))).y - 50 
	
func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("map_right") && position.x < right_boundary:
		position += Vector2(velocity, 0)
	
	if Input.is_action_pressed("map_left") && position.x > left_boundary:
		position += Vector2(-velocity, 0)
	
	if Input.is_action_pressed("map_up") && position.y > top_boundary:
		position += Vector2(0, -velocity)

	if Input.is_action_pressed("map_down") && position.y < bottom_boundary:
		position += Vector2(0, velocity)
		
	if Input.is_action_pressed("zoom_in") || mouse_wheel_scrolling_up:
		if zoom < Vector2(2.0, 2.0):
			zoom += Vector2(zoom_speed, zoom_speed)
	
	if Input.is_action_pressed("zoom_out") || mouse_wheel_scrolling_down:
		if zoom > Vector2(0.3, 0.3):
			zoom -= Vector2(zoom_speed, zoom_speed)
			
	if Input.is_action_just_released("mouse_zoom_in"):
		mouse_wheel_scrolling_up = true
	
	if !Input.is_action_just_released("mouse_zoom_in"):
		mouse_wheel_scrolling_up = false
		
	if Input.is_action_just_released("mouse_zoom_out"):
		mouse_wheel_scrolling_down = true
	
	if !Input.is_action_just_released("mouse_zoom_out"):
		mouse_wheel_scrolling_down = false
