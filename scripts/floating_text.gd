class_name FloatingText
extends Node2D

@onready var label: RichTextLabel = $Label
@onready var icon_rect: TextureRect = $Icon
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

## How far a segment readout travels upward, in pixels.
const RISE_DISTANCE := 60.0
## Seconds for that rise. Does not fade, so a later merge can still read the digits.
const SEGMENT_RISE_DURATION := 0.32
## Seconds for a readout that lands as the main score, flying in and growing to size.
const GROW_MERGE_DURATION := 0.22
## Seconds for a readout that is absorbed into the main score, flying in and shrinking away.
const SHRINK_MERGE_DURATION := 0.15
## Seconds the factor line holds after rising, before it becomes the product.
const FACTOR_HOLD_DURATION := 0.55
## Extra hold during the first tutorial product beat.
const TUTORIAL_EQUALS_HOLD := 0.55
## Seconds to grow the factor line into a larger Score number.
const EQUALS_MORPH_DURATION := 0.34
## Seconds the product stays readable before it merges into the turn total.
const PRODUCT_HOLD_DURATION := 0.6
## Factor line is smaller than the product, even when Mult is 1.
const FACTOR_FONT_SCALE := 0.72
## Peak scale overshoot when the product lands.
const PRODUCT_PUNCH_SCALE := 1.24
## Scale each glyph starts at before popping in. Near-zero so they appear from nothing.
const POP_START_SCALE := 0.05
## Seconds for one glyph to scale from POP_START_SCALE to full size.
const CHAR_POP_DURATION := 0.12
## Seconds between each glyph's pop, so letters appear in sequence rather than all at once.
const CHAR_STAGGER := 0.018
## Pause after the last glyph pops in, before the whole line shrinks away.
const HOLD_AFTER_POP := 0.85
## Seconds for the finished line to scale down to zero and then free itself.
const SHRINK_DURATION := 0.14
## Card floats are a bit smaller than the shared score-readout curve.
const CARD_FONT_SCALE := 0.9
## Treat nearby spawns as the same tile when stacking extra lines upward.
const STACK_GROUP_DISTANCE := 8.0
## Extra pixels between stacked card floats, on top of the previous line's font height.
const STACK_GAP := 10.0
## Centers card activation text over its rune, slightly above the rune's midpoint.
const CARD_FLOAT_ANCHOR_OFFSET := Vector2(0.0, -24.0)

## Live card floats. Used to stack extra lines above the first at that tile.
static var _active_card_floats: Array[FloatingText] = []

## Position before stack offset. Later floats compare against this.
var _stack_anchor: Vector2 = Vector2.ZERO
var _text_root: Node2D


func _ready() -> void:
	# Scene Icon stays visible in the editor for layout checks. Hide it until a float assigns a texture.
	icon_rect.visible = false


func set_text(text: String, color: Color = Color.WHITE, icon: Texture2D = null) -> void:
	if not is_node_ready():
		await ready

	label.bbcode_enabled = false
	label.text = text
	_apply_label_style(color, ScoreReadoutStyle.parse_amount(text), true)
	_apply_icon(icon)
	audio_stream_player_2d.play()


## One readout of "energy x multiplier" with aqua energy and plum multiplier.
func set_segment_product(score: int, multiplier: int) -> void:
	if not is_node_ready():
		await ready

	var score_html := Color.AQUA.to_html(false)
	var mult_html := Color.PLUM.to_html(false)
	label.bbcode_enabled = true
	label.text = "[color=#%s]%s[/color] x [color=#%s]%s[/color]" % [
		score_html,
		CountingNumber.format_int(score),
		mult_html,
		CountingNumber.format_int(multiplier),
	]
	_apply_label_style(Color.WHITE, score * multiplier, false, FACTOR_FONT_SCALE)
	_apply_icon(null)
	audio_stream_player_2d.play()


func _apply_label_style(
	color: Color,
	amount_for_size: int,
	card_float: bool,
	font_scale: float = 1.0
) -> void:
	label.add_theme_color_override("default_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 10 if card_float else 12)
	var font_size := float(ScoreReadoutStyle.font_size_for_score(amount_for_size))
	if card_float:
		font_size *= CARD_FONT_SCALE
	_set_font_size(font_size * font_scale)


## Pops each character in from a tiny scale, holds, then shrinks the whole line away.
func play_float_and_free() -> void:
	_apply_card_stack_offset()
	if not await _play_character_pop():
		queue_free()
		return

	await GameManager.create_pauseable_timer(HOLD_AFTER_POP / GameManager.game_speed).timeout
	if not is_instance_valid(self):
		return

	var shrink_tween := create_tween()
	shrink_tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	shrink_tween.set_trans(Tween.TRANS_CUBIC)
	shrink_tween.set_ease(Tween.EASE_IN)
	shrink_tween.tween_property(_text_root, "scale", Vector2.ZERO, SHRINK_DURATION / GameManager.game_speed)
	await shrink_tween.finished
	if is_instance_valid(self):
		queue_free()


## Later floats at the same tile sit above earlier ones instead of overlapping.
func _apply_card_stack_offset() -> void:
	position += CARD_FLOAT_ANCHOR_OFFSET
	_stack_anchor = position
	var stack_index := 0
	for other in _active_card_floats:
		if not is_instance_valid(other):
			continue
		if other._stack_anchor.distance_to(_stack_anchor) > STACK_GROUP_DISTANCE:
			continue
		stack_index += 1
	position.y -= float(stack_index) * (
		float(label.get_theme_font_size("normal_font_size")) * label.scale.y + STACK_GAP
	)
	_active_card_floats.append(self)


func _exit_tree() -> void:
	_active_card_floats.erase(self)


## Builds a per-character row and pops each glyph in. Returns false if there is nothing to show.
func _play_character_pop() -> bool:
	if label.text.is_empty():
		return false

	label.visible = false

	_text_root = Node2D.new()
	# Stay hidden until pivots and start scales are applied. Avoid a one-frame full-size flash.
	_text_root.visible = false
	add_child(_text_root)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_root.add_child(row)

	var pop_items: Array[Control] = []
	var color := label.get_theme_color("default_color")
	for character in label.text:
		var char_label := _make_character_label(character, color)
		row.add_child(char_label)
		pop_items.append(char_label)

	# Scene Icon is previewed next to the label in the editor. Reparent it into the pop row at runtime.
	if icon_rect.visible and icon_rect.texture != null:
		icon_rect.reparent(row)
		pop_items.append(icon_rect)

	await get_tree().process_frame
	if not is_instance_valid(self):
		return false

	# This row is not inside another Container, so explicitly size it before using its
	# dimensions as the center offset. Otherwise its origin can remain at the rune center.
	row.size = row.get_combined_minimum_size()
	row.position = -row.size * 0.5
	_text_root.scale = label.scale

	var pop_dur := CHAR_POP_DURATION / GameManager.game_speed
	var stagger := CHAR_STAGGER / GameManager.game_speed
	var pop_tween := create_tween()
	pop_tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	pop_tween.set_parallel(true)
	for i in pop_items.size():
		var pop_item := pop_items[i]
		pop_item.pivot_offset = pop_item.size * 0.5
		pop_item.scale = Vector2(POP_START_SCALE, POP_START_SCALE)
		pop_tween.tween_property(pop_item, "scale", Vector2.ONE, pop_dur).set_delay(i * stagger).set_trans(
			Tween.TRANS_BACK
		).set_ease(Tween.EASE_OUT)

	_text_root.visible = true
	await pop_tween.finished
	return is_instance_valid(self)


func _make_character_label(character: String, color: Color) -> Label:
	var char_label := Label.new()
	char_label.text = character
	char_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := label.get_theme_font("normal_font")
	if font:
		char_label.add_theme_font_override("font", font)
	char_label.add_theme_font_size_override("font_size", label.get_theme_font_size("normal_font_size"))
	char_label.add_theme_color_override("font_color", color)
	char_label.add_theme_color_override("font_outline_color", label.get_theme_color("font_outline_color"))
	char_label.add_theme_constant_override("outline_size", label.get_theme_constant("outline_size"))
	return char_label


func _apply_icon(texture: Texture2D) -> void:
	icon_rect.texture = texture
	icon_rect.visible = texture != null
	if texture == null:
		return

	var icon_size := float(label.get_theme_font_size("normal_font_size"))
	icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
	icon_rect.size = Vector2(icon_size, icon_size)


## Rises without fading so a follow-up merge can keep the digits visible.
func play_rise() -> void:
	label.modulate = Color.WHITE
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tween.tween_property(
		label,
		"position",
		Vector2(0, -RISE_DISTANCE),
		SEGMENT_RISE_DURATION / GameManager.game_speed
	)
	await tween.finished


## Turns the factor line into a larger Score product, punches, then holds so it can be read.
func play_equals_to_product(product: int, linger_extra: bool = false) -> void:
	await GameManager.create_pauseable_timer(FACTOR_HOLD_DURATION / GameManager.game_speed).timeout
	if linger_extra:
		await GameManager.create_pauseable_timer(TUTORIAL_EQUALS_HOLD / GameManager.game_speed).timeout
	if not is_instance_valid(self):
		return

	var start_font := float(label.get_theme_font_size("normal_font_size"))
	var end_font := float(ScoreReadoutStyle.font_size_for_score(product))
	var product_html := ScoreReadoutStyle.color_for_score(product).to_html(false)
	label.bbcode_enabled = true
	label.text = "[color=#%s]%s[/color]" % [product_html, CountingNumber.format_int(product)]
	label.add_theme_color_override("default_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", 12)
	_apply_icon(TileCard.ICON_SCORE)
	_set_font_size(start_font)
	_center_label_pivot()
	label.scale = Vector2.ONE
	audio_stream_player_2d.play()

	var duration := EQUALS_MORPH_DURATION / GameManager.game_speed
	var punch := create_tween()
	punch.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	punch.set_parallel(true)
	punch.tween_method(_set_font_size, start_font, end_font, duration).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	punch.tween_property(
		label,
		"scale",
		Vector2(PRODUCT_PUNCH_SCALE, PRODUCT_PUNCH_SCALE),
		duration * 0.45
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.set_parallel(false)
	punch.tween_property(label, "scale", Vector2.ONE, duration * 0.55).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	await punch.finished
	if not is_instance_valid(self):
		return

	await GameManager.create_pauseable_timer(PRODUCT_HOLD_DURATION / GameManager.game_speed).timeout


## Flies the readout toward a world-space point. Grow lands as the main score. Shrink absorbs into it.
func merge_into(target_world: Vector2, grow: bool, target_font_size: int) -> void:
	label.modulate = Color.WHITE
	_center_label_pivot()

	var duration := (GROW_MERGE_DURATION if grow else SHRINK_MERGE_DURATION) / GameManager.game_speed
	var dest := global_position + (target_world - get_visual_global_center())
	var start_font := float(label.get_theme_font_size("normal_font_size"))

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", dest, duration).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT if grow else Tween.EASE_IN
	)
	if grow:
		tween.tween_method(_set_font_size, start_font, float(target_font_size), duration)
		tween.tween_property(label, "scale", Vector2.ONE, duration)
	else:
		tween.tween_property(self, "scale", Vector2(0.08, 0.08), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(label, "modulate:a", 0.0, duration * 0.9)
	await tween.finished


func get_visual_global_center() -> Vector2:
	return label.global_position + (label.size * label.scale) * 0.5


func _set_font_size(value: float) -> void:
	label.add_theme_font_size_override("normal_font_size", int(round(value)))
	_center_label_pivot()


func _center_label_pivot() -> void:
	label.pivot_offset = label.size * 0.5
