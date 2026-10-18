class_name CardFace
extends Control

## Printed side of a card: layered frame art, name banner, icon, type ribbon, and rules text.
## Authored at a fixed size. Hosts call fit_to() so the whole face scales as one piece
## and the layered art never distorts.
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
# Below this the full "Type · Tag" label is dropped for the tag alone.
const TYPE_LABEL_MIN_FULL_FONT_SIZE := 11
const TYPE_LABEL_MIN_FONT_SIZE := 9
# Clear space kept at each end of the ribbon.
const TYPE_LABEL_SIDE_PADDING := 2.0
# The scene gives the type label a RibbonTextEffect that bends the text along the art.
const TYPE_LABEL_BBCODE := "[ribbon]%s[/ribbon]"
const DESCRIPTION_MIN_FONT_SIZE := 10
# Meal requirement row above the rules text. Kind slots ("any Vegetable") sit on a round
# backdrop so they read apart from named cards, which show their own icon bare.
const REQUIREMENT_ICON_SIZE := 18.0
const REQUIREMENT_ICON_PADDING := 1.0
# Rules text starts this far lower while the requirement row shows.
const REQUIREMENT_ROW_HEIGHT := 21.0

# Paper background. The details and tinted border are its children, so they share the selection tint.
@onready var _background: TextureRect = %Background
@onready var _border: TextureRect = %Border
@onready var _name_banner: PanelContainer = %NameBanner
@onready var _name_label: Label = %NameLabel
@onready var _icon_backdrop: TextureRect = %IconBackdrop
@onready var _icon: CardIcon = %Icon
@onready var _type_label: RichTextLabel = %TypeLabel
@onready var _description: RichTextLabel = %Description
@onready var _requirement_icons: HBoxContainer = %RequirementIcons
@onready var _selection_glow: Panel = %SelectionGlow
@onready var _sold_overlay: Panel = %SoldOverlay

# Largest text sizes, read from the scene so the look is tuned in one place.
@onready var _name_font_size := _name_label.get_theme_font_size("font_size")
@onready var _type_label_font_size := _type_label.get_theme_font_size("normal_font_size")
@onready var _description_font_size := _description.get_theme_font_size("normal_font_size")
@onready var _description_offset_top := _description.offset_top


## Binds every printed field from the shared Card resource.
func set_card(card: Card) -> void:
	if not is_node_ready():
		await ready
	_icon.setup(card)
	_apply_name(card)
	_apply_type_label(card)
	# Before the description, which fits its font to the space the row leaves.
	_apply_requirement_icons(card)
	_apply_description(card)
	_apply_accent(CardTypeColors.for_card(card))


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
	var tag_label := ""
	if card is TileCard:
		label = (card as TileCard).get_card_type_display()
		tag_label = (card as TileCard).get_distinct_recipe_tag_label()
	var font := _type_label.get_theme_font("normal_font")
	var max_width := _type_label.size.x - TYPE_LABEL_SIDE_PADDING * 2.0
	var font_size := _fitted_font_size(
		font,
		label,
		max_width,
		_type_label_font_size,
		TYPE_LABEL_MIN_FULL_FONT_SIZE
	)
	if _text_width(font, label, font_size) > max_width:
		# The ribbon is short. The accent color already shows the type, so keep the tag.
		if not tag_label.is_empty():
			label = tag_label
		font_size = _fitted_font_size(
			font,
			label,
			max_width,
			_type_label_font_size,
			TYPE_LABEL_MIN_FONT_SIZE
		)
	_type_label.add_theme_font_size_override("normal_font_size", font_size)
	_type_label.text = TYPE_LABEL_BBCODE % label


func _apply_description(card: Card) -> void:
	# Keywords such as Flavour, Mult, and Rating are colored in CardKeywordGlossary.
	_description.text = CardKeywordGlossary.to_bbcode(card.get_description_text())
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
	_description.offset_top = _description_offset_top + (REQUIREMENT_ROW_HEIGHT if _requirement_icons.visible else 0.0)
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


## Tints the inner border, name banner, and icon backdrop with the card type accent.
func _apply_accent(accent: Color) -> void:
	_border.modulate = accent
	_icon_backdrop.modulate = accent
	# Self modulate tints the banner art and leaves the name text alone.
	_name_banner.self_modulate = accent


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


## Largest font size whose wrapped lines fit the description box under the ribbon.
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
