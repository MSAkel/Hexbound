extends Node

## Shared menu-flow backdrop that survives scene changes so circular drift never resets.

const VIEW_SCENE := preload("res://scenes/ui/menu_background/menu_background_view.tscn")
const DRIFT_SHADER := preload("res://scenes/ui/menu_background/menu_background_drift.gdshader")

const MENU_FLOW_SCENES: Array[String] = [
	ScenePaths.MAIN_MENU,
	ScenePaths.DEVELOPER_MENU,
	ScenePaths.CHARACTER_SELECTION,
	ScenePaths.SEGMENT_PASSIVES,
]

var _view: Control
var _clip_root: Control
var _drift_material: ShaderMaterial
var _motion_time: float = 0.0
var _last_viewport_size := Vector2.ZERO


func _ready() -> void:
	_view = VIEW_SCENE.instantiate() as Control
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.z_index = -100
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.set_offsets_preset(Control.PRESET_FULL_RECT)
	_clip_root = _view.get_node("ClipRoot") as Control

	var root := get_tree().root
	root.call_deferred("add_child", _view)
	root.call_deferred("move_child", _view, 0)
	get_tree().scene_changed.connect(_on_scene_changed)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	call_deferred("_finish_setup")


func _finish_setup() -> void:
	await get_tree().process_frame
	while _view != null and not _view.is_inside_tree():
		await get_tree().process_frame
	_setup_drift_material()
	_sync_view_to_viewport()
	_refresh_visibility()


func _process(delta: float) -> void:
	if _drift_material == null:
		return
	# Keep advancing time while hidden so re-entry does not snap the drift angle.
	_motion_time += delta
	if _view == null or not _view.visible:
		return
	_drift_material.set_shader_parameter("motion_time", _motion_time)


func _on_scene_changed() -> void:
	call_deferred("_refresh_visibility")


func _refresh_visibility() -> void:
	if _view == null:
		return
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	_view.visible = current_scene.scene_file_path in MENU_FLOW_SCENES


func _setup_drift_material() -> void:
	_drift_material = ShaderMaterial.new()
	_drift_material.shader = DRIFT_SHADER
	var background := _clip_root.get_node("Background") as TextureRect
	var foreground := _clip_root.get_node("Foreground") as TextureRect
	# One shared material keeps art and tint locked while only UVs move.
	background.material = _drift_material
	foreground.material = _drift_material


func _on_viewport_size_changed() -> void:
	_sync_view_to_viewport()


func _sync_view_to_viewport() -> void:
	if _view == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size == _last_viewport_size:
		return
	_last_viewport_size = viewport_size

	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.set_offsets_preset(Control.PRESET_FULL_RECT)
	_clip_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clip_root.set_offsets_preset(Control.PRESET_FULL_RECT)
