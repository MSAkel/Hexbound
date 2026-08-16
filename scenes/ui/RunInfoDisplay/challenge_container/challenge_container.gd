extends Control

@onready var challenge_panel: PanelContainer = $"."
@onready var next_challenge_round: Label = $VBoxContainer/NextChallengeRound
@onready var challenge_name: Label = $VBoxContainer/ChallengeName
@onready var challenge_description: Label = $VBoxContainer/ChallengeDescription

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

func _ready() -> void:
	EventBus.round_changed.connect(_update_challenge_preview)
	EventBus.challenge_schedule_changed.connect(_update_challenge_preview)
	EventBus.challenge_changed.connect(_update_challenge_preview)

	challenge_panel.mouse_entered.connect(_on_mouse_entered)
	challenge_panel.mouse_exited.connect(_on_mouse_exited)

	_update_challenge_preview()


func _update_challenge_preview(_new_round: int = -1) -> void:
	# Keep showing the active challenge name until its round completes.
	if ChallengeManager.active_challenge != -1:
		challenge_name.text = ChallengeManager.get_challenge_name(ChallengeManager.active_challenge)
		return

	var next_round: int = ChallengeManager.get_next_challenge_round()
	if next_round == -1:
		next_challenge_round.text = "None"
		challenge_name.text = ""
		challenge_description.text = ""
		return

	var next_challenge := ChallengeManager.get_next_challenge_type()
	next_challenge_round.text = "Round %s" % next_round
	if next_challenge == -1:
		challenge_name.text = ""
		challenge_description.text = ""
	else:
		challenge_name.text = ChallengeManager.get_challenge_name(next_challenge)
		challenge_description.text = ChallengeManager.get_challenge_description(next_challenge)


func _get_tooltip_text() -> String:
	if ChallengeManager.active_challenge != -1:
		var description := ChallengeManager.get_challenge_description(ChallengeManager.active_challenge)
		return "Round %d\n%s" % [GameManager.current_round, description]

	var next_round: int = ChallengeManager.get_next_challenge_round()
	if next_round == -1:
		return ""

	var next_challenge := ChallengeManager.get_next_challenge_type()
	if next_challenge == -1:
		return ""

	return "Round %d\n%s" % [next_round, ChallengeManager.get_challenge_description(next_challenge)]


func _get_tooltip_rect() -> Rect2:
	return challenge_panel.get_global_rect()


func _on_mouse_entered() -> void:
	var text := _get_tooltip_text()
	if text.is_empty():
		return
	EventBus.toggle_tooltip.emit(true, text, _get_tooltip_rect())


func _on_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "")
