class_name DeckViewer
extends Control

## Full-screen overlay listing every card in the deck by pile. In view mode it only shows the cards.
## The Merchant opens it in removal mode: pick a card, then pay to take it out of the deck for good
## (DeckManager.buy_removal). Built in code as a first pass for the user's art and layout pass.

signal closed

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")
const CARD_SCALE := 0.62
const CARD_BASE_SIZE := Vector2(214, 317)
const COLUMNS := 7

enum Mode { VIEW, REMOVE }

var _mode := Mode.VIEW
var _selected: TileCard = null
var _selected_ui: CardUI = null

var _title: Label
var _subtitle: Label
var _sections: VBoxContainer
var _status: Label
var _remove_button: Button
var _close_button: Button


func _ready() -> void:
	add_to_group("deck_viewer")
	add_to_group(InputManager.MENU_GROUP)
	name = "DeckViewer"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 160
	panel.offset_right = -160
	panel.offset_top = 90
	panel.offset_bottom = -90
	add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	box.add_child(_title)

	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 18)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_subtitle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	_sections = VBoxContainer.new()
	_sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sections.add_theme_constant_override("separation", 14)
	scroll.add_child(_sections)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	box.add_child(footer)

	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.add_theme_font_size_override("font_size", 18)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(_status)

	_remove_button = Button.new()
	_remove_button.custom_minimum_size = Vector2(240, 48)
	_remove_button.pressed.connect(_on_remove_pressed)
	footer.add_child(_remove_button)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(140, 48)
	_close_button.pressed.connect(close)
	footer.add_child(_close_button)

	DeckManager.piles_changed.connect(func() -> void:
		if visible:
			_rebuild()
	)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## InputManager menu hook.
func is_gamepad_menu_active() -> bool:
	return visible


## InputManager menu hook.
func focus_default() -> void:
	if visible:
		_close_button.grab_focus()


func open_view() -> void:
	_open(Mode.VIEW)


## The Merchant's removal service.
func open_removal() -> void:
	_open(Mode.REMOVE)


func is_open() -> bool:
	return visible


func close() -> void:
	if not visible:
		return
	hide()
	_selected = null
	_selected_ui = null
	AudioManager.play_sfx(UISounds.CLICK)
	closed.emit()


func _open(mode: Mode) -> void:
	_mode = mode
	_selected = null
	_selected_ui = null
	show()
	move_to_front()
	_rebuild()
	if InputManager.is_using_gamepad():
		call_deferred("focus_default")


func _rebuild() -> void:
	for child in _sections.get_children():
		_sections.remove_child(child)
		child.queue_free()
	_selected_ui = null

	_title.text = "Your deck (%d cards)" % DeckManager.deck_size()
	var kitchen := DeckHud.kitchen_text()
	if _mode == Mode.REMOVE:
		_subtitle.text = "Pick a card to remove from your deck for good. Your deck can't go below %d cards." % DeckManager.MIN_DECK_SIZE
		_add_section("Deck", DeckManager.all_cards())
	else:
		_subtitle.text = kitchen if not kitchen.is_empty() else "Each Hour you draw %d cards and can play %d. Each new Day shuffles every card back into the draw pile." % [DeckManager.HOUR_DRAW, DeckManager.PLAYS_PER_HOUR]
		var waiting: Array[TileCard] = []
		# The draw pile's order stays hidden, so it is shown sorted.
		for card: TileCard in DeckManager.all_cards():
			if card in DeckManager.draw_pile or not (card in DeckManager.hand or card in DeckManager.discard_pile or card in DeckManager.played_pile):
				waiting.append(card)
		_add_section("Draw pile", waiting)
		_add_section("Hand", DeckManager.hand)
		_add_section("Discard pile", DeckManager.discard_pile)
		_add_section("Played (back next Day)", DeckManager.played_pile)
	_refresh_footer()


func _add_section(title: String, cards: Array[TileCard]) -> void:
	var sorted := cards.duplicate()
	sorted.sort_custom(func(a: TileCard, b: TileCard) -> bool:
		if a.type != b.type:
			return a.type < b.type
		return String(a.name) < String(b.name)
	)
	var header := Label.new()
	header.text = "%s (%d)" % [title, sorted.size()]
	header.add_theme_font_size_override("font_size", 22)
	_sections.add_child(header)
	if sorted.is_empty():
		return
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_sections.add_child(grid)
	for card: TileCard in sorted:
		var slot := Control.new()
		slot.custom_minimum_size = CARD_BASE_SIZE * CARD_SCALE
		grid.add_child(slot)
		var card_ui: CardUI = CARD_UI_SCENE.instantiate()
		slot.add_child(card_ui)
		card_ui.scale = Vector2.ONE * CARD_SCALE
		card_ui.configure_interaction(CardUI.InteractionMode.CHOICE if _mode == Mode.REMOVE else CardUI.InteractionMode.PREVIEW)
		card_ui.set_card(card)
		if _mode == Mode.REMOVE:
			card_ui.action_requested.connect(_on_card_chosen.bind(card))


func _on_card_chosen(card_ui: CardUI, card: TileCard) -> void:
	if _selected_ui != null and is_instance_valid(_selected_ui):
		_selected_ui.modulate = Color.WHITE
	_selected = card
	_selected_ui = card_ui
	card_ui.modulate = Color(1.0, 0.7, 0.7)
	AudioManager.play_sfx(UISounds.CLICK)
	_refresh_footer()


func _refresh_footer() -> void:
	_remove_button.visible = _mode == Mode.REMOVE
	if _mode != Mode.REMOVE:
		_status.text = "Draw %d · Hand %d · Discard %d · Played %d" % [
			DeckManager.draw_pile_size(), DeckManager.hand.size(),
			DeckManager.discard_pile.size(), DeckManager.played_pile.size(),
		]
		return
	var price := DeckManager.removal_price()
	_remove_button.text = "Remove - %d %s" % [price, GameTerms.GOLD]
	if not DeckManager.can_remove_card():
		_status.text = "Your deck is at the minimum of %d cards." % DeckManager.MIN_DECK_SIZE
		_remove_button.disabled = true
	elif _selected == null:
		_status.text = "Pick a card. Each removal this visit costs 1 %s more." % GameTerms.GOLD
		_remove_button.disabled = true
	else:
		_status.text = "Remove %s for %d %s?" % [_selected.name, price, GameTerms.GOLD]
		_remove_button.disabled = not EconomyManager.can_afford(price)


func _on_remove_pressed() -> void:
	if _selected == null:
		return
	if DeckManager.buy_removal(_selected):
		AudioManager.play_sfx(UISounds.DESTROY)
		_selected = null
		RunSaveManager.request_autosave()
	_rebuild()
