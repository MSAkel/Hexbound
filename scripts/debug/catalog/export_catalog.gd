extends Node

## Writes every card, Technique, condiment, station and chef to one JSON file, using the
## game's own loaders and keyword text, so the catalog page always matches the build.
##
## godot --headless --path . res://scenes/debug/export_catalog.tscn -- --out=<path>
##   --out=<path>   Output file (default user://catalog.json). Absolute paths work.

const DEFAULT_OUT := "user://catalog.json"


func _ready() -> void:
	var out_path := DEFAULT_OUT
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_path = arg.substr("--out=".length())
	var data := {
		"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"exported_at": Time.get_datetime_string_from_system(true),
		"keywords": _keywords(),
		"cards": _cards(),
		"techniques": _techniques(),
		"condiments": _condiments(),
		"stations": _stations(),
		"chefs": _chefs(),
	}
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("export_catalog: cannot write %s (%s)" % [out_path, error_string(FileAccess.get_open_error())])
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("[catalog] wrote %s: %d cards, %d techniques, %d condiments, %d stations, %d chefs" % [
		ProjectSettings.globalize_path(out_path),
		data.cards.size(), data.techniques.size(), data.condiments.size(),
		data.stations.size(), data.chefs.size(),
	])
	get_tree().quit(0)


func _text(source: String) -> Dictionary:
	return {"raw": source, "plain": CardKeywordGlossary.to_plain(source)}


func _icon_path(texture: Texture2D) -> String:
	return texture.resource_path if texture != null else ""


func _script_name(resource: Resource) -> String:
	var script := resource.get_script() as Script
	return script.resource_path.get_file() if script != null else ""


func _keywords() -> Array:
	var result: Array = []
	for token: String in ["flavour", "mult", "garnish", "following", "destroy", "trigger"]:
		var keyword := CardKeywordGlossary.find_keyword(token)
		if keyword == null:
			continue
		result.append({
			"id": token,
			"label": CardKeywordGlossary.to_plain("{%s}" % token),
			"tooltip": CardKeywordGlossary.to_plain(keyword.tooltip),
		})
	return result


func _cards() -> Array:
	var result: Array = []
	for card: TileCard in GameManager.tile_cards_pool:
		var entry := {
			"id": card.id,
			"name": card.name,
			"type": GameTerms.get_tile_card_type_label(card),
			"kind": card.get_card_kind_label().capitalize(),
			"tags": card.ingredient_tags.map(func(tag: StringName) -> String: return GameTerms.get_ingredient_kind_label(tag)),
			"product": _product_label(card.product),
			"base_amount": card.base_production_amount,
			"rarity": Card.Rarity.keys()[card.rarity].capitalize(),
			"price": card.get_shop_price(),
			"starting_hand": card.starting_hand_eligible,
			"once_per_hour": card.single_activation_per_turn,
			"description": _text(card.description),
			"icon": _icon_path(card.icon),
			"file": card.resource_path,
			"script": _script_name(card),
		}
		if card is MealCard:
			var meal := card as MealCard
			var recipe := {}
			for pair: Array in [
				["Vegetable", meal.recipe_vegetable_count], ["Fruit", meal.recipe_fruit_count],
				["Meat", meal.recipe_meat_count], ["Seafood", meal.recipe_seafood_count],
				["Dairy", meal.recipe_dairy_count], ["Sweet", meal.recipe_sweet_count],
				["Seasoning", meal.recipe_seasoning_count], ["Kitchenware", meal.recipe_kitchenware_count],
			]:
				if int(pair[1]) > 0:
					recipe[pair[0]] = pair[1]
			entry["recipe"] = recipe
			entry["recipe_cards"] = meal.recipe_required_card_ids
		result.append(entry)
	return result


func _product_label(product: TileCard.Product) -> String:
	match product:
		TileCard.Product.GOLD:
			return GameTerms.GOLD
		TileCard.Product.FLAVOUR:
			return GameTerms.FLAVOUR
		TileCard.Product.MULTIPLIER:
			return GameTerms.MULT
		TileCard.Product.HYBRID:
			return GameTerms.HYBRID
	return "None"


func _techniques() -> Array:
	var result: Array = []
	for staff: StaffCard in StaffCatalog.get_all():
		result.append({
			"id": staff.id,
			"name": staff.name,
			"rarity": Card.Rarity.keys()[staff.rarity].capitalize(),
			"price": staff.get_shop_price(),
			"description": _text(staff.description),
			"file": staff.resource_path,
			"script": _script_name(staff),
		})
	return result


func _condiments() -> Array:
	var result: Array = []
	for condiment: Condiment in CondimentCatalog.get_all():
		result.append({
			"id": condiment.id,
			"name": condiment.display_name,
			"price": condiment.get_shop_price(),
			"effect": Condiment.EffectType.keys()[condiment.effect_type].capitalize(),
			"value": condiment.effect_value,
			"target": Condiment.TargetKind.keys()[condiment.target_kind].capitalize(),
			"color": condiment.liquid_color.to_html(false),
			"description": _text(condiment.description),
			"icon": _icon_path(condiment.icon),
			"file": condiment.resource_path,
		})
	return result


func _perks(perks: Array) -> Array:
	var result: Array = []
	for perk: StationPerk in perks:
		result.append(_text(perk.description))
	return result


func _stations() -> Array:
	var result: Array = []
	for entry: String in ResourceLoader.list_directory("res://resources/stations/"):
		if not entry.ends_with(".tres"):
			continue
		var station := load("res://resources/stations/" + entry) as StationType
		if station == null:
			continue
		var needs := {}
		for key: Variant in station.required_counts:
			needs[GameTerms.get_ingredient_kind_label(StringName(key))] = station.required_counts[key]
		result.append({
			"id": station.id,
			"name": station.display_name,
			"color": station.color.to_html(false),
			"needs": needs,
			"level_perks": _perks(station.level_perks),
			"choices": _perks(station.choice_options),
			"icon": _icon_path(station.icon),
			"file": station.resource_path,
		})
	return result


func _chefs() -> Array:
	var result: Array = []
	for chef: ChefDefinition in ChefRegistry.get_all_chefs():
		result.append({
			"id": chef.id,
			"name": chef.display_name,
			"speciality": _text(chef.speciality_description),
			"icon": _icon_path(chef.icon),
			"file": chef.resource_path,
		})
	return result
