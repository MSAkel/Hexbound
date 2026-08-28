extends CanvasLayer

signal show_runes_choice_panel
signal show_merchant_panel
signal show_round_complete_panel

const PANEL_BOUND_META := "_ui_manager_panel_bound"

var active_panel: Control = null


func show_panel(panel: Control) -> void:
	if panel == null:
		return
	if is_instance_valid(active_panel) and active_panel != panel:
		var previous := active_panel
		active_panel = null
		_unbind_panel(previous)
		previous.hide()
	active_panel = panel
	_bind_panel(panel)
	panel.show()


## Drop the tracked panel after it hides or leaves the tree, without hiding it again.
func release_panel(panel: Control = null) -> void:
	if panel != null and active_panel != panel:
		return
	if is_instance_valid(active_panel):
		_unbind_panel(active_panel)
	active_panel = null


func _bind_panel(panel: Control) -> void:
	if panel.has_meta(PANEL_BOUND_META):
		return
	panel.set_meta(PANEL_BOUND_META, true)
	panel.visibility_changed.connect(_on_panel_visibility_changed.bind(panel))
	panel.tree_exiting.connect(_on_panel_tree_exiting.bind(panel))


func _unbind_panel(panel: Control) -> void:
	if not is_instance_valid(panel) or not panel.has_meta(PANEL_BOUND_META):
		return
	panel.remove_meta(PANEL_BOUND_META)
	var vis := _on_panel_visibility_changed.bind(panel)
	if panel.visibility_changed.is_connected(vis):
		panel.visibility_changed.disconnect(vis)
	var exiting := _on_panel_tree_exiting.bind(panel)
	if panel.tree_exiting.is_connected(exiting):
		panel.tree_exiting.disconnect(exiting)


func _on_panel_visibility_changed(panel: Control) -> void:
	if active_panel != panel:
		return
	if is_instance_valid(panel) and panel.visible:
		return
	release_panel(panel)


func _on_panel_tree_exiting(panel: Control) -> void:
	if active_panel == panel:
		active_panel = null
