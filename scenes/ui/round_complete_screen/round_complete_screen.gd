extends Panel

@onready var round_score: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/ScoreContainer/RoundScore
@onready var gold_earned: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/GoldContainer/GoldEarned
@onready var remaining_turns_rewards_container: VBoxContainer = $PanelContainer/ContentMarginContainer/ContentBoxContainer/RemainingTurnsRewardsContainer
@onready var base_gold_label: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/RemainingTurnsRewardsContainer/BaseGoldRow/BaseGoldValue
@onready var early_gold_row: HBoxContainer = $PanelContainer/ContentMarginContainer/ContentBoxContainer/RemainingTurnsRewardsContainer/EarlyGoldRow
@onready var early_gold_title: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/RemainingTurnsRewardsContainer/EarlyGoldRow/EarlyGoldTitle
@onready var early_gold_label: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/RemainingTurnsRewardsContainer/EarlyGoldRow/EarlyGoldValue
@onready var tokens_row: HBoxContainer = $PanelContainer/ContentMarginContainer/ContentBoxContainer/RemainingTurnsRewardsContainer/MerchantTokensRow
@onready var tokens_title: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/RemainingTurnsRewardsContainer/MerchantTokensRow/MerchantTokensTitle
@onready var tokens_earned_label: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/RemainingTurnsRewardsContainer/MerchantTokensRow/MerchantTokensValue
@onready var tokens_lost_label: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/RemainingTurnsRewardsContainer/TokensLostLabel


func _ready() -> void:
	hide()
	UiManager.show_round_complete_panel.connect(_on_show_panel)


func _on_show_panel() -> void:
	UiManager.show_panel(self)
	# Read while round advance and turn_started are still deferred so gold earned this turn
	# still reflects the completed round.
	round_score.text = str(GameManager.total_round_score)
	gold_earned.text = str(GoldManager.earned_this_turn)

	var reward: Dictionary = GoldManager.last_speed_reward
	var skipped_turns: int = reward.get("skipped_turns", 0)
	var turns_remaining: int = reward.get("turns_remaining", 0)

	remaining_turns_rewards_container.visible = true
	base_gold_label.text = "+%d" % reward.get("base_gold", 0)

	var has_early_bonus := skipped_turns > 0
	early_gold_row.visible = has_early_bonus
	tokens_row.visible = has_early_bonus

	if has_early_bonus:
		var turns_phrase := _turns_remaining_phrase(turns_remaining)
		early_gold_title.text = "%s" % turns_phrase
		tokens_title.text = "Merchant tokens (%s)" % turns_phrase
		early_gold_label.text = "+%d" % reward.get("early_gold", 0)

		var tokens_earned: int = reward.get("tokens_earned", 0)
		var tokens_lost: int = reward.get("tokens_lost", 0)
		tokens_earned_label.text = "+%d" % tokens_earned
		tokens_lost_label.visible = tokens_lost > 0
		if tokens_lost > 0:
			tokens_lost_label.text = "%d token(s) lost. Wallet is full." % tokens_lost
	else:
		tokens_lost_label.visible = false


func _turns_remaining_phrase(turns_remaining: int) -> String:
	if turns_remaining == 1:
		return "1 turn remaining"
	return "%d turns remaining" % turns_remaining


func _on_continue_button_pressed() -> void:
	hide()
	# RoundFlow owns what comes next, this screen only reports that it was dismissed.
	RoundFlow.notify_summary_confirmed()
