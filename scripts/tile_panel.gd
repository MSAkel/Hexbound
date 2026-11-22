class_name TilePanel
extends Control

@onready var card_icon: CardIcon = $VBoxContainer/RunePanelContainer/RuneIconPanel/RuneIcon
@onready var card_name_label: Label = $VBoxContainer/RunePanelContainer/RuneVBox/NameRow/RuneName
@onready var rarity_badge: PanelContainer = $VBoxContainer/RunePanelContainer/RuneVBox/NameRow/RarityBadge
@onready var rarity_label: Label = $VBoxContainer/RunePanelContainer/RuneVBox/NameRow/RarityBadge/RarityLabel
@onready var card_subtitle: RichTextLabel = $VBoxContainer/RunePanelContainer/RuneVBox/RuneSubtitle
@onready var card_chip_line: Label = $VBoxContainer/RunePanelContainer/RuneVBox/RuneChipLine
@onready var card_recipe_line: Label = $VBoxContainer/RunePanelContainer/RuneVBox/RuneRecipeLine
@onready var card_description: RichTextLabel = $VBoxContainer/RunePanelContainer/RuneVBox/RuneDescription
@onready var card_bonus_line: Label = $VBoxContainer/RunePanelContainer/RuneVBox/RuneBonusLine
@onready var condiment_fuse_line: Label = $VBoxContainer/RunePanelContainer/RuneVBox/CondimentFuseLine
@onready var icon_box: PanelContainer = $VBoxContainer/RunePanelContainer/RuneIconPanel

const EMPTY_SPOT_TEXTURE: Texture2D = preload("res://assets/gui/panels/box_tile.png")
const SUBTITLE_DOT_TEXTURE: Texture2D = preload("res://assets/gui/dividers/dot.png")
## The tooltip art is pixel art drawn at twice its file size, like the design mockup.
const PIXEL_ART_SCALE := 2
## Card picture size inside the icon box.
const ICON_SIZE := Vector2(80, 80)
## Keywords in this panel use the design's teal, not the card face green.
const KEYWORD_COLOR := Color(0.1764706, 0.49019608, 0.50980395, 1)
const SUBTITLE_COLOR := Color(0.4509804, 0.18039216, 0.24313726, 1)
## Spaces either side of the dot between subtitle parts.
const SUBTITLE_GAP := "  "
const RARITY_BG_COLORS := {
	Card.Rarity.COMMON: Color(0.7473333, 0.7472968, 0.77322227, 1),
	Card.Rarity.UNCOMMON: Color(0.72, 0.86, 0.96, 1),
	Card.Rarity.RARE: Color(0.82, 0.72, 0.94, 1),
}

var _rarity_badge_styles: Dictionary = {}
var _subtitle_dot: Texture2D = null

# Gap between the hovered spot and the panel edge.
const OFFSET := Vector2(12, 12)

var hex: Hex = null
# Card shown through show_card. Null while the panel inspects a spot.
var _shown_card: Card = null
# Screen-space rect of the hovered spot (viewport / CanvasLayer coords).
var target_rect: Rect2 = Rect2()


func _ready() -> void:
	_build_rarity_badge_styles()
	_apply_pixel_art_styles()
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.condiment_fuses_changed.connect(_on_condiment_fuses_changed)
	hide()
	# Keep above map UI chrome while ignoring mouse so hover can leave the spot.
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ignore_mouse_on_descendants(self)
	_pin_content_sized_layout()
	_pin_rune_icon_size()
	reset_size()


func set_hex(h: Hex, spot_rect: Rect2 = Rect2()) -> void:
	hex = h
	_shown_card = null
	target_rect = spot_rect
	_refresh_spot_card()
	show()
	# Size may change with content. Fit, then position after the layout pass.
	call_deferred("_fit_and_position")


## Inspection for Staff cards.
func show_card(card: Card, anchor_rect: Rect2) -> void:
	if card == null:
		return
	hex = null
	_shown_card = card
	target_rect = anchor_rect
	card_icon.setup(card)
	card_name_label.text = card.name
	_set_rarity_badge(card)
	_set_subtitle("")
	card_chip_line.hide()
	card_recipe_line.hide()
	condiment_fuse_line.hide()
	card_description.text = CardKeywordGlossary.to_bbcode(card.get_tooltip_description_text(), KEYWORD_COLOR)
	card_bonus_line.hide()
	show()
	call_deferred("_fit_and_position")


## Closes the panel only if it is still showing this card.
func hide_card(card: Card) -> void:
	if _shown_card != card:
		return
	_shown_card = null
	hide()


# Re-anchor while still hovering (e.g. camera zoom / pan mid-hover).
func update_anchor(spot_rect: Rect2) -> void:
	target_rect = spot_rect
	_update_position()


func _refresh_spot_card() -> void:
	if hex.active_tile_card != null:
		var card := hex.active_tile_card
		card_icon.setup(card)
		card_name_label.text = card.name
		# Spot cards have no rarity. Only staff show the badge.
		_hide_rarity_badge()
		_set_subtitle(card.get_inspect_subtitle())
		_set_chip_line(card)
		_set_recipe_line(card)
		var description_bbcode := CardKeywordGlossary.to_bbcode(card.get_tooltip_description_text(), KEYWORD_COLOR)
		card_description.text = description_bbcode
		_set_bonus_line(card)
		_set_condiment_fuse_line(card)
	else:
		card_icon.show_empty(EMPTY_SPOT_TEXTURE)
		card_name_label.text = "Empty %s" % GameTerms.SPOT
		_hide_rarity_badge()
		_set_subtitle("")
		card_chip_line.hide()
		card_recipe_line.hide()
		card_description.text = ""
		card_bonus_line.hide()
		condiment_fuse_line.hide()


## Subtitle parts such as "Kitchenware  ·  Mult" are split by a dot image.
## Parts that are keywords (Mult, Flavour, Garnish...) take the keyword colour.
func _set_subtitle(text: String) -> void:
	card_subtitle.clear()
	var parts: Array[String] = []
	for raw: String in text.split("·", false):
		var part := raw.strip_edges()
		if not part.is_empty():
			parts.append(part)
	if parts.is_empty():
		card_subtitle.hide()
		return
	for i in parts.size():
		if i > 0:
			card_subtitle.add_text(SUBTITLE_GAP)
			card_subtitle.add_image(_subtitle_dot, 0, 0, Color.WHITE, INLINE_ALIGNMENT_CENTER)
			card_subtitle.add_text(SUBTITLE_GAP)
		var is_keyword := CardKeywordGlossary.find_keyword(parts[i].to_lower()) != null
		card_subtitle.push_color(KEYWORD_COLOR if is_keyword else SUBTITLE_COLOR)
		card_subtitle.add_text(parts[i])
		card_subtitle.pop()
	card_subtitle.show()


## The panel, icon box and dot are drawn at PIXEL_ART_SCALE with crisp pixels.
## StyleBoxTexture has no scale, so the textures are enlarged once here.
func _apply_pixel_art_styles() -> void:
	var panel_style := get_theme_stylebox("panel") as StyleBoxTexture
	if panel_style != null:
		add_theme_stylebox_override("panel", _pixel_scaled_style(panel_style, PIXEL_ART_SCALE))
	var box_style := icon_box.get_theme_stylebox("panel") as StyleBoxTexture
	if box_style != null:
		icon_box.add_theme_stylebox_override("panel", _pixel_scaled_style(box_style, PIXEL_ART_SCALE))
	_subtitle_dot = _pixel_scaled_texture(SUBTITLE_DOT_TEXTURE, PIXEL_ART_SCALE)


## Same nine-slice with the texture and its texture margins enlarged. Content margins stay as authored.
static func _pixel_scaled_style(style: StyleBoxTexture, factor: int) -> StyleBoxTexture:
	var scaled := style.duplicate() as StyleBoxTexture
	scaled.texture = _pixel_scaled_texture(style.texture, factor)
	scaled.texture_margin_left = style.texture_margin_left * factor
	scaled.texture_margin_top = style.texture_margin_top * factor
	scaled.texture_margin_right = style.texture_margin_right * factor
	scaled.texture_margin_bottom = style.texture_margin_bottom * factor
	return scaled


static func _pixel_scaled_texture(texture: Texture2D, factor: int) -> Texture2D:
	if texture == null or factor <= 1:
		return texture
	var image := texture.get_image()
	if image == null:
		return texture
	if image.is_compressed():
		image.decompress()
	image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


func _set_chip_line(card: TileCard) -> void:
	var chip: Dictionary = card.get_board_chip(hex)
	var mode: TileCard.BoardChipMode = chip.get("mode", TileCard.BoardChipMode.HIDDEN)
	# Amount chips are a bare total. The bonus line under the description covers that.
	if mode == TileCard.BoardChipMode.HIDDEN or mode == TileCard.BoardChipMode.AMOUNT:
		card_chip_line.hide()
		return
	var detail: String = str(chip.get("detail", ""))
	var chip_text := str(chip.get("text", ""))
	if chip_text.is_empty() and detail.is_empty():
		card_chip_line.hide()
		return
	if detail.is_empty():
		card_chip_line.text = chip_text
	else:
		card_chip_line.text = "%s  ·  %s" % [chip_text, detail]
	card_chip_line.show()


func _set_recipe_line(card: TileCard) -> void:
	var meal := card as MealCard
	if meal == null:
		card_recipe_line.hide()
		return
	var recipe_text := meal.get_inspect_recipe_text(hex)
	if recipe_text.is_empty():
		card_recipe_line.hide()
		return
	card_recipe_line.text = recipe_text
	card_recipe_line.show()


func _set_rarity_badge(card: Card) -> void:
	var rarity := int(card.rarity)
	rarity_label.text = _get_rarity_display_name(rarity)
	var style: StyleBoxFlat = _rarity_badge_styles.get(
		rarity,
		_rarity_badge_styles[Card.Rarity.COMMON]
	)
	rarity_badge.add_theme_stylebox_override("panel", style)
	rarity_badge.show()


func _build_rarity_badge_styles() -> void:
	_rarity_badge_styles.clear()
	for rarity: int in RARITY_BG_COLORS.keys():
		var style := StyleBoxFlat.new()
		style.content_margin_left = 8.0
		style.content_margin_top = 3.0
		style.content_margin_right = 8.0
		style.content_margin_bottom = 3.0
		style.corner_radius_top_left = 999
		style.corner_radius_top_right = 999
		style.corner_radius_bottom_right = 999
		style.corner_radius_bottom_left = 999
		style.bg_color = RARITY_BG_COLORS[rarity]
		_rarity_badge_styles[rarity] = style


func _hide_rarity_badge() -> void:
	rarity_badge.hide()


func _get_rarity_display_name(rarity: int) -> String:
	match rarity:
		Card.Rarity.UNCOMMON:
			return "Uncommon"
		Card.Rarity.RARE:
			return "Rare"
		_:
			return "Common"


# Star level output scale. Hidden for 1-star cards.
func _set_bonus_line(card: TileCard) -> void:
	var lines: Array[String] = []
	if card.star_level > 1:
		lines.append("%s: x%s Flavour, Gold, +Mult, xMult (above x1)" % [TileCard.star_text(card.star_level), String.num(card.star_output_scale(), 2)])
	if lines.is_empty():
		card_bonus_line.hide()
		return
	card_bonus_line.text = "
".join(lines)
	card_bonus_line.show()


func _set_condiment_fuse_line(card: TileCard) -> void:
	if hex == null:
		condiment_fuse_line.hide()
		return
	var lines := CondimentManager.get_inspect_lines(card, hex.coordinates)
	if lines.is_empty():
		condiment_fuse_line.hide()
		return
	condiment_fuse_line.text = "\n".join(lines)
	condiment_fuse_line.show()


## Keep this inspect card content-sized. PanelContainer will not shrink on its own
## after a bad layout pass, and CanvasLayer children can pick up a fullscreen size.
func _pin_content_sized_layout() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	anchor_right = 0.0
	anchor_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN


## CardIcon.tscn is authored at 256px and scales with its host.
## In this panel it must stay an ICON_SIZE thumbnail inside the icon box.
func _pin_rune_icon_size() -> void:
	card_icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card_icon.anchor_right = 0.0
	card_icon.anchor_bottom = 0.0
	card_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_icon.custom_minimum_size = ICON_SIZE
	card_icon.size = ICON_SIZE
	card_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ignore_mouse_on_descendants(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse_on_descendants(child)


func _fit_and_position() -> void:
	_pin_content_sized_layout()
	_pin_rune_icon_size()
	_ignore_mouse_on_descendants(self)
	reset_size()
	_update_position()


# Position next to the spot, flipping sides when near viewport edges (same idea as Tooltip).
func _update_position() -> void:
	if target_rect == Rect2():
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var panel_pos := Vector2(target_rect.end.x + OFFSET.x, target_rect.position.y)

	# Prefer right of the spot. Flip to the left if it would clip.
	if panel_pos.x + size.x > viewport_size.x:
		panel_pos.x = target_rect.position.x - size.x - OFFSET.x

	# Prefer top-aligned with the spot. Shift up if it would clip at the bottom.
	if panel_pos.y + size.y > viewport_size.y:
		panel_pos.y = target_rect.end.y - size.y

	position = panel_pos
	_clamp_to_viewport()


func _clamp_to_viewport() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	position.x = clampf(position.x, 0.0, maxf(viewport_size.x - size.x, 0.0))
	position.y = clampf(position.y, 0.0, maxf(viewport_size.y - size.y, 0.0))


func _on_turn_ended() -> void:
	hide()


func _on_condiment_fuses_changed() -> void:
	if visible and hex != null:
		_refresh_spot_card()
		call_deferred("_fit_and_position")
