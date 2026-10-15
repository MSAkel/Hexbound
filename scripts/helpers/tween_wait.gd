class_name TweenWait
extends RefCounted

## Awaits a tween without hanging if it already finished or was killed.
## Tween.finished does not fire again after completion, and kill() never emits it.
static func finished(node: Node, tween: Tween) -> void:
	if tween == null or node == null or not node.is_inside_tree():
		return
	var tree := node.get_tree()
	while tween.is_valid() and is_instance_valid(node) and node.is_inside_tree():
		if tween.is_running() or tree.paused:
			await tree.process_frame
			continue
		return
