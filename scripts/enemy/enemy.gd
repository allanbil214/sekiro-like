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
## Needs the nodes listed in the Step 7 instructions (a missing one is an error on purpose).

enum Phase { IDLE, CHASE, ATTACK, RECOVER, YIELD, STUNNED, FLINCH, POSE, PERILOUS, COUNTERED }
enum Peril { NONE, THRUST, SWEEP, GRAB }

## The hit streak (see EnemyAIData.hit_streak_limit) resets after this long (s) without a hit.
const STREAK_RESET_TIME: float = 3.0
## Random jitter (s) on when a planned deflect presses, so it is not machine-perfect.
const PRESS_JITTER: float = 0.03

@export var ai: EnemyAIData
@export var weapon: WeaponData
@export var respawn_delay: float = 2.0
## Health bars, boss flag, and deathblow window (s); copied to the Combatant at startup.
@export var health_bars: int = 2
@export var boss: bool = false
@export var deathblow_window: float = 4.0
@export var gravity_multiplier: float = 2.0
@export var body_color: Color = Color(0.75, 0.3, 0.25)
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
var _gravity: float = 9.8
var _think_timer: float = 0.0
var _phase_timer: float = 0.0
var _strafe_sign: float = 1.0
var _strafe_timer: float = 0.0
var _action: ActionData
var _action_time: float = 0.0
var _combo_index: int = 0
var _burst_total: int = 0
var _chain_wait: float = 0.0
var _lunge_dir: Vector3 = Vector3.ZERO
var _hit_was_active: bool = false
var _recoil: float = 0.0
var _recoil_scale: float = 1.0
var _recoil_direction: Vector3 = Vector3.ZERO
var _base_material: StandardMaterial3D
var _stun_material: StandardMaterial3D
var _spawn_position: Vector3 = Vector3.ZERO
var _spawn_yaw: float = 0.0
# Defense state.
var _since_hit: float = 999.0
var _hit_streak: int = 0
var _flinch_immunity: float = 0.0
var _burst_armored: bool = false
var _guarded_streak: int = 0
var _break_threshold: int = 1
var _break_armed: bool = false
var _break_riposte: bool = false
var _since_guard_reaction: float = 999.0
var _press_lead: float = 0.0
var _since_player_attack: float = 999.0
var _guard_hold: float = 0.0
var _seen_action: ActionData
var _seen_time: float = 0.0
var _threat_active: bool = false
var _threat_action: ActionData
var _threat_time: float = 0.0
var _last_attack_action: ActionData
var _repeat_count: int = 0
var _react_timer: float = 0.0
var _plan_guard: bool = false
var _plan_deflect: bool = false
var _plan_repulse: bool = false
var _pressed: bool = false
var _riposte_pending: bool = false
var _riposte_timer: float = 0.0
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
var _bobble_droop: float = 0.0
var _bobble_sign: float = 1.0
var _visual_dirty: bool = false


func _ready() -> void:
	if ai == null or weapon == null or weapon.combo.is_empty():
		push_error("Enemy: set `ai` (EnemyAIData) and `weapon` (WeaponData with a combo) in the Inspector.")
		set_physics_process(false)
		return
	if sword_visual.hitbox == null:
		push_error("Enemy: the SwordVisual has no Hitbox assigned (set its Hitbox export in the Inspector).")
		set_physics_process(false)
		return
	add_to_group(&"enemy")
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
	combatant.damaged.connect(_on_damaged)
	combatant.hit_guarded.connect(_on_guarded)
	combatant.hit_deflected.connect(_on_deflected)
	combatant.died.connect(_on_died)
	combatant.deathblow_opened.connect(_on_deathblow_opened)
	combatant.deathblow_closed.connect(_on_deathblow_closed)
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
	_roll_break_threshold()


func _physics_process(delta: float) -> void:
	if combatant.dead:
		return
	if global_position.y < -30.0:
		_return_to_spawn()
	_since_hit += delta
	if _since_hit > STREAK_RESET_TIME:
		_hit_streak = 0
	_flinch_immunity = maxf(_flinch_immunity - delta, 0.0)
	_since_guard_reaction += delta
	if _since_guard_reaction > STREAK_RESET_TIME and (_guarded_streak > 0 or _break_armed):
		_break_armed = false
		_reset_guard_streak()
	_pose_cooldown = maxf(_pose_cooldown - delta, 0.0)
	_peril_cooldown = maxf(_peril_cooldown - delta, 0.0)
	_head_bounce_time = maxf(_head_bounce_time - delta, 0.0)
	var acting := phase == Phase.ATTACK or phase == Phase.PERILOUS
	combatant.tick_posture(delta, acting)
	combatant.tick_guard(delta, _guarding, acting)
	_apply_gravity(delta)
	if combatant.deathblow_open:
		# Stunned: no swings, no turning, until the window closes.
		_decelerate(delta)
		move_and_slide()
		return
	_find_player()
	_think_timer = maxf(_think_timer - delta, 0.0)
	var to_player := _flat_to_player()
	var distance := to_player.length()
	var has_target := _player != null and not _player_dead()
	_update_defense(delta, distance, has_target)
	_update_riposte(delta, has_target)
	match phase:
		Phase.IDLE:
			_decelerate(delta)
			if has_target and distance <= ai.aggro_range:
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
	var bobbing := _bobble_loop or _bobble_clock < _bobble_length
	if _recoil <= 0.0 and not bobbing:
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
	visual.position = offset
	visual.basis = bobble * tilt


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
	if not has_target or distance > ai.aggro_range * 1.5:
		_set_phase(Phase.IDLE)
		return
	_face(to_player, delta, ai.turn_speed)
	if distance > ai.engage_distance:
		var speed := ai.strafe_speed if _guarding else ai.run_speed
		_move_toward_velocity(to_player.normalized() * speed, delta)
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
	var yield_scale := lerpf(1.5, 0.5, ai.aggression)
	_phase_timer = randf_range(ai.yield_time.x, ai.yield_time.y) * yield_scale
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	_strafe_timer = randf_range(ai.strafe_switch_time.x, ai.strafe_switch_time.y)
	_set_phase(Phase.YIELD)


func _start_recover() -> void:
	_phase_timer = ai.recovery_time
	_set_phase(Phase.RECOVER)


func _start_flinch() -> void:
	_abort_attack()
	_riposte_pending = false
	_phase_timer = ai.hit_stun_time
	_set_phase(Phase.FLINCH)


## Riposte armor: from the deflect that earned the riposte until its burst ends.
func _is_armored() -> bool:
	return ai.riposte_armor and (_riposte_pending or (phase == Phase.ATTACK and _burst_armored))


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
			and _since_player_attack >= ai.pose_idle_time


func _start_pose() -> void:
	_drop_guard()
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


# --- Defense (guard, deflect, repulse, riposte) --------------------------------------------------

func _phase_allows_guard(p: Phase) -> bool:
	return p == Phase.IDLE or p == Phase.CHASE or p == Phase.YIELD


## Read the player's current attack. A new threat rolls the plan (guard or not, deflect or not,
## repulse or not) and a reaction delay; then the plan is carried out while the threat lasts.
func _update_defense(delta: float, distance: float, has_target: bool) -> void:
	var idle_before := _since_player_attack
	var state: ActionState = null
	var player_node := _player as Player
	if has_target and player_node != null and player_node.state_machine != null:
		state = player_node.state_machine.current as ActionState
	var attack: ActionData = null
	if state != null:
		attack = state.action
	var attacking := attack != null and attack.kind == ActionData.Kind.ATTACK \
			and attack.damage > 0.0 and state.action_time < attack.active_hit.y
	if attacking:
		_since_player_attack = 0.0
	else:
		_since_player_attack += delta
	# A charge holds the player's clock still: that is not a hit coming yet.
	var frozen := attacking and attack == _seen_action and is_equal_approx(state.action_time, _seen_time)
	_seen_action = attack if attacking else null
	_seen_time = state.action_time if attacking else 0.0
	var threat := attacking and not frozen and distance <= ai.threat_range
	var time_to_hit: float = INF
	if threat:
		time_to_hit = maxf((attack.active_hit.x - state.action_time) / maxf(state.speed_scale, 0.01), 0.0)
		if not _threat_active or attack != _threat_action or state.action_time < _threat_time:
			_begin_threat(attack, idle_before)
		_threat_time = state.action_time
		_threat_action = attack
	_threat_active = threat
	var can_guard := _phase_allows_guard(phase)
	if threat and _plan_guard and can_guard:
		_react_timer -= delta
		# A planned deflect presses on time whatever the reaction delay; only a plain guard waits for it.
		var pressing := _plan_deflect and not _pressed and time_to_hit <= _press_lead
		if _react_timer <= 0.0 or pressing:
			_guard_hold = ai.guard_hold_time
			_raise_guard(false, false)
			if pressing:
				_pressed = true
				_raise_guard(true, _plan_repulse)
				if debug_log:
					print("[Enemy] deflect press (%s), %.2f s before the hit" % [
						"repulse" if _plan_repulse else "normal", time_to_hit])
		return
	if _guarding:
		_guard_hold -= delta
		if _guard_hold <= 0.0 or not can_guard:
			_drop_guard()


func _begin_threat(attack: ActionData, idle_before: float) -> void:
	if idle_before > 3.0 or attack != _last_attack_action:
		_repeat_count = 0
	else:
		_repeat_count += 1
	_last_attack_action = attack
	_pressed = false
	var pressured := _since_hit <= ai.retry_window
	# Retry: after a landed hit the guard comes up at once (no reaction delay).
	_react_timer = 0.0 if pressured else randf_range(ai.reaction_delay.x, ai.reaction_delay.y)
	_press_lead = maxf(combatant.next_window() * 0.5 + randf_range(-PRESS_JITTER, PRESS_JITTER), 0.0)
	var guard_chance := ai.pressured_guard_chance if pressured else ai.neutral_guard_chance
	var deflect_chance := ai.pressured_deflect_chance if pressured else ai.neutral_deflect_chance
	guard_chance = clampf(guard_chance + ai.repeat_attack_guard_bonus * float(_repeat_count), 0.0, 1.0)
	_plan_guard = randf() < guard_chance
	var forced := ai.hit_streak_limit > 0 and _hit_streak >= ai.hit_streak_limit
	if forced:
		_plan_guard = true
	var breaking := _break_armed
	_break_armed = false
	_break_riposte = breaking
	if breaking:
		_plan_guard = true
	_plan_deflect = _plan_guard and (breaking or randf() < deflect_chance)
	_plan_repulse = _plan_deflect and randf() < ai.repulse_chance
	if debug_log:
		print("[Enemy] threat (%s, repeat %d, streak %d%s): guard=%s deflect=%s repulse=%s react %.2f s" % [
			"pressured" if pressured else "neutral", _repeat_count, _hit_streak,
			(", forced guard" if forced else "") + (", BREAK-OUT" if breaking else ""),
			_plan_guard, _plan_deflect, _plan_repulse, _react_timer])


## Raise the guard (stance); with `press`, also open a deflect window (a repulse window if asked).
func _raise_guard(press: bool, repulse: bool) -> void:
	var fresh := not _guarding
	_guarding = true
	combatant.guarding = true
	if fresh:
		sword_visual.play_guard(false)
	if press:
		combatant.press_guard(repulse)
		if not fresh:
			sword_visual.play_guard_press()


func _drop_guard() -> void:
	if not _guarding:
		return
	_guarding = false
	_guard_hold = 0.0
	combatant.guarding = false
	sword_visual.end_combo()


func _guard_facing() -> Vector3:
	return -global_transform.basis.z


func _update_riposte(delta: float, has_target: bool) -> void:
	if not _riposte_pending:
		return
	if not has_target or not _phase_allows_guard(phase):
		_riposte_pending = false
		return
	_riposte_timer -= delta
	if _riposte_timer <= 0.0:
		_riposte_pending = false
		if debug_log:
			print("[Enemy] riposte")
		_start_burst(ai.riposte_burst_count, true)


## Pressure break-out: how many of the player's hits in a row it takes before the next defense is
## forced (mostly pressure_break_hits, sometimes a random lower number).
func _roll_break_threshold() -> void:
	var hits := ai.pressure_break_hits
	if hits <= 1 or randf() >= ai.pressure_break_early_chance:
		_break_threshold = maxi(hits, 1)
	else:
		_break_threshold = randi_range(1, hits - 1)


func _reset_guard_streak() -> void:
	_guarded_streak = 0
	_roll_break_threshold()


func _count_guarded_hit() -> void:
	_since_guard_reaction = 0.0
	if ai.pressure_break_hits <= 0:
		return
	_guarded_streak += 1
	if _guarded_streak >= _break_threshold:
		_break_armed = true
		if debug_log:
			print("[Enemy] pressure: %d guarded hits in a row, next defense is a break-out" % _guarded_streak)
		_reset_guard_streak()


# --- Attacks (the weapon's ground combo) --------------------------------------------------------

func _start_burst(counts: Vector2i, armored: bool = false) -> void:
	_drop_guard()
	_riposte_pending = false
	_burst_armored = armored
	_reset_guard_streak()
	_burst_total = clampi(randi_range(counts.x, counts.y), 1, weapon.combo.size())
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
	if debug_log:
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
		return ai.windup_speed
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
	var window := _action.move_window
	if not ActionData.in_window(window, _action_time) or _lunge_dir == Vector3.ZERO \
			or distance <= ai.lunge_min_distance:
		_decelerate(delta)
		return
	var factor := 1.0
	if _action.move_fade:
		var progress := clampf((_action_time - window.x) / maxf(window.y - window.x, 0.001), 0.0, 1.0)
		factor = lerpf(1.0, _action.move_end_factor, progress)
	var speed := _action.move_speed * ai.lunge_factor * factor
	velocity.x = _lunge_dir.x * speed
	velocity.z = _lunge_dir.z * speed


func _hit_is_active() -> bool:
	return _action != null and _action.kind == ActionData.Kind.ATTACK and _action.damage > 0.0 \
			and _action.is_hit_active(_action_time)


## Open, sweep, and close the sword's hitbox for the current attack.
func _update_hit() -> void:
	var hitbox := sword_visual.hitbox
	if not _hit_is_active():
		_end_hit()
		return
	if not _hit_was_active:
		hitbox.begin_swing(_action.hitbox_length_scale)
		_hit_was_active = true
	var template := HitData.new()
	template.attacker = self
	template.damage = _action.damage * ai.damage_scale
	template.posture_damage = _action.posture_damage * ai.posture_scale
	template.hitstop = _action.hitstop
	template.guardable = _action.guardable
	template.deflectable = _action.deflectable
	template.knockback = _action.knockback
	template.action = _action
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
	if not _hit_was_active:
		return
	_hit_was_active = false
	sword_visual.hitbox.end_swing()


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
	if _peril_cooldown > 0.0 or distance > ai.perilous_range or randf() >= chance:
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
	_drop_guard()
	_riposte_pending = false
	_reset_guard_streak()
	_peril_kind = kind
	_peril_time = 0.0
	_peril_history.append(kind)
	if _peril_history.size() > 4:
		_peril_history.pop_front()
	_set_phase(Phase.PERILOUS)
	if debug_log:
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
func _countered(posture: float, stun: float, label: String, jump_over: bool) -> void:
	if debug_log:
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
		_symbol = get_tree().get_first_node_in_group(&"danger_symbol") as DangerSymbol
	if _symbol == null:
		if not _symbol_missing_warned:
			_symbol_missing_warned = true
			push_error("Enemy: no DangerSymbol found (add the Label3D with danger_symbol.gd under the Player).")
		return
	_symbol_shown = true
	_symbol.show_danger(self, ai.grab_symbol_color if _peril_kind == Peril.GRAB else Color(1.0, 0.1, 0.1))


func _hide_symbol() -> void:
	if not _symbol_shown:
		return
	_symbol_shown = false
	if _symbol != null and is_instance_valid(_symbol):
		_symbol.hide_danger(self)


# --- Movement helpers ---------------------------------------------------------------------------

func _find_player() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D


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


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= _gravity * delta


func _move_toward_velocity(target: Vector3, delta: float) -> void:
	velocity.x = move_toward(velocity.x, target.x, ai.acceleration * delta)
	velocity.z = move_toward(velocity.z, target.z, ai.acceleration * delta)


func _decelerate(delta: float) -> void:
	_move_toward_velocity(Vector3.ZERO, delta)


func _set_phase(new_phase: Phase) -> void:
	if debug_log and new_phase != phase:
		print("[Enemy] %s -> %s" % [Phase.keys()[phase], Phase.keys()[new_phase]])
	phase = new_phase
	if not _phase_allows_guard(new_phase):
		_drop_guard()


func _return_to_spawn() -> void:
	global_position = _spawn_position
	rotation.y = _spawn_yaw
	velocity = Vector3.ZERO


# --- Combatant signals --------------------------------------------------------------------------

## An unguarded hit landed: the recoil wobble always, a flinch if this moment allows it.
func _on_damaged(hit: HitData, _amount: float) -> void:
	_since_hit = 0.0
	_hit_streak += 1
	_recoil = 1.0
	_recoil_scale = 1.0
	_recoil_direction = hit.direction
	_reset_guard_streak()
	var flinch := _should_flinch()
	if phase == Phase.POSE:
		_end_pose()
	if flinch:
		_start_flinch()


func _on_guarded(hit: HitData, _chip: float) -> void:
	_guard_reaction(hit, false)


func _on_deflected(hit: HitData) -> void:
	_guard_reaction(hit, true)
	if _break_riposte or randf() < ai.riposte_chance:
		_riposte_pending = true
		_riposte_timer = ai.riposte_delay
	_break_riposte = false


## A lighter wobble, the blade flick and flash (as the player's guard), and the guard stays up a bit.
func _guard_reaction(hit: HitData, deflect: bool) -> void:
	_hit_streak = 0
	_count_guarded_hit()
	_guard_hold = maxf(_guard_hold, ai.guard_hold_time)
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
	_abort_attack()
	_drop_guard()
	_riposte_pending = false
	_end_pose()
	_set_phase(Phase.STUNNED)
	body.material_override = _stun_material
	_start_stun_bobble()


## The window closed: back to normal. A landed deathblow also makes it recoil from the player.
func _on_deathblow_closed(executed: bool, _killed: bool) -> void:
	body.material_override = _base_material
	_end_stun_bobble()
	if phase == Phase.STUNNED:
		_start_recover()
	if executed and _player != null:
		var away := global_position - _player.global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			_recoil = 1.0
			_recoil_scale = 1.0
			_recoil_direction = away.normalized()


func _on_died() -> void:
	_abort_attack()
	_drop_guard()
	_riposte_pending = false
	_end_pose()
	_end_stun_bobble()
	body.material_override = _base_material
	visual.visible = false
	bar.visible = false
	body_shape.set_deferred("disabled", true)
	await get_tree().create_timer(respawn_delay).timeout
	_return_to_spawn()
	combatant.reset()
	visual.visible = true
	bar.visible = true
	body_shape.set_deferred("disabled", false)
	_since_hit = 999.0
	_hit_streak = 0
	_flinch_immunity = 0.0
	_break_armed = false
	_break_riposte = false
	_burst_armored = false
	_reset_guard_streak()
	_since_player_attack = 999.0
	_peril_cooldown = 0.0
	_head_bounce_time = 0.0
	_peril_history.clear()
	_think_timer = 0.5
	_set_phase(Phase.IDLE)
