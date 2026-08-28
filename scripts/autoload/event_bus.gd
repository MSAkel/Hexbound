extends Node

## Emitted when game ends
signal game_ended  
## Emitted when a turn ends
signal turn_ended  
## Emitted when a turn starts
signal turn_started  
## Emitted when the turn changes
signal turn_changed
## Emitted when the round changes
signal round_changed(new_round: int)

## Challenge signals
signal challenge_schedule_changed
signal challenge_changed
signal challenge_banner_shown(challenge_name: String, dock_immediately: bool)
signal challenge_banner_hidden
## Emitted once the reveal banner has settled into its docked position.
signal challenge_reveal_finished
signal all_challenges_completed

signal card_drag_started(card: CardUI)
signal card_drag_ended()

## Resource signals
signal gold_changed(new_amount: int)  # Emitted when gold amount changes
signal merchant_tokens_changed(new_amount: int)
## Emitted when the shared run reroll budget changes.
signal rerolls_changed(remaining: int)

signal total_round_score_changed()
## Per-segment energy, multiplier, product (energy x mult), and gold during turn resolution.
signal segment_turn_results_changed(segment_index: int, score: int, multiplier: int, total_score: int, gold: int)
signal segment_turn_results_reset()
## Product unlocked for one segment after its Score lands in the output panel.
signal segment_score_revealed(segment_index: int, total_score: int)
## Segment row counter and punch finished for one reveal beat.
signal segment_score_count_finished(segment_index: int)
## Map glow and output-row highlight for the segment currently revealing.
signal segment_reveal_started(segment_index: int)
signal segment_reveal_ended()
## All segment score rows have finished resolving for this turn.
signal segment_reveals_finished(turn_total_score: int)
## Turn-total footer counter and punch finished for the current resolve.
signal turn_total_count_finished()
## Play the top-panel round score after the segment turn total lands.
signal round_score_commit_animation_requested()
## Top-panel round score counter finished after a turn commits.
signal round_score_count_finished()
## Fired once per resolved turn with a full per-segment snapshot for the run-info history UI.
signal segment_turn_completed(turn_number: int, snapshot: Dictionary)

signal required_score_changed()

signal merchant_closed

## Emitted when a card is played
signal card_played(card_ui: CardUI)  

signal tile_card_selected(tile_card: TileCard)
## Emitted when a tile card successfully triggers its effect
signal tile_card_activated(tile_card: TileCard)
## Emitted when a tile card becomes empowered
signal tile_card_empowered(tile_card: TileCard)
## Emitted when an empowered tile card triggers and loses empower
signal tile_card_empower_consumed(tile_card: TileCard)  
## Emitted when a tile effect creates a card that should animate into the hand
signal generated_hand_card(card: Card)  

signal toggle_tooltip(visible: bool, text: String, element_rect: Rect2)
## One hover panel per glossary keyword. Source is the CardUI that requested it.
signal toggle_keyword_tooltips(visible: bool, entries: Array, element_rect: Rect2, source: Object)
## Re-evaluate the control beneath a stationary cursor after a covering UI closes.
signal tooltip_hover_refresh_requested

signal map_display_layout_changed(layout: String)
