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
##
## Hits (Step 4): the Hitbox (an Area3D child of this node) follows the hand every frame, so the
## damage box lies along the blade. Without one set in the Inspector, a Hitbox is created in code.
##
## Sheathing (3c, visual only): the sword rests in a scabbard at the left hip (edge up) while the
## arm hangs relaxed. Drawing (R) reaches the right hand across to the grip, then pulls the blade
## out; sheathing brings it back, slides it in, and lets go. The draw slash does the same reach
## and pull as its wind-up. The blade root is pinned to the grip (`_pin` 1) while the hand is
## not holding it; the arm stretches (`_arm_len`) so the hand actually reaches the hip.

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
## The damage box that follows the blade (an Area3D with a Hitbox script, a child of this node).
@export var hitbox: Hitbox
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
@export_group("Sheath and draw")
## Scabbard color (a plain box along the sheathed blade).
@export var scabbard_color: Color = Color(0.16, 0.12, 0.1)
## Where the arm hangs while the sword is sheathed (the hand is not holding it).
@export var relaxed_arm_direction: Vector3 = Vector3(0.1, -1.0, -0.1)
## Draw (R button): time for the hand to reach the grip, then to pull the blade out.
@export var draw_reach_time: float = 0.15
@export var draw_pull_time: float = 0.25
## Of the draw slash's wind-up, the share spent reaching for the grip (the rest is the pull).
@export_range(0.1, 0.9) var draw_reach_share: float = 0.5
## Of the pull, the share spent sliding the blade out along its own line before it swings away.
@export_range(0.1, 0.9) var draw_slide_fraction: float = 0.3
## How far (m) the hand slides the blade along its own line when drawing or sheathing.
@export var draw_slide_distance: float = 0.3
## Sheathe (R, or auto): bring the sword to the scabbard, slide it in, then let go and relax.
@export var sheathe_approach_time: float = 0.2
@export var sheathe_slide_time: float = 0.25
@export var sheathe_release_time: float = 0.15
@export_group("Guard")
## Clock pose the hand aims at while guarding (hour, radius, forward), like the swing poses.
@export var guard_pose: Vector3 = Vector3(11.0, 0.2, 0.5)
## Blade and edge directions in the guard (the player's local space, -Z forward): the blade held
## across the front, the edge facing out.
@export var guard_blade_direction: Vector3 = Vector3(-0.92, 0.25, -0.3)
@export var guard_edge_direction: Vector3 = Vector3(0.0, 0.3, -1.0)
## Seconds to raise the sword into the guard from a drawn sword.
@export var guard_blend_time: float = 0.07
## From the scabbard: the reach to the grip and the (fast) pull into the guard pose.
@export var guard_draw_reach_time: float = 0.04
@export var guard_draw_pull_time: float = 0.08
## The blade flick on a hit (degrees), its length (s), and how far the hand is pushed back (m).
@export var deflect_wobble_angle: float = 30.0
@export var guard_wobble_angle: float = 12.0
@export var wobble_time: float = 0.28
@export var wobble_push: float = 0.08
## Blade flash on a deflect (white) and on a plain guard (orange), and its length (s).
@export var deflect_flash_color: Color = Color(1.0, 1.0, 1.0)
@export var guard_flash_color: Color = Color(1.0, 0.5, 0.1)
@export var flash_time: float = 0.18
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
enum Anim { NONE, DRAW, SHEATHE, GUARD }
var _weapon: WeaponData
var _scabbard: Node3D
## Arm length (the arm stretches to reach the hip) and how much the blade root is pinned to the
## sheathed grip instead of the hand (0 = in the hand, 1 = in the scabbard).
var _arm_len: float = 0.6
var _from_arm_len: float = 0.6
var _pin: float = 0.0
var _from_pin: float = 0.0
var _sheath_grip: Vector3 = Vector3.ZERO
var _sheath_blade: Vector3 = Vector3.BACK
var _sheath_edge: Vector3 = Vector3.UP
var _anim: Anim = Anim.NONE
var _anim_time: float = 0.0
var _guard_from_sheath: bool = false
var _wobble_left: float = 0.0
var _wobble_amp: float = 0.0
var _wobble_side: float = 1.0
var _flash: float = 0.0
var _flash_color: Color = Color.WHITE


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
	_weapon = weapon
	_arm_len = arm_reach
	_from_arm_len = arm_reach
	_pin = 0.0
	_from_pin = 0.0
	_anim = Anim.NONE
	_sheath_grip = weapon.sheathed_grip
	_sheath_blade = weapon.sheathed_blade_direction.normalized()
	_sheath_edge = weapon.sheathed_edge_direction.normalized()
	_build_scabbard(weapon)
	if hitbox == null:
		push_warning("SwordVisual: no Hitbox set; creating one in code (add an Area3D with hitbox.gd).")
		hitbox = Hitbox.new()
		hitbox.name = "Hitbox"
		add_child(hitbox)
	hitbox.configure(weapon.blade_length)
	_apply()


## (clock hour, radius, forward) -> the point the arm aims at (mirror = left-right flipped), in the player's local space
## (-Z is forward). Radius and forward are multiplied by pose_scale.
func pose_to_point(pose: Vector3, mirror: bool = false) -> Vector3:
	var hour := 12.0 - pose.x if mirror else pose.x
	var angle := deg_to_rad(hour * 30.0)
	var offset := Vector3(sin(angle) * pose.y, cos(angle) * pose.y, -pose.z)
	return Vector3(0.0, center_height - _drop, 0.0) + offset * pose_scale


## True while a draw or sheathe animation is playing (R is ignored then).
func is_busy() -> bool:
	return _anim != Anim.NONE


## Put the sword in the scabbard at once (no animation), arm relaxed.
func snap_sheathed() -> void:
	if _hand == null:
		return
	_anim = Anim.NONE
	_returning = false
	_charging_visual = false
	_tip = _relaxed_aim()
	_arm_len = arm_reach
	_pin = 1.0
	_blade_dir = _sheath_blade
	_edge_dir = _sheath_edge
	_twist = 0.0
	_set_active(false)
	_apply()


## R while sheathed: the hand reaches the grip, then pulls the blade out into the rest pose.
func play_draw() -> void:
	_start_anim(Anim.DRAW)


## R while drawn (or auto-sheathe): the hand brings the sword to the scabbard, slides it in, lets go.
func play_sheathe() -> void:
	_start_anim(Anim.SHEATHE)


## Guard pressed: the sword comes up across the front. From the scabbard it is a fast reach and
## pull (the hand grips and the blade is out, held in front); from a drawn sword, a quick raise.
func play_guard(from_sheath: bool) -> void:
	if _hand == null:
		return
	_returning = false
	_charging_visual = false
	_remember_current()
	_anim = Anim.GUARD
	_anim_time = 0.0
	_guard_from_sheath = from_sheath
	_wobble_left = 0.0
	_set_active(false)


## A fresh guard press while already guarding: a small flick, so a re-press is visible.
func play_guard_press() -> void:
	_start_wobble(deg_to_rad(guard_wobble_angle) * 0.4, 1.0)


## A hit met the guard: the blade flicks (more on a deflect, like Wolf's parry; a heavier shudder on
## a plain guard) and flashes white (deflect) or orange (guard). side > 0 = the attacker is on the right.
func play_guard_hit(deflect: bool, side: float) -> void:
	_start_wobble(deg_to_rad(deflect_wobble_angle if deflect else guard_wobble_angle), side)
	_flash = 1.0
	_flash_color = deflect_flash_color if deflect else guard_flash_color
	_refresh_color()


func _start_wobble(amplitude: float, side: float) -> void:
	_wobble_amp = amplitude
	_wobble_side = 1.0 if side >= 0.0 else -1.0
	_wobble_left = wobble_time


## A decaying swing from the full flick: 1 at the start, ringing out to 0.
func _wobble_value() -> float:
	if _wobble_left <= 0.0:
		return 0.0
	var t := 1.0 - _wobble_left / maxf(wobble_time, 0.001)
	return exp(-4.0 * t) * cos(TAU * 1.5 * t)


func _start_anim(kind: Anim) -> void:
	if _hand == null:
		return
	_returning = false
	_charging_visual = false
	_remember_current()
	_anim = kind
	_anim_time = 0.0
	_set_active(false)


## An attack starts (or chains): remember where the sword is now so the wind-up blends from it.
func begin_action(_action: ActionData) -> void:
	_wobble_left = 0.0
	_anim = Anim.NONE
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
	var windup_point := pose_to_point(action.swing_windup, mirror)
	var end_point := pose_to_point(action.swing_end, mirror)
	var follow_point := pose_to_point(action.swing_follow, mirror)
	var windup_end := action.active_hit.x
	var active_end := action.active_hit.y
	_settle_hold(ease(clampf(time / maxf(windup_end, 0.001), 0.0, 1.0), windup_ease))
	if time < windup_end:
		if _weapon != null and action == _weapon.draw_attack:
			_update_draw_windup(action, time, windup_point, end_point)
			_apply()
			return
		var t := clampf(time / maxf(windup_end, 0.001), 0.0, 1.0)
		var k := ease(t, windup_ease)
		_tip = _from_tip.lerp(windup_point, k) + Vector3.FORWARD * windup_arc_forward * sin(PI * k)
		_twist = lerpf(_from_twist, _pose_twist(action.swing_windup, mirror), k)
		var travel := _slash_tangent(windup_point, end_point, 0.0)
		var target := _pose(_tip, travel, wrist_start_angle)
		_blend_orientation(_from_blade, _from_edge, target[0], target[1], k)
		_set_active(false)
	elif time < active_end:
		var t := clampf((time - windup_end) / maxf(active_end - windup_end, 0.001), 0.0, 1.0)
		var s := ease(t, slash_ease)
		_tip = _slash_point(windup_point, end_point, s)
		_twist = lerpf(_pose_twist(action.swing_windup, mirror), _pose_twist(action.swing_end, mirror), s)
		var travel := _slash_tangent(windup_point, end_point, s)
		var pose := _pose(_tip, travel, lerpf(wrist_start_angle, wrist_end_angle, s))
		_blade_dir = pose[0]
		_edge_dir = pose[1]
		_set_active(true)
	else:
		var t := clampf((time - active_end) / maxf(action.duration - active_end, 0.001), 0.0, 1.0)
		var k := ease(t, follow_ease)
		_tip = end_point.lerp(follow_point, k) + Vector3.FORWARD * windup_arc_forward * sin(PI * k)
		_twist = lerpf(_pose_twist(action.swing_end, mirror), _pose_twist(action.swing_follow, mirror), k)
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
	_wobble_left = 0.0
	_anim = Anim.NONE
	_charging_visual = false
	_remember_current()
	_return_time = 0.0
	_returning = true
	_set_active(false)


func _process(delta: float) -> void:
	if _wobble_left > 0.0:
		_wobble_left = maxf(_wobble_left - delta, 0.0)
	if _flash > 0.0:
		_flash = maxf(_flash - delta / maxf(flash_time, 0.001), 0.0)
		_refresh_color()
	_update_crouch_drop(delta)
	if _glow > 0.0 and not _charging_visual:
		_glow = move_toward(_glow, 0.0, glow_fade_speed * delta)
		_refresh_color()
	if _anim != Anim.NONE:
		_update_anim(delta)
		return
	if not _returning:
		return
	_return_time += delta
	var t := clampf(_return_time / maxf(rest_return_time, 0.001), 0.0, 1.0)
	var k := ease(t, -2.0)
	_tip = _from_tip.lerp(_rest_tip, k)
	_arm_len = lerpf(_from_arm_len, arm_reach, k)
	_pin = lerpf(_from_pin, 0.0, k)
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
	_anim = Anim.NONE
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
	_settle_hold(k)
	_tip = _from_tip.lerp(windup_point, k)
	var pose := _thrust_pose(_tip, end_point)
	_blend_orientation(_from_blade, _from_edge, pose[0], pose[1], k)
	_twist = lerpf(_from_twist, _pose_twist(thrust.swing_windup, mirror) * thrust.twist_scale, k)
	_glow = fraction
	_refresh_color()
	_apply()


## While charging the iai (the charged draw slash): the hand and blade ease from where they are
## to the half-drawn pose (the blade slid out along the scabbard line, the hand at the front of the
## grip), the body stays turned, and the glow grows as the charge fills. Firing is the charged
## action's own short wind-up, which blends from this pose to 8:00 and then slashes.
func update_charge_iai(_iai: ActionData, charge_seconds: float, fraction: float) -> void:
	if _hand == null:
		return
	var front := _front_pos()
	var t := clampf(charge_seconds / maxf(charge_blend_time, 0.001), 0.0, 1.0)
	var k := ease(t, windup_ease)
	_tip = _from_tip.lerp(front, k)
	_arm_len = lerpf(_from_arm_len, (front - _shoulder()).length(), k)
	_pin = lerpf(_from_pin, 0.0, k)
	_twist = _from_twist
	_blend_orientation(_from_blade, _from_edge, _sheath_blade, _sheath_edge, k)
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
	_settle_hold(ease(clampf(time / maxf(windup_end, 0.001), 0.0, 1.0), windup_ease))
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
	_from_arm_len = _arm_len
	_from_pin = _pin
	_from_tip = _tip
	_from_blade = _blade_dir
	_from_edge = _edge_dir
	_from_twist = _twist


func _blend_orientation(from_blade: Vector3, from_edge: Vector3, to_blade: Vector3, to_edge: Vector3, t: float) -> void:
	_blade_dir = _blend_dir(from_blade, to_blade, t)
	# Nearly opposite edges (edge up in the scabbard, edge down at rest) roll around the blade
	# instead of snapping through the middle of a straight blend.
	if from_edge.dot(to_edge) < -0.2:
		_edge_dir = _roll_edge(from_edge, to_edge, _blade_dir, t)
	else:
		_edge_dir = _blend_dir(from_edge, to_edge, t)


## Rotate the edge from `from` toward `to` around the blade axis (t = 0 to 1).
func _roll_edge(from: Vector3, to: Vector3, axis: Vector3, t: float) -> Vector3:
	var a := from - axis * from.dot(axis)
	var b := to - axis * to.dot(axis)
	if a.length_squared() < 0.0001 or b.length_squared() < 0.0001:
		return _blend_dir(from, to, t)
	a = a.normalized()
	b = b.normalized()
	var angle := a.signed_angle_to(b, axis)
	# Exactly opposite: always roll the same way.
	if absf(angle) > PI - 0.05:
		angle = PI
	return a.rotated(axis, angle * t)


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
	if _flash > 0.0:
		_material.albedo_color = _flash_color
		_material.emission = _flash_color
		_material.emission_energy_multiplier = _flash * glow_energy
		return
	_material.emission = charge_color
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
	if _scabbard != null:
		_scabbard.rotation.y = yaw
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
	var arm_basis := Basis.looking_at(arm_dir, arm_up)
	_arm.basis = Basis(arm_basis.x, arm_basis.y, arm_basis.z * (_arm_len / maxf(arm_reach, 0.001)))
	var hand_end := _shoulder() + arm_dir * _arm_len
	var blade_dir := _blade_dir
	var edge_dir := _edge_dir
	var shift := Vector3.ZERO
	if _wobble_left > 0.0:
		# The guard flick: the blade swings about the vertical (and a little about the side axis),
		# and the hand is pushed back, then it rings out.
		var w := _wobble_value()
		var flick := Basis(Vector3.UP, w * _wobble_amp * _wobble_side) \
				* Basis(Vector3.RIGHT, -w * _wobble_amp * 0.5)
		blade_dir = flick * blade_dir
		edge_dir = flick * edge_dir
		shift = Vector3(0.0, 0.0, wobble_push * w)
	_hand.position = hand_end.lerp(_grip_pos(), _pin) + shift
	if _scabbard != null:
		_scabbard.position.y = -_drop
	var z := -blade_dir
	var x := edge_dir - blade_dir * edge_dir.dot(blade_dir)
	if x.length_squared() < 0.0001:
		x = blade_dir.cross(Vector3.UP)
	if x.length_squared() < 0.0001:
		x = blade_dir.cross(Vector3.RIGHT)
	x = x.normalized()
	var y := z.cross(x)
	_hand.basis = Basis(x, y, z)
	if hitbox != null:
		hitbox.transform = _hand.transform


## While the blade is still in the scabbard or in the hand, blend the arm length and the pin
## back to "hand holds the blade at arm's reach" as the wind-up progresses (k = 0 to 1).
func _settle_hold(k: float) -> void:
	_arm_len = lerpf(_from_arm_len, arm_reach, k)
	_pin = lerpf(_from_pin, 0.0, k)


## The grip point in the scabbard, lowered with the body when crouched.
func _grip_pos() -> Vector3:
	return _sheath_grip - Vector3(0.0, _drop, 0.0)


## Where the hand holds the blade just before it is drawn out or after it is slid in: the grip
## moved forward along the blade's own line.
func _front_pos() -> Vector3:
	return _grip_pos() - _sheath_blade * draw_slide_distance


## Where the arm points when it hangs relaxed at the side.
func _relaxed_aim() -> Vector3:
	return _shoulder() + relaxed_arm_direction.normalized() * arm_reach


## Run the draw or sheathe animation (R, auto-sheathe).
func _update_anim(delta: float) -> void:
	_anim_time += delta
	if _anim == Anim.GUARD:
		_update_guard()
		_apply()
		return
	if _anim == Anim.DRAW:
		var reach_t := clampf(_anim_time / maxf(draw_reach_time, 0.001), 0.0, 1.0)
		var pull_t := clampf((_anim_time - draw_reach_time) / maxf(draw_pull_time, 0.001), 0.0, 1.0)
		_draw_pose(reach_t, pull_t, _rest_tip, _rest_blade, _rest_edge)
		_twist = lerpf(_from_twist, 0.0, ease(pull_t, windup_ease))
		if pull_t >= 1.0:
			_anim = Anim.NONE
	else:
		var approach_t := clampf(_anim_time / maxf(sheathe_approach_time, 0.001), 0.0, 1.0)
		var slide_t := clampf((_anim_time - sheathe_approach_time) / maxf(sheathe_slide_time, 0.001), 0.0, 1.0)
		var release_t := clampf(
				(_anim_time - sheathe_approach_time - sheathe_slide_time) / maxf(sheathe_release_time, 0.001),
				0.0, 1.0)
		_sheathe_pose(approach_t, slide_t, release_t)
		if release_t >= 1.0:
			_anim = Anim.NONE
	_apply()


## The guard pose: from the scabbard a fast reach and pull into it, from a drawn sword a quick raise;
## then it is held (and flicks on a hit) until the Guard state ends.
func _update_guard() -> void:
	var tip := pose_to_point(guard_pose)
	var blade := guard_blade_direction.normalized()
	var edge := guard_edge_direction.normalized()
	if _guard_from_sheath:
		var reach_t := clampf(_anim_time / maxf(guard_draw_reach_time, 0.001), 0.0, 1.0)
		var pull_t := clampf((_anim_time - guard_draw_reach_time) / maxf(guard_draw_pull_time, 0.001), 0.0, 1.0)
		_draw_pose(reach_t, pull_t, tip, blade, edge)
		_twist = lerpf(_from_twist, 0.0, ease(pull_t, windup_ease))
		return
	var k := ease(clampf(_anim_time / maxf(guard_blend_time, 0.001), 0.0, 1.0), windup_ease)
	_tip = _from_tip.lerp(tip, k)
	_arm_len = lerpf(_from_arm_len, arm_reach, k)
	_pin = lerpf(_from_pin, 0.0, k)
	_twist = lerpf(_from_twist, 0.0, k)
	_blend_orientation(_from_blade, _from_edge, blade, edge, k)


## Drawing, from the captured pose to a target pose. reach_t (0 to 1): the arm swings from where it
## is to the grip. pull_t (0 to 1, only after the reach): the blade slides out along its own line,
## then swings away into the target (tip aim point, blade and edge directions).
func _draw_pose(reach_t: float, pull_t: float, to_tip: Vector3, to_blade: Vector3, to_edge: Vector3) -> void:
	var grip := _grip_pos()
	if pull_t <= 0.0:
		var k := ease(reach_t, windup_ease)
		_tip = _from_tip.lerp(grip, k)
		_arm_len = lerpf(_from_arm_len, (grip - _shoulder()).length(), k)
		_pin = lerpf(_from_pin, 1.0, k)
		_blend_orientation(_from_blade, _from_edge, _sheath_blade, _sheath_edge, k)
		return
	var front := _front_pos()
	_pin = 0.0
	if pull_t < draw_slide_fraction:
		var point := grip.lerp(front, ease(pull_t / draw_slide_fraction, 0.5))
		_tip = point
		_arm_len = (point - _shoulder()).length()
		_blade_dir = _sheath_blade
		_edge_dir = _sheath_edge
	else:
		var u := ease((pull_t - draw_slide_fraction) / maxf(1.0 - draw_slide_fraction, 0.001), windup_ease)
		_tip = front.lerp(to_tip, u)
		_arm_len = lerpf((front - _shoulder()).length(), arm_reach, u)
		_blend_orientation(_sheath_blade, _sheath_edge, to_blade, to_edge, u)


## Sheathing, in three parts: approach (the sword comes to the scabbard mouth), slide (the blade
## goes in), release (the hand lets go and the arm relaxes down).
func _sheathe_pose(approach_t: float, slide_t: float, release_t: float) -> void:
	var grip := _grip_pos()
	if slide_t <= 0.0:
		var front := _front_pos()
		var k := ease(approach_t, windup_ease)
		_tip = _from_tip.lerp(front, k)
		_arm_len = lerpf(_from_arm_len, (front - _shoulder()).length(), k)
		_pin = lerpf(_from_pin, 0.0, k)
		_twist = lerpf(_from_twist, 0.0, k)
		_blend_orientation(_from_blade, _from_edge, _sheath_blade, _sheath_edge, k)
		return
	_twist = 0.0
	_blade_dir = _sheath_blade
	_edge_dir = _sheath_edge
	if release_t <= 0.0:
		var point := _front_pos().lerp(grip, ease(slide_t, windup_ease))
		_tip = point
		_arm_len = (point - _shoulder()).length()
		_pin = 0.0
		return
	var u := ease(release_t, windup_ease)
	_tip = grip.lerp(_relaxed_aim(), u)
	_arm_len = lerpf((grip - _shoulder()).length(), arm_reach, u)
	_pin = 1.0


## The draw slash's wind-up: the hand reaches the grip, then pulls the blade out and swings it
## to the wind-up pose (8:00). The body twist only starts with the pull, so the hand meets the grip.
func _update_draw_windup(action: ActionData, time: float, windup_point: Vector3, end_point: Vector3) -> void:
	var t := clampf(time / maxf(action.active_hit.x, 0.001), 0.0, 1.0)
	var travel := _slash_tangent(windup_point, end_point, 0.0)
	var target := _pose(windup_point, travel, wrist_start_angle)
	if t < draw_reach_share:
		_draw_pose(t / draw_reach_share, 0.0, windup_point, target[0], target[1])
		_twist = _from_twist
	else:
		var p := (t - draw_reach_share) / maxf(1.0 - draw_reach_share, 0.001)
		_draw_pose(1.0, p, windup_point, target[0], target[1])
		_twist = lerpf(_from_twist, _pose_twist(action.swing_windup), ease(p, windup_ease))
	_set_active(false)


## A plain box scabbard along the sheathed blade, under Visual next to the nose. It turns with
## the body twist and lowers with the body when crouched.
func _build_scabbard(weapon: WeaponData) -> void:
	if _scabbard != null:
		_scabbard.queue_free()
		_scabbard = null
	var parent := get_parent()
	if parent == null:
		return
	var start := 0.1
	var finish := weapon.blade_length + 0.05
	var mesh := BoxMesh.new()
	mesh.size = Vector3(weapon.blade_thickness * 1.6, 0.05, finish - start)
	var material := StandardMaterial3D.new()
	material.albedo_color = scabbard_color
	var box := MeshInstance3D.new()
	box.mesh = mesh
	box.material_override = material
	var z := -_sheath_blade
	var x := _sheath_edge - _sheath_blade * _sheath_edge.dot(_sheath_blade)
	if x.length_squared() < 0.0001:
		x = _sheath_blade.cross(Vector3.UP)
	x = x.normalized()
	var y := z.cross(x)
	box.transform = Transform3D(Basis(x, y, z), _sheath_grip + _sheath_blade * (start + finish) * 0.5)
	_scabbard = Node3D.new()
	_scabbard.name = "Scabbard"
	_scabbard.add_child(box)
	parent.add_child(_scabbard)
