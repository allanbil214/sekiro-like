class_name ThrowState
extends ActionState
## Throws the selected item (Phase 2 item 11a), started by `Player._try_throw()` from Locomotion, Crouch or Dash
## (a crouch is stood up first). Driven by `actions/throw.tres` (the clock, the locked window, the cancel window).
## You turn to the aim direction at once (the locked target, else the way the camera looks) and keep walking
## slowly. At `release_time` the item leaves the hand and ONE is spent; before that the throw can still be
## cancelled for free (guard, or a hit) and nothing is used. After the locked window dodge, jump and attack cancel it.
## The throw itself is quiet (`Player.noise_throw`), the landing is the noise (`Throwable`).
## Placeholder: no arm animation yet; the item simply appears at the hand height.
## From a hold (item 11b) `AimState` sets `aim_velocity` first: the throw then leaves with exactly that velocity
## (the one the aim preview showed) and the body faces its flat direction, whatever the lock-on says.

## Seconds from the start when the item leaves the hand (keep it below `locked_until`).
@export var release_time: float = 0.18
## Where the item starts: this high above the feet and this far in front of the body (m).
@export var release_height: float = 1.3
@export var release_forward: float = 0.5

## Set by `AimState` for one throw (item 11b); used and cleared when the throw starts. ZERO = a tap throw.
var aim_velocity: Vector3 = Vector3.ZERO

var _item: ThrowableData
var _aim: Vector3 = Vector3.FORWARD
var _aimed_velocity: Vector3 = Vector3.ZERO
var _released: bool = false


func _on_action_enter(_previous: StringName) -> void:
	_item = player.item_belt.selected() as ThrowableData
	_released = false
	player.walk_only = true
	if player.is_crouched:
		player.set_crouched(false)
	for buffered: StringName in [Actions.DODGE, Actions.JUMP, Actions.ATTACK, Actions.GUARD]:
		player.input_buffer.consume(buffered)
	_aimed_velocity = aim_velocity
	aim_velocity = Vector3.ZERO
	if _aimed_velocity != Vector3.ZERO:
		_aim = Vector3(_aimed_velocity.x, 0.0, _aimed_velocity.z).normalized()
	else:
		_aim = _flat_aim()
	player.snap_facing(_aim)


func _on_action_exit() -> void:
	player.walk_only = false


func _on_action_update(_delta: float) -> void:
	if not _released and action_time >= release_time:
		_release()
	if not action.can_cancel(action_time):
		return
	if player.is_on_floor():
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


## A slow walk while throwing (no turning: the body keeps facing the throw).
func _apply_action_movement(delta: float) -> void:
	player.apply_horizontal_movement(delta, player.get_move_speed())


func _on_action_finished() -> void:
	machine.transition_to(StateName.LOCOMOTION if player.is_on_floor() else StateName.AIR)


func _release() -> void:
	_released = true
	if _item == null or not player.item_belt.spend(_item):
		return
	var origin := player.global_position + Vector3.UP * release_height + _aim * release_forward
	var velocity: Vector3
	if _aimed_velocity != Vector3.ZERO:
		velocity = _aimed_velocity
	elif player.lock_on.has_target():
		velocity = _item.velocity_to(origin, player.lock_on.get_target_position())
	else:
		velocity = _item.velocity_forward(_aim)
	Throwable.launch(player, _item, origin, velocity)
	Sfx.play(player.get_tree(), Sfx.Id.SWING_ALT)


## The flat direction of the throw: toward the locked target, else the way the camera looks.
func _flat_aim() -> Vector3:
	var lock_dir := player.get_lock_direction()
	if lock_dir != Vector3.ZERO:
		return lock_dir
	return Basis(Vector3.UP, player.camera_rig.global_rotation.y) * Vector3.FORWARD
