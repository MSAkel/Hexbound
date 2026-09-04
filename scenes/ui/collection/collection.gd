extends Panel

## Collection screen for browsing cards by shelf, characters, events, and passives.

signal closed

@onready var tab_bar: TabBar = $PanelContainer/VBoxContainer/PanelContainer/VBoxContainer/TabBar
@onready var collection_grid_container: GridContainer = $PanelContainer/VBoxContainer/PanelContainer/VBoxContainer/ScrollContainer/MarginContainer/CollectionGridContainer
@onready var back_button: Button = $PanelContainer/VBoxContainer/BackButton

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")
const EVENT_ICON := preload("res://assets/gui/map_layouts/challenge_icon.png")
const PASSIVE_TILE := preload("res://assets/passives/passives_tile.png")
const LOCKED_PASSIVE_ICON := preload("res://assets/passives/icons/locked_modifier.png")

const TEXT_PRIMARY := Color("e8dfc9")
const TEXT_SECONDARY := Color("aeb9b3")
const ACCENT := Color("c29a56")
const ITEM_BACKGROUND := Color("182b30e8")
const ITEM_BORDER := Color("617575")

enum CollectionTab {
	INGREDIENT,
	KITCHENWARE,
	CONDIMENTS,
	UTILITY,
	CHARACTERS,
	EVENTS,
	PASSIVES,
}


func _ready() -> void:
	_configure_tabs()
	_show_tab(tab_bar.current_tab)
	call_deferred("_focus_collection")


func _focus_collection() -> void:
	if tab_bar != null:
		tab_bar.grab_focus()
		return
	MenuFocus.grab_first(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_on_back_button_pressed()


func _configure_tabs() -> void:
	var titles := PackedStringArray([
		FeastDisplay.INGREDIENT,
		"Kitchenware",
		FeastDisplay.CONDIMENTS,
		"Utility",
		"Characters",
		"Events",
		"Passives",
	])
	tab_bar.tab_count = titles.size()
	for i: int in titles.size():
		tab_bar.set_tab_title(i, titles[i])


func _show_tab(tab: int) -> void:
	_clear_collection()
	match tab:
		CollectionTab.INGREDIENT:
			_show_ingredients_cards()
		CollectionTab.KITCHENWARE:
			_show_kitchenware_cards()
		CollectionTab.CONDIMENTS:
			_show_condiments()
		CollectionTab.UTILITY:
			_show_utility_cards()
		CollectionTab.CHARACTERS:
			_show_characters()
		CollectionTab.EVENTS:
			_show_events()
		CollectionTab.PASSIVES:
			_show_passives()


func _clear_collection() -> void:
	EventBus.toggle_tooltip.emit(false, "")
	for child in collection_grid_container.get_children():
		collection_grid_container.remove_child(child)
		child.queue_free()


func _show_tile_cards(cards: Array) -> void:
	collection_grid_container.columns = 5
	for card in cards:
		if card is not TileCard:
			continue
		var card_ui: CardUI = CARD_UI_SCENE.instantiate()
		card_ui.configure_interaction(CardUI.InteractionMode.PREVIEW)
		collection_grid_container.add_child(card_ui)
		card_ui.set_card(card)


func _show_ingredients_cards() -> void:
	var cards: Array = []
	for card in GameManager.tile_cards_pool:
		if card is TileCard and _is_ingredients_card(card as TileCard):
			cards.append(card)
	_show_tile_cards(cards)


func _show_kitchenware_cards() -> void:
	var cards: Array = []
	for card in GameManager.tile_cards_pool:
		if card is TileCard and (card as TileCard).type == TileCard.TileCardType.KITCHENWARE:
			cards.append(card)
	_show_tile_cards(cards)


func _show_utility_cards() -> void:
	var cards: Array = []
	for card in GameManager.tile_cards_pool:
		if card is TileCard and (card as TileCard).type == TileCard.TileCardType.UTILITY:
			cards.append(card)
	_show_tile_cards(cards)


func _is_ingredients_card(card: TileCard) -> bool:
	return card.type == TileCard.TileCardType.INGREDIENT


func _show_condiments() -> void:
	collection_grid_container.columns = 5
	for condiment: Condiment in CondimentCatalog.get_all():
		collection_grid_container.add_child(_create_condiment_entry(condiment))


func _create_condiment_entry(condiment: Condiment) -> PanelContainer:
	var panel := _create_item_panel(Vector2(180, 200))
	panel.mouse_default_cursor_shape = Control.CURSOR_HELP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(96, 96)
	icon.texture = condiment.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon)

	var name_label := _create_label(condiment.display_name, 18, TEXT_PRIMARY)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)

	panel.mouse_entered.connect(_show_condiment_tooltip.bind(panel, condiment))
	panel.mouse_exited.connect(_hide_passive_tooltip)
	return panel


func _show_condiment_tooltip(panel: Control, condiment: Condiment) -> void:
	var tip := "%s\n%s" % [condiment.display_name, condiment.description]
	EventBus.toggle_tooltip.emit(true, tip, panel.get_global_rect())


func _show_characters() -> void:
	collection_grid_container.columns = 3
	for character: CharacterDefinition in PlayerCharacter.get_all_characters():
		collection_grid_container.add_child(_create_character_entry(character))


func _show_events() -> void:
	collection_grid_container.columns = 3
	for event_type: EventManager.Type in EventManager.ALL_EVENTS:
		collection_grid_container.add_child(_create_event_entry(event_type))


func _show_passives() -> void:
	collection_grid_container.columns = 5
	for passive: SegmentPassive in MetaProgressionManager.get_all_passives():
		collection_grid_container.add_child(_create_passive_entry(passive))


func _create_passive_entry(passive: SegmentPassive) -> PanelContainer:
	var panel := _create_item_panel(Vector2(210, 180))
	panel.mouse_default_cursor_shape = Control.CURSOR_HELP

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)

	var hex := TextureRect.new()
	hex.custom_minimum_size = Vector2(112, 130)
	hex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hex.texture = PASSIVE_TILE
	hex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center.add_child(hex)

	var unlocked := MetaProgressionManager.is_unlocked(passive.id)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = passive.icon if unlocked else LOCKED_PASSIVE_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 20
	icon.offset_top = 24
	icon.offset_right = -20
	icon.offset_bottom = -24
	hex.add_child(icon)
	if not unlocked:
		hex.modulate = Color(0.7, 0.7, 0.72, 1.0)

	panel.mouse_entered.connect(_show_passive_tooltip.bind(panel, passive, unlocked))
	panel.mouse_exited.connect(_hide_passive_tooltip)
	return panel


func _show_passive_tooltip(
	panel: Control,
	passive: SegmentPassive,
	unlocked: bool
) -> void:
	var tile_count := maxi(1, passive.tile_cost)
	var tile_text := "Spot size: %d spot%s" % [tile_count, "" if tile_count == 1 else "s"]
	var passive_tip: String
	if unlocked:
		passive_tip = "%s\n%s\n%s" % [
			passive.display_name,
			passive.get_effect_summary(),
			tile_text,
		]
	else:
		var requirement := "Unlock requirement unavailable"
		if passive.unlock_condition != null and not passive.unlock_condition.description.is_empty():
			requirement = passive.unlock_condition.description
		passive_tip = "Locked\n%s\n%s" % [requirement, tile_text]
	EventBus.toggle_tooltip.emit(true, passive_tip, panel.get_global_rect())


func _hide_passive_tooltip() -> void:
	EventBus.toggle_tooltip.emit(false, "")


func _create_character_entry(character: CharacterDefinition) -> PanelContainer:
	var panel := _create_item_panel(Vector2(500, 270))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(170, 230)
	portrait.texture = character.icon
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	row.add_child(details)

	details.add_child(_create_label(character.display_name.to_upper(), 27, TEXT_PRIMARY))
	details.add_child(_create_separator())
	details.add_child(_create_label("FIRE ORDER", 14, ACCENT))
	var order_label := _create_label(character.trigger_order_display_name, 20, TEXT_PRIMARY)
	order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(order_label)

	var description := _create_label(character.trigger_order_description, 16, TEXT_SECONDARY)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(description)

	var segment_text := "Variable courses" if character.segments_count < 0 else "%d courses" % character.segments_count
	details.add_child(_create_label(segment_text.to_upper(), 14, ACCENT))
	return panel


func _create_event_entry(event_type: EventManager.Type) -> PanelContainer:
	var panel := _create_item_panel(Vector2(500, 210))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(72, 72)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture = EVENT_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 10)
	row.add_child(details)

	details.add_child(_create_label(EventManager.get_event_name(event_type).to_upper(), 25, TEXT_PRIMARY))
	details.add_child(_create_separator())
	var description := _create_label(EventManager.get_event_description(event_type), 17, TEXT_SECONDARY)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(description)
	details.add_child(_create_label(EventManager.get_allowed_rounds_label(event_type).to_upper(), 14, ACCENT))
	return panel


func _create_item_panel(minimum_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = ITEM_BACKGROUND
	style.border_color = ITEM_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_top = 18
	style.content_margin_right = 20
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _create_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _create_separator() -> HSeparator:
	var separator := HSeparator.new()
	separator.modulate = ITEM_BORDER
	return separator


func _on_tab_bar_tab_changed(tab: int) -> void:
	_show_tab(tab)


func _on_back_button_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	EventBus.toggle_tooltip.emit(false, "")
	# Scene root goes back to the main menu. Overlay instances return to the host.
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)
		return
	closed.emit()
