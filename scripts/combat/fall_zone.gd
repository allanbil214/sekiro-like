class_name FallZone
extends Area3D
## A volume placed under the playable area of an arena (Phase 2, item 3a). When the Player is inside it
## (it fell out of the world), the Player is put back at its starting spot: a fade to black, a share of
## its max health lost (never lethal, it always leaves 1 HP), and a moment of invulnerability. See
## Player.begin_fall_respawn(). Enemies are ignored (Enemy has its own "below -30 m" check).
## The player is checked every physics frame instead of by a one-time signal, so a fall that happens
## during a deathblow or while dead still triggers once that ends and the player is still inside.
## Needs a CollisionShape3D child (a big flat BoxShape3D). Keep its collision mask on layer 1.

## Share of the player's max health lost on a fall (0.25 = 25 percent). The result is never below 1 HP.
@export_range(0.0, 1.0) var damage_fraction: float = 0.25


func _ready() -> void:
	# It only looks for bodies; nothing needs to detect the zone itself.
	collision_layer = 0
	monitorable = false


func _physics_process(_delta: float) -> void:
	for body: Node3D in get_overlapping_bodies():
		var player := body as Player
		if player != null:
			player.begin_fall_respawn(damage_fraction)
