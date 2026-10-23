class_name RestPoint
extends Interactable
## A place to rest (Phase 2 item 18): a shrine, a camp, a clinic, whatever the `kind` says. Using it starts the
## Player's Rest state (a kneel, a fade, then a full refill) and makes this the place the player restarts from.
## Every kind rests the same way; the kind only changes the words (`RestPointKind`) and the scene is the look.
## It cannot be used while a living enemy is in combat with the player, or while the player is dead.

## The kind: its name, the prompt verb and the line after the rest.
@export var kind: RestPointKind
## Replaces the kind's prompt verb for this one rest point (empty: use the kind's).
@export var prompt_override: String = ""
## Names this rest point for the memory (`RestPoints`); empty uses the node's name. Keep it unique in a scene.
@export var rest_id: StringName = &""
## Where the player restarts, relative to this node (in front of it, clear of the base). The y is the player's own.
@export var spawn_offset: Vector3 = Vector3(0.0, 0.0, 1.6)


func _ready() -> void:
	if kind == null:
		push_warning("RestPoint %s has no kind; assign a RestPointKind in the Inspector." % name)


func get_rest_id() -> StringName:
	return rest_id if rest_id != &"" else StringName(name)


func can_interact(player: Player) -> bool:
	return not player.combatant.dead and not _enemy_in_combat()


func get_prompt_text(_player: Player) -> String:
	if prompt_override != "":
		return prompt_override
	return kind.prompt_verb if kind != null else prompt_text


## The line to show when the rest is over.
func get_flavor_line() -> String:
	return kind.flavor_line if kind != null else ""


## Where the player restarts (the given player height, in front of this node).
func get_restart_position(player_y: float) -> Vector3:
	var spot := global_transform * spawn_offset
	spot.y = player_y
	return spot


## The way the player faces on restarting: away from this node.
func get_restart_yaw(restart_position: Vector3) -> float:
	var away := restart_position - global_position
	away.y = 0.0
	if away.length() < 0.01:
		away = global_transform.basis.z
	away = away.normalized()
	return atan2(-away.x, -away.z)


func _on_interact(player: Player) -> void:
	player.begin_rest(self)


func _enemy_in_combat() -> bool:
	for node: Node3D in Enemies.all():
		var enemy := node as Enemy
		if enemy == null or enemy.combatant.dead:
			continue
		if enemy.phase != Enemy.Phase.IDLE:
			return true
	return false
