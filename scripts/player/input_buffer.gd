class_name InputBuffer
extends RefCounted
## Remembers recent button presses so an action pressed slightly early still counts.

var buffer_time: float
var tracked: Array[StringName] = [Actions.JUMP, Actions.DODGE, Actions.INTERACT, Actions.ATTACK, Actions.GUARD]

var _time: float = 0.0
var _pressed_at: Dictionary = {}


func _init(p_buffer_time: float = 0.15) -> void:
	buffer_time = p_buffer_time


## Call once per physics frame, before the states run.
func tick(delta: float) -> void:
	_time += delta
	for action in tracked:
		if Input.is_action_just_pressed(action):
			_pressed_at[action] = _time


## `within` (s) overrides the buffer time for this one check (negative = use `buffer_time`).
func has_pressed(action: StringName, within: float = -1.0) -> bool:
	if not _pressed_at.has(action):
		return false
	var pressed_time: float = _pressed_at[action]
	return _time - pressed_time <= (buffer_time if within < 0.0 else within)


## True if the action was pressed recently. Using it up so it can't trigger twice.
func consume(action: StringName) -> bool:
	if has_pressed(action):
		_pressed_at.erase(action)
		return true
	return false


func clear(action: StringName) -> void:
	_pressed_at.erase(action)
