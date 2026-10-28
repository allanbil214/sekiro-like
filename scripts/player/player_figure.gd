class_name PlayerFigure
extends MannequinFigure
## PLACEHOLDER(own code, ER skeleton): the mannequin on the player (Phase 3a-3b-1, docs/placeholders.md P5). It replaces the
## capsule `Body` and the box `Nose` while shown. It HOLDS poses of the converted clips: `idle` standing and
## `crouch_idle` crouched, blended over the crouch time (3a-3b-1), and PLAYS an action's clip (3a-3c, below). It sits under `Visual`, so the hit
## wobble, the lean and the kneel of `PlayerBodyReaction` move it with everything else, and `SwordVisual` turns it by the
## body twist. The code-drawn sword is still used (the figure's blade is hidden).
## 3a-3b-2: its arms follow the hands the code-drawn arms compute (`SwordVisual` for the right arm, `HealArm` for the left
## while healing, `ReachArms` for both while they show), and those box arms are hidden while the figure is shown.
## 3a-3c: while an action with a `placeholder_clip` runs, `drive_clip()` (called by `ActionState` every physics frame)
## makes the figure play that clip, stretched evenly to the action's duration. The clip drives the whole figure, arms and
## blade included: the code-drawn blade is hidden and the figure's own blade shown, the arm solving and the body twist
## pause, and the figure blends in from and back out to the held pose (`blend_in`, `blend_out`). The hitbox, the trail
## and the clock are untouched. F1 "Clips drive the figure" (`clips_enabled`) turns it off.
## 3a-3c-2: a clip name ending in ":upper" (`combo_1:upper`) plays only the clip's upper body: every joint above the pelvis
## comes from the clip, shifted so the clip's pelvis sits on the held pose's pelvis, and the legs and the pelvis keep the
## held pose (the air attacks use it: idle legs, the swing of a ground attack). The hitbox follows the same shifted blade.
## The collision capsule and the hurtbox are never touched. If the clip file is missing, `available` stays false and the
## Player keeps the capsule.
## 3c-2a: the held pose is no longer only a pose. While the owner reports it walking (`drive_locomotion()`, once per physics
## frame, by the Player and the Enemy) the base layer is a `FigureLocomotion` pose: idle, walk, run, sprint and crouch clips
## at the real speed. Action clips blend over it as before, from and back to it. While the owner does not report (dead,
## held, in the air...) or the F1 switch `locomotion_enabled` is off, the base layer fades back to the held stand or crouch
## pose. The right arm follows the base layer while the sword is sheathed (`right_arm_free`) instead of hanging on the
## code-drawn hand; the left arm follows it unless healing or reaching.

## PLACEHOLDER: how far (fraction of the arm's length) the bones may stretch to reach a hand target.
@export var max_stretch: float = 0.25
## Which way the right elbow bends (figure space: +X right, -Y down, +Z back); the left arm mirrors X.
@export var elbow_pole: Vector3 = Vector3(0.5, -1.0, 0.3)

## PLACEHOLDER: seconds to blend from the held pose into a clip, and from the clip back to the held pose.
@export var blend_in: float = 0.1
@export var blend_out: float = 0.12

## The F1 switch (3a-3c): false = no clip plays, the figure holds its pose and the code sword is drawn.
static var clips_enabled: bool = true
## The F1 switch (3c-2a): false = no locomotion clips, the figure holds its idle or crouch pose out of actions.
static var locomotion_enabled: bool = true
static var _loco_warned: bool = false

const STAND_CLIP: String = "idle"
const CROUCH_CLIP: String = "crouch_idle"
## The suffix of a clip name that plays the upper body only.
const UPPER_SUFFIX: String = ":upper"
## 3c-2a: seconds to fade between the held pose and the locomotion pose, and for the sheathed right arm between the pose's
## hand and the code-drawn hand.
const LOCO_BLEND: float = 0.15
const ARM_BLEND: float = 0.12

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
# 3a-3c: the clip being played.
var _clip_action: ActionData
var _clip_name: String = ""
# 3a-3c-2: the playing clip is upper-body only; which joints are legs or pelvis (held) and where the pelvis is.
var _clip_upper: bool = false
var _lower: PackedByteArray = PackedByteArray()
var _pelvis: int = -1
var _clip_length: float = 0.0
# 3a-3c-3: the part of the clip that plays (seconds into it): progress 0 is `_clip_from`, progress 1 is `_clip_to`.
var _clip_from: float = 0.0
var _clip_to: float = 0.0
## Progress through the played part (0 to 1) and how fast it advances (per second).
var _clip_p: float = 0.0
var _clip_prate: float = 0.0
var _since_tick: float = 0.0
var _playing: bool = false
var _was_clip: bool = false
var _blade_swapped: bool = false
## 0 = the held pose, 1 = the clip (ramps over `blend_in` and `blend_out`).
var _mix: float = 0.0
var _clip_pose: PlaceholderClips.Pose
## When a clip starts while another is showing: the pose it fades away from (1 -> 0 over `blend_in`).
var _xfade_from: PlaceholderClips.Pose
var _xfade: float = 0.0
var _warned: Dictionary = {}
# 3c-2a: the locomotion layer.
var _loco: FigureLocomotion
## The physics frame of the last `drive_locomotion()`; the layer is off when it was more than two frames ago.
var _loco_frame: int = -100
var _loco_wanted: bool = false
var _loco_mix: float = 0.0
var _base_pose: PlaceholderClips.Pose
var _was_loco: bool = false
var _right_free: bool = false
var _right_follow: float = 0.0


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
	var missing: String = FigureLocomotion.missing_clip(clips)
	if missing.is_empty():
		_loco = FigureLocomotion.new(clips)
	elif not _loco_warned:
		_loco_warned = true
		push_warning("[PlayerFigure] locomotion clip '%s' is missing: no locomotion clips (run tools/placeholder/convert_clips.py)" % missing)
	_pelvis = clips.joint_index("Pelvis")
	_lower.resize(clips.joint_names.size())
	for i in clips.joint_names.size():
		var joint: String = clips.joint_names[i]
		var is_lower: bool = joint == "Pelvis" or joint.contains("Thigh") or joint.contains("Calf") \
				or joint.contains("Foot") or joint.contains("Toe")
		_lower[i] = 1 if is_lower else 0
	# Which side of the figure is the right arm (+X): the file's names should say, but check.
	var right_x: float = _stand.points[clips.joint_index("R_UpperArm")].x
	var left_x: float = _stand.points[clips.joint_index("L_UpperArm")].x
	if right_x < left_x:
		_right = "L"
		_left = "R"
	available = true
	visibility_changed.connect(_on_visibility_changed)
	_refresh()


## Called once by the Player: the sources of the hands the arms follow.
func bind_arms(sword: SwordVisual, heal: HealArm, reach: ReachArms) -> void:
	_sword = sword
	_heal = heal
	_reach = reach


func _process(delta: float) -> void:
	if not available or not visible:
		return
	delta *= Hitstop.fighter_scale(owner)  # 3c-1: the clip's blends and its step between physics frames follow the fighter's freeze
	_update_locomotion(delta)
	var clip_active: bool = _playing or _mix > 0.0
	if clip_active:
		_step_clip(delta)
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
		if _sword != null and _right_follow < 1.0:
			has_right = true
			right_hand = _sword.get_hand_global()
		if _heal != null and _heal.visible:
			has_left = true
			left_hand = _heal.get_hand_global()
	var driven: bool = has_right or has_left
	var loco_active: bool = _base_pose != null
	if driven or _arms_driven or clip_active or _was_clip or loco_active or _was_loco:
		_refresh()  # back to the held pose (or the clip), then bend the driven arms
	_arms_driven = driven
	_was_clip = clip_active
	_was_loco = loco_active
	_update_clip_visuals()
	if _mix >= 1.0:
		return  # the clip has its own arms
	if has_right:
		solve_arm(_right, _arm_target(_right, right_hand, _right_follow), elbow_pole, max_stretch)
	if has_left:
		solve_arm(_left, _arm_target(_left, left_hand), Vector3(-elbow_pole.x, elbow_pole.y, elbow_pole.z), max_stretch)


## The hand target for an arm, in the figure's space: the code-drawn hand, or while a clip blends in or out a mix of
## the clip's hand and the code-drawn hand. `follow` (3c-2a) is how much the shown pose's own hand counts instead of the
## code-drawn one (the sheathed right arm following the locomotion clip).
func _arm_target(prefix: String, hand_world: Vector3, follow: float = 0.0) -> Vector3:
	var target: Vector3 = to_local(hand_world)
	var own: float = maxf(_mix, follow)
	if own <= 0.0 or _last_pose == null:
		return target
	var shown: Vector3 = _last_pose.points[_clips.joint_index(prefix + "_Hand")]
	return shown.lerp(target, 1.0 - own)


## 3c-2a: called by the Player and by the Enemy once per physics frame (not at all while they cannot walk: dead, held...).
## `on` = the body walks, runs, crouches or stands on the ground now, so the locomotion clips play; otherwise the figure
## fades to its held pose. `world_velocity` is how the body really moves, `strafe` = blend the four directions by the angle
## between that and where the figure faces (locked on, circling), `sprint` = the dash, `right_arm_free` = the sword is
## sheathed and at rest, so the right arm follows the pose instead of the code-drawn hand.
func drive_locomotion(on: bool, world_velocity: Vector3, strafe: bool, sprint: bool, right_arm_free: bool) -> void:
	if _loco == null or not available or not visible:
		return
	_loco_frame = Engine.get_physics_frames()
	_loco_wanted = on
	_right_free = right_arm_free
	var flat := Vector3(world_velocity.x, 0.0, world_velocity.z)
	var local: Vector3 = global_transform.basis.orthonormalized().inverse() * flat
	_loco.set_input(flat.length(), Vector2(local.x, local.z), strafe, sprint)


## Fade the locomotion layer in and out, step it, and make the base pose of this frame (null = the plain held pose).
func _update_locomotion(delta: float) -> void:
	var fresh: bool = Engine.get_physics_frames() - _loco_frame <= 2
	var enabled: bool = _loco != null and locomotion_enabled
	var on: bool = enabled and fresh and _loco_wanted
	_loco_mix = move_toward(_loco_mix, 1.0 if on else 0.0, delta / maxf(LOCO_BLEND, 0.001))
	var follow_goal: float = 1.0 if enabled and fresh and _right_free else 0.0
	_right_follow = move_toward(_right_follow, follow_goal, delta / maxf(ARM_BLEND, 0.001))
	if not enabled or (not on and _loco_mix <= 0.0):
		_base_pose = null
		return
	_loco.step(delta, crouch_blend, scale.x)
	var loco_pose: PlaceholderClips.Pose = _loco.pose(crouch_blend)
	_base_pose = loco_pose if _loco_mix >= 1.0 else _blend(_static_pose(), loco_pose, _loco_mix)


## 3a-3c: called by `ActionState` every physics frame with the running action, its clock and how fast the clock runs.
## Starts the action's clip when it changes (or the clock goes back), follows the clock, and stops the clip for an
## action with none. `clip` is the clip the action wants now (3a-3c-2: the state picks it; a ":upper" suffix plays the
## upper body only).
func drive_clip(action: ActionData, time: float, rate: float, clip: StringName, from: float = 0.0, to: float = -1.0) -> void:
	var span: float = maxf(action.duration, 0.001)
	drive_clip_progress(action, time / span, rate / span, clip, from, to)


## 3a-3c-4 PLACEHOLDER(ER clip): "hit-sync" (`ActionData.placeholder_clip_hit`, seconds into the clip). The clip is warped in
## three pieces so its hit start meets `active_hit.x`, its hit end meets `active_hit.y` and its end meets `duration`:
## the wind-up plays stretched across the telegraph, the strike near natural speed, then the recovery. An enemy attack
## uses it so the tuned telegraph keeps its timing. Without a hit span (or without the clip) it is the even stretch.
func drive_clip_synced(action: ActionData, time: float, rate: float, clip: StringName) -> void:
	var hit: Vector2 = action.placeholder_clip_hit
	var clip_str: String = String(clip)
	var from_hit: float = action.active_hit.x
	var to_hit: float = action.active_hit.y
	if not available or not _clips.has_clip(clip_str) or hit.x < 0.0 or hit.y <= hit.x \
			or from_hit <= 0.0 or to_hit <= from_hit or action.duration <= to_hit:
		drive_clip(action, time, rate, clip)
		return
	var length: float = maxf(_clips.length_of(clip_str), 0.001)
	var hit_end: float = minf(hit.y, length - 0.001)
	var hit_start: float = minf(hit.x, hit_end - 0.001)
	var clip_time: float
	var slope: float  # clip seconds per action second
	if time < from_hit:
		slope = hit_start / from_hit
		clip_time = time * slope
	elif time < to_hit:
		slope = (hit_end - hit_start) / (to_hit - from_hit)
		clip_time = hit_start + (time - from_hit) * slope
	else:
		slope = (length - hit_end) / (action.duration - to_hit)
		clip_time = hit_end + (time - to_hit) * slope
	drive_clip_progress(action, clampf(clip_time / length, 0.0, 1.0), slope * rate / length, clip)


## True while a clip plays (false when the clips are switched off, the figure is hidden or no clip was asked for).
func is_clip_playing() -> bool:
	return _playing


## 3a-3c-3: the same, but the caller gives the progress through the played part directly (0 to 1) and how fast it
## advances per second (a charge phase has no action clock). `from` and `to` are seconds into the clip: the part that
## plays (`to` -1 = the clip's end). A thrust's release plays the second half of the charge clip this way.
func drive_clip_progress(action: ActionData, progress: float, progress_rate: float, clip: StringName,
		from: float = 0.0, to: float = -1.0) -> void:
	if not available or not visible:
		return
	var full: String = String(clip) if clips_enabled else ""
	var upper: bool = full.ends_with(UPPER_SUFFIX)
	var wanted: String = full.trim_suffix(UPPER_SUFFIX) if upper else full
	if wanted.is_empty():
		if _playing:
			stop_clip()
		return
	if not _clips.has_clip(wanted):
		if not _warned.has(wanted):
			_warned[wanted] = true
			push_warning("[PlayerFigure] unknown clip '%s' on %s" % [wanted, action.resource_path])
		if _playing:
			stop_clip()
		return
	if action != _clip_action or not _playing or progress < _clip_p - 0.0005 or wanted != _clip_name or upper != _clip_upper:
		_begin_clip(action, wanted, upper, from, to)
	_clip_p = progress
	_clip_prate = progress_rate
	_since_tick = 0.0
	# The hitbox follows the clip's blade (sampled at exactly this time), so the hit lands where the blade is drawn.
	if _sword != null:
		_sword.hitbox_external = true
		_sword.place_hitbox_global(_blade_global(_clip_at(progress)))


## The clip's blade as a world transform: the blade root at the weapon joint, local -Z along the blade (the same
## convention as `SwordVisual`'s hand, which the hitbox expects), +X the weapon joint's X axis.
func _blade_global(pose: PlaceholderClips.Pose) -> Transform3D:
	var root: Vector3 = pose.points[_weapon_joint]
	var along: Vector3 = pose.axes[_weapon_axes * 3 + 1]
	var edge: Vector3 = pose.axes[_weapon_axes * 3]
	var z: Vector3 = -along
	var x: Vector3 = edge - z * edge.dot(z)
	if x.length_squared() < 0.0001:
		x = z.cross(Vector3.UP)
	x = x.normalized()
	var blade_basis := Basis(x, z.cross(x), z)
	var world: Transform3D = global_transform
	return Transform3D(world.basis.orthonormalized() * blade_basis, world * root)


## 3a-3c, for the F2 overlay: the playing clip, its current frame and the action clock, or "" when none plays.
func clip_status() -> String:
	if not _playing or _clip_action == null:
		return ""
	var progress: float = clampf(_clip_p + _since_tick * _clip_prate, 0.0, 1.0)
	var span: float = maxf(_clip_action.duration, 0.001)
	var frames: int = roundi(_clip_length * PlaceholderClips.FPS) + 1
	var frame: int = roundi(lerpf(_clip_from, _clip_to, progress) * PlaceholderClips.FPS)
	return "clip %s%s  f%d/%d  t %.2f / %.2f" % [_clip_name, UPPER_SUFFIX if _clip_upper else "", frame, frames, progress * span, span]


## The running clip ends: the figure blends back to the held pose. Does nothing when no clip plays.
func stop_clip() -> void:
	_playing = false
	_clip_action = null
	if _sword != null:
		_sword.hitbox_external = false


func _begin_clip(action: ActionData, clip_name: String, upper: bool, from: float, to: float) -> void:
	_clip_action = action
	_clip_name = clip_name
	_clip_upper = upper
	_clip_length = _clips.length_of(clip_name)
	_clip_from = clampf(from, 0.0, _clip_length)
	_clip_to = _clip_length if to < 0.0 else clampf(to, _clip_from, _clip_length)
	_playing = true
	if _mix > 0.0 and _last_pose != null:
		_xfade_from = _last_pose  # a clip is showing (a chained attack): fade from it instead of jumping
		_xfade = 1.0
	else:
		_xfade_from = null
		_xfade = 0.0
	_clip_p = 0.0
	_since_tick = 0.0
	_clip_pose = _clip_at(0.0)


## The played part of the clip at `progress` (0 to 1).
func _clip_at(progress: float) -> PlaceholderClips.Pose:
	return _sample_clip(lerpf(_clip_from, _clip_to, clampf(progress, 0.0, 1.0)))


## The playing clip at `time` seconds into it. An upper-body clip keeps the held pose's pelvis and legs, and the rest of
## the clip is moved by the same offset the pelvis was (so the torso stays on the hips, whatever the clip's step does).
func _sample_clip(time: float) -> PlaceholderClips.Pose:
	var pose: PlaceholderClips.Pose = _clips.sample(_clip_name, time)
	if not _clip_upper or pose == null or _pelvis < 0:
		return pose
	var held: PlaceholderClips.Pose = _held_pose()
	var shift: Vector3 = held.points[_pelvis] - pose.points[_pelvis]
	for i in pose.points.size():
		if _lower[i] == 1:
			pose.points[i] = held.points[i]
		else:
			pose.points[i] += shift
	return pose


## Advance the clip between physics frames (the clock is given once per physics frame), and the blends.
func _step_clip(delta: float) -> void:
	if _playing:
		_since_tick = minf(_since_tick + delta, 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0))
		var progress: float = clampf(_clip_p + _since_tick * _clip_prate, 0.0, 1.0)
		_clip_pose = _clip_at(progress)
	var goal: float = 1.0 if _playing else 0.0
	_mix = move_toward(_mix, goal, delta / maxf(blend_in if _playing else blend_out, 0.001))
	if _xfade > 0.0:
		_xfade = move_toward(_xfade, 0.0, delta / maxf(blend_in, 0.001))


## The figure's own blade shows (and the code-drawn one hides) once the clip is mostly in; the body twist of the code
## sword is switched off in step with the clip.
func _update_clip_visuals() -> void:
	var swap: bool = _mix > 0.5
	if swap != _blade_swapped:
		_blade_swapped = swap
		set_blade_visible(swap)
		if _sword != null:
			_sword.set_blade_hidden(swap)
	if _sword != null:
		_sword.figure_twist_scale = 1.0 - _mix
	if _mix >= 1.0:
		rotation.y = 0.0


func _on_visibility_changed() -> void:
	if visible:
		return
	# The capsule is back: forget the clip and give the code sword its blade.
	_playing = false
	_clip_action = null
	if _sword != null:
		_sword.hitbox_external = false
	_mix = 0.0
	_xfade = 0.0
	_was_clip = false
	_loco_mix = 0.0
	_right_follow = 0.0
	_base_pose = null
	_was_loco = false
	if _blade_swapped:
		_blade_swapped = false
		set_blade_visible(false)
		if _sword != null:
			_sword.set_blade_hidden(false)
			_sword.figure_twist_scale = 1.0


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
	var held: PlaceholderClips.Pose = _held_pose()
	if _mix <= 0.0 or _clip_pose == null:
		show_pose(held)
		return
	var clip_pose: PlaceholderClips.Pose = _clip_pose
	if _xfade > 0.0 and _xfade_from != null:
		clip_pose = _blend(clip_pose, _xfade_from, _xfade)
	show_pose(clip_pose if _mix >= 1.0 else _blend(held, clip_pose, _mix))


## The base layer under the actions: the locomotion pose of this frame (3c-2a), or the held pose.
func _held_pose() -> PlaceholderClips.Pose:
	return _base_pose if _base_pose != null else _static_pose()


## The standing pose, the crouched pose, or the blend between them while the crouch eases.
func _static_pose() -> PlaceholderClips.Pose:
	if crouch_blend <= 0.0:
		return _stand
	if crouch_blend >= 1.0:
		return _crouch
	return _blend(_stand, _crouch, crouch_blend)


static func _blend(a: PlaceholderClips.Pose, b: PlaceholderClips.Pose, weight: float) -> PlaceholderClips.Pose:
	var pose := PlaceholderClips.Pose.new()
	pose.points.resize(a.points.size())
	for i in a.points.size():
		pose.points[i] = a.points[i].lerp(b.points[i], weight)
	pose.axes.resize(a.axes.size())
	for i in a.axes.size():
		pose.axes[i] = a.axes[i].lerp(b.axes[i], weight).normalized()
	return pose
