extends Building

func activate_passive() -> void:
	GameManager.explores_per_turn += 1
	# Immediate update of the explore count
	GameManager.available_explores += 1
