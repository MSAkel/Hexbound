class_name CardSelectionUI
extends Control

@onready var choices_container: HBoxContainer = $Panel/VBoxContainer/MarginPanel/ChoicesContainer
@onready var reroll_button: Button = $Panel/VBoxContainer/RerollButton
@onready var _content_panel: Panel = $Panel
@onready var _show_board_button: Button = $Panel/ShowBoardButton
@onready var _show_options_button: Button = $ShowOptionsButton

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")
const CHOICE_CARD_SCALE := 1.45
const CHOICE_CARD_BASE_SIZE := Vector2(214, 317)
const CARD_FLOAT_HEIGHT := 4.0
const CARD_FLOAT_SWAY_WIDTH := 1.25
const CARD_FLOAT_ROTATION := 0.0045
const CARD_FLOAT_SPEED := 1.4
const CARD_FLOAT_PHASE_OFFSET := 1.85

var _float_time := 0.0
var _float_wrappers: Array[Control] = []

## List of card choices for the current turn
var cards_pack: Array[TileCard] = []
var _offer_reroll_count := 0
## Drops a stale instantiate if the panel is shown again before the last rebuild finishes.
var _pack_display_token := 0
## Pending offer snapshot applied the next time the panel opens after a continue.
var _restore_state: Dictionary = {}
## True from the moment an offer is shown until the player picks a card.
var _awaiting_pick := false


func _ready() -> void:
	add_to_group("run_card_selection")
	hide()

	_show_board_button.pressed.connect(_on_show_board_button_pressed)
	_show_options_button.pressed.connect(_on_show_options_button_pressed)
	UiManager.show_cards_choice_panel.connect(_on_show_panel)
	# Picking up a controller mid-offer should place a focus ring without a re-open.
	InputManager.input_mode_changed.connect(_on_input_mode_changed)
	EventBus.rerolls_changed.connect(_on_rerolls_changed)
	_update_reroll_button()
	set_process(false)


func _process(delta: float) -> void:
	_float_time += delta * CARD_FLOAT_SPEED
	for index in _float_wrappers.size():
		var float_wrapper := _float_wrappers[index]
		if is_instance_valid(float_wrapper):
			_apply_card_float(float_wrapper, index)


func _apply_card_float(float_wrapper: Control, index: int) -> void:
	var phase := _float_time + float(index) * CARD_FLOAT_PHASE_OFFSET
	## Slightly different frequencies keep the motion soft instead of mechanical.
	float_wrapper.position = Vector2(
		cos(phase * 0.55) * CARD_FLOAT_SWAY_WIDTH,
		sin(phase) * CARD_FLOAT_HEIGHT
	)
	float_wrapper.rotation = sin(phase * 0.7) * CARD_FLOAT_ROTATION


func _on_show_panel() -> void:
	if not RoundFlow.is_transition_card_pick() and EventManager.should_auto_grant_card(false):
		return
	_awaiting_pick = true
	_set_board_view(false)
	UiManager.show_panel(self)
	set_process(true)
	_update_reroll_button()
	if not _restore_state.is_empty():
		_offer_reroll_count = int(_restore_state.get("offer_reroll_count", 0))
		_restore_state.clear()
	else:
		_offer_reroll_count = 0
	cards_pack.clear()
	create_cards_pack()
	instantiate_card_choices()


func _on_show_board_button_pressed() -> void:
	_set_board_view(true)


func _on_show_options_button_pressed() -> void:
	_set_board_view(false)


## Hide the selection overlay so the player can inspect the board and hand.
## Does not advance card selection or round flow.
func _set_board_view(active: bool) -> void:
	_content_panel.visible = not active
	_show_options_button.visible = active
	mouse_filter = Control.MOUSE_FILTER_IGNORE if active else Control.MOUSE_FILTER_STOP
	_queue_focus()


func _on_input_mode_changed(using_gamepad: bool) -> void:
	if using_gamepad and visible:
		_queue_focus()


func _queue_focus() -> void:
	call_deferred("_focus_card_selection")


## Places the gamepad focus ring on the first offered card, or the reroll button when
## the offer is still building. Mouse and keyboard players are left alone.
func _focus_card_selection() -> void:
	if not visible or not InputManager.is_using_gamepad():
		return
	if not _content_panel.visible:
		_show_options_button.grab_focus()
		return
	var first_choice := _first_choice_card()
	if first_choice != null:
		first_choice.grab_focus()
		return
	if not reroll_button.disabled:
		reroll_button.grab_focus()


## Choice cards sit inside a per-slot float wrapper, so walk two levels down.
func _first_choice_card() -> CardUI:
	for slot in choices_container.get_children():
		for wrapper in slot.get_children():
			for node in wrapper.get_children():
				if node is CardUI:
					return node as CardUI
	return null


func _on_reroll_button_pressed() -> void:
	if not RerollManager.use_reroll():
		_update_reroll_button()
		return

	reroll_button.disabled = true
	await clear_choices()
	cards_pack.clear()
	_offer_reroll_count += 1
	create_cards_pack()
	instantiate_card_choices()
	_update_reroll_button()
	RunSaveManager.request_autosave()


func _on_rerolls_changed(_remaining: int) -> void:
	_update_reroll_button()


## Keep reroll label and disabled state in sync with the shared run budget.
func _update_reroll_button() -> void:
	var remaining := RerollManager.remaining
	if remaining <= 0:
		reroll_button.text = "0 rerolls"
	else:
		reroll_button.text = "Reroll (%d left)" % remaining
	reroll_button.disabled = not RerollManager.can_reroll()

func instantiate_card_choices() -> void:
	_pack_display_token += 1
	var display_token := _pack_display_token
	## Always clear existing choices first to ensure fresh display
	for node in choices_container.get_children():
		node.queue_free()
	
	## Wait one frame to ensure nodes are freed
	await get_tree().process_frame
	if display_token != _pack_display_token:
		return
	
	## Now create new choices from the current cards_pack
	_float_time = 0.0
	_float_wrappers.clear()
	for card in cards_pack:
		_create_choice_card(card)
	_queue_focus()


func _create_choice_card(card: TileCard) -> void:
	## Wrapper reserves scaled layout space, the card itself is visually scaled up.
	var card_slot := Control.new()
	card_slot.custom_minimum_size = CHOICE_CARD_BASE_SIZE * CHOICE_CARD_SCALE
	choices_container.add_child(card_slot)

	## Float a wrapper so CardUI remains free to run its own interaction animations.
	var float_wrapper := Control.new()
	float_wrapper.name = 'FloatWrapper'
	float_wrapper.size = card_slot.custom_minimum_size
	float_wrapper.pivot_offset = float_wrapper.size * 0.5
	float_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_slot.add_child(float_wrapper)
	_float_wrappers.append(float_wrapper)
	_apply_card_float(float_wrapper, card_slot.get_index())

	var card_ui: CardUI = CARD_UI_SCENE.instantiate()
	float_wrapper.add_child(card_ui)
	card_ui.scale = Vector2.ONE * CHOICE_CARD_SCALE
	card_ui.configure_interaction(CardUI.InteractionMode.CHOICE)
	card_ui.set_card(card)
	card_ui.action_requested.connect(_on_tile_card_choice_selected)


func _on_tile_card_choice_selected(card_ui: CardUI) -> void:
	var card := card_ui.card as TileCard
	## Selecting a card consumes the pack so a new one can be offered later.
	_awaiting_pick = false
	cards_pack.clear()
	_set_board_view(false)
	hide()
	set_process(false)
	EventBus.tile_card_selected.emit(card)
	## Report the pick here rather than on tile_card_selected, which merchant purchases also emit.
	RoundFlow.notify_card_picked()


## Pick random cards for the selection panel from the shared pool.
## Isolated RNG means rebuilding this offer always yields the same cards for this moment.
func create_cards_pack() -> void:
	if GameManager.tile_cards_pool.is_empty():
		push_error("Cannot create cards pack: card pool is empty")
		return

	# Isolated loot RNG. Combat rolls cannot advance this sequence.
	var pack_size := EventManager.get_cards_pack_size(_is_round_reward_offer())
	var stream_name: String = RunRng.build_card_offer_stream_name(
		_get_offer_round_number(),
		GameManager.remaining_turns,
		_is_round_reward_offer(),
		_offer_reroll_count
	)
	var loot_rng: RandomNumberGenerator = RunRng.create_rng(stream_name)
	cards_pack = CardLoot.card_draw(pack_size, GameManager.tile_cards_pool, true, loot_rng)


func _get_offer_round_number() -> int:
	if RoundFlow.is_transition_card_pick():
		return RoundFlow.get_transition_card_pick_round()
	return GameManager.current_round


func _is_round_reward_offer() -> bool:
	return RoundFlow.is_transition_card_pick()


func clear_choices() -> void:
	for node in choices_container.get_children():
		animate_and_free(node)

	## Ensure the node queue is flushed before continuing.
	while choices_container.get_child_count() > 0:
		await get_tree().process_frame

func animate_and_free(node: Node) -> void:
	if node.has_method("fade_out"):
		node.fade_out()
	else:
		node.modulate = Color(1, 1, 1, 1)
		var tween := create_tween()
		tween.tween_property(node, "modulate:a", 0.0, 0.3)
		tween.tween_callback(Callable(node, "queue_free"))


func capture_offer_state() -> Dictionary:
	# Persist the pick obligation, not Control visibility. Quit can hide the tree first.
	return {
		"awaiting": _awaiting_pick,
		"open": _awaiting_pick,
		"offer_reroll_count": _offer_reroll_count,
	}


func apply_offer_state(state: Dictionary) -> void:
	if state.is_empty():
		_restore_state.clear()
		return
	_restore_state = state.duplicate(true)


## Legacy saves may still carry a pending pick. Deal the pack into the hand instead.
func restore_open_if_needed() -> void:
	if _restore_state.is_empty():
		return
	var awaiting := bool(_restore_state.get("awaiting", _restore_state.get("open", false)))
	_restore_state.clear()
	_awaiting_pick = false
	if not awaiting or RoundFlow.is_transition_card_pick():
		return
	var hand := get_tree().get_first_node_in_group("run_hand") as Hand
	if hand != null:
		EventManager.deal_fail_hour_pack(hand)
