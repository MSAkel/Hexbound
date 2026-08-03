class_name TriggerOrderType
extends Resource

# Activation order used when runes trigger at end of turn.
enum Type {
	TOP_LEFT_TO_BOTTOM_RIGHT,
	OUTER_RING_TO_INNER,
	CLOCKWISE_SPIRAL,
}


static func get_display_name(order: Type) -> String:
	match order:
		Type.TOP_LEFT_TO_BOTTOM_RIGHT:
			return "Top-left → bottom-right"
		Type.OUTER_RING_TO_INNER:
			return "Outer ring → inner ring"
		Type.CLOCKWISE_SPIRAL:
			return "Clockwise spiral"
		_:
			return "Unknown"


static func get_description(order: Type) -> String:
	match order:
		Type.TOP_LEFT_TO_BOTTOM_RIGHT:
			return "Runes activate from top-left to bottom-right across the map."
		Type.OUTER_RING_TO_INNER:
			return "Outer ring runes activate first, moving inward toward the center."
		Type.CLOCKWISE_SPIRAL:
			return "Runes activate in a clockwise spiral, starting at the center and expanding outward."
		_:
			return "Unknown"


static func get_all_types() -> Array[Type]:
	return [
		Type.TOP_LEFT_TO_BOTTOM_RIGHT,
		Type.OUTER_RING_TO_INNER,
		Type.CLOCKWISE_SPIRAL,
	]


static func get_preview_texture(order: Type) -> Texture2D:
	match order:
		Type.TOP_LEFT_TO_BOTTOM_RIGHT:
			return preload("res://assets/map/trigger_order/surveyor_trigger_order.png")
		Type.OUTER_RING_TO_INNER:
			return preload("res://assets/map/trigger_order/encircler_trigger_order.png")
		Type.CLOCKWISE_SPIRAL:
			return preload("res://assets/map/trigger_order/spiralist_trigger_order.png")
		_:
			return preload("res://assets/map/trigger_order/surveyor_trigger_order.png")
