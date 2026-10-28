class_name DodgeState
extends ActionState
## Dodge: a burst of movement with i-frames. Direction follows the movement input;
## with no input it is a backstep. Holding the dodge button after the locked window
## ends turns it into a dash. Pressing attack after the locked window starts the weapon's
## dash attack (the draw slash instead, while sheathed).

@export var backstep_speed_multiplier: float = 0.7

## 3a-3c-2 PLACEHOLDER(ER clip): the clip picked for this dodge (`roll_front`, `roll_back`, `roll_left`, `roll_right` or
## `backstep`), see `_clip_name()`.
var _clip: StringName = &"roll_front"


func _on_action_enter(_previous: StringName) -> void:
	Sfx.play(player.get_tree(), Sfx.Id.DODGE)
	var input_dir := player.get_move_input()
	if input_dir.length_squared() > 0.01:
		_move_dir = input_dir.normalized()
		_move_speed_multiplier = 1.0
		player.snap_facing_lock_aware(_move_dir)
		_clip = _roll_clip()
	else:
		var back := -player.get_facing_direction()
		var lock_dir := player.get_lock_direction()
		if lock_dir != Vector3.ZERO:
			# Locked on: the backstep goes straight away from the target.
			back = -lock_dir
		back.y = 0.0
		_move_dir = back.normalized()
		_move_speed_multiplier = backstep_speed_multiplier
		_clip = &"backstep"


## 3a-3c-2: the roll clip for the dodge direction relative to where the body faces (after the facing snap). Free-moving
## the body faces the dodge, so it is always `roll_front`; locked on it keeps facing the target, so left, right and back
## can happen. Within 45 degrees of the facing is front, beyond 135 is back.
func _roll_clip() -> StringName:
	var angle: float = rad_to_deg(player.get_facing_direction().signed_angle_to(_move_dir, Vector3.UP))
	if absf(angle) <= 45.0:
		return &"roll_front"
	if absf(angle) >= 135.0:
		return &"roll_back"
	# A positive angle (counterclockwise seen from above) is to the figure's left.
	return &"roll_left" if angle > 0.0 else &"roll_right"


func _clip_name() -> StringName:
	return _clip if action.placeholder_clip != &"" else &""


## Each input has its own time when the dodge's 3b-1 fields are set; an input with none set follows the old
## cancel window.
func _on_action_update(_delta: float) -> void:
	if player.is_on_floor() and action.can_cancel_input(ActionData.FeelInput.JUMP, action_time) \
			and player.input_buffer.consume(Actions.JUMP):
		player.start_jump()
		machine.transition_to(StateName.AIR)
		return
	if player.weapon != null and action.can_cancel_input(ActionData.FeelInput.ATTACK, action_time) \
			and player.input_buffer.has_pressed(Actions.ATTACK):
		var attack := machine.get_state(StateName.ATTACK) as AttackState
		if attack != null and attack.try_start_variant(player.weapon.dash_attack):
			player.input_buffer.consume(Actions.ATTACK)
			return
	if action.can_cancel_input(ActionData.FeelInput.DODGE, action_time) and player.input_buffer.consume(Actions.DODGE):
		machine.transition_to(StateName.DODGE)
		return
	if action.can_cancel_input(ActionData.FeelInput.MOVE, action_time) \
			and player.get_move_input().length_squared() > 0.01:
		if Input.is_action_pressed(Actions.DODGE):
			machine.transition_to(StateName.DASH)
		else:
			machine.transition_to(StateName.LOCOMOTION)


## While the dodge button is held with a direction input (it is about to flow into a dash, or a jump),
## the burst fades down to the dash speed and no lower, so there is no dip before the dash. A tap and
## the backstep keep the normal fade (move_end_factor) and the short slide.
func _apply_action_movement(delta: float) -> void:
	if _move_dir != Vector3.ZERO and runner.in_move_window(action) and _flows_into_dash():
		var base_speed := action.move_speed * _move_speed_multiplier
		var factor := maxf(runner.move_fade_factor(action), player.dash_speed / maxf(base_speed, 0.001))
		player.set_horizontal_velocity(_move_dir * base_speed * factor)
		return
	super(delta)


func _flows_into_dash() -> bool:
	return _move_speed_multiplier >= 1.0 and Input.is_action_pressed(Actions.DODGE) \
			and player.get_move_input().length_squared() > 0.01