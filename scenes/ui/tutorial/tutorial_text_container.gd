extends PanelContainer

## One-shot banner at the top of the run HUD.

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

const STEP_TEXTS: PackedStringArray = [
	"Select a card to place it into an empty tile.\nYou must reach the required score for the current round before your turns reach to 0.",
	"You can hover over a tile to check its stats.\nSupport cards abilities are not always limited to their own segments",
	"The turn ends when there are only two remaining cards in your hand.\nYou win once you have completed nine rounds.",
	"Every segment measures Energy and Mult separately. Energy × Mult becomes that segment's Score, then Scores add for the turn.\nMult only applies to Energy in its own segment. Gold is not multiplied.",
]

const FADE_OUT_DURATION := 0.18
const FADE_IN_DURATION := 0.28
const PUNCH_SCALE := Vector2(1.04, 1.08)

@onready var label: Label = $Label

var _step: int = 0
var _cards_placed: int = 0
var _active: bool = false
var _text_tween: Tween


func _ready() -> void:
	add_to_group("tutorial_banner")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_update_pivot)
	_update_pivot()

	EventBus.card_played.connect(_on_card_played)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.turn_changed.connect(_on_turn_changed)

	# First run consumes the flag so later runs stay quiet unless settings re-enables it.
	if GameSettings.consume_tutorial_on_run_start():
		_begin_tutorial()
	else:
		hide()


func is_tutorial_active() -> bool:
	return _active


func set_tutorial_visible_from_settings(should_show: bool) -> void:
	if should_show:
		_begin_tutorial()
	else:
		_active = false
		hide()
		if _text_tween != null and _text_tween.is_valid():
			_text_tween.kill()


func _begin_tutorial() -> void:
	_active = true
	_step = 0
	_cards_placed = 0
	label.text = STEP_TEXTS[0]
	show()
	_play_text_change_animation(true)


func _on_card_played(_card_ui: CardUI) -> void:
	if not _active:
		return
	_cards_placed += 1
	# First placement explains support range. Second explains hover and hand size.
	if _cards_placed == 1:
		_advance_to(1)
	elif _cards_placed >= 2:
		_advance_to(2)


func _on_turn_ended() -> void:
	if not _active or not visible:
		return
	# Hide during scoring. remaining_turns has not decremented yet.
	if GameManager.current_round != 1:
		return
	var turn_number := GameManager.get_turn_number()
	# Third text leaves when turn 1 ends. Fourth text leaves when turn 2 ends.
	if turn_number == 1 and _step >= 2:
		_hide_banner(false)
	elif turn_number >= 2:
		_hide_banner(true)


func _on_turn_changed() -> void:
	if not _active:
		return
	# Later rounds reuse turn_changed. Keep this copy on the opening round only.
	if GameManager.current_round != 1:
		return
	if GameManager.get_turn_number() >= 2:
		_advance_to(3)


func _advance_to(next_step: int) -> void:
	if next_step <= _step or next_step >= STEP_TEXTS.size():
		return
	var was_hidden := not visible
	_step = next_step
	show()
	_play_text_change_animation(was_hidden)


func _hide_banner(finish_tutorial: bool) -> void:
	if _text_tween != null and _text_tween.is_valid():
		_text_tween.kill()

	if finish_tutorial:
		_active = false

	_text_tween = create_tween()
	_text_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_text_tween.set_ease(Tween.EASE_IN)
	_text_tween.set_trans(Tween.TRANS_QUAD)
	_text_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	_text_tween.tween_callback(hide)


func _play_text_change_animation(is_first_show: bool) -> void:
	if _text_tween != null and _text_tween.is_valid():
		_text_tween.kill()

	# Scale from the panel center so the punch reads as a notice, not a layout shift.
	_update_pivot()
	AudioManager.play_sfx(UI_SOUNDS.SELECT)

	_text_tween = create_tween()
	_text_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_text_tween.set_ease(Tween.EASE_OUT)
	_text_tween.set_trans(Tween.TRANS_QUAD)

	if is_first_show:
		_apply_step_text()
		modulate.a = 0.0
		scale = Vector2(0.94, 0.94)
	else:
		_text_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
		_text_tween.parallel().tween_property(self, "scale", Vector2(0.96, 0.96), FADE_OUT_DURATION)
		_text_tween.tween_callback(_apply_step_text)

	_text_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	_text_tween.parallel().tween_property(self, "scale", PUNCH_SCALE, FADE_IN_DURATION * 0.55)
	_text_tween.tween_property(self, "scale", Vector2.ONE, FADE_IN_DURATION * 0.45)


func _apply_step_text() -> void:
	label.text = STEP_TEXTS[_step]


func _update_pivot() -> void:
	pivot_offset = size * 0.5
