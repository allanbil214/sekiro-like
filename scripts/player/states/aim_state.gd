class_name AimState
extends State
## Aim a throwable (Phase 2 items 11b and 11c). `Player._try_use_item()` enters it when `use_item` has been held
## for `Player.hold_to_aim_time`; a quicker tap is still the plain throw (`ThrowState`) on release.
## While it lasts:
##   - the camera drops to head height with the body hidden (`CameraRig.begin_aim`);
##   - you stand up and walk slowly (`Player.walk_only`), the body always facing the camera's yaw;
##   - the lock-on is suspended: with a locked target at the start the camera swings onto its chest, then you
##     aim freely (to the head, a leg, a gap), and the lock comes back when the aim ends if the target is still valid;
##   - `AimPreview` solves the throw to the crosshair every frame (the arc and the landing ring for a rock or
##     ceramic; `AimHud` draws the crosshair, so a shuriken or kunai has its crosshair only).
## Attack (left click, R1) THROWS and the aim goes on; after a throw there is `throw_recovery` seconds before the
## next one (a click pressed up to the input buffer time early still counts). Releasing `use_item` never throws.
## How the aim ends:
##   - `Player.sticky_aim` off (HOLD): letting go of `use_item` ends it. Dodge and jump presses are ignored.
##   - `Player.sticky_aim` on (STICKY): letting go keeps the aim; a fresh `use_item` press ends it, and so do dodge
##     and jump (they then act as usual).
##   - Both: guard and heal end it and start their action; so do a stagger, death, leaving the ground, and the selected
##     item running out. Nothing is spent when the aim ends. `cycle_item` works: the preview follows the new item.
## An attack press never starts a deathblow from here (it throws), so leave the aim first.

## Seconds before the next aimed throw after one (placeholder, tune by playing).
@export var throw_recovery: float = 0.3

var _item: ThrowableData
var _relock: Node3D
var _was_locked_out: bool = false
var _recovery_left: float = 0.0


func enter(_previous: StringName) -> void:
	_item = player.item_belt.selected() as ThrowableData
	_recovery_left = 0.0
	player.walk_only = true
	if player.is_crouched:
		player.set_crouched(false)
	for buffered: StringName in [Actions.DODGE, Actions.JUMP, Actions.ATTACK, Actions.GUARD]:
		player.input_buffer.consume(buffered)
	var camera_rig := player.camera_rig as CameraRig
	var lock_on := player.lock_on
	_relock = null
	var snap_point := Vector3.ZERO
	if lock_on.has_target():
		_relock = lock_on.target
		snap_point = lock_on.get_target_position()
		lock_on.release()
	_was_locked_out = lock_on.locked_out
	lock_on.locked_out = true
	player.visual.visible = false
	camera_rig.begin_aim(snap_point, _relock != null)


func exit(_next: StringName) -> void:
	player.walk_only = false
	player.visual.visible = true
	(player.camera_rig as CameraRig).end_aim()
	player.aim_preview.hide_preview()
	var lock_on := player.lock_on
	lock_on.locked_out = _was_locked_out
	if _relock != null and is_instance_valid(_relock):
		lock_on.lock_onto(_relock)
	_relock = null


func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.coyote_timer = player.coyote_time
		machine.transition_to(StateName.AIR)
		return
	if player.input_buffer.consume(Actions.GUARD):
		machine.transition_to(StateName.GUARD)
		return
	if player.sticky_aim:
		if Input.is_action_just_pressed(Actions.USE_ITEM):
			machine.transition_to(StateName.LOCOMOTION)
			return
		if player.input_buffer.consume(Actions.JUMP):
			player.start_jump()
			machine.transition_to(StateName.AIR)
			return
		if player.input_buffer.consume(Actions.DODGE):
			machine.transition_to(StateName.DODGE)
			return
	else:
		if not Input.is_action_pressed(Actions.USE_ITEM):
			machine.transition_to(StateName.LOCOMOTION)
			return
		for ignored: StringName in [Actions.DODGE, Actions.JUMP]:
			player.input_buffer.clear(ignored)
	_item = player.item_belt.selected() as ThrowableData
	if _item == null or player.item_belt.selected_count() <= 0:
		machine.transition_to(StateName.LOCOMOTION)
		return
	_recovery_left = maxf(_recovery_left - delta, 0.0)
	var throw_state := machine.get_state(StateName.THROW) as ThrowState
	var flat := _camera_flat()
	player.snap_facing(flat)
	player.apply_horizontal_movement(delta, player.get_move_speed())
	var origin := player.global_position + Vector3.UP * throw_state.release_height + flat * throw_state.release_forward
	player.aim_preview.update(origin, _item)
	if _recovery_left <= 0.0 and player.input_buffer.consume(Actions.ATTACK):
		if ThrowState.fire(player, _item, origin, player.aim_preview.velocity):
			_recovery_left = throw_recovery


## The flat direction the camera looks along (the body faces this while aiming).
func _camera_flat() -> Vector3:
	var camera := player.get_viewport().get_camera_3d()
	var forward := -camera.global_basis.z if camera != null else Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Basis(Vector3.UP, player.camera_rig.global_rotation.y) * Vector3.FORWARD
	return forward.normalized()
