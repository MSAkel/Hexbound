extends PanelContainer

@onready var amount_label: Label = $HBoxContainer/AmountLabel
@onready var round_label: Label = $HBoxContainer/RoundLabel

func _ready() -> void:
	amount_label.text = str(GoldManager.amount)
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.turn_started.connect(_update_round_label)


func _on_gold_changed(new_amount: int) -> void:
	amount_label.text = str(new_amount)

func _update_round_label() -> void:
	round_label.text = "Round %s" % [GameManager.current_round]
