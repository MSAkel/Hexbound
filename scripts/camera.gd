extends Camera2D

@export var rune_shake_strength: float = 10.0
@export var rune_shake_duration: float = 0.3

## Screen shake state: applied via offset so world position stays fixed.
var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_timer: float = 0.0
## UI/background live on CanvasLayers and ignore Camera2D offset, so mirror shake there too.
var _shake_canvas_layers: Array[CanvasLayer] = []
var _shake_canvas_layer_bases: Dictionary = {}
# Map ref
var map = HexTileMap

func _ready() -> void:
	GameSettings.ensure_loaded()
	var maps = get_tree().get_nodes_in_group("hex_map_group")
	if maps.size() > 0:
		map = maps[0] as HexTileMap

	EventBus.tile_card_activated.connect(_on_tile_card_activated)
	_cache_shake_canvas_layers()

func _process(delta: float) -> void:
	_update_screen_shake(delta)

func _on_tile_card_activated(_rune: TileCard) -> void:
	shake(rune_shake_strength, rune_shake_duration)

## Start or intensify a screen shake, duration scales with game speed like other turn effects.
func shake(strength: float, duration: float) -> void:
	GameSettings.ensure_loaded()
	if not GameSettings.screen_shake_enabled:
		_apply_shake_offset(Vector2.ZERO)
		_shake_strength = 0.0
		_shake_duration = 0.0
		_shake_timer = 0.0
		return
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
	if not GameSettings.screen_shake_enabled:
		_apply_shake_offset(Vector2.ZERO)
		_shake_strength = 0.0
		_shake_duration = 0.0
		_shake_timer = 0.0
		return
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
