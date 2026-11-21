class_name CondimentBoardEffects
extends RefCounted

## Instant board edits that used to live on Utility hand cards.


## Destroys the placed card and gives nothing back. Its deck card is not touched, so it still comes
## back with the Day reshuffle. Counts as a destroy (Zero Waste, Deglaze) and a Ward stops it.
static func throw_out(tile: Hex, _rng: RandomNumberGenerator = null) -> bool:
	var target := tile.active_tile_card
	if target == null:
		return false
	if not destroy_placed_at(tile, target):
		return false
	_show_text(tile, "Thrown out")
	return true


## Discards the placed card with its stars: it leaves the board (not a destroy) and goes to the
## discard pile as a deck card, so the deck gains it on top of the card the Day reshuffle brings back.
static func send_back(tile: Hex) -> bool:
	var target := tile.active_tile_card
	if target == null:
		return false

	DeckManager.gain_card(target, DeckManager.Source.SEND_BACK)
	tile.remove_tile_card()
	_show_text(tile, "Sent back %s" % TileCard.star_text(target.star_level) if target.star_level > 1 else "Sent back")
	return true


## Copies the placed card (at ★1) into the draw pile, shuffled in.
static func duplicate_order(tile: Hex) -> bool:
	if tile.active_tile_card == null:
		return false

	copy_placed_to_deck(tile.active_tile_card)
	_show_text(tile, "Copied!")
	return true


static func swap_spots(hex_a: Hex, hex_b: Hex) -> bool:
	if hex_a == null or hex_b == null or hex_a.map == null:
		return false
	if hex_a.active_tile_card == null or hex_b.active_tile_card == null:
		return false
	# Meals and Meal slots stay paired.
	if not hex_a.active_tile_card.can_place_on_tile(hex_b) or not hex_b.active_tile_card.can_place_on_tile(hex_a):
		_show_failure(hex_a)
		return false
	hex_a.map.swap_placed_tile_cards(hex_a, hex_b)
	_show_text(hex_a, "Swapped")
	_show_text(hex_b, "Swapped")
	return true


static func copy_placed_to_deck(source_card: TileCard) -> void:
	var deck_copy := DeckManager.make_deck_card(source_card)
	deck_copy.star_level = 1
	DeckManager.gain_card(deck_copy, DeckManager.Source.COPY)


## A duplicate played onto its own card, or Star Up. The seated instance keeps its state and gains a star.
static func star_up_placed_at(tile: Hex) -> void:
	var target := tile.active_tile_card
	if target == null:
		return
	target.star_level += 1
	tile.refresh_tile_card_visual_state()
	_show_text(tile, "%s!" % TileCard.star_text(target.star_level), Color(1.0, 0.85, 0.2, 1.0))


## The one Destroy rule: a Ward stops it, otherwise the card is counted and removed.
## Returns false when a Ward saved the card.
static func destroy_placed_at(source_tile: Hex, placed_card: TileCard) -> bool:
	if source_tile == null or source_tile.map == null or placed_card == null:
		return false
	if CondimentManager.try_prevent_destroy(placed_card):
		_show_text(source_tile, "Warded", Color(0.45, 0.88, 0.58, 1.0))
		return false
	source_tile.map.notify_card_destroyed(placed_card)
	RunLedger.record_card_destroyed(placed_card)
	source_tile.map.destroy_placed_tile_card(placed_card)
	AudioManager.play_sfx(UISounds.DESTROY)
	return true


static func _show_text(tile: Hex, text: String, color: Color = Color.WHITE) -> void:
	if tile == null or tile.map == null:
		return
	var pos := tile.map.floating_text_position_for_hex(tile.coordinates)
	tile.map.create_floating_text(pos, text, color)


static func _show_failure(tile: Hex) -> void:
	_show_text(tile, "Failed", Color(1.0, 0.45, 0.45, 1.0))
