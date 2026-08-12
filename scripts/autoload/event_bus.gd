extends Node

## Emitted when game ends
signal game_ended  
## Emitted when a turn ends
signal turn_ended  
## Emitted when a turn starts
signal turn_started  
## Emitted when the turn changes
signal turn_changed
## Emitted when the phase changes
signal phase_changed(new_phase: int)

## Challenge signals
signal challenge_schedule_changed
signal challenge_changed
signal challenge_banner_shown(challenge_name: String)
signal challenge_banner_hidden
signal all_challenges_completed

signal card_drag_started(card: CardUI)
signal card_drag_ended()

## Resource signals
signal gold_changed(new_amount: int)  # Emitted when gold amount changes

signal total_round_score_changed()
signal turn_score_changed()
## Per-segment score, multiplier, total (score x mult), and gold during turn resolution.
signal segment_turn_results_changed(segment_index: int, score: int, multiplier: int, total_score: int, gold: int)
signal segment_turn_results_reset()

signal required_score_changed()

## Emitted when an item is purchased
signal merchant_item_purchased(item_type: String)  
## Emitted when merchant discount changes
signal merchant_discount_changed(new_discount: float)
signal merchant_closed

## Emitted when a card is played
signal card_played(card_ui: CardUI)  

signal rune_selected(rune: Rune)
## Emitted when a rune successfully triggers its effect
signal rune_activated(rune: Rune)  
## Emitted when a rune becomes empowered
signal rune_empowered(rune: Rune)  
## Emitted when an empowered rune triggers and loses empower
signal rune_empower_consumed(rune: Rune)  
## Emitted when an enhancement card is added to hand
signal enhancement_selected(enhancement: Enhancement)  
## Emitted when an enhancement is placed on a rune
signal enhancement_applied(rune: Rune, enhancement: Enhancement)  
signal card_selected(card: CardUI)

signal trigger_order_changed(new_order: TriggerOrderType.Type)

signal toggle_tooltip(visible: bool, text: String, element_rect: Rect2)
