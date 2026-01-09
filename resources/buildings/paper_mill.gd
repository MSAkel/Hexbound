extends Building

func trigger_building() -> void:
	super.trigger_building()
	GoodsManager.remove_good(GoodType.Type.GOLD, 3)
