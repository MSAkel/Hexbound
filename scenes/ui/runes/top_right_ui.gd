extends Control

@onready var runes_button: TextureButton = $MarginContainer/RunesButton
@onready var rune_count_label: Label = $MarginContainer/RunesButton/RuneCounterPanel/RuneCountLabel
@onready var rune_icon_particles: GPUParticles2D = $MarginContainer/RunesButton/RuneIconParticles
@onready var rune_counter_panel: Panel = $MarginContainer/RunesButton/RuneCounterPanel
@onready var rune_icon: TextureRect = $MarginContainer/RunesButton/RuneIcon

func _ready() -> void:
	if not is_node_ready():
		await ready

	#rune_count_label.text = str(GameManager.available_runes_packs)

	Events.rune_pack_count_changed.connect(_update_runes_count)

func _on_runes_button_pressed() -> void:
	UiManager.show_runes_choice_panel.emit()


func _update_runes_count() -> void:
	rune_count_label.text = str(GameManager.available_runes_packs)

	if GameManager.available_runes_packs > 0:
		runes_button.disabled = false
		runes_button.modulate = Color.GOLD
		rune_icon_particles.emitting = true
		rune_icon.modulate = Color(1, 1, 1, 1)
		rune_counter_panel.show()
	else:
		runes_button.disabled = true
		runes_button.modulate = Color.WHITE
		rune_icon_particles.emitting = false
		rune_icon.modulate = Color(0.5, 0.5, 0.5, 1)
		rune_counter_panel.hide()


func _on_runes_button_mouse_entered() -> void:
	Events.toggle_tooltip.emit(true, "Rune packs", runes_button.get_global_rect())


func _on_runes_button_mouse_exited() -> void:
	Events.toggle_tooltip.emit(false, "", Rect2())
