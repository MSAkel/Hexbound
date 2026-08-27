extends Control

## Center-screen challenge reveal. Stays until click, then flies into ChallengeContainer.

enum Phase { HIDDEN, INTRO, DOCKING, DOCKED }

const INTRO_IN_DURATION := 0.35
const DOCK_DURATION := 0.6

const CENTER_NAME_SIZE := 96
const DOCKED_NAME_SIZE := 18
const CENTER_KICKER_SIZE := 28
const DOCKED_KICKER_SIZE := 12
const CENTER_ICON_SIZE := Vector2(48, 48)
const DOCKED_ICON_SIZE := Vector2(28, 28)
const CENTER_WAVE_AMP := 50.0
const DOCKED_WAVE_AMP := 8.0
const CENTER_NAME_OUTLINE := 14
const DOCKED_NAME_OUTLINE := 4

const DIM_ALPHA := 0.48
const BANNER_INTRO_SCALE := Vector2(0.82, 0.82)

const CENTER_OFFSETS := {
	"left": -560.0,
	"top": -160.0,
	"right": 560.0,
	"bottom": 160.0,
}

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var banner: VBoxContainer = $Banner
@onready var challenge_icon: TextureRect = $Banner/KickerRow/ChallengeIcon
@onready var kicker_label: Label = $Banner/KickerRow/KickerLabel
@onready var challenge_label: RichTextLabel = $Banner/ChallengeName
@onready var description_label: Label = $Banner/Description
@onready var skip_hint: Label = $Banner/SkipHint

var _phase: Phase = Phase.HIDDEN
var _reveal_id := 0
var _challenge_name := ""
var _tween: Tween
var _name_font_size := float(CENTER_NAME_SIZE)
var _wave_amp := CENTER_WAVE_AMP


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.challenge_banner_shown.connect(_on_challenge_banner_shown)
	EventBus.challenge_banner_hidden.connect(_on_challenge_banner_hidden)


func _gui_input(event: InputEvent) -> void:
	# Click anywhere after the pop-in to dock. The hold is the read beat.
	if _phase != Phase.INTRO:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_begin_dock()


func _on_challenge_banner_shown(challenge_name: String, dock_immediately: bool = false) -> void:
	_reveal_id += 1
	var reveal_id := _reveal_id
	_challenge_name = challenge_name
	_apply_copy()

	if dock_immediately:
		_show_docked_immediately()
		return

	_prepare_intro_visuals()
	show()
	await get_tree().process_frame
	if reveal_id != _reveal_id or not is_inside_tree():
		return

	_center_banner_pivot()
	_play_intro()


func _on_challenge_banner_hidden() -> void:
	_reveal_id += 1
	_kill_tween()
	_phase = Phase.HIDDEN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.top_level = false
	hide()


func _play_intro() -> void:
	_kill_tween()
	_phase = Phase.INTRO
	mouse_filter = Control.MOUSE_FILTER_STOP

	var intro_in := INTRO_IN_DURATION / GameManager.game_speed

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(dim_overlay, "color:a", DIM_ALPHA, intro_in).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	_tween.tween_property(banner, "modulate:a", 1.0, intro_in).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	_tween.tween_property(banner, "scale", Vector2.ONE, intro_in).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)


func _begin_dock() -> void:
	if _phase != Phase.INTRO:
		return

	_kill_tween()
	_phase = Phase.DOCKING
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var duration := DOCK_DURATION / GameManager.game_speed

	# Intro-only copy leaves the overlay. The chip shows name and description after landing.
	description_label.hide()
	skip_hint.hide()

	# Leave the layout anchors so the fly-in is a free transform into the chip.
	var start_global := banner.global_position
	banner.top_level = true
	banner.global_position = start_global
	_center_banner_pivot()

	var start_center := banner.get_global_rect().get_center()
	var target_rect := _get_dock_target_global_rect()
	var destination := banner.global_position + (target_rect.get_center() - start_center)
	var start_size := banner.size
	var scale_to := Vector2(
		target_rect.size.x / maxf(start_size.x, 1.0),
		target_rect.size.y / maxf(start_size.y, 1.0)
	)

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(banner, "global_position", destination, duration).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN_OUT
	)
	_tween.tween_property(banner, "scale", scale_to, duration).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN
	)
	_tween.tween_property(banner, "modulate:a", 0.0, duration * 0.85).set_ease(Tween.EASE_IN)
	_tween.tween_property(dim_overlay, "color:a", 0.0, duration * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	_tween.tween_property(challenge_icon, "custom_minimum_size", DOCKED_ICON_SIZE, duration)
	_tween.tween_method(_set_name_font_size, _name_font_size, float(DOCKED_NAME_SIZE), duration)
	_tween.tween_method(_set_kicker_font_size, float(CENTER_KICKER_SIZE), float(DOCKED_KICKER_SIZE), duration)
	_tween.tween_method(_set_wave_amp, _wave_amp, DOCKED_WAVE_AMP, duration)
	_tween.tween_method(_set_name_outline, float(CENTER_NAME_OUTLINE), float(DOCKED_NAME_OUTLINE), duration)
	_tween.chain()
	_tween.set_parallel(false)
	_tween.tween_callback(_finish_dock)


func _finish_dock() -> void:
	_phase = Phase.DOCKED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.top_level = false
	banner.scale = Vector2.ONE
	hide()
	# RoundFlow holds the first turn until this lands. The chip then shows the copy.
	EventBus.challenge_reveal_finished.emit()


func _show_docked_immediately() -> void:
	# Save reload already knows the challenge. Skip the overlay and show the chip.
	_kill_tween()
	_phase = Phase.DOCKED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	EventBus.challenge_reveal_finished.emit()


func _prepare_intro_visuals() -> void:
	_phase = Phase.INTRO
	_apply_center_layout()
	_set_name_font_size(float(CENTER_NAME_SIZE))
	_set_kicker_font_size(float(CENTER_KICKER_SIZE))
	_set_wave_amp(CENTER_WAVE_AMP)
	_set_name_outline(float(CENTER_NAME_OUTLINE))
	challenge_icon.custom_minimum_size = CENTER_ICON_SIZE
	description_label.show()
	description_label.modulate.a = 1.0
	skip_hint.show()
	skip_hint.modulate.a = 1.0
	dim_overlay.color.a = 0.0
	banner.top_level = false
	banner.modulate.a = 0.0
	banner.scale = BANNER_INTRO_SCALE


func _apply_copy() -> void:
	_refresh_name_bbcode()
	description_label.text = ChallengeManager.get_challenge_description(ChallengeManager.active_challenge)
	kicker_label.text = "CHALLENGE ROUND %d" % GameManager.current_round


func _apply_center_layout() -> void:
	banner.anchor_left = 0.5
	banner.anchor_top = 0.5
	banner.anchor_right = 0.5
	banner.anchor_bottom = 0.5
	banner.offset_left = CENTER_OFFSETS.left
	banner.offset_top = CENTER_OFFSETS.top
	banner.offset_right = CENTER_OFFSETS.right
	banner.offset_bottom = CENTER_OFFSETS.bottom
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH


func _get_dock_target_global_rect() -> Rect2:
	var slot := get_tree().get_first_node_in_group("challenge_hud_slot") as Control
	if slot == null:
		var viewport := get_viewport_rect()
		return Rect2(viewport.size - Vector2(98.0, 98.0), Vector2(66.0, 66.0))
	return slot.get_global_rect()


func _set_name_font_size(value: float) -> void:
	_name_font_size = value
	challenge_label.add_theme_font_size_override("normal_font_size", int(round(value)))


func _set_kicker_font_size(value: float) -> void:
	kicker_label.add_theme_font_size_override("font_size", int(round(value)))


func _set_wave_amp(value: float) -> void:
	_wave_amp = value
	_refresh_name_bbcode()


func _set_name_outline(value: float) -> void:
	challenge_label.add_theme_constant_override("outline_size", int(round(value)))


func _refresh_name_bbcode() -> void:
	challenge_label.text = "[wave amp=%d freq=2]%s[/wave]" % [int(round(_wave_amp)), _challenge_name]


func _center_banner_pivot() -> void:
	banner.pivot_offset = banner.size * 0.5


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
