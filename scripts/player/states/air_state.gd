class_name AirState
extends State
## In the air: gravity, air control, coyote jump, and landing.

## Item 16: how often the hint probes (the rays are cheap but not free), in milliseconds.
const HINT_PROBE_MS: int = 100

var _hint_probe_at: int = 0
var _hint_wall_jump: bool = false
var _hint_hang: bool = false


func enter(_previous: StringName) -> void:
	_hint_probe_at = 0
	_hint_wall_jump = false
	_hint_hang = false


func exit(_next: StringName) -> void:
	player.stop_air_reach()  # 3c-5: the arms raised by `interact` come down (a ledge hang raises its own)


func physics_update(delta: float) -> void:
	player.coyote_timer = maxf(player.coyote_timer - delta, 0.0)
	player.apply_gravity(delta)
	player.update_air_reach(delta)  # 3c-5: `interact` held in the air raises the arms
	if player.ledge_sensor.try_ledge_grab():
		machine.transition_to(player.ledge_sensor.ledge_grab_state())
		return
	if player.coyote_timer > 0.0 and player.input_buffer.consume(Actions.JUMP):
		player.start_jump()
	elif player.coyote_timer <= 0.0 and player.try_air_jump():
		machine.transition_to(StateName.WALL_JUMP)
		return
	# Jump guard (and jump deflect): the same Guard state, with gravity.
	if player.input_buffer.has_pressed(Actions.GUARD):
		machine.transition_to(StateName.GUARD)
		return
	# Death from above (item 7c): an attack press over a stealth target plunges onto it.
	if player.weapon != null and player.input_buffer.has_pressed(Actions.ATTACK, player.aerial_kill_buffer_time):
		var aerial_target := player.find_aerial_target()
		if aerial_target != null:
			player.begin_aerial_kill(aerial_target)
			return
	# Attack in the air starts the air tap loop. Close to the ground the press stays buffered,
	# so landing turns it into a ground attack instead.
	if player.weapon != null and player.input_buffer.has_pressed(Actions.ATTACK) \
			and not player.is_near_ground():
		var air_attack := machine.get_state(StateName.AIR_ATTACK) as AirAttackState
		if air_attack != null and air_attack.start():
			player.input_buffer.consume(Actions.ATTACK)
			return
	player.apply_air_steering(delta)
	player.face_input(delta)
	if player.is_on_floor() and player.velocity.y <= 0.0:
		player.reset_air_actions()
		# 3c-3a: a landing of a real fall gets its own short action (clip and lockout); a bump or a step does not.
		var land := machine.get_state(StateName.LAND) as LandState
		if land != null and land.begin(player.last_fall_height, player.last_land_jumped,
				Vector2(player.velocity.x, player.velocity.z).length()):
			return
		machine.transition_to(StateName.LOCOMOTION)


## Item 16: Wall jump (a wall in reach and a wall jump left) and Hang (a ledge top in reach that is not grabbed yet,
## for instance while still rising fast; `interact` makes the grab a hang instead of the auto-climb).
func get_hints() -> Array[Dictionary]:
	var hints: Array[Dictionary] = []
	var now := Time.get_ticks_msec()
	if now - _hint_probe_at >= HINT_PROBE_MS:
		_hint_probe_at = now
		_hint_wall_jump = player.can_wall_jump_now()
		_hint_hang = player.ledge_sensor.ledge_in_reach()
	if _hint_wall_jump:
		hints.append({"action": Actions.JUMP, "text": "Wall jump"})
	if _hint_hang:
		hints.append({"action": Actions.INTERACT, "text": "Hang"})
	return hints
