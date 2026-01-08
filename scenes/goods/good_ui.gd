extends Panel

@onready var icon: TextureRect = $CenterContainer/Icon
@onready var amount_label: Label = $AmountContainer/AmountLabel

@export var good_type: Good



func _ready() -> void:
	amount_label.text = "0"
	icon.texture = good_type.icon

	GoodsManager.good_amount_changed.connect(_on_amount_changed)


func _on_amount_changed(good: Good, new_amount: int) -> void:
	if good == good_type:
		amount_label.text = str(new_amount)


func _on_mouse_entered() -> void:
	# Formats its own tooltip string and passes it to the generic signal:
	var text := good_type.name
	if good_type.description != "":
		text += "\n" + good_type.description
	var global_rect = get_global_rect()
	Events.toggle_tooltip.emit(true, text, global_rect)


func _on_mouse_exited() -> void:
	#hide tooltip
	Events.toggle_tooltip.emit(false, "", Rect2())
