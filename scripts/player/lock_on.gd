class_name LockOn
extends Node3D
## Lock-on (Step 9). A direct child of the Player. Holds the locked target and its rules:
##   acquire: `lock_on` locks the living enemy nearest the screen center that is in view, in range, and
##            visible (a ray to it is not blocked by the world). With no such enemy nothing happens
##            (or the camera recenters behind the player, if recenter_when_no_target is on).
##   release: `lock_on` again, the target out of release_range, no line of sight for los_lost_time, or
##            the player dead. If the target dies and auto_lock_next is on, the nearest living enemy in
##            range is locked instead (a deathblow that leaves the enemy alive keeps the lock).
##   switch:  a fast sideways mouse move (CameraRig forwards it here) or a right-stick flick selects the
##            next enemy on that side of the screen, with a short cooldown.
## The camera (CameraRig), the body facing (Player.face_input) and the attack lunge read this. Enemies
## and the dummy are targets because they are in group "enemy" and have a Combatant; an optional
## `lock_point_height` property on them (m above the feet) sets where the marker and the aim point sit.

signal target_changed(node: Node3D)
## No target and nothing to lock, with recenter_when_no_target on: turn the camera to this yaw.
signal recenter_requested(yaw: float)

@export_group("Acquire and release")
## How far (m) an enemy can be to be locked or switched to.
@export var acquire_range: float = 20.0
## Half the camera's field (degrees) in which an enemy can be locked by a press.
@export var view_half_angle_degrees: float = 50.0
## A locked target farther than this (m) is released.
@export var release_range: float = 25.0
## A locked target without a clear line for this long (s) is released.
@export var los_lost_time: float = 2.0
## Height (m above the feet) the line-of-sight ray starts from.
@export var los_eye_height: float = 1.4
## Used when the target has no `lock_point_height` property.
@export var default_lock_point_height: float = 1.2

@export_group("Options")
## A press with nothing to lock turns the camera behind the player (off by default).
@export var recenter_when_no_target: bool = false
## When the locked enemy dies, lock the nearest living enemy in range (on by default).
@export var auto_lock_next: bool = true

@export_group("Switching")
## A sideways mouse move this far (pixels, gathered within about a tenth of a second) switches.
@export var flick_distance_px: float = 90.0
## How fast the gathered mouse movement drains (pixels per second); slow movement never adds up.
@export var flick_decay_px_per_s: float = 1200.0
## The right stick must pass this (0 to 1) from near center to count as a flick.
@export var stick_flick_threshold: float = 0.8
@export var switch_cooldown: float = 0.3

@export_group("Marker")
@export var marker_size: float = 0.45
@export var marker_color: Color = Color(1.0, 1.0, 1.0, 0.9)

## The locked target, or null. Use has_target() (the node may have been freed).
var target: Node3D

var _player: Player
var _marker: MeshInstance3D
var _flick_x: float = 0.0
var _stick_previous: float = 0.0
var _cooldown_left: float = 0.0
var _los_lost: float = 0.0


func _ready() -> void:
	_player = get_parent() as Player
	_marker = MeshInstance3D.new()
	_marker.top_level = true
	_marker.visible = false
	var quad := QuadMesh.new()
	quad.size = Vector2(marker_size, marker_size)
	_marker.mesh = quad
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.62, 0.72, 0.88, 0.98])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ring := GradientTexture2D.new()
	ring.gradient = gradient
	ring.fill = GradientTexture2D.FILL_RADIAL
	ring.fill_from = Vector2(0.5, 0.5)
	ring.fill_to = Vector2(1.0, 0.5)
	ring.width = 128
	ring.height = 128
	var material := StandardMaterial3D.new()
	material.albedo_texture = ring
	material.albedo_color = marker_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.render_priority = 10
	_marker.material_override = material
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marker)


func has_target() -> bool:
	return target != null and is_instance_valid(target)


## The aim point on the target (world space): its feet plus the lock point height.
func get_target_position() -> Vector3:
	return _point(target)


## Called by CameraRig while locked: the horizontal mouse movement of this event (pixels).
func feed_flick(dx: float) -> void:
	_flick_x += dx


func release() -> void:
	if target == null:
		return
	target = null
	_los_lost = 0.0
	_flick_x = 0.0
	_marker.visible = false
	target_changed.emit(null)


func get_debug_text() -> String:
	var in_range := 0
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node3D
		if enemy != null and _is_valid_target(enemy) and _flat_distance(enemy) <= acquire_range:
			in_range += 1
	if has_target():
		return "Lock-on: %s  %.1f m  (in range: %d)" % [target.name, _flat_distance(target), in_range]
	return "Lock-on: off  (in range: %d)" % in_range


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"lock_on") or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if has_target():
		release()
		return
	var best := _best_in_view()
	if best != null:
		_set_target(best)
	elif recenter_when_no_target:
		var facing := _player.get_facing_direction()
		recenter_requested.emit(atan2(-facing.x, -facing.z))


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	_flick_x = move_toward(_flick_x, 0.0, flick_decay_px_per_s * delta)
	var stick := Input.get_axis(&"look_left", &"look_right")
	var stick_flick := 0
	if absf(stick) >= stick_flick_threshold and absf(_stick_previous) < 0.5:
		stick_flick = 1 if stick > 0.0 else -1
	_stick_previous = stick
	if target == null:
		_flick_x = 0.0
		return
	var reason := _lost_reason(delta)
	if reason != &"":
		release()
		if reason == &"dead" and auto_lock_next:
			var relock := _nearest_to_player()
			if relock != null:
				_set_target(relock)
		return
	if _cooldown_left > 0.0:
		return
	var direction := 0
	if absf(_flick_x) >= flick_distance_px:
		direction = 1 if _flick_x > 0.0 else -1
	elif stick_flick != 0:
		direction = stick_flick
	if direction == 0:
		return
	_flick_x = 0.0
	var next := _next_on_side(direction)
	if next != null:
		_set_target(next)
		_cooldown_left = switch_cooldown


func _process(_delta: float) -> void:
	if not has_target():
		_marker.visible = false
		return
	var cam := get_viewport().get_camera_3d()
	_marker.visible = true
	_marker.global_position = get_target_position()
	if cam != null:
		var distance := cam.global_position.distance_to(_marker.global_position)
		_marker.scale = Vector3.ONE * maxf(1.0, distance / 6.0)


# --- Rules -------------------------------------------------------------------------------------

## Why the lock must end now: &"dead", &"player", &"range", &"los", or &"" to keep it.
func _lost_reason(delta: float) -> StringName:
	if not is_instance_valid(target) or not _is_valid_target(target):
		return &"dead"
	if _player.combatant.dead:
		return &"player"
	if _flat_distance(target) > release_range:
		return &"range"
	if _has_line_of_sight(target):
		_los_lost = 0.0
	else:
		_los_lost += delta
		if _los_lost >= los_lost_time:
			return &"los"
	return &""


func _set_target(node: Node3D) -> void:
	target = node
	_los_lost = 0.0
	_flick_x = 0.0
	_marker.visible = true
	target_changed.emit(node)


## Alive enemies in range with a clear line to them.
func _candidates() -> Array[Node3D]:
	var found: Array[Node3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node3D
		if enemy == null or not _is_valid_target(enemy):
			continue
		if _flat_distance(enemy) > acquire_range or not _has_line_of_sight(enemy):
			continue
		found.append(enemy)
	return found


## The candidate nearest the screen center, inside the view cone.
func _best_in_view() -> Node3D:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var forward := -cam.global_transform.basis.z
	var half := deg_to_rad(view_half_angle_degrees)
	var best: Node3D = null
	var best_angle := INF
	for enemy: Node3D in _candidates():
		var angle := forward.angle_to(_point(enemy) - cam.global_position)
		if angle <= half and angle < best_angle:
			best = enemy
			best_angle = angle
	return best


## The candidate nearest the player (used after a kill; no view cone).
func _nearest_to_player() -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for enemy: Node3D in _candidates():
		var distance := _flat_distance(enemy)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best


## The candidate just past the current target on the screen, in `direction` (1 = right, -1 = left).
func _next_on_side(direction: int) -> Node3D:
	var origin := _screen_angle(target)
	var best: Node3D = null
	var best_gap := INF
	for enemy: Node3D in _candidates():
		if enemy == target:
			continue
		var gap := (_screen_angle(enemy) - origin) * float(direction)
		if gap > 0.02 and gap < best_gap:
			best = enemy
			best_gap = gap
	return best


## Where the node sits sideways on the screen: an angle from the camera's forward, + = right.
func _screen_angle(node: Node3D) -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	var cam_basis := cam.global_transform.basis
	var to := _point(node) - cam.global_position
	return atan2(to.dot(cam_basis.x), -to.dot(cam_basis.z))


func _is_valid_target(node: Node3D) -> bool:
	var combatant := Combatant.of(node)
	return combatant != null and not combatant.dead


func _flat_distance(node: Node3D) -> float:
	var delta := node.global_position - _player.global_position
	delta.y = 0.0
	return delta.length()


func _point(node: Node3D) -> Vector3:
	var height: Variant = node.get("lock_point_height")
	return node.global_position + Vector3.UP * (float(height) if height != null else default_lock_point_height)


func _has_line_of_sight(node: Node3D) -> bool:
	var from := _player.global_position + Vector3.UP * los_eye_height
	var query := PhysicsRayQueryParameters3D.create(from, _point(node), Layers.WORLD)
	var skip: Array[RID] = [_player.get_rid()]
	for other: Node in get_tree().get_nodes_in_group(&"enemy"):
		var body := other as CollisionObject3D
		if body != null:
			skip.append(body.get_rid())
	query.exclude = skip
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
