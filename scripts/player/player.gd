class_name Player
extends CharacterBody3D
## Shared player data and helpers. Behavior lives in the states under StateMachine.

## Step 10: the death flow, for the death screen (DeadState emits them in this order).
## The player just died (the body goes down).
@warning_ignore("unused_signal")
signal death_started
## The Die / Resurrect prompt is up (`can_resurrect` false = the final death: no choice).
@warning_ignore("unused_signal")
signal death_prompt_shown(can_resurrect: bool)
## The player chose to die (or had no resurrection left): fade to black over `fade_time`, then the scene reloads.
@warning_ignore("unused_signal")
signal death_confirmed(fade_time: float)
## The player resurrected.
@warning_ignore("unused_signal")
signal resurrected

@export_group("Movement")
@export var run_speed: float = 6.5
@export var walk_speed: float = 2.5
@export var dash_speed: float = 9.0
@export var acceleration: float = 50.0
@export var deceleration: float = 60.0
@export var turn_speed: float = 18.0

@export_group("Jump")
## 9.88 with gravity 2.0, a 1.5x fall and a 1.5x apex band = the same ~2.46 m jump as 8.5 with 1.5 used
## to give, in about 0.88 s. If you change one of these, change the others to keep the height.
@export var jump_velocity: float = 9.88
@export var gravity_multiplier: float = 2.0
## Gravity multiple while falling (1.5 = a 50% faster descent than the climb).
@export var fall_gravity_factor: float = 1.5
## Landing faster than this (m/s downward) is a hard landing: a small camera shake (Step 11c).
@export var hard_land_speed: float = 14.0
## Landing faster than this (m/s downward) puffs a little dust (Step 11b).
@export var land_dust_speed: float = 5.0
## Off: no red mist or flecks on flesh hits (Step 11b; the deathblow keeps its red sparks).
@export var show_blood: bool = true
## Near the top of a jump (vertical speed within +/- this many m/s of zero) gravity is multiplied by
## apex_gravity_factor, so there is no hang at the peak.
@export var apex_speed_band: float = 2.0
@export var apex_gravity_factor: float = 1.5
@export var coyote_time: float = 0.1
## In the air your horizontal speed is kept; the move keys only add a push this strong (m/s^2) that can
## steer it or fight it (holding back slows you, left and right curve it) but never takes you above
## your run speed (or your current speed, if faster). Not used by the wall jump or air attacks.
@export var air_steer_acceleration: float = 8.0

@export_group("Footsteps (Step 11a)")
## Distance (m) walked between two footsteps, per gait. The sounds are in audio/sfx_data.tres.
@export var step_distance_walk: float = 1.0
@export var step_distance_run: float = 1.9
@export var step_distance_crouch: float = 0.9

@export_group("Crouch")
## Placeholder speed while crouched (m/s).
@export var crouch_speed: float = 2.0
## How fast you slow down to crouch_speed when entering crouch faster than that (m/s^2).
@export var crouch_decel: float = 12.0
## Seconds the mesh takes to ease between standing and crouched height (collision is instant).
@export var crouch_transition_time: float = 0.12
## Capsule height while standing and crouched. Crouch shrinks from the top; feet stay planted.
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.1
## Off = press to toggle crouch. On = crouch only while the button is held.
@export var crouch_is_hold: bool = false

@export_group("Reach and wall jump")
## Wall jump speed multiplier: up = jump_velocity * boost, sideways/back = run_speed * boost.
@export var wall_jump_boost: float = 1.2
## A wall counts if it is within this distance (m) of the capsule edge, at chest height.
@export var wall_range: float = 0.6
@export var max_wall_jumps: int = 2
## How directly the input must point toward/away from the wall (dot product, 0.5 = within 60 degrees).
@export var wall_input_threshold: float = 0.75
## Air jump presses this close to the floor (m) are left buffered for the landing jump.
@export var air_jump_ground_margin: float = 0.3

@export_group("Ledge")
## Hand zone: a ledge top counts if it is between these heights above the feet (m).
@export var ledge_zone_min: float = 1.4
@export var ledge_zone_max: float = 2.1
## How directly the input must point at the wall to grab a ledge (dot product, 0.5 = within 60 degrees).
@export var ledge_input_threshold: float = 0.5
## No ledge grab while rising faster than this (m/s). 99 = no limit (grab while rising too).
@export var ledge_max_rise_speed: float = 99.0
## Only grab a ledge while the jump button is held (stops accidental re-grabs after a drop).
@export var ledge_requires_jump_held: bool = true
## Gap (m) between the capsule and the wall edge at the landing spot on top.
@export var ledge_standoff: float = 0.1
## Hang: the capsule center hangs this far (m) below the ledge top, and this far (m) off the wall.
@export var hang_center_depth: float = 1.2
@export var hang_gap: float = 0.05
## Both hands must be on the ledge: two hand points this far (m) either side of the center.
@export var hang_hand_spacing: float = 0.3
## At a grab near a ledge end, the hang spot may shift up to this far (m) along the wall
## so both hands are on the ledge. If that is not enough, it auto-climbs instead.
@export var hang_adjust_max: float = 0.6
## Seconds to snap into the hanging spot after a grab.
@export var hang_snap_time: float = 0.1
@export var shimmy_speed: float = 1.5
## After a drop or leap, no ledge grab for this long (s).
@export var ledge_regrab_cooldown: float = 0.3

@export_group("Input")
@export var input_buffer_time: float = 0.15

@export_group("Combat")
## The equipped weapon: its combo, blade size, and rest pose.
@export var weapon: WeaponData
## Clock speed inside a normal slash's hit window (ground combo, crouch, air, dash, and draw
## attacks; not the thrusts, helm splitters, or deathblow). Below 1 the swing is slower, so it does
## not look instant: the hit window and the attack are longer by duration x (1/speed - 1).
@export_range(0.2, 1.0, 0.05) var slash_active_speed: float = 0.7

@export_group("Sheath")
## The sword starts sheathed (in the scabbard at the left hip).
@export var start_sheathed: bool = true
## Seconds without an attack or dodge (counted only while in Locomotion or Crouch) before a
## drawn sword sheathes itself. 0 = never.
@export var auto_sheathe_time: float = 5.0

## True while the sword is in its scabbard. Visual only: it changes no movement or rules.
var sheathed: bool = false
@export_group("Hurtbox and health")
## The Area3D that takes hits (an Area3D with hurtbox.gd, Team = Player, and a CapsuleShape3D child).
## Created in code if the scene has none.
@export var hurtbox: Hurtbox
## The player's health (a Node with combatant.gd). Created in code if the scene has none.
@export var combatant: Combatant
## Hurtbox shapes per posture (height / bottom offset). Crouched = crouch, in the air = air.
@export var stand_hurtbox: HurtboxProfile = preload("res://resources/hurtbox/stand.tres")
@export var crouch_hurtbox: HurtboxProfile = preload("res://resources/hurtbox/crouch.tres")
@export var air_hurtbox: HurtboxProfile = preload("res://resources/hurtbox/air.tres")
@export var max_health: float = 100.0
@export_group("Heal and resurrection")
## Healing gourd charges per run (a scene reload gives them back) and the health one heal restores.
@export var max_heal_charges: int = 3
@export var heal_amount: float = 40.0
## Off: the heal does not start at full health (no charge wasted). On: it plays and costs a charge anyway.
@export var allow_heal_at_full_health: bool = false
## Resurrections per run, the share of max health you come back with, and the invulnerable time (s) after.
@export var max_resurrections: int = 2
@export_range(0.05, 1.0) var resurrect_health_fraction: float = 0.5
@export var resurrect_invulnerable_time: float = 2.0
## Hit wobble (cosmetic): the whole Visual shifts this far (m) away from the attacker, tilts this far
## (radians), and eases back over this many seconds.
@export var hit_recoil_distance: float = 0.15
@export var hit_recoil_tilt: float = 0.2
@export var hit_recoil_time: float = 0.25
@export_group("Posture and deathblow")
## A deathblow needs an enemy with an open window within this distance (m, flat) ...
@export var deathblow_range: float = 2.5
## ... and in front of you: within this total cone (degrees) around where you face.
@export var deathblow_facing_degrees: float = 120.0
## How far (radians) the body leans forward while staggered.
@export var stagger_lean: float = 0.5
## While staggered the body also sinks to a knee (visual only: how far, m, and how fast, per second),
## and sways side to side (radians, and speed in radians per second).
@export var stagger_kneel_drop: float = 0.45
@export var stagger_kneel_speed: float = 3.0
@export var stagger_sway_angle: float = 0.12
@export var stagger_sway_speed: float = 2.0
@export_group("Enemy heads")
## Landing on an enemy's head right after a jump-over (a sweep dodged in the air) bounces you up at
## this speed (m/s), so you can dive with a helm splitter. Any other landing on a head slides you off
## at head_slide_speed (m/s). It counts as a head when your feet are this far (m) above the enemy's origin.
@export var head_bounce_velocity: float = 7.6
@export var head_slide_speed: float = 4.0
@export var head_min_height: float = 1.2
@export_group("Guard")
## A guard or deflect uses this share of the hit's hitstop (the plain hit uses all of it).
@export var guard_hitstop_factor: float = 0.5
## The player wobble on a plain guard and on a deflect, as a share of the hit wobble.
@export var guard_recoil_scale: float = 0.7
@export var deflect_recoil_scale: float = 0.35
## Guard break: a perilous attack that hits you while you guard drops the guard. The body wobble is
## this many times a plain hit's, and guard presses are ignored for the lockout (s; 0 = none).
@export var guard_break_recoil_scale: float = 1.6
@export var guard_break_lockout: float = 0.0
## A grab that connects also sinks the player to a knee (visual only) for this long (s), on the ground.
@export var grab_kneel_time: float = 0.8
## Knockback is a push that eases out over this many seconds (the distance comes from the hit).
@export var knockback_time: float = 0.2
## Name of the hurtbox posture in use (debug overlay).
var hurtbox_profile_name: String = "stand"
## Seconds left in which guard presses are ignored (after a guard break).
var _guard_lockout: float = 0.0
var _grab_kneel_left: float = 0.0

## Seconds since the last attack or dodge (counts only in Locomotion or Crouch).
var sheathe_idle: float = 0.0
## Set by GuardState: forces walking.
var walk_only: bool = false
## Step 10: gourd charges and resurrections left (set in _ready from the exports).
var heal_charges: int = 0
var resurrections_left: int = 0
## The enemy that was locked when the player died (DeadState re-locks it on a resurrection).
var relock_target: Node3D
var _death_pending: bool = false
var _revive_invulnerable_left: float = 0.0
var _kneel_sway: bool = true
## Set by actions during their i-frame window (read by the damage system in Step 4).
var invulnerable: bool = false
var coyote_timer: float = 0.0
var input_buffer: InputBuffer
var is_crouched: bool = false
## Mid-air reach is once per airtime; a wall jump restores it. Landing resets both.
var reach_ready: bool = true
var wall_jumps_used: int = 0
## The next attack of the air tap loop (empty = start from the first). Landing resets it.
var air_loop_next: ActionData
## The helm splitter is once per airtime; landing (reset_air_actions) clears it.
var helm_used: bool = false
## Set by try_air_jump() when it returns true: the surface normal of the wall to jump from.
var wall_normal: Vector3 = Vector3.ZERO
## Set by try_ledge_grab() when it returns true (read by the LedgeClimb state).
var ledge_stand_pos: Vector3 = Vector3.ZERO
var ledge_wall_normal: Vector3 = Vector3.ZERO
## Debug: where the last ledge was found, and when (msec).
var ledge_hang_pos: Vector3 = Vector3.ZERO
var ledge_hang_fits: bool = false
var ledge_top_y: float = 0.0
var last_ledge_point: Vector3 = Vector3.ZERO
var last_ledge_ms: int = -100000
## No ledge grab until this time (msec); set by a drop or leap.
var ledge_block_until_ms: int = 0
## Set by the ledge hang state: the next WallJump goes away from the wall and is not counted.
var wall_jump_forced_away: bool = false

var _headroom_shape: CapsuleShape3D
var _hurt_shape: CollisionShape3D
var _recoil: float = 0.0
var _recoil_direction: Vector3 = Vector3.ZERO
var _recoil_scale: float = 1.0
## A repulse (an enemy's special deflect, Step 7b) is waiting to cancel the current attack.
var _repulse_pending: bool = false
var _repulse_direction: Vector3 = Vector3.ZERO
var _knockback_velocity: Vector3 = Vector3.ZERO
## Metres walked since the last footstep.
var _step_travelled: float = 0.0
var _knockback_decel: float = 0.0
var _visual_rest: Vector3 = Vector3.ZERO
var _hurt_capsule: CapsuleShape3D
var _nose_drop: float = 0.4
var _visual_tween: Tween
var _reach_arms: ReachArms
## The enemy a deathblow was started on (read by DeathblowState).
var deathblow_target: Node3D
var _stagger_pending: bool = false
var _lean_current: float = 0.0
var _lean_target: float = 0.0
var _kneeling: bool = false
var _kneel_current: float = 0.0
var _sway_time: float = 0.0
## The placeholder sword (found in _ready). Null if the scene has no SwordVisual.
var sword_visual: SwordVisual

@onready var visual: Node3D = $Visual
@onready var camera_rig: Node3D = $CameraRig
@onready var lock_on: LockOn = $LockOn
@onready var state_machine: StateMachine = $StateMachine
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _body_mesh: MeshInstance3D = $Visual/Body
@onready var _nose: MeshInstance3D = $Visual/Nose
## The left arm that lifts the gourd while healing (Step 11, HealState drives it).
@onready var heal_arm: HealArm = $Visual/HealArm


func _ready() -> void:
	input_buffer = InputBuffer.new(input_buffer_time)
	Fx.blood_enabled = show_blood
	_nose_drop = stand_height - _nose.position.y
	_reach_arms = get_node_or_null("Visual/ReachArms") as ReachArms
	sword_visual = get_node_or_null("Visual/SwordVisual") as SwordVisual
	if sword_visual != null and weapon != null:
		sword_visual.setup(weapon)
	sheathed = start_sheathed and weapon != null
	if sheathed and sword_visual != null:
		sword_visual.snap_sheathed()
	_headroom_shape = CapsuleShape3D.new()
	_headroom_shape.radius = 0.38
	_headroom_shape.height = stand_height - 0.07
	add_to_group("player")
	heal_charges = max_heal_charges
	resurrections_left = max_resurrections
	_visual_rest = visual.position
	_setup_hurtbox()
	if state_machine.get_node_or_null("Guard") == null:
		push_warning("Player: no Guard state under StateMachine; creating one in code (add a Node named Guard with guard_state.gd).")
		var guard_state := GuardState.new()
		guard_state.name = "Guard"
		state_machine.add_child(guard_state)
	state_machine.setup(self)
	state_machine.start()


## The hit wobble: shift and tilt the Visual away from the hit, then ease back. The yaw (facing) is
## left alone; only the position and the tilt are set here.
func _process(delta: float) -> void:
	var leaning := not is_zero_approx(_lean_current) or not is_zero_approx(_lean_target)
	var kneeling := _kneeling or not is_zero_approx(_kneel_current)
	_lean_current = move_toward(_lean_current, _lean_target, delta * 4.0)
	_kneel_current = move_toward(_kneel_current, 1.0 if _kneeling else 0.0, delta * stagger_kneel_speed)
	if _kneeling:
		_sway_time += delta
	if _recoil <= 0.0 and not leaning and not kneeling:
		return
	_recoil = maxf(0.0, _recoil - delta / maxf(hit_recoil_time, 0.001))
	var k := ease(_recoil, 2.0)
	var kneel := ease(_kneel_current, -2.0)
	visual.position = _visual_rest + _recoil_direction * hit_recoil_distance * _recoil_scale * k \
			+ Vector3.DOWN * stagger_kneel_drop * kneel
	# Tilt the top toward the push, in the Visual's own (yawed) frame.
	var local_dir := Basis(Vector3.UP, visual.rotation.y).inverse() * _recoil_direction
	var axis := Vector3.UP.cross(local_dir)
	# The weary sway while kneeling: a side roll and a slower nod of the head.
	var sway_scale := 1.0 if _kneel_sway else 0.0
	var sway := sin(_sway_time * stagger_sway_speed) * stagger_sway_angle * kneel * sway_scale
	var nod := sin(_sway_time * stagger_sway_speed * 0.6) * stagger_sway_angle * 0.5 * kneel * sway_scale
	visual.rotation.x = axis.x * hit_recoil_tilt * _recoil_scale * k - _lean_current + nod
	visual.rotation.z = axis.z * hit_recoil_tilt * _recoil_scale * k + sway


func _physics_process(delta: float) -> void:
	input_buffer.tick(delta)
	if _guard_lockout > 0.0:
		_guard_lockout -= delta
		input_buffer.clear(&"guard")
	_update_grab_kneel(delta)
	combatant.tick_guard(delta, state_machine.current is GuardState, state_machine.current is ActionState)
	combatant.tick_posture(delta, _posture_regen_paused())
	_revive_invulnerable_left = maxf(_revive_invulnerable_left - delta, 0.0)
	_update_death()
	_update_stagger()
	_update_repulse()
	_try_deathblow()
	_try_heal()
	state_machine.physics_update(delta)
	# DeadState can reload the scene during the update; this node is out of the tree then.
	if not is_inside_tree():
		return
	_update_auto_sheathe(delta)
	# A knockback push is added on top of the state's own velocity for the move, then taken off
	# again, so the states never see it (they set or ease the velocity themselves).
	var push := _knockback_velocity
	if push != Vector3.ZERO and not state_machine.current is LedgeClimbState:
		velocity.x += push.x
		velocity.z += push.z
		_knockback_velocity = push.move_toward(Vector3.ZERO, _knockback_decel * delta)
	else:
		push = Vector3.ZERO
		_knockback_velocity = Vector3.ZERO
	var was_airborne := not is_on_floor()
	var fall_speed := -velocity.y
	move_and_slide()
	if was_airborne and is_on_floor():
		if fall_speed >= hard_land_speed:
			Fx.play(get_tree(), Fx.Kind.HARD_LAND, global_position)
		elif fall_speed >= land_dust_speed:
			Fx.play(get_tree(), Fx.Kind.LAND_DUST, global_position)
	velocity.x -= push.x
	velocity.z -= push.z
	_update_enemy_head()
	_update_footsteps(delta)
	_update_hurtbox()


## Movement input in world space, relative to the camera. Length 0 to 1.
func get_move_input() -> Vector3:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := Basis(Vector3.UP, camera_rig.global_rotation.y)
	return cam_basis * Vector3(input_dir.x, 0.0, input_dir.y)


func get_move_speed() -> float:
	return walk_speed if walk_only else run_speed


func get_facing_direction() -> Vector3:
	# Yaw only, so the hit wobble's tilt never changes where attacks aim.
	return Basis(Vector3.UP, visual.global_rotation.y) * Vector3.FORWARD


func apply_gravity(delta: float) -> void:
	velocity += get_gravity_now() * delta


## The gravity pulling on the player right now (a vector like get_gravity()): the base gravity times
## the jump phase (faster near the apex, faster again while falling). The dive and the helm hover
## multiply this, so their factors keep their meaning.
func get_gravity_now() -> Vector3:
	var factor := 1.0
	if velocity.y <= apex_speed_band:
		factor = apex_gravity_factor
	if velocity.y < 0.0:
		factor = maxf(factor, fall_gravity_factor)
	return get_gravity() * gravity_multiplier * factor


## Air control for a normal jump or fall: momentum stays, the move input only steers it.
func apply_air_steering(delta: float) -> void:
	var move_dir := get_move_input()
	if move_dir.length_squared() < 0.0001:
		return
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var cap := maxf(get_move_speed(), horizontal.length())
	horizontal += move_dir * air_steer_acceleration * delta
	if horizontal.length() > cap:
		horizontal = horizontal.normalized() * cap
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func start_jump() -> void:
	Sfx.play(get_tree(), Sfx.Id.JUMP)
	velocity.y = jump_velocity
	coyote_timer = 0.0


## If overspeed_decel > 0 and there is input while faster than speed, slow down at that rate.
func apply_horizontal_movement(delta: float, speed: float, overspeed_decel: float = -1.0) -> void:
	var move_dir := get_move_input()
	var target_vel := move_dir * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if move_dir.length_squared() > 0.0 else deceleration
	if overspeed_decel > 0.0 and move_dir.length_squared() > 0.0 and horizontal.length() > speed:
		rate = overspeed_decel
	horizontal = horizontal.move_toward(target_vel, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func decelerate(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(Vector3.ZERO, deceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func set_horizontal_velocity(v: Vector3) -> void:
	velocity.x = v.x
	velocity.z = v.z


## Step 9: the flat direction from the player to the locked target, or Vector3.ZERO when not locked on.
func get_lock_direction() -> Vector3:
	if not lock_on.has_target():
		return Vector3.ZERO
	var to := lock_on.get_target_position() - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return Vector3.ZERO
	return to.normalized()


## Turn smoothly toward the movement input (if any). While locked on, toward the target instead
## (so walking and dashing backward still face it).
func face_input(delta: float) -> void:
	var lock_dir := get_lock_direction()
	if lock_dir != Vector3.ZERO:
		face_direction(lock_dir, delta)
		return
	var move_dir := get_move_input()
	if move_dir.length_squared() > 0.01:
		face_direction(move_dir, delta)


func face_direction(dir: Vector3, delta: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


## Turn instantly (used when an action starts).
func snap_facing(dir: Vector3) -> void:
	visual.rotation.y = atan2(-dir.x, -dir.z)


## Like snap_facing(), but while locked on the body faces the target instead of `dir` (the dodge and
## the slide still move along `dir`).
func snap_facing_lock_aware(dir: Vector3) -> void:
	var lock_dir := get_lock_direction()
	snap_facing(lock_dir if lock_dir != Vector3.ZERO else dir)


## Resize the body. The collision capsule changes instantly (sizes are set on the shape
## resource, never by scaling the node); the mesh and nose ease over crouch_transition_time.
## The bottom stays at the feet.
func set_crouched(crouched: bool) -> void:
	is_crouched = crouched
	var height := crouch_height if crouched else stand_height
	var shape := _collision_shape.shape as CapsuleShape3D
	shape.height = height
	_collision_shape.position.y = height * 0.5
	var mesh := _body_mesh.mesh as CapsuleMesh
	var nose_y := height - _nose_drop
	if _visual_tween != null:
		_visual_tween.kill()
	if crouch_transition_time <= 0.0:
		mesh.height = height
		_body_mesh.position.y = height * 0.5
		_nose.position.y = nose_y
		return
	_visual_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_visual_tween.tween_property(mesh, "height", height, crouch_transition_time)
	_visual_tween.tween_property(_body_mesh, "position:y", height * 0.5, crouch_transition_time)
	_visual_tween.tween_property(_nose, "position:y", nose_y, crouch_transition_time)


## True if there is room above to stand up (checked with a standing-sized capsule).
func can_stand() -> bool:
	return _fits_standing_at(global_position)


## True if a standing capsule fits with its feet at the given point.
func _fits_standing_at(feet: Vector3) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _headroom_shape
	params.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (0.07 + _headroom_shape.height * 0.5))
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func reset_air_actions() -> void:
	reach_ready = true
	wall_jumps_used = 0
	air_loop_next = null
	helm_used = false


func play_reach_arms() -> void:
	if _reach_arms != null:
		_reach_arms.play()


## Slide pose: arms held straight forward at crouched shoulder height until stop_slide_arms().
func play_climb_arms() -> void:
	if _reach_arms != null:
		_reach_arms.hold_up()


func release_arms() -> void:
	if _reach_arms != null:
		_reach_arms.release()


func play_slide_arms() -> void:
	if _reach_arms != null:
		_reach_arms.hold_forward(crouch_height - _nose_drop)


func stop_slide_arms() -> void:
	if _reach_arms != null:
		_reach_arms.release()


## True if the equipped weapon has at least one combo attack.
## R: draw the sword (without attacking) or sheathe it. Ignored while it is still moving.
func toggle_sheathe() -> void:
	if weapon == null or (sword_visual != null and sword_visual.is_busy()):
		return
	set_sheathed(not sheathed)


## Switch between sheathed and drawn (plays the arm animation). Changes no rules.
func set_sheathed(value: bool) -> void:
	if weapon == null or sheathed == value:
		return
	sheathed = value
	sheathe_idle = 0.0
	Sfx.play(get_tree(), Sfx.Id.SHEATHE if value else Sfx.Id.DRAW)
	if sword_visual == null:
		return
	if sheathed:
		sword_visual.play_sheathe()
	else:
		sword_visual.play_draw()


## Combat just happened: restart the auto-sheathe timer. Step 4 also calls this when hit.
func notify_combat() -> void:
	sheathe_idle = 0.0


## Find or create the Hurtbox and Combatant, and connect them (i-frames, damage, death).
func _setup_hurtbox() -> void:
	if combatant == null:
		combatant = get_node_or_null("Combatant") as Combatant
	if combatant == null:
		push_warning("Player: no Combatant set; creating one in code (add a Node with combatant.gd).")
		combatant = Combatant.new()
		combatant.name = "Combatant"
		add_child(combatant)
	combatant.max_health = max_health
	combatant.health = max_health
	combatant.fast_regen_on_guard = true
	if hurtbox == null:
		hurtbox = get_node_or_null("Hurtbox") as Hurtbox
	if hurtbox == null:
		push_warning("Player: no Hurtbox set; creating one in code (add an Area3D with hurtbox.gd).")
		hurtbox = Hurtbox.new()
		hurtbox.name = "Hurtbox"
		hurtbox.team = Layers.Team.PLAYER
		add_child(hurtbox)
	hurtbox.team = Layers.Team.PLAYER
	hurtbox.collision_layer = Layers.hurtbox_layer(Layers.Team.PLAYER)
	hurtbox.combatant = combatant
	hurtbox.is_invulnerable = func() -> bool: return invulnerable or _revive_invulnerable_left > 0.0
	for child: Node in hurtbox.get_children():
		if child is CollisionShape3D:
			_hurt_shape = child as CollisionShape3D
			break
	if _hurt_shape == null:
		_hurt_shape = CollisionShape3D.new()
		hurtbox.add_child(_hurt_shape)
	# This hurtbox owns its capsule (the height changes with the posture).
	_hurt_capsule = CapsuleShape3D.new()
	_hurt_capsule.radius = (_collision_shape.shape as CapsuleShape3D).radius
	_hurt_shape.shape = _hurt_capsule
	combatant.guard_facing = get_facing_direction
	combatant.damaged.connect(_on_damaged)
	combatant.hit_guarded.connect(_on_guarded)
	combatant.hit_deflected.connect(_on_deflected)
	combatant.guard_broken.connect(_on_guard_broken)
	combatant.repulsed.connect(_on_repulsed)
	combatant.posture_broken.connect(_on_posture_broken)
	combatant.died.connect(_on_died)
	_update_hurtbox()


## Resize the hurtbox for the current posture: crouched, in the air (not while hanging or climbing a
## ledge), or standing. The body capsule is not touched.
func _update_hurtbox() -> void:
	if _hurt_capsule == null:
		return
	var profile := stand_hurtbox
	var profile_name := "stand"
	var on_ledge := state_machine.current is LedgeHangState or state_machine.current is LedgeClimbState
	if is_crouched:
		profile = crouch_hurtbox
		profile_name = "crouch"
	elif not is_on_floor() and not on_ledge:
		profile = air_hurtbox
		profile_name = "air"
	var height := maxf(profile.height, _hurt_capsule.radius * 2.0)
	_hurt_capsule.height = height
	_hurt_shape.position.y = profile.bottom_offset + height * 0.5
	hurtbox_profile_name = profile_name


## Footsteps (Step 11a): one every step_distance_* metres walked on the floor, only in the walking
## states (not in actions, the air, or ledges). The gait comes from the speed (crouch, walk, run).
func _update_footsteps(delta: float) -> void:
	var current := state_machine.current
	var walking := current is LocomotionState or current is CrouchState or current is GuardState \
			or current is DashState or current is HealState
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if not walking or not is_on_floor() or horizontal < 0.5:
		# Standing still: the first step comes soon after setting off.
		_step_travelled = step_distance_walk * 0.6
		return
	var id := Sfx.Id.FOOTSTEP_WALK
	var stride := step_distance_walk
	if is_crouched:
		id = Sfx.Id.FOOTSTEP_CROUCH
		stride = step_distance_crouch
	elif horizontal > walk_speed * 1.5:
		id = Sfx.Id.FOOTSTEP_RUN
		stride = step_distance_run
	_step_travelled += horizontal * delta
	if _step_travelled >= stride:
		_step_travelled -= stride
		Sfx.play(get_tree(), id)


## Took a hit (the Combatant already lost the health): the combat timer restarts, the hitstop plays,
## and a hanging player is knocked off the ledge. A full posture staggers (_on_posture_broken).
func _on_damaged(hit: HitData, _amount: float) -> void:
	_recoil = 1.0
	_recoil_scale = 1.0
	_recoil_direction = hit.direction
	apply_knockback(hit.direction, hit.knockback * combatant.knockback_multiplier_hit, hit.knockback_time)
	notify_combat()
	Hitstop.request(get_tree(), hit.hitstop)
	var fx_kind := Fx.Kind.HURT
	if hit.grab:
		fx_kind = Fx.Kind.GRAB
	elif hit.perilous:
		fx_kind = Fx.Kind.PERILOUS_HIT
	Fx.play(get_tree(), fx_kind, hit.point, hit.direction)
	var hang := state_machine.current as LedgeHangState
	if hang != null:
		hang.knock_off()


## The guard blocked a hit (no health lost unless chip damage is on): a heavier wobble, an orange
## blade flash, a shorter hitstop, and the knockback. (The posture damage is added by the Combatant.)
func _on_guarded(hit: HitData, _chip: float) -> void:
	_guard_reaction(hit, false)
	apply_knockback(hit.direction, hit.knockback * combatant.knockback_multiplier_guard, hit.knockback_time)


## A perilous attack hit through the guard: the guard drops (back to Locomotion or Air) and the sword
## is knocked aside (SwordVisual.play_guard_break). The damage and the knockback are the plain hit's
## (_on_damaged ran just before this).
func _on_guard_broken(hit: HitData) -> void:
	Fx.play(get_tree(), Fx.Kind.GUARD_BREAK, hit.point, hit.direction)
	_recoil_scale = guard_break_recoil_scale
	if state_machine.current is GuardState:
		state_machine.transition_to(&"Locomotion" if is_on_floor() else &"Air")
	_guard_lockout = guard_break_lockout
	if hit.grab and is_on_floor() and grab_kneel_time > 0.0:
		_grab_kneel_left = grab_kneel_time
		set_stagger_kneel(true)
	if sword_visual != null:
		var local_dir := Basis(Vector3.UP, visual.rotation.y).inverse() * -hit.direction
		sword_visual.play_guard_break(local_dir.x)


## The grab's kneel is only a look: it ends after grab_kneel_time, or as soon as the player jumps, falls,
## or starts an action. (A posture-break stagger keeps its own kneel.)
func _update_grab_kneel(delta: float) -> void:
	if _grab_kneel_left <= 0.0:
		return
	_grab_kneel_left -= delta
	var current := state_machine.current
	if current is StaggerState or current is DeadState:
		_grab_kneel_left = 0.0
		return
	if _grab_kneel_left <= 0.0 or not is_on_floor() or current is ActionState or current is AirState:
		_grab_kneel_left = 0.0
		set_stagger_kneel(false)


## A deflect: a lighter wobble, a white blade flash and the blade flick, and a softer knockback.
func _on_deflected(hit: HitData) -> void:
	_guard_reaction(hit, true)
	apply_knockback(hit.direction, hit.knockback * combatant.knockback_multiplier_deflect, hit.knockback_time)


func _guard_reaction(hit: HitData, deflect: bool) -> void:
	notify_combat()
	Hitstop.request(get_tree(), hit.hitstop * guard_hitstop_factor)
	var fx_kind := Fx.Kind.GUARD
	if deflect:
		fx_kind = Fx.Kind.DEFLECT_PERILOUS if hit.perilous else Fx.Kind.DEFLECT
	Fx.play(get_tree(), fx_kind, hit.point, hit.direction)
	_recoil = 1.0
	_recoil_scale = deflect_recoil_scale if deflect else guard_recoil_scale
	_recoil_direction = hit.direction
	if sword_visual != null:
		# Which side of the player the attacker is on, in the Visual's own frame.
		var local_dir := Basis(Vector3.UP, visual.rotation.y).inverse() * -hit.direction
		if deflect:
			sword_visual.play_deflect(hit, local_dir.x)
		else:
			sword_visual.play_guard_hit(false, local_dir.x)


## One of the player's hits was repulsed by an enemy (Step 7b): bounced back and the swing is cut
## short (applied at the start of the next physics frame, see _update_repulse). No stun: the player
## can guard, jump, or dodge at once, and the combo is back at attack 1.
func _on_repulsed(hit: HitData, distance: float) -> void:
	Fx.play(get_tree(), Fx.Kind.REPULSE, hit.point, hit.direction)
	notify_combat()
	apply_knockback(-hit.direction, distance)
	_recoil = 1.0
	_recoil_scale = 1.0
	_recoil_direction = -hit.direction
	_repulse_pending = true
	_repulse_direction = -hit.direction


## Cut the attack that was repulsed (the state machine is not touched in the middle of a sweep) and
## flick the blade. Leaving the attack resets the combo. Anything else the player is doing stays.
func _update_repulse() -> void:
	if not _repulse_pending:
		return
	_repulse_pending = false
	var current := state_machine.current
	if current is AttackState:
		state_machine.transition_to(&"Crouch" if is_crouched else &"Locomotion")
	elif current is AirAttackState or current is HelmSplitterState:
		state_machine.transition_to(&"Air")
	if sword_visual != null:
		var local_dir := Basis(Vector3.UP, visual.rotation.y).inverse() * -_repulse_direction
		sword_visual.play_guard_hit(true, local_dir.x)


## Posture is full: stagger as soon as nothing is in the way (a ledge climb finishes first).
func _on_posture_broken() -> void:
	_stagger_pending = true
	Fx.play(get_tree(), Fx.Kind.POSTURE_BREAK, global_position + Vector3.UP * 1.2)


func _update_stagger() -> void:
	if not _stagger_pending:
		return
	var current := state_machine.current
	if current is StaggerState or current is DeadState:
		_stagger_pending = false
		return
	if current is LedgeClimbState or current is DeathblowState:
		return
	_stagger_pending = false
	var hang := current as LedgeHangState
	if hang != null:
		hang.knock_off()
	state_machine.transition_to(&"Stagger")


## Lean the body forward (radians; 0 = upright). Eases in and out. Used by the stagger.
func set_stagger_lean(angle: float) -> void:
	_lean_target = angle


## Sink to a knee and sway (visual only; the capsules and the hurtbox are not touched). Used by the stagger.
func set_stagger_kneel(on: bool, sway: bool = true) -> void:
	if on and not _kneeling:
		_sway_time = 0.0
	_kneeling = on
	_kneel_sway = sway


## Standing on an enemy's head: after a jump-over the landing is the counter and bounces you up (a
## helm splitter from there), otherwise you are pushed off sideways. Uses the same easing push as knockback.
func _update_enemy_head() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider() as Node3D
		if body == null or not body.is_in_group(&"enemy") or collision.get_normal().y < 0.35:
			continue
		if global_position.y < body.global_position.y + head_min_height:
			continue
		var enemy := body as Enemy
		if enemy != null and state_machine.current is AirState and velocity.y <= 0.0 \
				and enemy.on_stomped():
			velocity.y = head_bounce_velocity
			return
		var away := global_position - body.global_position
		away.y = 0.0
		if away.length_squared() < 0.0001:
			away = -get_facing_direction()
		away.y = 0.0
		_knockback_velocity = away.normalized() * head_slide_speed
		_knockback_decel = head_slide_speed / 0.15
		return


## Posture does not regenerate while attacking, dashing, or dodging.
func _posture_regen_paused() -> bool:
	var current := state_machine.current
	var action_state := current as ActionState
	if action_state != null:
		return action_state.action.pauses_posture_regen
	return current is DashState


## An enemy with an open deathblow window within reach and in front, or null.
func find_deathblow_target() -> Node3D:
	var best: Node3D = null
	var best_distance := deathblow_range
	var facing := get_facing_direction()
	facing.y = 0.0
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var enemy := node as Node3D
		var enemy_combatant := Combatant.of(enemy)
		if enemy == null or enemy_combatant == null or not enemy_combatant.deathblow_open:
			continue
		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0.0
		var distance := to_enemy.length()
		if distance > best_distance:
			continue
		if distance > 0.01 and facing.length_squared() > 0.0001 and facing.normalized().dot(to_enemy.normalized()) \
				< cos(deg_to_rad(deathblow_facing_degrees * 0.5)):
			continue
		best = enemy
		best_distance = distance
	return best


## A fresh attack press next to a stunned enemy is a deathblow, not a normal attack.
func _try_deathblow() -> void:
	if weapon == null or not input_buffer.has_pressed(&"attack") or not is_on_floor():
		return
	var current := state_machine.current
	if current is StaggerState or current is DeathblowState or current is DeadState or current is AirState \
			or current is WallJumpState or current is LedgeHangState or current is LedgeClimbState:
		return
	var action_state := current as ActionState
	if action_state != null and (not action_state.action.can_cancel(action_state.action_time) \
			or action_state.action.is_hit_active(action_state.action_time)):
		return
	if is_crouched and not can_stand():
		return
	var target := find_deathblow_target()
	if target == null:
		return
	input_buffer.consume(&"attack")
	deathblow_target = target
	state_machine.transition_to(&"Deathblow")


## Push the player away along `direction` by about `distance` metres, easing out over `time` seconds
## (a heavy hit can ask for a longer one; 0 or less = knockback_time).
func apply_knockback(direction: Vector3, distance: float, time: float = -1.0) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	var duration := time if time > 0.0 else knockback_time
	if distance <= 0.0 or duration <= 0.0 or flat.length_squared() < 0.0001:
		return
	_knockback_velocity = flat.normalized() * (2.0 * distance / duration)
	_knockback_decel = _knockback_velocity.length() / duration


## Health hit 0 (Step 10): go to the Dead state as soon as nothing is in the way (see _update_death).
func _on_died() -> void:
	_death_pending = true


## A ledge climb finishes first (it is scripted); anything else is left at once for Dead.
func _update_death() -> void:
	if not _death_pending:
		return
	var current := state_machine.current
	if current is DeadState:
		_death_pending = false
		return
	if current is LedgeClimbState:
		return
	_death_pending = false
	state_machine.transition_to(&"Dead")


## Called by DeadState when the player chooses to resurrect: spends one, comes back at a share of the
## max health with no posture, and is invulnerable for a moment. The enemy is not touched.
func resurrect() -> void:
	resurrections_left = maxi(resurrections_left - 1, 0)
	combatant.revive(resurrect_health_fraction)
	Fx.play(get_tree(), Fx.Kind.RESURRECT, global_position)
	_revive_invulnerable_left = resurrect_invulnerable_time
	notify_combat()


## Start the heal if `heal` was just pressed and the player is in a state that allows it (Locomotion,
## Crouch, or Dash). Crouched under a low ceiling cannot heal (it stands you up first).
func _try_heal() -> void:
	if not Input.is_action_just_pressed(&"heal"):
		return
	if heal_charges <= 0 or combatant.dead or combatant.vulnerable:
		return
	if not allow_heal_at_full_health and combatant.health >= combatant.max_health:
		return
	var current := state_machine.current
	if not (current is LocomotionState or current is CrouchState or current is DashState):
		return
	if is_crouched and not can_stand():
		return
	state_machine.transition_to(&"Heal")


## One of the player's attacks connected: restart the auto-sheathe timer and request the hitstop.
func on_hit_landed(hit: HitData) -> void:
	notify_combat()
	Hitstop.request(get_tree(), hit.hitstop)
	var fx_kind := Fx.Kind.HIT_LANDED
	if hit.outcome == HitData.Outcome.DEFLECT:
		fx_kind = Fx.Kind.DEFLECT
	elif hit.outcome == HitData.Outcome.GUARD:
		fx_kind = Fx.Kind.GUARD
	elif hit.action != null and hit.action.charge_time > 0.0:
		fx_kind = Fx.Kind.HIT_LANDED_CHARGED
	Fx.play(get_tree(), fx_kind, hit.point, hit.direction)


## Called by ActionState when any action starts. Attacks leave the sword drawn; attacks and
## dodges restart the auto-sheathe timer.
func on_action_started(kind: ActionData.Kind) -> void:
	if kind == ActionData.Kind.ATTACK:
		sheathed = false
		notify_combat()
	elif kind == ActionData.Kind.DODGE:
		notify_combat()


func _update_auto_sheathe(delta: float) -> void:
	if sheathed or weapon == null or auto_sheathe_time <= 0.0:
		return
	var current := state_machine.get_current_name()
	if current != &"Locomotion" and current != &"Crouch":
		return
	sheathe_idle += delta
	if sheathe_idle >= auto_sheathe_time:
		set_sheathed(true)


func has_combo() -> bool:
	return weapon != null and not weapon.combo.is_empty()


## True if there is floor a short way ahead in dir (within max_drop below the feet).
## Attacks use it to stop a lunge before an edge.
func has_ground_ahead(dir: Vector3, distance: float, max_drop: float = 0.5) -> bool:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return true
	var from := global_position + flat.normalized() * distance + Vector3.UP * 0.3
	var to := from + Vector3.DOWN * (0.3 + max_drop)
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## True if the floor is within air_jump_ground_margin below the feet.
func is_near_ground() -> bool:
	var from := global_position + Vector3.UP * 0.05
	var to := global_position + Vector3.DOWN * air_jump_ground_margin
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Nearest wall within wall_range of the capsule edge, from 8 horizontal rays at chest
## height. Returns {"normal": Vector3, "distance": float}, or {} if there is none.
func find_wall() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var capsule := _collision_shape.shape as CapsuleShape3D
	var origin := global_position + Vector3.UP * (stand_height * 0.5)
	var reach := capsule.radius + wall_range
	var best: Dictionary = {}
	var best_distance := INF
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, collision_mask, [get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit["normal"]
		if absf(normal.y) > 0.3:
			continue
		var distance := origin.distance_to(hit["position"])
		if distance < best_distance:
			best_distance = distance
			best = {
				"normal": Vector3(normal.x, 0.0, normal.z).normalized(),
				"distance": distance,
				"position": hit["position"],
			}
	return best


## Handles a jump press made in mid-air (after the coyote jump had its chance).
## Returns true if a wall jump should start (wall_normal is set; the caller transitions
## to WallJump). Otherwise it may play the reach, and returns false.
func try_air_jump() -> bool:
	if not input_buffer.has_pressed(&"jump") or is_near_ground():
		return false
	input_buffer.consume(&"jump")
	if wall_jumps_used < max_wall_jumps:
		var wall := find_wall()
		if not wall.is_empty():
			wall_normal = wall["normal"]
			return true
	if reach_ready:
		reach_ready = false
		play_reach_arms()
		Sfx.play(get_tree(), Sfx.Id.REACH)
	return false


## Looks for a ledge to grab: airborne, near the top of a jump or falling, input toward a
## wall, a flat ledge top in the hand zone that is deep enough, and room to stand on it.
## Returns {"stand_position", "normal", "edge"} or {}.
func find_ledge() -> Dictionary:
	if is_on_floor() or velocity.y > ledge_max_rise_speed:
		return {}
	if Time.get_ticks_msec() < ledge_block_until_ms:
		return {}
	if ledge_requires_jump_held and not (Input.is_action_pressed("jump")
			or Input.is_action_pressed("interact") or input_buffer.has_pressed(&"interact")):
		return {}
	var want := get_move_input()
	want.y = 0.0
	if want.length_squared() < 0.01:
		return {}
	var wall := find_wall()
	if wall.is_empty():
		return {}
	var normal: Vector3 = wall["normal"]
	if want.normalized().dot(-normal) < ledge_input_threshold:
		return {}
	var hit_pos: Vector3 = wall["position"]
	var to_face := Vector3(hit_pos.x - global_position.x, 0.0, hit_pos.z - global_position.z)
	var face_distance := to_face.dot(-normal)
	var feet_y := global_position.y
	var space := get_world_3d().direct_space_state
	var radius := (_collision_shape.shape as CapsuleShape3D).radius
	var base := Vector3(global_position.x, 0.0, global_position.z)

	# 1. Ray down just inside the wall face to find the ledge top.
	var probe := base - normal * (face_distance + 0.15)
	var top_query := PhysicsRayQueryParameters3D.create(
			Vector3(probe.x, feet_y + ledge_zone_max + 0.2, probe.z),
			Vector3(probe.x, feet_y + ledge_zone_min - 0.05, probe.z),
			collision_mask, [get_rid()])
	var top := space.intersect_ray(top_query)
	if top.is_empty():
		return {}
	var top_normal: Vector3 = top["normal"]
	var top_pos: Vector3 = top["position"]
	if top_normal.y < 0.9 or top_pos.y < feet_y + ledge_zone_min or top_pos.y > feet_y + ledge_zone_max:
		return {}

	# 2. The top must be deep enough to stand on: check the landing spot.
	var stand_xz := base - normal * (face_distance + radius + ledge_standoff)
	var stand_query := PhysicsRayQueryParameters3D.create(
			Vector3(stand_xz.x, top_pos.y + 0.5, stand_xz.z),
			Vector3(stand_xz.x, top_pos.y - 0.3, stand_xz.z),
			collision_mask, [get_rid()])
	var ground := space.intersect_ray(stand_query)
	if ground.is_empty():
		return {}
	var ground_normal: Vector3 = ground["normal"]
	var ground_pos: Vector3 = ground["position"]
	if ground_normal.y < 0.9 or absf(ground_pos.y - top_pos.y) > 0.1:
		return {}
	var stand_pos := Vector3(stand_xz.x, ground_pos.y, stand_xz.z)

	# 3. There must be room for the standing capsule up there.
	if not _fits_standing_at(stand_pos + Vector3.UP * 0.02):
		return {}
	var hang_xz := base - normal * (face_distance - (radius + hang_gap))
	var hang_pos := Vector3(hang_xz.x, top_pos.y - hang_center_depth - stand_height * 0.5, hang_xz.z)
	var hang_spot := _find_hang_spot(hang_pos, normal, top_pos.y)
	if not hang_spot.is_empty():
		hang_pos = hang_spot["position"]
	return {
		"stand_position": stand_pos,
		"normal": normal,
		"edge": top_pos,
		"top_y": top_pos.y,
		"hang_position": hang_pos,
		"hang_fits": not hang_spot.is_empty(),
	}


## If a ledge can be grabbed, stores it for the LedgeClimb state and returns true
## (the caller transitions to LedgeClimb).
func try_ledge_grab() -> bool:
	var ledge := find_ledge()
	if ledge.is_empty():
		return false
	ledge_stand_pos = ledge["stand_position"]
	ledge_wall_normal = ledge["normal"]
	last_ledge_point = ledge["edge"]
	ledge_top_y = ledge["top_y"]
	ledge_hang_pos = ledge["hang_position"]
	ledge_hang_fits = ledge["hang_fits"]
	last_ledge_ms = Time.get_ticks_msec()
	return true


## Turn the body collision on or off (used during the scripted ledge climb).
func set_body_collision_enabled(enabled: bool) -> void:
	_collision_shape.set_deferred("disabled", not enabled)


## Which state a found ledge leads to: hang if interact is held (or was just pressed) and
## the hanging body fits there, otherwise the auto-climb.
func ledge_grab_state() -> StringName:
	var wants_hang := Input.is_action_pressed("interact") or input_buffer.has_pressed(&"interact")
	if wants_hang and ledge_hang_fits:
		input_buffer.consume(&"interact")
		return &"LedgeHang"
	return &"LedgeClimb"


## While hanging: finds the ledge top along the wall at the given feet position (near the
## last known ledge height). Returns {"top_y", "stand_position", "fits"} or {} if there is
## no ledge top there. "fits" says whether a standing body fits on top (needed to climb).
func probe_hang_ledge(pos: Vector3, normal: Vector3) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var radius := (_collision_shape.shape as CapsuleShape3D).radius
	var face_distance := radius + hang_gap
	var base := Vector3(pos.x, 0.0, pos.z)
	var probe := base - normal * (face_distance + 0.15)
	var top_query := PhysicsRayQueryParameters3D.create(
			Vector3(probe.x, ledge_top_y + 0.3, probe.z),
			Vector3(probe.x, ledge_top_y - 0.3, probe.z),
			collision_mask, [get_rid()])
	var top := space.intersect_ray(top_query)
	if top.is_empty():
		return {}
	var top_normal: Vector3 = top["normal"]
	if top_normal.y < 0.9:
		return {}
	var top_pos: Vector3 = top["position"]
	if not _hands_on_ledge(pos, normal, ledge_top_y):
		return {}
	var stand_xz := base - normal * (face_distance + radius + ledge_standoff)
	var ground_query := PhysicsRayQueryParameters3D.create(
			Vector3(stand_xz.x, top_pos.y + 0.5, stand_xz.z),
			Vector3(stand_xz.x, top_pos.y - 0.3, stand_xz.z),
			collision_mask, [get_rid()])
	var ground := space.intersect_ray(ground_query)
	if ground.is_empty():
		return {"top_y": top_pos.y, "fits": false}
	var ground_normal: Vector3 = ground["normal"]
	var ground_pos: Vector3 = ground["position"]
	if ground_normal.y < 0.9 or absf(ground_pos.y - top_pos.y) > 0.1:
		return {"top_y": top_pos.y, "fits": false}
	var stand_pos := Vector3(stand_xz.x, ground_pos.y, stand_xz.z)
	return {
		"top_y": top_pos.y,
		"stand_position": stand_pos,
		"fits": _fits_standing_at(stand_pos + Vector3.UP * 0.02),
	}


## True if the body fits with its feet at the given point (used while shimmying).
func can_hang_at(feet: Vector3) -> bool:
	return _fits_standing_at(feet + Vector3.UP * 0.02)


## True if both hand points (either side of pos along the wall) find a flat ledge top
## near top_y just inside the wall face.
func _hands_on_ledge(pos: Vector3, normal: Vector3, top_y: float) -> bool:
	var space := get_world_3d().direct_space_state
	var radius := (_collision_shape.shape as CapsuleShape3D).radius
	var face_distance := radius + hang_gap
	var tangent := normal.cross(Vector3.UP).normalized()
	for side: float in [-1.0, 1.0]:
		var hand := Vector3(pos.x, 0.0, pos.z) + tangent * side * hang_hand_spacing
		var probe := hand - normal * (face_distance + 0.15)
		var query := PhysicsRayQueryParameters3D.create(
				Vector3(probe.x, top_y + 0.3, probe.z),
				Vector3(probe.x, top_y - 0.3, probe.z),
				collision_mask, [get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return false
		var hit_normal: Vector3 = hit["normal"]
		if hit_normal.y < 0.9:
			return false
	return true


## Finds the hang position closest to the wanted one (shifting sideways along the wall, up
## to hang_adjust_max) where both hands are on the ledge and the body fits.
## Returns {"position": Vector3} or {} if there is none.
func _find_hang_spot(wanted: Vector3, normal: Vector3, top_y: float) -> Dictionary:
	var tangent := normal.cross(Vector3.UP).normalized()
	var step := 0.05
	var count := int(ceil(hang_adjust_max / step))
	for i in range(count + 1):
		for side: float in [1.0, -1.0]:
			if i == 0 and side < 0.0:
				continue
			var candidate := wanted + tangent * side * step * float(i)
			if _hands_on_ledge(candidate, normal, top_y) and _fits_standing_at(candidate + Vector3.UP * 0.02):
				return {"position": candidate}
	return {}
