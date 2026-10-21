class_name Interactable
extends Node3D
## Something in the world the player can use with `interact` (Phase 2 item 8). This base only says what
## it is: the prompt text, a priority, and whether it can be used right now. What happens after the press
## is `_on_interact()`, overridden by each behavior (door, chest, switch, NPC), so the picker never changes
## when a new behavior is added. The node's origin is the point the picker measures from.

## Emitted after a successful interaction.
signal interacted(player: Player)

## The verb shown on the prompt ("Open"). Behaviors may change it with `get_prompt_text()`.
@export var prompt_text: String = "Use"
## A higher priority wins over a nearer one when several are in reach.
@export var priority: int = 0
## True lets the player use it while carrying a body (a door, a switch, a chest by kicking; Phase 2 item 15a).
## Off by default: an NPC, say, cannot be used with a body in the arms.
@export var usable_while_carrying: bool = false
## False: the picker does not need the player to face it (a big volume like a bush; Phase 2 item 15b).
@export var needs_facing: bool = true

static var _all: Array[Interactable] = []


## Every interactable in the scene (read-only), like `Enemies.all()`.
static func all() -> Array[Interactable]:
	return _all


func _enter_tree() -> void:
	_all.append(self)


func _exit_tree() -> void:
	_all.erase(self)


## False hides the prompt and ignores the press.
func can_interact(_player: Player) -> bool:
	return true


## The text after the key name on the prompt.
func get_prompt_text(_player: Player) -> String:
	return prompt_text


## The point the picker measures the distance and the facing from (the node's origin unless overridden).
func reach_point(_player: Player) -> Vector3:
	return global_position


## Called by the player on a press. Behaviors override `_on_interact`.
func interact(player: Player) -> void:
	_on_interact(player)
	interacted.emit(player)


func _on_interact(_player: Player) -> void:
	pass
