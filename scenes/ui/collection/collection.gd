extends Panel

## Collection screen. Opens on a vertical menu of collection types; each entry opens a page that
## lists only that type (cards, Techniques, Stations, Chefs, Condiments, events). Back on a page
## returns to the menu, back on the menu leaves the Collection.

signal closed

const CONTENT := "PanelContainer/VBoxContainer/PanelContainer/VBoxContainer"

@onready var menu_center: CenterContainer = get_node(CONTENT + "/MenuCenter")
@onready var collection_menu: VBoxContainer = get_node(CONTENT + "/MenuCenter/CollectionMenu")
@onready var page_title: Label = get_node(CONTENT + "/PageTitle")
@onready var collection_grid_container: GridContainer = $PanelContainer/VBoxContainer/PanelContainer/VBoxContainer/ScrollContainer/MarginContainer/CollectionGridContainer
@onready var collection_scroll: ScrollContainer = $PanelContainer/VBoxContainer/PanelContainer/VBoxContainer/ScrollContainer

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")
const EVENT_ICON := preload("res://assets/gui/map_layouts/challenge_icon.png")

const TEXT_PRIMARY := Color("e8dfc9")
const TEXT_SECONDARY := Color("aeb9b3")
const ACCENT := Color("c29a56")
const ITEM_BACKGROUND := Color("182b30e8")
const ITEM_BORDER := Color("617575")

## Menu order. Each menu button passes its index (the scene's pressed binds).
enum CollectionPage {
	CARDS,
	STAFF,
	STATIONS,
	CHEFS,
	CONDIMENTS,
	EVENTS,
}

const NO_PAGE := -1

## Page on screen, or NO_PAGE while the menu shows.
var _page: int = NO_PAGE


func _ready() -> void:
	add_to_group(InputManager.MENU_GROUP)
	collection_scroll.follow_focus = true
	# Game terms can be renamed, so these two read GameTerms rather than the scene text.
	(collection_menu.get_node("TechniquesButton") as Button).text = GameTerms.TECHNIQUES
	(collection_menu.get_node("CondimentsButton") as Button).text = GameTerms.CONDIMENTS
	visibility_changed.connect(_on_visibility_changed)
	_show_menu()


## The pause menu reuses one Collection: each time it opens, it starts on the menu again.
func _on_visibility_changed() -> void:
	if visible and _page != NO_PAGE:
		_show_menu(_page)


## InputManager menu hook.
func focus_default() -> void:
	_focus_current()


func _focus_current() -> void:
	if _page == NO_PAGE:
		var first := collection_menu.get_node("CardsButton") as Button
		first.grab_focus()
		return
	if MenuFocus.grab_first(collection_grid_container) == null:
		MenuFocus.grab_first(self)


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_on_back_button_pressed()


## Shows the menu of collection types and hides any page.
func _show_menu(focus_page: int = CollectionPage.CARDS) -> void:
	_clear_collection()
	_page = NO_PAGE
	menu_center.visible = true
	page_title.visible = false
	collection_scroll.visible = false
	var buttons := collection_menu.get_children().filter(func(node: Node) -> bool: return node is Button)
	var target := buttons[clampi(focus_page, 0, buttons.size() - 1)] as Button
	target.grab_focus.call_deferred()


## Opens the page for one collection type.
func _show_page(page: int) -> void:
	_page = page
	menu_center.visible = false
	page_title.visible = true
	collection_scroll.visible = true
	collection_scroll.scroll_vertical = 0
	page_title.text = _page_title(page)
	_show_tab(page)
	_focus_current.call_deferred()


func _page_title(page: int) -> String:
	match page:
		CollectionPage.CARDS:
			return "Cards"
		CollectionPage.STAFF:
			return GameTerms.TECHNIQUES
		CollectionPage.STATIONS:
			return "Stations"
		CollectionPage.CHEFS:
			return "Chefs"
		CollectionPage.CONDIMENTS:
			return GameTerms.CONDIMENTS
		CollectionPage.EVENTS:
			return "Events"
	return ""


func _show_tab(page: int) -> void:
	_clear_collection()
	match page:
		CollectionPage.CARDS:
			_show_cards()
		CollectionPage.CONDIMENTS:
			_show_condiments()
		CollectionPage.STAFF:
			_show_staff()
		CollectionPage.STATIONS:
			_show_stations()
		CollectionPage.CHEFS:
			_show_chefs()
		CollectionPage.EVENTS:
			_show_events()


func _clear_collection() -> void:
	EventBus.toggle_tooltip.emit(false, "")
	for child in collection_grid_container.get_children():
		collection_grid_container.remove_child(child)
		child.queue_free()


func _show_card_uis(cards: Array) -> void:
	collection_grid_container.columns = 5
	for card in cards:
		if card is not Card:
			continue
		var card_ui: CardUI = CARD_UI_SCENE.instantiate()
		# Focusable so a controller can walk the grid and read each card's keyword tips.
		card_ui.configure_interaction(CardUI.InteractionMode.PREVIEW, {"focusable": true})
		collection_grid_container.add_child(card_ui)
		card_ui.set_card(card)


func _show_cards() -> void:
	var cards: Array = []
	for card in GameManager.tile_cards_pool:
		if card is TileCard:
			cards.append(card)
	_show_card_uis(_with_meals_grouped_by_category(cards))


## Same cards in the same order, except the Meals are sorted by category and then by name.
## Meals keep the spots they had, so Ingredients and Kitchenware do not move.
func _with_meals_grouped_by_category(cards: Array) -> Array:
	var meals: Array[MealCard] = []
	for card in cards:
		if card is MealCard:
			meals.append(card as MealCard)
	meals.sort_custom(func(a: MealCard, b: MealCard) -> bool:
		if a.meal_category != b.meal_category:
			return int(a.meal_category) < int(b.meal_category)
		return a.name.naturalnocasecmp_to(b.name) < 0
	)
	var result: Array = []
	var next_meal := 0
	for card in cards:
		if card is MealCard:
			result.append(meals[next_meal])
			next_meal += 1
		else:
			result.append(card)
	return result


func _show_staff() -> void:
	_show_card_uis(StaffCatalog.get_all())


func _show_stations() -> void:
	collection_grid_container.columns = 3
	for station_type: StationType in StationManager.get_station_types():
		collection_grid_container.add_child(_create_station_entry(station_type))


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
	panel.mouse_exited.connect(_hide_tooltip)
	panel.focus_entered.connect(_show_condiment_tooltip.bind(panel, condiment))
	panel.focus_exited.connect(_hide_tooltip)
	return panel


func _show_condiment_tooltip(panel: Control, condiment: Condiment) -> void:
	EventBus.toggle_tooltip.emit(true, condiment.get_tooltip_text(), panel.get_global_rect())


func _show_chefs() -> void:
	collection_grid_container.columns = 3
	for chef: ChefDefinition in ChefRegistry.get_all_chefs():
		collection_grid_container.add_child(_create_chef_entry(chef))


func _show_events() -> void:
	collection_grid_container.columns = 3
	for event_type: EventManager.Type in EventManager.ALL_EVENTS:
		collection_grid_container.add_child(_create_event_entry(event_type))


func _hide_tooltip() -> void:
	EventBus.toggle_tooltip.emit(false, "")


func _create_chef_entry(chef: ChefDefinition) -> PanelContainer:
	var panel := _create_item_panel(Vector2(500, 270))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(170, 230)
	portrait.texture = chef.icon
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	row.add_child(details)

	details.add_child(_create_label(chef.display_name.to_upper(), 27, TEXT_PRIMARY))
	details.add_child(_create_separator())
	details.add_child(_create_label("SPECIALITY", 14, ACCENT))
	var speciality_label := _create_label(
		CardKeywordGlossary.to_plain(chef.speciality_description), 20, TEXT_PRIMARY
	)
	speciality_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speciality_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(speciality_label)
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


func _create_station_entry(station_type: StationType) -> PanelContainer:
	var panel := _create_item_panel(Vector2(500, 170))
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 8)
	panel.add_child(details)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	details.add_child(header)
	if station_type.icon != null:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(56, 56)
		icon.texture = station_type.icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		header.add_child(icon)
	var name_label := _create_label(station_type.display_name.to_upper(), 25, station_type.color)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(name_label)

	details.add_child(_create_separator())
	details.add_child(_create_label("REQUIRES", 14, ACCENT))
	var requirements := _create_label(station_type.get_requirements_text(), 18, TEXT_PRIMARY)
	requirements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_child(requirements)

	details.add_child(_create_separator())
	details.add_child(_create_label("LEVELS", 14, ACCENT))
	for level: int in range(StationManager.START_LEVEL, StationManager.MAX_LEVEL + 1):
		details.add_child(_create_station_level_row(level, _station_level_lines(station_type, level)))
	return panel


## Everything reaching a level gives a station, one line each.
func _station_level_lines(station_type: StationType, level: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	var upgrade := station_type.get_level_upgrade_text(level)
	if not upgrade.is_empty():
		lines.append(CardKeywordGlossary.to_plain(upgrade))
	if level == StationManager.MEAL_SLOT_UNLOCK_LEVEL:
		lines.append("Opens a locked second %s (higher difficulty levels)." % GameTerms.MEAL_SLOT)
	var options: Array[StationPerk] = []
	if level == StationManager.CHOICE_LEVEL:
		options = station_type.choice_options
	elif level == StationManager.CAPSTONE_LEVEL:
		options = station_type.capstone_options
	if not options.is_empty():
		lines.append("Choose one perk:")
	for perk: StationPerk in options:
		lines.append("• %s" % CardKeywordGlossary.to_plain(perk.description))
	return lines


func _create_station_level_row(level: int, lines: PackedStringArray) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var level_label := _create_label("LV %d" % level, 16, ACCENT)
	level_label.custom_minimum_size = Vector2(42, 0)
	level_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(level_label)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 2)
	row.add_child(column)
	for line: String in lines:
		var label := _create_label(line, 16, TEXT_PRIMARY)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(label)
	return row


func _create_item_panel(minimum_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Entries take focus so a controller can scroll through them.
	panel.focus_mode = Control.FOCUS_ALL

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


func _on_menu_entry_pressed(page: int) -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	_show_page(page)


func _on_back_button_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	EventBus.toggle_tooltip.emit(false, "")
	# A page goes back to the menu, with its entry selected.
	if _page != NO_PAGE:
		_show_menu(_page)
		return
	# Scene root goes back to the main menu. Overlay instances return to the host.
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)
		return
	closed.emit()
