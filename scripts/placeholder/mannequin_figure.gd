class_name MannequinFigure
extends Node3D
## PLACEHOLDER(own code, ER skeleton): a figure of simple shapes (thin cylinders between the joints, a sphere head with a
## nose, a blade) that shows a `PlaceholderClips.Pose` (docs/placeholders.md, P5). It only draws what it is given; it knows
## nothing of gameplay. This is the viewer's version (3a-3a); 3a-3b makes the in-game figure from the same idea.
## The proportions are the clips' (Elden Ring's) skeleton, so the user's own rig replaces all of it in Phase 6.

## [from joint, to joint, radius (m), side: 0 centre, 1 right, -1 left]
const BONES: Array = [
	["Pelvis", "Spine", 0.10, 0], ["Spine", "Spine1", 0.11, 0], ["Spine1", "Spine2", 0.12, 0], ["Spine2", "Neck", 0.10, 0],
	["Neck", "Head", 0.045, 0],
	["Spine2", "L_UpperArm", 0.05, -1], ["L_UpperArm", "L_Forearm", 0.045, -1], ["L_Forearm", "L_Hand", 0.04, -1],
	["Spine2", "R_UpperArm", 0.05, 1], ["R_UpperArm", "R_Forearm", 0.045, 1], ["R_Forearm", "R_Hand", 0.04, 1],
	["Pelvis", "L_Thigh", 0.06, -1], ["L_Thigh", "L_Calf", 0.07, -1], ["L_Calf", "L_Foot", 0.05, -1], ["L_Foot", "L_Toe0", 0.035, -1],
	["Pelvis", "R_Thigh", 0.06, 1], ["R_Thigh", "R_Calf", 0.07, 1], ["R_Calf", "R_Foot", 0.05, 1], ["R_Foot", "R_Toe0", 0.035, 1],
]
const HEAD_RADIUS: float = 0.11
const BLADE_LENGTH: float = 1.0
const BLADE_RADIUS: float = 0.012

@export var tint: Color = Color(0.72, 0.76, 0.84)
## Off hides the blade (the game draws its own sword, `SwordVisual`). Set it before `setup()`.
@export var show_blade: bool = true
## Radians the head (its nose) tilts up (negative = down); the enemy's head pitch sets it. Used at the next `show_pose()`.
var head_pitch: float = 0.0

var _clips: PlaceholderClips
var _segments: Array[MeshInstance3D] = []
var _from: PackedInt32Array = PackedInt32Array()
var _to: PackedInt32Array = PackedInt32Array()
var _head: MeshInstance3D
var _nose: MeshInstance3D
var _blade: MeshInstance3D
var _head_joint: int = -1
var _head_axes: int = -1
var _weapon_joint: int = -1
var _weapon_axes: int = -1
var _last_pose: PlaceholderClips.Pose
## prefix ("L" or "R") -> (index of the upper arm segment, index of the forearm segment).
var _arm_segments: Dictionary = {}
var _meshes: Array[MeshInstance3D] = []
var _own_materials: Array[Material] = []


## Builds the shapes for the joints of `clips`. Call once.
func setup(clips: PlaceholderClips) -> void:
	_clips = clips
	for bone: Array in BONES:
		var mesh := CylinderMesh.new()
		mesh.top_radius = bone[2]
		mesh.bottom_radius = bone[2]
		mesh.height = 1.0
		mesh.radial_segments = 8
		mesh.rings = 1
		var side: int = bone[3]
		var segment := _instance(mesh, tint.darkened(0.25) if side < 0 else tint)
		_segments.append(segment)
		_from.append(clips.joint_index(bone[0]))
		_to.append(clips.joint_index(bone[1]))
	for i in BONES.size():
		var from_joint: String = BONES[i][0]
		if from_joint.ends_with("_UpperArm"):
			_arm_segments[from_joint.substr(0, 1)] = Vector2i(i, i + 1)
	var sphere := SphereMesh.new()
	sphere.radius = HEAD_RADIUS
	sphere.height = HEAD_RADIUS * 2.0
	_head = _instance(sphere, tint)
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.05, 0.05, 0.09)
	_nose = _instance(nose_mesh, Color(1.0, 0.55, 0.2))
	var blade_mesh := CylinderMesh.new()
	blade_mesh.top_radius = BLADE_RADIUS
	blade_mesh.bottom_radius = BLADE_RADIUS
	blade_mesh.height = 1.0
	blade_mesh.radial_segments = 6
	blade_mesh.rings = 1
	_blade = _instance(blade_mesh, Color(0.95, 0.95, 1.0))
	_head_joint = clips.joint_index("Head")
	_head_axes = clips.oriented_index("Head")
	_weapon_joint = clips.joint_index("R_Weapon")
	_weapon_axes = clips.oriented_index("R_Weapon")
	_blade.visible = show_blade


## Put the figure into `pose` (null does nothing).
func show_pose(pose: PlaceholderClips.Pose) -> void:
	if pose == null or _clips == null:
		return
	_last_pose = pose
	for i in _segments.size():
		_segments[i].transform = _segment_transform(pose.points[_from[i]], pose.points[_to[i]])
	var head := pose.points[_head_joint]
	_head.position = head + Vector3.UP * 0.07
	# The Head's Z axis faces forward (checked on the idle clip); the nose sits on that side.
	var tilt := Basis(Vector3.RIGHT, head_pitch)
	var forward := tilt * pose.axes[_head_axes * 3 + 2]
	_nose.position = head + Vector3.UP * 0.07 + forward * HEAD_RADIUS
	_nose.basis = Basis.looking_at(forward, tilt * pose.axes[_head_axes * 3 + 1])
	# The weapon joint's Y axis runs along the blade (checked on the first attack's hit frames).
	var root := pose.points[_weapon_joint]
	var along := pose.axes[_weapon_axes * 3 + 1]
	_blade.transform = _segment_transform(root, root + along * BLADE_LENGTH)


## Bend arm `prefix` ("L" or "R") of the last pose so its hand reaches `hand_target` (this node's own space): a two-bone
## solve from the pose's shoulder, the elbow bending toward `pole`. The bones keep their length and stretch up to
## `max_stretch` (0.25 = 25 percent) to reach; farther than that the hand stops short. Call after `show_pose()`.
func solve_arm(prefix: String, hand_target: Vector3, pole: Vector3, max_stretch: float) -> void:
	if _last_pose == null or not _arm_segments.has(prefix):
		return
	var shoulder: Vector3 = _last_pose.points[_clips.joint_index(prefix + "_UpperArm")]
	var elbow_rest: Vector3 = _last_pose.points[_clips.joint_index(prefix + "_Forearm")]
	var hand_rest: Vector3 = _last_pose.points[_clips.joint_index(prefix + "_Hand")]
	var upper: float = shoulder.distance_to(elbow_rest)
	var fore: float = elbow_rest.distance_to(hand_rest)
	var to: Vector3 = hand_target - shoulder
	var dist: float = to.length()
	if dist < 0.001 or upper + fore < 0.001:
		return
	var dir: Vector3 = to / dist
	var stretch: float = clampf(dist / ((upper + fore) * 0.999), 1.0, 1.0 + max_stretch)
	upper *= stretch
	fore *= stretch
	dist = clampf(dist, absf(upper - fore) + 0.001, (upper + fore) * 0.999)
	var along: float = (upper * upper - fore * fore + dist * dist) / (2.0 * dist)
	var height: float = sqrt(maxf(upper * upper - along * along, 0.0))
	var bend: Vector3 = pole - dir * pole.dot(dir)
	bend = bend.normalized() if bend.length() > 0.0001 else Vector3.DOWN
	var elbow: Vector3 = shoulder + dir * along + bend * height
	var hand: Vector3 = shoulder + dir * dist
	var segments: Vector2i = _arm_segments[prefix]
	_segments[segments.x].transform = _segment_transform(shoulder, elbow)
	_segments[segments.y].transform = _segment_transform(elbow, hand)


## Show or hide the figure's own blade (3a-3c: shown while a clip plays, when the code-drawn sword is hidden).
func set_blade_visible(on: bool) -> void:
	if _blade != null:
		_blade.visible = on


## 3d-2: every shape of the figure casts a real shadow (on), or none (off, how the viewer's figure is). The arenas' lights decide
## whether shadows show at all.
func set_shadow_casting(on: bool) -> void:
	var mode: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on \
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mesh: MeshInstance3D in _meshes:
		mesh.cast_shadow = mode


## Draw every shape with `material` (the i-frame tint), or with its own colors again when null.
func set_overlay_material(material: Material) -> void:
	for i in _meshes.size():
		_meshes[i].material_override = material if material != null else _own_materials[i]


func _instance(mesh: Mesh, color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_meshes.append(instance)
	_own_materials.append(material)
	return instance


## A unit-height cylinder placed from `a` to `b`: its Y axis along the bone, stretched to the bone's length.
static func _segment_transform(a: Vector3, b: Vector3) -> Transform3D:
	var along := b - a
	var length := along.length()
	if length < 0.001:
		return Transform3D(Basis.from_scale(Vector3.ZERO), a)
	var y := along / length
	var reference := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := reference.cross(y).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x, y * length, z), (a + b) * 0.5)
