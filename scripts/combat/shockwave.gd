class_name Shockwave
extends RefCounted
## Visual shockwaves for attacks whose hitbox reaches past the blade (ActionData.hitbox_length_scale
## above 1, Step 11e). Visual only: the hit itself is still the Hitbox. The helm splitter shows a ground
## ring where it lands (HelmSplitterState; the glowing blade extension is drawn by the Hitbox), the
## charged iai sends a crescent wave forward (AttackState). Everything is made at runtime and freed.

const WAVE_TIME: float = 0.25
const ARC_HALF_ANGLE_DEGREES: float = 55.0
## Crescent thickness at its middle, as a share of its radius.
const ARC_THICKNESS: float = 0.3
const WAVE_COLOR: Color = Color(0.8, 0.9, 1.0, 0.85)

static var _arc_mesh: ArrayMesh


## A ground shockwave spreading from `point` out to `radius` (m), with a puff of dust.
static func ground(tree: SceneTree, point: Vector3, radius: float) -> void:
	if tree == null:
		return
	var floor_point := point + Vector3.UP * 0.03
	Fx.ring(tree, floor_point, WAVE_COLOR, radius, 0.4)
	Fx.ring(tree, floor_point, Color(1.0, 1.0, 1.0, 0.5), radius * 0.65, 0.3)
	Fx.dust(tree, floor_point, 12, 0.3)


## A flat crescent wave that leaves `origin` along `facing` (horizontal): it starts `radius` (m) out
## (the blade tip) and flies `distance` (m) further while it fades.
static func arc(tree: SceneTree, origin: Vector3, facing: Vector3, radius: float, distance: float) -> void:
	if tree == null or tree.current_scene == null:
		return
	var scene: Node = tree.current_scene
	var flat := Vector3(facing.x, 0.0, facing.z)
	if flat.length_squared() < 0.0001:
		return
	flat = flat.normalized()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = WAVE_COLOR
	var wave := MeshInstance3D.new()
	wave.mesh = _arc()
	wave.material_override = material
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(wave)
	wave.global_transform = Transform3D(Basis.looking_at(flat, Vector3.UP) * Basis.from_scale(Vector3(radius, 1.0, radius)), origin)
	var tween := wave.create_tween()
	tween.set_parallel(true)
	tween.tween_property(wave, "global_position", origin + flat * distance, WAVE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, WAVE_TIME)
	tween.chain().tween_callback(wave.queue_free)


## A unit crescent in the XZ plane (outer edge at radius 1, bulging forward along -Z), bright on the outer
## edge and fading toward the inner one. Built once; scaled to the wave's radius.
static func _arc() -> ArrayMesh:
	if _arc_mesh != null:
		return _arc_mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 20
	var half := deg_to_rad(ARC_HALF_ANGLE_DEGREES)
	for i in steps:
		var t0 := -1.0 + 2.0 * float(i) / float(steps)
		var t1 := -1.0 + 2.0 * float(i + 1) / float(steps)
		var outer0 := _arc_point(t0, half, 1.0)
		var outer1 := _arc_point(t1, half, 1.0)
		var inner0 := _arc_point(t0, half, 1.0 - ARC_THICKNESS * (1.0 - t0 * t0))
		var inner1 := _arc_point(t1, half, 1.0 - ARC_THICKNESS * (1.0 - t1 * t1))
		_vertex(surface, outer0, 1.0)
		_vertex(surface, outer1, 1.0)
		_vertex(surface, inner0, 0.0)
		_vertex(surface, outer1, 1.0)
		_vertex(surface, inner1, 0.0)
		_vertex(surface, inner0, 0.0)
	_arc_mesh = surface.commit()
	return _arc_mesh


static func _arc_point(t: float, half: float, radius: float) -> Vector3:
	var angle := t * half
	return Vector3(sin(angle) * radius, 0.0, -cos(angle) * radius)


static func _vertex(surface: SurfaceTool, position: Vector3, alpha: float) -> void:
	surface.set_color(Color(1.0, 1.0, 1.0, alpha))
	surface.add_vertex(position)
