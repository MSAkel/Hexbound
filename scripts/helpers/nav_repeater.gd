class_name NavRepeater
extends RefCounted

## Turns held stick or D-pad input into discrete steps: one on press, then repeats after a delay.

const INITIAL_DELAY := 0.32
const REPEAT_DELAY := 0.11

var _held := Vector2i.ZERO
var _timer := 0.0


## Call once per frame. Returns a cardinal step such as (1, 0), or zero when nothing fires.
func poll(delta: float) -> Vector2i:
	var direction := _read_direction()
	if direction != _held:
		_held = direction
		_timer = INITIAL_DELAY
		return direction
	if direction == Vector2i.ZERO:
		return Vector2i.ZERO
	_timer -= delta
	if _timer > 0.0:
		return Vector2i.ZERO
	_timer = REPEAT_DELAY
	return direction


## Treat the direction held right now as already used, so it only fires again after the repeat delay.
## Used when input resumes, so the press that woke the controller does not also move focus.
func absorb() -> void:
	_held = _read_direction()
	_timer = INITIAL_DELAY


func _read_direction() -> Vector2i:
	var vector := Input.get_vector(
		InputManager.ACTION_LEFT,
		InputManager.ACTION_RIGHT,
		InputManager.ACTION_UP,
		InputManager.ACTION_DOWN
	)
	if vector == Vector2.ZERO:
		return Vector2i.ZERO
	if absf(vector.x) > absf(vector.y):
		return Vector2i(int(signf(vector.x)), 0)
	return Vector2i(0, int(signf(vector.y)))
