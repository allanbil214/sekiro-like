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

@export_group("Swing trail (Step 11f)")
## How long (s) the ribbon takes to fade, where its inner edge sits along the blade (0 = the hand, 1 = the
## tip), and its color (the tip edge; the inner edge fades to nothing).
@export var trail_time: float = 0.25
@export_range(0.0, 0.95) var trail_base_fraction: float = 0.3
@export var trail_color: Color = Color(0.82, 0.92, 1.0, 0.7)

## Set by SwordVisual (its swing_trail switch). Off: no ribbon.
var trail_enabled: bool = false
var _shape_node: CollisionShape3D
var _box: BoxShape3D
var _debug_mesh: MeshInstance3D
## The glowing extension (Step 11e): the part of the box past the blade, shown when asked.
var _glow_halo: MeshInstance3D
var _glow_core: MeshInstance3D
## The swing trail (Step 11f): a ribbon behind the blade, drawn in world space from the points sampled
## while the hit window is open; each point fades out after trail_time.
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _trail_points: Array[Dictionary] = []
var _trail_new_strip: bool = true
var _length: float = 1.1
## Extra box behind the hand (m): the handle end of a spear. 0 = none.
var _back: float = 0.0
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
	_glow_halo = _make_glow(Color(0.6, 0.8, 1.0, 0.3), 0.14)
	_glow_core = _make_glow(Color(0.9, 0.97, 1.0, 0.9), 0.035)
	_make_trail()
	_apply_size(1.0)


## Set the blade length (m) the box is built on, and how far it reaches behind the hand
## (back_length, 0 = nothing behind). Called by SwordVisual in setup.
func configure(blade_length: float, back_length: float = 0.0) -> void:
	_length = blade_length
	_back = maxf(back_length, 0.0)
	_apply_size(1.0)


## The blade length (m) the box is built on, and how far the box reaches at `length_scale`.
func get_blade_length() -> float:
	return _length


func get_reach(length_scale: float) -> float:
	return _length * maxf(length_scale, 0.01)


## A hit window opened: forget who was hit, and size the box (length_scale grows it from the tip).
## `show_extension` also draws a glowing beam over the part of the box past the blade (Step 11e).
func begin_swing(length_scale: float, show_extension: bool = false) -> void:
	_hit_set.clear()
	_apply_size(length_scale)
	_active = true
	_has_last = false
	_trail_new_strip = true
	_debug_mesh.visible = debug_draw
	var extra := _length * (length_scale - 1.0)
	var glow := show_extension and extra > 0.01
	for beam: MeshInstance3D in [_glow_halo, _glow_core]:
		beam.visible = glow
		if glow:
			(beam.mesh as BoxMesh).size.z = extra
			beam.position = Vector3(0.0, 0.0, -(_length + extra * 0.5))


func end_swing() -> void:
	_active = false
	_debug_mesh.visible = false
	_glow_halo.visible = false
	_glow_core.visible = false


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
		if trail_enabled:
			_add_trail_point(step)
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


func _make_trail() -> void:
	_trail_mesh = ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	_trail.material_override = material
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.top_level = true
	add_child(_trail)
	_trail.global_transform = Transform3D.IDENTITY
	set_process(false)


## Remember where the blade's tip and the inner edge are at this step of the swing (`shape_transform` is
## the box's transform; its offset from the hand is the box's local position).
func _add_trail_point(shape_transform: Transform3D) -> void:
	var offset := _shape_node.position.z
	_trail_points.append({
		"tip": shape_transform * Vector3(0.0, 0.0, -_length - offset),
		"base": shape_transform * Vector3(0.0, 0.0, -_length * trail_base_fraction - offset),
		"age": 0.0,
		"start": _trail_new_strip,
	})
	_trail_new_strip = false
	set_process(true)


func _process(delta: float) -> void:
	for point: Dictionary in _trail_points:
		point["age"] = float(point["age"]) + delta
	while not _trail_points.is_empty() and float(_trail_points[0]["age"]) > trail_time:
		_trail_points.pop_front()
	_rebuild_trail()
	if _trail_points.is_empty():
		set_process(false)


func _rebuild_trail() -> void:
	_trail_mesh.clear_surfaces()
	var strips: Array[Array] = []
	var current: Array = []
	for point: Dictionary in _trail_points:
		if bool(point["start"]) and not current.is_empty():
			strips.append(current)
			current = []
		current.append(point)
	if not current.is_empty():
		strips.append(current)
	for strip: Array in strips:
		if strip.size() < 2:
			continue
		_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for point: Dictionary in strip:
			var fade := clampf(1.0 - float(point["age"]) / maxf(trail_time, 0.01), 0.0, 1.0)
			fade *= fade
			_trail_mesh.surface_set_color(Color(trail_color.r, trail_color.g, trail_color.b, trail_color.a * fade))
			_trail_mesh.surface_add_vertex(point["tip"])
			_trail_mesh.surface_set_color(Color(trail_color.r, trail_color.g, trail_color.b, 0.0))
			_trail_mesh.surface_add_vertex(point["base"])
		_trail_mesh.surface_end()


func _make_glow(color: Color, thickness: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, 1.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var beam := MeshInstance3D.new()
	beam.mesh = mesh
	beam.material_override = material
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.visible = false
	add_child(beam)
	return beam


## Box length = blade length x scale, from the hand (root) out past the tip, plus the back
## length behind the hand (the box stays one piece: it spans from the handle end to the tip).
func _apply_size(length_scale: float) -> void:
	var length := _length * maxf(length_scale, 0.01)
	_box.size = Vector3(width, width, length + _back)
	_shape_node.position = Vector3(0.0, 0.0, (_back - length) * 0.5)
	(_debug_mesh.mesh as BoxMesh).size = _box.size
