class_name PlayerBodyReaction
extends RefCounted
## The placeholder body reactions of the player (Phase 1.5, item 5c), moved out of Player: the hit wobble
## (the Visual shifts and tilts away from a hit and eases back), the stagger lean, the kneel with its
## weary sway (stagger, grab, death) and the grab's short kneel. Visual only: the capsules and the
## hurtbox are not touched. The tuned exports (hit_recoil_*, stagger_*, grab_kneel_time and the
## *_recoil_scale ones) stay on the Player; this class reads them and writes only the Player's Visual.
## Placeholder code: real animations are expected to replace it.

var player: Player

## The hit wobble: 1 right after a hit, easing to 0; its scale (a guard hit wobbles less) and direction.
var recoil: float = 0.0
var recoil_direction: Vector3 = Vector3.ZERO
var recoil_scale: float = 1.0

var _visual_rest: Vector3 = Vector3.ZERO
var _lean_current: float = 0.0
var _lean_target: float = 0.0
var _kneeling: bool = false
var _kneel_current: float = 0.0
var _sway_time: float = 0.0
var _kneel_sway: bool = true
var _grab_kneel_left: float = 0.0


func _init(owner_player: Player) -> void:
	player = owner_player


## Remember where the Visual rests (called once in Player._ready, after the Visual is there).
func capture_rest() -> void:
	_visual_rest = player.visual.position


## A hit wobble: shift and tilt the Visual away along `direction`.
func start_recoil(direction: Vector3, scale: float) -> void:
	recoil = 1.0
	recoil_scale = scale
	recoil_direction = direction


## Lean the body forward (radians; 0 = upright). Eases in and out. Used by the stagger.
func set_lean(angle: float) -> void:
	_lean_target = angle


## Sink to a knee and sway. Used by the stagger, the grab and death.
func set_kneel(on: bool, sway: bool = true) -> void:
	if on and not _kneeling:
		_sway_time = 0.0
	_kneeling = on
	_kneel_sway = sway


## A grab connected on the ground: kneel for grab_kneel_time.
func start_grab_kneel() -> void:
	_grab_kneel_left = player.grab_kneel_time
	set_kneel(true)


## The grab's kneel is only a look: it ends after grab_kneel_time, or as soon as the player jumps, falls,
## or starts an action. (A posture-break stagger keeps its own kneel.)
func update_grab_kneel(delta: float) -> void:
	if _grab_kneel_left <= 0.0:
		return
	_grab_kneel_left -= delta
	var current := player.state_machine.current
	if current is StaggerState or current is DeadState:
		_grab_kneel_left = 0.0
		return
	if _grab_kneel_left <= 0.0 or not player.is_on_floor() or current is ActionState or current is AirState:
		_grab_kneel_left = 0.0
		set_kneel(false)


## The hit wobble, the lean and the kneel, applied to the Visual every frame. The yaw (facing) is left
## alone; only the position and the tilt are set here.
func update(delta: float) -> void:
	var leaning := not is_zero_approx(_lean_current) or not is_zero_approx(_lean_target)
	var kneeling := _kneeling or not is_zero_approx(_kneel_current)
	_lean_current = move_toward(_lean_current, _lean_target, delta * 4.0)
	_kneel_current = move_toward(_kneel_current, 1.0 if _kneeling else 0.0, delta * player.stagger_kneel_speed)
	if _kneeling:
		_sway_time += delta
	if recoil <= 0.0 and not leaning and not kneeling:
		return
	recoil = maxf(0.0, recoil - delta / maxf(player.hit_recoil_time, 0.001))
	var k := ease(recoil, 2.0)
	var kneel := ease(_kneel_current, -2.0)
	var visual := player.visual
	visual.position = _visual_rest + recoil_direction * player.hit_recoil_distance * recoil_scale * k \
			+ Vector3.DOWN * player.stagger_kneel_drop * kneel
	# Tilt the top toward the push, in the Visual's own (yawed) frame.
	var local_dir := Basis(Vector3.UP, visual.rotation.y).inverse() * recoil_direction
	var axis := Vector3.UP.cross(local_dir)
	# The weary sway while kneeling: a side roll and a slower nod of the head.
	var sway_scale := 1.0 if _kneel_sway else 0.0
	var sway := sin(_sway_time * player.stagger_sway_speed) * player.stagger_sway_angle * kneel * sway_scale
	var nod := sin(_sway_time * player.stagger_sway_speed * 0.6) * player.stagger_sway_angle * 0.5 * kneel * sway_scale
	visual.rotation.x = axis.x * player.hit_recoil_tilt * recoil_scale * k - _lean_current + nod
	visual.rotation.z = axis.z * player.hit_recoil_tilt * recoil_scale * k + sway
