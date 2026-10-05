class_name DebugOverlay
extends CanvasLayer
## Debug info: current state, i-frames, action clock. Must be a direct child of Player.

## Tint the body while the player is invulnerable.
@export var tint_on_iframes: bool = true
@export var tint_color: Color = Color(0.3, 0.7, 1.0)

var _player: Player
var _label: Label
var _body: MeshInstance3D
var _tint_material: StandardMaterial3D


func _ready() -> void:
	_player = get_parent() as Player
	_body = _player.get_node_or_null("Visual/Body") as MeshInstance3D
	_label = Label.new()
	_label.position = Vector2(16, 16)
	add_child(_label)
	_tint_material = StandardMaterial3D.new()
	_tint_material.albedo_color = tint_color


func _process(_delta: float) -> void:
	var machine := _player.state_machine
	var text := "State: %s\nInvulnerable: %s" % [machine.get_current_name(), _player.invulnerable]
	var action_state := machine.current as ActionState
	if action_state != null:
		text += "\nAction time: %.2f / %.2f" % [action_state.action_time, action_state.action.duration]
	_label.text = text
	if _body != null:
		if tint_on_iframes and _player.invulnerable:
			_body.material_override = _tint_material
		else:
			_body.material_override = null
