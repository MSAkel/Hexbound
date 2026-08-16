class_name Enhancement
extends Card

# Player-applied bonus attached to a placed tile card. Effects are independent of the host's
# product type, so a mult producer can receive a score enhancement and vice versa.

enum Type {
	SCORE,
	MULTIPLIER,
	GOLD,
	TRIGGER,
}

const ENHANCEMENT_BASE_PRICE := 30

@export var type: Type
@export var short_description: String

# Bonus output resolved each time the host tile card activates.
@export var score_bonus: int = 0
@export var mult_bonus: int = 0
@export var gold_bonus: int = 0
# Extra activations of the host tile card (including its enhancement) before tile flow continues.
@export var trigger_count: int = 0


func get_card_kind_label() -> String:
	return "Enhancement"


func get_save_kind() -> String:
	return "enhancement"


func get_shop_price(discount: float = 0.0) -> int:
	return _apply_merchant_discount(ENHANCEMENT_BASE_PRICE, discount)


func can_play_on(hex: Hex) -> bool:
	if hex.is_disabled_by_difficulty:
		return false
	return can_apply_to(hex)


func is_placement_candidate(hex: Hex) -> bool:
	if hex.is_disabled_by_difficulty:
		return false
	return can_apply_to(hex)


func play_on(hex: Hex) -> void:
	hex.try_apply_enhancement(self)


# Enhancement cards target occupied tiles whose tile card does not already have one.
static func can_apply_to(hex: Hex) -> bool:
	if hex.active_tile_card == null:
		return false
	return hex.active_tile_card.enhancement == null


# Resolve enhancement output using the host tile card's activation helpers so empower scaling applies.
func activate(host_tile_card: TileCard, tile: Hex) -> void:
	if type == Type.SCORE:
		host_tile_card.add_score(tile, score_bonus)
	if type == Type.MULTIPLIER:
		host_tile_card.add_multiplier(tile, mult_bonus)
	if type == Type.GOLD:
		host_tile_card.add_gold(tile, gold_bonus)
	if type == Type.TRIGGER:
		var retriggers: Array[TileCard] = []
		retriggers.resize(trigger_count)
		retriggers.fill(host_tile_card)
		host_tile_card.queue_tile_card_triggers(tile, retriggers)
