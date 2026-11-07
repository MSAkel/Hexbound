extends Node

## Content sanity check for CI: fails when content a shop depends on loads empty.
## Empty content raises no error. A moved Technique folder once left the catalog empty, the
## merchant's Technique slot vanished, and every other check stayed green.
## Prints [content] lines and exits 1 when any check fails.
##   godot --headless --path . res://scenes/debug/content_check.tscn

var _failures := 0


func _ready() -> void:
	# One frame so the autoloads finish their own setup.
	await get_tree().process_frame
	_check_techniques()
	_check_condiments()
	_check_tile_pool()
	_check_merchant_shelf()
	if _failures > 0:
		print("[content] FAILED: %d check(s)" % _failures)
	else:
		print("[content] all checks passed")
	get_tree().quit(1 if _failures > 0 else 0)


func _check(check_name: String, passed: bool, detail: String) -> void:
	if passed:
		print("[content] PASS %s: %s" % [check_name, detail])
		return
	_failures += 1
	print("[content] FAIL %s: %s" % [check_name, detail])
	# Also an ERROR: line, which godot_checks.sh's log scan treats as a failure.
	push_error("Content check failed: %s (%s)" % [check_name, detail])


func _check_techniques() -> void:
	var count := StaffCatalog.get_all().size()
	_check("Technique catalog", count > 0, "%d Techniques loaded" % count)


func _check_condiments() -> void:
	var count := CondimentCatalog.get_all().size()
	_check("Condiment catalog", count > 0, "%d condiments loaded" % count)


## The merchant, card picks and packs draw from these. A type with no cards hides its pack.
func _check_tile_pool() -> void:
	var counts := {
		TileCard.TileCardType.INGREDIENT: 0,
		TileCard.TileCardType.KITCHENWARE: 0,
		TileCard.TileCardType.MEAL: 0,
	}
	for tile_card in GameManager.tile_cards_pool:
		if counts.has(tile_card.type):
			counts[tile_card.type] += 1
	var detail := "%d Ingredients, %d Kitchenware, %d Meals" % [
		counts[TileCard.TileCardType.INGREDIENT],
		counts[TileCard.TileCardType.KITCHENWARE],
		counts[TileCard.TileCardType.MEAL],
	]
	var all_present := true
	for type_count: int in counts.values():
		all_present = all_present and type_count > 0
	_check("Tile card pool", all_present, detail)


## The exact symptom: the merchant has a Technique to offer, and a Chef's Notebook can open.
func _check_merchant_shelf() -> void:
	var stock := Merchant.draw_staff_stock(0, [] as Array[String])
	_check("Merchant Technique slot", stock.size() == Merchant.MERCHANT_STAFF_COUNT, "%d drawn" % stock.size())
	var notebook := MerchantPacks.draw_contents(MerchantPacks.Kind.TECHNIQUES, 0, 0)
	_check(
		"Chef's Notebook contents",
		notebook.size() == MerchantPacks.CARD_COUNT,
		"%d of %d Techniques" % [notebook.size(), MerchantPacks.CARD_COUNT]
	)
