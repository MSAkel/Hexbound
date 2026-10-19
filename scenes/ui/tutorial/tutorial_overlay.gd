class_name TutorialOverlay
extends CanvasLayer

## Draws TutorialManager's active hint: a dimmed screen with spotlight holes over the
## anchors, an arrow, and a callout.
##
## Click hints block the game until dismissed. Action hints (e.g. "place a card") leave input
## alone and finish when their EventBus signal fires.
## Must be the last child of MainUI: _input runs in reverse tree order, so this node sees
## clicks before the hand does.

const SPOTLIGHT_SHADER := preload("res://scenes/ui/tutorial/tutorial_spotlight.gdshader")

## Anchor name -> node path(s) under MainUI. Arrays are combined into one hole.
const ANCHOR_PATHS := {
	&"hand": "CardsHand/Hand",
	&"day_score": "RunInfoUI/DayScoreColumn/DayScoreStack",
	&"hours_left": "RunInfoUI/RunInfoColumn/HBoxContainer/RunStatus/HBoxContainer/TurnsContainer",
	&"event_icon": "RunInfoUI/RunInfoColumn/HBoxContainer/ChallengeContainer",
	&"sell_panel": "CardSellPanel",
	&"condiment_belt": "CondimentBelt/SlotsColumn",
	&"card_choices": "CardSelectionUI/Panel/VBoxContainer/MarginPanel/ChoicesContainer",
	&"card_reroll": "CardSelectionUI/Panel/VBoxContainer/RerollButton",
	&"merchant_cards": "Merchant/ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/CardsCenter/MerchandiseColumn/CardsGridContainer",
	&"merchant_condiments": "Merchant/ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/CardsCenter/MerchandiseColumn/ShelfRow/CondimentShelf",
	&"merchant_reroll": "Merchant/ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/MerchantSideFrame/MerchantSide/RerollButton",
	&"merchant_leave": "Merchant/ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/MerchantSideFrame/MerchantSide/LeaveButton",
}

const CONTEXT_PANELS := {
	TutorialHints.Context.CARD_PICK: "CardSelectionUI",
	TutorialHints.Context.MERCHANT: "Merchant",
	TutorialHints.Context.STATION_CHOICE: "StationUpgradeChoice",
}
## Card containers searched for a card the hint is about, in the order players see them.
const CARD_CONTAINER_PATHS: Array[String] = [
	"CardSelectionUI/Panel/VBoxContainer/MarginPanel/ChoicesContainer",
	"Merchant/ContainerPanel/ShopPanel/MarginContainer/MainVBox/Body/CardsCenter/MerchandiseColumn/CardsGridContainer",
	"CardsHand/Hand",
]
## HUD panels that must be closed before a board (HOUR) hint can show.
const BLOCKING_PANELS: Array[String] = [
	"CardSelectionUI",
	"Merchant",
	"RoundCompleteScreen",
	"StationUpgradeChoice",
	"GameOverScreen",
	"VictoryScreen",
	"PauseMenu",
]

## A screen must hold still this long before a hint appears, so panels finish sliding in.
const SETTLE_TIME := 0.45
## Clicks right after a hint appears are ignored, so a double-click can't skip one unread.
const INPUT_GRACE := 0.3
const HOLE_PADDING := 10.0
const HOLE_FOLLOW_SPEED := 14.0
const CLICK_DIM := 0.62
const ACTION_DIM := 0.3
const SCREEN_MARGIN := 16.0
const CALLOUT_GAP := 64.0
const CALLOUT_WIDTH := 520.0
const ARROW_SIZE := 22.0
const FADE_IN := 0.25
const FADE_OUT := 0.16

const PANEL_COLOR := Color(0.07, 0.11, 0.09, 0.97)
const BORDER_COLOR := Color("#6fdc9c")
const TITLE_COLOR := Color("#ffd166")
const PROMPT_COLOR := Color(0.78, 0.9, 0.83)

var _main_ui: Node = null
var _active_id: StringName = &""
var _is_action := false
var _shown_at := 0.0
var _anchor_names: Array[StringName] = []
## Board spot picked when the hint opened, so the hole stays put after the card lands there.
var _locked_spot := Vector2i(-1, -1)
var _last_typed_segment := -1
var _last_leveled_segment := -1
var _event_banner_animating := false

var _target_holes: Array[Rect2] = []
var _holes: Array[Rect2] = []
var _settle_signature := ""
var _settle_timer := 0.0
var _tween: Tween = null

var _root: Control
var _dim: ColorRect
var _dim_material: ShaderMaterial
var _arrow_layer: Control
var _callout: PanelContainer
var _title_label: Label
var _body_label: RichTextLabel
var _dots_label: Label
var _prompt_label: Label
var _button_row: HBoxContainer
var _skip_basics_button: Button
var _start_button: Button
var _hide_tips_button: LinkButton


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main_ui = get_parent()
	_build_ui()
	_root.hide()
	EventBus.station_type_changed.connect(func(segment: int, _type: String) -> void: _last_typed_segment = segment)
	EventBus.station_leveled_up.connect(func(segment: int, _level: int) -> void: _last_leveled_segment = segment)
	EventBus.event_banner_shown.connect(func(_name: String, _dock: bool) -> void: _event_banner_animating = true)
	InputManager.input_mode_changed.connect(_refresh_prompt.unbind(1))
	InputManager.prompts_changed.connect(_refresh_prompt)
	EventBus.event_reveal_finished.connect(func() -> void: _event_banner_animating = false)
	EventBus.event_banner_hidden.connect(func() -> void: _event_banner_animating = false)
	# Deferred so the board (a later sibling of MainUI) has finished _ready first.
	TutorialManager.register_overlay.call_deferred(self)


func _exit_tree() -> void:
	TutorialManager.unregister_overlay(self)


func _process(delta: float) -> void:
	_update_settle(delta)
	if _active_id == &"":
		return
	# The pause menu draws below this layer. Step aside while it is open.
	_root.visible = not get_tree().paused
	if get_tree().paused:
		return
	# The screen can change under any hint: action hints let play continue, and automatic flow
	# (an Hour ending, a Day completing) runs under click hints too. Set it aside until it's back.
	if not _is_context_up(int(TutorialHints.get_def(_active_id).get("context", 0))):
		close_hint()
		TutorialManager.suspend_active()
		return
	_refresh_target_holes()
	var weight := 1.0 - exp(-HOLE_FOLLOW_SPEED * delta)
	for i in _holes.size():
		var target := _target_holes[i]
		_holes[i] = Rect2(
			_holes[i].position.lerp(target.position, weight),
			_holes[i].size.lerp(target.size, weight)
		)
	_apply_holes()
	# Shrink to the text each frame. The body only knows its height once it has a width.
	_callout.reset_size()
	_position_callout()
	_arrow_layer.queue_redraw()


#region Manager hooks

## True once the hint's screen is up and has been still for SETTLE_TIME.
func is_context_ready(context: int) -> bool:
	return _settle_timer >= SETTLE_TIME and _is_context_up(context)


func show_hint(id: StringName) -> void:
	var def := TutorialHints.get_def(id)
	if def.is_empty():
		return
	var was_visible := _active_id != &"" or _root.visible
	_active_id = id
	_is_action = def.get("action_signal", &"") != &""
	_anchor_names.assign(def.get("anchors", []))
	_locked_spot = _find_empty_spot() if &"board_spot" in _anchor_names else Vector2i(-1, -1)
	_shown_at = _now()

	_title_label.text = String(def.get("title", ""))
	_title_label.visible = not _title_label.text.is_empty()
	_body_label.text = TutorialHints.to_bbcode(TutorialManager.get_body(id))
	var progress := TutorialManager.get_chain_progress(id)
	_dots_label.visible = progress.y > 1
	_dots_label.text = _dots_text(progress)
	var is_welcome: bool = id == TutorialHints.chain_steps(&"basics")[0]
	_button_row.visible = is_welcome
	_prompt_label.visible = not is_welcome
	_prompt_label.text = _prompt_text()
	_hide_tips_button.visible = not is_welcome

	_refresh_target_holes()
	if not was_visible or _holes.size() != _target_holes.size():
		# Spotlight closes in from slightly larger rects.
		_holes.clear()
		for rect: Rect2 in _target_holes:
			_holes.append(rect.grow(60.0))
	_dim_material.set_shader_parameter("dim_alpha", ACTION_DIM if _is_action else CLICK_DIM)
	_apply_holes()

	_root.show()
	_callout.reset_size()
	_position_callout()
	_play_in(was_visible)
	AudioManager.play_sfx(UISounds.SELECT)
	if is_welcome:
		_start_button.grab_focus.call_deferred()


## True while a click hint holds the screen. The in-run controller stays off meanwhile.
func is_blocking_input() -> bool:
	return _active_id != &"" and not _is_action and _root.visible


## Hide the active hint without marking it seen.
func close_hint() -> void:
	if _active_id == &"":
		return
	_active_id = &""
	_play_out()

#endregion


#region Input

func _input(event: InputEvent) -> void:
	if _active_id == &"" or get_tree().paused:
		return
	# Pause and back always reach the pause menu.
	if event.is_action_pressed("pause_game") or event.is_action_pressed("ui_cancel"):
		return
	if _is_action:
		return
	var over_callout := false
	if event is InputEventMouse:
		over_callout = _callout.get_global_rect().has_point((event as InputEventMouse).position)
	if over_callout:
		# Buttons and links handle themselves. A click elsewhere on the panel continues.
		if _is_click(event) and not _button_row.visible and not _is_over_button(event.position):
			_continue()
			get_viewport().set_input_as_handled()
		return
	if _button_row.visible and _is_pad_event(event):
		# The welcome buttons take pad input through GUI focus. Keep focus on them.
		if not _skip_basics_button.has_focus() and not _start_button.has_focus():
			_start_button.grab_focus()
			get_viewport().set_input_as_handled()
		return
	if _is_click(event) or (event.is_action_pressed("ui_accept") and not _button_row.visible):
		if not _button_row.visible:
			_continue()
		else:
			_on_start_pressed()
		get_viewport().set_input_as_handled()
		return
	# Everything else stays off the board and any open panel while a click hint is up.
	if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch 			or _is_pad_event(event):
		get_viewport().set_input_as_handled()


func _is_pad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


func _is_click(event: InputEvent) -> bool:
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT


func _is_over_button(point: Vector2) -> bool:
	return _hide_tips_button.visible and _hide_tips_button.get_global_rect().has_point(point)


func _continue() -> void:
	if _now() - _shown_at < INPUT_GRACE:
		return
	AudioManager.play_sfx(UISounds.CLICK)
	close_hint()
	TutorialManager.dismiss_active()


func _on_start_pressed() -> void:
	_continue()


func _on_skip_basics_pressed() -> void:
	if _now() - _shown_at < INPUT_GRACE:
		return
	AudioManager.play_sfx(UISounds.CLICK)
	close_hint()
	TutorialManager.dismiss_active()
	TutorialManager.skip_basics()


func _on_hide_tips_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	close_hint()
	TutorialManager.set_enabled(false)

#endregion


#region Context

func _is_context_up(context: int) -> bool:
	if context == TutorialHints.Context.HOUR:
		return _is_board_idle()
	if context == TutorialHints.Context.ANY_CARD_SCREEN:
		return (
			_is_board_idle()
			or _is_context_up(TutorialHints.Context.CARD_PICK)
			or _is_context_up(TutorialHints.Context.MERCHANT)
		)
	var panel := _main_ui.get_node_or_null(String(CONTEXT_PANELS.get(context, ""))) as Control
	return panel != null and panel.is_visible_in_tree()


func _is_board_idle() -> bool:
	var hand := _hand()
	if hand == null or hand.is_awaiting_intro() or hand.is_hand_hidden():
		return false
	# A play or sell left too few cards. The Hour ends on its own a moment later.
	if hand.has_pending_auto_end():
		return false
	if GameManager.is_processing_turn or _event_banner_animating:
		return false
	if CondimentManager.targeting_slot != -1:
		return false
	for panel_name: String in BLOCKING_PANELS:
		var panel := _main_ui.get_node_or_null(panel_name) as Control
		if panel != null and panel.visible:
			return false
	return true


## Restarts the settle timer whenever the visible screen changes.
func _update_settle(delta: float) -> void:
	var hand := _hand()
	# Hand size is included so every play or sell restarts the wait. The auto-end after a
	# hand drops below 3 cards fires well inside SETTLE_TIME.
	var signature := "%s|%s|%s|%s|%s" % [
		str(UiManager.active_panel.name) if is_instance_valid(UiManager.active_panel) else "",
		str(hand != null and hand.is_hand_hidden()),
		str(hand.get_hand_card_count() if hand != null else -1),
		str(GameManager.is_processing_turn),
		str(_event_banner_animating),
	]
	if signature != _settle_signature:
		_settle_signature = signature
		_settle_timer = 0.0
		return
	_settle_timer += delta


## A Meal card on screen right now: in the card pick, on the Merchant shelf, or in the hand.
func find_visible_meal_card() -> CardUI:
	for path: String in CARD_CONTAINER_PATHS:
		var container := _main_ui.get_node_or_null(path) as Control
		if container == null or not container.is_visible_in_tree():
			continue
		if container is Hand and ((container as Hand).is_hand_hidden() or (container as Hand).is_awaiting_intro()):
			continue
		for child in container.get_children():
			var card_ui := child as CardUI
			if card_ui == null or not card_ui.is_visible_in_tree():
				continue
			var tile_card := card_ui.card as TileCard
			if tile_card != null and tile_card.type == TileCard.TileCardType.MEAL:
				return card_ui
	return null


func _is_board_uncovered() -> bool:
	for panel_name: String in BLOCKING_PANELS:
		var panel := _main_ui.get_node_or_null(panel_name) as Control
		if panel != null and panel.visible:
			return false
	return true


func _hand() -> Hand:
	return _main_ui.get_node_or_null("CardsHand/Hand") as Hand


func _board() -> HexTileMap:
	return _main_ui.get_node_or_null("../HexTileMap") as HexTileMap

#endregion


#region Anchors

func _refresh_target_holes() -> void:
	_target_holes.clear()
	for anchor: StringName in _anchor_names:
		var rect := _resolve_anchor(anchor)
		if rect.size.x > 1.0 and rect.size.y > 1.0:
			_target_holes.append(rect.grow(HOLE_PADDING))
	while _holes.size() > _target_holes.size():
		_holes.pop_back()
	while _holes.size() < _target_holes.size():
		_holes.append(_target_holes[_holes.size()])


func _resolve_anchor(anchor: StringName) -> Rect2:
	if ANCHOR_PATHS.has(anchor):
		var paths: Variant = ANCHOR_PATHS[anchor]
		if paths is String:
			paths = [paths]
		var union := Rect2()
		for path: String in paths:
			var control := _main_ui.get_node_or_null(path) as Control
			if control == null or not control.is_visible_in_tree():
				continue
			var rect := _control_rect(control)
			union = rect if union.size == Vector2.ZERO else union.merge(rect)
		return union
	if anchor == &"meal_card":
		var meal := find_visible_meal_card()
		return meal.get_global_rect() if meal != null else Rect2()
	var board := _board()
	# Panels cover the board. A hole there would cut through the panel.
	if board == null or not _is_board_uncovered():
		return Rect2()
	match anchor:
		&"board_spot":
			return board.get_tile_screen_rect(_locked_spot) if _locked_spot.x >= 0 else Rect2()
		&"board_station":
			return _segment_rect(board, _first_occupied_segment(board))
		&"meal_slot":
			return _meal_slot_rect(board)
		&"staff_slot":
			return _staff_slot_rect(board)
		&"typed_station":
			return _segment_rect(board, _pick_segment(board, _last_typed_segment, _is_typed))
		&"leveled_station":
			return _segment_rect(board, _pick_segment(board, _last_leveled_segment, _is_leveled))
	push_warning("TutorialOverlay: unknown anchor %s" % anchor)
	return Rect2()


## Hand cards sit outside the HBox's own rect, so measure the cards themselves.
func _control_rect(control: Control) -> Rect2:
	if control is Hand:
		var union := Rect2()
		for child in control.get_children():
			if child is CardUI and (child as CardUI).visible:
				var rect := (child as CardUI).get_global_rect()
				union = rect if union.size == Vector2.ZERO else union.merge(rect)
		if union.size != Vector2.ZERO:
			return union
	return control.get_global_rect()


func _find_empty_spot() -> Vector2i:
	var board := _board()
	if board == null:
		return Vector2i(-1, -1)
	for hex: Hex in board.get_hexes_in_trigger_order():
		var coords := hex.coordinates
		if hex.active_tile_card == null and board.is_tile_interactable(coords) and not board.is_meal_slot(coords):
			return coords
	return Vector2i(-1, -1)


func _segment_rect(board: HexTileMap, segment: int) -> Rect2:
	var union := Rect2()
	for hex: Hex in board.get_hexes_in_segment(segment):
		var rect := board.get_tile_screen_rect(hex.coordinates)
		union = rect if union.size == Vector2.ZERO else union.merge(rect)
	return union


func _first_occupied_segment(board: HexTileMap) -> int:
	for segment in board.get_segment_count():
		for hex: Hex in board.get_hexes_in_segment(segment):
			if hex.active_tile_card != null:
				return segment
	return 0


## The Station that triggered the hint if it still qualifies, else the first one that does.
## A hint can wait a whole Day for its screen, and a Station can lose its type meanwhile.
func _pick_segment(board: HexTileMap, preferred: int, qualifies: Callable) -> int:
	if preferred >= 0 and qualifies.call(preferred):
		return preferred
	for segment in board.get_segment_count():
		if qualifies.call(segment):
			return segment
	return 0


func _is_typed(segment: int) -> bool:
	return StationManager.get_station_type(segment) != null


func _is_leveled(segment: int) -> bool:
	return StationManager.get_level(segment) > StationManager.START_LEVEL


func _meal_slot_rect(board: HexTileMap) -> Rect2:
	for segment in board.get_segment_count():
		for coords: Vector2i in board.get_meal_slot_coords(segment):
			if not StationManager.is_meal_slot_locked(coords):
				return board.get_tile_screen_rect(coords)
	return Rect2()


func _staff_slot_rect(board: HexTileMap) -> Rect2:
	for slot in StaffManager.slots.size():
		if StaffManager.slots[slot] != null:
			return board.get_staff_slot_screen_rect(slot)
	return Rect2()

#endregion


#region Layout and drawing

func _apply_holes() -> void:
	var packed: Array[Vector4] = []
	for rect: Rect2 in _holes:
		packed.append(Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	while packed.size() < 4:
		packed.append(Vector4.ZERO)
	_dim_material.set_shader_parameter("holes", packed)
	_dim_material.set_shader_parameter("hole_count", mini(_holes.size(), 4))
	_dim_material.set_shader_parameter("rect_size", _dim.size)


func _target_union() -> Rect2:
	var union := Rect2()
	for rect: Rect2 in _target_holes:
		union = rect if union.size == Vector2.ZERO else union.merge(rect)
	return union


## Beside the spotlight where it fits (above, below, right, left), else centred.
func _position_callout() -> void:
	var view := _root.size
	var size := _callout.size
	var target := _target_union()
	var pos := Vector2((view.x - size.x) * 0.5, view.y * 0.32 - size.y * 0.5)
	if target.size != Vector2.ZERO:
		var center := target.get_center()
		var candidates: Array[Vector2] = [
			Vector2(center.x - size.x * 0.5, target.position.y - CALLOUT_GAP - size.y),
			Vector2(center.x - size.x * 0.5, target.end.y + CALLOUT_GAP),
			Vector2(target.end.x + CALLOUT_GAP, center.y - size.y * 0.5),
			Vector2(target.position.x - CALLOUT_GAP - size.x, center.y - size.y * 0.5),
		]
		var placed := false
		for candidate: Vector2 in candidates:
			var clamped := _clamp_to_view(candidate, size, view)
			if not Rect2(clamped, size).intersects(target):
				pos = clamped
				placed = true
				break
		if not placed:
			pos = _clamp_to_view(pos, size, view)
	_callout.position = pos


func _clamp_to_view(pos: Vector2, size: Vector2, view: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, view.x - size.x - SCREEN_MARGIN)),
		clampf(pos.y, SCREEN_MARGIN, maxf(SCREEN_MARGIN, view.y - size.y - SCREEN_MARGIN))
	)


## Bobbing arrow from the callout edge toward each spotlight.
func _draw_arrow() -> void:
	if _active_id == &"" or _target_holes.is_empty():
		return
	var callout_rect := _callout.get_rect()
	for target: Rect2 in _target_holes:
		_draw_arrow_to(callout_rect, target)


func _draw_arrow_to(callout_rect: Rect2, target: Rect2) -> void:
	var from := _closest_point_on_rect(callout_rect, target.get_center())
	var to := _closest_point_on_rect(target, from)
	var direction := to - from
	if direction.length() < ARROW_SIZE * 1.8:
		return
	direction = direction.normalized()
	var bob := sin(_now() * 6.0) * 5.0
	var tip := to - direction * (8.0 - bob)
	var base := tip - direction * ARROW_SIZE
	var normal := Vector2(-direction.y, direction.x)
	var alpha := _callout.modulate.a
	var points := PackedVector2Array([
		tip,
		base + normal * ARROW_SIZE * 0.9,
		base + normal * ARROW_SIZE * 0.35,
		base - direction * ARROW_SIZE * 0.8 + normal * ARROW_SIZE * 0.35,
		base - direction * ARROW_SIZE * 0.8 - normal * ARROW_SIZE * 0.35,
		base - normal * ARROW_SIZE * 0.35,
		base - normal * ARROW_SIZE * 0.9,
	])
	var outline := points.duplicate()
	outline.append(points[0])
	_arrow_layer.draw_colored_polygon(points, Color(TITLE_COLOR, alpha))
	_arrow_layer.draw_polyline(outline, Color(0.1, 0.07, 0.02, alpha), 3.0, true)


func _closest_point_on_rect(rect: Rect2, point: Vector2) -> Vector2:
	return Vector2(
		clampf(point.x, rect.position.x, rect.end.x),
		clampf(point.y, rect.position.y, rect.end.y)
	)


func _dots_text(progress: Vector2i) -> String:
	var dots := ""
	for i in progress.y:
		dots += "●" if i < progress.x else "○"
	return dots


func _prompt_text() -> String:
	if _is_action:
		return "Do it to continue"
	if InputManager.is_using_gamepad():
		return "Press %s to continue" % InputManager.get_button_name(&"ui_accept")
	return "Click to continue"


func _refresh_prompt() -> void:
	if _active_id != &"" and _prompt_label.visible:
		_prompt_label.text = _prompt_text()


func _play_in(was_visible: bool) -> void:
	_kill_tween()
	_callout.pivot_offset = _callout.size * 0.5
	_tween = create_tween().set_parallel(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if not was_visible:
		_dim.modulate.a = 0.0
		_tween.tween_property(_dim, "modulate:a", 1.0, FADE_IN)
	_callout.modulate.a = 0.0
	_callout.scale = Vector2(0.92, 0.92)
	_tween.tween_property(_callout, "modulate:a", 1.0, FADE_IN)
	_tween.tween_property(_callout, "scale", Vector2.ONE, FADE_IN)


func _play_out() -> void:
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(_dim, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_property(_callout, "modulate:a", 0.0, FADE_OUT)
	_tween.chain().tween_callback(_on_out_finished)


func _on_out_finished() -> void:
	# A chain's next step may already be showing.
	if _active_id == &"":
		_root.hide()
		_holes.clear()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

#endregion


#region Build

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_material = ShaderMaterial.new()
	_dim_material.shader = SPOTLIGHT_SHADER
	_dim_material.set_shader_parameter("outline_color", TITLE_COLOR)
	_dim.material = _dim_material
	_root.add_child(_dim)

	_arrow_layer = Control.new()
	_arrow_layer.name = "ArrowLayer"
	_arrow_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrow_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow_layer.draw.connect(_draw_arrow)
	_root.add_child(_arrow_layer)

	_callout = PanelContainer.new()
	_callout.name = "Callout"
	_callout.custom_minimum_size = Vector2(CALLOUT_WIDTH, 0)
	_callout.mouse_filter = Control.MOUSE_FILTER_STOP
	_callout.add_theme_stylebox_override("panel", _make_panel_style())
	_root.add_child(_callout)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_callout.add_child(column)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)

	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	header.add_child(_title_label)

	_dots_label = Label.new()
	_dots_label.add_theme_font_size_override("font_size", 16)
	_dots_label.add_theme_color_override("font_color", BORDER_COLOR)
	_dots_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_dots_label)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content = true
	_body_label.scroll_active = false
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_label.add_theme_font_size_override("normal_font_size", 23)
	_body_label.add_theme_constant_override("line_separation", 4)
	column.add_child(_body_label)

	var footer := HBoxContainer.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(footer)

	_hide_tips_button = LinkButton.new()
	_hide_tips_button.text = "Turn off tips"
	_hide_tips_button.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	_hide_tips_button.add_theme_font_size_override("font_size", 15)
	_hide_tips_button.add_theme_color_override("font_color", Color(PROMPT_COLOR, 0.55))
	_hide_tips_button.add_theme_color_override("font_hover_color", PROMPT_COLOR)
	_hide_tips_button.size_flags_vertical = Control.SIZE_SHRINK_END
	_hide_tips_button.focus_mode = Control.FOCUS_NONE
	_hide_tips_button.pressed.connect(_on_hide_tips_pressed)
	footer.add_child(_hide_tips_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(spacer)

	_prompt_label = Label.new()
	_prompt_label.add_theme_font_size_override("font_size", 17)
	_prompt_label.add_theme_color_override("font_color", PROMPT_COLOR)
	footer.add_child(_prompt_label)

	_button_row = HBoxContainer.new()
	_button_row.alignment = BoxContainer.ALIGNMENT_END
	_button_row.add_theme_constant_override("separation", 12)
	footer.add_child(_button_row)

	_skip_basics_button = Button.new()
	_skip_basics_button.text = "Skip tutorial"
	_skip_basics_button.custom_minimum_size = Vector2(150, 44)
	_skip_basics_button.pressed.connect(_on_skip_basics_pressed)
	_button_row.add_child(_skip_basics_button)

	_start_button = Button.new()
	_start_button.text = "Let's cook!"
	_start_button.custom_minimum_size = Vector2(150, 44)
	_start_button.pressed.connect(_on_start_pressed)
	_button_row.add_child(_start_button)
	MenuFocus.trap_row([_skip_basics_button, _start_button])

	# Prompt text gently pulses so it reads as an instruction, not body copy.
	var pulse := create_tween().set_loops()
	pulse.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pulse.tween_property(_prompt_label, "modulate:a", 0.55, 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_prompt_label, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)


func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(22)
	style.content_margin_top = 18
	style.content_margin_bottom = 16
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)
	return style

#endregion
