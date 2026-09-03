class_name TilePanel
extends Control

@onready var card_icon: CardIcon = $PanelContainer/VBoxContainer/RunePanelContainer/RuneIconPanel/RuneIcon
@onready var card_name_label: Label = $PanelContainer/VBoxContainer/RunePanelContainer/RuneVBox/NameRow/RuneName
@onready var rarity_badge: PanelContainer = $PanelContainer/VBoxContainer/RunePanelContainer/RuneVBox/NameRow/RarityBadge
@onready var rarity_label: Label = $PanelContainer/VBoxContainer/RunePanelContainer/RuneVBox/NameRow/RarityBadge/RarityLabel
@onready var card_subtitle: Label = $PanelContainer/VBoxContainer/RunePanelContainer/RuneVBox/RuneSubtitle
@onready var card_chip_line: Label = $PanelContainer/VBoxContainer/RunePanelContainer/RuneVBox/RuneChipLine
@onready var card_description: RichTextLabel = $PanelContainer/VBoxContainer/RunePanelContainer/RuneVBox/RuneDescription
@onready var card_bonus_line: Label = $PanelContainer/VBoxContainer/RunePanelContainer/RuneVBox/RuneBonusLine
@onready var condiment_fuse_line: Label = $PanelContainer/VBoxContainer/RunePanelContainer/RuneVBox/CondimentFuseLine

const RARITY_BG_COLORS := {
	TileCard.TileCardRarity.COMMON: Color(0.7473333, 0.7472968, 0.77322227, 1),
	TileCard.TileCardRarity.UNCOMMON: Color(0.72, 0.86, 0.96, 1),
	TileCard.TileCardRarity.RARE: Color(0.82, 0.72, 0.94, 1),
}

var _rarity_badge_styles: Dictionary = {}

# Gap between the hovered spot and the panel edge.
const OFFSET := Vector2(12, 12)
const EMPTY_SPOT_ICON := preload("res://assets/tilesets/tile_dashed.png")

var hex: Hex = null
# Screen-space rect of the hovered spot (viewport / CanvasLayer coords).
var target_rect: Rect2 = Rect2()


func _ready() -> void:
	_build_rarity_badge_styles()
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.condiment_fuses_changed.connect(_on_condiment_fuses_changed)
	hide()
	# Keep above map UI chrome while ignoring mouse so hover can leave the spot.
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_hex(h: Hex, spot_rect: Rect2 = Rect2()) -> void:
	hex = h
	target_rect = spot_rect
	_refresh_spot_card()
	show()
	# Size may change with content. Position after the layout pass.
	call_deferred("_update_position")


# Re-anchor while still hovering (e.g. camera zoom / pan mid-hover).
func update_anchor(spot_rect: Rect2) -> void:
	target_rect = spot_rect
	_update_position()


func _refresh_spot_card() -> void:
	if hex.active_tile_card != null:
		var card := hex.active_tile_card
		card_icon.setup(card)
		card_name_label.text = card.name
		_set_rarity_badge(card)
		card_subtitle.text = card.get_inspect_subtitle()
		card_subtitle.visible = not card_subtitle.text.is_empty()
		_set_chip_line(card)
		var description_bbcode := CardKeywordGlossary.to_bbcode(card.description)
		card_description.text = description_bbcode
		_set_bonus_line(card)
		_set_condiment_fuse_line(card)
	else:
		card_icon.show_empty(EMPTY_SPOT_ICON)
		card_name_label.text = "Empty %s" % FeastDisplay.SPOT
		_hide_rarity_badge()
		card_subtitle.text = ""
		card_subtitle.hide()
		card_chip_line.hide()
		card_description.text = ""
		card_bonus_line.hide()
		condiment_fuse_line.hide()


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


func _set_rarity_badge(card: TileCard) -> void:
	var rarity := int(card.rarity)
	rarity_label.text = _get_rarity_display_name(rarity)
	var style: StyleBoxFlat = _rarity_badge_styles.get(
		rarity,
		_rarity_badge_styles[TileCard.TileCardRarity.COMMON]
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
		TileCard.TileCardRarity.UNCOMMON:
			return "Uncommon"
		TileCard.TileCardRarity.RARE:
			return "Rare"
		_:
			return "Common"


# Extra Flavour or Mult from other cards and passives. Hidden when there is none.
func _set_bonus_line(card: TileCard) -> void:
	var bonus := card.bonus_production_amount
	if is_zero_approx(bonus):
		card_bonus_line.hide()
		return
	var stat_label := FeastDisplay.MULT if card.product == TileCard.Product.MULTIPLIER else FeastDisplay.FLAVOUR
	var amount_text: String
	if card.product == TileCard.Product.MULTIPLIER:
		amount_text = CountingNumber.format_mult(bonus)
	else:
		amount_text = str(int(round(bonus)))
	if bonus > 0.0:
		card_bonus_line.text = "+%s %s" % [amount_text, stat_label]
	else:
		card_bonus_line.text = "%s %s" % [amount_text, stat_label]
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


func _on_close_button_pressed() -> void:
	hide()


func _on_toggle_spot_card_button_pressed() -> void:
	if hex.active_tile_card.is_active:
		hex.active_tile_card.is_active = false
	else:
		hex.active_tile_card.is_active = true
	hex.refresh_tile_card_visual_state()


func _on_turn_ended() -> void:
	hide()


func _on_condiment_fuses_changed() -> void:
	if visible and hex != null:
		_refresh_spot_card()
