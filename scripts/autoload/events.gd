extends Node

# Game state signals
signal game_started(selected_boons: Array)  # Emitted when game starts with selected boons
signal game_paused  # Emitted when game is paused
signal game_resumed  # Emitted when game is resumed
signal game_ended  # Emitted when game ends
signal turn_ended  # Emitted when a turn ends
signal turn_started  # Emitted when a turn starts

signal card_drag_started(card: CardUI)
signal card_drag_ended()

# Resource signals
signal gold_changed(new_amount: int)  # Emitted when gold amount changes

signal influence_changed()


signal quest_progress_updated()

# Merchant signals
signal merchant_item_purchased(item_type: String)  # Emitted when an item is purchased
signal merchant_discount_changed(new_discount: float)  # Emitted when merchant discount changes

signal card_played(card_ui: CardUI)  # Emitted when a card is played

signal building_selected(building: Building)
signal rune_selected(rune: Rune)

signal building_pack_count_changed()
signal rune_pack_count_changed()

signal explore_count_changed()
