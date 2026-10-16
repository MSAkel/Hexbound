extends Panel

@onready var round_score: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/ScoreContainer/RoundScore
@onready var gold_earned: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/GoldContainer/GoldEarned
@onready var remaining_turns_rewards_container: VBoxContainer = $PanelContainer/ContentMarginContainer/ContentBoxContainer/RemainingTurnsRewardsContainer
@onready var base_gold_label: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/RemainingTurnsRewardsContainer/RewardBreakdownPanel/RewardBreakdownRows/BaseGoldRow/BaseGoldValue
@onready var early_gold_row: HBoxContainer = $PanelContainer/ContentMarginContainer/ContentBoxContainer/RemainingTurnsRewardsContainer/RewardBreakdownPanel/RewardBreakdownRows/EarlyGoldRow
@onready var early_gold_label: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/RemainingTurnsRewardsContainer/RewardBreakdownPanel/RewardBreakdownRows/EarlyGoldRow/EarlyGoldValue
@onready var early_gold_title: Label = $PanelContainer/ContentMarginContainer/ContentBoxContainer/RemainingTurnsRewardsContainer/RewardBreakdownPanel/RewardBreakdownRows/EarlyGoldRow/EarlyGoldTitle


func _ready() -> void:
	hide()
	UiManager.show_round_complete_panel.connect(_on_show_panel)


func _on_show_panel() -> void:
	UiManager.show_panel(self)
	# Read while round advance and turn_started are still deferred so gold earned this turn
	# still reflects the completed round.
	round_score.text = str(GameManager.total_round_score)
	gold_earned.text = str(EconomyManager.earned_this_turn)

	var reward: Dictionary = EconomyManager.last_speed_reward
	var skipped_turns: int = reward.get("skipped_turns", 0)

	remaining_turns_rewards_container.visible = true
	base_gold_label.text = "+%d" % reward.get("base_gold", 0)

	var has_early_bonus := skipped_turns > 0
	early_gold_row.visible = has_early_bonus

	if has_early_bonus:
		early_gold_title.text = "Early finish (x%d per turn)" % EconomyManager.GOLD_PER_UNUSED_TURN
		early_gold_label.text = "+%d" % reward.get("early_gold", 0)

	# Deferred so the panel is laid out and visible before the button takes focus.
	call_deferred("_focus_continue")


## Seats keyboard and gamepad focus on the only action this summary offers.
func _focus_continue() -> void:
	if not visible:
		return
	MenuFocus.grab_named(self, "ContinueButton")


func _on_continue_button_pressed() -> void:
	hide()
	# RoundFlow owns what comes next, this screen only reports that it was dismissed.
	RoundFlow.notify_summary_confirmed()
