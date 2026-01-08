extends Building

func activate_passive() -> void:
    GameManager.influence_progress += 0.1
    GoodsManager.remove_good(GoodType.Type.FOOD, 3)