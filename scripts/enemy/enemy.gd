class_name Enemy
extends CharacterBody3D
## The first real enemy (Step 7a, defense added in 7b). It chases the player, circles at a distance,
## and attacks in bursts with the player's own ground combo (the weapon's attack_1 to attack_5
## ActionData and the same arm-swing SwordVisual, so its wind-up is the telegraph). Damage and
## posture damage are scaled by EnemyAIData.
##
## Perilous attacks (7c-1): instead of a burst it may start the weapon's charged thrust or a low
## sweep (EnemyAIData: chance, cooldown, range; Debug Force Perilous forces one for testing). They
## cannot be guarded or deflected, and in the PERILOUS phase it has super armor (no flinch, no
## guard; your hits still do damage and posture). A red danger symbol shows above the player 0.5 s
## before the hit window. Counters: mikiri (the player dodges toward it during a thrust) and the
## jump-over (the player is in the air during a sweep) cut the attack, add posture, and leave it
## stunned (COUNTERED: no guard, no flinch). The grab comes in 7c-2.
##
## Loop: IDLE (nobody near) > CHASE (run in, then start a burst) > ATTACK (2 to 4 combo hits, each
## chained at the earliest cancel point) > RECOVER (stands still: the player's opening) > YIELD
## (circles at a distance for a while) > CHASE again.
##
## Defense (7b, every number in EnemyAIData, so each enemy type is a different .tres):
## - Threat: the player is inside an attack (read from its action clock) within threat_range. After a
##   random reaction_delay it rolls guard (neutral or pressured chances, plus a bonus for repeated
##   attacks). A guard is either a plain guard (stance only) or a timed deflect (a press so the 0.2 s
##   window lands on the hit); a deflect may be a repulse (the attacker bounces and its combo resets).
##   A planned deflect presses on time whatever the reaction delay; after a landed hit (pressured) the
##   guard comes up at once; after hit_streak_limit unguarded hits in a row the next threat is guarded.
## - It can only guard in IDLE, CHASE, and YIELD: never in its own attack, recovery, a flinch, the
##   pose, or a stun. That is where the player's openings come from.
## - Flinch: an unguarded hit that lands can stop it for hit_stun_time (per moment: wind-up,
##   recovery, neutral; never during its own hit window), then it is immune to flinching for
##   flinch_immunity_time (no stunlock). The recoil wobble plays on every hit.
## - Riposte: after a deflect it may counter with a short burst; with riposte_armor a landed hit cannot
##   flinch it until the burst ends. After pressure_break_hits guarded hits of yours in a row (a
##   little random) its next defense is a forced deflect with a guaranteed riposte.
## - Recovery pose: with high posture and no pressure it stands in a white aura and regenerates
##   posture faster; any damage ends it.
##
## It uses the same Combatant rules as the player (HP, 2 bars, posture, deathblow, guard): an empty
## bar or a posture break stuns it (pale, frozen) until the deathblow window closes.
## The defense decisions (the plan, the streaks, the riposte timer) are in EnemyDefense (Phase 1.5, item 5b).
## Needs the nodes listed in the Step 7 instructions (a missing one is an error on purpose).

enum Phase { IDLE, CHASE, ATTACK, RECOVER, YIELD, STUNNED, FLINCH, POSE, PERILOUS, COUNTERED }
enum Peril { NONE, THRUST, SWEEP, GRAB }

@export var ai: EnemyAIData
@export var weapon: WeaponData
@export var respawn_delay: float = 2.0
## Health bars, boss flag, and deathblow window (s); copied to the Combatant at startup.
@export var health_bars: int = 2
@export var boss: bool = false
## The name the boss HUD shows (empty = the node's name).
@export var display_name: String = ""
@export var deathblow_window: float = 4.0
@export var gravity_multiplier: float = 2.0
@export var body_color: Color = Color(0.75, 0.3, 0.25)
## Step 9: where the lock-on marker and the camera aim sit, in metres above its feet.
@export var lock_point_height: float = 1.2
@export_group("Recoil")
## How far (m) the body shifts away from a hit, and how far (radians) it tilts.
@export var recoil_distance: float = 0.12
@export var recoil_tilt: float = 0.15
@export var recoil_time: float = 0.2
## The recoil is lighter when its guard or deflect takes the hit.
@export var guard_recoil_scale: float = 0.6
@export var deflect_recoil_scale: float = 0.3
@export_group("Bobble (head wobble)")
## A bobblehead flinch: the whole body pivots at the feet, so the top swings most. After a jump-over:
## tilt (radians), length (s), and how many swings fit in it. The mikiri uses a shorter, sharper one.
@export var bobble_tilt: float = 0.5
@export var bobble_time: float = 0.8
@export var bobble_cycles: float = 3.0
## While stunned for a deathblow: a slow, heavy sway (tilt in radians, one swing in this many
## seconds) and a constant forward droop of the head (radians).
@export var stun_bobble_tilt: float = 0.3
@export var stun_bobble_period: float = 1.6
@export var stun_droop: float = 0.25
@export_group("Awareness (Phase 2 item 7a)")
## On: this enemy has senses (sight and hearing, see EnemyAwareness) and notices the player only when it sees or
## hears it, instead of at `aggro_range` through walls. It can patrol, search and shout, and it has the edge
## guard. Off (the default): the old behavior, nothing else changes. The numbers are in the `ai` preset.
@export var use_awareness: bool = false
## Item 7d: with `use_awareness`, an enemy that dies stays where it fell (tipped over, grey, no collider, no
## bar) until the scene reloads, and guards can find the body (see EnemyAIData.notices_corpses). Off, or a boss
## or an enemy without awareness: it vanishes and respawns after `respawn_delay`, as before.
@export var leaves_corpse: bool = true
## Non-lethal combat (Phase 2 item 10): a knocked-out enemy wakes after this many seconds (0 = never; a boss
## never wakes), but not while the player is within `wake_player_distance` (m). It wakes at its post, healthy
## and unaware; a guard that wakes it by hand (EnemyAIData.wake_pause) wakes it where it lies.
@export var wake_time: float = 300.0
@export var wake_player_distance: float = 8.0
## The health bar, the dots and the posture bar show only while this enemy is fighting the player (any phase but
## IDLE) and fade in and out (see EnemyBar's "Combat fade"). Off: they are always shown.
@export var bars_only_in_combat: bool = true
## A node whose Marker3D children are the patrol waypoints, walked in a loop. Empty: it stands at its post and scans.
@export var patrol_path: NodePath
## Seconds it waits at each waypoint (a random time between the two).
@export var patrol_wait: Vector2 = Vector2(1.5, 3.5)

@export_group("Navigation (Phase 2 item 12a)")
## On: this enemy walks around walls and obstacles along a baked navmesh (see EnemyNavigation) when it patrols,
## investigates a noise, searches, walks to a body, or chases the player. Needs a `NavigationAgent3D` child named
## `NavigationAgent` on this enemy and a baked `NavigationRegion3D` in the arena. Off (the default): the old
## straight-line walking, nothing else changes. The numbers are in the `ai` preset.
@export var use_navigation: bool = false
## Draws this enemy's current path in the game (the agent's own debug line).
@export var debug_navigation: bool = false
## Prints one line per second to the Output panel while it walks by navigation: the target, whether the map is
## ready, the path length and why it has no direction (for finding why an enemy does not move). Debug builds only.
@export var debug_navigation_log: bool = false
## Items 12b-1a, 12b-2 and 12b-3: on (needs `use_navigation`): this enemy also takes navigation links. Drop links
## are one-way `NavigationLink3D` nodes on navigation layer 2 (it walks to the edge, pauses, steps off and falls to
## the level below); jump links are nodes on layer 4 across a gap (it pauses at the edge and jumps; the preset's
## `nav_jump_max_distance` 0 turns jumping off); climb links are nodes on layer 8 from the foot of a wall to the top
## (it climbs up or down; `nav_climb_max_height` 0 turns climbing off). It also counts a target up to
## `nav_drop_max_height` below it, and up to `nav_climb_max_height` above it, as reachable. Off (the default): it
## ignores the links, as before. The numbers are in the `ai` preset.
@export var use_nav_links: bool = false

@export_group("Debug")
## Print phase changes, attacks, and defense decisions to the Output panel.
@export var debug_log: bool = false
## Testing aid: every time it would start an attack burst it does this perilous attack instead
## (ignoring chance, cooldown, and the preset's switches; the attack itself must exist: the weapon's
## thrust, or `sweep_action` on the AI data). Grab does nothing until 7c-2.
@export_enum("None", "Thrust", "Sweep", "Grab") var debug_force_perilous: int = 0

@onready var combatant: Combatant = $Combatant
@onready var visual: Node3D = $Visual
@onready var body: MeshInstance3D = $Visual/Body
@onready var sword_visual: SwordVisual = $Visual/SwordVisual
@onready var bar: EnemyBar = $Visual/Bar
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var aura: MeshInstance3D = $Aura

var phase: Phase = Phase.IDLE
var _guarding: bool = false

var _player: Node3D
var _awareness: EnemyAwareness
var _navigation: EnemyNavigation
## True while the player is dead and this enemy is standing down (Step 10).
var _stood_down: bool = false
## Item 7b: seconds left in which a fresh spot (not a hit) can still be stealth-killed (see can_be_stealth_killed).
var _stealth_grace_left: float = 0.0
## Item 7d: this enemy died and left a body; set once a guard has seen it.
var _is_corpse: bool = false
## Item 10: knocked out (tipped over, no collider), and the seconds left before it wakes by itself.
var _unconscious: bool = false
var _wake_left: float = 0.0
## Item 10: held by the player's choke: no AI, no movement, a struggle and then a droop (0 to 1) drawn on `visual`.
var _held: bool = false
var _held_amount: float = 0.0
var _held_clock: float = 0.0
var corpse_discovered: bool = false
## Phase 2 item 15a: the player carries this body (guards neither see nor lift it meanwhile; temporary until
## item 15d), a guard carries it (the player cannot pick it up), and a released body that is falling.
var _carried: bool = false
var held_by_guard: bool = false
var _body_falling: bool = false
var _body_fall_speed: float = 0.0
## Item 15c: the body is flying (thrown by the player).
var _body_flying: bool = false
var _flight_velocity: Vector3 = Vector3.ZERO
var _flight_thrower: Player
var _flight_data: ThrowableData
var _corpse_material: StandardMaterial3D
## Awareness enemies only: it was in combat when it stood down, so it yields when the player is back (an unaware one
## just carries on).
var _stand_down_was_combat: bool = false
var _gravity: float = 9.8
var _think_timer: float = 0.0
var _phase_timer: float = 0.0
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0
var _action: ActionData
## The shared core (Step 12D): the clock, the swing, and the movement fade. `_action_time` is the
## runner's clock, so the AI code below reads as before.
var _runner: ActionRunner = ActionRunner.new()
var _action_time: float:
	get:
		return _runner.time
	set(value):
		_runner.time = value
var _combo_index: int = 0
var _burst_total: int = 0
var _chain_wait: float = 0.0
var _lunge_dir: Vector3 = Vector3.ZERO
var _recoil: float = 0.0
var _recoil_scale: float = 1.0
var _recoil_direction: Vector3 = Vector3.ZERO
var _base_material: StandardMaterial3D
## Phase 2 item 11.5: the taunt stacks (0 = calm) and the seconds left before they all clear.
var _provoke_stacks: int = 0
var _provoke_left: float = 0.0
var _unconscious_material: StandardMaterial3D
var _stun_material: StandardMaterial3D
var _spawn_position: Vector3 = Vector3.ZERO
var _spawn_yaw: float = 0.0
# Defense state.
## The defense decisions (Phase 1.5, item 5b): the plan, the streaks, the riposte timer.
var _defense: EnemyDefense
var _flinch_immunity: float = 0.0
var _burst_armored: bool = false
var _pose_timer: float = 0.0
var _pose_cooldown: float = 0.0
var _base_posture_regen: float = 15.0
# Perilous attack state (7c).
var _peril_kind: int = Peril.NONE
var _peril_charging: bool = false
var _peril_time: float = 0.0
var _peril_cooldown: float = 0.0
var _grab_connected: bool = false
var _peril_history: Array[int] = []
var _symbol: DangerSymbol
var _symbol_shown: bool = false
var _symbol_missing_warned: bool = false
var _chain_rolled: bool = false
var _head_bounce_time: float = 0.0
# Bobble (visual only): a damped swing, or a loop while it is stunned for a deathblow.
var _bobble_tilt: float = 0.0
var _bobble_length: float = 0.0
var _bobble_period: float = 1.0
var _bobble_clock: float = 0.0
var _bobble_loop: bool = false
## The sweep duck, 0 (standing) to 1 (full), moved in _process (visual only).
var _crouch: float = 0.0
var _bobble_droop: float = 0.0
var _bobble_sign: float = 1.0
var _visual_dirty: bool = false


func _init() -> void:
	_defense = EnemyDefense.new(self)


func _ready() -> void:
	if ai == null or weapon == null or weapon.combo.is_empty():
		push_error("Enemy: set `ai` (EnemyAIData) and `weapon` (WeaponData with a combo) in the Inspector.")
		set_physics_process(false)
		return
	if sword_visual.hitbox == null:
		push_error("Enemy: the SwordVisual has no Hitbox assigned (set its Hitbox export in the Inspector).")
		set_physics_process(false)
		return
	add_to_group(Groups.ENEMY)
	Enemies.register(self)
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity")) * gravity_multiplier
	_spawn_position = global_position
	_spawn_yaw = rotation.y
	combatant.health_bars = health_bars
	combatant.boss = boss
	combatant.deathblow_window = deathblow_window
	combatant.deathblow_enabled = true
	combatant.guard_facing = _guard_facing
	combatant.reset()
	_base_posture_regen = combatant.posture_regen
	_base_material = StandardMaterial3D.new()
	_base_material.albedo_color = body_color
	body.material_override = _base_material
	_stun_material = StandardMaterial3D.new()
	_stun_material.albedo_color = Color(0.95, 0.95, 0.85)
	_stun_material.emission_enabled = true
	_stun_material.emission = Color(0.9, 0.9, 0.7)
	_stun_material.emission_energy_multiplier = 0.6
	var aura_material := StandardMaterial3D.new()
	aura_material.albedo_color = Color(1.0, 1.0, 1.0, 0.22)
	aura_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	aura.material_override = aura_material
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aura.visible = false
	bar.bind(combatant)
	bar.set_in_combat(not bars_only_in_combat, true)
	combatant.damaged.connect(_on_damaged)
	combatant.hit_guarded.connect(_on_guarded)
	combatant.hit_deflected.connect(_on_deflected)
	combatant.died.connect(_on_died)
	combatant.knocked_out.connect(_on_knocked_out)
	combatant.deathblow_opened.connect(_on_deathblow_opened)
	combatant.deathblow_closed.connect(_on_deathblow_closed)
	combatant.posture_broken.connect(_on_posture_broken)
	sword_visual.hitbox.team = Layers.Team.ENEMY
	# Per-type look: a copy of the weapon with a scaled blade (the weapon file stays as it is).
	var look_weapon := weapon
	if not is_equal_approx(ai.blade_length_scale, 1.0) or not is_equal_approx(ai.blade_thickness_scale, 1.0):
		look_weapon = weapon.duplicate() as WeaponData
		look_weapon.blade_length = weapon.blade_length * ai.blade_length_scale
		look_weapon.blade_thickness = weapon.blade_thickness * ai.blade_thickness_scale
	if ai.blade_color.a > 0.0:
		sword_visual.idle_color = Color(ai.blade_color, 1.0)
	sword_visual.setup(look_weapon, ai.blade_back_length)
	_think_timer = 0.5
	_defense.roll_break_threshold()
	if use_awareness:
		_awareness = EnemyAwareness.new(self)
		_awareness.setup()
	if use_navigation:
		_navigation = EnemyNavigation.new(self)
		_navigation.setup()


func _exit_tree() -> void:
	Enemies.unregister(self)


func _physics_process(delta: float) -> void:
	if _body_flying:
		_fly_body(delta)
		return
	if _body_falling:
		_fall_body(delta)
		return
	if combatant.dead:
		if _unconscious:
			_tick_wake(delta)
		return
	if _held:
		# The choke has hold of it (item 10): it stays where the player put it.
		velocity = Vector3.ZERO
		return
	if global_position.y < -30.0:
		_return_to_spawn()
	_defense.tick(delta)
	_flinch_immunity = maxf(_flinch_immunity - delta, 0.0)
	_pose_cooldown = maxf(_pose_cooldown - delta, 0.0)
	_peril_cooldown = maxf(_peril_cooldown - delta, 0.0)
	_head_bounce_time = maxf(_head_bounce_time - delta, 0.0)
	_tick_provoke(delta)
	var acting := phase == Phase.ATTACK or phase == Phase.PERILOUS
	combatant.tick_posture(delta, acting)
	combatant.tick_guard(delta, _guarding, acting)
	_apply_gravity(delta)
	if combatant.deathblow_open:
		# Stunned: no swings, no turning, until the window closes.
		_decelerate(delta)
		move_and_slide()
		return
	if _navigation != null and _navigation.is_crossing():
		# Item 12b-1a: a drop link is being crossed; it overrides the AI until the enemy has landed and recovered.
		_navigation.tick_crossing(delta)
		move_and_slide()
		return
	_find_player()
	_update_stealth_marker(delta)
	_think_timer = maxf(_think_timer - delta, 0.0)
	var to_player := _flat_to_player()
	var distance := to_player.length()
	var has_target := _player != null and not _player_dead()
	# Step 10: a dead player (the death prompt) means stand down; a resurrection resumes with a yield.
	if _player != null:
		if not has_target:
			_stand_down()
		elif _stood_down:
			_stand_down_ended()
	# An enemy that has not noticed the player yet does not plan guards against it (item 7a).
	if not (use_awareness and phase == Phase.IDLE):
		_defense.update(delta, distance, _player_action_state(has_target))
	if _defense.tick_riposte(delta, has_target):
		_start_burst(ai.riposte_burst_count, true)
	match phase:
		Phase.IDLE:
			if _awareness != null:
				if _awareness.update(delta, has_target):
					_enter_combat()
			else:
				_decelerate(delta)
				if has_target and distance <= ai.aggro_range and not _player_undetectable():
					_set_phase(Phase.CHASE)
		Phase.CHASE:
			_update_chase(delta, to_player, distance, has_target)
		Phase.ATTACK:
			_update_attack(delta, to_player, distance)
		Phase.RECOVER:
			_decelerate(delta)
			_face(to_player, delta, ai.turn_speed * 0.5)
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_start_yield()
		Phase.YIELD:
			_update_yield(delta, to_player, distance, has_target)
		Phase.FLINCH:
			_decelerate(delta)
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_flinch_immunity = ai.flinch_immunity_time
				_think_timer = 0.3
				_set_phase(Phase.CHASE)
		Phase.POSE:
			_update_pose(delta, to_player)
		Phase.PERILOUS:
			_update_perilous(delta, to_player, distance, has_target)
		Phase.COUNTERED:
			_decelerate(delta)
			_phase_timer -= delta
			if _phase_timer <= 0.0:
				_think_timer = 0.3
				_set_phase(Phase.CHASE)
	move_and_slide()


func _process(delta: float) -> void:
	if _is_corpse or _unconscious:
		return  # the body keeps its tipped-over pose (items 7d and 10)
	if _held:
		_update_held_pose(delta)
		return
	_update_crouch(delta)
	var bobbing := _bobble_loop or _bobble_clock < _bobble_length
	if _recoil <= 0.0 and not bobbing and _crouch <= 0.0:
		if _visual_dirty:
			_visual_dirty = false
			visual.position = Vector3.ZERO
			visual.basis = Basis.IDENTITY
		return
	_visual_dirty = true
	var offset := Vector3.ZERO
	var tilt := Basis.IDENTITY
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta / maxf(recoil_time, 0.001))
		var k := ease(_recoil, 2.0) * _recoil_scale
		var local_dir := global_transform.basis.inverse() * _recoil_direction
		local_dir.y = 0.0
		offset = local_dir * recoil_distance * k
		var axis := Vector3.UP.cross(local_dir)
		if axis.length_squared() > 0.0001:
			tilt = Basis(axis.normalized(), recoil_tilt * k)
	var bobble := Basis.IDENTITY
	if bobbing:
		_bobble_clock += delta
		var envelope := 1.0
		if not _bobble_loop:
			envelope = pow(clampf(1.0 - _bobble_clock / maxf(_bobble_length, 0.001), 0.0, 1.0), 2.0)
		var swing := TAU * _bobble_clock / maxf(_bobble_period, 0.001)
		# Pitch (nodding forward and back; negative = forward) and a smaller side roll a quarter swing later.
		var pitch := -_bobble_droop * (1.0 if _bobble_loop else envelope) + _bobble_tilt * envelope * sin(swing)
		var roll := _bobble_sign * _bobble_tilt * 0.6 * envelope * cos(swing)
		bobble = Basis(Vector3.RIGHT, pitch) * Basis(Vector3.FORWARD, roll)
	var crouch_basis := Basis.IDENTITY
	if _crouch > 0.0:
		var duck := smoothstep(0.0, 1.0, _crouch)
		offset.y -= ai.sweep_crouch_drop * duck
		crouch_basis = Basis(Vector3.RIGHT, -deg_to_rad(ai.sweep_crouch_lean_degrees) * duck)
	visual.position = offset
	visual.basis = crouch_basis * bobble * tilt


## The sweep duck: follows the sweep's action clock up to full at the start of the hit window, holds
## until the window closes, then stands back up over sweep_crouch_out_time.
func _update_crouch(delta: float) -> void:
	var ducking := phase == Phase.PERILOUS and _peril_kind == Peril.SWEEP and _action != null \
			and _action_time < _action.active_hit.y \
			and (ai.sweep_crouch_drop > 0.0 or ai.sweep_crouch_lean_degrees > 0.0)
	if ducking:
		_crouch = clampf(_action_time / maxf(_action.active_hit.x, 0.001), 0.0, 1.0)
	elif _crouch > 0.0:
		_crouch = move_toward(_crouch, 0.0, delta / maxf(ai.sweep_crouch_out_time, 0.001))


## Start a damped bobble (visual only): `tilt` radians, over `length` seconds, `cycles` swings.
func _start_bobble(tilt: float, length: float, cycles: float) -> void:
	_bobble_tilt = tilt
	_bobble_length = length
	_bobble_period = length / maxf(cycles, 0.1)
	_bobble_clock = 0.0
	_bobble_loop = false
	_bobble_droop = 0.0
	_bobble_sign = 1.0 if randf() < 0.5 else -1.0


## The deathblow stun: a slow heavy sway with a drooping head, until the window closes.
func _start_stun_bobble() -> void:
	_bobble_tilt = stun_bobble_tilt
	_bobble_length = 0.0
	_bobble_period = stun_bobble_period
	_bobble_clock = 0.0
	_bobble_loop = true
	_bobble_droop = stun_droop
	_bobble_sign = 1.0 if randf() < 0.5 else -1.0


## Stop the loop: the sway and droop fade out over a short last swing.
func _end_stun_bobble() -> void:
	if not _bobble_loop:
		return
	_bobble_loop = false
	_bobble_droop = 0.0
	_bobble_length = 0.4
	_bobble_period = 0.4
	_bobble_clock = 0.0
	_bobble_tilt = stun_bobble_tilt * 0.5


## The player lands on this enemy's head. If a jump-over armed it (the player was in the air while the
## sweep's symbol showed, within head_bounce_window), that is the counter: the sweep is cut, posture is
## added, the enemy is stunned, and this returns true so the player bounces. Otherwise false.
func on_stomped() -> bool:
	if _head_bounce_time <= 0.0:
		return false
	_head_bounce_time = 0.0
	if not combatant.deathblow_open:
		_countered(ai.jump_over_posture, ai.jump_over_stun, "jump-over", true)
	return true


# --- Phases -----------------------------------------------------------------------------------

func _update_chase(delta: float, to_player: Vector3, distance: float, has_target: bool) -> void:
	if not has_target or distance > ai.aggro_range * 1.5 or _is_out_of_reach():
		_set_phase(Phase.IDLE)
		return
	_face(to_player, delta, ai.turn_speed)
	if distance > ai.engage_distance:
		var speed := ai.strafe_speed if _guarding else ai.run_speed
		var heading := to_player.normalized()
		if use_navigation:
			# Item 12a: follow the path around obstacles (zero when there is none: it stands).
			heading = nav_direction(_player.global_position)
		_move_toward_velocity(heading * speed, delta)
		return
	_decelerate(delta)
	if _think_timer <= 0.0 and not _guarding:
		var kind := _pick_perilous(distance, ai.perilous_chance)
		if kind != Peril.NONE:
			_start_perilous(kind)
		else:
			_start_burst(ai.attack_burst_count)


func _update_yield(delta: float, to_player: Vector3, distance: float, has_target: bool) -> void:
	if not has_target:
		_set_phase(Phase.IDLE)
		return
	if _can_pose():
		_start_pose()
		return
	_face(to_player, delta, ai.turn_speed)
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_sign = -_strafe_sign
		_strafe_timer = randf_range(ai.strafe_switch_time.x, ai.strafe_switch_time.y)
	var dir := to_player.normalized() if distance > 0.01 else Vector3.ZERO
	var side := Vector3(dir.z, 0.0, -dir.x) * _strafe_sign
	var radial := clampf((distance - ai.preferred_distance) * 2.0, -ai.strafe_speed, ai.strafe_speed)
	_move_toward_velocity(side * ai.strafe_speed + dir * radial, delta)
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_think_timer = 0.0
		_set_phase(Phase.CHASE)


func _start_yield() -> void:
	var yield_scale := lerpf(1.5, 0.5, ai.aggression) * pow(ai.provoke_yield_scale, _provoke_level())
	_phase_timer = randf_range(ai.yield_time.x, ai.yield_time.y) * yield_scale
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	_strafe_timer = randf_range(ai.strafe_switch_time.x, ai.strafe_switch_time.y)
	_set_phase(Phase.YIELD)


func _start_recover() -> void:
	_phase_timer = ai.recovery_time
	_set_phase(Phase.RECOVER)


func _start_flinch() -> void:
	Sfx.play_at(get_tree(), Sfx.Id.ENEMY_FLINCH, global_position + Vector3.UP * 1.2)
	_abort_attack()
	_defense.riposte_pending = false
	_phase_timer = ai.hit_stun_time
	_set_phase(Phase.FLINCH)


## Riposte armor: from the deflect that earned the riposte until its burst ends.
func _is_armored() -> bool:
	return ai.riposte_armor and (_defense.riposte_pending or (phase == Phase.ATTACK and _burst_armored))


## Would a landed (unguarded) hit flinch it right now? Never during its own hit window.
func _should_flinch() -> bool:
	if ai.hit_stun_time <= 0.0 or _flinch_immunity > 0.0 or combatant.deathblow_open or combatant.dead:
		return false
	if _is_armored():
		return false
	match phase:
		Phase.ATTACK:
			if _hit_is_active():
				return false
			if _action_time < _action.active_hit.x:
				return ai.flinch_in_windup
			return ai.flinch_in_recovery
		Phase.RECOVER:
			return ai.flinch_in_recovery
		Phase.PERILOUS:
			# Super armor until its hit window ends; after that it follows the recovery rule.
			if _peril_charging or _action_time < _action.active_hit.x or _hit_is_active():
				return false
			return ai.flinch_in_recovery
		Phase.IDLE, Phase.CHASE, Phase.YIELD, Phase.POSE:
			return ai.flinch_in_neutral
	return false


# --- Recovery pose -------------------------------------------------------------------------------

func _can_pose() -> bool:
	return ai.pose_enabled and _pose_cooldown <= 0.0 and not combatant.posture_full \
			and combatant.posture >= ai.posture_pose_threshold * combatant.max_posture \
			and _defense.since_player_attack >= ai.pose_idle_time


func _start_pose() -> void:
	Sfx.play_at(get_tree(), Sfx.Id.AURA_START, global_position + Vector3.UP * 1.2)
	drop_guard()
	_pose_timer = 0.0
	combatant.posture_regen = _base_posture_regen * ai.pose_regen_factor
	aura.visible = true
	_set_phase(Phase.POSE)


func _update_pose(delta: float, to_player: Vector3) -> void:
	_decelerate(delta)
	_face(to_player, delta, ai.turn_speed * 0.5)
	_pose_timer += delta
	if combatant.posture <= ai.pose_end_posture * combatant.max_posture \
			or _pose_timer >= ai.pose_max_time:
		_end_pose()


## Leave the pose (finished, hit, stunned, or dead): normal regen, no aura, a cooldown.
func _end_pose() -> void:
	combatant.posture_regen = _base_posture_regen
	aura.visible = false
	if phase == Phase.POSE:
		_pose_cooldown = ai.pose_cooldown
		_think_timer = 0.2
		_set_phase(Phase.CHASE)


# --- Defense actuators (the decisions are in EnemyDefense) ----------------------------------------

func is_guarding() -> bool:
	return _guarding


## Raise the guard (stance); with `press`, also open a deflect window (a repulse window if asked).
func raise_guard(press: bool, repulse: bool) -> void:
	var fresh := not _guarding
	_guarding = true
	combatant.guarding = true
	if fresh:
		sword_visual.play_guard(false)
	if press:
		combatant.press_guard(repulse)
		if not fresh:
			sword_visual.play_guard_press()


func drop_guard() -> void:
	if not _guarding:
		return
	_guarding = false
	_defense.guard_hold = 0.0
	combatant.guarding = false
	sword_visual.end_combo()


func _guard_facing() -> Vector3:
	return -global_transform.basis.z


## The player's current action state (null when there is no target), for EnemyDefense.
func _player_action_state(has_target: bool) -> ActionState:
	var player_node := _player as Player
	if has_target and player_node != null and player_node.state_machine != null:
		return player_node.state_machine.current as ActionState
	return null


# --- Attacks (the weapon's ground combo) --------------------------------------------------------

func _start_burst(counts: Vector2i, armored: bool = false) -> void:
	drop_guard()
	_defense.riposte_pending = false
	_burst_armored = armored
	_defense.reset_guard_streak()
	_burst_total = clampi(randi_range(counts.x, counts.y) + _provoke_burst_bonus(), 1, weapon.combo.size())
	_set_phase(Phase.ATTACK)
	_begin_attack(0)


func _begin_attack(index: int) -> void:
	_end_hit()
	_chain_rolled = false
	_combo_index = index
	_action = weapon.combo[index]
	_action_time = 0.0
	_chain_wait = randf_range(ai.chain_delay.x, ai.chain_delay.y)
	var to_player := _flat_to_player()
	_lunge_dir = to_player.normalized() if to_player.length_squared() > 0.0001 else -global_transform.basis.z
	sword_visual.begin_action(_action)
	if debug_log and OS.is_debug_build():
		print("[Enemy] attack %d of %d" % [index + 1, _burst_total])


func _update_attack(delta: float, to_player: Vector3, distance: float) -> void:
	_action_time += delta * _attack_speed()
	# Steering: during the wind-up it turns toward the player and aims the lunge; both lock
	# when the hit window opens (like the player's attacks).
	if _action_time < _action.active_hit.x:
		_face(to_player, delta, ai.attack_turn_speed)
		if to_player.length_squared() > 0.0001:
			_lunge_dir = to_player.normalized()
	sword_visual.update_action(_action, _action_time, false)
	_update_hit()
	_apply_lunge(delta, distance)
	if _hit_is_active():
		return
	# At the chain point it may continue into a perilous attack instead of the next hit (or the end).
	if not _chain_rolled and _action_time >= _chain_time() + _chain_wait:
		_chain_rolled = true
		var kind := _pick_perilous(distance, ai.perilous_chain_chance)
		if kind != Peril.NONE:
			_burst_armored = false
			_end_hit()
			_start_perilous(kind)
			return
	var next := _combo_index + 1
	if next < _burst_total and _action_time >= _chain_time() + _chain_wait:
		_begin_attack(next)
		return
	if _action_time >= _action.duration:
		_end_burst()


## Clock speed of the current combo attack: slower in the wind-up and in the hit window (EnemyAIData).
func _attack_speed() -> float:
	if _action_time < _action.active_hit.x:
		return minf(ai.windup_speed + ai.provoke_windup_bonus * _provoke_level(), 1.5)
	if _action_time < _action.active_hit.y:
		return ai.active_speed
	return 1.0


## Earliest time the next attack may start: where the cancel window opens (as for the player).
func _chain_time() -> float:
	if _action.cancel_window == Vector2.ZERO:
		return _action.locked_until
	return _action.cancel_window.x


func _end_burst() -> void:
	_burst_armored = false
	_end_hit()
	sword_visual.end_combo()
	_start_recover()


func _apply_lunge(delta: float, distance: float) -> void:
	if not _runner.in_move_window(_action) or _lunge_dir == Vector3.ZERO \
			or distance <= ai.lunge_min_distance:
		_decelerate(delta)
		return
	var factor := _runner.move_fade_factor(_action)
	var speed := _action.move_speed * ai.lunge_factor * factor
	velocity.x = _lunge_dir.x * speed
	velocity.z = _lunge_dir.z * speed


func _hit_is_active() -> bool:
	return _runner.hit_is_active(_action)


## Open, sweep, and close the sword's hitbox for the current attack.
func _update_hit() -> void:
	var hitbox := sword_visual.hitbox
	if not _hit_is_active():
		_end_hit()
		return
	if _runner.open_hit(hitbox, _action):
		if _peril_kind != Peril.GRAB:
			Sfx.play_at(get_tree(), Sfx.swing_id(_action), global_position + Vector3.UP * 1.2)
	var template := _runner.make_hit(_action, self, ai.damage_scale, ai.posture_scale)
	if _peril_kind != Peril.NONE:
		# Perilous: its own numbers. A guard does nothing; only the thrust can be deflected, and only by a
		# press this recent (the sweep is answered by the jump-over).
		template.damage = ai.perilous_damage
		template.posture_damage = ai.perilous_posture
		template.guardable = false
		template.perilous = true
		template.deflectable = _peril_kind == Peril.THRUST
		template.deflect_within = ai.perilous_deflect_window
		if _peril_kind == Peril.THRUST:
			template.knockback = ai.perilous_thrust_knockback
			template.knockback_time = ai.perilous_knockback_time
		if _peril_kind == Peril.GRAB:
			# The grab: its own numbers, never deflectable, and it always breaks the guard.
			template.damage = ai.grab_damage
			template.posture_damage = ai.grab_posture
			template.knockback = ai.grab_knockback
			template.grab = true
	var landed := hitbox.sweep(template)
	if _peril_kind == Peril.GRAB and not landed.is_empty():
		_grab_connected = true


func _end_hit() -> void:
	_runner.end_hit(sword_visual.hitbox)


## Drop whatever attack is running (flinch, stun, death).
func _abort_attack() -> void:
	_burst_armored = false
	_end_hit()
	_cancel_perilous()
	if phase == Phase.ATTACK:
		sword_visual.end_combo()


# --- Perilous attacks (7c-1: thrust and sweep) ----------------------------------------------------

## Which perilous attack (if any) to start now instead of a burst. Debug Force Perilous wins.
func _pick_perilous(distance: float, chance: float) -> int:
	if debug_force_perilous != Peril.NONE:
		return debug_force_perilous if _peril_available(debug_force_perilous, true) else Peril.NONE
	var provoked_chance := chance + (ai.provoke_perilous_bonus * _provoke_level() if chance > 0.0 else 0.0)
	if _peril_cooldown > 0.0 or distance > ai.perilous_range or randf() >= provoked_chance:
		return Peril.NONE
	var options: Array[int] = []
	for kind: int in [Peril.THRUST, Peril.SWEEP, Peril.GRAB]:
		if kind == Peril.GRAB and distance > ai.grab_range:
			continue
		if _peril_available(kind, false) and not _peril_repeated(kind):
			options.append(kind)
	if options.is_empty():
		return Peril.NONE
	return options[randi() % options.size()]


func _peril_available(kind: int, ignore_switch: bool) -> bool:
	match kind:
		Peril.THRUST:
			return weapon.thrust != null and (ignore_switch or ai.perilous_thrust)
		Peril.SWEEP:
			return ai.sweep_action != null and (ignore_switch or ai.perilous_sweep)
		Peril.GRAB:
			return ai.grab_action != null and (ignore_switch or ai.perilous_grab)
	return false


## Would this be the same attack more than perilous_repeat_limit times in a row (and is there another)?
func _peril_repeated(kind: int) -> bool:
	if ai.perilous_repeat_limit <= 0 or _peril_history.size() < ai.perilous_repeat_limit:
		return false
	var other := Peril.SWEEP if kind == Peril.THRUST else Peril.THRUST
	if not _peril_available(other, false):
		return false
	for i in range(_peril_history.size() - ai.perilous_repeat_limit, _peril_history.size()):
		if _peril_history[i] != kind:
			return false
	return true


func _start_perilous(kind: int) -> void:
	drop_guard()
	_defense.riposte_pending = false
	_defense.reset_guard_streak()
	_peril_kind = kind
	_peril_time = 0.0
	_peril_history.append(kind)
	if _peril_history.size() > 4:
		_peril_history.pop_front()
	_set_phase(Phase.PERILOUS)
	if debug_log and OS.is_debug_build():
		print("[Enemy] perilous %s" % Peril.keys()[kind])
	if kind == Peril.THRUST:
		# The telegraph is the player's own charge: the pull back and the orange glow.
		_peril_charging = true
		_action = weapon.thrust
		_action_time = 0.0
		sword_visual.begin_charge()
	else:
		_peril_charging = false
		_action = ai.sweep_action if kind == Peril.SWEEP else ai.grab_action
		_action_time = 0.0
		_grab_connected = false
		_lunge_dir = _flat_to_player().normalized()
		sword_visual.begin_action(_action)
		if kind == Peril.SWEEP:
			sword_visual.set_drop_target(ai.sweep_drop)


func _update_perilous(delta: float, to_player: Vector3, distance: float, has_target: bool) -> void:
	if _peril_kind == Peril.NONE:
		_set_phase(Phase.CHASE)
		return
	var thrust_charge := _peril_kind == Peril.THRUST and _peril_charging
	var time_to_hit: float
	if thrust_charge:
		_peril_time += delta
		_decelerate(delta)
		_face(to_player, delta, ai.attack_turn_speed)
		var fraction := clampf(_peril_time / maxf(weapon.thrust.charge_time, 0.001), 0.0, 1.0)
		sword_visual.update_charge(weapon.thrust, false, _peril_time, fraction)
		time_to_hit = (weapon.thrust.charge_time - _peril_time) + weapon.thrust.active_hit.x
		if fraction >= 1.0:
			_fire_perilous_thrust(to_player)
	else:
		_action_time += delta
		if _action_time < _action.active_hit.x:
			_face(to_player, delta, ai.attack_turn_speed)
			if to_player.length_squared() > 0.0001:
				_lunge_dir = to_player.normalized()
		sword_visual.update_action(_action, _action_time, false)
		_update_hit()
		_apply_lunge(delta, distance)
		time_to_hit = _action.active_hit.x - _action_time
	var window_closed := not thrust_charge and _action_time >= _action.active_hit.y
	if has_target:
		if window_closed:
			_hide_symbol()
		elif time_to_hit <= ai.perilous_symbol_lead:
			_show_symbol()
			if _check_counter(distance):
				return
	if not thrust_charge and _action_time >= _action.duration:
		_end_perilous()


## Charge full: fire the thrust (the weapon's thrust action, authored right-handed).
func _fire_perilous_thrust(to_player: Vector3) -> void:
	_peril_charging = false
	_action = weapon.thrust
	_action_time = 0.0
	_lunge_dir = to_player.normalized() if to_player.length_squared() > 0.0001 else -global_transform.basis.z
	sword_visual.begin_action(_action)


## Mikiri (thrust) or the jump-over (sweep): true if the player answered it and the attack was cut.
func _check_counter(distance: float) -> bool:
	var player_node := _player as Player
	if player_node == null or player_node.state_machine == null or distance > ai.mikiri_range:
		return false
	if _peril_kind == Peril.THRUST:
		var dodge := player_node.state_machine.current as DodgeState
		if dodge == null:
			return false
		var dir := dodge.get_move_direction()
		var to_enemy := global_position - player_node.global_position
		to_enemy.y = 0.0
		if dir.length_squared() < 0.0001 or to_enemy.length_squared() < 0.0001:
			return false
		if rad_to_deg(dir.angle_to(to_enemy)) > ai.mikiri_angle:
			return false
		_countered(ai.mikiri_posture, ai.mikiri_stun, "mikiri", false)
		return true
	if _peril_kind == Peril.SWEEP and not player_node.is_on_floor():
		# Jumping only arms the counter: the sweep goes on under the player, and landing on this head
		# (on_stomped) is the parry.
		_head_bounce_time = ai.head_bounce_window
	return false


## The attack is cut: posture added, then a stun with no guard and no flinch. A posture break opens
## the deathblow window instead (the usual stun).
## The posture is full (Step 11c): a shake. The stun itself is handled by the deathblow window.
func _on_posture_broken() -> void:
	Fx.play(get_tree(), Fx.Kind.POSTURE_BREAK, global_position + Vector3.UP * 1.2)


func _countered(posture: float, stun: float, label: String, jump_over: bool) -> void:
	Fx.play(get_tree(), Fx.Kind.HEAD_STOMP if jump_over else Fx.Kind.MIKIRI, global_position + Vector3.UP * (1.8 if jump_over else 0.05))
	if debug_log and OS.is_debug_build():
		print("[Enemy] %s! +%.0f posture, stun %.1f s" % [label, posture, stun])
	_abort_attack()
	sword_visual.end_combo()
	if _player != null:
		var away := global_position - _player.global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			_recoil = 1.0
			_recoil_scale = 1.5
			_recoil_direction = away.normalized()
	# The bobblehead flinch (a posture break below replaces it with the heavy stun sway).
	if jump_over:
		_start_bobble(bobble_tilt, bobble_time, bobble_cycles)
	else:
		_start_bobble(bobble_tilt * 0.7, bobble_time * 0.6, bobble_cycles * 0.7)
	combatant.add_posture(posture)
	if combatant.deathblow_open:
		return
	_phase_timer = stun
	_set_phase(Phase.COUNTERED)


func _end_perilous() -> void:
	var whiffed := _peril_kind == Peril.GRAB and not _grab_connected
	_end_hit()
	_cancel_perilous()
	sword_visual.end_combo()
	_start_recover()
	if whiffed:
		_phase_timer = ai.grab_whiff_recovery


## Forget the perilous attack (it ended, was cut, or was interrupted): symbol off, swing back up.
func _cancel_perilous() -> void:
	if _peril_kind == Peril.NONE and not _symbol_shown:
		return
	if _peril_kind != Peril.NONE:
		_peril_cooldown = ai.perilous_cooldown
	_peril_kind = Peril.NONE
	_peril_charging = false
	_hide_symbol()
	sword_visual.set_drop_target(0.0)


func _show_symbol() -> void:
	if _symbol_shown:
		return
	if _symbol == null or not is_instance_valid(_symbol):
		_symbol = get_tree().get_first_node_in_group(Groups.DANGER_SYMBOL) as DangerSymbol
	if _symbol == null:
		if not _symbol_missing_warned:
			_symbol_missing_warned = true
			push_error("Enemy: no DangerSymbol found (add the Label3D with danger_symbol.gd under the Player).")
		return
	_symbol_shown = true
	Sfx.play(get_tree(), Sfx.Id.DANGER_YELLOW if _peril_kind == Peril.GRAB else Sfx.Id.DANGER_RED)
	_symbol.show_danger(self, ai.grab_symbol_color if _peril_kind == Peril.GRAB else Color(1.0, 0.1, 0.1))


func _hide_symbol() -> void:
	if not _symbol_shown:
		return
	_symbol_shown = false
	if _symbol != null and is_instance_valid(_symbol):
		_symbol.hide_danger(self)


# --- Movement helpers ---------------------------------------------------------------------------

## The player is dead: cut any swing, guard, or pose and go idle, once (a flinch, a counter, or a
## stun finishes by itself). _stand_down_ended() runs when the player is alive again.
func _stand_down() -> void:
	if _stood_down:
		return
	_stood_down = true
	_stand_down_was_combat = phase != Phase.IDLE
	_abort_attack()
	drop_guard()
	_defense.riposte_pending = false
	_end_pose()
	if phase != Phase.FLINCH and phase != Phase.COUNTERED and phase != Phase.STUNNED:
		_set_phase(Phase.IDLE)
	if _awareness != null:
		_awareness.reset()


## The player came back (a resurrection): the enemy keeps its health and posture, and starts with a
## short yield (it keeps its distance and circles) instead of rushing in.
func _stand_down_ended() -> void:
	_stood_down = false
	if phase == Phase.IDLE and (_awareness == null or _stand_down_was_combat):
		_start_yield()


## The player this enemy is tracking (null before it was found). The awareness helper reads it.
func get_target() -> Node3D:
	return _player


## It spotted the player or was hit while unaware: it enters combat after a short reaction time, and shouts.
func _enter_combat(by_hit: bool = false) -> void:
	_stealth_grace_left = 0.0 if by_hit else ai.stealth_grace_time
	if _awareness != null:
		_awareness.on_spotted()
	_think_timer = maxf(_think_timer, ai.spot_reaction_time)
	_set_phase(Phase.CHASE)


## The player's debug switch (F4): this enemy cannot notice the player at `aggro_range`.
func _player_undetectable() -> bool:
	var player := _player as Player
	return player != null and player.debug_undetectable


## Item 7d: the enemy stays down: it tips over backward, goes grey, loses its collider, hurtbox and bar, and
## never respawns (the scene reload does it). Guards find it through is_undiscovered_corpse().
func _become_corpse() -> void:
	_is_corpse = true
	corpse_discovered = false
	bar.visible = false
	body_shape.set_deferred("disabled", true)
	var hurtbox := get_node_or_null("Hurtbox") as Area3D
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", false)
		hurtbox.set_deferred("monitoring", false)
	if _corpse_material == null:
		_corpse_material = StandardMaterial3D.new()
		_corpse_material.albedo_color = Color(0.3, 0.3, 0.33)
	body.material_override = _corpse_material
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "rotation:x", deg_to_rad(90.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "position:y", 0.4, 0.35)


func is_corpse() -> bool:
	return _is_corpse


## Item 10: knocked out and lying there.
func is_unconscious() -> bool:
	return _unconscious


## A body (dead or unconscious) no guard has seen yet.
func is_undiscovered_body() -> bool:
	return (_is_corpse or _unconscious) and not corpse_discovered and not _carried and not _body_flying


## Item 15a: the player is carrying this body.
func is_carried() -> bool:
	return _carried


func set_carried(on: bool) -> void:
	_carried = on
	if on:
		_body_falling = false
		scale = Vector3.ONE


## Item 15a: the player lets go of the body: it is set at `at` facing `yaw` (its tipped-over pose is kept), or,
## with `fall`, starts to fall from there until it lands (below -30 m it is lost for good). Item 15b: a body
## stuffed into a container is shrunk to `body_scale`; picking it up or waking restores the size.
func place_body(at: Vector3, yaw: float, fall: bool, body_scale: float = 1.0) -> void:
	_carried = false
	scale = Vector3.ONE * body_scale
	global_position = at
	global_rotation = Vector3(0.0, yaw, 0.0)
	_body_falling = fall
	_body_fall_speed = 0.0


## Item 15a: where this lying body's root goes so its middle is at `center` with the root turned by `basis`. The
## root is at the feet; the tipped-over body's middle is LYING_MIDDLE from it (in the root's own axes).
const LYING_MIDDLE: Vector3 = Vector3(0.0, 0.4, 0.9)


func lying_root_for(center: Vector3, body_basis: Basis) -> Vector3:
	return center - body_basis * LYING_MIDDLE


## Item 15b: the middle of the lying body, in the world.
func get_lying_middle() -> Vector3:
	return global_position + global_basis * LYING_MIDDLE


## Item 15b: a body (dead or unconscious) lying mostly inside a `CoverVolume` (most of its points along its
## length): guards cannot discover it by sight.
func is_hidden_in_cover() -> bool:
	if _carried or _body_flying or not (_is_corpse or _unconscious):
		return false
	var middle := get_lying_middle()
	var along := global_basis * Vector3(0.0, 0.0, 1.0)
	var points: Array[Vector3] = []
	for t in CoverVolume.POINT_OFFSETS:
		points.append(middle + along * t)
	return CoverVolume.count_inside(get_tree(), points) >= CoverVolume.MIN_POINTS


## Item 15c: the player throws the body: its middle starts at `middle`, head first along the throw, flying with
## `velocity` and `data`'s gravity until the first world surface or guard (`_fly_body`), then it settles on the floor.
func launch_body(thrower: Player, data: ThrowableData, middle: Vector3, throw_velocity: Vector3) -> void:
	_carried = false
	_body_falling = false
	scale = Vector3.ONE
	_flight_thrower = thrower
	_flight_data = data
	_flight_velocity = throw_velocity
	var flat := Vector3(throw_velocity.x, 0.0, throw_velocity.z)
	var yaw := atan2(flat.x, flat.z) if flat.length_squared() > 0.0001 else global_rotation.y
	global_rotation = Vector3(0.0, yaw, 0.0)
	global_position = lying_root_for(middle, Basis(Vector3.UP, yaw))
	_body_flying = true


## One physics step of a thrown body. Points on the body (its underside for the floor, its axis for walls and
## guards) are traced with the same ray a thrown item uses; the first thing met stops the body: a guard's
## hurtbox takes the hit (the same numbers as a thrown item, `ThrowableData`), the landing is heard, and the body
## then settles on the floor (`_body_falling`).
func _fly_body(delta: float) -> void:
	_flight_velocity.y -= _flight_data.gravity * delta
	var step := _flight_velocity * delta
	var body_basis := Basis(Vector3.UP, global_rotation.y)
	var middle := get_lying_middle()
	var exclude := Throwable.make_exclude(_flight_thrower)
	var own_hurtbox := get_node_or_null("Hurtbox") as Hurtbox
	if own_hurtbox != null:
		exclude.append(own_hurtbox.get_rid())
	var best: Dictionary = {}
	var best_distance := INF
	var best_from := Vector3.ZERO
	for sample: Vector3 in [Vector3(0.0, -0.4, 0.0), Vector3(0.0, -0.4, 0.8), Vector3(0.0, -0.4, -0.8),
			Vector3(0.0, 0.0, 0.8), Vector3(0.0, 0.0, -0.8), Vector3.ZERO]:
		var from := middle + body_basis * sample
		var result := Throwable.trace(_flight_thrower, from, from + step, exclude.duplicate())
		if result.is_empty():
			continue
		var distance := from.distance_to(result["position"] as Vector3)
		if distance < best_distance:
			best = result
			best_distance = distance
			best_from = from
	if best.is_empty():
		global_position += step
		if global_position.y < -30.0:
			queue_free()
		return
	var point: Vector3 = best["position"]
	global_position += (point - best_from) + (best["normal"] as Vector3) * 0.02
	var hurtbox := best.get("collider") as Hurtbox
	var tree := get_tree()
	if hurtbox != null:
		Throwable.apply_hit(_flight_thrower, _flight_data, hurtbox, point, _flight_velocity)
	else:
		Fx.play(tree, Fx.Kind.LAND_DUST, point)
		Sfx.play_at(tree, Sfx.Id.LAND_HARD, point)
	Throwable.broadcast_noise(point, _flight_data.noise)
	_body_flying = false
	_body_falling = true
	_body_fall_speed = 0.0


func _fall_body(delta: float) -> void:
	_body_fall_speed += float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)) * delta
	var step := _body_fall_speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1,
			global_position + Vector3.DOWN * (step + 0.05), Layers.WORLD, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = (hit["position"] as Vector3).y
		_body_falling = false
		return
	global_position.y -= step
	if global_position.y < -30.0:
		queue_free()


## Item 10: the player's choke holds this enemy (true) or lets go (false).
func set_held(held: bool) -> void:
	if _held == held:
		return
	_held = held
	_held_amount = 0.0
	_held_clock = 0.0
	velocity = Vector3.ZERO
	if not held:
		visual.position = Vector3.ZERO
		visual.basis = Basis.IDENTITY


## The choke's progress, 0 to 1: it struggles at first (a shake and a lean back), then goes limp (it droops forward).
func set_held_amount(amount: float) -> void:
	_held_amount = clampf(amount, 0.0, 1.0)


func _update_held_pose(delta: float) -> void:
	_held_clock += delta
	var limp := smoothstep(0.55, 1.0, _held_amount)
	var shake := (1.0 - limp) * 0.04
	visual.position = Vector3(sin(_held_clock * 58.0) * shake, 0.0, cos(_held_clock * 47.0) * shake * 0.5)
	var lean := lerpf(deg_to_rad(-14.0), deg_to_rad(38.0), limp)
	visual.basis = Basis(Vector3.RIGHT, lean)


## A body no guard has seen yet.
func is_undiscovered_corpse() -> bool:
	return _is_corpse and not corpse_discovered and not _carried and not _body_flying


func mark_corpse_discovered() -> void:
	corpse_discovered = true


## Item 7b: can a fresh attack press kill this enemy silently right now? It needs awareness, and either
## Phase.IDLE (unaware, suspicious or searching) or the short grace after it spotted the player by sight or sound.
func can_be_stealth_killed() -> bool:
	if _awareness == null or combatant.dead or combatant.deathblow_open or _stood_down:
		return false
	if phase == Phase.IDLE:
		return true
	return phase == Phase.CHASE and _stealth_grace_left > 0.0


## Counts the grace down and shows the red marker while the player could stealth-kill this enemy now.
func _update_stealth_marker(delta: float) -> void:
	_stealth_grace_left = maxf(_stealth_grace_left - delta, 0.0)
	if _awareness == null:
		return
	var player := _player as Player
	bar.set_stealth_marker(player != null and can_be_stealth_killed() \
			and (player.can_stealth_kill(self) or player.can_aerial_kill(self)))


## Another enemy shouted (EnemyAwareness): `player_position` is where the player is.
func hear_shout(player_position: Vector3, close: bool) -> void:
	if _awareness != null and phase == Phase.IDLE and not combatant.dead:
		_awareness.hear_shout(player_position, close)


## Phase 2 item 11a: a thrown item landed at `point` and made `radius` m of noise. An enemy with awareness that is
## not in combat (and not unconscious) may turn suspicious and go to look.
func hear_noise_at(point: Vector3, radius: float) -> void:
	if _awareness != null and phase == Phase.IDLE and not combatant.dead and not _unconscious:
		_awareness.hear_noise_at(point, radius)


## Phase 2 item 11.5: the player taunted at `point`. An enemy in combat within `provoke_range` (m) is provoked; one
## that is not in combat hears it as a noise of `noise_radius` (m) and may turn suspicious.
func hear_taunt(point: Vector3, provoke_range: float, noise_radius: float) -> void:
	if combatant.dead or _unconscious or _held:
		return
	if phase == Phase.IDLE:
		hear_noise_at(point, noise_radius)
	elif global_position.distance_to(point) <= provoke_range:
		provoke()


## One more taunt stack (up to `EnemyAIData.provoke_max_stacks`) and the clear timer restarts. The stacks make it
## rest less, wind up faster, go perilous more often and (at 2 stacks) attack longer; see `EnemyAIData`.
func provoke() -> void:
	if ai.provoke_max_stacks <= 0 or combatant.dead or _unconscious or _held:
		return
	_provoke_stacks = mini(_provoke_stacks + 1, ai.provoke_max_stacks)
	_provoke_left = ai.provoke_duration
	_apply_provoke_tint()
	Sfx.play_at(get_tree(), Sfx.Id.ENEMY_PROVOKED, global_position + Vector3.UP * 1.4)


## The strength of the taunt on this enemy: the stacks, times the boss share for a boss.
func _provoke_level() -> float:
	if _provoke_stacks <= 0:
		return 0.0
	return float(_provoke_stacks) * (ai.provoke_boss_factor if boss else 1.0)


## 1 once the level reaches `provoke_burst_bonus_at` (its bursts get one more attack), else 0.
func _provoke_burst_bonus() -> int:
	if ai.provoke_burst_bonus_at <= 0 or _provoke_level() < float(ai.provoke_burst_bonus_at):
		return 0
	return 1


func _tick_provoke(delta: float) -> void:
	if _provoke_stacks <= 0:
		return
	_provoke_left -= delta
	if _provoke_left <= 0.0:
		_clear_provoke()


func _clear_provoke() -> void:
	if _provoke_stacks <= 0:
		return
	_provoke_stacks = 0
	_provoke_left = 0.0
	_apply_provoke_tint()


## The body color moves toward `provoke_tint` with the stacks (the base material is the one every state returns to).
func _apply_provoke_tint() -> void:
	if _base_material == null:
		return
	var share := clampf(_provoke_level() / float(maxi(ai.provoke_max_stacks, 1)), 0.0, 1.0)
	_base_material.albedo_color = body_color.lerp(ai.provoke_tint, share * ai.provoke_tint_strength)


## What the awareness HUD draws: the meter (0 to 1), the level, whether it is in combat, and a stamp that changes
## every time it spots the player. Empty when it has no awareness or is dead.
func get_awareness_info() -> Dictionary:
	if _awareness == null or combatant.dead:
		return {}
	return {
		"meter": _awareness.meter,
		"level": int(_awareness.level),
		"combat": phase != Phase.IDLE,
		"stamp": _awareness.spotted_stamp,
	}


## One line for the debug overlay.
func get_awareness_debug() -> String:
	if _awareness == null or combatant.dead:
		return ""
	if phase != Phase.IDLE:
		return "%s COMBAT" % name
	return _awareness.debug_text()


## True when the player is on another level than this enemy can follow (no pathfinding, item 7a).
## Item 12a: the flat unit direction of the next step on the navmesh path toward `point`, or zero when the path
## is finished, missing, or the navigation could not be set up. Only meaningful when `use_navigation` is on.
func nav_direction(point: Vector3) -> Vector3:
	if _navigation == null:
		return Vector3.ZERO
	return _navigation.direction_to(point)


func _is_out_of_reach() -> bool:
	return _awareness != null and _player != null \
			and not can_reach_height(_player.global_position.y - global_position.y, 1.0)


## Item 12b-1a: whether a point `dy` m above (positive) or below (negative) this enemy is on a level it can deal
## with: within `max_vertical_reach`, and for an enemy with links also `nav_drop_max_height` further below and
## `nav_climb_max_height` further above (0 = not at all). `slack` widens the limit (the chase gives up a meter
## later). Without `use_nav_links` this is the old `absf(dy) <= max_vertical_reach`.
func can_reach_height(dy: float, slack: float = 0.0) -> bool:
	var limit: float = ai.max_vertical_reach + slack
	if use_nav_links and _navigation != null:
		if dy < 0.0:
			limit += ai.nav_drop_max_height
		else:
			limit += ai.nav_climb_max_height
	return absf(dy) <= limit


## The boss HUD (BossHud) asks these: a boss is engaged once it has noticed the player (it left IDLE),
## until it dies or loses the player (back to IDLE, which also happens while the player is dead).
func is_boss_engaged() -> bool:
	return boss and not combatant.dead and phase != Phase.IDLE


func get_boss_name() -> String:
	return display_name if display_name != "" else String(name)


## The boss HUD shows (or stops showing) this boss's health and posture: hide (or show) the floating bars.
func set_boss_hud_shown(shown: bool) -> void:
	bar.set_bars_hidden(shown)


func _find_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(Groups.PLAYER) as Node3D


func _player_dead() -> bool:
	var player_combatant := Combatant.of(_player)
	return player_combatant != null and player_combatant.dead


func _flat_to_player() -> Vector3:
	if _player == null or not is_instance_valid(_player):
		return Vector3.ZERO
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	return to_player


func _face(to_player: Vector3, delta: float, speed: float) -> void:
	if to_player.length_squared() < 0.0001:
		return
	var yaw := atan2(-to_player.x, -to_player.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-speed * delta))


## The gravity (m/s^2) this enemy falls with; a jump link's arc is computed from it.
func gravity_strength() -> float:
	return _gravity


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= _gravity * delta


func _move_toward_velocity(target: Vector3, delta: float) -> void:
	# The edge guard (item 7a): an awareness enemy does not walk off a ledge.
	if _awareness != null and target.length_squared() > 0.0001 and not _awareness.edge_safe(target):
		target = Vector3.ZERO
	velocity.x = move_toward(velocity.x, target.x, ai.acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, ai.acceleration * delta)


func _decelerate(delta: float) -> void:
	_move_toward_velocity(Vector3.ZERO, delta)


func _set_phase(new_phase: Phase) -> void:
	if debug_log and OS.is_debug_build() and new_phase != phase:
		print("[Enemy] %s -> %s" % [Phase.keys()[phase], Phase.keys()[new_phase]])
	var old_phase := phase
	phase = new_phase
	if bar != null:
		bar.set_in_combat(not bars_only_in_combat or new_phase != Phase.IDLE)
	if not EnemyDefense.phase_allows_guard(new_phase):
		drop_guard()
	if _awareness != null:
		if new_phase != Phase.IDLE:
			_awareness.hide_symbol()
		elif old_phase != Phase.IDLE and not _stood_down and not combatant.dead and _player != null:
			# It lost the player in combat: it goes to where it last saw it and searches.
			drop_guard()
			_awareness.begin_search(_player.global_position)


func _return_to_spawn() -> void:
	global_position = _spawn_position
	rotation.y = _spawn_yaw
	velocity = Vector3.ZERO


# --- Combatant signals --------------------------------------------------------------------------

## An unguarded hit landed: the recoil wobble always, a flinch if this moment allows it.
func _on_damaged(hit: HitData, _amount: float) -> void:
	# A hit on an enemy that had not noticed the player: it notices at once (item 7a).
	_stealth_grace_left = 0.0
	if _awareness != null and phase == Phase.IDLE and not combatant.dead:
		_enter_combat(true)
	_defense.on_unguarded_hit()
	_recoil = 1.0
	_recoil_scale = 1.0
	_recoil_direction = hit.direction
	var flinch := _should_flinch()
	if phase == Phase.POSE:
		_end_pose()
	if flinch:
		_start_flinch()


func _on_guarded(hit: HitData, _chip: float) -> void:
	_guard_reaction(hit, false)


func _on_deflected(hit: HitData) -> void:
	_guard_reaction(hit, true)
	_defense.on_deflected()


## A lighter wobble, the blade flick and flash (as the player's guard), and the guard stays up a bit.
func _guard_reaction(hit: HitData, deflect: bool) -> void:
	_defense.on_guard_reaction()
	_recoil = 1.0
	_recoil_scale = deflect_recoil_scale if deflect else guard_recoil_scale
	_recoil_direction = hit.direction
	var local_dir := global_transform.basis.inverse() * -hit.direction
	if deflect:
		sword_visual.play_deflect(hit, local_dir.x)
	else:
		sword_visual.play_guard_hit(false, local_dir.x)


## Stunned (empty bar or posture break): drop any swing, guard, and pose, and turn pale.
func _on_deathblow_opened() -> void:
	# Item 7b: a stealth kill that left a boss on empty health: it now knows about the player.
	var was_unaware := combatant.stealth_kill_active and _awareness != null and phase == Phase.IDLE
	_abort_attack()
	drop_guard()
	_defense.riposte_pending = false
	_end_pose()
	_set_phase(Phase.STUNNED)
	body.material_override = _stun_material
	_start_stun_bobble()
	if was_unaware:
		_awareness.on_spotted()


## The window closed: back to normal. A landed deathblow also makes it recoil from the player.
func _on_deathblow_closed(executed: bool, killed: bool) -> void:
	if executed and combatant.last_blow_lethal:
		var blow := Vector3.ZERO
		if _player != null:
			blow = global_position - _player.global_position
			blow.y = 0.0
		Fx.play(get_tree(), Fx.Kind.DEATHBLOW, global_position + Vector3.UP * 1.2, blow, visual)
	body.material_override = _base_material
	_end_stun_bobble()
	if phase == Phase.STUNNED:
		_start_recover()
	# Item 7b: a boss that survived a stealth kill turns to combat (the sound and the shout).
	if executed and not killed and combatant.stealth_kill_active and _awareness != null and phase == Phase.IDLE:
		_enter_combat(true)
	if executed and _player != null:
		var away := global_position - _player.global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			_recoil = 1.0
			_recoil_scale = 1.0
			_recoil_direction = away.normalized()


## Item 10: a non-lethal blow finished it. Like dying (nothing keeps fighting, a carried body is dropped, the
## awareness resets) but it stays here, tipped over, and wakes later (see `_tick_wake`). No victory banner.
func _on_knocked_out() -> void:
	_clear_provoke()
	if _navigation != null:
		_navigation.cancel_crossing()
	bar.set_stealth_marker(false)
	Sfx.play_at(get_tree(), Sfx.Id.ENEMY_FLINCH, global_position + Vector3.UP * 1.0)
	set_held(false)
	if _awareness != null:
		_awareness.drop_carried()
		_awareness.reset()
	_abort_attack()
	drop_guard()
	_defense.riposte_pending = false
	_end_pose()
	_end_stun_bobble()
	_set_phase(Phase.IDLE)
	_unconscious = true
	corpse_discovered = false
	_wake_left = wake_time if not boss else 0.0
	bar.visible = false
	body_shape.set_deferred("disabled", true)
	var hurtbox := get_node_or_null("Hurtbox") as Area3D
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", false)
		hurtbox.set_deferred("monitoring", false)
	if _unconscious_material == null:
		_unconscious_material = StandardMaterial3D.new()
		_unconscious_material.albedo_color = Color(0.35, 0.42, 0.62)
	body.material_override = _unconscious_material
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "rotation:x", deg_to_rad(90.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "position:y", 0.4, 0.35)


## Counts down to waking up by itself (a boss and `wake_time` 0 never do), and waits while the player is near.
func _tick_wake(delta: float) -> void:
	if _wake_left <= 0.0 and (boss or wake_time <= 0.0):
		return
	_wake_left = maxf(_wake_left - delta, 0.0)
	if _wake_left > 0.0:
		return
	if _player == null or not is_instance_valid(_player):
		_find_player()
	if _player != null:
		var away := _player.global_position - global_position
		away.y = 0.0
		if away.length() < wake_player_distance:
			return
	wake_up(Vector3.ZERO, true)


## Wake up (item 10): upright, healthy, solid again. `at_post` puts it back at its post, unaware (the timer);
## otherwise it wakes where it lies and is made suspicious about `from_position` (a guard woke it).
func wake_up(from_position: Vector3, at_post: bool) -> void:
	if not _unconscious:
		return
	_unconscious = false
	corpse_discovered = false
	scale = Vector3.ONE
	body.material_override = _base_material
	visual.rotation.x = 0.0
	visual.position = Vector3.ZERO
	if at_post:
		_return_to_spawn()
	combatant.reset()
	bar.visible = true
	bar.set_in_combat(not bars_only_in_combat, true)
	body_shape.set_deferred("disabled", false)
	var hurtbox := get_node_or_null("Hurtbox") as Area3D
	if hurtbox != null:
		hurtbox.set_deferred("monitorable", true)
		hurtbox.set_deferred("monitoring", true)
	_defense.reset_for_respawn()
	_flinch_immunity = 0.0
	_burst_armored = false
	_peril_cooldown = 0.0
	_head_bounce_time = 0.0
	_peril_history.clear()
	_think_timer = 0.5
	_set_phase(Phase.IDLE)
	if _awareness != null:
		_awareness.reset()
		if not at_post:
			_awareness.hear_shout(from_position, false)


func _on_died() -> void:
	_clear_provoke()
	if _navigation != null:
		_navigation.cancel_crossing()
	bar.set_stealth_marker(false)
	Sfx.play_at(get_tree(), Sfx.Id.ENEMY_DEATH, global_position + Vector3.UP * 1.0)
	if boss and ai != null:
		# Step 11d: the VictoryScreen (group "victory_screen") shows the boss-slain banner.
		get_tree().call_group(Groups.VICTORY_SCREEN, "show_victory", ai.victory_kanji, ai.victory_text)
	if _awareness != null:
		_awareness.drop_carried()
		_awareness.reset()
	_abort_attack()
	drop_guard()
	_defense.riposte_pending = false
	_end_pose()
	_end_stun_bobble()
	body.material_override = _base_material
	if leaves_corpse and use_awareness and not boss:
		_become_corpse()
		return
	visual.visible = false
	bar.visible = false
	body_shape.set_deferred("disabled", true)
	await get_tree().create_timer(respawn_delay).timeout
	_return_to_spawn()
	combatant.reset()
	visual.visible = true
	bar.visible = true
	bar.set_in_combat(not bars_only_in_combat, true)
	body_shape.set_deferred("disabled", false)
	_defense.reset_for_respawn()
	_flinch_immunity = 0.0
	_burst_armored = false
	_peril_cooldown = 0.0
	_head_bounce_time = 0.0
	_peril_history.clear()
	_think_timer = 0.5
	_set_phase(Phase.IDLE)
	if _awareness != null:
		_awareness.reset()
