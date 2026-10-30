class_name FigureFeet
extends RefCounted
## PLACEHOLDER(own code, ER skeleton): foot placement for the mannequin (Phase 3d-2, docs/placeholders.md P5). The clips are
## forward kinematics (every joint position per frame); this is an inverse kinematics layer on top of the pose of the frame:
## - The owner (`PlayerFigure`) probes the ground under each foot with a ray (`set_ground()`, once per physics frame): how far
##   above or below the body's own floor the surface is, in metres. Stairs, slopes and curbs show up here.
## - The pelvis follows the LOWER foot (`pelvis_offset()`, metres; the figure node moves by it), so the lower foot needs no
##   stretch, and each leg then reaches its foot with a two-bone solve (hip, knee, ankle) that keeps the clip's own knee direction.
## - Only the height of a foot is fitted, never its sideways position, so a clip's steps and rolls keep their motion; a foot in
##   mid-swing keeps its clip height above the ground under it.
## - Offsets ease (`FOOT_SMOOTH`, `PELVIS_SMOOTH`) so the figure does not pop on a step edge, and the whole layer fades in and out
##   (`FADE_TIME`) when it is switched on or off (airborne, lying, F1 switch). It knows nothing of gameplay.

## The ground a foot ray looks for: this far above and below the body's floor (metres, a placeholder).
const STEP_UP: float = 0.5
const STEP_DOWN: float = 0.5
## Seconds a foot's ground height eases over, the pelvis's, and the layer's own fade.
const FOOT_SMOOTH: float = 0.06
const PELVIS_SMOOTH: float = 0.1
const FADE_TIME: float = 0.12
## A change smaller than this (metres) does not ask for a new pose.
const EPSILON: float = 0.001

const LEFT: int = 0
const RIGHT: int = 1

var _thigh: PackedInt32Array = PackedInt32Array([-1, -1])
var _calf: PackedInt32Array = PackedInt32Array([-1, -1])
var _foot: PackedInt32Array = PackedInt32Array([-1, -1])
var _toe: PackedInt32Array = PackedInt32Array([-1, -1])
## The ground offset each foot probed (metres relative to the body's floor), and the eased value.
var _target: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _smooth: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
var _pelvis: float = 0.0
var _weight: float = 0.0
## What the last shown pose used, to tell whether a new pose is needed.
var _applied: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var ready_to_use: bool = false


func _init(clips: PlaceholderClips) -> void:
	var names: Array[String] = ["L", "R"]
	ready_to_use = true
	for side in 2:
		_thigh[side] = clips.joint_index(names[side] + "_Thigh")
		_calf[side] = clips.joint_index(names[side] + "_Calf")
		_foot[side] = clips.joint_index(names[side] + "_Foot")
		_toe[side] = clips.joint_index(names[side] + "_Toe0")
		if _thigh[side] < 0 or _calf[side] < 0 or _foot[side] < 0 or _toe[side] < 0:
			ready_to_use = false


## The joints that mark where a foot stands (its ankle and its toe), so the owner can aim the ray between them.
func foot_joints(side: int) -> Vector2i:
	return Vector2i(_foot[side], _toe[side])


## The ground under `side`'s foot, metres above (+) or below (-) the body's floor; `NAN` = no ground found (neutral).
func set_ground(side: int, offset: float) -> void:
	_target[side] = 0.0 if is_nan(offset) else clampf(offset, -STEP_DOWN, STEP_UP)


## Once per rendered frame. `active` = the figure stands on the ground and may be fitted; otherwise the layer fades out.
## Returns true when the shown pose or the pelvis must be redrawn.
func step(delta: float, active: bool) -> bool:
	_weight = move_toward(_weight, 1.0 if active else 0.0, delta / FADE_TIME)
	var foot_k: float = 1.0 - exp(-delta / FOOT_SMOOTH)
	for side in 2:
		_smooth[side] = lerpf(_smooth[side], _target[side], foot_k)
	var pelvis_goal: float = minf(_smooth[LEFT], _smooth[RIGHT])
	_pelvis = lerpf(_pelvis, pelvis_goal, 1.0 - exp(-delta / PELVIS_SMOOTH))
	var now: PackedFloat32Array = PackedFloat32Array([_smooth[LEFT] * _weight, _smooth[RIGHT] * _weight, _pelvis * _weight, _weight])
	var changed: bool = false
	for i in 4:
		if absf(now[i] - _applied[i]) > EPSILON:
			changed = true
	if changed:
		_applied = now
	return changed


## How far the whole figure moves in height (metres): the pelvis follows the lower foot.
func pelvis_offset() -> float:
	return _pelvis * _weight


## True while the layer has any effect (the pose needs the leg solve).
func is_active() -> bool:
	return _weight > 0.001


## `pose` with both legs reaching their feet's ground. `scale_y` is the figure's scale (the pose is in the clips' own metres).
## Returns `pose` itself when there is nothing to do, otherwise a new pose (the joints of the legs changed, the rest shared).
func apply(pose: PlaceholderClips.Pose, scale_y: float) -> PlaceholderClips.Pose:
	if pose == null or not ready_to_use or _weight <= 0.001:
		return pose
	var out := PlaceholderClips.Pose.new()
	out.points = pose.points.duplicate()
	out.axes = pose.axes
	for side in 2:
		var delta: float = (_smooth[side] - _pelvis) * _weight / maxf(scale_y, 0.01)
		if absf(delta) > 0.0002:
			_solve_leg(out, side, delta)
	return out


## Move the ankle up by `delta` (the clips' metres) and bend the knee to keep the bones' lengths, in the direction the clip's
## own knee points; the toe rides along with the ankle.
func _solve_leg(pose: PlaceholderClips.Pose, side: int, delta: float) -> void:
	var points: PackedVector3Array = pose.points
	var hip: Vector3 = points[_thigh[side]]
	var knee: Vector3 = points[_calf[side]]
	var ankle: Vector3 = points[_foot[side]]
	var upper: float = hip.distance_to(knee)
	var lower: float = knee.distance_to(ankle)
	var to: Vector3 = ankle + Vector3(0.0, delta, 0.0) - hip
	var dist: float = to.length()
	if dist < 0.001 or upper < 0.001 or lower < 0.001:
		return
	dist = clampf(dist, absf(upper - lower) + 0.001, (upper + lower) * 0.999)
	var dir: Vector3 = to / to.length()
	# The knee bends the way the clip bends it: its offset from the hip-to-ankle line.
	var rest: Vector3 = ankle - hip
	var rest_dir: Vector3 = rest.normalized() if rest.length() > 0.001 else Vector3.DOWN
	var bend: Vector3 = (knee - hip) - rest_dir * (knee - hip).dot(rest_dir)
	if bend.length_squared() < 0.00001:
		var forward: Vector3 = points[_toe[side]] - ankle  # a straight leg: the knee goes the way the foot points
		bend = Vector3(forward.x, 0.0, forward.z)
	bend -= dir * bend.dot(dir)
	bend = bend.normalized() if bend.length_squared() > 0.00001 else Vector3.FORWARD
	var along: float = (upper * upper - lower * lower + dist * dist) / (2.0 * dist)
	var height: float = sqrt(maxf(upper * upper - along * along, 0.0))
	var new_knee: Vector3 = hip + dir * along + bend * height
	var new_ankle: Vector3 = hip + dir * dist
	var shift: Vector3 = new_ankle - ankle
	pose.points[_calf[side]] = new_knee
	pose.points[_foot[side]] = new_ankle
	pose.points[_toe[side]] = pose.points[_toe[side]] + shift
