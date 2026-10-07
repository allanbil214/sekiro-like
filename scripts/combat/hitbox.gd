class_name Hitbox
extends Area3D
## The part of an attack that deals damage: a box along the blade (local -Z from the hand).
## Add it as an Area3D with a CollisionShape3D (BoxShape3D) child under SwordVisual; SwordVisual
## moves it with the hand every frame. It is only a shape holder: hits are found by sweeping the
## box through the space it moved through since the last physics frame (so a fast swing cannot
## skip over a target), and each Hurtbox is hit at most once per swing.
##
## ActionState drives it: begin_swing() when an attack's hit window opens, sweep() every physics
## frame while it is open, end_swing() when it closes.

signal hit_landed(hurtbox: Hurtbox, hit: HitData)

@export var team: Layers.Team = Layers.Team.PLAYER
## Cross-section of the box (m). Wider than the visible blade, so hits feel fair.
@export var width: float = 0.3
## The box is tested at least every this many meters of travel (smaller = safer, slower).
@export var sweep_step_distance: float = 0.15
@export var max_sweep_steps: int = 12
## Draw the box while the hit window is open.
@export var debug_draw: bool = true

var _shape_node: CollisionShape3D
var _box: BoxShape3D
var _debug_mesh: MeshInstance3D
var _length: float = 1.1
var _active: bool = false
var _hit_set: Array[Hurtbox] = []
var _last_transform: Transform3D = Transform3D.IDENTITY
var _has_last: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	for child: Node in get_children():
		if child is CollisionShape3D:
			_shape_node = child as CollisionShape3D
			break
	if _shape_node == null:
		_shape_node = CollisionShape3D.new()
		add_child(_shape_node)
	_box = _shape_node.shape as BoxShape3D
	if _box == null:
		_box = BoxShape3D.new()
	else:
		# Each Hitbox owns its box (the size is changed per action).
		_box = _box.duplicate() as BoxShape3D
	_shape_node.shape = _box
	_debug_mesh = MeshInstance3D.new()
	_debug_mesh.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.2, 0.1, 0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_mesh.material_override = material
	_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debug_mesh.visible = false
	_shape_node.add_child(_debug_mesh)
	_apply_size(1.0)


## Set the blade length (m) the box is built on. Called by SwordVisual in setup.
func configure(blade_length: float) -> void:
	_length = blade_length
	_apply_size(1.0)


## A hit window opened: forget who was hit, and size the box (length_scale grows it from the tip).
func begin_swing(length_scale: float) -> void:
	_hit_set.clear()
	_apply_size(length_scale)
	_active = true
	_has_last = false
	_debug_mesh.visible = debug_draw


func end_swing() -> void:
	_active = false
	_debug_mesh.visible = false


## Test the swept box against the other team's hurtboxes. `template` carries the damage, hitstop,
## attacker, and action; each new target gets its own copy with direction and point filled in.
## Returns the hits that landed this frame.
func sweep(template: HitData) -> Array[HitData]:
	var landed: Array[HitData] = []
	if not _active or _shape_node == null:
		return landed
	var now := _shape_node.global_transform
	var from := now
	if _has_last:
		from = _last_transform
	_last_transform = now
	_has_last = true
	var half := Vector3(0.0, 0.0, -_box.size.z * 0.5)
	var travel := maxf(from.origin.distance_to(now.origin),
			(from * half).distance_to(now * half))
	var steps := clampi(ceili(travel / maxf(sweep_step_distance, 0.01)), 1, max_sweep_steps)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _box
	params.collision_mask = Layers.hurtbox_layer(Layers.opposing(team))
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var space := get_world_3d().direct_space_state
	for i in range(1, steps + 1):
		var step := from.interpolate_with(now, float(i) / float(steps))
		params.transform = Transform3D(step.basis.orthonormalized(), step.origin)
		for result: Dictionary in space.intersect_shape(params, 16):
			var hurtbox := result.get("collider") as Hurtbox
			if hurtbox == null or hurtbox in _hit_set or not hurtbox.can_be_hit():
				continue
			_hit_set.append(hurtbox)
			var hit := template.copy()
			hit.point = params.transform.origin
			var away := hurtbox.global_position
			if template.attacker is Node3D:
				away -= (template.attacker as Node3D).global_position
			away.y = 0.0
			if away.length_squared() > 0.0001:
				hit.direction = away.normalized()
			hurtbox.receive_hit(hit)
			hit_landed.emit(hurtbox, hit)
			landed.append(hit)
	return landed


## Box length = blade length x scale, from the hand (root) out past the tip.
func _apply_size(length_scale: float) -> void:
	var length := _length * maxf(length_scale, 0.01)
	_box.size = Vector3(width, width, length)
	_shape_node.position = Vector3(0.0, 0.0, -length * 0.5)
	(_debug_mesh.mesh as BoxMesh).size = _box.size
