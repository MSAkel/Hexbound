extends Panel

## Collection screen. Opens on a vertical menu of collection types. Each entry opens a page that
## lists only that type (cards, Techniques, Stations, Chefs, Condiments, events): a grid of tiles on
## the left and a detail panel for the selected tile on the right. Back on a page returns to the
## menu, back on the menu leaves the Collection.

signal closed

const CONTENT := "PanelContainer/VBoxContainer/PanelContainer/VBoxContainer"
const TILE_SCENE := preload("res://scenes/ui/collection/collection_tile.tscn")
const EVENT_ICON := preload("res://assets/gui/map_layouts/challenge_icon.png")

@onready var menu_center: CenterContainer = get_node(CONTENT + "/MenuCenter")
@onready var collection_menu: VBoxContainer = get_node(CONTENT + "/MenuCenter/CollectionMenu")
@onready var page_title: Label = get_node(CONTENT + "/PageTitle")
@onready var page_body: HBoxContainer = get_node(CONTENT + "/PageBody")
@onready var list_scroll: ScrollContainer = get_node(CONTENT + "/PageBody/ListPanel/ListScroll")
@onready var list_grid: GridContainer = get_node(CONTENT + "/PageBody/ListPanel/ListScroll/ListMargin/ListGrid")
@onready var detail: CollectionDetail = get_node(CONTENT + "/PageBody/Detail")

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
## What each tile of the open page shows, by tile index: a Card, StationType, ChefDefinition,
## Condiment or an EventManager.Type.
var _entries: Array = []


func _ready() -> void:
	add_to_group(InputManager.MENU_GROUP)
	# Game terms can be renamed, so these two read GameTerms rather than the scene text.
	(collection_menu.get_node("TechniquesButton") as Button).text = GameTerms.TECHNIQUES
	(collection_menu.get_node("CondimentsButton") as Button).text = GameTerms.CONDIMENTS
	# Hover moves focus, so only one menu entry shows the highlight (as on the main menu).
	for node in collection_menu.get_children():
		if node is Button:
			var button := node as Button
			button.mouse_entered.connect(button.grab_focus)
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
	for tile in list_grid.get_children():
		if tile is CollectionTile and (tile as CollectionTile).button_pressed:
			(tile as CollectionTile).grab_focus()
			return
	if MenuFocus.grab_first(list_grid) == null:
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
	_clear_list()
	_page = NO_PAGE
	menu_center.visible = true
	page_title.visible = false
	page_body.visible = false
	var buttons := collection_menu.get_children().filter(func(node: Node) -> bool: return node is Button)
	var target := buttons[clampi(focus_page, 0, buttons.size() - 1)] as Button
	target.grab_focus.call_deferred()


## Opens the page for one collection type, with its first entry selected.
func _show_page(page: int) -> void:
	_page = page
	menu_center.visible = false
	page_title.visible = true
	page_body.visible = true
	page_title.text = _page_title(page)
	_clear_list()
	_entries = _page_entries(page)
	# One group per page, so exactly one tile is selected.
	var group := ButtonGroup.new()
	for i in _entries.size():
		var tile := TILE_SCENE.instantiate() as CollectionTile
		tile.entry_index = i
		tile.button_group = group
		list_grid.add_child(tile)
		_set_tile(tile, _entries[i])
		tile.chosen.connect(_on_tile_chosen)
	list_scroll.scroll_vertical = 0
	if list_grid.get_child_count() > 0:
		(list_grid.get_child(0) as CollectionTile).select()
	_focus_current.call_deferred()


## The right stick scrolls the detail panel while a page is open (InputManager hook).
func get_pad_scroll_target() -> ScrollContainer:
	return detail.get_scroll() if _page != NO_PAGE else null


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


func _page_entries(page: int) -> Array:
	var entries: Array = []
	match page:
		CollectionPage.CARDS:
			var cards: Array = []
			for card in GameManager.tile_cards_pool:
				if card is TileCard:
					cards.append(card)
			entries = _with_meals_grouped_by_category(cards)
		CollectionPage.STAFF:
			entries.assign(StaffCatalog.get_all())
		CollectionPage.STATIONS:
			entries.assign(StationManager.get_station_types())
		CollectionPage.CHEFS:
			entries.assign(ChefRegistry.get_all_chefs())
		CollectionPage.CONDIMENTS:
			entries.assign(CondimentCatalog.get_all())
		CollectionPage.EVENTS:
			entries.assign(EventManager.ALL_EVENTS)
	return entries


func _set_tile(tile: CollectionTile, entry: Variant) -> void:
	if _is_undiscovered(entry):
		tile.set_undiscovered((entry as MealCard).icon)
	elif entry is MealCard:
		var meal := entry as MealCard
		tile.set_entry(meal.icon, meal.name, CollectionDetail.meal_kind_label(meal))
	elif entry is TileCard:
		var card := entry as TileCard
		var kind := card.get_distinct_recipe_tag_label()
		tile.set_entry(card.icon, card.name, kind if not kind.is_empty() else GameTerms.get_tile_card_type_label(card))
	elif entry is StaffCard:
		var technique := entry as StaffCard
		tile.set_entry(technique.icon, technique.name, CollectionDetail.rarity_label(technique.rarity))
	elif entry is StationType:
		var station_type := entry as StationType
		tile.set_entry(station_type.icon, station_type.display_name, "")
	elif entry is ChefDefinition:
		var chef := entry as ChefDefinition
		tile.set_entry(chef.icon, chef.display_name, "")
	elif entry is Condiment:
		var condiment := entry as Condiment
		tile.set_entry(condiment.icon, condiment.display_name, "")
	elif entry is int:
		tile.set_entry(EVENT_ICON, EventManager.get_event_name(int(entry)), "")


## A Meal marked hidden_until_discovered that has never been in the player's deck.
func _is_undiscovered(entry: Variant) -> bool:
	if not entry is MealCard or not (entry as MealCard).hidden_until_discovered:
		return false
	return not bool(CollectionStats.get_meal_stats((entry as MealCard).id)["discovered"])


func _show_detail(entry: Variant) -> void:
	if _is_undiscovered(entry):
		detail.show_undiscovered()
	elif entry is MealCard:
		detail.show_meal(entry as MealCard)
	elif entry is TileCard:
		detail.show_tile_card(entry as TileCard)
	elif entry is StaffCard:
		detail.show_technique(entry as StaffCard)
	elif entry is StationType:
		detail.show_station(entry as StationType)
	elif entry is ChefDefinition:
		detail.show_chef(entry as ChefDefinition)
	elif entry is Condiment:
		detail.show_condiment(entry as Condiment)
	elif entry is int:
		detail.show_event(int(entry) as EventManager.Type)


## A tile was selected (click, focus or the page opening): show it, and keep focus on it so the
## arrow keys carry on from there.
func _on_tile_chosen(tile: CollectionTile) -> void:
	if tile.entry_index < 0 or tile.entry_index >= _entries.size():
		return
	if not tile.has_focus() and tile.is_visible_in_tree() and get_viewport().gui_get_focus_owner() != null:
		tile.grab_focus()
	_show_detail(_entries[tile.entry_index])


func _clear_list() -> void:
	EventBus.toggle_tooltip.emit(false, "")
	_entries.clear()
	for child in list_grid.get_children():
		list_grid.remove_child(child)
		child.queue_free()


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
