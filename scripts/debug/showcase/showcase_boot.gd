extends Node

## Boots the showcase driver on the root so it survives the switch to the main scene.

func _ready() -> void:
	var driver := Node.new()
	driver.set_script(preload("res://scripts/debug/showcase/showcase_driver.gd"))
	get_tree().root.add_child.call_deferred(driver)
