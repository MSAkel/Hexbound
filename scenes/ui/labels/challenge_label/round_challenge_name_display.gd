extends Control

## Center-screen challenge reveal that docks to a persistent top banner.

enum Phase { HIDDEN, INTRO, DOCKING, DOCKED }

const INTRO_IN_DURATION := 0.35
const INTRO_HOLD_DURATION := 1.75
const DOCK_DURATION := 0.6
const SKIP_DOCK_DURATION := 0.28

const CENTER_NAME_SIZE := 96
const DOCKED_NAME_SIZE := 42
const CENTER_KICKER_SIZE := 28
const DOCKED_KICKER_SIZE := 16
const CENTER_ICON_SIZE := Vector2(48, 48)
const DOCKED_ICON_SIZE := Vector2(28, 28)
const CENTER_WAVE_AMP := 50.0
const DOCKED_WAVE_AMP := 16.0
const CENTER_NAME_OUTLINE := 14
const DOCKED_NAME_OUTLINE := 8

const DIM_ALPHA := 0.48
const BANNER_INTRO_SCALE := Vector2(0.82, 0.82)

const CENTER_OFFSETS := {
	"left": -560.0,
	"top": -160.0,
	"right": 560.0,
	"bottom": 160.0,
}
const DOCKED_OFFSETS := {
	"left": -420.0,
	"top": 10.0,
	"right": 420.0,
	"bottom": 96.0,
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
	# Click anywhere during the center beat to dock early.
	if _phase != Phase.INTRO:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_begin_dock(true)


func _on_challenge_banner_shown(challenge_name: String) -> void:
	_reveal_id += 1
	var reveal_id := _reveal_id
	_challenge_name = challenge_name
	_apply_copy()
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
	hide()


func _play_intro() -> void:
	_kill_tween()
	_phase = Phase.INTRO
	mouse_filter = Control.MOUSE_FILTER_STOP

	var intro_in := INTRO_IN_DURATION / GameManager.game_speed
	var hold := INTRO_HOLD_DURATION / GameManager.game_speed

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
	_tween.chain()
	_tween.tween_interval(hold)
	_tween.tween_callback(_begin_dock.bind(false))


func _begin_dock(skipped: bool = false) -> void:
	if _phase != Phase.INTRO:
		return

	_kill_tween()
	_phase = Phase.DOCKING
	var duration := (SKIP_DOCK_DURATION if skipped else DOCK_DURATION) / GameManager.game_speed

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(banner, "anchor_top", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN_OUT
	)
	_tween.tween_property(banner, "anchor_bottom", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN_OUT
	)
	_tween.tween_property(banner, "offset_left", DOCKED_OFFSETS.left, duration).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN_OUT
	)
	_tween.tween_property(banner, "offset_top", DOCKED_OFFSETS.top, duration).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN_OUT
	)
	_tween.tween_property(banner, "offset_right", DOCKED_OFFSETS.right, duration).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN_OUT
	)
	_tween.tween_property(banner, "offset_bottom", DOCKED_OFFSETS.bottom, duration).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_IN_OUT
	)
	_tween.tween_property(dim_overlay, "color:a", 0.0, duration * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	_tween.tween_property(description_label, "modulate:a", 0.0, duration * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	_tween.tween_property(skip_hint, "modulate:a", 0.0, duration * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	_tween.tween_property(challenge_icon, "custom_minimum_size", DOCKED_ICON_SIZE, duration)
	_tween.tween_method(_set_name_font_size, _name_font_size, float(DOCKED_NAME_SIZE), duration)
	_tween.tween_method(_set_kicker_font_size, float(CENTER_KICKER_SIZE), float(DOCKED_KICKER_SIZE), duration)
	_tween.tween_method(_set_wave_amp, _wave_amp, DOCKED_WAVE_AMP, duration)
	_tween.tween_method(_set_name_outline, float(CENTER_NAME_OUTLINE), float(DOCKED_NAME_OUTLINE), duration)
	_tween.chain()
	_tween.tween_callback(_finish_dock)


func _finish_dock() -> void:
	_phase = Phase.DOCKED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_label.hide()
	skip_hint.hide()
	_apply_docked_layout()
	_center_banner_pivot()


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


func _apply_docked_layout() -> void:
	banner.anchor_left = 0.5
	banner.anchor_top = 0.0
	banner.anchor_right = 0.5
	banner.anchor_bottom = 0.0
	banner.offset_left = DOCKED_OFFSETS.left
	banner.offset_top = DOCKED_OFFSETS.top
	banner.offset_right = DOCKED_OFFSETS.right
	banner.offset_bottom = DOCKED_OFFSETS.bottom
	_set_name_font_size(float(DOCKED_NAME_SIZE))
	_set_kicker_font_size(float(DOCKED_KICKER_SIZE))
	_set_wave_amp(DOCKED_WAVE_AMP)
	_set_name_outline(float(DOCKED_NAME_OUTLINE))
	challenge_icon.custom_minimum_size = DOCKED_ICON_SIZE
	banner.scale = Vector2.ONE
	banner.modulate.a = 1.0
	dim_overlay.color.a = 0.0


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
