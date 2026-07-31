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


static func get_all_types() -> Array[Type]:
	return [
		Type.TOP_LEFT_TO_BOTTOM_RIGHT,
		Type.OUTER_RING_TO_INNER,
		Type.CLOCKWISE_SPIRAL,
	]
