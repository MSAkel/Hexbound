extends Node

# Preload chef scripts so typed arrays resolve during autoload parse.
const _ChefCardScript := preload("res://scripts/resources/chef_card.gd")
const _ChefContextScript := preload("res://scripts/resources/chef_context.gd")
const _ChefCatalogScript := preload("res://scripts/helpers/chef_catalog.gd")

## Run-long chef column. Owns the seated chefs and fans engine events out to their hooks.

## One slot per station on the shared board.
const SLOT_COUNT := 5

## Seated chefs by slot. Null means empty. Slot index equals the linked station index.
var slots: Array[ChefCard] = []
## Per-slot scratch space for the current Hour.
var _hour_state: Array[Dictionary] = []
## Seasoning fires so far this Hour, across every station.
var _seasoning_fires_this_hour := 0
## Live board. HexTileMap registers itself, so headless boards work without the main scene.
var _board: HexTileMap = null


func _ready() -> void:
	slots.resize(SLOT_COUNT)
	_reset_hour_state()
	ChefCatalog.ensure_loaded()


## Called by HexTileMap when it enters the tree.
func bind_board(board: HexTileMap) -> void:
	_board = board


## Called by HexTileMap when it leaves the tree. A newer board keeps its binding.
func unbind_board(board: HexTileMap) -> void:
	if _board == board:
		_board = null


func reset_for_new_run() -> void:
	for i in SLOT_COUNT:
		slots[i] = null
	_reset_hour_state()
	EventBus.chef_roster_changed.emit()


#region --- Roster ---

func get_chef(slot: int) -> ChefCard:
	if slot < 0 or slot >= SLOT_COUNT:
		return null
	return slots[slot]


func first_free_slot() -> int:
	for i in SLOT_COUNT:
		if slots[i] == null:
			return i
	return -1


func has_free_slot() -> bool:
	return first_free_slot() >= 0


func owned_ids() -> Array[String]:
	var ids: Array[String] = []
	for chef: ChefCard in slots:
		if chef != null:
			ids.append(chef.id)
	return ids


## Seats a copy of template in the first empty slot. Returns that slot, or -1 when full.
func add_chef(template: ChefCard) -> int:
	return add_chef_to_slot(template, first_free_slot())


## Seats a copy of template in slot, replacing whatever was there.
func add_chef_to_slot(template: ChefCard, slot: int) -> int:
	if template == null or slot < 0 or slot >= SLOT_COUNT:
		return -1
	# Each slot needs its own instance. Shop and catalog cards share one .tres reference.
	slots[slot] = template.duplicate(true)
	_hour_state[slot] = {}
	EventBus.chef_added.emit(slot)
	_notify_roster_changed()
	return slot


## Chefs stay put while the Hour is firing.
func can_rearrange() -> bool:
	return not GameManager.is_processing_turn


## Moves a chef into to_slot. An occupied target swaps the two.
func move_chef(from_slot: int, to_slot: int) -> bool:
	if not can_rearrange() or from_slot == to_slot:
		return false
	if get_chef(from_slot) == null or to_slot < 0 or to_slot >= SLOT_COUNT:
		return false
	var moved := slots[from_slot]
	slots[from_slot] = slots[to_slot]
	slots[to_slot] = moved
	var moved_state := _hour_state[from_slot]
	_hour_state[from_slot] = _hour_state[to_slot]
	_hour_state[to_slot] = moved_state
	EventBus.chef_moved.emit(from_slot, to_slot)
	_notify_roster_changed()
	return true


## Removes the chef and pays its sell value. Returns the gold paid, or -1 when nothing sold.
func sell_chef(slot: int) -> int:
	var chef := get_chef(slot)
	if chef == null or not can_rearrange():
		return -1
	var value := chef.get_sell_value()
	slots[slot] = null
	_hour_state[slot] = {}
	GoldManager.add(value)
	EventBus.chef_sold.emit(slot)
	_notify_roster_changed()
	return value


func _notify_roster_changed() -> void:
	EventBus.chef_roster_changed.emit()
	RunSaveManager.request_autosave()

#endregion --- Roster ---


#region --- Effect resolution ---

## Chef whose effect applies at slot, following copy chefs. depth guards copy chains.
func resolve_effect_at(slot: int, depth: int = 0) -> ChefCard:
	var chef := get_chef(slot)
	if chef == null or depth > SLOT_COUNT:
		return null
	return chef.resolve_effect(self, slot, depth)


func _context_for(slot: int, map: HexTileMap = null) -> ChefContext:
	var effect := resolve_effect_at(slot)
	if effect == null:
		return null
	var ctx := ChefContext.new()
	ctx.slot = slot
	ctx.owner = slots[slot]
	ctx.effect = effect
	ctx.map = map if map != null else _tile_map()
	ctx.hour_state = _hour_state[slot]
	return ctx


## Every slot with a live effect, top to bottom.
func _contexts(map: HexTileMap = null) -> Array[ChefContext]:
	var resolved_map := map if map != null else _tile_map()
	var contexts: Array[ChefContext] = []
	for slot in SLOT_COUNT:
		var ctx := _context_for(slot, resolved_map)
		if ctx != null:
			contexts.append(ctx)
	return contexts

#endregion --- Effect resolution ---


#region --- Engine hooks ---

## Fire order reached a new station. Returns true when its chef did something visible.
func station_started(map: HexTileMap, segment_index: int) -> bool:
	var ctx := _context_for(segment_index, map)
	if ctx == null:
		return false
	ctx.hour_state.erase("_acted")
	ctx.effect.on_station_started(ctx)
	return bool(ctx.hour_state.get("_acted", false))


func after_card_activated(tile: Hex, card: TileCard) -> void:
	if tile == null or card == null:
		return
	if card.has_ingredient_tag(TileCard.TAG_SEASONING):
		_seasoning_fires_this_hour += 1
	for ctx: ChefContext in _contexts(tile.map):
		ctx.effect.on_card_activated(ctx, tile, card)


func get_seasoning_fires_this_hour() -> int:
	return _seasoning_fires_this_hour


## Double stack cap for this seated card, including chef bonuses.
func max_double_stacks_for(card: TileCard) -> int:
	var cap := TileCard.MAX_EMPOWER_STACKS
	var map := _tile_map()
	if map == null or card == null:
		return cap
	var tile := map.get_hex_for_tile_card(card)
	if tile == null:
		return cap
	for ctx: ChefContext in _contexts(map):
		cap += ctx.effect.bonus_max_double_stacks(ctx, tile, card)
	return cap


func after_card_doubled(card: TileCard) -> void:
	var map := _tile_map()
	if map == null or card == null:
		return
	var tile := map.get_hex_for_tile_card(card)
	if tile == null:
		return
	for ctx: ChefContext in _contexts(map):
		ctx.effect.on_card_doubled(ctx, tile, card)


func extra_double_applications(source_tile: Hex, source_card: TileCard, target: TileCard) -> int:
	if source_tile == null:
		return 0
	var extra := 0
	for ctx: ChefContext in _contexts(source_tile.map):
		extra += ctx.effect.extra_double_applications(ctx, source_tile, source_card, target)
	return extra


func dish_ingredient_discount() -> int:
	var discount := 0
	for slot in SLOT_COUNT:
		var effect := resolve_effect_at(slot)
		if effect != null:
			discount += effect.dish_ingredient_discount(null)
	return discount


## A Dish just plated with fewer ingredients than its recipe. Lights the chefs responsible.
func notify_dish_discount_used(dish_tile: Hex) -> void:
	for ctx: ChefContext in _contexts(dish_tile.map if dish_tile != null else null):
		if ctx.effect.dish_ingredient_discount(ctx) > 0:
			ctx.pulse(dish_tile)


func on_day_started() -> void:
	for ctx: ChefContext in _contexts():
		ctx.effect.on_day_started(ctx)


func on_day_ended() -> void:
	for ctx: ChefContext in _contexts():
		ctx.effect.on_day_ended(ctx)


## Hour finished firing. Drops per-Hour scratch state.
func end_hour() -> void:
	_reset_hour_state()

#endregion --- Engine hooks ---


func _reset_hour_state() -> void:
	_hour_state.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		_hour_state[i] = {}
	_seasoning_fires_this_hour = 0


func capture_run_state() -> Dictionary:
	var slot_ids: Array = []
	for chef: ChefCard in slots:
		slot_ids.append(chef.id if chef != null else "")
	return {"slots": slot_ids}


func apply_run_state(state: Dictionary) -> void:
	for i in SLOT_COUNT:
		slots[i] = null
	var slot_ids: Array = state.get("slots", [])
	for i in mini(SLOT_COUNT, slot_ids.size()):
		var template := ChefCatalog.get_by_id(str(slot_ids[i]))
		if template != null:
			slots[i] = template.duplicate(true)
	_reset_hour_state()
	EventBus.chef_roster_changed.emit()


func _tile_map() -> HexTileMap:
	return _board if is_instance_valid(_board) else null
