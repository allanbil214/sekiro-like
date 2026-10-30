class_name FigureUpperLayer
extends RefCounted
## PLACEHOLDER(ER clip, made-up pose): the upper-body layers of the mannequin (Phase 3c-4c, docs/placeholders.md P2 and P4). A layer
## changes only the joints above the pelvis of the base pose (the locomotion pose, so the legs keep walking, running and
## crouching) and fades in and out on its own, separately from the legs:
## - GUARD: the sandbox's one-handed guard stance (`guard_stance`, `a000_000100`), looped, shifted so its pelvis sits on the base
##   pose's pelvis. The right arm is still driven by the code-drawn sword (the figure's arm solve), so the deflect poses stay.
## - CARRY: a made-up pose (no carry clip exists in the sandbox): the upper body leans a little away from the shoulder the body
##   rests on, and both hands go up to hold it (a two-bone solve on the pose's own arm joints).
## `PlayerFigure` owns one, tells it the base pose and the weight, and shows the result. It knows nothing of gameplay.

enum Kind { NONE, GUARD, CARRY }

const GUARD_CLIP: String = "guard_stance"

## Carry pose tuning (figure space: +X right, +Y up, -Z forward, in the clips' own metres). The hands are given relative to
## the chest (`Spine2`); the lean is degrees toward the left, about the pelvis. Set by the figure each frame from its exports.
var carry_right_hand: Vector3 = Vector3(0.2, 0.05, -0.17)
var carry_left_hand: Vector3 = Vector3(0.1, -0.12, -0.22)
var carry_lean_degrees: float = 6.0
var carry_right_pole: Vector3 = Vector3(0.7, -0.8, 0.3)
var carry_left_pole: Vector3 = Vector3(-0.7, -0.8, 0.3)

var _clips: PlaceholderClips
var _lower: PackedByteArray = PackedByteArray()
var _pelvis: int = -1
var _chest: int = -1
## prefix ("L" or "R") -> [shoulder index, elbow index, hand index].
var _arms: Dictionary = {}
## prefix -> the joints that ride along with the hand (weapon point and fingers).
var _hand_followers: Dictionary = {}


func _init(clips: PlaceholderClips) -> void:
	_clips = clips
	_pelvis = clips.joint_index("Pelvis")
	_chest = clips.joint_index("Spine2")
	_lower.resize(clips.joint_names.size())
	for i in clips.joint_names.size():
		var joint: String = clips.joint_names[i]
		var is_lower: bool = joint == "Pelvis" or joint.contains("Thigh") or joint.contains("Calf") \
				or joint.contains("Foot") or joint.contains("Toe")
		_lower[i] = 1 if is_lower else 0
	for prefix: String in ["L", "R"]:
		_arms[prefix] = [clips.joint_index(prefix + "_UpperArm"), clips.joint_index(prefix + "_Forearm"), clips.joint_index(prefix + "_Hand")]
		var followers: Array[int] = []
		for i in clips.joint_names.size():
			var joint: String = clips.joint_names[i]
			if joint.begins_with(prefix + "_Finger") or joint == prefix + "_Weapon":
				followers.append(i)
		_hand_followers[prefix] = followers


## True when the library has what the layers need (the guard clip may be missing from an old file: then only carry works).
func has_guard() -> bool:
	return _clips.has_clip(GUARD_CLIP)


## The base pose with the guard stance's upper body, looped at `time` seconds. Not blended yet (see `blend()`).
func guard_pose(under: PlaceholderClips.Pose, time: float) -> PlaceholderClips.Pose:
	var guard: PlaceholderClips.Pose = _clips.sample_loop(GUARD_CLIP, time)
	if guard == null:
		return under
	var shift: Vector3 = under.points[_pelvis] - guard.points[_pelvis]
	var pose := PlaceholderClips.Pose.new()
	pose.points = under.points.duplicate()
	pose.axes = guard.axes.duplicate()
	for i in pose.points.size():
		if _lower[i] == 0:
			pose.points[i] = guard.points[i] + shift
	return pose


## The base pose with a made-up carrying upper body: a lean, then both hands reaching up to the carried body.
func carry_pose(under: PlaceholderClips.Pose) -> PlaceholderClips.Pose:
	var pose := PlaceholderClips.Pose.new()
	pose.points = under.points.duplicate()
	pose.axes = under.axes.duplicate()
	var pelvis: Vector3 = under.points[_pelvis]
	var lean := Basis(Vector3.BACK, deg_to_rad(carry_lean_degrees))
	for i in pose.points.size():
		if _lower[i] == 0:
			pose.points[i] = pelvis + lean * (under.points[i] - pelvis)
	var chest: Vector3 = pose.points[_chest]
	_reach(pose, "R", chest + carry_right_hand, carry_right_pole)
	_reach(pose, "L", chest + carry_left_hand, carry_left_pole)
	return pose


## `under` with the joints above the pelvis moved `weight` of the way to `layer` (the legs and the pelvis stay).
func blend(under: PlaceholderClips.Pose, layer: PlaceholderClips.Pose, weight: float) -> PlaceholderClips.Pose:
	var pose := PlaceholderClips.Pose.new()
	pose.points = under.points.duplicate()
	for i in pose.points.size():
		if _lower[i] == 0:
			pose.points[i] = under.points[i].lerp(layer.points[i], weight)
	pose.axes.resize(under.axes.size())
	for i in under.axes.size():
		pose.axes[i] = under.axes[i].lerp(layer.axes[i], weight).normalized()
	return pose


## A two-bone solve on the pose's own arm joints: the hand goes to `target` (or as near as the arm reaches), the elbow bends
## toward `pole`; the weapon point and the fingers move with the hand.
func _reach(pose: PlaceholderClips.Pose, prefix: String, target: Vector3, pole: Vector3) -> void:
	var joints: Array = _arms[prefix]
	var shoulder: Vector3 = pose.points[joints[0]]
	var elbow_rest: Vector3 = pose.points[joints[1]]
	var hand_rest: Vector3 = pose.points[joints[2]]
	var upper: float = shoulder.distance_to(elbow_rest)
	var fore: float = elbow_rest.distance_to(hand_rest)
	var to: Vector3 = target - shoulder
	var dist: float = to.length()
	if dist < 0.001 or upper + fore < 0.001:
		return
	var dir: Vector3 = to / dist
	dist = clampf(dist, absf(upper - fore) + 0.001, (upper + fore) * 0.999)
	var along: float = (upper * upper - fore * fore + dist * dist) / (2.0 * dist)
	var height: float = sqrt(maxf(upper * upper - along * along, 0.0))
	var bend: Vector3 = pole - dir * pole.dot(dir)
	bend = bend.normalized() if bend.length() > 0.0001 else Vector3.DOWN
	var hand: Vector3 = shoulder + dir * dist
	pose.points[joints[1]] = shoulder + dir * along + bend * height
	pose.points[joints[2]] = hand
	var moved: Vector3 = hand - hand_rest
	for index: int in _hand_followers[prefix]:
		pose.points[index] += moved
