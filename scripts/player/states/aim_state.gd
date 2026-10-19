class_name AimState
extends State
## Hold to aim a throwable (Phase 2 item 11b). `Player._try_use_item()` enters it when `use_item` has been held
## for `Player.hold_to_aim_time`; a quicker tap is still the plain throw (`ThrowState`) on release.
## While it lasts:
##   - the camera drops to head height with the body hidden (`CameraRig.begin_aim`);
##   - you stand up and walk slowly (`Player.walk_only`), the body always facing the camera's yaw;
##   - the lock-on is suspended: with a locked target at the start the camera swings onto its chest, then you
##     aim freely (to the head, a leg, a gap), and the lock comes back on release if the target is still valid;
##   - `AimPreview` solves the throw to the crosshair every frame (the arc and the landing ring for a rock or
##     ceramic; `AimHud` draws the crosshair, so a shuriken or kunai has its crosshair only).
## Releasing `use_item` throws: the preview's velocity goes to `ThrowState`, which spends the item at its
## `release_time`. Nothing is spent when the aim is cancelled by guard, a stagger, death, leaving the ground, or
## the selected item running out. Dodge, jump and attack presses are ignored while aiming (an attack press near
## a deathblow target still starts the deathblow). `cycle_item` works: the preview follows the new item.

var _item: ThrowableData
var _relock: Node3D
var _was_locked_out: bool = false


func enter(_previous: StringName) -> void:
	_item = player.item_belt.selected() as ThrowableData
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
	for ignored: StringName in [Actions.DODGE, Actions.JUMP]:
		player.input_buffer.clear(ignored)
	_item = player.item_belt.selected() as ThrowableData
	if _item == null or player.item_belt.selected_count() <= 0:
		machine.transition_to(StateName.LOCOMOTION)
		return
	var throw_state := machine.get_state(StateName.THROW) as ThrowState
	var flat := _camera_flat()
	player.snap_facing(flat)
	player.apply_horizontal_movement(delta, player.get_move_speed())
	var origin := player.global_position + Vector3.UP * throw_state.release_height + flat * throw_state.release_forward
	player.aim_preview.update(origin, _item)
	if not Input.is_action_pressed(Actions.USE_ITEM):
		throw_state.aim_velocity = player.aim_preview.velocity
		machine.transition_to(StateName.THROW)


## The flat direction the camera looks along (the body faces this while aiming).
func _camera_flat() -> Vector3:
	var camera := player.get_viewport().get_camera_3d()
	var forward := -camera.global_basis.z if camera != null else Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Basis(Vector3.UP, player.camera_rig.global_rotation.y) * Vector3.FORWARD
	return forward.normalized()
