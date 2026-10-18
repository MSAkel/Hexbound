class_name Card
extends Resource

# Shared hand and shop payload for TileCard and StaffCard. CardUI binds to this type.

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
}

@export var id: String
@export var name: String
@export var icon: Texture2D
@export_multiline var description: String
@export var rarity: Rarity

const DEFAULT_PRICE := 2


## Description shown on faces and panels. Cards with live counters extend it.
func get_description_text() -> String:
	return description


# Full placement validity, including tile occupancy and restrictions.
func can_play_on(_hex: Hex) -> bool:
	return false


# Occupancy check used for restriction overlays before can_place_on_tile.
func is_placement_candidate(_hex: Hex) -> bool:
	return false


# Apply this card to hex. TileCard places or modifies the board.
func play_on(_hex: Hex, _animate: bool = true) -> void:
	pass


# Short type strip for CardUI, such as Food or Kitchenware.
func get_card_kind_label() -> String:
	return ""


# Save key written into hand snapshots.
func get_save_kind() -> String:
	return ""


func get_shop_price(discount: float = 0.0) -> int:
	return _apply_merchant_discount(DEFAULT_PRICE, discount)


## Why the merchant cannot sell this card right now. Empty when it can be bought.
func get_purchase_block_reason() -> String:
	return ""


func _apply_merchant_discount(base_price: int, discount: float) -> int:
	var multiplier := Difficulty.get_merchant_price_multiplier(GameManager.selected_difficulty) - discount
	return maxi(1, int(round(base_price * multiplier)))
