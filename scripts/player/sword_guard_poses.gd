class_name SwordGuardPoses
extends RefCounted
## The deflect poses (Step 7d) and the guard-break pose of the placeholder sword (Phase 1.5, item 5a),
## moved out of SwordVisual. It keeps the state of the two overlays (which pose, its timer, its stored
## tip, blade and edge) and the timing curve; it owns no settings: the tuned exports (deflect_*, break_*,
## debug_force_deflect) stay on the SwordVisual, which also applies the blended pose to its own _tip,
## _blade_dir and _edge_dir. Placeholder code: real animations will replace it.

const NONE: float = -1.0

var visual: SwordVisual

var deflect_kind: int = -1
var deflect_time: float = 0.0
var deflect_tip: Vector3 = Vector3.ZERO
var deflect_blade: Vector3 = Vector3.ZERO
var deflect_edge: Vector3 = Vector3.ZERO

var break_time: float = -1.0
var break_tip: Vector3 = Vector3.ZERO
var break_blade: Vector3 = Vector3.ZERO
var break_edge: Vector3 = Vector3.ZERO


func _init(owner_visual: SwordVisual) -> void:
	visual = owner_visual


# --- Deflect ----------------------------------------------------------------------------------

## A deflect met the attack: pick a pose from the attack (side, high, low, or the thrust's slap), aimed
## partly at where it connected, and store it. Returns the kind. side > 0 = the attacker is on the right.
func start_deflect(hit: HitData, side: float) -> int:
	var kind := _deflect_kind_for(hit)
	var pose := visual.deflect_side_pose
	var blade := visual.deflect_side_blade
	var edge := visual.deflect_side_edge
	var mirror := false
	match kind:
		SwordVisual.DeflectKind.HIGH:
			pose = visual.deflect_high_pose
			blade = visual.deflect_high_blade
			edge = visual.deflect_high_edge
		SwordVisual.DeflectKind.LOW:
			pose = visual.deflect_low_pose
			blade = visual.deflect_low_blade
			edge = visual.deflect_low_edge
		SwordVisual.DeflectKind.THRUST:
			pose = visual.deflect_thrust_pose
			blade = visual.deflect_thrust_blade
			edge = visual.deflect_thrust_edge
		_:
			if side < 0.0:
				mirror = true
				blade.x = -blade.x
				edge.x = -edge.x
	var tip := visual.pose_to_point(pose, mirror)
	if hit != null and hit.point != Vector3.ZERO and visual.deflect_aim_follow > 0.0:
		# Turn the aim part of the way toward the contact point, so the blade meets it where it landed.
		var shoulder := visual.get_shoulder()
		var to_pose := tip - shoulder
		var to_contact := visual.to_local(hit.point) - shoulder
		if to_pose.length_squared() > 0.0001 and to_contact.length_squared() > 0.0001:
			var aim := to_pose.normalized().lerp(to_contact.normalized(), visual.deflect_aim_follow)
			if aim.length_squared() > 0.0001:
				tip = shoulder + aim.normalized() * to_pose.length()
	deflect_kind = kind
	deflect_time = 0.0
	deflect_tip = tip
	deflect_blade = blade.normalized()
	deflect_edge = edge.normalized()
	return kind


## Which pose answers this hit: the thrust's slap for a charged thrust, else high, low, or side from
## the height of the contact point.
func _deflect_kind_for(hit: HitData) -> int:
	if visual.debug_force_deflect > 0:
		return visual.debug_force_deflect - 1
	if hit != null and hit.action != null \
			and (hit.action.charge_time > 0.0 or hit.action.kind == ActionData.Kind.PERILOUS_THRUST):
		return SwordVisual.DeflectKind.THRUST
	if hit != null and hit.point != Vector3.ZERO:
		var centre := visual.center_height - visual.get_drop()
		var y := visual.to_local(hit.point).y
		if y > centre + visual.deflect_high_above:
			return SwordVisual.DeflectKind.HIGH
		if y < centre - visual.deflect_low_below:
			return SwordVisual.DeflectKind.LOW
	return SwordVisual.DeflectKind.SIDE


func cancel_deflect() -> void:
	deflect_kind = -1


## Run the deflect timer (called every frame an animation runs); the pose ends after snap, hold and return.
func advance_deflect(delta: float) -> void:
	if deflect_kind >= 0:
		deflect_time += delta
		if deflect_time >= visual.deflect_snap_time + visual.deflect_hold_time + visual.deflect_return_time:
			deflect_kind = -1


## How far the guard pose is blended toward the deflect pose (0 to 1: snap in, hold, ease out), or NONE
## when no deflect is playing.
func deflect_weight() -> float:
	if deflect_kind < 0:
		return NONE
	var t := deflect_time
	var w := 1.0
	if t < visual.deflect_snap_time:
		w = ease(clampf(t / maxf(visual.deflect_snap_time, 0.001), 0.0, 1.0), visual.windup_ease)
	elif t > visual.deflect_snap_time + visual.deflect_hold_time:
		w = 1.0 - ease(clampf((t - visual.deflect_snap_time - visual.deflect_hold_time)
				/ maxf(visual.deflect_return_time, 0.001), 0.0, 1.0), visual.windup_ease)
	return w


# --- Guard break ------------------------------------------------------------------------------

## The guard broke: store the knocked-aside pose (mirrored for an attacker on the left) and start its
## timer. side > 0 = the attacker is on the right.
func start_break(side: float) -> void:
	var mirror := side < 0.0
	var blade := visual.break_blade
	var edge := visual.break_edge
	if mirror:
		blade.x = -blade.x
		edge.x = -edge.x
	break_time = 0.0
	break_tip = visual.pose_to_point(visual.break_pose, mirror)
	break_blade = blade.normalized()
	break_edge = edge.normalized()


func cancel_break() -> void:
	break_time = -1.0


func break_active() -> bool:
	return break_time >= 0.0


## Run the break timer and return how far the current pose is blended toward the knocked-aside pose
## (snap in, hold, ease out), or NONE when no break is playing or it ended this frame.
func advance_break(delta: float) -> float:
	if break_time < 0.0:
		return NONE
	break_time += delta
	var total := visual.break_snap_time + visual.break_hold_time + visual.break_return_time
	if break_time >= total:
		break_time = -1.0
		return NONE
	var w := 1.0
	if break_time < visual.break_snap_time:
		w = ease(clampf(break_time / maxf(visual.break_snap_time, 0.001), 0.0, 1.0), visual.windup_ease)
	elif break_time > visual.break_snap_time + visual.break_hold_time:
		w = 1.0 - ease(clampf((break_time - visual.break_snap_time - visual.break_hold_time)
				/ maxf(visual.break_return_time, 0.001), 0.0, 1.0), visual.windup_ease)
	return w
