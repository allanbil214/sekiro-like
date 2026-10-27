class_name PlayerFigure
extends MannequinFigure
## PLACEHOLDER(own code, ER skeleton): the mannequin on the player (Phase 3a-3b-1, docs/placeholders.md P5). It replaces the
## capsule `Body` and the box `Nose` while shown. It only HOLDS poses of the converted clips: `idle` standing and
## `crouch_idle` crouched, blended over the crouch time; no clip plays (that is 3a-3c). It sits under `Visual`, so the hit
## wobble, the lean and the kneel of `PlayerBodyReaction` move it with everything else, and `SwordVisual` turns it by the
## body twist. The code-drawn sword is still used (the figure's blade is hidden).
## 3a-3b-2: its arms follow the hands the code-drawn arms compute (`SwordVisual` for the right arm, `HealArm` for the left
## while healing, `ReachArms` for both while they show), and those box arms are hidden while the figure is shown.
## The collision capsule and the hurtbox are never touched. If the clip file is missing, `available` stays false and the
## Player keeps the capsule.

## PLACEHOLDER: how far (fraction of the arm's length) the bones may stretch to reach a hand target.
@export var max_stretch: float = 0.25
## Which way the right elbow bends (figure space: +X right, -Y down, +Z back); the left arm mirrors X.
@export var elbow_pole: Vector3 = Vector3(0.5, -1.0, 0.3)

const STAND_CLIP: String = "idle"
const CROUCH_CLIP: String = "crouch_idle"

## True once the clips are loaded and the figure can be shown.
var available: bool = false
## 0 = standing pose, 1 = crouched pose (tweened by `set_crouched()`).
var crouch_blend: float = 0.0:
	set(value):
		crouch_blend = value
		_refresh()

var _stand: PlaceholderClips.Pose
var _crouch: PlaceholderClips.Pose
var _tween: Tween
var _sword: SwordVisual
var _heal: HealArm
var _reach: ReachArms
var _right: String = "R"
var _left: String = "L"
var _arms_driven: bool = false


func _ready() -> void:
	# After the other visuals have moved their hands this frame.
	process_priority = 100
	var clips := PlaceholderClips.shared()
	if clips == null or not clips.has_clip(STAND_CLIP) or not clips.has_clip(CROUCH_CLIP):
		visible = false
		return
	show_blade = false
	setup(clips)
	_stand = clips.sample(STAND_CLIP, 0.0)
	_crouch = clips.sample(CROUCH_CLIP, 0.0)
	# Which side of the figure is the right arm (+X): the file's names should say, but check.
	var right_x: float = _stand.points[clips.joint_index("R_UpperArm")].x
	var left_x: float = _stand.points[clips.joint_index("L_UpperArm")].x
	if right_x < left_x:
		_right = "L"
		_left = "R"
	available = true
	_refresh()


## Called once by the Player: the sources of the hands the arms follow.
func bind_arms(sword: SwordVisual, heal: HealArm, reach: ReachArms) -> void:
	_sword = sword
	_heal = heal
	_reach = reach


func _process(_delta: float) -> void:
	if not available or not visible:
		return
	var has_right: bool = false
	var has_left: bool = false
	var right_hand: Vector3 = Vector3.ZERO
	var left_hand: Vector3 = Vector3.ZERO
	if _reach != null and _reach.visible:
		has_right = true
		has_left = true
		right_hand = _reach.get_hand_global(1)
		left_hand = _reach.get_hand_global(0)
	else:
		if _sword != null:
			has_right = true
			right_hand = _sword.get_hand_global()
		if _heal != null and _heal.visible:
			has_left = true
			left_hand = _heal.get_hand_global()
	var driven: bool = has_right or has_left
	if driven or _arms_driven:
		_refresh()  # back to the held pose, then bend the driven arms
	_arms_driven = driven
	if has_right:
		solve_arm(_right, to_local(right_hand), elbow_pole, max_stretch)
	if has_left:
		solve_arm(_left, to_local(left_hand), Vector3(-elbow_pole.x, elbow_pole.y, elbow_pole.z), max_stretch)


## Scale the figure evenly so the top of its head is at `height` and its lowest point is on the feet line.
func fit_to_height(height: float) -> void:
	if not available:
		return
	var top: float = _stand.points[_head_joint].y + 0.07 + HEAD_RADIUS
	var lowest: float = INF
	for point: Vector3 in _stand.points:
		lowest = minf(lowest, point.y)
	var factor: float = height / maxf(top - lowest, 0.1)
	scale = Vector3.ONE * factor
	position.y = -lowest * factor


## Ease between the standing and the crouched pose over `time` seconds (instantly when 0).
func set_crouched(crouched: bool, time: float) -> void:
	if _tween != null:
		_tween.kill()
	var goal: float = 1.0 if crouched else 0.0
	if not available or time <= 0.0:
		crouch_blend = goal
		return
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "crouch_blend", goal, time)


func _refresh() -> void:
	if not available:
		return
	if crouch_blend <= 0.0:
		show_pose(_stand)
	elif crouch_blend >= 1.0:
		show_pose(_crouch)
	else:
		show_pose(_blend(_stand, _crouch, crouch_blend))


static func _blend(a: PlaceholderClips.Pose, b: PlaceholderClips.Pose, weight: float) -> PlaceholderClips.Pose:
	var pose := PlaceholderClips.Pose.new()
	pose.points.resize(a.points.size())
	for i in a.points.size():
		pose.points[i] = a.points[i].lerp(b.points[i], weight)
	pose.axes.resize(a.axes.size())
	for i in a.axes.size():
		pose.axes[i] = a.axes[i].lerp(b.axes[i], weight).normalized()
	return pose
