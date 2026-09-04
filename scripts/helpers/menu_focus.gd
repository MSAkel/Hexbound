class_name MenuFocus
extends RefCounted

## Grabs focus on the first visible, enabled, focusable Control under root.
static func grab_first(root: Node) -> Control:
	var candidate := _find_first(root)
	if candidate != null:
		candidate.grab_focus()
	return candidate


## Grabs focus on a named descendant when it can receive focus.
static func grab_named(root: Node, node_name: String) -> Control:
	var candidate := root.find_child(node_name, true, false) as Control
	if candidate != null and _can_focus(candidate):
		candidate.grab_focus()
		return candidate
	return grab_first(root)


static func _find_first(node: Node) -> Control:
	if node is Control:
		var control := node as Control
		if _can_focus(control):
			return control
	for child in node.get_children():
		var found := _find_first(child)
		if found != null:
			return found
	return null


static func _can_focus(control: Control) -> bool:
	if control.focus_mode == Control.FOCUS_NONE:
		return false
	if not control.is_visible_in_tree():
		return false
	if control is BaseButton:
		return not (control as BaseButton).disabled
	if control is Range:
		return (control as Range).editable
	return true
