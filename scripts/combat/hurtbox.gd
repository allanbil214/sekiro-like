class_name Hurtbox
extends Area3D
## The part of a character that takes hits. Add it as an Area3D with a CollisionShape3D child.
## It sets its own layer from the team, and passes each hit to its Combatant (found among its
## siblings if not assigned).

signal hit_received(hit: HitData)

@export var team: Layers.Team = Layers.Team.ENEMY
@export var combatant: Combatant

## Optional extra gate, e.g. i-frames: a Callable that returns true while untouchable.
var is_invulnerable: Callable = Callable()


func _ready() -> void:
	collision_layer = Layers.hurtbox_layer(team)
	collision_mask = 0
	monitoring = false
	monitorable = true
	if combatant == null:
		combatant = _find_combatant()


func can_be_hit() -> bool:
	if combatant != null and combatant.dead:
		return false
	if is_invulnerable.is_valid() and bool(is_invulnerable.call()):
		return false
	return true


func receive_hit(hit: HitData) -> void:
	hit_received.emit(hit)
	if combatant != null:
		combatant.take_hit(hit)


func _find_combatant() -> Combatant:
	var parent := get_parent()
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if child is Combatant:
			return child as Combatant
	return null
