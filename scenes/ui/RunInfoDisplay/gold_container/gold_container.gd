extends PanelContainer

@onready var amount_label: Label = $HBoxContainer/AmountLabel

func _ready() -> void:
	amount_label.text = str(GoldManager.amount)
	Events.gold_changed.connect(_on_gold_changed)


func _on_gold_changed(new_amount: int) -> void:
	amount_label.text = str(new_amount)
