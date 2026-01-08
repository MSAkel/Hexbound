extends Building

func trigger_building() -> void:
	for good in generated_goods:
		var amount = int(generated_goods[good])
		var final_amount = amount
		if final_amount > 0:
			# 50% chance to generate additional 1-2 resources
			if randf() < 0.5:
				final_amount += randi_range(1, 2)
			var good_type = get_good_type_from_id(good)
			if good_type != null:
				GoodsManager.add_good(good_type, final_amount)