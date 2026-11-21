extends Node
# Temporary: sets the Sommelier perk scale in memory (env SOMM_SCALE), then starts the playtest runner.

func _ready() -> void:
	var def := load("res://resources/chefs/sommelier.tres") as ChefDefinition
	var scale_text := OS.get_environment("SOMM_SCALE")
	if not scale_text.is_empty():
		def.perk.set("scale", float(scale_text))
	Engine.set_meta("tmp_somm_keep", def)
	for chef: ChefDefinition in ChefRegistry.get_all_chefs():
		if chef.id == "sommelier":
			print("[tmp] sommelier perk scale = ", chef.perk.get("scale"), " same instance: ", chef == def)
	get_tree().change_scene_to_file.call_deferred("res://scenes/debug/playtest_runner.tscn")
