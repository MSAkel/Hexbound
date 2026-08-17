class_name CountingNumber
extends RefCounted

## Tweens an integer readout on a label. Large jumps stay snappy via a log-scaled duration.

const MIN_DURATION := 0.14
const MAX_DURATION := 0.5

var _host: Node
var _apply_text: Callable
var _on_value: Callable
var _displayed: float = 0.0
var _tween: Tween
var _use_thousands_separator: bool = false


func _init(
	host: Node,
	apply_text: Callable,
	use_thousands_separator: bool = false,
	on_value: Callable = Callable()
) -> void:
	_host = host
	_apply_text = apply_text
	_use_thousands_separator = use_thousands_separator
	_on_value = on_value


## Binds a standard Label so callers do not have to wrap text assignment.
static func for_label(
	host: Node,
	label: Label,
	use_thousands_separator: bool = false,
	on_value: Callable = Callable()
) -> CountingNumber:
	return CountingNumber.new(
		host,
		func(text: String) -> void: label.text = text,
		use_thousands_separator,
		on_value
	)


## Binds a RichTextLabel the same way as for_label.
static func for_rich_text_label(
	host: Node,
	label: RichTextLabel,
	use_thousands_separator: bool = false,
	on_value: Callable = Callable()
) -> CountingNumber:
	return CountingNumber.new(
		host,
		func(text: String) -> void: label.text = text,
		use_thousands_separator,
		on_value
	)


## Sets the displayed value immediately and stops any running count.
func snap_to(value: int) -> void:
	kill()
	_displayed = float(value)
	_write(_displayed)


## Starts a count from the current displayed value to target. Await the returned tween to wait.
func play(target: int) -> Tween:
	var from := _displayed
	var delta := absf(float(target) - from)
	if delta < 0.5 or not _is_host_valid():
		snap_to(target)
		return null

	# Log-scaled duration so huge jumps still finish quickly, small ones still read as a count.
	var duration := clampf(
		MIN_DURATION + log(delta + 1.0) / log(10.0) * 0.1,
		MIN_DURATION,
		MAX_DURATION
	)
	duration /= GameManager.game_speed

	kill()
	_tween = _host.create_tween()
	_tween.tween_method(_write, from, float(target), duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void:
		_displayed = float(target)
		_write(_displayed)
	)
	return _tween


func kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _write(value: float) -> void:
	_displayed = value
	var as_int := int(round(value))
	if _apply_text.is_valid():
		_apply_text.call(format_int(as_int) if _use_thousands_separator else str(as_int))
	if _on_value.is_valid():
		_on_value.call(as_int)


func _is_host_valid() -> bool:
	return _host != null and is_instance_valid(_host)


static func format_int(value: int) -> String:
	var sign_prefix := "-" if value < 0 else ""
	var digits := str(absi(value))
	var grouped := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			grouped = "," + grouped
		grouped = digits[i] + grouped
		count += 1
	return sign_prefix + grouped
