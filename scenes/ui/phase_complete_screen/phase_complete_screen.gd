extends Panel

@onready var phase_score: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/ScoreContainer/PhaseScore
@onready var gold_earned: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/GoldContainer/GoldEarned
@onready var turns_remaning_label: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/MerchantTokens/TurnsRemaningLabel
@onready var tokens_earned: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/MerchantTokens/TokensEarned

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide()
	UiManager.show_phase_complete_panel.connect(_on_show_panel)

	# phase_score.text = str(GameManager.total_round_score)
	# gold_earned.text = str(GoldManager.earned_this_turn)
	# turns_remaning_label.text = "%d Turns Remaining" % GameManager.remaining_turns
	# tokens_earned.text = "%d Token(s)" % GameManager.remaining_turns
	

func _on_show_panel() -> void:
	UiManager.show_panel(self)
	# total_round_score is already reset when the phase completes, use the snapshot instead.
	phase_score.text = str(GameManager.completed_phase_score)
	gold_earned.text = str(GoldManager.earned_this_turn)
	turns_remaning_label.text = "%d Turns Remaining" % GameManager.remaining_turns
	tokens_earned.text = "%d Token(s)" % GameManager.remaining_turns

func _on_continue_button_pressed() -> void:
	hide()
	UiManager.show_runes_choice_panel.emit()
