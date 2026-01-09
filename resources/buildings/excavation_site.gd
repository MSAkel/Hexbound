extends Building

func trigger_building() -> void:
	for good in generated_goods:
		var amount = int(generated_goods[good])
		var final_amount = amount
		if final_amount > 0:
			# 50% chance to generate additional 1-2 resources
		if randf() < 0.5:
			final_amount += randi_range(1, 2)
		if GoodType.ID_TO_TYPE.has(good.to_lower()):
			var good_type = GoodType.get_type_from_id(good)
			GoodsManager.add_good(good_type, final_amount)