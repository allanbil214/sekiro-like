class_name LedgeClimbState
extends ActionState
## Auto-climb onto a ledge found by LedgeSensor.try_ledge_grab(). Scripted: the position is
## moved directly (up along the wall, then forward onto the top) over the action's
## duration, with the body collision off. The landing spot was checked for room first.

## Share of the duration spent rising before moving forward onto the top.
@export_range(0.1, 0.9) var rise_fraction: float = 0.6

## The climb used when the top only has room to crouch (item 13b); it ends in Crouch. Assign
## data/actions/player/ledge_climb_low.tres in the editor.
@export var low_action: ActionData

var _normal_action: ActionData
var _low: bool = false
var _start: Vector3
var _rise_end: Vector3
var _target: Vector3


func _allows_guard_cancel() -> bool:
	return false


func enter(previous: StringName) -> void:
	if _normal_action == null:
		_normal_action = action
	_low = player.ledge_climb_low and low_action != null
	action = low_action if _low else _normal_action
	super.enter(previous)


func _on_action_enter(_previous: StringName) -> void:
	if _low:
		player.set_crouched(true)
	_start = player.global_position
	_target = player.ledge_stand_pos + Vector3.UP * 0.01
	_rise_end = Vector3(_start.x, _target.y, _start.z)
	player.velocity = Vector3.ZERO
	player.snap_facing(-player.ledge_wall_normal)
	player.set_body_collision_enabled(false)
	player.play_climb_arms()
	Sfx.play(player.get_tree(), Sfx.Id.LEDGE_CLIMB)


func _on_action_update(_delta: float) -> void:
	var t := clampf(action_time / maxf(action.duration, 0.001), 0.0, 1.0)
	if t < rise_fraction:
		var u := smoothstep(0.0, 1.0, t / rise_fraction)
		player.global_position = _start.lerp(_rise_end, u)
	else:
		var u := smoothstep(0.0, 1.0, (t - rise_fraction) / (1.0 - rise_fraction))
		player.global_position = _rise_end.lerp(_target, u)
	player.velocity = Vector3.ZERO


func exit(next: StringName) -> void:
	super.exit(next)
	# Cut short (not finished into Crouch): stand the body capsule up again.
	if _low and next != StateName.CROUCH:
		player.set_crouched(false)


func _on_action_exit() -> void:
	player.set_body_collision_enabled(true)
	player.release_arms()


func _on_action_finished() -> void:
	player.global_position = _target
	player.velocity = Vector3.ZERO
	player.reset_air_actions()
	machine.transition_to(StateName.CROUCH if _low else StateName.LOCOMOTION)
