extends Button

## End Hour, under the chef portrait. Ends the Hour now and discards the cards left in hand.
## Disabled while the hand can't end the Hour (mid-play, between Hours, in menus).


func _ready() -> void:
	pressed.connect(_on_pressed)


func _process(_delta: float) -> void:
	var hand := _find_hand()
	disabled = hand == null or not hand.can_end_hour()


func _on_pressed() -> void:
	var hand := _find_hand()
	if hand != null and hand.can_end_hour():
		hand.end_hour()


func _find_hand() -> Hand:
	return get_tree().get_first_node_in_group("run_hand") as Hand
