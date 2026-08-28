extends CanvasLayer

## Debug overlay for a live run. Complete rounds, pass turns, inject cards, and set gold.
## Only spawned from main.gd in debug builds.

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")

@onready var _gold_spin: SpinBox = $ToolsPanel/MarginContainer/VBoxContainer/GoldRow/GoldSpinBox
@onready var _token_spin: SpinBox = $ToolsPanel/MarginContainer/VBoxContainer/TokenRow/TokenSpinBox
@onready var _seed_label: Label = $ToolsPanel/MarginContainer/VBoxContainer/SeedRow/SeedLabel
@onready var _complete_round_button: Button = $ToolsPanel/MarginContainer/VBoxContainer/CompleteRoundButton
@onready var _pass_turn_button: Button = $ToolsPanel/MarginContainer/VBoxContainer/PassTurnButton
@onready var _open_merchant_button: Button = $ToolsPanel/MarginContainer/VBoxContainer/OpenMerchantButton
@onready var _open_rune_selection_button: Button = $ToolsPanel/MarginContainer/VBoxContainer/OpenRuneSelectionButton
@onready var _character_option: OptionButton = $ToolsPanel/MarginContainer/VBoxContainer/CharacterRow/CharacterOption
@onready var _challenge_option: OptionButton = $ToolsPanel/MarginContainer/VBoxContainer/ChallengeRow/ChallengeOption
@onready var _activate_challenge_button: Button = $ToolsPanel/MarginContainer/VBoxContainer/ChallengeRow/ActivateChallengeButton
@onready var _card_picker: Control = $CardPicker
@onready var _card_search: LineEdit = $CardPicker/Panel/MarginContainer/VBoxContainer/SearchRow/CardSearch
@onready var _card_grid: GridContainer = $CardPicker/Panel/MarginContainer/VBoxContainer/ScrollContainer/CardGrid


func _ready() -> void:
	_gold_spin.value = GoldManager.amount
	_token_spin.max_value = GoldManager.MAX_MERCHANT_TOKENS
	_token_spin.value = GoldManager.merchant_tokens
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.merchant_tokens_changed.connect(_on_tokens_changed)
	EventBus.challenge_changed.connect(_sync_challenge_option)
	_card_picker.hide()
	_populate_character_options()
	_populate_challenge_options()
	_sync_challenge_option()
	_refresh_action_buttons()
	_refresh_seed_label()


func _process(_delta: float) -> void:
	_refresh_action_buttons()
	_refresh_seed_label()


func _refresh_action_buttons() -> void:
	var busy := GameManager.is_processing_turn or RoundFlow.is_transitioning()
	_complete_round_button.disabled = busy
	_pass_turn_button.disabled = busy
	_activate_challenge_button.disabled = busy
	_open_merchant_button.disabled = busy
	_open_rune_selection_button.disabled = busy


func _refresh_seed_label() -> void:
	_seed_label.text = "Run seed: %s" % RunRng.get_display_seed()


func _on_copy_seed_button_pressed() -> void:
	if not RunRng.copy_display_seed_to_clipboard():
		return
	AudioManager.play_sfx(UISounds.CLICK)


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
	AudioManager.play_sfx(UISounds.CLICK)
	GameManager.debug_meet_round_goal_and_complete()


func _on_pass_turn_pressed() -> void:
	_dismiss_blocking_panels()
	AudioManager.play_sfx(UISounds.END_TURN)
	EventBus.turn_ended.emit()


func _on_draw_random_card_pressed() -> void:
	var card := _pick_random_card()
	if card == null:
		return
	AudioManager.play_sfx(UISounds.CLICK)
	_add_card_to_hand(card)


func _on_pick_card_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	_open_card_picker()


func _on_close_card_picker_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	_close_card_picker()


func _on_card_picker_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_card_picker()


func _on_set_gold_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	GoldManager.set_amount(int(_gold_spin.value))


func _on_set_tokens_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	GoldManager.set_merchant_tokens(int(_token_spin.value))
	_token_spin.value = GoldManager.merchant_tokens


func _on_open_merchant_pressed() -> void:
	_dismiss_blocking_panels()
	AudioManager.play_sfx(UISounds.CLICK)
	UiManager.show_merchant_panel.emit()


func _on_open_rune_selection_pressed() -> void:
	_dismiss_blocking_panels()
	AudioManager.play_sfx(UISounds.CLICK)
	UiManager.show_runes_choice_panel.emit()


func _on_character_option_item_selected(index: int) -> void:
	var character_id := str(_character_option.get_item_metadata(index))
	var character := PlayerCharacter.get_character_by_id(character_id)
	if character == null:
		return
	if GameManager.selected_character != null and GameManager.selected_character.id == character.id:
		return

	AudioManager.play_sfx(UISounds.CLICK)
	_restart_run_as(character)


## Lock in the new character, drop the current save, and reload the run scene.
func _restart_run_as(character: CharacterDefinition) -> void:
	GameManager.selected_character = character
	GameManager.apply_active_segment_passives(character.id)
	RunSaveManager.delete_save()
	RunRng.restart_same_seed()
	RunSaveManager.request_scene_enter_transition()
	get_tree().change_scene_to_file(ScenePaths.MAIN)


func _populate_character_options() -> void:
	_character_option.clear()
	var current_id := ""
	if GameManager.selected_character != null:
		current_id = GameManager.selected_character.id

	for character in PlayerCharacter.get_all_characters():
		var index := _character_option.item_count
		_character_option.add_item(character.display_name)
		_character_option.set_item_metadata(index, character.id)
		if character.id == current_id:
			_character_option.select(index)


func _on_activate_challenge_pressed() -> void:
	_dismiss_blocking_panels()
	AudioManager.play_sfx(UISounds.CLICK)
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
	if is_instance_valid(UiManager.active_panel):
		UiManager.active_panel.hide()
	UiManager.release_panel()


func _pick_random_card() -> Card:
	var pool: Array[Card] = []
	for rune in GameManager.tile_cards_pool:
		pool.append(rune)
	if pool.is_empty():
		return null
	return pool.pick_random() as Card


func _add_card_to_hand(card: Card) -> void:
	# Fresh copy so the hand does not share the catalog template.
	var hand_copy: Card = card.duplicate(true)
	EventBus.generated_hand_card.emit(hand_copy)


func _open_card_picker() -> void:
	_clear_card_grid()
	_card_search.text = ""
	var cards := _all_cards_sorted()
	for card in cards:
		_add_picker_card(card)
	_apply_card_filter()
	_card_picker.show()
	_card_search.grab_focus()


func _close_card_picker() -> void:
	_card_picker.hide()
	_card_search.text = ""
	_clear_card_grid()


func _on_card_search_text_changed(_new_text: String) -> void:
	_apply_card_filter()


# Hide picker cards whose names do not contain the search text.
func _apply_card_filter() -> void:
	var query := _card_search.text.strip_edges().to_lower()
	for child in _card_grid.get_children():
		var card_ui := child as CardUI
		if card_ui == null or card_ui.card == null:
			continue
		if query.is_empty():
			card_ui.visible = true
			continue
		card_ui.visible = card_ui.card.name.to_lower().contains(query)


func _clear_card_grid() -> void:
	for child in _card_grid.get_children():
		_card_grid.remove_child(child)
		child.queue_free()


func _all_cards_sorted() -> Array[Card]:
	var cards: Array[Card] = []
	for rune in GameManager.tile_cards_pool:
		cards.append(rune)
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
	AudioManager.play_sfx(UISounds.CLICK)
	_add_card_to_hand(card_ui.card)
	_close_card_picker()
