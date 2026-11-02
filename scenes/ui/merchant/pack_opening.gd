class_name PackOpening
extends PanelContainer

## Shown over the shelf after a pack is bought: its cards face up, keep one or take nothing.
## The merchant owns the rules (gold, saving, where the kept card goes). This only shows the choice.
## It lives inside the merchant's content panel, so Show Board hides it with the shelf.

signal card_kept(card: Card, shelf_rect: Rect2)
signal skipped

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")
const CARD_SCALE := 1.15
const CARD_BASE_SIZE := Vector2(214, 317)
const TITLE_COLOR := Color(0.97, 0.93, 0.8, 1.0)
const SUBTITLE_COLOR := Color(0.9, 0.82, 0.62, 1.0)

var _title: Label
var _subtitle: Label
var _row: HBoxContainer
var _skip_button: Button
var _card_uis: Array[CardUI] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Below the Show Board button (z 2) so the player can still peek at the board.
	z_index = 1
	var wash := StyleBoxFlat.new()
	wash.bg_color = Color(0.03, 0.05, 0.04, 0.9)
	add_theme_stylebox_override("panel", wash)
	_build()
	hide()


func is_open() -> bool:
	return visible


## Shows the cards of an opened pack. Replaces whatever was showing.
func present(kind: MerchantPacks.Kind, cards: Array[Card]) -> void:
	_clear_cards()
	_title.text = MerchantPacks.display_name(kind)
	_subtitle.text = "Keep 1 of %d" % cards.size() if cards.size() > 1 else "Keep it"
	for card in cards:
		_add_card(card)
	show()
	call_deferred("focus_first")


func close() -> void:
	_clear_cards()
	hide()


## Gamepad focus lands on the first card. Mouse and keyboard players are left alone.
func focus_first() -> void:
	if not visible or not InputManager.is_using_gamepad():
		return
	if not _card_uis.is_empty():
		_card_uis[0].grab_focus()
	else:
		_skip_button.grab_focus()


func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", TITLE_COLOR)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 22)
	_subtitle.add_theme_color_override("font_color", SUBTITLE_COLOR)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 26)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_row)

	_skip_button = Button.new()
	_skip_button.text = "Take nothing"
	_skip_button.custom_minimum_size = Vector2(240, 48)
	_skip_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_skip_button.add_theme_font_size_override("font_size", 21)
	_skip_button.pressed.connect(_on_skip_pressed)
	column.add_child(_skip_button)


func _add_card(card: Card) -> void:
	# The slot reserves the scaled size; the card itself is visually scaled up.
	var slot := Control.new()
	slot.custom_minimum_size = CARD_BASE_SIZE * CARD_SCALE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(slot)
	var card_ui: CardUI = CARD_UI_SCENE.instantiate()
	slot.add_child(card_ui)
	card_ui.scale = Vector2.ONE * CARD_SCALE
	card_ui.configure_interaction(CardUI.InteractionMode.CHOICE)
	card_ui.set_card(card)
	card_ui.action_requested.connect(_on_card_chosen)
	_card_uis.append(card_ui)


func _clear_cards() -> void:
	_card_uis.clear()
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()


func _on_card_chosen(card_ui: CardUI) -> void:
	var card := card_ui.card
	var rect := card_ui.get_global_rect()
	close()
	card_kept.emit(card, rect)


func _on_skip_pressed() -> void:
	close()
	skipped.emit()
