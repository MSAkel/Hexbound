class_name CardSellPanel
extends PanelContainer

## Bottom-left corner of the run screen: the current chef's portrait above the gold panel, with the
## End Hour button under them.
## The gold panel shows the player's gold. Techniques and condiments are sold from their own Sell
## button (click one to open it), not here. Hand cards can't be sold: the Merchant's removal
## service takes a card out of the deck.
## Hovering the portrait shows the chef's name and ability.

# The art pops when a condiment is sold with the controller's Sell button.
const SELL_PULSE_SCALE := 1.12
const SELL_PULSE_RISE := 0.08
const SELL_PULSE_SETTLE := 0.22

@onready var _art: TextureRect = %Art
## Takes the sell pulse. The chef portrait stays as it is.
@onready var _gold_panel: TextureRect = %GoldPanel
@onready var _gold_label: Label = %GoldLabel

var _pulse_tween: Tween
var _gold_counter: CountingNumber


func _ready() -> void:
	add_to_group("card_sell_panel")
	_gold_counter = CountingNumber.for_label(self, _gold_label)
	_gold_counter.snap_to(EconomyManager.amount)
	_show_chef_portrait()
	_art.mouse_entered.connect(_on_art_mouse_entered)
	_art.mouse_exited.connect(_on_art_mouse_exited)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.run_state_loaded.connect(_on_run_state_loaded)


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
	if chef == null:
		return
	var ability := CardKeywordGlossary.to_plain(chef.speciality_description)
	EventBus.show_tooltip_above.emit("%s
%s" % [chef.display_name, ability], _art.get_global_rect())


func _on_art_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "", Rect2())


func _on_gold_changed(amount: int) -> void:
	_gold_counter.play(amount)


func _on_run_state_loaded() -> void:
	_show_chef_portrait()
	_gold_counter.snap_to(EconomyManager.amount)


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


## Pops the gold panel as the sold item's gold lands.
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


## Screen rect of the chef portrait, where discarded cards fly into.
func get_portrait_rect() -> Rect2:
	return _art.get_global_rect()
