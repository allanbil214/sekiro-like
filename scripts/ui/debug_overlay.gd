class_name DebugOverlay
extends CanvasLayer
## Debug info: current state, i-frames, action clock. Must be a direct child of Player.

## Tint the body while the player is invulnerable.
@export var tint_on_iframes: bool = true
@export var tint_color: Color = Color(0.3, 0.7, 1.0)
## Show a ring at chest height marking how far a wall counts as "in range" for wall jumps.
@export var show_wall_range: bool = true
## Show a marker at the ledge edge found by the last ledge check.
@export var show_ledge_marker: bool = true

var _player: Player
var _label: Label
var _body: MeshInstance3D
var _tint_material: StandardMaterial3D
var _ledge_marker: MeshInstance3D


func _ready() -> void:
	_player = get_parent() as Player
	_body = _player.get_node_or_null("Visual/Body") as MeshInstance3D
	_label = Label.new()
	_label.position = Vector2(16, 16)
	add_child(_label)
	_tint_material = StandardMaterial3D.new()
	_tint_material.albedo_color = tint_color
	if show_wall_range:
		_create_wall_range_ring.call_deferred()
	if show_ledge_marker:
		_create_ledge_marker.call_deferred()


func _process(_delta: float) -> void:
	var machine := _player.state_machine
	var text := "State: %s\nInvulnerable: %s" % [machine.get_current_name(), _player.invulnerable]
	text += "\nReach: %s\nWall jumps: %d/%d\nvel.y: %.2f" % [
		"ready" if _player.reach_ready else "used",
		_player.wall_jumps_used, _player.max_wall_jumps, _player.velocity.y,
	]
	var ledge_recent := Time.get_ticks_msec() - _player.last_ledge_ms < 600
	text += "\nLedge: %s" % ("found" if ledge_recent else "-")
	if _ledge_marker != null:
		_ledge_marker.visible = ledge_recent
		_ledge_marker.global_position = _player.last_ledge_point
	var action_state := machine.current as ActionState
	if action_state != null:
		text += "\nAction time: %.2f / %.2f" % [action_state.action_time, action_state.action.duration]
	var attack_state := machine.current as AttackState
	if attack_state != null:
		text += "\n" + attack_state.get_debug_text()
	var air_attack_state := machine.current as AirAttackState
	if air_attack_state != null:
		text += "\n" + air_attack_state.get_debug_text()
	_label.text = text
	if _body != null:
		if tint_on_iframes and _player.invulnerable:
			_body.material_override = _tint_material
		else:
			_body.material_override = null


func _create_wall_range_ring() -> void:
	var shape := _player.get_node("CollisionShape3D").shape as CapsuleShape3D
	var radius := shape.radius + _player.wall_range
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.8, 0.2, 0.25)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ring := MeshInstance3D.new()
	ring.name = "WallRangeRing"
	ring.mesh = mesh
	ring.material_override = material
	ring.position = Vector3(0.0, _player.stand_height * 0.5, 0.0)
	_player.add_child(ring)


func _create_ledge_marker() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.2, 0.8)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ledge_marker = MeshInstance3D.new()
	_ledge_marker.name = "LedgeMarker"
	_ledge_marker.mesh = mesh
	_ledge_marker.material_override = material
	_ledge_marker.top_level = true
	_ledge_marker.visible = false
	_player.add_child(_ledge_marker)
