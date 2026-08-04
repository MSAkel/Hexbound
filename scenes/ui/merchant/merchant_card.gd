class_name MerchantCard
extends Control

signal purchased(card: Resource)

# Fallback prices when a rune has no rarity set in its resource.
const BASE_PRICE_BY_RARITY := {
	Rune.RuneRarity.COMMON: 15,
	Rune.RuneRarity.UNCOMMON: 30,
	Rune.RuneRarity.RARE: 45,
}
const DEFAULT_PRICE := 10
const ENHANCEMENT_BASE_PRICE := 30

@onready var price_label: Label = $Container/PriceLabel
@onready var card_name: Label = $Container/CardPanel/CardDetailsContainer/NameContainer/CardName
@onready var icon: TextureRect = $Container/CardPanel/CardDetailsContainer/IconContainer/Icon
@onready var card_description: Label = $Container/CardPanel/CardDetailsContainer/CardDescription
@onready var card_type_label: Label = $Container/CardPanel/CardDetailsContainer/IconContainer/CardTypeLabel
@onready var sold_overlay: Panel = $Container/CardPanel/SoldOverlay
@onready var card_panel: Panel = $Container/CardPanel

var card: Resource
var price: int = 0

var _is_sold := false
var _discount := 0.0


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


# Populate card visuals and compute the sale price for a rune or enhancement.
func setup(card_data: Resource, discount: float = 0.0) -> void:
	if not is_node_ready():
		await ready

	card = card_data
	_discount = discount
	_is_sold = false
	sold_overlay.visible = false

	if card_data is Rune:
		var rune := card_data as Rune
		card_name.text = rune.name
		icon.texture = rune.icon
		card_description.text = rune.description
		card_type_label.text = _get_rune_type_label(rune.type)
		card_type_label.visible = true
		price = get_price_for_rune(rune, discount)
	elif card_data is Enhancement:
		var enhancement := card_data as Enhancement
		card_name.text = enhancement.name
		icon.texture = enhancement.icon
		card_description.text = enhancement.description
		card_type_label.text = "Enhancement"
		card_type_label.visible = true
		price = get_price_for_enhancement(discount)
	else:
		push_error("MerchantCard.setup received unsupported resource type")
		return

	price_label.text = "$%d" % price
	_update_affordability()


static func get_price_for_rune(card_rune: Rune, discount: float = 0.0) -> int:
	var base_price: int = BASE_PRICE_BY_RARITY.get(card_rune.rarity, DEFAULT_PRICE)
	return maxi(1, int(round(base_price * (1.0 - discount))))


static func get_price_for_enhancement(discount: float = 0.0) -> int:
	return maxi(1, int(round(ENHANCEMENT_BASE_PRICE * (1.0 - discount))))


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
	if card is Rune:
		price = get_price_for_rune(card as Rune, _discount)
	elif card is Enhancement:
		price = get_price_for_enhancement(_discount)
	price_label.text = "$%d" % price
	_update_affordability()


func _update_affordability() -> void:
	var can_afford := GoldManager.can_afford(price)
	# Price color communicates affordability; the card itself stays unchanged.
	price_label.modulate = Color.WHITE if can_afford else Color.RED
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_afford else Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	if _is_sold:
		return

	if event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if not GoldManager.can_afford(price):
			return

		purchased.emit(card)
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
		Rune.RuneType.PRODUCER:
			return "Producer"
		Rune.RuneType.SUPPORT:
			return "Support"
		Rune.RuneType.HYBRID:
			return "Hybrid"
		_:
			return "Rune"
