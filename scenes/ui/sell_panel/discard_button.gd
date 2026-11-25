extends Button

## Discard, under End Hour. Throws the whole hand away and draws as many new cards, using one of the
## Day's discards (DeckManager.HAND_DISCARDS_PER_DAY) and no play. The label counts what is left.
## Disabled while the hand can't discard (mid-play, between Hours, in menus, none left).

const LABEL_FORMAT := "Discard (%d)"


func _ready() -> void:
	pressed.connect(_on_pressed)


func _process(_delta: float) -> void:
	var hand := _find_hand()
	disabled = hand == null or not hand.can_discard_hand()
	var label := LABEL_FORMAT % DeckManager.discards_left
	if text != label:
		text = label


func _on_pressed() -> void:
	var hand := _find_hand()
	if hand != null and hand.can_discard_hand():
		hand.discard_hand()


func _find_hand() -> Hand:
	return get_tree().get_first_node_in_group("run_hand") as Hand
