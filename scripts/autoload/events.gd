extends Node

# Game state signals
signal game_started(selected_boons: Array)  # Emitted when game starts with selected boons
signal game_paused  # Emitted when game is paused
signal game_resumed  # Emitted when game is resumed
signal game_ended  # Emitted when game ends
signal turn_ended  # Emitted when a turn ends
signal turn_started  # Emitted when a turn starts
signal turn_changed
signal phase_changed(new_phase: int)

# Challenge signals
signal challenge_schedule_changed
signal challenge_changed
signal challenge_banner_shown(challenge_name: String)
signal challenge_banner_hidden
signal merchant_closed
signal all_challenges_completed

signal card_drag_started(card: CardUI)
signal card_drag_ended()

# Resource signals
signal gold_changed(new_amount: int)  # Emitted when gold amount changes

signal total_round_score_changed()
signal turn_score_changed()
signal turn_multi_changed()
signal required_score_changed()

# Merchant signals
signal merchant_item_purchased(item_type: String)  # Emitted when an item is purchased
signal merchant_discount_changed(new_discount: float)  # Emitted when merchant discount changes

signal card_played(card_ui: CardUI)  # Emitted when a card is played

signal rune_selected(rune: Rune)
signal rune_activated(rune: Rune)  # Emitted when a rune successfully triggers its effect
signal rune_empowered(rune: Rune)  # Emitted when a rune becomes empowered
signal rune_empower_consumed(rune: Rune)  # Emitted when an empowered rune triggers and loses empower
signal enhancement_selected(enhancement: Enhancement)  # Emitted when an enhancement card is added to hand
signal enhancement_applied(rune: Rune, enhancement: Enhancement)  # Emitted when an enhancement is placed on a rune
signal card_selected(card: CardUI)

signal rune_pack_count_changed()

signal trigger_order_changed(new_order: TriggerOrderType.Type)

signal toggle_tooltip(visible: bool, text: String, element_rect: Rect2)
