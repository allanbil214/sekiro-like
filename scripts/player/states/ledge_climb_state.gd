class_name LedgeClimbState
extends ActionState
## Auto-climb onto a ledge found by Player.try_ledge_grab(). Scripted: the position is
## moved directly (up along the wall, then forward onto the top) over the action's
## duration, with the body collision off. The landing spot was checked for room first.

## Share of the duration spent rising before moving forward onto the top.
@export_range(0.1, 0.9) var rise_fraction: float = 0.6

var _start: Vector3
var _rise_end: Vector3
var _target: Vector3


func _allows_guard_cancel() -> bool:
	return false


func _on_action_enter(_previous: StringName) -> void:
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


func _on_action_exit() -> void:
	player.set_body_collision_enabled(true)
	player.release_arms()


func _on_action_finished() -> void:
	player.global_position = _target
	player.velocity = Vector3.ZERO
	player.reset_air_actions()
	machine.transition_to(&"Locomotion")
