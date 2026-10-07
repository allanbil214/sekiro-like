class_name Dummy
extends StaticBody3D
## A target dummy: it takes hits (Hurtbox), loses health (Combatant), shows a floating bar
## (EnemyBar), and wobbles away from the hit. At 0 health it vanishes and comes back after
## respawn_delay. It does not fight back yet (Step 4b and later).

@export var respawn_delay: float = 2.0
## How far (m) the body shifts away from a hit, and how far (radians) it tilts.
@export var recoil_distance: float = 0.12
@export var recoil_tilt: float = 0.15
@export var recoil_time: float = 0.2

@onready var combatant: Combatant = $Combatant
@onready var visual: Node3D = $Visual
@onready var bar: EnemyBar = $Bar

var _recoil: float = 0.0
var _recoil_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	bar.bind(combatant)
	combatant.damaged.connect(_on_damaged)
	combatant.died.connect(_on_died)


func _process(delta: float) -> void:
	if _recoil <= 0.0:
		return
	_recoil = maxf(0.0, _recoil - delta / maxf(recoil_time, 0.001))
	var k := ease(_recoil, 2.0)
	visual.position = _recoil_direction * recoil_distance * k
	var axis := Vector3.UP.cross(_recoil_direction)
	if axis.length_squared() > 0.0001:
		visual.basis = Basis(axis.normalized(), recoil_tilt * k)


func _on_damaged(hit: HitData, _amount: float) -> void:
	_recoil = 1.0
	_recoil_direction = hit.direction


func _on_died() -> void:
	visual.visible = false
	bar.visible = false
	await get_tree().create_timer(respawn_delay).timeout
	combatant.reset()
	visual.visible = true
	bar.visible = true
