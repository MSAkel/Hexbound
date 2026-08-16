extends Camera2D

signal intro_zoom_finished

@export var velocity: int = 15
@export var zoom_speed: float = 0.02
@export var initial_zoom_duration: float = 1.5
## Multiplier applied to the playable zoom at intro start (< 1 = pulled back, then zooms in).
@export var intro_start_zoom_factor: float = 0.72
@export var rune_shake_strength: float = 10.0
@export var rune_shake_duration: float = 0.3

var mouse_wheel_scrolling_up := false
var mouse_wheel_scrolling_down := false

## Screen shake state: applied via offset so world position stays fixed.
var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
## UI/background live on CanvasLayers and ignore Camera2D offset, so mirror shake there too.
var _shake_canvas_layers: Array[CanvasLayer] = []
var _shake_canvas_layer_bases: Dictionary = {}
## Blocks player zoom while the scene-enter zoom tween is running.
var _intro_zoom_active := false
## Playable zoom captured before the intro pulls the camera back.
var _intro_target_zoom: Vector2 = Vector2.ONE

# Map ref
var map = HexTileMap

@onready var zoom_sound: AudioStreamPlayer2D = $ZoomSound

func _ready() -> void:
	var maps = get_tree().get_nodes_in_group("hex_map_group")
	if maps.size() > 0:
		map = maps[0] as HexTileMap

	## Park at the pulled-back intro zoom before the first frame draws.
	_intro_target_zoom = zoom
	zoom = _intro_target_zoom * intro_start_zoom_factor
	_intro_zoom_active = true
	
	EventBus.tile_card_activated.connect(_on_tile_card_activated)
	_cache_shake_canvas_layers()

func _process(delta: float) -> void:
	_update_screen_shake(delta)

func _physics_process(_delta: float) -> void:
	# Ignore manual zoom while the enter-run zoom settles on the playable level.
	if _intro_zoom_active:
		return
		
	if Input.is_action_pressed("zoom_in") || mouse_wheel_scrolling_up:
		if zoom < Vector2(2.0, 2.0):
			zoom += Vector2(zoom_speed, zoom_speed)
	
	if Input.is_action_pressed("zoom_out") || mouse_wheel_scrolling_down:
		if zoom > Vector2(0.4, 0.4):
			zoom -= Vector2(zoom_speed, zoom_speed)
			
	mouse_wheel_scrolling_up = Input.is_action_just_released("mouse_zoom_in")
	mouse_wheel_scrolling_down = Input.is_action_just_released("mouse_zoom_out")


## Eases from the pulled-back intro zoom into the scene's configured playable zoom.
func play_intro_zoom() -> void:
	_intro_zoom_active = true

	if zoom_sound:
		zoom_sound.play()

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "zoom", _intro_target_zoom, initial_zoom_duration)
	await tween.finished

	_intro_zoom_active = false
	intro_zoom_finished.emit()

func _on_tile_card_activated(_rune: TileCard) -> void:
	shake(rune_shake_strength, rune_shake_duration)

## Start or intensify a screen shake, duration scales with game speed like other turn effects.
func shake(strength: float, duration: float) -> void:
	var scaled_duration := duration / GameManager.game_speed
	_shake_strength = max(_shake_strength, strength)
	_shake_duration = max(_shake_duration, scaled_duration)
	_shake_timer = _shake_duration

## Collect screen-space layers from the scene root so shake hits UI and background too.
func _cache_shake_canvas_layers() -> void:
	_shake_canvas_layers.clear()
	_shake_canvas_layer_bases.clear()
	var scene_root := get_parent()
	if scene_root == null:
		return
	for child in scene_root.get_children():
		if child is CanvasLayer:
			var layer := child as CanvasLayer
			_shake_canvas_layers.append(layer)
			_shake_canvas_layer_bases[layer] = layer.offset

## Camera offset moves the board, CanvasLayer offsets move everything drawn in screen space.
func _apply_shake_offset(shake_offset: Vector2) -> void:
	offset = shake_offset
	for layer in _shake_canvas_layers:
		if not is_instance_valid(layer):
			continue
		layer.offset = _shake_canvas_layer_bases.get(layer, Vector2.ZERO) + shake_offset

func _update_screen_shake(delta: float) -> void:
	if _shake_timer <= 0.0:
		_apply_shake_offset(Vector2.ZERO)
		_shake_strength = 0.0
		_shake_duration = 0.0
		return
	
	_shake_timer = max(_shake_timer - delta, 0.0)
	var progress := _shake_timer / _shake_duration if _shake_duration > 0.0 else 0.0
	var current_strength := _shake_strength * progress
	var shake_offset := Vector2(
		randf_range(-current_strength, current_strength),
		randf_range(-current_strength, current_strength)
	)
	_apply_shake_offset(shake_offset)
