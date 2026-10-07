class_name Dummy
extends StaticBody3D
## A target dummy: it takes hits (Hurtbox), loses health (Combatant), shows a floating bar
## (EnemyBar), and wobbles away from the hit. At 0 health it vanishes and comes back after
## respawn_delay.
##
## Step 4b: it also swings an arm at the player, so the hurtbox postures can be tested. While the
## player is within attack_range it turns toward them and swings at a high, low, or mid height
## (the cycle order is high, low, mid): wind-up (the red arm is the telegraph), a 120 degree arc
## (the Hitbox is swept like the player's), recovery, a pause. High passes over a crouching
## player, low passes under a jumping one, mid hits everything. A stand-in until the real
## enemy (Step 7).

enum AttackMode { OFF, CYCLE, HIGH, MID, LOW }
enum Phase { IDLE, WINDUP, ACTIVE, RECOVER }

## The arm starts this far (m) from the dummy's center, so it does not begin inside the body.
const SWING_START: float = 0.3

@export var respawn_delay: float = 2.0
## How far (m) the body shifts away from a hit, and how far (radians) it tilts.
@export var recoil_distance: float = 0.12
@export var recoil_tilt: float = 0.15
@export var recoil_time: float = 0.2

@export_group("Attack")
@export var attack_mode: AttackMode = AttackMode.CYCLE
## The player must be this close (m, center to center) for it to start a swing.
@export var attack_range: float = 2.6
## How far the arm reaches from the dummy's center (m).
@export var swing_reach: float = 2.0
@export var swing_arc_degrees: float = 120.0
@export var windup_time: float = 0.6
@export var active_time: float = 0.25
@export var recover_time: float = 0.7
## Pause between swings while the player stays in range.
@export var pause_time: float = 1.2
@export var attack_damage: float = 20.0
@export var attack_hitstop: float = 0.08
## Height (m above the feet) of the arm for each swing.
@export var high_height: float = 1.5
@export var mid_height: float = 0.9
@export var low_height: float = 0.15
@export var turn_speed: float = 6.0

@onready var combatant: Combatant = $Combatant
@onready var visual: Node3D = $Visual
@onready var bar: EnemyBar = $Bar
@onready var swing_pivot: Node3D = $SwingPivot
@onready var hitbox: Hitbox = $SwingPivot/Hitbox
@onready var arm: MeshInstance3D = $SwingPivot/Arm

var _recoil: float = 0.0
var _recoil_direction: Vector3 = Vector3.ZERO
var _phase: Phase = Phase.IDLE
var _timer: float = 0.0
var _swing_time: float = 0.0
var _cycle_index: int = 0
var _player: Node3D


func _ready() -> void:
	bar.bind(combatant)
	combatant.damaged.connect(_on_damaged)
	combatant.died.connect(_on_died)
	var length := maxf(swing_reach - SWING_START, 0.1)
	hitbox.configure(length)
	hitbox.position = Vector3(0.0, 0.0, -SWING_START)
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.14, 0.14, length)
	arm.mesh = arm_mesh
	var arm_material := StandardMaterial3D.new()
	arm_material.albedo_color = Color(0.9, 0.1, 0.1)
	arm_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arm.material_override = arm_material
	arm.position = Vector3(0.0, 0.0, -(SWING_START + length * 0.5))
	arm.visible = false
	_timer = pause_time


func _physics_process(delta: float) -> void:
	if combatant.dead:
		_end_attack()
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player == null:
		return
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	match _phase:
		Phase.IDLE:
			_face(to_player, delta)
			_timer -= delta
			if _timer <= 0.0 and attack_mode != AttackMode.OFF \
					and to_player.length() <= attack_range:
				_start_windup()
		Phase.WINDUP:
			_timer -= delta
			if _timer <= 0.0:
				_start_active()
		Phase.ACTIVE:
			_swing_time += delta
			var t := clampf(_swing_time / maxf(active_time, 0.001), 0.0, 1.0)
			swing_pivot.rotation_degrees.y = lerpf(swing_arc_degrees * 0.5, -swing_arc_degrees * 0.5, t)
			var template := HitData.new()
			template.attacker = self
			template.damage = attack_damage
			template.hitstop = attack_hitstop
			hitbox.sweep(template)
			if _swing_time >= active_time:
				hitbox.end_swing()
				arm.visible = false
				_phase = Phase.RECOVER
				_timer = recover_time
		Phase.RECOVER:
			_timer -= delta
			if _timer <= 0.0:
				_phase = Phase.IDLE
				_timer = pause_time


func _process(delta: float) -> void:
	if _recoil <= 0.0:
		return
	_recoil = maxf(0.0, _recoil - delta / maxf(recoil_time, 0.001))
	var k := ease(_recoil, 2.0)
	visual.position = _recoil_direction * recoil_distance * k
	var axis := Vector3.UP.cross(_recoil_direction)
	if axis.length_squared() > 0.0001:
		visual.basis = Basis(axis.normalized(), recoil_tilt * k)


func _start_windup() -> void:
	swing_pivot.position.y = _next_height()
	swing_pivot.rotation_degrees.y = swing_arc_degrees * 0.5
	arm.visible = true
	_phase = Phase.WINDUP
	_timer = windup_time


func _start_active() -> void:
	_phase = Phase.ACTIVE
	_swing_time = 0.0
	hitbox.begin_swing(1.0)


func _end_attack() -> void:
	if _phase == Phase.ACTIVE:
		hitbox.end_swing()
	arm.visible = false
	_phase = Phase.IDLE
	_timer = pause_time


func _face(to_player: Vector3, delta: float) -> void:
	if to_player.length_squared() < 0.0001:
		return
	var yaw := atan2(-to_player.x, -to_player.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-turn_speed * delta))


## High, low, mid in turn (CYCLE), or the one chosen.
func _next_height() -> float:
	match attack_mode:
		AttackMode.HIGH:
			return high_height
		AttackMode.MID:
			return mid_height
		AttackMode.LOW:
			return low_height
	var heights: Array[float] = [high_height, low_height, mid_height]
	var height := heights[_cycle_index % heights.size()]
	_cycle_index += 1
	return height


func _on_damaged(hit: HitData, _amount: float) -> void:
	_recoil = 1.0
	_recoil_direction = hit.direction


func _on_died() -> void:
	visual.visible = false
	bar.visible = false
	_end_attack()
	await get_tree().create_timer(respawn_delay).timeout
	combatant.reset()
	visual.visible = true
	bar.visible = true
