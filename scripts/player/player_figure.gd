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
## 3c-4c: an upper-body layer (`FigureUpperLayer`) sits on that base pose: while the owner reports a guard (`drive_upper(GUARD)`)
## the joints above the pelvis take the sandbox's guard stance, and while it reports a carry they take a made-up carrying pose;
## the legs keep the locomotion clip. The layer fades in and out over `UPPER_BLEND`, on its own. The right arm still follows
## the code-drawn hand unless the sword is sheathed at rest (`right_arm_free`), so the sword's guard and deflect poses are kept.
## 3d-2: foot placement (`FigureFeet`): while the owner stands on the ground, a ray under each foot finds the surface (the world and the
## `Layers.FOOT_SURFACE` layer, never the smooth ramp a body walks on), the whole figure moves to the lower foot and each leg reaches its
## foot with a two-bone solve, over every pose that is shown (clips, locomotion, held). The figure's shapes cast real shadows, and an
## optional blob shadow lies on the ground under it. F1: "Foot placement", "Figure shadow", "Blob shadow".

## PLACEHOLDER: how far (fraction of the arm's length) the bones may stretch to reach a hand target.
@export var max_stretch: float = 0.25
## Which way the right elbow bends (figure space: +X right, -Y down, +Z back); the left arm mirrors X.
@export var elbow_pole: Vector3 = Vector3(0.5, -1.0, 0.3)

## PLACEHOLDER: seconds to blend from the held pose into a clip, and from the clip back to the held pose.
@export var blend_in: float = 0.1
@export var blend_out: float = 0.12

## 3c-4c PLACEHOLDER(made-up pose): the carrying pose, in figure space (+X right, +Y up, -Z forward, the clips' metres). The hands
## are relative to the chest; the lean is degrees away from the shoulder the body rests on. Tuned by eye.
@export var carry_right_hand: Vector3 = Vector3(0.2, 0.05, -0.17)
@export var carry_left_hand: Vector3 = Vector3(0.1, -0.12, -0.22)
@export var carry_lean_degrees: float = 6.0
## Which way the elbows bend while carrying (the right one; the left mirrors X).
@export var carry_elbow_pole: Vector3 = Vector3(0.7, -0.8, 0.3)

## The F1 switch (3a-3c): false = no clip plays, the figure holds its pose and the code sword is drawn.
static var clips_enabled: bool = true
## The F1 switch (3c-2a): false = no locomotion clips, the figure holds its idle or crouch pose out of actions.
static var locomotion_enabled: bool = true
## The F1 switch (3d-1): true = footsteps come from the locomotion clips' foot plants (the player's and the enemies'); false =
## the old distance steps of the Player (the enemies are then silent).
static var frame_footsteps_enabled: bool = true
## The F1 switch (3d-2): false = the legs keep the clips' own height (no fitting to stairs and slopes).
static var foot_placement_enabled: bool = true
## The F1 switch (3d-2): the figure's shapes cast real shadows.
static var shadow_enabled: bool = true
## The F1 switch (3d-2): a soft dark disc on the ground under the figure (off by default; the real shadow is the main one).
static var blob_enabled: bool = false
static var _loco_warned: bool = false

const STAND_CLIP: String = "idle"
const CROUCH_CLIP: String = "crouch_idle"
## The suffix of a clip name that plays the upper body only.
const UPPER_SUFFIX: String = ":upper"
## 3c-2a: seconds to fade between the held pose and the locomotion pose, and for the sheathed right arm between the pose's
## hand and the code-drawn hand.
const LOCO_BLEND: float = 0.15
const ARM_BLEND: float = 0.12
## 3c-3a: seconds the air pose fades in and out against the ground pose.
const AIR_BLEND: float = 0.08
## 3c-4c: seconds an upper-body layer (guard, carry) fades in and out.
const UPPER_BLEND: float = 0.12
## 3d-1: an enemy's footsteps are this much quieter (dB) than the player's, and play in the world at its feet.
const ENEMY_STEP_DB: float = -8.0
## 3d-2: the figure is fitted to the ground only while its head is above this fraction of the standing head height (a body lying
## flat, in a knockdown or a roll's low point, keeps the clip's legs). PLACEHOLDER: a guess; the heavy landing crouch is about 0.5.
const FEET_HEAD_MIN: float = 0.4
## 3d-2: the blob shadow's size (m) on the ground, its darkest alpha, and how far above the ground it fades out.
const BLOB_SIZE: float = 1.0
const BLOB_ALPHA: float = 0.5
const BLOB_FADE_HEIGHT: float = 8.0

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
## 3d-1: the owner is on the ground in a gait this frame (the base layer is walking, not only fading).
var _loco_on_now: bool = false
var _loco_mix: float = 0.0
## 3c-3a: the physics frame of the last `drive_air()`, whether the body is airborne, and the air pose's blend weight.
var _air_frame: int = -100
var _air_wanted: bool = false
var _air_mix: float = 0.0
var _base_pose: PlaceholderClips.Pose
## The first air clip the library lacks ("" = none), which switches the air layer off.
var _air_missing: String = ""
var _was_loco: bool = false
var _right_free: bool = false
var _right_follow: float = 0.0
# 3c-4c: the upper-body layer. `_upper_wanted` is what the owner asked for in the physics frame `_upper_frame`; `_upper_kind` is
# the layer being shown or faded (it changes only at weight 0), `_upper_mix` its weight, `_upper_time` the guard loop's clock.
var _upper: FigureUpperLayer
var _upper_wanted: int = FigureUpperLayer.Kind.NONE
var _upper_frame: int = -100
var _upper_kind: int = FigureUpperLayer.Kind.NONE
var _upper_mix: float = 0.0
var _upper_time: float = 0.0
var _upper_warned: bool = false
# 3d-2: foot placement. `_base_y` is the figure's resting height (`fit_to_height()`), the pelvis offset rides on top of it.
var _feet: FigureFeet
var _base_y: float = 0.0
var _stand_head_y: float = 1.0
var _shadow_applied: bool = false
var _blob: MeshInstance3D
var _blob_material: StandardMaterial3D


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
		var missing_air: String = FigureLocomotion.missing_air_clip(clips)
		if not missing_air.is_empty():
			_air_missing = missing_air
			push_warning("[PlayerFigure] air clip '%s' is missing: no jump or fall clips (run tools/placeholder/convert_clips.py)" % missing_air)
	elif not _loco_warned:
		_loco_warned = true
		push_warning("[PlayerFigure] locomotion clip '%s' is missing: no locomotion clips (run tools/placeholder/convert_clips.py)" % missing)
	_upper = FigureUpperLayer.new(clips)
	_feet = FigureFeet.new(clips)
	if not _feet.ready_to_use:
		_feet = null
	_stand_head_y = maxf(_stand.points[_head_joint].y, 0.1)
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
	if shadow_enabled != _shadow_applied:
		_shadow_applied = shadow_enabled
		set_shadow_casting(shadow_enabled)
	_update_locomotion(delta)
	var feet_changed: bool = _update_feet(delta)
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
	if driven or _arms_driven or clip_active or _was_clip or loco_active or _was_loco or feet_changed:
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


## 3c-3a: called by the Player and by the Enemy once per physics frame. `on` = the body is airborne (jumping, falling, in an
## air action); the figure then shows the jump, the fall start and the airborne loop as its base layer.
## 3c-4b: `strafe` = locked on, so a walking or running jump plays the clip of the direction the body moves in.
func drive_air(on: bool, world_velocity: Vector3, strafe: bool = false) -> void:
	if _loco == null or not available or not visible or not _air_missing.is_empty():
		return
	_air_frame = Engine.get_physics_frames()
	_air_wanted = on
	_loco.set_air(on, world_velocity.y, Vector2(world_velocity.x, world_velocity.z).length(), strafe,
			local_flat_velocity(world_velocity))


## 3c-5: the mid-air jump press: the figure plays the jump clip again from its start (no height change; the clip is picked by
## the flat speed, in four directions while `strafe`, and fitted to `take_off_speed`). Only while the air layer is live.
func replay_jump(world_velocity: Vector3, strafe: bool, take_off_speed: float) -> void:
	if _loco == null or not available or not visible or not _air_missing.is_empty():
		return
	_loco.restart_jump(Vector2(world_velocity.x, world_velocity.z).length(), strafe, local_flat_velocity(world_velocity), take_off_speed)


## 3c-4b: the flat part of a world velocity in the figure's own space (x right, y back), for picking a direction clip.
func local_flat_velocity(world_velocity: Vector3) -> Vector2:
	var local: Vector3 = global_transform.basis.orthonormalized().inverse() * Vector3(world_velocity.x, 0.0, world_velocity.z)
	return Vector2(local.x, local.z)


## 3c-4c: called by the Player and by the Enemy once per physics frame with the upper-body layer it wants (`FigureUpperLayer.Kind.GUARD` while a
## guard is up on the ground, `FigureUpperLayer.Kind.CARRY` while a body is on its shoulder, otherwise `FigureUpperLayer.Kind.NONE`). Not called, or not for two
## physics frames, counts as NONE. The legs keep their locomotion clip.
func drive_upper(kind: int) -> void:
	if _upper == null or not available or not visible:
		return
	_upper_frame = Engine.get_physics_frames()
	_upper_wanted = kind


## The base pose of this frame: the locomotion layer (3c-2a, 3c-3a) with the upper-body layer on top (3c-4c); null = the plain held pose.
func _update_locomotion(delta: float) -> void:
	var base: PlaceholderClips.Pose = _locomotion_base(delta)
	_play_footsteps()
	_update_upper(delta)
	if _upper_mix > 0.0 and _upper_kind != FigureUpperLayer.Kind.NONE:
		var under: PlaceholderClips.Pose = base if base != null else _static_pose()
		base = _with_upper(under)
	_base_pose = base


## 3d-1: true while the figure times the footsteps itself (the Player then skips its distance steps).
func drives_footsteps() -> bool:
	return frame_footsteps_enabled and available and visible and locomotion_enabled and _loco != null


## 3d-1: a footstep sound for every foot plant the locomotion cycle passed this frame: flat for the player, in the world for an
## enemy. Only on the ground in a gait (the owner reports it walking), and not while an action clip owns the legs.
func _play_footsteps() -> void:
	if _loco == null:
		return
	var count: int = _loco.take_steps()
	if count <= 0 or not drives_footsteps() or not _loco_on_now or _mix >= 0.5 or _air_mix >= 0.5:
		return
	var id: Sfx.Id = Sfx.Id.FOOTSTEP_WALK
	match _loco.step_gait():
		FigureLocomotion.Gait.RUN, FigureLocomotion.Gait.SPRINT:
			id = Sfx.Id.FOOTSTEP_RUN
		FigureLocomotion.Gait.CROUCH_RUN:
			id = Sfx.Id.FOOTSTEP_CROUCH
	for i in count:
		if owner is Player:
			Sfx.play(get_tree(), id)
		else:
			Sfx.play_at(get_tree(), id, global_position, ENEMY_STEP_DB)


## Step the layer's weight and clock: it fades out before another kind takes over, and off when it is not asked for.
func _update_upper(delta: float) -> void:
	var fresh: bool = Engine.get_physics_frames() - _upper_frame <= 2
	var want: int = _upper_wanted if (_upper != null and locomotion_enabled and fresh) else FigureUpperLayer.Kind.NONE
	if want == FigureUpperLayer.Kind.GUARD and not _upper.has_guard():
		want = FigureUpperLayer.Kind.NONE
		if not _upper_warned:
			_upper_warned = true
			push_warning("[PlayerFigure] clip '%s' is missing: no guard layer (run tools/placeholder/convert_clips.py)" % FigureUpperLayer.GUARD_CLIP)
	if _upper_kind != want and _upper_mix <= 0.0:
		_upper_kind = want
		_upper_time = 0.0
	var goal: float = 1.0 if (want != FigureUpperLayer.Kind.NONE and want == _upper_kind) else 0.0
	_upper_mix = move_toward(_upper_mix, goal, delta / maxf(UPPER_BLEND, 0.001))
	_upper_time += delta
	if _upper != null:
		_upper.carry_right_hand = carry_right_hand
		_upper.carry_left_hand = carry_left_hand
		_upper.carry_lean_degrees = carry_lean_degrees
		_upper.carry_right_pole = carry_elbow_pole
		_upper.carry_left_pole = Vector3(-carry_elbow_pole.x, carry_elbow_pole.y, carry_elbow_pole.z)


## `under` with the upper-body layer on it. A guard stands up out of a crouch: its weight falls as the figure crouches.
func _with_upper(under: PlaceholderClips.Pose) -> PlaceholderClips.Pose:
	if _upper_kind == FigureUpperLayer.Kind.GUARD:
		var weight: float = _upper_mix * (1.0 - crouch_blend)
		return under if weight <= 0.0 else _upper.blend(under, _upper.guard_pose(under, _upper_time), weight)
	return _upper.blend(under, _upper.carry_pose(under), _upper_mix)


## Fade the locomotion layer in and out, step it, and make the base pose of this frame (null = the plain held pose).
func _locomotion_base(delta: float) -> PlaceholderClips.Pose:
	var fresh: bool = Engine.get_physics_frames() - _loco_frame <= 2
	var enabled: bool = _loco != null and locomotion_enabled
	var on: bool = enabled and fresh and _loco_wanted
	_loco_on_now = on
	var air_fresh: bool = Engine.get_physics_frames() - _air_frame <= 2
	if not air_fresh and _loco != null:
		_loco.reset_air()
	var air_live: bool = enabled and air_fresh and _air_wanted and _loco.air_live()
	var air_on: bool = air_live and _loco.air_active()
	_air_mix = move_toward(_air_mix, 1.0 if air_on else 0.0, delta / maxf(AIR_BLEND, 0.001))
	_loco_mix = move_toward(_loco_mix, 1.0 if (on or air_on) else 0.0, delta / maxf(LOCO_BLEND, 0.001))
	var follow_goal: float = 1.0 if enabled and fresh and _right_free else 0.0
	_right_follow = move_toward(_right_follow, follow_goal, delta / maxf(ARM_BLEND, 0.001))
	if not enabled or (not on and not air_live and _loco_mix <= 0.0 and _air_mix <= 0.0):
		return null
	_loco.step(delta, crouch_blend, scale.x)
	var loco_pose: PlaceholderClips.Pose = _loco.pose(crouch_blend)
	if _air_mix > 0.0:
		var air_pose: PlaceholderClips.Pose = _loco.air_pose()
		loco_pose = air_pose if _air_mix >= 1.0 else _blend(loco_pose, air_pose, _air_mix)
	return loco_pose if _loco_mix >= 1.0 else _blend(_static_pose(), loco_pose, _loco_mix)


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
	_upper_mix = 0.0
	_upper_kind = FigureUpperLayer.Kind.NONE
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
	_base_y = -lowest * factor
	position.y = _base_y


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
		show_pose(_with_feet(held))
		return
	var clip_pose: PlaceholderClips.Pose = _clip_pose
	if _xfade > 0.0 and _xfade_from != null:
		clip_pose = _blend(clip_pose, _xfade_from, _xfade)
	show_pose(_with_feet(clip_pose if _mix >= 1.0 else _blend(held, clip_pose, _mix)))


## 3d-2: `pose` with the legs fitted to the ground (the pose itself when foot placement is off or has nothing to do).
func _with_feet(pose: PlaceholderClips.Pose) -> PlaceholderClips.Pose:
	return pose if _feet == null else _feet.apply(pose, scale.y)


## 3d-2: true while the figure may be fitted to the ground: the switch is on, the owner is alive and free (its owner drives the
## locomotion layer every physics frame), stands on the floor, and the figure is not lying flat (the head height of the pose shown).
func _feet_active() -> bool:
	if _feet == null or not foot_placement_enabled or not available or not visible:
		return false
	if Engine.get_physics_frames() - _loco_frame > 2:
		return false
	var body := owner as CharacterBody3D
	if body == null or not body.is_on_floor():
		return false
	if _last_pose == null:
		return true
	return _last_pose.points[_head_joint].y / _stand_head_y > FEET_HEAD_MIN


## 3d-2: once per rendered frame: ease the offsets, move the figure to the lower foot, and say whether the pose must be redrawn.
func _update_feet(delta: float) -> bool:
	if _feet == null:
		return false
	var changed: bool = _feet.step(delta, _feet_active())
	position.y = _base_y + _feet.pelvis_offset()
	return changed


## 3d-2: once per physics frame: probe the ground under each foot and place the blob shadow. The physics space is only
## read here.
func _physics_process(_delta: float) -> void:
	if not available or not visible:
		if _blob != null:
			_blob.visible = false
		return
	var body := owner as Node3D
	if body == null:
		return
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	var collider := owner as CollisionObject3D
	if collider != null:
		exclude.append(collider.get_rid())
	if _feet != null and _last_pose != null and foot_placement_enabled:
		var floor_y: float = body.global_position.y
		for side in 2:
			var joints: Vector2i = _feet.foot_joints(side)
			var middle: Vector3 = (_last_pose.points[joints.x] + _last_pose.points[joints.y]) * 0.5
			var at: Vector3 = global_transform * middle
			var hit_y: float = _ground_y(space, at.x, floor_y + FigureFeet.STEP_UP, floor_y - FigureFeet.STEP_DOWN, at.z, exclude)
			_feet.set_ground(side, NAN if is_nan(hit_y) else hit_y - floor_y)
	_update_blob(space, body, exclude)


## The height of the ground at (x, z) between `top` and `bottom`, or NAN. Sees the world and the foot surfaces, never the smooth ramp.
func _ground_y(space: PhysicsDirectSpaceState3D, x: float, top: float, bottom: float, z: float, exclude: Array[RID]) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, bottom, z), Layers.WORLD | Layers.FOOT_SURFACE, exclude)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return NAN
	return (hit["position"] as Vector3).y


## 3d-2: the blob shadow: a soft dark disc flat on the ground under the owner, smaller and fainter the higher it is. Made when first
## switched on; a world-space node (top level), so the figure's scale and tilt do not touch it.
func _update_blob(space: PhysicsDirectSpaceState3D, body: Node3D, exclude: Array[RID]) -> void:
	if not blob_enabled:
		if _blob != null:
			_blob.visible = false
		return
	if _blob == null:
		_make_blob()
	var origin: Vector3 = body.global_position
	var ground: float = _ground_y(space, origin.x, origin.y + 0.3, origin.y - 40.0, origin.z, exclude)
	if is_nan(ground):
		_blob.visible = false
		return
	var height: float = maxf(origin.y - ground, 0.0)
	var fade: float = clampf(1.0 - height / BLOB_FADE_HEIGHT, 0.0, 1.0)
	_blob.visible = fade > 0.01
	_blob.global_position = Vector3(origin.x, ground + 0.02, origin.z)
	_blob.scale = Vector3.ONE * (BLOB_SIZE * (1.0 + height * 0.1))
	_blob_material.albedo_color = Color(1.0, 1.0, 1.0, BLOB_ALPHA * fade)


func _make_blob() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(0, 0, 0, 1), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	_blob_material = StandardMaterial3D.new()
	_blob_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blob_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blob_material.albedo_texture = texture
	_blob_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	_blob = MeshInstance3D.new()
	_blob.mesh = plane
	_blob.material_override = _blob_material
	_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blob.top_level = true
	add_child(_blob)


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
