class_name FloatingText
extends Node2D

@onready var label: RichTextLabel = $Label
@onready var icon_rect: TextureRect = $Icon
@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D

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
## Readable on a hex, still smaller than the old score-curve sizes that overlapped.
const CARD_FONT_SIZE := 60
## Long phrases shrink a little, but never below a size you can still read.
const CARD_LONG_TEXT_START := 12
const CARD_MIN_FONT_SIZE := 40
## Treat nearby spawns as the same tile when stacking extra lines upward.
const STACK_GROUP_DISTANCE := 8.0
## Extra pixels between stacked card floats, on top of the previous line's font height.
const STACK_GAP := 6.0
## Centers card activation text over its rune, slightly above the rune's midpoint.
const CARD_FLOAT_ANCHOR_OFFSET := Vector2(0.0, -24.0)
const GLOW_SHADER := preload("res://scenes/animations/floating_text_glow.gdshader")

## Live card floats. Used to stack extra lines above the first at that tile.
static var _active_card_floats: Array[FloatingText] = []

## Position before stack offset. Later floats compare against this.
var _stack_anchor: Vector2 = Vector2.ZERO
var _text_root: Node2D


func _ready() -> void:
	# Scene Icon stays visible in the editor for layout checks. Hide it until a float assigns a texture.
	icon_rect.visible = false


func set_text(text: String, _color: Color = Color.WHITE, icon: Texture2D = null) -> void:
	if not is_node_ready():
		await ready

	label.bbcode_enabled = false
	label.text = text
	# Scene preview uses 1.2 scale. Card floats stay at 1 so size matches CARD_FONT_SIZE.
	label.scale = Vector2.ONE
	# One color for every tile-card float. Icons still distinguish Energy, Gold, and Mult.
	_apply_label_style(Color.WHITE, ScoreReadoutStyle.parse_amount(text), true)
	_apply_icon(icon)
	audio_stream_player_2d.play()


func _apply_label_style(
	color: Color,
	amount_for_size: int,
	card_float: bool,
	font_scale: float = 1.0
) -> void:
	label.add_theme_color_override("default_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 9 if card_float else 12)
	var font_size: float
	if card_float:
		font_size = _card_font_size_for_text(label.text)
	else:
		font_size = float(ScoreReadoutStyle.font_size_for_score(amount_for_size))
	_set_font_size(font_size * font_scale)


## Shorter numbers stay at CARD_FONT_SIZE. Longer phrases step down toward CARD_MIN_FONT_SIZE.
func _card_font_size_for_text(text: String) -> float:
	var extra := maxi(text.length() - CARD_LONG_TEXT_START, 0)
	return maxf(CARD_MIN_FONT_SIZE, CARD_FONT_SIZE - float(extra) * 0.4)


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
	var valid_floats: Array[FloatingText] = []
	for other in _active_card_floats:
		if not is_instance_valid(other):
			continue
		valid_floats.append(other)
		if other._stack_anchor.distance_to(_stack_anchor) > STACK_GROUP_DISTANCE:
			continue
		stack_index += 1
	_active_card_floats = valid_floats
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

	var glow := _make_glow_backdrop(row.size)
	_text_root.add_child(glow)
	_text_root.move_child(glow, 0)

	var pop_dur := CHAR_POP_DURATION / GameManager.game_speed
	var stagger := CHAR_STAGGER / GameManager.game_speed
	var pop_tween := create_tween()
	pop_tween.set_pause_mode(Tween.TWEEN_PAUSE_BOUND)
	pop_tween.set_parallel(true)
	pop_tween.tween_property(glow, "modulate:a", 1.0, pop_dur).set_ease(Tween.EASE_OUT)
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


## Soft ink capsule behind the glyphs. Covers the card art without a hard rectangle.
func _make_glow_backdrop(row_size: Vector2) -> ColorRect:
	var glow := ColorRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := Vector2(maxf(18.0, row_size.y * 0.4), row_size.y * 0.32)
	glow.size = row_size + pad * 2.0
	glow.position = -glow.size * 0.5
	glow.pivot_offset = glow.size * 0.5
	glow.z_index = -1
	glow.modulate.a = 0.0

	var mat := ShaderMaterial.new()
	mat.shader = GLOW_SHADER
	mat.set_shader_parameter("aspect", glow.size.x / maxf(glow.size.y, 1.0))
	glow.material = mat
	return glow


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


func _set_font_size(value: float) -> void:
	label.add_theme_font_size_override("normal_font_size", int(round(value)))
