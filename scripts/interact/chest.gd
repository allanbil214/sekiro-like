class_name Chest
extends Interactable
## A chest (Phase 2 item 8). Opens once: the `Lid` (a Node3D at the hinge) tips back and a line says it is
## empty (the contents come with the item system in Phase 3). Opening makes a small noise.

@export var open_angle_degrees: float = -100.0
@export var open_time: float = 0.4
@export var open_noise: float = 3.0
@export var empty_line: String = "It is empty."
@onready var _lid: Node3D = $Lid

var is_open: bool = false


func _ready() -> void:
	if prompt_text == "Use":
		prompt_text = "Open"


func can_interact(_player: Player) -> bool:
	return not is_open


func _on_interact(player: Player) -> void:
	is_open = true
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_OK)
	player.make_noise(open_noise)
	var tween := create_tween()
	tween.tween_property(_lid, "rotation:x", deg_to_rad(open_angle_degrees), open_time)
	player.show_interact_line(empty_line)
