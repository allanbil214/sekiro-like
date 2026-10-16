class_name NpcLine
extends Interactable
## The placeholder NPC (Phase 2 item 8): each press shows the next line of `lines` as a short text near the
## bottom of the screen (no freeze and no dialogue box, those are Phase 3). A crowd NPC later picks its line
## by reputation; for now the lines are a plain list.

@export var lines: Array[String] = ["Hello there.", "Mind the guards on the upper floor."]


func _ready() -> void:
	if prompt_text == "Use":
		prompt_text = "Talk"


var _next: int = 0


func _on_interact(player: Player) -> void:
	if lines.is_empty():
		return
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_OK)
	player.show_interact_line(lines[_next % lines.size()])
	_next += 1
