extends Node

# Game state signals
signal game_started(selected_boons: Array)  # Emitted when game starts with selected boons
signal game_paused  # Emitted when game is paused
signal game_resumed  # Emitted when game is resumed
signal game_ended  # Emitted when game ends
signal turn_ended  # Emitted when a turn ends
signal turn_started  # Emitted when a turn starts

# Resource signals
signal gold_changed(new_amount: int)  # Emitted when gold amount changes

# Merchant signals
signal merchant_item_purchased(item_type: String)  # Emitted when an item is purchased
signal merchant_discount_changed(new_discount: float)  # Emitted when merchant discount changes

signal card_played(card_ui: CardUI)  # Emitted when a card is played
