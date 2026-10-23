class_name RestState
extends State
## Resting at a rest point (Phase 2 item 18). No control: the player kneels, the screen fades to black, the rest is
## applied under the black (full health and posture, the gourd and the resurrections back, this place remembered
## as the restart point, `RestPoints.bus.rested` announced), then the screen fades back in with the kind's line and the
## player stands. Started by `Player.begin_rest()`, which sets `point` first. Nothing here depends on the kind.

enum Phase { KNEEL, FADE_OUT, BLACK, FADE_IN, DONE }

## Seconds kneeling before the fade starts.
@export var kneel_time: float = 0.8
## Seconds fading to black, staying black (the rest is applied here), and fading back in.
@export var fade_out_time: float = 0.6
@export var black_time: float = 0.5
@export var fade_in_time: float = 0.7

## The rest point being used (set by `Player.begin_rest()` before the state starts).
var point: RestPoint

var _phase: Phase = Phase.KNEEL
var _timer: float = 0.0


func enter(_previous: StringName) -> void:
	_phase = Phase.KNEEL
	_timer = kneel_time
	player.walk_only = false
	player.invulnerable = false
	if player.is_crouched:
		player.set_crouched(false)
	_clear_buffers()
	player.set_stagger_kneel(true, false)


func exit(_next: StringName) -> void:
	player.set_stagger_kneel(false)
	# Left early (for instance by a death): do not stay black.
	if _phase == Phase.FADE_OUT or _phase == Phase.BLACK:
		player.screen_fade.fade_in(0.2)


func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.apply_gravity(delta)
	player.decelerate(delta)
	_clear_buffers()
	_timer -= delta
	if _timer > 0.0:
		return
	match _phase:
		Phase.KNEEL:
			_phase = Phase.FADE_OUT
			_timer = fade_out_time
			player.screen_fade.fade_out(fade_out_time)
		Phase.FADE_OUT:
			_phase = Phase.BLACK
			_timer = black_time
			_apply_rest()
		Phase.BLACK:
			_phase = Phase.FADE_IN
			_timer = fade_in_time
			player.screen_fade.fade_in(fade_in_time)
			player.set_stagger_kneel(false)
			if point != null and is_instance_valid(point):
				player.show_interact_line(point.get_flavor_line())
		Phase.FADE_IN:
			_phase = Phase.DONE
			machine.transition_to(StateName.LOCOMOTION)


## Under the black: the refill, and this place remembered.
func _apply_rest() -> void:
	player.rest_refill()
	if point == null or not is_instance_valid(point):
		return
	var spot := point.get_restart_position(player.global_position.y)
	var yaw := point.get_restart_yaw(spot)
	player.set_restart_point(spot, yaw)
	RestPoints.record(point, spot, yaw)


func _clear_buffers() -> void:
	for action_name: StringName in [Actions.JUMP, Actions.DODGE, Actions.ATTACK, Actions.GUARD, Actions.INTERACT]:
		player.input_buffer.clear(action_name)
