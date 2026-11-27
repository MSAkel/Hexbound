class_name StationMenu
extends PanelContainer

## The Station badge's hover panel, laid out as a restaurant menu. A typed Station shows its level
## and perks ("House Specials"). A Station with no type lists every Station type as a dish with the
## cards it needs.
## Opens on EventBus.show_station_menu. Anything that sets or clears the tooltip closes it.

## Space between the menu and the badge it opens beside.
const GAP := 14.0

@export var special_scene: PackedScene
@export var entry_scene: PackedScene

@onready var _station_icon: TextureRect = %StationIcon
@onready var _station_name: Label = %StationName
@onready var _level: Label = %Level
@onready var _served_row: HBoxContainer = %ServedRow
@onready var _served: Label = %Served
@onready var _specials_divider: Control = %SpecialsDivider
@onready var _specials: VBoxContainer = %Specials
@onready var _no_specialty: Label = %NoSpecialty
@onready var _types_divider: Control = %TypesDivider
@onready var _entries: VBoxContainer = %Entries

## Bumped by every show and hide, so a show that is still measuring can tell it is stale.
var _request := 0


func _ready() -> void:
	EventBus.show_station_menu.connect(_on_show_station_menu)
	EventBus.toggle_tooltip.connect(_on_toggle_tooltip)
	EventBus.show_tooltip_above.connect(_on_show_tooltip_above)
	hide()


## cards are the row's regular-spot cards.
func _on_show_station_menu(segment_index: int, cards: Array[TileCard], element_rect: Rect2) -> void:
	_request += 1
	var request := _request
	var station_type := StationManager.get_station_type(segment_index)
	_fill_header(segment_index, station_type)
	_fill_specials(segment_index, station_type)
	_types_divider.visible = station_type == null
	_entries.visible = station_type == null
	if station_type == null:
		_fill_entries(cards)

	# Wrapped text only knows its height after a layout pass, so lay out unseen first.
	modulate.a = 0.0
	show()
	for frame in 2:
		await get_tree().process_frame
		if request != _request:
			return
		reset_size()
	_place_beside(element_rect)
	modulate.a = 1.0


func _on_toggle_tooltip(_is_visible: bool, _text: String, _element_rect: Rect2 = Rect2()) -> void:
	_close()


func _on_show_tooltip_above(_text: String, _element_rect: Rect2) -> void:
	_close()


func _close() -> void:
	_request += 1
	hide()


func _fill_header(segment_index: int, station_type: StationType) -> void:
	_station_icon.texture = station_type.icon if station_type != null else null
	_station_icon.visible = station_type != null
	_station_name.text = StationManager.get_station_name(segment_index)
	_level.visible = station_type != null
	_level.text = "Level %d" % StationManager.get_level(segment_index)
	var next := StationManager.get_next_threshold(segment_index)
	_served_row.visible = station_type != null and next >= 0
	if _served_row.visible:
		_served.text = "%d/%d" % [StationManager.get_served(segment_index), next]


func _fill_specials(segment_index: int, station_type: StationType) -> void:
	for child: Node in _specials.get_children():
		_specials.remove_child(child)
		child.queue_free()
	_specials_divider.visible = station_type != null
	_specials.visible = station_type != null
	_no_specialty.visible = station_type == null
	if station_type == null:
		return
	var perks: Array[StationPerk] = []
	var level_perk := station_type.perk_for_level(StationManager.get_level(segment_index))
	if level_perk != null:
		perks.append(level_perk)
	perks.append_array(StationManager.get_picked_perks(segment_index))
	for perk: StationPerk in perks:
		var special := special_scene.instantiate() as StationMenuSpecial
		_specials.add_child(special)
		special.setup(perk.description)


func _fill_entries(cards: Array[TileCard]) -> void:
	var types := StationManager.get_station_types()
	while _entries.get_child_count() < types.size():
		_entries.add_child(entry_scene.instantiate())
	for index in types.size():
		var entry := _entries.get_child(index) as StationMenuEntry
		entry.setup(types[index], cards)


## Right of the element, or left of it when there is no room, level with it and kept on screen.
func _place_beside(element_rect: Rect2) -> void:
	var viewport_size := get_viewport_rect().size
	var target := Vector2(element_rect.end.x + GAP, element_rect.get_center().y - size.y * 0.5)
	if target.x + size.x > viewport_size.x:
		target.x = element_rect.position.x - GAP - size.x
	position = target.clamp(Vector2.ZERO, (viewport_size - size).max(Vector2.ZERO)).floor()
