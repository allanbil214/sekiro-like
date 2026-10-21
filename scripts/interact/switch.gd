class_name Switch
extends Interactable
## A lever (Phase 2 item 8): each press toggles `flag` in `GameFlags` (a door with that `locked_by_flag`
## unlocks while it is set). The `Handle` (a Node3D at the pivot) tilts to show the state.

@export var flag: StringName = &"switch_1"
@export var handle_angle_degrees: float = 45.0
@export var move_time: float = 0.2
@onready var _handle: Node3D = $Handle


func _ready() -> void:
	if prompt_text == "Use":
		prompt_text = "Pull"
	usable_while_carrying = true
	_handle.rotation.z = deg_to_rad(handle_angle_degrees if GameFlags.has_flag(flag) else -handle_angle_degrees)


func _on_interact(_player: Player) -> void:
	var on := GameFlags.toggle_flag(flag)
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_OK)
	var tween := create_tween()
	tween.tween_property(_handle, "rotation:z", deg_to_rad(handle_angle_degrees if on else -handle_angle_degrees), move_time)
