extends Control

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

@onready var pause_menu: Control = $"."
@onready var panel: Panel = $Panel
# Sibling settings instance under MainUI
@onready var settings_container: PanelContainer = $"../SettingsContainer"


func _ready() -> void:
	# Restore pause buttons when settings Back is pressed
	settings_container.closed.connect(_on_settings_closed)


func _on_continue_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	_close_pause_menu()


func _on_settings_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	panel.hide()
	settings_container.show()


func _on_settings_closed() -> void:
	settings_container.hide()
	panel.show()


func _on_main_menu_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	

func _on_exit_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	get_tree().quit()


func _close_pause_menu() -> void:
	# Dismiss settings too so it cannot linger over gameplay.
	settings_container.hide()
	panel.show()
	pause_menu.hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if pause_menu.visible:
			_close_pause_menu()
			return
		pause_menu.show()
