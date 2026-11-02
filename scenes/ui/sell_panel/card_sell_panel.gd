class_name CardSellPanel
extends PanelContainer

## Bottom-left corner of the run screen: the current chef's portrait above the gold panel.
## The gold panel shows the player's gold. While a hand card, staff member or condiment is dragged
## over the corner it shows that item's sell price instead. Release there to sell it.
## Hovering the portrait shows the chef's name and ability.

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
## Takes the drag tint, hover scale and sell pulse. The chef portrait stays as it is.
@onready var _gold_panel: TextureRect = %GoldPanel
@onready var _gold_label: Label = %GoldLabel
## Text colour for the sell price, so it reads as a gain rather than the wallet.
const SELL_PRICE_COLOR := Color(0.62, 1.0, 0.55)

## True while a hand card is picked up.
var _card_dragged := false
## Staff slot being dragged, or -1. Staff sell for their own value, not SELL_VALUE.
var _drag_staff_slot := -1
## True while a belt condiment is held. Condiments sell for their own value too.
var _condiment_dragged := false
## Belt slot of the condiment being dragged, or -1.
var _drag_condiment_slot := -1
var _pulse_tween: Tween
var _gold_counter: CountingNumber
var _gold_color: Color
## True while the gold panel shows a sell price instead of the wallet.
var _showing_price := false


func _ready() -> void:
	add_to_group("card_sell_panel")
	_gold_color = _gold_label.get_theme_color("font_color")
	_gold_counter = CountingNumber.for_label(self, _gold_label)
	_gold_counter.snap_to(EconomyManager.amount)
	_show_chef_portrait()
	_art.mouse_entered.connect(_on_art_mouse_entered)
	_art.mouse_exited.connect(_on_art_mouse_exited)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.run_state_loaded.connect(_on_run_state_loaded)
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


func _on_condiment_drag_started(slot: int) -> void:
	_condiment_dragged = true
	_drag_condiment_slot = slot
	_refresh_state()


func _on_condiment_drag_ended() -> void:
	_condiment_dragged = false
	_drag_condiment_slot = -1
	_refresh_state()


## The bound chef's in-game portrait. Chefs without one fall back to their selection portrait.
func _show_chef_portrait() -> void:
	var chef := GameManager.selected_chef
	if chef == null:
		return
	var portrait := chef.get_ingame_portrait()
	if portrait != null:
		_art.texture = portrait


func _on_art_mouse_entered() -> void:
	var chef := GameManager.selected_chef
	# The corner is a sell target during a drag, so the tooltip stays out of the way.
	if chef == null or _is_armed():
		return
	var ability := CardKeywordGlossary.to_plain(chef.speciality_description)
	EventBus.show_tooltip_above.emit("%s
%s" % [chef.display_name, ability], _art.get_global_rect())


func _on_art_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "", Rect2())


func _on_gold_changed(amount: int) -> void:
	# A sell price on show is replaced by the wallet once the drag ends.
	if _showing_price:
		return
	_gold_counter.play(amount)


func _on_run_state_loaded() -> void:
	_show_chef_portrait()
	_gold_counter.snap_to(EconomyManager.amount)


## Gold the dragged item sells for, or -1 when nothing sellable is held.
func _held_sell_price() -> int:
	if _card_dragged:
		return SELL_VALUE
	if _drag_staff_slot >= 0:
		var staff := StaffManager.get_staff(_drag_staff_slot)
		return staff.get_sell_value() if staff != null else -1
	if _condiment_dragged and _drag_condiment_slot >= 0 and _drag_condiment_slot < CondimentManager.belt.size():
		var condiment: Condiment = CondimentManager.belt[_drag_condiment_slot]
		return condiment.get_sell_value() if condiment != null else -1
	return -1


## Wallet by default. The held item's sell price while it hovers the corner.
func _refresh_gold_text(hovered: bool) -> void:
	var price := _held_sell_price() if hovered else -1
	if price >= 0:
		_gold_counter.kill()
		_showing_price = true
		_gold_label.text = "+%d" % price
		_gold_label.add_theme_color_override("font_color", SELL_PRICE_COLOR)
		return
	if not _showing_price:
		return
	_showing_price = false
	_gold_label.add_theme_color_override("font_color", _gold_color)
	_gold_counter.snap_to(EconomyManager.amount)


## Used by CondimentBelt when the player releases a dragged condiment. True when it was sold.
func try_sell_condiment(slot: int) -> bool:
	return is_cursor_over() and sell_condiment(slot)


## Used by StaffRail when the player releases a dragged staff member. True when it was sold.
func try_sell_staff(slot: int) -> bool:
	return is_cursor_over() and sell_staff(slot)


## Sells without a pointer check. The controller's Sell button uses this.
func sell_condiment(slot: int) -> bool:
	if CondimentManager.sell_slot(slot) < 0:
		return false
	AudioManager.play_sfx(UISounds.GOLD_GAINED)
	play_sell_pulse()
	return true


## Sells without a pointer check. The controller's Sell button uses this.
func sell_staff(slot: int) -> bool:
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


## Pops the gold panel as the sold card's ghost lands on it.
func play_sell_pulse() -> void:
	if GameManager.skip_presentation:
		return
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_gold_panel.pivot_offset = _gold_panel.size * 0.5
	_gold_panel.scale = Vector2.ONE
	_pulse_tween = create_tween()
	_pulse_tween.tween_property(
		_gold_panel, "scale", Vector2.ONE * SELL_PULSE_SCALE, SELL_PULSE_RISE
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(
		_gold_panel, "scale", Vector2.ONE, SELL_PULSE_SETTLE
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## True when a card or staff released now would land on the panel.
func is_cursor_over() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


## Idle, armed while a card is dragged, and hover while it sits over the panel.
func _refresh_state() -> void:
	var armed := _is_armed()
	var hovered := armed and is_cursor_over()
	_refresh_gold_text(hovered)
	if hovered:
		_gold_panel.modulate = HOVER_MODULATE
	elif armed:
		_gold_panel.modulate = ARMED_MODULATE
	else:
		_gold_panel.modulate = IDLE_MODULATE
	# Leave scale alone while the sell pulse owns it.
	if _pulse_tween != null and _pulse_tween.is_valid():
		return
	_gold_panel.pivot_offset = _gold_panel.size * 0.5
	_gold_panel.scale = Vector2.ONE * (HOVER_SCALE if hovered else 1.0)
