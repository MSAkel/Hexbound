class_name DeckHud
extends PanelContainer

## Bottom-right of the run screen: draw and discard pile counts, the plays left this Hour, the
## End Hour button and a button that opens the deck viewer. Built in code, so the layout is a first
## pass for the user's art and layout pass. The kitchen line names the Stations the starting deck was
## built from, for chefs whose kitchen is rolled.

const MARGIN := 24.0
const WIDTH := 236.0

var _kitchen_label: Label
var _piles_label: Label
var _plays_label: Label
var _deck_button: Button
var _end_hour_button: Button


func _ready() -> void:
	add_to_group("deck_hud")
	name = "DeckHud"
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = Vector2(WIDTH, 0)
	offset_right = -MARGIN
	offset_bottom = -MARGIN
	offset_left = -MARGIN - WIDTH

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)

	_kitchen_label = Label.new()
	_kitchen_label.add_theme_font_size_override("font_size", 16)
	_kitchen_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_kitchen_label)

	_piles_label = Label.new()
	_piles_label.add_theme_font_size_override("font_size", 18)
	box.add_child(_piles_label)

	_plays_label = Label.new()
	_plays_label.add_theme_font_size_override("font_size", 18)
	box.add_child(_plays_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	_deck_button = Button.new()
	_deck_button.text = "Deck"
	_deck_button.tooltip_text = "See every card in your deck."
	_deck_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_button.pressed.connect(_on_deck_pressed)
	row.add_child(_deck_button)

	_end_hour_button = Button.new()
	_end_hour_button.text = "End Hour"
	_end_hour_button.tooltip_text = "End the Hour now. Cards left in your hand are discarded."
	_end_hour_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_end_hour_button.pressed.connect(_on_end_hour_pressed)
	row.add_child(_end_hour_button)

	DeckManager.piles_changed.connect(_refresh)
	EventBus.run_state_loaded.connect(_refresh)
	EventBus.round_changed.connect(func(_round: int) -> void: _refresh())
	_refresh()


func _process(_delta: float) -> void:
	var hand := _find_hand()
	_end_hour_button.disabled = hand == null or not hand.can_end_hour()


func _refresh() -> void:
	_piles_label.text = "Draw %d · Discard %d" % [DeckManager.draw_pile_size(), DeckManager.discard_pile.size()]
	_plays_label.text = "Plays left: %d" % DeckManager.plays_left()
	var kitchen := kitchen_text()
	_kitchen_label.text = kitchen
	_kitchen_label.visible = not kitchen.is_empty() and GameManager.current_round <= 1


## "Your kitchen: Fry + Bar" for chefs whose starting Stations are rolled. Empty otherwise.
static func kitchen_text() -> String:
	var chef := GameManager.selected_chef
	if chef == null or DeckManager.kitchen_station_ids.is_empty():
		return ""
	var rolled := false
	for entry: String in chef.deck_stations:
		var choice := entry.split(":")[0]
		if choice == ChefDefinition.ANY_STATION or "|" in choice:
			rolled = true
	if not rolled:
		return ""
	var names: Array[String] = []
	for station_id: String in DeckManager.kitchen_station_ids:
		var station_type := StationManager.get_station_type_by_id(station_id)
		names.append(station_type.display_name.trim_suffix(" Station") if station_type != null else station_id)
	return "Your kitchen: %s" % " + ".join(names)


func _on_deck_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	var viewer := get_tree().get_first_node_in_group("deck_viewer") as DeckViewer
	if viewer != null:
		viewer.open_view()


func _on_end_hour_pressed() -> void:
	var hand := _find_hand()
	if hand != null and hand.can_end_hour():
		hand.end_hour()


func _find_hand() -> Hand:
	return get_tree().get_first_node_in_group("run_hand") as Hand
