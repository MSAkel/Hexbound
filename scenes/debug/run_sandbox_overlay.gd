extends CanvasLayer

## Debug overlay for a live run. Complete rounds, pass turns, inject cards, and set gold.
## Only spawned from main.gd in debug builds.

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")
const STATE_PATH := "user://run_sandbox_overlay.cfg"
const STATE_SECTION := "overlay"
const STATE_KEY_COLLAPSED := "collapsed"
## Original panel was 596px. Cap the tool list at ~70% of that and scroll the rest.
const MAX_BODY_HEIGHT := 350.0

@onready var _tools_panel: PanelContainer = $OverlayRoot/ToolsPanel
@onready var _tools_scroll: ScrollContainer = $OverlayRoot/ToolsPanel/MarginContainer/VBoxContainer/ToolsScroll
@onready var _tools_body: VBoxContainer = $OverlayRoot/ToolsPanel/MarginContainer/VBoxContainer/ToolsScroll/ToolsBody
@onready var _collapse_button: Button = $OverlayRoot/ToolsPanel/MarginContainer/VBoxContainer/TitleRow/CollapseButton
@onready var _gold_spin: SpinBox = $OverlayRoot/ToolsPanel/MarginContainer/VBoxContainer/ToolsScroll/ToolsBody/GoldRow/GoldSpinBox
@onready var _token_spin: SpinBox = $OverlayRoot/ToolsPanel/MarginContainer/VBoxContainer/ToolsScroll/ToolsBody/TokenRow/TokenSpinBox
@onready var _seed_label: Label = $OverlayRoot/ToolsPanel/MarginContainer/VBoxContainer/ToolsScroll/ToolsBody/SeedRow/SeedLabel
@onready var _complete_round_button: Button = $OverlayRoot/ToolsPanel/MarginContainer/VBoxContainer/ToolsScroll/ToolsBody/CompleteRoundButton
@onready var _jump_round_spin: SpinBox = $OverlayRoot/ToolsPanel/MarginContainer/VBoxContainer/ToolsScroll/ToolsBody/RoundJumpRow/JumpRoundSpinBox
@onready var _jump_round_button: Button = $OverlayRoot/ToolsPanel/MarginContainer/VBoxContainer/ToolsScroll/ToolsBody/RoundJumpRow/JumpRoundButton
@onready var _pass_turn_button: Button = $OverlayRoot/ToolsPanel/MarginContainer/VBoxContainer/ToolsScroll/ToolsBody/PassTurnButton
@onready var _open_merchant_button: Button = $OverlayRoot/ToolsPanel/MarginContainer/VBoxContainer/ToolsScroll/ToolsBody/OpenMerchantButton
@onready var _open_rune_selection_button: Button = $OverlayRoot/ToolsPanel/MarginContainer/VBoxContainer/ToolsScroll/ToolsBody/OpenRuneSelectionButton
@onready var _character_option: OptionButton = $OverlayRoot/ToolsPanel/MarginContainer/VBoxContainer/ToolsScroll/ToolsBody/CharacterRow/CharacterOption
@onready var _event_option: OptionButton = $OverlayRoot/ToolsPanel/MarginContainer/VBoxContainer/ToolsScroll/ToolsBody/EventRow/EventOption
@onready var _activate_event_button: Button = $OverlayRoot/ToolsPanel/MarginContainer/VBoxContainer/ToolsScroll/ToolsBody/EventRow/ActivateEventButton
@onready var _card_picker: Control = $CardPicker
@onready var _card_search: LineEdit = $CardPicker/Panel/MarginContainer/VBoxContainer/SearchRow/CardSearch
@onready var _card_grid: GridContainer = $CardPicker/Panel/MarginContainer/VBoxContainer/ScrollContainer/CardGrid

var _collapsed := false


func _ready() -> void:
	_gold_spin.value = GoldManager.amount
	_token_spin.max_value = GoldManager.MAX_MERCHANT_TOKENS
	_token_spin.value = GoldManager.merchant_tokens
	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.merchant_tokens_changed.connect(_on_tokens_changed)
	EventBus.round_changed.connect(_on_round_changed)
	EventBus.event_changed.connect(_sync_event_option)
	_jump_round_spin.value = GameManager.current_round
	_card_picker.hide()
	_populate_character_options()
	_populate_event_options()
	_sync_event_option()
	_refresh_action_buttons()
	_refresh_seed_label()
	_collapsed = _load_collapsed_state()
	_apply_collapsed()


func _process(_delta: float) -> void:
	if _collapsed:
		return
	_refresh_action_buttons()
	_refresh_seed_label()


func _refresh_action_buttons() -> void:
	var busy := GameManager.is_processing_turn or RoundFlow.is_transitioning()
	_complete_round_button.disabled = busy
	_jump_round_button.disabled = busy
	_pass_turn_button.disabled = busy
	_activate_event_button.disabled = busy
	_open_merchant_button.disabled = busy
	_open_rune_selection_button.disabled = busy


func _refresh_seed_label() -> void:
	_seed_label.text = "Run seed: %s" % RunRng.get_display_seed()


func _on_collapse_button_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	_collapsed = not _collapsed
	_apply_collapsed()
	_save_collapsed_state()


## Hide the tool rows and shrink the panel so it sits as a compact header.
func _apply_collapsed() -> void:
	_tools_scroll.visible = not _collapsed
	_collapse_button.text = "▸" if _collapsed else "▾"
	_collapse_button.tooltip_text = "Expand sandbox" if _collapsed else "Collapse sandbox"
	if _collapsed:
		_tools_scroll.custom_minimum_size.y = 0.0
	else:
		_refresh_action_buttons()
		_refresh_seed_label()
		_fit_scroll_height()
	_pin_to_bottom_right()
	# Min size updates after the hidden scroll leaves the layout.
	call_deferred("_pin_to_bottom_right")


## Keep the bottom-right corner on the viewport even when the panel shrinks.
func _pin_to_bottom_right() -> void:
	var min_size := _tools_panel.get_combined_minimum_size()
	var width := maxf(_tools_panel.custom_minimum_size.x, min_size.x)
	var height := min_size.y
	_tools_panel.anchor_left = 1.0
	_tools_panel.anchor_top = 1.0
	_tools_panel.anchor_right = 1.0
	_tools_panel.anchor_bottom = 1.0
	_tools_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tools_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tools_panel.offset_right = 0.0
	_tools_panel.offset_bottom = 0.0
	_tools_panel.offset_left = -width
	_tools_panel.offset_top = -height


## Keep the list from growing past MAX_BODY_HEIGHT. Extra rows scroll.
func _fit_scroll_height() -> void:
	var content_height := _tools_body.get_combined_minimum_size().y
	_tools_scroll.custom_minimum_size.y = minf(content_height, MAX_BODY_HEIGHT)


func _load_collapsed_state() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(STATE_PATH) != OK:
		return true
	return bool(cfg.get_value(STATE_SECTION, STATE_KEY_COLLAPSED, true))


func _save_collapsed_state() -> void:
	var cfg := ConfigFile.new()
	cfg.load(STATE_PATH)
	cfg.set_value(STATE_SECTION, STATE_KEY_COLLAPSED, _collapsed)
	cfg.save(STATE_PATH)


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


func _on_round_changed(new_round: int) -> void:
	# Keep the jump field in sync unless the player is mid-edit.
	if _jump_round_spin.has_focus():
		return
	_jump_round_spin.value = new_round


func _on_jump_round_pressed() -> void:
	_dismiss_blocking_panels()
	AudioManager.play_sfx(UISounds.CLICK)
	GameManager.debug_jump_to_round(int(_jump_round_spin.value))


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


func _on_activate_event_pressed() -> void:
	_dismiss_blocking_panels()
	AudioManager.play_sfx(UISounds.CLICK)
	var event_type := _event_option.get_selected_id()
	if event_type == -1:
		EventManager.debug_clear_event()
	else:
		EventManager.debug_activate_event(event_type)


func _populate_event_options() -> void:
	_event_option.clear()
	_event_option.add_item("(none)", -1)
	for event_type in EventManager.ALL_EVENTS:
		_event_option.add_item(
			"%s (%s)" % [
				EventManager.get_event_name(event_type),
				EventManager.get_allowed_rounds_label(event_type),
			],
			event_type
		)


func _sync_event_option(_unused: Variant = null) -> void:
	var active_event := EventManager.active_event
	if active_event == -1:
		_event_option.select(0)
		return

	for index in _event_option.item_count:
		if _event_option.get_item_id(index) == active_event:
			_event_option.select(index)
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
