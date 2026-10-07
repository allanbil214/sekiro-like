class_name Enemy
extends CharacterBody3D
## The first real enemy (Step 7a). It chases the player, circles at a distance, and attacks in
## bursts with the player's own ground combo (the weapon's attack_1 to attack_5 ActionData and the
## same arm-swing SwordVisual, so its wind-up is the telegraph). Damage and posture damage are
## scaled by EnemyAIData. Guard, deflect, riposte, and the perilous attacks come in 7b and 7c.
##
## Loop: IDLE (nobody near) > CHASE (run in, then start a burst) > ATTACK (2 to 4 combo hits, each
## chained at the earliest cancel point) > RECOVER (stands still: the player's opening) > YIELD
## (circles at a distance for a while) > CHASE again.
##
## It uses the same Combatant rules as the player and the dummy (HP, 2 bars, posture, deathblow):
## an empty bar or a posture break stuns it (pale, frozen) until the deathblow window closes. A hit
## only plays a visual recoil (the Visual shifts and tilts); it never interrupts the enemy.
## Needs the nodes listed in the Step 7a instructions (a missing one is an error on purpose).

enum Phase { IDLE, CHASE, ATTACK, RECOVER, YIELD, STUNNED }

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
@export_group("Debug")
## Print phase changes and attacks to the Output panel.
@export var debug_log: bool = false

@onready var combatant: Combatant = $Combatant
@onready var visual: Node3D = $Visual
@onready var body: MeshInstance3D = $Visual/Body
@onready var sword_visual: SwordVisual = $Visual/SwordVisual
@onready var bar: EnemyBar = $Bar
@onready var body_shape: CollisionShape3D = $CollisionShape3D

var phase: Phase = Phase.IDLE

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
var _recoil_direction: Vector3 = Vector3.ZERO
var _base_material: StandardMaterial3D
var _stun_material: StandardMaterial3D
var _spawn_position: Vector3 = Vector3.ZERO
var _spawn_yaw: float = 0.0


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
	combatant.reset()
	_base_material = StandardMaterial3D.new()
	_base_material.albedo_color = body_color
	body.material_override = _base_material
	_stun_material = StandardMaterial3D.new()
	_stun_material.albedo_color = Color(0.95, 0.95, 0.85)
	_stun_material.emission_enabled = true
	_stun_material.emission = Color(0.9, 0.9, 0.7)
	_stun_material.emission_energy_multiplier = 0.6
	bar.bind(combatant)
	combatant.damaged.connect(_on_damaged)
	combatant.died.connect(_on_died)
	combatant.deathblow_opened.connect(_on_deathblow_opened)
	combatant.deathblow_closed.connect(_on_deathblow_closed)
	sword_visual.hitbox.team = Layers.Team.ENEMY
	sword_visual.setup(weapon)
	_think_timer = 0.5


func _physics_process(delta: float) -> void:
	if combatant.dead:
		return
	if global_position.y < -30.0:
		_return_to_spawn()
	combatant.tick_posture(delta, phase == Phase.ATTACK)
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
	move_and_slide()


func _process(delta: float) -> void:
	if _recoil <= 0.0:
		return
	_recoil = maxf(0.0, _recoil - delta / maxf(recoil_time, 0.001))
	var k := ease(_recoil, 2.0)
	var local_dir := global_transform.basis.inverse() * _recoil_direction
	local_dir.y = 0.0
	visual.position = local_dir * recoil_distance * k
	var axis := Vector3.UP.cross(local_dir)
	if axis.length_squared() > 0.0001:
		visual.basis = Basis(axis.normalized(), recoil_tilt * k)


# --- Phases -----------------------------------------------------------------------------------

func _update_chase(delta: float, to_player: Vector3, distance: float, has_target: bool) -> void:
	if not has_target or distance > ai.aggro_range * 1.5:
		_set_phase(Phase.IDLE)
		return
	_face(to_player, delta, ai.turn_speed)
	if distance > ai.engage_distance:
		_move_toward_velocity(to_player.normalized() * ai.run_speed, delta)
		return
	_decelerate(delta)
	if _think_timer <= 0.0:
		_start_burst()


func _update_yield(delta: float, to_player: Vector3, distance: float, has_target: bool) -> void:
	if not has_target:
		_set_phase(Phase.IDLE)
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


# --- Attacks (the weapon's ground combo) --------------------------------------------------------

func _start_burst() -> void:
	_burst_total = clampi(randi_range(ai.attack_burst_count.x, ai.attack_burst_count.y),
			1, weapon.combo.size())
	_set_phase(Phase.ATTACK)
	_begin_attack(0)


func _begin_attack(index: int) -> void:
	_end_hit()
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
	_action_time += delta
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
	var next := _combo_index + 1
	if next < _burst_total and _action_time >= _chain_time() + _chain_wait:
		_begin_attack(next)
		return
	if _action_time >= _action.duration:
		_end_burst()


## Earliest time the next attack may start: where the cancel window opens (as for the player).
func _chain_time() -> float:
	if _action.cancel_window == Vector2.ZERO:
		return _action.locked_until
	return _action.cancel_window.x


func _end_burst() -> void:
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
	hitbox.sweep(template)


func _end_hit() -> void:
	if not _hit_was_active:
		return
	_hit_was_active = false
	sword_visual.hitbox.end_swing()


## Drop whatever attack is running (stun, death).
func _abort_attack() -> void:
	_end_hit()
	if phase == Phase.ATTACK:
		sword_visual.end_combo()


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


func _return_to_spawn() -> void:
	global_position = _spawn_position
	rotation.y = _spawn_yaw
	velocity = Vector3.ZERO


# --- Combatant signals --------------------------------------------------------------------------

## Any hit: only the visual recoil (the enemy keeps doing what it was doing).
func _on_damaged(hit: HitData, _amount: float) -> void:
	_recoil = 1.0
	_recoil_direction = hit.direction


## Stunned (empty bar or posture break): drop any swing and turn pale.
func _on_deathblow_opened() -> void:
	_abort_attack()
	_set_phase(Phase.STUNNED)
	body.material_override = _stun_material


## The window closed: back to normal. A landed deathblow also makes it recoil from the player.
func _on_deathblow_closed(executed: bool, _killed: bool) -> void:
	body.material_override = _base_material
	if phase == Phase.STUNNED:
		_start_recover()
	if executed and _player != null:
		var away := global_position - _player.global_position
		away.y = 0.0
		if away.length_squared() > 0.0001:
			_recoil = 1.0
			_recoil_direction = away.normalized()


func _on_died() -> void:
	_abort_attack()
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
	_think_timer = 0.5
	_set_phase(Phase.IDLE)
