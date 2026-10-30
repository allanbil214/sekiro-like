class_name GuardState
extends State
## Guard, deflect, jump guard, jump deflect (Step 5), on the ground and in the air.
##
## A fresh guard press opens a deflect window (Combatant.press_guard(): 0.2 s, shrinking with
## rapid presses). While the state lasts the guard is up (a 90 degree cone in front blocks hits);
## the Combatant decides deflect, guard, or hit when a hit arrives. Holding does not extend the
## window; every deflect needs a new press, and a new press mid-guard starts a new window at once
## (a slightly early press is buffered). Releasing ends the guard, but never before the window has
## run out, so a quick tap still gives its full deflect.
## Forced walk (Player.walk_only); you turn toward your movement input like walking.
## Guard from sheathed snaps the sword drawn with a guard-draw pose (SwordVisual.play_guard).
## Cancels: jump, dodge, and attack (and the wall jump or air attack in the air). Guard itself
## cancels any action outside its hit window (see ActionState._try_guard_cancel).

## 3c-4b PLACEHOLDER(ER clip): the blocked-hit clip (`guard_hit`, the sandbox's guard hit, data/actions/player/guard_hit.tres) the
## figure plays over the held guard when a plain guard blocks a hit on the ground. Only the figure changes: the guard cone, the
## deflect window and walking are untouched. Follows the F1 "Clips drive the figure" switch.
@export var hit_action: ActionData = preload("res://data/actions/player/guard_hit.tres")

var _airborne: bool = false
var _hit_time: float = -1.0


func enter(_previous: StringName) -> void:
	var was_sheathed := player.sheathed
	player.sheathed = false
	player.sheathe_idle = 0.0
	player.walk_only = true
	player.combatant.guarding = true
	player.input_buffer.consume(Actions.GUARD)
	player.combatant.press_guard()
	_airborne = not player.is_on_floor()
	_hit_time = -1.0
	Sfx.play(player.get_tree(), Sfx.Id.GUARD_RAISE)
	if was_sheathed:
		Sfx.play(player.get_tree(), Sfx.Id.DRAW)
	if player.sword_visual != null:
		player.sword_visual.play_guard(was_sheathed)


func exit(_next: StringName) -> void:
	_end_hit_clip()
	player.walk_only = false
	player.combatant.guarding = false
	player.notify_combat()
	if player.sword_visual != null:
		player.sword_visual.end_combo()


func physics_update(delta: float) -> void:
	var combatant := player.combatant
	# A fresh press: a new window, even mid-deflect.
	if player.input_buffer.consume(Actions.GUARD):
		combatant.press_guard()
		if player.sword_visual != null:
			player.sword_visual.play_guard_press()
	var on_floor := player.is_on_floor()
	_update_hit_clip(delta, on_floor)
	if on_floor:
		if _airborne:
			_airborne = false
			player.reset_air_actions()
		if player.input_buffer.consume(Actions.JUMP):
			player.start_jump()
			machine.transition_to(StateName.AIR)
			return
		if player.input_buffer.consume(Actions.DODGE):
			machine.transition_to(StateName.DODGE)
			return
		if player.has_combo() and player.input_buffer.consume(Actions.ATTACK):
			machine.transition_to(StateName.ATTACK)
			return
	else:
		_airborne = true
		player.apply_gravity(delta)
		if player.try_air_jump():
			machine.transition_to(StateName.WALL_JUMP)
			return
		if player.weapon != null and player.input_buffer.has_pressed(Actions.ATTACK) \
				and not player.is_near_ground():
			var air_attack := machine.get_state(StateName.AIR_ATTACK) as AirAttackState
			if air_attack != null and air_attack.start():
				player.input_buffer.consume(Actions.ATTACK)
				return
	player.apply_horizontal_movement(delta, player.get_move_speed())
	player.face_input(delta)
	if not Input.is_action_pressed(Actions.GUARD) and combatant.deflect_left <= 0.0:
		machine.transition_to(StateName.LOCOMOTION if on_floor else StateName.AIR)


## 3c-4b: a plain guard blocked a hit (called by the Player): the figure's blocked-hit clip starts, or starts again. Not in the air.
func play_guard_hit() -> void:
	if hit_action == null or not player.is_on_floor():
		return
	_hit_time = 0.0


func _update_hit_clip(delta: float, on_floor: bool) -> void:
	if _hit_time < 0.0:
		return
	_hit_time += delta * Hitstop.fighter_scale(player)
	if _hit_time >= hit_action.duration or not on_floor:
		_end_hit_clip()
		return
	player.figure.drive_clip(hit_action, _hit_time, 1.0, hit_action.placeholder_clip)


func _end_hit_clip() -> void:
	if _hit_time < 0.0:
		return
	_hit_time = -1.0
	player.figure.stop_clip()
