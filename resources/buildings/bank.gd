extends Building


func trigger_building() -> void:
	GoodsManager.add_good(generated_good, generation_amount)
