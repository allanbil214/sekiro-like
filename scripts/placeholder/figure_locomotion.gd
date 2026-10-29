class_name FigureLocomotion
extends RefCounted
## PLACEHOLDER(ER clip): the walking, running and crouching of the mannequin (Phase 3c-2a, docs/placeholders.md P2). It turns how
## a body really moves (its speed, and which way that is from where it faces) into a pose of the converted locomotion clips.
## `PlayerFigure` owns one and shows its pose as the figure's base layer; action clips blend over it as before. It knows
## nothing of gameplay: the Player and the Enemy only tell the figure how they move (`PlayerFigure.drive_locomotion()`).
##
## - Which clip: idle when still, walk, run (from `RUN_FROM`), sprint (the dash), and a crouch idle and crouch run while the
##   figure is crouched. Changing clip cross-fades over `FADE`; the walk-to-run threshold and the idle threshold have a
##   small band so a speed that hovers there does not flicker.
## - Four ways: while `strafe` is set (locked on, or an enemy circling), the walk, run and crouch-run clips of the two
##   directions nearest to the way the body moves (from where it faces) are blended by the angle. Otherwise the front clip.
## - Rate: the clip plays at the real speed over the clip's own travel speed (`CLIP_SPEED`, metres per second in the clip's
##   own metres, times the figure's scale), so the feet keep up with the ground. `RATE_CAP` is only a safety limit.
##   The clips are baked in place (the pelvis never travels), so `CLIP_SPEED` was measured from the planted foot of each
##   front clip once, offline; the other directions reuse it. It belongs to the clips: new clips, new numbers.
## - The converted loops are closed (the last frame is the first), so they loop with `PlaceholderClips.sample_loop()`.

enum Gait { IDLE, WALK, RUN, SPRINT, CROUCH_IDLE, CROUCH_RUN }

## Seconds to cross-fade from one clip to another.
const FADE: float = 0.15
## Speed (m/s) under which the body counts as standing still, and above which a walk turns into a run.
const IDLE_BELOW: float = 0.3
const RUN_FROM: float = 4.0
## Half-width of the band around those two speeds in which the current clip is kept.
const BAND: float = 0.25
## The most the clips are ever sped up (safety limit; a real speed over the clip's own is about 1.7 to 1.9 for the player).
const RATE_CAP: float = 2.2
## How fast (per second) the blend angle follows the way the body moves.
const DIRECTION_SMOOTHING: float = 14.0

## Travel speed of each gait's clip (m/s in the clip's own metres), indexed by `Gait`. Idle gaits have none.
const CLIP_SPEED: Array = [0.0, 1.3, 3.85, 5.0, 0.0, 2.8]

const IDLE_CLIP: String = "idle"
const CROUCH_IDLE_CLIP: String = "crouch_idle"
const SPRINT_CLIP: String = "sprint"
## The four directions in clockwise order from the front: the blend angle 0, 90, 180 and 270 degrees.
const WALK_CLIPS: Array = ["walk_front", "walk_right", "walk_back", "walk_left"]
const RUN_CLIPS: Array = ["run_front", "run_right", "run_back", "run_left"]
const CROUCH_RUN_CLIPS: Array = ["crouch_run_front", "crouch_run_right", "crouch_run_back", "crouch_run_left"]

## 3c-3a PLACEHOLDER(ER clip): the air layer. A jump plays the jump clip of its take-off speed, a fall off a ledge plays the fall
## start, and both end in the airborne loop. The clips are the sandbox's (docs/placeholders.md P2).
const AIR_LOOP_CLIP: String = "air_loop"
const FALL_START_CLIP: String = "fall_start"
const JUMP_CLIPS: Array = ["jump_stand", "jump_walk", "jump_run", "jump_sprint"]
## Take-off speeds (m/s) from which a jump counts as a walking, running or sprinting one (the player's walk is 2.5, its run
## 6.5 and its dash 9.0; an enemy's speeds fall in the same bands).
const JUMP_WALK_FROM: float = 0.5
const JUMP_RUN_FROM: float = 3.75
const JUMP_SPRINT_FROM: float = 8.0
## Rising faster than this (m/s) at the first airborne frame means a jump; anything else is a fall.
const RISE_FROM: float = 1.0
## A kick upwards of more than this (m/s in one frame) in mid-air (a wall jump) starts the jump clip again.
const KICK_FROM: float = 4.0
## A fall shows its clip only after this long in the air (s), so a bump or a step does not flicker.
const AIR_MIN: float = 0.1
## Time (s) the air must have been off before a new take-off counts (a short hop through another state is not one).
const EDGE_GAP: float = 0.12
## 3c-3a tuning (the jump clip against our jump, set by feel): the jump clip starts this many seconds after take-off (the
## first frame is held), and is sped up or slowed down so its first half (up to the apex) takes as long as our rise, which is
## about `JUMP_RISE_PER_SPEED` seconds per m/s of take-off speed (0.42 s at 10.08 m/s). Set the delay to 0 and the apex
## share to 0.5 and the rise per speed to 0.0417 for the plain, unfitted clip.
const JUMP_CLIP_DELAY: float = 0.06
const JUMP_CLIP_APEX_SHARE: float = 0.5
const JUMP_RISE_PER_SPEED: float = 0.0417
const JUMP_RATE_MIN: float = 0.7
const JUMP_RATE_MAX: float = 1.4
## Seconds the lead clip (jump or fall start) cross-fades into the loop at its end.
const AIR_FADE: float = 0.15

var _clips: PlaceholderClips
## Blend weight of each gait; the standing gaits (0 to 3) add up to 1 and so do the crouched ones (4 and 5).
var _weights: Array[float] = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0]
var _stand_gait: int = Gait.IDLE
var _crouch_gait: int = Gait.CROUCH_IDLE
## Position in the walk, run and sprint cycle (0 to 1), and the time of the idle loops.
var _phase: float = 0.0
var _idle_time: float = 0.0
## Radians clockwise from the front (0 = front, PI / 2 = right) the body moves, smoothed.
var _angle: float = 0.0
var _speed: float = 0.0
var _local: Vector2 = Vector2.ZERO
var _strafe: bool = false
var _sprint: bool = false

## The air layer (3c-3a): the last input, the clip that leads (a jump or the fall start), time since take-off, and the
## time the air was off.
var _air_input: bool = false
var _air_jumped: bool = false
var _air_clip: String = FALL_START_CLIP
var _air_t: float = 0.0
var _air_delay: float = 0.0
var _air_rate: float = 1.0
var _air_off: float = 1.0
var _air_vy: float = 0.0


func _init(clips: PlaceholderClips) -> void:
	_clips = clips


## The name of the first locomotion clip the library lacks, or "" when it has them all.
static func missing_clip(clips: PlaceholderClips) -> String:
	var wanted: Array = [IDLE_CLIP, CROUCH_IDLE_CLIP, SPRINT_CLIP]
	wanted.append_array(WALK_CLIPS)
	wanted.append_array(RUN_CLIPS)
	wanted.append_array(CROUCH_RUN_CLIPS)
	for clip_name: String in wanted:
		if not clips.has_clip(clip_name):
			return clip_name
	return ""


## The name of the first air clip the library lacks, or "" when it has them all (the air layer is off without them).
static func missing_air_clip(clips: PlaceholderClips) -> String:
	var wanted: Array = [AIR_LOOP_CLIP, FALL_START_CLIP]
	wanted.append_array(JUMP_CLIPS)
	for clip_name: String in wanted:
		if not clips.has_clip(clip_name):
			return clip_name
	return ""


## 3c-3a: how the body moves through the air (call once per physics frame). `on` = it is airborne and the air layer
## should show; `vy` its vertical speed, `flat` its flat speed. A take-off (the air was off for `EDGE_GAP`) picks the
## lead clip: a jump when rising, else the fall start.
func set_air(on: bool, vy: float, flat: float) -> void:
	var tick: float = 1.0 / maxf(float(Engine.physics_ticks_per_second), 1.0)
	if not on:
		_air_off += tick
		_air_input = false
		_air_vy = 0.0
		return
	if not _air_input and _air_off >= EDGE_GAP:
		_air_t = 0.0
		_air_jumped = vy > RISE_FROM
		_air_clip = _jump_clip(flat) if _air_jumped else FALL_START_CLIP
		_fit_lead(vy)
	elif _air_input and vy - _air_vy > KICK_FROM:
		_air_t = 0.0
		_air_jumped = true
		_air_clip = _jump_clip(flat)
		_fit_lead(vy)
	_air_input = true
	_air_off = 0.0
	_air_vy = vy


## The air layer was not driven for a while (the body died, was held): forget the air, so the next take-off counts.
func reset_air() -> void:
	if _air_input:
		_air_input = false
		_air_off = 1.0


## True while the air layer has a pose to show: a jump at once, a fall after `AIR_MIN`.
func air_active() -> bool:
	return _air_input and (_air_jumped or _air_t >= AIR_MIN)


## True while the body is airborne (the layer steps even before it shows).
func air_live() -> bool:
	return _air_input


## Sets the lead clip's start delay and speed from the take-off speed (a fall start plays as it is).
func _fit_lead(vy: float) -> void:
	_air_delay = 0.0
	_air_rate = 1.0
	if not _air_jumped:
		return
	_air_delay = JUMP_CLIP_DELAY
	var rise: float = maxf(vy, 0.0) * JUMP_RISE_PER_SPEED
	if rise > 0.05:
		var apex_time: float = _clips.length_of(_air_clip) * JUMP_CLIP_APEX_SHARE
		_air_rate = clampf(apex_time / (rise - _air_delay if rise > _air_delay + 0.05 else rise), JUMP_RATE_MIN, JUMP_RATE_MAX)


func _jump_clip(flat: float) -> String:
	if flat >= JUMP_SPRINT_FROM:
		return String(JUMP_CLIPS[3])
	if flat >= JUMP_RUN_FROM:
		return String(JUMP_CLIPS[2])
	if flat >= JUMP_WALK_FROM:
		return String(JUMP_CLIPS[1])
	return String(JUMP_CLIPS[0])


## The air pose now: the lead clip, cross-fading into the loop over its last `AIR_FADE` seconds.
func air_pose() -> PlaceholderClips.Pose:
	var loop_pose: PlaceholderClips.Pose = _clips.sample_loop(AIR_LOOP_CLIP, _air_t)
	var lead_length: float = _clips.length_of(_air_clip) / _air_rate + _air_delay
	if _air_t >= lead_length:
		return loop_pose
	var lead_pose: PlaceholderClips.Pose = _clips.sample(_air_clip, maxf(_air_t - _air_delay, 0.0) * _air_rate)
	var weight: float = clampf((_air_t - (lead_length - AIR_FADE)) / AIR_FADE, 0.0, 1.0)
	return lead_pose if weight <= 0.0 else _mix(lead_pose, loop_pose, weight)


## How the body moves now (call once per physics frame): its flat speed, that velocity in the figure's own space
## (x right, y = z back), whether to blend the four directions, and whether it is sprinting (the dash).
func set_input(speed: float, local_xz: Vector2, strafe: bool, sprint: bool) -> void:
	_speed = speed
	_local = local_xz
	_strafe = strafe
	_sprint = sprint


## Advance the cross-fades and the cycle by `delta`. `crouch` is the figure's crouch blend (0 standing, 1 crouched) and
## `body_scale` the figure's scale (metres of the world per metre of the clips).
func step(delta: float, crouch: float, body_scale: float) -> void:
	_pick_gaits()
	_fade(delta)
	_update_angle(delta)
	_idle_time += delta
	if _air_input:
		_air_t += delta
	var standing: float = _group_cycles(Gait.IDLE, Gait.CROUCH_IDLE, body_scale)
	var crouched: float = _group_cycles(Gait.CROUCH_IDLE, Gait.CROUCH_RUN + 1, body_scale)
	# While one group is still (or has no moving clip), the other sets the pace.
	var cycles: float = lerpf(standing if standing > 0.0 else crouched, crouched if crouched > 0.0 else standing, crouch)
	_phase = fposmod(_phase + cycles * delta, 1.0)


## The pose now: the standing and the crouched gaits, blended by `crouch`.
func pose(crouch: float) -> PlaceholderClips.Pose:
	var standing: PlaceholderClips.Pose = _group_pose(Gait.IDLE, Gait.CROUCH_IDLE) if crouch < 1.0 else null
	var crouched: PlaceholderClips.Pose = _group_pose(Gait.CROUCH_IDLE, Gait.CROUCH_RUN + 1) if crouch > 0.0 else null
	if standing == null:
		return crouched
	if crouched == null:
		return standing
	return _mix(standing, crouched, crouch)


func _pick_gaits() -> void:
	var idle_limit: float = IDLE_BELOW + BAND if _stand_gait == Gait.IDLE else IDLE_BELOW
	if _speed < idle_limit:
		_stand_gait = Gait.IDLE
	elif _sprint:
		_stand_gait = Gait.SPRINT
	else:
		var running: bool = _stand_gait == Gait.RUN or _stand_gait == Gait.SPRINT
		var run_at: float = RUN_FROM - BAND if running else RUN_FROM + BAND
		_stand_gait = Gait.RUN if _speed >= run_at else Gait.WALK
	var crouch_idle_limit: float = IDLE_BELOW + BAND if _crouch_gait == Gait.CROUCH_IDLE else IDLE_BELOW
	_crouch_gait = Gait.CROUCH_IDLE if _speed < crouch_idle_limit else Gait.CROUCH_RUN


func _fade(delta: float) -> void:
	var amount: float = delta / maxf(FADE, 0.001)
	for i in _weights.size():
		var goal: float = 1.0 if i == _stand_gait or i == _crouch_gait else 0.0
		_weights[i] = move_toward(_weights[i], goal, amount)
	_normalize(Gait.IDLE, Gait.CROUCH_IDLE, _stand_gait)
	_normalize(Gait.CROUCH_IDLE, Gait.CROUCH_RUN + 1, _crouch_gait)


func _normalize(first: int, last: int, fallback: int) -> void:
	var total: float = 0.0
	for i in range(first, last):
		total += _weights[i]
	if total < 0.0001:
		_weights[fallback] = 1.0
		return
	for i in range(first, last):
		_weights[i] /= total


func _update_angle(delta: float) -> void:
	var target: float = 0.0
	if _strafe and not _sprint:
		if _speed < IDLE_BELOW:
			return  # standing: keep the last direction
		target = atan2(_local.x, -_local.y)
	_angle = lerp_angle(_angle, target, 1.0 - exp(-DIRECTION_SMOOTHING * delta))


## How many cycles per second the moving gaits in [first, last) advance, weighted by their blend weights.
func _group_cycles(first: int, last: int, body_scale: float) -> float:
	var total: float = 0.0
	var sum: float = 0.0
	for i in range(first, last):
		var clip_speed: float = float(CLIP_SPEED[i])
		if clip_speed <= 0.0 or _weights[i] <= 0.0:
			continue
		var rate: float = minf(_speed / maxf(clip_speed * body_scale, 0.01), RATE_CAP)
		var length: float = maxf(_clips.length_of(_first_clip(i)), 0.001)
		total += _weights[i]
		sum += _weights[i] * rate / length
	return sum / total if total > 0.001 else 0.0


func _first_clip(gait: int) -> String:
	match gait:
		Gait.WALK:
			return String(WALK_CLIPS[0])
		Gait.RUN:
			return String(RUN_CLIPS[0])
		Gait.SPRINT:
			return SPRINT_CLIP
		Gait.CROUCH_RUN:
			return String(CROUCH_RUN_CLIPS[0])
		Gait.CROUCH_IDLE:
			return CROUCH_IDLE_CLIP
	return IDLE_CLIP


func _group_pose(first: int, last: int) -> PlaceholderClips.Pose:
	var result: PlaceholderClips.Pose = null
	var total: float = 0.0
	for i in range(first, last):
		var weight: float = _weights[i]
		if weight <= 0.001:
			continue
		var gait_pose: PlaceholderClips.Pose = _gait_pose(i)
		total += weight
		result = gait_pose if result == null else _mix(result, gait_pose, weight / total)
	if result == null:
		result = _gait_pose(first)
	return result


func _gait_pose(gait: int) -> PlaceholderClips.Pose:
	match gait:
		Gait.WALK:
			return _directional(WALK_CLIPS)
		Gait.RUN:
			return _directional(RUN_CLIPS)
		Gait.SPRINT:
			return _sample_cycle(SPRINT_CLIP)
		Gait.CROUCH_RUN:
			return _directional(CROUCH_RUN_CLIPS)
		Gait.CROUCH_IDLE:
			return _clips.sample_loop(CROUCH_IDLE_CLIP, _idle_time)
	return _clips.sample_loop(IDLE_CLIP, _idle_time)


## The clip at the shared cycle position.
func _sample_cycle(clip_name: String) -> PlaceholderClips.Pose:
	return _clips.sample_loop(clip_name, _phase * _clips.length_of(clip_name))


## The two clips of `names` (front, right, back, left) nearest to the movement angle, blended by it.
func _directional(names: Array) -> PlaceholderClips.Pose:
	var scaled: float = fposmod(_angle, TAU) / (TAU * 0.25)
	var base: float = floorf(scaled)
	var first: int = int(base) % 4
	var along: float = scaled - base
	var from_pose: PlaceholderClips.Pose = _sample_cycle(String(names[first]))
	if along < 0.001:
		return from_pose
	return _mix(from_pose, _sample_cycle(String(names[(first + 1) % 4])), along)


static func _mix(a: PlaceholderClips.Pose, b: PlaceholderClips.Pose, weight: float) -> PlaceholderClips.Pose:
	var result := PlaceholderClips.Pose.new()
	result.points.resize(a.points.size())
	for i in a.points.size():
		result.points[i] = a.points[i].lerp(b.points[i], weight)
	result.axes.resize(a.axes.size())
	for i in a.axes.size():
		result.axes[i] = a.axes[i].lerp(b.axes[i], weight).normalized()
	return result
