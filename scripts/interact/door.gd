class_name Door
extends Interactable
## A door (Phase 2 item 8). The root is the door's center. A `Pivot` child (a Node3D at the hinge) holds
## the leaf (a CSGBox3D with collision) and swings open; once open the leaf's collision is switched off so
## the way is clear. Locked while `locked_by_flag` is set and `GameFlags` does not have that flag; a locked
## door shows "Locked" on the prompt and the press does nothing. Opening makes a small noise.

## Empty = never locked. Otherwise the door stays locked until this flag is set (a switch sets it).
@export var locked_by_flag: StringName = &""
## How far (degrees) the leaf swings, and how long it takes (s).
@export var open_angle_degrees: float = 100.0
@export var open_time: float = 0.5
## Noise radius (m) of opening it.
@export var open_noise: float = 3.0
@export var locked_text: String = "Locked"
## The hinge and the leaf's collision, found in the scene (an error if missing).
@onready var _pivot: Node3D = $Pivot
@onready var _leaf: CSGBox3D = $Pivot/Leaf

var is_open: bool = false


func _ready() -> void:
	if prompt_text == "Use":
		prompt_text = "Open"


func is_locked() -> bool:
	return locked_by_flag != &"" and not GameFlags.has_flag(locked_by_flag)


func can_interact(_player: Player) -> bool:
	return not is_open


func get_prompt_text(_player: Player) -> String:
	return locked_text if is_locked() else prompt_text


func _on_interact(player: Player) -> void:
	if is_open or is_locked():
		return
	is_open = true
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_OK)
	player.make_noise(open_noise)
	var tween := create_tween()
	tween.tween_property(_pivot, "rotation:y", deg_to_rad(open_angle_degrees), open_time)
	# Let the leaf stop blocking once it has swung away.
	tween.tween_callback(func() -> void: _leaf.use_collision = false)
