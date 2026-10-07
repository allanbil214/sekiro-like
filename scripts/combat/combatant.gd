class_name Combatant
extends Node
## Health for anything that can be hurt (the dummy now; the player and the enemy later share this
## component, so the rules match). Posture, guard, and health bars come in later steps.

signal damaged(hit: HitData, amount: float)
signal health_changed(current: float, maximum: float)
signal died

@export var max_health: float = 100.0

var health: float = 0.0
var dead: bool = false


func _ready() -> void:
	health = max_health


## Apply a hit. Returns the damage actually taken (never more than the health left).
func take_hit(hit: HitData) -> float:
	if dead:
		return 0.0
	var amount := minf(hit.damage, health)
	health -= amount
	damaged.emit(hit, amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		dead = true
		died.emit()
	return amount


## Back to full health and alive.
func reset() -> void:
	health = max_health
	dead = false
	health_changed.emit(health, max_health)
