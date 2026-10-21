class_name Chest
extends Interactable
## A chest (Phase 2 item 8). Opens once: the `Lid` (a Node3D at the hinge) tips back and a line says it is
## empty (the contents come with the item system in Phase 4). Opening makes a small noise.

@export var open_angle_degrees: float = -100.0
@export var open_time: float = 0.4
@export var open_noise: float = 3.0
@export var empty_line: String = "It is empty."
## Carrying a body (Phase 2 item 15a): the chest is kicked open: the prompt changes and the lid goes after this
## many seconds (a placeholder for a kick animation).
@export var kick_text: String = "Kick open"
@export var kick_delay: float = 0.4
@onready var _lid: Node3D = $Lid

var is_open: bool = false


func _ready() -> void:
	if prompt_text == "Use":
		prompt_text = "Open"
	usable_while_carrying = true


func can_interact(_player: Player) -> bool:
	return not is_open


func get_prompt_text(player: Player) -> String:
	return kick_text if player.is_carrying() else prompt_text


func _on_interact(player: Player) -> void:
	is_open = true
	if player.is_carrying():
		await get_tree().create_timer(kick_delay).timeout
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_OK)
	player.make_noise(open_noise)
	var tween := create_tween()
	tween.tween_property(_lid, "rotation:x", deg_to_rad(open_angle_degrees), open_time)
	player.show_interact_line(empty_line)
