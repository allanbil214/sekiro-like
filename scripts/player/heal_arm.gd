class_name HealArm
extends Node3D
## Placeholder left arm for the heal (Step 11): it lifts a small gourd to the mouth, tips it back while
## you drink, and lowers it. Place it under Visual (so it turns with the body). HealState calls begin(),
## then set_progress(elapsed / duration) every frame, then end() when the state is left; the pose
## follows that progress, so changing the heal's duration changes the animation with it. A hit or a
## cancel (end() before the progress reached 1) drops the arm over drop_time from wherever it is.
## The arm is two boxes (upper arm and forearm) placed by a two-bone solve, so only the hand's rest and
## drink positions (in Visual space, the player faces -Z, left is -X) need tuning.

@export_group("Arm")
## The left shoulder is at x = -shoulder_offset.
@export var shoulder_height: float = 1.4
@export var shoulder_offset: float = 0.45
@export var upper_length: float = 0.32
@export var fore_length: float = 0.32
@export var arm_thickness: float = 0.1
@export var arm_color: Color = Color(1.0, 0.6, 0.15)
## Where the hand hangs before and after, and where it is while drinking (Visual space).
@export var rest_hand: Vector3 = Vector3(-0.5, 0.85, -0.12)
@export var drink_hand: Vector3 = Vector3(-0.12, 1.42, -0.42)
## The elbow bends toward this direction (outward and down).
@export var elbow_pole: Vector3 = Vector3(-0.6, -1.0, 0.3)

@export_group("Gourd")
@export var gourd_length: float = 0.2
@export var gourd_radius: float = 0.055
@export var gourd_color: Color = Color(0.45, 0.28, 0.12)
## How far the gourd tips back (its top toward the face) while drinking.
@export_range(0.0, 120.0) var gourd_tilt_degrees: float = 65.0

@export_group("Timing (shares of the heal, 0 to 1)")
## The raise ends here; the lowering starts at lower_start; the tilt eases in over tilt_in after the raise.
@export_range(0.0, 1.0) var raise_end: float = 0.3
@export_range(0.0, 1.0) var lower_start: float = 0.85
@export_range(0.01, 1.0) var tilt_in: float = 0.12
## Seconds to drop the arm when the heal ends or is cut.
@export var drop_time: float = 0.12

var _upper: Node3D
var _fore: Node3D
var _gourd: Node3D
var _reach: float = 0.0
var _tilt: float = 0.0
var _driven: bool = false


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = arm_color
	_upper = _make_segment(upper_length, material)
	_fore = _make_segment(fore_length, material)
	var gourd_material := StandardMaterial3D.new()
	gourd_material.albedo_color = gourd_color
	_gourd = Node3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = gourd_radius
	mesh.height = gourd_length
	var gourd_mesh := MeshInstance3D.new()
	gourd_mesh.mesh = mesh
	gourd_mesh.material_override = gourd_material
	gourd_mesh.position = Vector3(0.0, gourd_length * 0.35, 0.0)
	_gourd.add_child(gourd_mesh)
	add_child(_gourd)
	visible = false


func _make_segment(length: float, material: Material) -> Node3D:
	var segment := Node3D.new()
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(arm_thickness, length, arm_thickness)
	box.mesh = mesh
	box.material_override = material
	box.position = Vector3(0.0, -length * 0.5, 0.0)
	segment.add_child(box)
	add_child(segment)
	return segment


## The heal started: show the arm at rest.
func begin() -> void:
	_driven = true
	_reach = 0.0
	_tilt = 0.0
	visible = true
	_apply()


## `progress` is the heal's elapsed share (0 to 1).
func set_progress(progress: float) -> void:
	if not _driven:
		return
	var p := clampf(progress, 0.0, 1.0)
	if p < raise_end:
		_reach = smoothstep(0.0, 1.0, p / maxf(raise_end, 0.001))
	elif p < lower_start:
		_reach = 1.0
	else:
		_reach = 1.0 - smoothstep(0.0, 1.0, (p - lower_start) / maxf(1.0 - lower_start, 0.001))
	if p < lower_start:
		_tilt = smoothstep(0.0, 1.0, (p - raise_end) / tilt_in)
	else:
		_tilt = 1.0 - smoothstep(0.0, 1.0, (p - lower_start) / maxf((1.0 - lower_start) * 0.5, 0.001))
	_apply()


## The heal ended (done, hit, or cancelled): drop the arm from the current pose, then hide it.
func end() -> void:
	_driven = false


func _process(delta: float) -> void:
	if _driven or not visible:
		return
	var step := delta / maxf(drop_time, 0.01)
	_reach = move_toward(_reach, 0.0, step)
	_tilt = move_toward(_tilt, 0.0, step * 1.5)
	_apply()
	if _reach <= 0.0 and _tilt <= 0.0:
		visible = false


func _apply() -> void:
	var shoulder := Vector3(-shoulder_offset, shoulder_height, 0.0)
	var target := rest_hand.lerp(drink_hand, _reach)
	var to := target - shoulder
	var reach_max := upper_length + fore_length - 0.001
	var reach_min := absf(upper_length - fore_length) + 0.001
	var dist := clampf(to.length(), reach_min, reach_max)
	var dir := to.normalized()
	var along := (upper_length * upper_length - fore_length * fore_length + dist * dist) / (2.0 * dist)
	var height := sqrt(maxf(upper_length * upper_length - along * along, 0.0))
	var pole := elbow_pole - dir * elbow_pole.dot(dir)
	pole = pole.normalized() if pole.length() > 0.0001 else Vector3.DOWN
	var elbow := shoulder + dir * along + pole * height
	var hand := shoulder + dir * dist
	_place(_upper, shoulder, elbow)
	_place(_fore, elbow, hand)
	_gourd.position = hand
	_gourd.basis = Basis(Vector3.RIGHT, deg_to_rad(gourd_tilt_degrees) * _tilt)


## Point a segment's hanging box from `from` toward `to`.
func _place(segment: Node3D, from: Vector3, to: Vector3) -> void:
	var direction := (to - from).normalized()
	segment.position = from
	segment.basis = Basis(Quaternion(Vector3.DOWN, direction))
