class_name MerchantCard
extends Control

signal purchased(rune: Rune)

# Fallback prices when a rune has no rarity set in its resource.
const BASE_PRICE_BY_RARITY := {
	Rune.RuneRarity.COMMON: 10,
	Rune.RuneRarity.UNCOMMON: 25,
	Rune.RuneRarity.RARE: 30,
}
const DEFAULT_PRICE := 10

@onready var price_label: Label = $Container/PriceLabel
@onready var card_name: Label = $Container/CardPanel/CardDetailsContainer/NameContainer/CardName
@onready var icon: TextureRect = $Container/CardPanel/CardDetailsContainer/IconContainer/Icon
@onready var card_description: Label = $Container/CardPanel/CardDetailsContainer/CardDescription
@onready var card_type_label: Label = $Container/CardPanel/CardDetailsContainer/IconContainer/CardTypeLabel
@onready var sold_overlay: Panel = $Container/CardPanel/SoldOverlay
@onready var card_panel: Panel = $Container/CardPanel

var rune: Rune
var price: int = 0

var _is_sold := false
var _discount := 0.0


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


# Populate card visuals and compute the sale price for the given rune.
func setup(card_rune: Rune, discount: float = 0.0) -> void:
	if not is_node_ready():
		await ready

	rune = card_rune
	_discount = discount
	_is_sold = false
	sold_overlay.visible = false

	card_name.text = rune.name
	icon.texture = rune.icon
	card_description.text = rune.description
	card_type_label.text = _get_rune_type_label(rune.type)
	card_type_label.visible = true

	price = get_price_for_rune(rune, discount)
	price_label.text = "$%d" % price
	_update_affordability()


static func get_price_for_rune(card_rune: Rune, discount: float = 0.0) -> int:
	var base_price: int = BASE_PRICE_BY_RARITY.get(card_rune.rarity, DEFAULT_PRICE)
	return maxi(1, int(round(base_price * (1.0 - discount))))


func is_sold() -> bool:
	return _is_sold


func mark_sold() -> void:
	_is_sold = true
	sold_overlay.visible = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW


# Re-check gold after purchases elsewhere in the merchant panel.
func refresh_affordability() -> void:
	if _is_sold:
		return
	_update_affordability()


# Recompute the listed price when a merchant discount boon is applied.
func apply_discount(discount: float) -> void:
	if _is_sold:
		return

	_discount = discount
	price = get_price_for_rune(rune, _discount)
	price_label.text = "$%d" % price
	_update_affordability()


func _update_affordability() -> void:
	var can_afford := GameManager.get_gold() >= price
	# Price color communicates affordability; the card itself stays unchanged.
	price_label.modulate = Color.WHITE if can_afford else Color.RED
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_afford else Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	if _is_sold:
		return

	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if GameManager.get_gold() < price:
			return

		purchased.emit(rune)
		accept_event()


func _on_mouse_entered() -> void:
	if _is_sold:
		return

	#if GameManager.get_gold() >= price:
		# card_panel.modulate = Color(1.1, 1.15, 0.9, 1.0)


func _on_mouse_exited() -> void:
	if _is_sold:
		return


func _get_rune_type_label(rune_type: Rune.RuneType) -> String:
	match rune_type:
		Rune.RuneType.GENERATION:
			return "Generation"
		Rune.RuneType.SUPPORT:
			return "Support"
		Rune.RuneType.HYBRID:
			return "Hybrid"
		_:
			return "Rune"
