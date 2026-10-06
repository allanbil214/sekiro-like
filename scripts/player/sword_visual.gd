class_name SwordVisual
extends Node3D
## Placeholder sword swung by an arm. The poses in ActionData say where the sword's TIP
## should pass (clock hour, radius, forward). The arm points from the right shoulder toward
## that point, the hand sits at arm's reach along it, and the blade extends from the hand,
## bent at the wrist: cocked (trailing) at the start of a cut, straightening through it.
## The tip travels along a curve that bows forward, so a slash sweeps through the space in
## front of the player. The cutting edge (the bright strip) leads along the direction of
## travel. Driven by the attack's action_time (the data stays authoritative):
## previous pose -> wind-up -> slash -> follow-through. Place it under Visual.

@export_group("Arm and scale")
## Where the right shoulder is, in the player's local space.
@export var shoulder_offset: float = 0.35
@export var shoulder_height: float = 1.4
## Distance from the shoulder to the hand.
@export var arm_reach: float = 0.6
## Height of the "clock face" center the poses are measured from.
@export var center_height: float = 1.2
## Multiplies every pose's radius and forward distance. The poses were written for a small
## clock face; the sword is swung by an arm, so they need to be bigger.
@export var pose_scale: float = 1.5
## Draw a simple arm from the shoulder to the hand.
@export var show_arm: bool = true
@export_group("Slash path")
## How far (m) the tip bows forward in the middle of a slash. 0 = straight line.
@export var slash_arc_forward: float = 0.5
## The same bow for the wind-up and follow-through (negative bows backward).
@export var windup_arc_forward: float = 0.25
@export_group("Wrist angle")
## Angle between the blade and the arm, in degrees. Positive = the tip trails behind the
## direction of travel (cocked); negative = the tip leads.
@export var wrist_start_angle: float = 50.0
@export var wrist_end_angle: float = -10.0
## Extra lead the wrist adds at the start of the follow-through (degrees).
@export var follow_overshoot: float = 15.0
## How far the blade settles toward the rest direction by the end of the follow-through (0 to 1).
@export_range(0.0, 1.0) var follow_relax: float = 0.5
## Turn on if the bright edge strip trails the swing instead of leading it.
@export var flip_edge: bool = false
@export_group("Rest")
## Blade direction at rest (the hand hangs on the arm line toward the weapon's rest pose).
@export var rest_blade_direction: Vector3 = Vector3(0.15, -0.5, -0.85)
## Which way the cutting edge faces at rest.
@export var rest_edge_direction: Vector3 = Vector3(0.0, 1.0, 0.0)
@export_group("Body twist")
## How far (degrees) the torso twists for a pose at 3:00 or 9:00. Other poses twist in
## proportion to how far left or right they are (1:00 = half). 0 turns the twist off.
@export var max_twist_degrees: float = 30.0
## How much further the arms turn than the body (the arms lead the torso). 1.0 = the same
## angle as the body; 1.5 = 50% further.
@export var arm_twist_factor: float = 2.0
@export_group("Look and timing")
@export var idle_color: Color = Color(0.8, 0.8, 0.85)
@export var active_color: Color = Color(1.0, 0.15, 0.1)
@export var edge_color: Color = Color(1.0, 0.9, 0.3)
@export var arm_color: Color = Color(0.45, 0.5, 0.6)
## Thrust charge: the blade blends toward this color and glows as the charge fills.
@export var charge_color: Color = Color(1.0, 0.55, 0.1)
@export var glow_energy: float = 2.0
## How fast the glow fades after a thrust fires (per second).
@export var glow_fade_speed: float = 4.0
## Time to pull the sword back from the slash wind-up to the charge pose.
@export var charge_blend_time: float = 0.15
## Time to return to the rest pose when the combo ends.
@export var rest_return_time: float = 0.2
## Easing curves (Godot's ease(): negative = in-out, 0 to 1 = fast start, above 1 = slow start).
@export var windup_ease: float = -2.0
@export var slash_ease: float = 0.45
@export var follow_ease: float = 0.5

## Share of the follow-through spent on the wrist overshoot before relaxing.
const OVERSHOOT_PORTION: float = 0.3

var _hand: Node3D
var _arm: Node3D
var _material: StandardMaterial3D
var _tip: Vector3 = Vector3.ZERO
var _blade_dir: Vector3 = Vector3.DOWN
var _edge_dir: Vector3 = Vector3.UP
var _from_tip: Vector3 = Vector3.ZERO
var _from_blade: Vector3 = Vector3.DOWN
var _from_edge: Vector3 = Vector3.UP
var _rest_tip: Vector3 = Vector3.ZERO
var _rest_blade: Vector3 = Vector3.DOWN
var _rest_edge: Vector3 = Vector3.UP
var _twist: float = 0.0
var _from_twist: float = 0.0
var _nose: Node3D
var _nose_base: Vector3 = Vector3.ZERO
var _nose_twisted: bool = false
var _glow: float = 0.0
var _player: Player
var _drop: float = 0.0
var _is_active: bool = false
var _charging_visual: bool = false
var _returning: bool = false
var _return_time: float = 0.0


## Called by the Player in _ready. Builds the arm and blade and puts them at the rest pose.
## The weapon's blade_thickness is used as the blade's width (edge to spine).
func setup(weapon: WeaponData) -> void:
	if _hand != null:
		_hand.queue_free()
	if _arm != null:
		_arm.queue_free()
	var width := weapon.blade_thickness
	var thin := width * 0.2
	_material = StandardMaterial3D.new()
	_material.albedo_color = idle_color
	_material.emission_enabled = true
	_material.emission = charge_color
	_material.emission_energy_multiplier = 0.0
	var edge_material := StandardMaterial3D.new()
	edge_material.albedo_color = edge_color
	var blade := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, thin, weapon.blade_length)
	blade.mesh = mesh
	blade.material_override = _material
	# The hand pivot points its -Z along the blade; the box extends along -Z from the hand.
	blade.position = Vector3(0.0, 0.0, -weapon.blade_length * 0.5)
	# The cutting edge is the strip on the +X side (local +X is the edge direction).
	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(width * 0.2, thin * 1.4, weapon.blade_length)
	strip.mesh = strip_mesh
	strip.material_override = edge_material
	strip.position = Vector3(width * 0.5, 0.0, -weapon.blade_length * 0.5)
	_hand = Node3D.new()
	_hand.add_child(blade)
	_hand.add_child(strip)
	add_child(_hand)
	# The arm pivots at the shoulder and points toward the hand.
	var arm_material := StandardMaterial3D.new()
	arm_material.albedo_color = arm_color
	var arm_mesh_instance := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.09, 0.09, arm_reach)
	arm_mesh_instance.mesh = arm_mesh
	arm_mesh_instance.material_override = arm_material
	arm_mesh_instance.position = Vector3(0.0, 0.0, -arm_reach * 0.5)
	_arm = Node3D.new()
	_arm.add_child(arm_mesh_instance)
	_arm.visible = show_arm
	add_child(_arm)
	_rest_tip = pose_to_point(weapon.rest_pose)
	_rest_blade = rest_blade_direction.normalized()
	_rest_edge = rest_edge_direction.normalized()
	_tip = _rest_tip
	_blade_dir = _rest_blade
	_edge_dir = _rest_edge
	_returning = false
	_twist = 0.0
	_from_twist = 0.0
	# The torso twist also turns the capsule's nose (a sibling under Visual).
	_nose = get_parent().get_node_or_null("Nose") as Node3D
	_player = get_parent().get_parent() as Player
	if _nose != null:
		_nose_base = Vector3(_nose.position.x, 0.0, _nose.position.z)
	_apply()


## (clock hour, radius, forward) -> the point the arm aims at (mirror = left-right flipped), in the player's local space
## (-Z is forward). Radius and forward are multiplied by pose_scale.
func pose_to_point(pose: Vector3, mirror: bool = false) -> Vector3:
	var hour := 12.0 - pose.x if mirror else pose.x
	var angle := deg_to_rad(hour * 30.0)
	var offset := Vector3(sin(angle) * pose.y, cos(angle) * pose.y, -pose.z)
	return Vector3(0.0, center_height - _drop, 0.0) + offset * pose_scale


## An attack starts (or chains): remember where the sword is now so the wind-up blends from it.
func begin_action(_action: ActionData) -> void:
	_returning = false
	_charging_visual = false
	_remember_current()
	_set_active(false)


## Position the sword for the given action time.
func update_action(action: ActionData, time: float, mirror: bool = false) -> void:
	if _hand == null:
		return
	if action.blade_aims_at_end:
		_update_thrust(action, time, mirror)
		return
	var windup_point := pose_to_point(action.swing_windup)
	var end_point := pose_to_point(action.swing_end)
	var follow_point := pose_to_point(action.swing_follow)
	var windup_end := action.active_hit.x
	var active_end := action.active_hit.y
	if time < windup_end:
		var t := clampf(time / maxf(windup_end, 0.001), 0.0, 1.0)
		var k := ease(t, windup_ease)
		_tip = _from_tip.lerp(windup_point, k) + Vector3.FORWARD * windup_arc_forward * sin(PI * k)
		_twist = lerpf(_from_twist, _pose_twist(action.swing_windup), k)
		var travel := _slash_tangent(windup_point, end_point, 0.0)
		var target := _pose(_tip, travel, wrist_start_angle)
		_blend_orientation(_from_blade, _from_edge, target[0], target[1], k)
		_set_active(false)
	elif time < active_end:
		var t := clampf((time - windup_end) / maxf(active_end - windup_end, 0.001), 0.0, 1.0)
		var s := ease(t, slash_ease)
		_tip = _slash_point(windup_point, end_point, s)
		_twist = lerpf(_pose_twist(action.swing_windup), _pose_twist(action.swing_end), s)
		var travel := _slash_tangent(windup_point, end_point, s)
		var pose := _pose(_tip, travel, lerpf(wrist_start_angle, wrist_end_angle, s))
		_blade_dir = pose[0]
		_edge_dir = pose[1]
		_set_active(true)
	else:
		var t := clampf((time - active_end) / maxf(action.duration - active_end, 0.001), 0.0, 1.0)
		var k := ease(t, follow_ease)
		_tip = end_point.lerp(follow_point, k) + Vector3.FORWARD * windup_arc_forward * sin(PI * k)
		_twist = lerpf(_pose_twist(action.swing_end), _pose_twist(action.swing_follow), k)
		var travel := _slash_tangent(windup_point, end_point, 1.0)
		var overshot := _pose(_tip, travel, wrist_end_angle - follow_overshoot)
		if t < OVERSHOOT_PORTION:
			var at_end := _pose(_tip, travel, wrist_end_angle)
			var u := ease(t / OVERSHOOT_PORTION, 0.5)
			_blend_orientation(at_end[0], at_end[1], overshot[0], overshot[1], u)
		else:
			var u := ease((t - OVERSHOOT_PORTION) / (1.0 - OVERSHOOT_PORTION), follow_ease)
			var relaxed_blade := _blend_dir(overshot[0], _rest_blade, follow_relax)
			var relaxed_edge := _blend_dir(overshot[1], _rest_edge, follow_relax)
			_blend_orientation(overshot[0], overshot[1], relaxed_blade, relaxed_edge, u)
		_set_active(false)
	_apply()


## The combo ended: ease back to the rest pose.
func end_combo() -> void:
	if _hand == null:
		return
	_charging_visual = false
	_remember_current()
	_return_time = 0.0
	_returning = true
	_set_active(false)


func _process(delta: float) -> void:
	_update_crouch_drop(delta)
	if _glow > 0.0 and not _charging_visual:
		_glow = move_toward(_glow, 0.0, glow_fade_speed * delta)
		_refresh_color()
	if not _returning:
		return
	_return_time += delta
	var t := clampf(_return_time / maxf(rest_return_time, 0.001), 0.0, 1.0)
	var k := ease(t, -2.0)
	_tip = _from_tip.lerp(_rest_tip, k)
	_twist = lerpf(_from_twist, 0.0, k)
	_blend_orientation(_from_blade, _from_edge, _rest_blade, _rest_edge, k)
	_apply()
	if t >= 1.0:
		_returning = false


## A point on the slash path: a straight chord from a to b, bowed forward in the middle.
func _slash_point(a: Vector3, b: Vector3, s: float) -> Vector3:
	return a.lerp(b, s) + Vector3.FORWARD * slash_arc_forward * sin(PI * s)


## Direction the tip is moving along the slash path at progress s (the path's slope).
func _slash_tangent(a: Vector3, b: Vector3, s: float) -> Vector3:
	var slope := (b - a) + Vector3.FORWARD * slash_arc_forward * PI * cos(PI * s)
	if slope.length_squared() < 0.0001:
		return Vector3.FORWARD
	return slope.normalized()


func _shoulder() -> Vector3:
	return Vector3(shoulder_offset, shoulder_height - _drop, 0.0)


func _arm_direction(tip: Vector3) -> Vector3:
	var to_tip := tip - _shoulder()
	if to_tip.length_squared() < 0.0001:
		return Vector3.FORWARD
	return to_tip.normalized()


## Blade and edge directions for a tip aimed at `tip`, moving along `travel`, with the wrist
## bent by wrist_deg (positive = the blade trails behind the travel direction). The edge is
## the part of the travel direction perpendicular to the blade, so it leads the cut.
func _pose(tip: Vector3, travel: Vector3, wrist_deg: float) -> Array[Vector3]:
	var arm := _arm_direction(tip)
	var lag := travel - arm * travel.dot(arm)
	if lag.length_squared() < 0.0001:
		lag = Vector3.UP - arm * Vector3.UP.dot(arm)
	if lag.length_squared() < 0.0001:
		lag = Vector3.RIGHT
	lag = lag.normalized()
	var wrist := deg_to_rad(wrist_deg)
	var blade := (arm * cos(wrist) - lag * sin(wrist)).normalized()
	var edge := travel - blade * travel.dot(blade)
	if edge.length_squared() < 0.0001:
		edge = lag
	edge = edge.normalized()
	if flip_edge:
		edge = -edge
	var pose: Array[Vector3] = [blade, edge]
	return pose


## The wind-up ended with the button still held: start pulling back into the charge pose.
func begin_charge() -> void:
	_returning = false
	_charging_visual = true
	_remember_current()
	_set_active(false)


## While charging a thrust: pull the sword from where it is to the thrust's wind-up pose (hand
## back, blade pointing forward) and glow more as the charge fills.
func update_charge(thrust: ActionData, mirror: bool, charge_seconds: float, fraction: float) -> void:
	if _hand == null:
		return
	var windup_point := pose_to_point(thrust.swing_windup, mirror)
	var end_point := pose_to_point(thrust.swing_end, mirror)
	var t := clampf(charge_seconds / maxf(charge_blend_time, 0.001), 0.0, 1.0)
	var k := ease(t, windup_ease)
	_tip = _from_tip.lerp(windup_point, k)
	var pose := _thrust_pose(_tip, end_point)
	_blend_orientation(_from_blade, _from_edge, pose[0], pose[1], k)
	_twist = lerpf(_from_twist, _pose_twist(thrust.swing_windup, mirror) * thrust.twist_scale, k)
	_glow = fraction
	_refresh_color()
	_apply()


## A thrust: the hand moves from the wind-up pose to the end pose along a straight line, the
## blade always points at the end pose, and the edge faces down.
func _update_thrust(action: ActionData, time: float, mirror: bool) -> void:
	var windup_point := pose_to_point(action.swing_windup, mirror)
	var end_point := pose_to_point(action.swing_end, mirror)
	var follow_point := pose_to_point(action.swing_follow, mirror)
	var twist_windup := _pose_twist(action.swing_windup, mirror) * action.twist_scale
	var twist_end := _pose_twist(action.swing_end, mirror) * action.twist_scale
	var twist_follow := _pose_twist(action.swing_follow, mirror) * action.twist_scale
	var windup_end := action.active_hit.x
	var active_end := action.active_hit.y
	if time < windup_end:
		var t := clampf(time / maxf(windup_end, 0.001), 0.0, 1.0)
		var k := ease(t, windup_ease)
		_tip = _from_tip.lerp(windup_point, k)
		var pose := _thrust_pose(_tip, end_point)
		_blend_orientation(_from_blade, _from_edge, pose[0], pose[1], k)
		_twist = lerpf(_from_twist, twist_windup, k)
		_set_active(false)
	elif time < active_end:
		var t := clampf((time - windup_end) / maxf(active_end - windup_end, 0.001), 0.0, 1.0)
		var s := ease(t, slash_ease)
		_tip = windup_point.lerp(end_point, s)
		var pose := _thrust_pose(_tip, end_point)
		_blade_dir = pose[0]
		_edge_dir = pose[1]
		_twist = lerpf(twist_windup, twist_end, s)
		_set_active(true)
	else:
		var t := clampf((time - active_end) / maxf(action.duration - active_end, 0.001), 0.0, 1.0)
		var k := ease(t, follow_ease)
		_tip = end_point.lerp(follow_point, k)
		var pose := _thrust_pose(_tip, end_point)
		_blade_dir = _blend_dir(pose[0], _rest_blade, follow_relax * k)
		_edge_dir = _blend_dir(pose[1], _rest_edge, follow_relax * k)
		_twist = lerpf(twist_end, twist_follow, k)
		_set_active(false)
	_apply()


## Blade and edge directions for a thrust with the arm aimed at `tip`: the blade points from
## the hand at the end pose, and the edge faces down.
func _thrust_pose(tip: Vector3, end_point: Vector3) -> Array[Vector3]:
	var hand := _shoulder() + _arm_direction(tip) * arm_reach
	var to_end := end_point - hand
	var blade := Vector3.FORWARD
	if to_end.length_squared() > 0.0001:
		blade = to_end.normalized()
	var edge := Vector3.DOWN - blade * Vector3.DOWN.dot(blade)
	if edge.length_squared() < 0.0001:
		edge = Vector3.RIGHT
	edge = edge.normalized()
	if flip_edge:
		edge = -edge
	var pose: Array[Vector3] = [blade, edge]
	return pose


func _remember_current() -> void:
	_from_tip = _tip
	_from_blade = _blade_dir
	_from_edge = _edge_dir
	_from_twist = _twist


func _blend_orientation(from_blade: Vector3, from_edge: Vector3, to_blade: Vector3, to_edge: Vector3, t: float) -> void:
	_blade_dir = _blend_dir(from_blade, to_blade, t)
	_edge_dir = _blend_dir(from_edge, to_edge, t)


## Blend two directions and renormalize (keeps the first if they cancel out).
func _blend_dir(a: Vector3, b: Vector3, t: float) -> Vector3:
	var d := a.lerp(b, t)
	if d.length_squared() < 0.0001:
		return a
	return d.normalized()


func _set_active(active: bool) -> void:
	_is_active = active
	_refresh_color()


## Blade color: red while the hit window is open, otherwise the idle color tinted toward the
## charge color (and glowing) by the current charge glow.
func _refresh_color() -> void:
	if _material == null:
		return
	if _is_active:
		_material.albedo_color = active_color
	else:
		_material.albedo_color = idle_color.lerp(charge_color, _glow)
	_material.emission_energy_multiplier = _glow * glow_energy


## The whole arm swing lowers with the body while crouched, easing like the body does. The
## stored aim points shift by the same amount so nothing jumps.
func _update_crouch_drop(delta: float) -> void:
	if _player == null or _hand == null:
		return
	var full_drop := _player.stand_height - _player.crouch_height
	var target := full_drop if _player.is_crouched else 0.0
	if is_equal_approx(_drop, target):
		return
	var speed := full_drop / maxf(_player.crouch_transition_time, 0.001)
	var new_drop := move_toward(_drop, target, speed * delta)
	var shift := new_drop - _drop
	_tip.y -= shift
	_from_tip.y -= shift
	_rest_tip.y -= shift
	_drop = new_drop
	_apply()


## Torso twist for a clock pose: positive = twisted to the right, negative = to the left.
func _pose_twist(pose: Vector3, mirror: bool = false) -> float:
	var hour := 12.0 - pose.x if mirror else pose.x
	return max_twist_degrees * sin(deg_to_rad(hour * 30.0))


## Turn the capsule's nose by the body twist, and the whole arm swing by arm_twist_factor
## times that, around the body's vertical axis.
## Godot's positive Y rotation turns the player's front toward its left, so a twist to the
## right is a negative angle.
func _apply_twist() -> void:
	var yaw := -deg_to_rad(_twist)
	rotation.y = yaw * arm_twist_factor
	if _nose == null:
		return
	if absf(_twist) < 0.001 and not _nose_twisted:
		return
	var turned := _nose_base.rotated(Vector3.UP, yaw)
	_nose.position.x = turned.x
	_nose.position.z = turned.z
	_nose.rotation.y = yaw
	_nose_twisted = absf(_twist) >= 0.001


## Place the arm and hand, and build the blade's orientation: local -Z along the blade,
## local +X toward the cutting edge.
func _apply() -> void:
	_apply_twist()
	var arm_dir := _arm_direction(_tip)
	var arm_up := Vector3.UP
	if absf(arm_dir.dot(Vector3.UP)) > 0.99:
		arm_up = Vector3.FORWARD
	_arm.position = _shoulder()
	_arm.basis = Basis.looking_at(arm_dir, arm_up)
	_hand.position = _shoulder() + arm_dir * arm_reach
	var z := -_blade_dir
	var x := _edge_dir - _blade_dir * _edge_dir.dot(_blade_dir)
	if x.length_squared() < 0.0001:
		x = _blade_dir.cross(Vector3.UP)
	if x.length_squared() < 0.0001:
		x = _blade_dir.cross(Vector3.RIGHT)
	x = x.normalized()
	var y := z.cross(x)
	_hand.basis = Basis(x, y, z)
