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
## Emitted once a fresh or restored run has replaced last run's autoload state.
## HUD readouts snap to the new values instead of counting from the old ones.
signal run_state_loaded

## Event signals
signal event_schedule_changed
signal event_changed
signal event_banner_shown(event_name: String, dock_immediately: bool)
signal event_banner_hidden
## Emitted once the reveal banner has settled into its docked position.
signal event_reveal_finished
signal all_events_completed

## A hand card was dragged past its threshold and asks to be picked up.
signal card_drag_requested(card: CardUI)
## CardPlacementHandler picked a hand card up, by drag or by controller confirm.
signal card_drag_started(card: CardUI)
## Follows every card_drag_started exactly once. outcome is a CardPlacementHandler.DragOutcome.
signal card_drag_ended(card: CardUI, outcome: int)

## Resource signals
signal gold_changed(new_amount: int)  # Emitted when gold amount changes
## Gold paid out of the wallet, at the merchant or on a reroll.
signal gold_spent(amount: int)
## Emitted when the shared run reroll budget changes.
signal rerolls_changed(remaining: int)

signal total_round_score_changed()
## Hour Flavour, combined Mult, and Gold changed during turn resolution.
## segment_index is the station whose card produced the change.
signal hour_results_changed(segment_index: int, flavour: int, mult: float, gold: int)
## Hour totals were cleared at the start of turn resolution.
signal hour_results_reset()
## Natural pass finished for this segment. Retriggers into it are now blocked.
signal segment_resolved(segment_index: int)
## Every trigger fired. The Hour readout merges Flavour x Mult into its score.
signal hour_score_presentation_requested(flavour: int, mult: float, score: int)
## The Hour readout finished showing its merged score.
signal hour_score_presentation_finished()
## Send the Hour score into the Day Rating once it commits.
signal round_score_commit_animation_requested(transfer_amount: int, round_score_before: int)
## Day Rating finished counting after a turn commits.
signal round_score_count_finished()

signal required_score_changed()

signal merchant_closed

## Emitted when a card is played
signal card_played(card_ui: CardUI)
## Emitted when a hand card is sold from the sell panel.
signal card_sold(card_ui: CardUI)

signal tile_card_selected(tile_card: TileCard)
## Emitted when a tile card successfully triggers its effect
signal tile_card_activated(tile_card: TileCard)
## Emitted when a tile card gains a Garnish stack
signal tile_card_garnished(tile_card: TileCard)
## Emitted when a tile card loses all Garnish stacks at Hour end
signal tile_card_garnish_cleared(tile_card: TileCard)  
## Emitted when a tile effect creates a card that should animate into the hand
signal generated_hand_card(card: Card)  

signal toggle_tooltip(visible: bool, text: String, element_rect: Rect2)
## One hover panel per glossary keyword. Source is the CardUI that requested it.
signal toggle_keyword_tooltips(visible: bool, entries: Array, element_rect: Rect2, source: Object)
## Re-evaluate the control beneath a stationary cursor after a covering UI closes.
signal tooltip_hover_refresh_requested

## Station type, Meals served, level, or level 3 pick changed. Badges redraw from StationManager.
signal station_state_changed(segment_index: int)
## A base station became a type for the rest of the run.
signal station_type_changed(segment_index: int, type_id: String)
signal station_leveled_up(segment_index: int, level: int)
## Level 3 opened the station's second Meal slot.
signal meal_slot_unlocked(segment_index: int)
## A typed station reached level 3 and waits on a perk pick.
signal station_choice_requested(segment_index: int)

## Staff column contents or order changed.
signal staff_roster_changed
## A staff member was seated in this slot.
signal staff_added(slot: int)
## A staff member moved from one slot to another. An occupied target means the two swapped.
signal staff_moved(from_slot: int, to_slot: int)
signal staff_sold(slot: int)
## The staff member in this slot applied its effect.
signal staff_effect_triggered(slot: int)
signal staff_drag_started(slot: int)
signal staff_drag_ended

## Condiment belt contents changed.
signal condiment_belt_changed
## A belt condiment was picked up. The sell panel arms while it is held.
signal condiment_drag_started(slot_index: int)
## Follows every condiment_drag_started, whether it was used, sold or put back.
signal condiment_drag_ended
## Tile-target drink was selected or cancelled. Slot is -1 when idle.
signal condiment_targeting_changed(slot_index: int)
## Fuses on placed cards or turn-scope badges changed.
signal condiment_fuses_changed
## A belt slot started its drink animation.
signal condiment_consume_started(slot_index: int, condiment: Condiment)
## Belt drink animation finished. CondimentManager waits on this before applying.
signal condiment_consume_animation_finished
## Drink was requested but cannot be used (for example no upcoming event).
signal condiment_use_failed(condiment: Condiment)
