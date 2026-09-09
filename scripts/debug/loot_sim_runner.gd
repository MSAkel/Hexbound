extends Node

## Headless pack-draw simulator. Reports draw rates by rarity, type, product, tag, and card id.
##
## godot --headless --path "E:/Godot/game++" res://scenes/debug/loot_sim_runner.tscn
## godot --headless --path "E:/Godot/game++" res://scenes/debug/loot_sim_runner.tscn -- --samples=50000
## godot --headless --path "E:/Godot/game++" res://scenes/debug/loot_sim_runner.tscn -- --layout=surveyor --samples=20000
## godot --headless --path "E:/Godot/game++" res://scenes/debug/loot_sim_runner.tscn -- --all-layouts

const REPORT_PATH := "user://loot_sim_report.json"
const CHARACTER_IDS: Array[String] = [
	"surveyor",
	"encircler",
	"spiralist",
	"columnist",
	"converger",
]
const DEFAULT_SAMPLES := 10000
const DEFAULT_PACK_SIZE := 3
const DEFAULT_SEED := "LOOTSIM"
const OUTLIER_LOW_RATIO := 0.5
const OUTLIER_HIGH_RATIO := 2.0

var _samples := DEFAULT_SAMPLES
var _pack_size := DEFAULT_PACK_SIZE
var _seed_text := DEFAULT_SEED
var _layout_filter: Array[String] = []
var _all_layouts := false


func _ready() -> void:
	_parse_args()
	await get_tree().process_frame
	var reports: Array[Dictionary] = []
	var layouts := CHARACTER_IDS.duplicate() if _all_layouts or _layout_filter.is_empty() else _layout_filter
	for layout_id: String in layouts:
		if layout_id not in CHARACTER_IDS:
			push_error("LootSimRunner: unknown layout %s" % layout_id)
			continue
		reports.append(_simulate_layout(layout_id))
	_write_report(reports)
	get_tree().quit(0)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--samples="):
			_samples = maxi(1, int(arg.substr("--samples=".length()).strip_edges()))
		elif arg.begins_with("--pack-size="):
			_pack_size = maxi(1, int(arg.substr("--pack-size=".length()).strip_edges()))
		elif arg.begins_with("--seed="):
			_seed_text = arg.substr("--seed=".length()).strip_edges()
		elif arg.begins_with("--layout="):
			_layout_filter.append(arg.substr("--layout=".length()).strip_edges().to_lower())
		elif arg == "--all-layouts":
			_all_layouts = true


func _simulate_layout(layout_id: String) -> Dictionary:
	GameManager.selected_character = PlayerCharacter.get_character_by_id(layout_id)
	RunRng.begin_new_run("%s:%s" % [_seed_text, layout_id])

	var legal_pool := _legal_pool()
	var pool_counts := _count_pool_buckets(legal_pool)
	var draw_counts := _empty_bucket_counts()
	var total_draws := 0

	for sample_index in _samples:
		var rng := RunRng.create_rng("loot_sim:%d" % sample_index)
		var cards := CardLoot.card_draw(_pack_size, [], true, rng)
		for card: TileCard in cards:
			total_draws += 1
			_bump_card_draw(draw_counts, card)

	var report := {
		"layout": layout_id,
		"samples": _samples,
		"pack_size": _pack_size,
		"seed": "%s:%s" % [_seed_text, layout_id],
		"legal_pool_size": legal_pool.size(),
		"total_draws": total_draws,
		"target_rarity_weights": CardLoot.RARITY_WEIGHTS,
		"pool": pool_counts,
		"draws": draw_counts,
	}
	_print_layout_report(report)
	return report


func _legal_pool() -> Array[TileCard]:
	var legal: Array[TileCard] = []
	for card: TileCard in GameManager.tile_cards_pool:
		if card.is_legal_for_layout(GameManager.selected_character):
			legal.append(card)
	return legal


func _empty_bucket_counts() -> Dictionary:
	return {
		"rarity": {},
		"type": {},
		"product": {},
		"tag": {},
		"card": {},
	}


func _count_pool_buckets(pool: Array[TileCard]) -> Dictionary:
	var counts := _empty_bucket_counts()
	for card: TileCard in pool:
		_bump_bucket(counts, "rarity", _enum_label(TileCard.TileCardRarity, card.rarity))
		_bump_bucket(counts, "type", _enum_label(TileCard.TileCardType, card.type))
		_bump_bucket(counts, "product", _enum_label(TileCard.Product, card.product))
		for tag: StringName in TileCard.queryable_kind_tags(card):
			_bump_bucket(counts, "tag", String(tag))
		_bump_bucket(counts, "card", card.id)
	return counts


func _bump_card_draw(draw_counts: Dictionary, card: TileCard) -> void:
	_bump_bucket(draw_counts, "rarity", _enum_label(TileCard.TileCardRarity, card.rarity))
	_bump_bucket(draw_counts, "type", _enum_label(TileCard.TileCardType, card.type))
	_bump_bucket(draw_counts, "product", _enum_label(TileCard.Product, card.product))
	for tag: StringName in TileCard.queryable_kind_tags(card):
		_bump_bucket(draw_counts, "tag", String(tag))
	_bump_bucket(draw_counts, "card", card.id)


func _bump_bucket(counts: Dictionary, bucket: String, key: String, amount: int = 1) -> void:
	var table: Dictionary = counts[bucket]
	table[key] = int(table.get(key, 0)) + amount


func _enum_label(enum_type: Dictionary, value: int) -> String:
	var key: Variant = enum_type.find_key(value)
	return String(key) if key != null else "UNKNOWN_%d" % value


func _print_layout_report(report: Dictionary) -> void:
	var total_draws := int(report.get("total_draws", 0))
	var pool: Dictionary = report.get("pool", {})
	var draws: Dictionary = report.get("draws", {})
	print(
		"[loot_sim] layout=%s samples=%d pack=%d pool=%d draws=%d seed=%s"
		% [
			report.get("layout", "?"),
			report.get("samples", 0),
			report.get("pack_size", 0),
			report.get("legal_pool_size", 0),
			total_draws,
			report.get("seed", ""),
		]
	)
	_print_bucket_table("rarity", pool, draws, total_draws, _rarity_target_shares(report))
	_print_bucket_table("type", pool, draws, total_draws)
	_print_bucket_table("product", pool, draws, total_draws)
	_print_bucket_table("tag", pool, draws, total_draws)
	_print_card_extremes(pool, draws, total_draws)
	_print_adjustment_hints(pool, draws, total_draws)


func _rarity_target_shares(report: Dictionary) -> Dictionary:
	var targets: Dictionary = {}
	var weights: Dictionary = report.get("target_rarity_weights", CardLoot.RARITY_WEIGHTS)
	var total_weight := 0.0
	for rarity in CardLoot.RARITY_ROLL_ORDER:
		total_weight += float(weights.get(rarity, 0.0))
	for rarity in CardLoot.RARITY_ROLL_ORDER:
		var label := _enum_label(TileCard.TileCardRarity, rarity)
		targets[label] = float(weights.get(rarity, 0.0)) / total_weight if total_weight > 0.0 else 0.0
	return targets


func _print_bucket_table(
	bucket_name: String,
	pool: Dictionary,
	draws: Dictionary,
	total_draws: int,
	target_shares: Dictionary = {}
) -> void:
	var pool_table: Dictionary = pool.get(bucket_name, {})
	var draw_table: Dictionary = draws.get(bucket_name, {})
	var keys: Array[String] = []
	for key: String in pool_table.keys():
		if key not in keys:
			keys.append(key)
	for key: String in draw_table.keys():
		if key not in keys:
			keys.append(key)
	keys.sort()

	var pool_total := 0
	for count: int in pool_table.values():
		pool_total += count
	print("[loot_sim] --- %s ---" % bucket_name)
	print("[loot_sim]   key            pool%   draw%   ratio  target%  note")
	for key: String in keys:
		var pool_count := int(pool_table.get(key, 0))
		var draw_count := int(draw_table.get(key, 0))
		var pool_pct := 100.0 * float(pool_count) / float(maxi(pool_total, 1))
		var draw_pct := 100.0 * float(draw_count) / float(maxi(total_draws, 1))
		var ratio := draw_pct / pool_pct if pool_pct > 0.0 else 0.0
		var target_pct := 100.0 * float(target_shares.get(key, -1.0))
		var target_text := "%5.1f" % target_pct if target_shares.has(key) else "   - "
		var note := _bucket_note(pool_count, draw_count, ratio)
		print(
			"[loot_sim]   %-14s %5.1f   %5.1f   %4.2f   %s   %s"
			% [key, pool_pct, draw_pct, ratio, target_text, note]
		)

	var ranked := _rank_by_draw_rate(draw_table, total_draws)
	if ranked.is_empty():
		return
	print(
		"[loot_sim]   lowest draw: %s (%.2f%%)"
		% [ranked.front()["key"], ranked.front()["draw_pct"]]
	)
	print(
		"[loot_sim]   highest draw: %s (%.2f%%)"
		% [ranked.back()["key"], ranked.back()["draw_pct"]]
	)


func _bucket_note(pool_count: int, draw_count: int, ratio: float) -> String:
	if pool_count <= 0 and draw_count > 0:
		return "drawn but not in pool"
	if pool_count > 0 and draw_count <= 0:
		return "never drawn"
	if ratio <= OUTLIER_LOW_RATIO:
		return "low vs pool"
	if ratio >= OUTLIER_HIGH_RATIO:
		return "high vs pool"
	return ""


func _rank_by_draw_rate(draw_table: Dictionary, total_draws: int) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for key: String in draw_table.keys():
		var draw_count := int(draw_table[key])
		ranked.append({
			"key": key,
			"draw_count": draw_count,
			"draw_pct": 100.0 * float(draw_count) / float(maxi(total_draws, 1)),
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["draw_count"] == b["draw_count"]:
			return String(a["key"]) < String(b["key"])
		return int(a["draw_count"]) < int(b["draw_count"])
	)
	return ranked


func _print_card_extremes(pool: Dictionary, draws: Dictionary, total_draws: int) -> void:
	var pool_cards: Dictionary = pool.get("card", {})
	var draw_cards: Dictionary = draws.get("card", {})
	var ranked := _rank_by_draw_rate(draw_cards, total_draws)
	print("[loot_sim] --- cards ---")
	if ranked.is_empty():
		print("[loot_sim]   (no draws)")
		return

	var show_count := mini(10, ranked.size())
	print("[loot_sim]   lowest draw rates:")
	for index in show_count:
		var entry: Dictionary = ranked[index]
		print(
			"[loot_sim]     %-24s %6d  %5.2f%%"
			% [entry["key"], entry["draw_count"], entry["draw_pct"]]
		)
	print("[loot_sim]   highest draw rates:")
	for index in range(ranked.size() - show_count, ranked.size()):
		var entry: Dictionary = ranked[index]
		print(
			"[loot_sim]     %-24s %6d  %5.2f%%"
			% [entry["key"], entry["draw_count"], entry["draw_pct"]]
		)

	var never_drawn: Array[String] = []
	for card_id: String in pool_cards.keys():
		if int(draw_cards.get(card_id, 0)) <= 0:
			never_drawn.append(card_id)
	never_drawn.sort()
	print("[loot_sim]   never drawn (%d): %s" % [never_drawn.size(), ", ".join(never_drawn)])


func _print_adjustment_hints(pool: Dictionary, draws: Dictionary, total_draws: int) -> void:
	print("[loot_sim] --- adjustment hints ---")
	var hints: Array[String] = []
	for bucket_name: String in ["type", "tag", "product"]:
		hints.append_array(_bucket_outlier_hints(bucket_name, pool, draws, total_draws))
	hints.append_array(_card_outlier_hints(pool, draws, total_draws))
	if hints.is_empty():
		print("[loot_sim]   no large pool-vs-draw outliers at current sample size")
		return
	for hint: String in hints:
		print("[loot_sim]   %s" % hint)


func _bucket_outlier_hints(
	bucket_name: String,
	pool: Dictionary,
	draws: Dictionary,
	total_draws: int
) -> Array[String]:
	var hints: Array[String] = []
	var pool_table: Dictionary = pool.get(bucket_name, {})
	var draw_table: Dictionary = draws.get(bucket_name, {})
	var pool_total := 0
	for count: int in pool_table.values():
		pool_total += count
	if pool_total <= 0:
		return hints

	for key: String in pool_table.keys():
		var pool_count := int(pool_table[key])
		if pool_count <= 0:
			continue
		var draw_count := int(draw_table.get(key, 0))
		var pool_pct := 100.0 * float(pool_count) / float(pool_total)
		var draw_pct := 100.0 * float(draw_count) / float(maxi(total_draws, 1))
		var ratio := draw_pct / pool_pct if pool_pct > 0.0 else 0.0
		if draw_count <= 0:
			hints.append("%s '%s' is in the legal pool but never drew in %d slots" % [bucket_name, key, total_draws])
		elif ratio <= OUTLIER_LOW_RATIO:
			hints.append(
				"%s '%s' draws low: pool %.1f%% vs draw %.1f%% (ratio %.2f)"
				% [bucket_name, key, pool_pct, draw_pct, ratio]
			)
		elif ratio >= OUTLIER_HIGH_RATIO:
			hints.append(
				"%s '%s' draws high: pool %.1f%% vs draw %.1f%% (ratio %.2f)"
				% [bucket_name, key, pool_pct, draw_pct, ratio]
			)
	return hints


func _card_outlier_hints(pool: Dictionary, draws: Dictionary, total_draws: int) -> Array[String]:
	var hints: Array[String] = []
	var pool_cards: Dictionary = pool.get("card", {})
	var draw_cards: Dictionary = draws.get("card", {})
	var pool_total := pool_cards.size()
	if pool_total <= 0:
		return hints

	var expected_each := 100.0 / float(pool_total)
	for card_id: String in pool_cards.keys():
		var draw_count := int(draw_cards.get(card_id, 0))
		var draw_pct := 100.0 * float(draw_count) / float(maxi(total_draws, 1))
		if draw_count <= 0:
			continue
		var ratio := draw_pct / expected_each if expected_each > 0.0 else 0.0
		if ratio >= 3.0:
			hints.append("card '%s' over-indexes: %.2f%% draw vs %.2f%% uniform (ratio %.2f)" % [
				card_id, draw_pct, expected_each, ratio,
			])
	return hints


func _write_report(reports: Array[Dictionary]) -> void:
	var payload := {
		"reports": reports,
	}
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("LootSimRunner: could not write %s" % REPORT_PATH)
		return
	file.store_string(JSON.stringify(payload, "\t"))
	print("[loot_sim] wrote %s" % REPORT_PATH)
	print("[loot_sim] user data dir: %s" % OS.get_user_data_dir())
