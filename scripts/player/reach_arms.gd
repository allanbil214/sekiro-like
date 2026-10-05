class_name ReachArms
extends Node3D
## Debug stand-in for the mid-air reach animation: two arms snap up and forward, hold
## briefly, then drop. Builds its own boxes. Place under Visual so it turns with the body.

@export var shoulder_height: float = 1.4
@export var shoulder_offset: float = 0.45
@export var arm_length: float = 0.5
@export var raise_time: float = 0.08
@export var hold_time: float = 0.15
@export var lower_time: float = 0.12
@export var raised_angle_deg: float = 140.0
@export var color: Color = Color(1.0, 0.6, 0.15)

var _pivots: Array[Node3D] = []
var _tween: Tween


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * shoulder_offset, shoulder_height, 0.0)
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.1, arm_length, 0.1)
		box.mesh = mesh
		box.material_override = material
		box.position = Vector3(0.0, -arm_length * 0.5, 0.0)
		pivot.add_child(box)
		add_child(pivot)
		_pivots.append(pivot)
	visible = false


func play() -> void:
	if _tween != null:
		_tween.kill()
	visible = true
	_tween = create_tween()
	_tween.tween_method(_set_pose, 0.0, 1.0, raise_time)
	_tween.tween_interval(hold_time)
	_tween.tween_method(_set_pose, 1.0, 0.0, lower_time)
	_tween.tween_callback(func() -> void: visible = false)


func _set_pose(amount: float) -> void:
	for pivot in _pivots:
		pivot.rotation.x = deg_to_rad(raised_angle_deg) * amount
