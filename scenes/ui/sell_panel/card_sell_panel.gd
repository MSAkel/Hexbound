class_name CardSellPanel
extends PanelContainer

## Drop zone in the bottom-left corner. Drag a hand card, a staff member or a condiment here and release to sell it.

const SELL_VALUE := 2

## Resting panel sits back so it does not compete with the board.
const IDLE_MODULATE := Color(1, 1, 1, 0.88)
const ARMED_MODULATE := Color(1.12, 1.05, 0.9)
const HOVER_MODULATE := Color(0.9, 1.15, 0.85)
const HOVER_SCALE := 1.04
# The art pops when a sold card lands on the panel.
const SELL_PULSE_SCALE := 1.12
const SELL_PULSE_RISE := 0.08
const SELL_PULSE_SETTLE := 0.22

@onready var _art: TextureRect = %Art

## True while a hand card is picked up.
var _card_dragged := false
## Staff slot being dragged, or -1. Staff sell for their own value, not SELL_VALUE.
var _drag_staff_slot := -1
## True while a belt condiment is held. Condiments sell for their own value too.
var _condiment_dragged := false
var _pulse_tween: Tween


func _ready() -> void:
	add_to_group("card_sell_panel")
	EventBus.card_drag_started.connect(_on_card_drag_started)
	EventBus.card_drag_ended.connect(_on_card_drag_ended)
	EventBus.staff_drag_started.connect(_on_staff_drag_started)
	EventBus.staff_drag_ended.connect(_on_staff_drag_ended)
	EventBus.condiment_drag_started.connect(_on_condiment_drag_started)
	EventBus.condiment_drag_ended.connect(_on_condiment_drag_ended)
	_refresh_state()


func _process(_delta: float) -> void:
	if not _is_armed():
		return
	_refresh_state()


func _on_card_drag_started(_card: CardUI) -> void:
	_card_dragged = true
	_refresh_state()


func _on_card_drag_ended(_card: CardUI, _outcome: int) -> void:
	_card_dragged = false
	_refresh_state()


func _on_staff_drag_started(slot: int) -> void:
	_drag_staff_slot = slot
	_refresh_state()


func _on_staff_drag_ended() -> void:
	_drag_staff_slot = -1
	_refresh_state()


func _on_condiment_drag_started(_slot: int) -> void:
	_condiment_dragged = true
	_refresh_state()


func _on_condiment_drag_ended() -> void:
	_condiment_dragged = false
	_refresh_state()


## Used by CondimentBelt when the player releases a dragged condiment. True when it was sold.
func try_sell_condiment(slot: int) -> bool:
	if not is_cursor_over():
		return false
	if CondimentManager.sell_slot(slot) < 0:
		return false
	AudioManager.play_sfx(UISounds.GOLD_GAINED)
	play_sell_pulse()
	return true


## Used by StaffRail when the player releases a dragged staff member. True when it was sold.
func try_sell_staff(slot: int) -> bool:
	if not is_cursor_over():
		return false
	if StaffManager.sell_staff(slot) < 0:
		return false
	AudioManager.play_sfx(UISounds.GOLD_GAINED)
	return true


## Sells without a pointer check. Controller players pick Sell as a drop target instead.
func sell_staff_from_controller(slot: int) -> bool:
	if StaffManager.sell_staff(slot) < 0:
		return false
	AudioManager.play_sfx(UISounds.GOLD_GAINED)
	return true


func _is_armed() -> bool:
	return _card_dragged or _drag_staff_slot >= 0 or _condiment_dragged


## Pays out for a hand card dropped on the panel. CardPlacementHandler removes the card.
func sell_card() -> void:
	EconomyManager.add(SELL_VALUE)
	AudioManager.play_sfx(UISounds.GOLD_GAINED)


## Pops the art as the sold card's ghost lands on the panel.
func play_sell_pulse() -> void:
	if GameManager.skip_presentation:
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_art.pivot_offset = _art.size * 0.5
	_art.scale = Vector2.ONE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(
		_art, "scale", Vector2.ONE * SELL_PULSE_SCALE, SELL_PULSE_RISE
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(
		_art, "scale", Vector2.ONE, SELL_PULSE_SETTLE
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## True when a card or staff released now would land on the panel.
func is_cursor_over() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


## Idle, armed while a card is dragged, and hover while it sits over the panel.
func _refresh_state() -> void:
	var armed := _is_armed()
	var hovered := armed and is_cursor_over()
	if hovered:
		modulate = HOVER_MODULATE
	elif armed:
		modulate = ARMED_MODULATE
	else:
		modulate = IDLE_MODULATE
	# Leave scale alone while the sell pulse owns it.
	if _pulse_tween != null and _pulse_tween.is_valid():
		return
	_art.pivot_offset = _art.size * 0.5
	_art.scale = Vector2.ONE * (HOVER_SCALE if hovered else 1.0)
