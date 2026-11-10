class_name HourLedger
extends RefCounted

## Playtest-only log of every Flavour, +Mult, xMult and Gold event in one Hour, in the order it
## happened. Off unless the playtest runner turns it on (--ledger), so a normal game pays one
## bool check per event. Replaying the events rebuilds the Hour score exactly:
##   Flavour += x, mult += a, mult *= f, score = round(Flavour x mult), mult starting at 1.
##
## Event: [kind, source, value, segment, scales]
##   kind    "f" Flavour, "a" +Mult, "x" xMult factor (already boosted), "g" Gold
##   source  id of the card whose activation paid it, "" when no card was activating
##   scales  [garnish, star, chef, station, queued] of that activation, or [] outside one.
##           Their product is the whole output scale, so a reader can take one back out.

static var recording := false
static var events: Array = []
static var _activations: Array = []


static func begin_hour() -> void:
	events = []
	_activations = []
	recording = true


## Stops recording and returns the Hour's events.
static func end_hour() -> Array:
	recording = false
	var result := events
	events = []
	_activations = []
	return result


static func push_activation(source: StringName, scales: Array) -> void:
	if recording:
		_activations.append([String(source), scales])


static func pop_activation() -> void:
	if recording and not _activations.is_empty():
		_activations.pop_back()


static func record(kind: String, segment_index: int, value: float) -> void:
	if not recording:
		return
	var source := ""
	var scales: Array = []
	if not _activations.is_empty():
		var top: Array = _activations.back()
		source = top[0]
		scales = top[1]
	events.append([kind, source, snappedf(value, 0.0001), segment_index, scales])
