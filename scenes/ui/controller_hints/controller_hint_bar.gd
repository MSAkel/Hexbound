class_name ControllerHintBar
extends CanvasLayer

## Button hints for the in-run controller, pinned top center between the status bar and Day Rating.
## GamepadGameplayController fills it. Built in code so it has no scene of its own.

const TOP_MARGIN := 30.0
## Lower position used while a board view's "Show ..." button sits at the top center.
const TOP_MARGIN_BELOW_BUTTON := 86.0
const FONT_SIZE := 17
const PANEL_FILL := Color(0.07, 0.11, 0.09, 0.86)
const BORDER_COLOR := Color("#6fdc9c")
const AREA_COLOR := Color("#6fdc9c")
const TEXT_COLOR := Color(0.9, 0.94, 0.9)

var _panel: PanelContainer
var _label: RichTextLabel
var _text := ""


func _ready() -> void:
	layer = 1
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_FILL
	style.border_color = BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_label.add_theme_font_size_override("bold_font_size", FONT_SIZE)
	_label.add_theme_color_override("default_color", TEXT_COLOR)
	_panel.add_child(_label)
	_panel.hide()


## Shows area as a heading followed by hints. An empty hints list hides the bar.
func show_hints(area: String, hints: PackedStringArray, below_top_button: bool) -> void:
	_panel.offset_top = TOP_MARGIN_BELOW_BUTTON if below_top_button else TOP_MARGIN
	if hints.is_empty():
		hide_hints()
		return
	var text := "[color=#%s][b]%s[/b][/color]     %s" % [
		AREA_COLOR.to_html(false), area.to_upper(), "     ".join(hints)
	]
	if text != _text:
		_text = text
		_label.text = text
		# Shrink to the new text, then re-center on the anchor.
		_panel.reset_size()
		_panel.offset_left = -_panel.size.x * 0.5
		_panel.offset_right = _panel.size.x * 0.5
	_panel.show()


func hide_hints() -> void:
	_panel.hide()
