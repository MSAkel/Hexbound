extends CanvasLayer

## Debug overlay for a live run. Complete rounds, pass turns, inject cards, and set gold.
## Only spawned from main.gd in debug builds.

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")
const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")

@onready var _gold_spin: SpinBox = $ToolsPanel/MarginContainer/VBoxContainer/GoldRow/GoldSpinBox
@onready var _token_spin: SpinBox = $ToolsPanel/MarginContainer/VBoxContainer/TokenRow/TokenSpinBox
@onready var _complete_round_button: Button = $ToolsPanel/MarginContainer/VBoxContainer/CompleteRoundButton
@onready var _pass_turn_button: Button = $ToolsPanel/MarginContainer/VBoxContainer/PassTurnButton
@onready var _open_merchant_button: Button = $ToolsPanel/MarginContainer/VBoxContainer/OpenMerchantButton
@onready var _open_rune_selection_button: Button = $ToolsPanel/MarginContainer/VBoxContainer/OpenRuneSelectionButton
@onready var _challenge_option: OptionButton = $ToolsPanel/MarginContainer/VBoxContainer/ChallengeRow/ChallengeOption
@onready var _activate_challenge_button: Button = $ToolsPanel/MarginContainer/VBoxContainer/ChallengeRow/ActivateChallengeButton
@onready var _card_picker: Control = $CardPicker
@onready var _card_grid: GridContainer = $CardPicker/Panel/MarginContainer/VBoxContainer/ScrollContainer/CardGrid


func _ready() -> void:
	_gold_spin.value = GoldManager.amount
	_token_spin.max_value = GoldManager.MAX_MERCHANT_TOKENS
	_token_spin.value = GoldManager.merchant_tokens
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.merchant_tokens_changed.connect(_on_tokens_changed)
	EventBus.challenge_changed.connect(_sync_challenge_option)
	_card_picker.hide()
	_populate_challenge_options()
	_sync_challenge_option()
	_refresh_action_buttons()


func _process(_delta: float) -> void:
	_refresh_action_buttons()


func _refresh_action_buttons() -> void:
	var busy := GameManager.is_processing_turn or RoundFlow.is_transitioning()
	_complete_round_button.disabled = busy
	_pass_turn_button.disabled = busy
	_activate_challenge_button.disabled = busy
	_open_merchant_button.disabled = busy
	_open_rune_selection_button.disabled = busy


func _on_gold_changed(new_amount: int) -> void:
	# Keep the spin box in sync unless the player is mid-edit.
	if _gold_spin.has_focus():
		return
	_gold_spin.value = new_amount


func _on_tokens_changed(new_amount: int) -> void:
	if _token_spin.has_focus():
		return
	_token_spin.value = new_amount


func _on_complete_round_pressed() -> void:
	_dismiss_blocking_panels()
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	GameManager.debug_meet_round_goal_and_complete()


func _on_pass_turn_pressed() -> void:
	_dismiss_blocking_panels()
	AudioManager.play_sfx(UI_SOUNDS.END_TURN)
	EventBus.turn_ended.emit()


func _on_draw_random_card_pressed() -> void:
	var card := _pick_random_card()
	if card == null:
		return
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	_add_card_to_hand(card)


func _on_pick_card_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	_open_card_picker()


func _on_close_card_picker_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	_close_card_picker()


func _on_card_picker_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_card_picker()


func _on_set_gold_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	GoldManager.set_amount(int(_gold_spin.value))


func _on_set_tokens_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	GoldManager.set_merchant_tokens(int(_token_spin.value))
	_token_spin.value = GoldManager.merchant_tokens


func _on_open_merchant_pressed() -> void:
	_dismiss_blocking_panels()
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	UiManager.show_merchant_panel.emit()


func _on_open_rune_selection_pressed() -> void:
	_dismiss_blocking_panels()
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	UiManager.show_runes_choice_panel.emit()


func _on_activate_challenge_pressed() -> void:
	_dismiss_blocking_panels()
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	var challenge_type := _challenge_option.get_selected_id()
	if challenge_type == -1:
		ChallengeManager.debug_clear_challenge()
	else:
		ChallengeManager.debug_activate_challenge(challenge_type)


func _populate_challenge_options() -> void:
	_challenge_option.clear()
	_challenge_option.add_item("(none)", -1)
	for challenge_type in ChallengeManager.ALL_CHALLENGES:
		_challenge_option.add_item(
			ChallengeManager.get_challenge_name(challenge_type),
			challenge_type
		)


func _sync_challenge_option(_unused: Variant = null) -> void:
	var active_challenge := ChallengeManager.active_challenge
	if active_challenge == -1:
		_challenge_option.select(0)
		return

	for index in _challenge_option.item_count:
		if _challenge_option.get_item_id(index) == active_challenge:
			_challenge_option.select(index)
			return


## Hide a mid-turn pick overlay so the sandbox action owns the next flow step.
func _dismiss_blocking_panels() -> void:
	if UiManager.active_panel == null:
		return
	UiManager.active_panel.hide()
	UiManager.active_panel = null


func _pick_random_card() -> Card:
	var pool: Array[Card] = []
	for rune in GameManager.tile_cards_pool:
		pool.append(rune)
	for enhancement in GameManager.enhancements_pool:
		pool.append(enhancement)
	if pool.is_empty():
		return null
	return pool.pick_random() as Card


func _add_card_to_hand(card: Card) -> void:
	# Fresh copy so the hand does not share the catalog template.
	var hand_copy: Card = card.duplicate(true)
	EventBus.generated_hand_card.emit(hand_copy)


func _open_card_picker() -> void:
	_clear_card_grid()
	var cards := _all_cards_sorted()
	for card in cards:
		_add_picker_card(card)
	_card_picker.show()


func _close_card_picker() -> void:
	_card_picker.hide()
	_clear_card_grid()


func _clear_card_grid() -> void:
	for child in _card_grid.get_children():
		_card_grid.remove_child(child)
		child.queue_free()


func _all_cards_sorted() -> Array[Card]:
	var cards: Array[Card] = []
	for rune in GameManager.tile_cards_pool:
		cards.append(rune)
	for enhancement in GameManager.enhancements_pool:
		cards.append(enhancement)
	cards.sort_custom(func(a: Card, b: Card) -> bool:
		return a.name.naturalnocasecmp_to(b.name) < 0
	)
	return cards


func _add_picker_card(card: Card) -> void:
	var card_ui: CardUI = CARD_UI_SCENE.instantiate()
	_card_grid.add_child(card_ui)
	card_ui.configure_interaction(CardUI.InteractionMode.CHOICE)
	card_ui.set_card(card)
	card_ui.action_requested.connect(_on_picker_card_selected)


func _on_picker_card_selected(card_ui: CardUI) -> void:
	if card_ui.card == null:
		return
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	_add_card_to_hand(card_ui.card)
	_close_card_picker()
