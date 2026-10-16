extends RefCounted

## What-if Hours for the playtest bot. Snapshots the run, applies a change, resolves one Hour
## with the real resolver, reads the Hour score, then rolls everything back.
## Card effects, staff, station perks, and chef specialities all count because the game runs them.

const FRAME_EVERY_SIMULATIONS := 4

var _map: HexTileMap
## Hand cards that arrive while simulating (Duplicate Order and the like) are dropped.
var is_simulating := false
## Debug: compare a full state capture before and after every what-if Hour.
var check_purity := false
var purity_failures: Array[String] = []
var simulations_run := 0
## Time spent inside the resolver, to tell resolve cost from snapshot cost.
var resolve_msec := 0.0
var slowest_resolve_msec := 0.0
var evaluate_msec := 0.0
## Optional logger, set by the runner's --trace.
var trace: Callable


func _init(map: HexTileMap) -> void:
	_map = map


## Run-scoped autoloads an Hour can change. Order matches RunSaveManager.
## EventManager and RoundFlow are left out: an Hour never changes them, and EventManager's
## load path drops the live Blackout state. The purity check still watches them.
func _owners() -> Array:
	return [
		GameManager,
		EconomyManager,
		RunRng,
		StaffManager,
		StationManager,
		CondimentManager,
		RunLedger,
	]


func _watched_owners() -> Array:
	return _owners() + [EventManager, RoundFlow]


func snapshot() -> Dictionary:
	var managers: Array = []
	for owner: Variant in _owners():
		managers.append(owner.capture_run_state())
	return {"managers": managers, "map": _map.capture_playtest_snapshot()}


func restore(state: Dictionary) -> void:
	# The what-if Hour left per-Hour counters behind. Clear them first so the saved
	# manager state below (gold earned this Hour) wins.
	GameManager.reset_turn_counters()
	var owners := _owners()
	var managers: Array = state["managers"]
	# Stations before the map so meal-slot locks read the right levels, as on load.
	for index in owners.size():
		if owners[index] == CondimentManager or owners[index] == RunLedger:
			continue
		owners[index].apply_run_state(managers[index])
	_map.restore_playtest_snapshot(state["map"])
	for index in owners.size():
		if owners[index] == CondimentManager or owners[index] == RunLedger:
			owners[index].apply_run_state(managers[index])


## Calls change (which may place cards, seat staff, or drink condiments), resolves one Hour,
## and returns {score, gold, flavour, mult}. The run is rolled back before returning.
func evaluate(change: Callable) -> Dictionary:
	var before_fingerprint := _fingerprint() if check_purity else ""
	var started := Time.get_ticks_usec()
	var saved := snapshot()
	var gold_before := EconomyManager.amount
	is_simulating = true
	change.call()
	StationManager.evaluate_station_types()
	var result := await _resolve_hour()
	result["gold"] = EconomyManager.amount - gold_before
	restore(saved)
	is_simulating = false
	simulations_run += 1
	evaluate_msec += (Time.get_ticks_usec() - started) / 1000.0
	# Rolled-back cards and badges are queue_free'd. Headless Hours rarely wait a frame,
	# so let one pass now and then or freed UI piles up into gigabytes and slows every Hour.
	if simulations_run % FRAME_EVERY_SIMULATIONS == 0:
		await _map.get_tree().process_frame
	if check_purity:
		var after_fingerprint := _fingerprint()
		if after_fingerprint != before_fingerprint:
			purity_failures.append(_describe_difference(before_fingerprint, after_fingerprint))
	return result


func _resolve_hour() -> Dictionary:
	GameManager.playtest_simulating_hour = true
	GameManager.end_turn()
	var started := Time.get_ticks_usec()
	if trace.is_valid():
		trace.call("what-if Hour %d" % simulations_run)
	await _map.turn_resolver.resolve_turn()
	var elapsed_msec := (Time.get_ticks_usec() - started) / 1000.0
	resolve_msec += elapsed_msec
	slowest_resolve_msec = maxf(slowest_resolve_msec, elapsed_msec)
	GameManager.playtest_simulating_hour = false
	var flavour := _map.get_hour_flavour()
	var mult := _map.get_hour_additive_mult()
	return {
		"score": GameManager.compute_hour_turn_contribution(flavour, mult),
		"flavour": flavour,
		"mult": mult,
		"storm": _map.turn_resolver.aborted_retrigger_storm,
	}


func _fingerprint() -> String:
	var parts: Dictionary = {"map": _map.capture_map_state()}
	for owner: Variant in _watched_owners():
		parts[str(owner.name)] = owner.capture_run_state()
	return JSON.stringify(parts, "", true)


func _describe_difference(before: String, after: String) -> String:
	var a: Dictionary = JSON.parse_string(before)
	var b: Dictionary = JSON.parse_string(after)
	var keys: PackedStringArray = []
	for key: String in a:
		if JSON.stringify(a[key], "", true) != JSON.stringify(b.get(key), "", true):
			keys.append(key)
	return "what-if Hour leaked state in %s" % ", ".join(keys)
