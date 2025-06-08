extends Building

func trigger_building() -> void:
	# GameManager.insight_count += generation_amount + temporary_boost
	GoodsManager.add_good( generated_good, generation_amount + temporary_boost)
	reset_temporary_boost()
