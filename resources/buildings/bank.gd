extends Building


func trigger_building() -> void:
    GameManager.gold_count += generation_amount
    