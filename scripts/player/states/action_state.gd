class_name ActionState
extends State
## Runs any ActionData on an "action clock". Windows in the data are read against
## action_time, so a later AnimationPlayer can simply follow it. Dodge, attacks, and
## other actions extend this.

@export var action: ActionData

var action_time: float = 0.0
var speed_scale: float = 1.0

var _move_dir: Vector3 = Vector3.ZERO
var _move_speed_multiplier: float = 1.0


func enter(previous: StringName) -> void:
	action_time = 0.0
	speed_scale = action.speed_scale
	_move_dir = Vector3.ZERO
	_move_speed_multiplier = 1.0
	_on_action_enter(previous)


func exit(_next: StringName) -> void:
	player.invulnerable = false
	_on_action_exit()


func physics_update(delta: float) -> void:
	action_time += delta * speed_scale
	player.invulnerable = action.has_iframes(action_time)
	if not player.is_on_floor():
		player.apply_gravity(delta)
	_apply_action_movement(delta)
	_on_action_update(delta)
	if machine.current != self:
		return
	if action_time >= action.duration:
		_on_action_finished()


func _apply_action_movement(delta: float) -> void:
	var window := action.move_window
	if _move_dir != Vector3.ZERO and ActionData.in_window(window, action_time):
		var factor := 1.0
		if action.move_fade:
			factor = 1.0 - (action_time - window.x) / maxf(window.y - window.x, 0.001)
		player.set_horizontal_velocity(_move_dir * action.move_speed * _move_speed_multiplier * factor)
	else:
		player.decelerate(delta)


## Hooks for subclasses.
func _on_action_enter(_previous: StringName) -> void:
	pass


func _on_action_exit() -> void:
	pass


func _on_action_update(_delta: float) -> void:
	pass


func _on_action_finished() -> void:
	machine.transition_to(&"Locomotion")
