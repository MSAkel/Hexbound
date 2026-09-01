class_name MerchantPurchaseTray
extends HBoxContainer

## Compact buy controls shown beneath a selected merchant shelf item.

signal gold_purchase_pressed
signal token_purchase_pressed

@onready var _gold_button: Button = $GoldButton
@onready var _token_button: Button = $TokenButton


# Scene buttons forward to these so CardUI can emit purchase requests with a card identity.
func _on_gold_button_pressed() -> void:
	gold_purchase_pressed.emit()


func _on_token_button_pressed() -> void:
	token_purchase_pressed.emit()


func set_gold_enabled(enabled: bool) -> void:
	_gold_button.disabled = not enabled


func set_token_enabled(enabled: bool) -> void:
	_token_button.disabled = not enabled
