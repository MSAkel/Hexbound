extends Panel

@onready var phase_score: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/ScoreContainer/PhaseScore
@onready var gold_earned: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/GoldContainer/GoldEarned
@onready var turns_remaning_label: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/MerchantTokens/TurnsRemaningLabel
@onready var tokens_earned: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/MerchantTokens/TokensEarned

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()
	UiManager.show_phase_complete_panel.connect(_on_show_panel)


func _on_show_panel() -> void:
	UiManager.show_panel(self)
	# Read while phase advance / turn_started are still deferred so leftover turns and
	# gold earned this turn still reflect the completed phase.
	phase_score.text = str(GameManager.total_round_score)
	gold_earned.text = str(GoldManager.earned_this_turn)
	turns_remaning_label.text = "%d Turns Remaining" % GameManager.remaining_turns
	tokens_earned.text = "%d Token(s)" % GameManager.remaining_turns


func _on_continue_button_pressed() -> void:
	hide()
	# Advance the next phase and start the new turn only after the summary is dismissed.
	GameManager.confirm_phase_complete()
	UiManager.show_runes_choice_panel.emit()
