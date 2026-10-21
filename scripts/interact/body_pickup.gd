class_name BodyPickup
extends Interactable
## Picks up an unconscious or dead enemy so the player can carry it (Phase 2 item 15a). A child of the
## Enemy root (add a `Node3D` named `BodyPickup` with this script under it in `enemy.tscn`). Before the
## pick-up it shows "Pick up" for a body no guard is carrying; while the player carries this body it shows
## "Put down" at the lowest priority, so a door, switch or chest in reach wins the press. Nothing else
## can be picked up while carrying.

@export var put_down_text: String = "Put down"
## The priority while the body is carried (below every other interactable's).
@export var carried_priority: int = -100

var _enemy: Enemy
var _pick_priority: int = 0


func _ready() -> void:
	_enemy = get_parent() as Enemy
	if _enemy == null:
		push_error("BodyPickup: it must be a child of an Enemy (Phase 2 item 15a).")
	if prompt_text == "Use":
		prompt_text = "Pick up"
	_pick_priority = priority
	usable_while_carrying = true


func can_interact(player: Player) -> bool:
	if _enemy == null:
		return false
	# The picker reads `priority` right after this call, so it is kept up to date here.
	priority = carried_priority if _enemy.is_carried() else _pick_priority
	if _enemy.is_carried():
		return player.carried_body == _enemy
	if player.is_carrying() or _enemy.held_by_guard:
		return false
	return _enemy.is_corpse() or _enemy.is_unconscious()


func get_prompt_text(player: Player) -> String:
	if _enemy != null and player.carried_body == _enemy:
		return put_down_text
	return prompt_text


func _on_interact(player: Player) -> void:
	if _enemy == null:
		return
	if player.carried_body == _enemy:
		player.try_put_down_body()
	else:
		player.pick_up_body(_enemy)
