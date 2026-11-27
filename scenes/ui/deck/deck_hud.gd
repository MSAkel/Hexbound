class_name DeckHud
extends VBoxContainer

## Bottom-right of the run screen: the deck pile, a card with the cards left to draw out of the whole
## deck under it. Clicking the pile opens the deck viewer, and hovering it shows the draw and discard counts.
## chefs whose kitchen is rolled. The layout and art live in deck_hud.tscn.

const HOVER_SCALE := 1.06
const HOVER_TIME := 0.08

@onready var _pile_button: Button = %PileButton
@onready var _cards: Control = %Cards
@onready var _count_label: Label = %CountLabel

var _hover_tween: Tween


func _ready() -> void:
	add_to_group("deck_hud")
	_pile_button.pressed.connect(_on_pile_pressed)
	_pile_button.mouse_entered.connect(_on_pile_mouse_entered)
	_pile_button.mouse_exited.connect(_on_pile_mouse_exited)
	_pile_button.resized.connect(_update_pivot)
	_update_pivot()
	DeckManager.piles_changed.connect(_refresh)
	EventBus.run_state_loaded.connect(_refresh)
	EventBus.round_changed.connect(func(_round: int) -> void: _refresh())
	_refresh()


## Screen rect of the top card, where drawn cards fly out from.
func get_pile_rect() -> Rect2:
	return _cards.get_global_rect()


func _refresh() -> void:
	_count_label.text = "%d/%d" % [DeckManager.draw_pile_size(), DeckManager.deck_size()]

func _on_pile_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	EventBus.toggle_tooltip.emit(false, "", Rect2())
	var viewer := get_tree().get_first_node_in_group("deck_viewer") as DeckViewer
	if viewer != null:
		viewer.open_view()


func _on_pile_mouse_entered() -> void:
	_tween_scale(HOVER_SCALE)
	var text := "Deck: %d cards\nDraw pile %d · Discard %d\nClick to see your deck." % [
		DeckManager.deck_size(), DeckManager.draw_pile_size(), DeckManager.discard_pile.size(),
	]
	EventBus.show_tooltip_above.emit(text, _pile_button.get_global_rect())


func _on_pile_mouse_exited() -> void:
	_tween_scale(1.0)
	EventBus.toggle_tooltip.emit(false, "", Rect2())


func _tween_scale(target: float) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(_cards, "scale", Vector2.ONE * target, HOVER_TIME)


func _update_pivot() -> void:
	_cards.pivot_offset = _cards.size * 0.5
