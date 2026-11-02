class_name CardFace
extends Control

## Printed side of a card: full card art per type, name banner, icon, type label, and rules text.
## Authored at a fixed size. Hosts call fit_to() so the whole face scales as one piece
## and the art never distorts.
## Presentation only. Input, hover, and shop behavior live in CardUI.

# Name text carries rarity for staff, since the banner fill shows the card type. Spot cards have none.
const RARITY_NAME_COLORS := {
	Card.Rarity.COMMON: Color(1, 1, 1, 1),
	Card.Rarity.UNCOMMON: Color(0.62, 0.84, 1, 1),
	Card.Rarity.RARE: Color(0.86, 0.72, 1, 1),
}
# Warm highlight so the selected card reads clearly above its neighbors.
const SELECTED_TINT := Color(1.15, 1.1, 0.75, 1.0)
# Text starts at the size authored in the scene and shrinks toward these until it fits.
const NAME_MIN_FONT_SIZE := 9
const NAME_MAX_WIDTH := 150.0
const TYPE_LABEL_MIN_FONT_SIZE := 12
const DESCRIPTION_MIN_FONT_SIZE := 10
# Meal requirement row above the rules text. Kind slots ("any Vegetable") sit on a round
# backdrop so they read apart from named cards, which show their own icon bare.
const REQUIREMENT_ICON_SIZE := 18.0
const REQUIREMENT_ICON_PADDING := 1.0
# The name banner sits this much darker than the card art, matching the banner printed on it.
const BANNER_DARKEN := 0.12

# Full card art, rules-text keyword colour, and printed banner width per card type. Set in card_face.tscn.
@export var ingredient_art: Texture2D
@export var kitchenware_art: Texture2D
@export var meal_art: Texture2D
@export var ingredient_keyword_color: Color
@export var kitchenware_keyword_color: Color
@export var meal_keyword_color: Color
@export var ingredient_banner_width: float
@export var kitchenware_banner_width: float
@export var meal_banner_width: float

@onready var _background: TextureRect = %Background
@onready var _name_banner: PanelContainer = %NameBanner
@onready var _name_label: Label = %NameLabel
@onready var _icon: CardIcon = %Icon
@onready var _type_label: Label = %TypeLabel
@onready var _description: RichTextLabel = %Description
@onready var _requirement_icons: HBoxContainer = %RequirementIcons
@onready var _selection_glow: Panel = %SelectionGlow
@onready var _sold_overlay: Panel = %SoldOverlay

# Largest text sizes, read from the scene so the look is tuned in one place.
@onready var _name_font_size := _name_label.get_theme_font_size("font_size")
@onready var _type_label_font_size := _type_label.get_theme_font_size("font_size")
@onready var _description_font_size := _description.get_theme_font_size("normal_font_size")

var _keyword_color := CardKeywordGlossary.COLOR


## Binds every printed field from the shared Card resource.
func set_card(card: Card) -> void:
	if not is_node_ready():
		await ready
	_apply_design(card)
	_icon.setup(card)
	_apply_name(card)
	_apply_type_label(card)
	_apply_requirement_icons(card)
	_apply_description(card)


## Scales the face uniformly to fit rect, top-aligned and centered.
## The rect is in the parent's local space.
func fit_to(rect: Rect2) -> void:
	var face_scale := minf(rect.size.x / size.x, rect.size.y / size.y)
	scale = Vector2.ONE * face_scale
	position = rect.position + Vector2((rect.size.x - size.x * face_scale) * 0.5, 0.0)


func set_selected(selected: bool) -> void:
	_selection_glow.visible = selected
	_background.modulate = SELECTED_TINT if selected else Color.WHITE


func set_sold(sold: bool) -> void:
	_sold_overlay.visible = sold


func _apply_name(card: Card) -> void:
	_name_label.text = card.name
	_name_label.add_theme_font_size_override("font_size", _fitted_font_size(
		_name_label.get_theme_font("font"),
		card.name,
		NAME_MAX_WIDTH,
		_name_font_size,
		NAME_MIN_FONT_SIZE
	))
	_name_label.add_theme_color_override(
		"font_color",
		Color.WHITE if card is TileCard else RARITY_NAME_COLORS.get(card.rarity, Color.WHITE)
	)


func _apply_type_label(card: Card) -> void:
	var label := card.get_card_kind_label()
	if card is TileCard:
		var tile_card := card as TileCard
		label = tile_card.get_card_type_display()
		# Ingredients show their tag alone. The art already shows the type.
		var tag_label := tile_card.get_distinct_recipe_tag_label()
		if tile_card.type == TileCard.TileCardType.INGREDIENT and not tag_label.is_empty():
			label = tag_label
	_type_label.text = label
	_type_label.add_theme_font_size_override("font_size", _fitted_font_size(
		_type_label.get_theme_font("font"),
		label,
		_type_label.size.x,
		_type_label_font_size,
		TYPE_LABEL_MIN_FONT_SIZE
	))


func _apply_description(card: Card) -> void:
	# Keywords such as Flavour, Mult, and Rating are colored in CardKeywordGlossary.
	_description.text = CardKeywordGlossary.to_bbcode(card.get_description_text(), _keyword_color)
	_description.add_theme_font_size_override(
		"normal_font_size",
		_fitted_description_font_size(CardKeywordGlossary.to_plain(card.get_description_text()))
	)


## Small icons for each card a Meal needs on its station. Hidden for every other card.
func _apply_requirement_icons(card: Card) -> void:
	for child: Node in _requirement_icons.get_children():
		child.queue_free()
	var entries: Array[Dictionary] = []
	if card is MealCard:
		entries = (card as MealCard).get_requirement_icons()
	_requirement_icons.visible = not entries.is_empty()
	for entry: Dictionary in entries:
		_requirement_icons.add_child(_make_requirement_icon(entry["icon"], entry["kind"]))


func _make_requirement_icon(texture: Texture2D, kind: StringName) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop := StyleBoxFlat.new()
	backdrop.set_content_margin_all(REQUIREMENT_ICON_PADDING)
	if kind.is_empty():
		backdrop.draw_center = false
	else:
		backdrop.bg_color = CardTypeColors.KITCHENWARE if kind == TileCard.TAG_KITCHENWARE else CardTypeColors.INGREDIENT
		backdrop.set_corner_radius_all(int(REQUIREMENT_ICON_SIZE))
	slot.add_theme_stylebox_override("panel", backdrop)
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2.ONE * REQUIREMENT_ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)
	return slot


## Picks the card art and keyword colour for the card's type, and matches the name banner to it.
func _apply_design(card: Card) -> void:
	var accent := CardTypeColors.for_card(card)
	if accent == CardTypeColors.MEAL:
		_background.texture = meal_art
		_keyword_color = meal_keyword_color
		_name_banner.custom_minimum_size.x = meal_banner_width
	elif accent == CardTypeColors.KITCHENWARE:
		_background.texture = kitchenware_art
		_keyword_color = kitchenware_keyword_color
		_name_banner.custom_minimum_size.x = kitchenware_banner_width
	else:
		_background.texture = ingredient_art
		_keyword_color = ingredient_keyword_color
		_name_banner.custom_minimum_size.x = ingredient_banner_width
	# Self modulate tints the banner and leaves the name text alone.
	_name_banner.self_modulate = accent.darkened(BANNER_DARKEN)


## Largest font size that keeps the text on one line within max_width.
## Stops at min_size, even when that still overflows.
func _fitted_font_size(
	font: Font,
	text: String,
	max_width: float,
	max_size: int,
	min_size: int
) -> int:
	var font_size := max_size
	while font_size > min_size and _text_width(font, text, font_size) > max_width:
		font_size -= 1
	return font_size


func _text_width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x


## Largest font size whose wrapped lines fit the description box.
func _fitted_description_font_size(plain_text: String) -> int:
	var font := _description.get_theme_font("normal_font")
	var box := _description.size
	var font_size := _description_font_size
	while font_size > DESCRIPTION_MIN_FONT_SIZE:
		var text_size := font.get_multiline_string_size(
			plain_text,
			HORIZONTAL_ALIGNMENT_CENTER,
			box.x,
			font_size
		)
		if text_size.y <= box.y:
			break
		font_size -= 1
	return font_size
