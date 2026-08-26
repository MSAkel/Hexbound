extends Control

## Shows one unlocked passive at a time after leaving victory or game over.

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

## Live flow consumes pending unlocks. Sandbox instances turn this off.
@export var auto_present: bool = true

@onready var icon_rect: TextureRect = %IconRect
@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel
@onready var reveal_panel: Control = %Panel
@onready var continue_button: Button = %ContinueButton
@onready var aura_particles: GPUParticles2D = %AuraParticles
@onready var spark_particles: GPUParticles2D = %SparkParticles
@onready var glow_rect: TextureRect = %GlowRect
@onready var rays_rect: TextureRect = %RaysRect
@onready var card_stack: Control = %CardStack

var _fx_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	card_stack.resized.connect(_center_particles)
	_center_particles()
	if not auto_present:
		hide()
		return
	present_sequence()


func present_sequence() -> void:
	var passive := MetaProgressionManager.consume_next_pending_unlock()
	if passive == null:
		queue_free()
		return
	_show_passive(passive)


## Fills the overlay from a given passive. Does not touch the profile unlock queue.
func present_passive(passive: SegmentPassive) -> void:
	if passive == null:
		hide()
		return
	_show_passive(passive)
	show()


func _show_passive(passive: SegmentPassive) -> void:
	icon_rect.texture = passive.icon
	name_label.text = passive.display_name
	description_label.text = passive.description
	_play_reveal_animation()
	AudioManager.play_sfx(UI_SOUNDS.SELECT)


func _center_particles() -> void:
	var center := card_stack.size * 0.5
	aura_particles.position = center
	spark_particles.position = center


func _play_reveal_animation() -> void:
	if _fx_tween != null and _fx_tween.is_valid():
		_fx_tween.kill()
	aura_particles.restart()
	spark_particles.restart()
	reveal_panel.modulate = Color(1, 1, 1, 0)
	reveal_panel.scale = Vector2(0.92, 0.92)
	glow_rect.modulate.a = 0.0
	rays_rect.modulate.a = 0.0
	await get_tree().process_frame
	reveal_panel.pivot_offset = reveal_panel.size * 0.5
	_center_particles()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(reveal_panel, "scale", Vector2.ONE, 0.48)
	tween.tween_property(reveal_panel, "modulate:a", 1.0, 0.22)
	tween.tween_property(glow_rect, "modulate:a", 0.42, 0.55)
	tween.tween_property(rays_rect, "modulate:a", 0.2, 0.7)
	await tween.finished
	_start_idle_fx()
	continue_button.grab_focus()


func _process(delta: float) -> void:
	if not visible:
		return
	rays_rect.rotation += delta * 0.07


func _start_idle_fx() -> void:
	if _fx_tween != null and _fx_tween.is_valid():
		_fx_tween.kill()
	_fx_tween = create_tween().set_loops()
	_fx_tween.tween_property(glow_rect, "modulate:a", 0.26, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fx_tween.tween_property(glow_rect, "modulate:a", 0.48, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_continue_pressed() -> void:
	_advance()


func _advance() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	if not auto_present:
		hide()
		return
	present_sequence()
