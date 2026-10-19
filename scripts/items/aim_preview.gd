class_name AimPreview
extends Node3D
## The aim solver and the arc preview (Phase 2 item 11b). A direct child of the Player. While `AimState` runs it
## calls `update()` every physics frame with the hand position and the selected throwable:
##   1. A ray from the camera along its look direction finds the AIM POINT (the first world surface or enemy
##      Hurtbox that can be hit, else a far point `aim_range` away). That is what the crosshair is over.
##   2. `velocity` is the throw that goes from the hand to that point (`ThrowableData.velocity_to`: straight
##      for a shuriken or kunai, the lower arc for a rock or ceramic; a point out of range gets the 45 degree
##      throw, the farthest one). `AimState` hands this velocity to `ThrowState` on release.
##   3. For an item with gravity, the arc is simulated with the projectile's own rules (the same physics step,
##      gravity and ray as `Throwable`) and drawn as dots, with a ring where it lands and a wide ring for the
##      noise radius. A straight flyer has no arc to show (its crosshair is drawn by `AimHud`).
## The dots and rings are small meshes built in code (placeholders until real art exists).

## The most dots drawn (one every `dot_spacing_time` seconds of flight).
const MAX_DOTS: int = 80

@export_group("Aim")
## How far (m) the aim ray looks when it hits nothing.
@export var aim_range: float = 60.0
@export_group("Arc")
@export var dot_spacing_time: float = 0.05
@export var dot_size: float = 0.06
@export var dot_color: Color = Color(1.0, 1.0, 1.0, 0.85)
@export_group("Landing")
## Diameter (m) of the landing ring.
@export var landing_size: float = 0.6
@export var landing_color: Color = Color(1.0, 0.9, 0.5, 0.9)
## The wide ring that shows how far the landing is heard (the item's noise radius).
@export var noise_ring_color: Color = Color(1.0, 1.0, 1.0, 0.3)

## The point the crosshair is over (world space), valid after `update()`.
var aim_point: Vector3 = Vector3.ZERO
## The throw velocity from the hand to `aim_point`, valid after `update()`.
var velocity: Vector3 = Vector3.ZERO

var _player: Player
var _dots: MultiMeshInstance3D
var _landing: MeshInstance3D
var _noise_ring: MeshInstance3D


func _ready() -> void:
	_player = get_parent() as Player
	top_level = true
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var ball := SphereMesh.new()
	ball.radius = dot_size * 0.5
	ball.height = dot_size
	ball.radial_segments = 8
	ball.rings = 4
	multimesh.mesh = ball
	multimesh.instance_count = MAX_DOTS
	multimesh.visible_instance_count = 0
	_dots = MultiMeshInstance3D.new()
	_dots.multimesh = multimesh
	_dots.material_override = _make_material(null, dot_color, 10)
	_dots.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dots.visible = false
	add_child(_dots)
	_landing = _make_ring(landing_color, PackedFloat32Array([0.0, 0.7, 0.76, 0.94, 1.0]), PackedFloat32Array([0.25, 0.25, 1.0, 1.0, 0.0]), 10)
	_noise_ring = _make_ring(noise_ring_color, PackedFloat32Array([0.0, 0.94, 0.96, 0.985, 1.0]), PackedFloat32Array([0.0, 0.0, 1.0, 1.0, 0.0]), 9)


## Solves the aim and (for an item with gravity) draws the arc. `origin` is where the item leaves the hand.
func update(origin: Vector3, item: ThrowableData) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var exclude := Throwable.make_exclude(_player)
	var from := camera.global_position
	var forward := -camera.global_basis.z
	var far := from + forward * aim_range
	var hit := Throwable.trace(_player, from, far, exclude)
	aim_point = hit["position"] if not hit.is_empty() else far
	if aim_point.distance_to(origin) < 0.5:
		aim_point = origin + forward * 0.5
	velocity = item.velocity_to(origin, aim_point)
	if item.gravity <= 0.0:
		_hide_arc()
		return
	_draw_arc(origin, item, exclude)


## Hides the dots and rings (aim over).
func hide_preview() -> void:
	_hide_arc()


func _hide_arc() -> void:
	_dots.visible = false
	_landing.visible = false
	_noise_ring.visible = false


func _draw_arc(origin: Vector3, item: ThrowableData, exclude: Array[RID]) -> void:
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	var multimesh := _dots.multimesh
	var position_now := origin
	var velocity_now := velocity
	var time := 0.0
	var next_dot := dot_spacing_time
	var count := 0
	var landed := false
	var landing_point := origin
	var landing_normal := Vector3.UP
	while time < Throwable.MAX_LIFE:
		velocity_now.y -= item.gravity * step
		var next := position_now + velocity_now * step
		var result := Throwable.trace(_player, position_now, next, exclude)
		time += step
		if not result.is_empty():
			landed = true
			landing_point = result["position"]
			landing_normal = result["normal"]
			# A hit on an enemy's Hurtbox (an Area3D) has no surface normal: lay the ring flat.
			if landing_normal.length_squared() < 0.01:
				landing_normal = Vector3.UP
			break
		position_now = next
		if time >= next_dot and count < MAX_DOTS:
			multimesh.set_instance_transform(count, Transform3D(Basis.IDENTITY, position_now))
			count += 1
			next_dot += dot_spacing_time
	multimesh.visible_instance_count = count
	_dots.visible = count > 0
	_landing.visible = landed
	_noise_ring.visible = landed
	if not landed:
		return
	_landing.global_transform = Transform3D(_basis_facing(landing_normal, landing_size), landing_point + landing_normal * 0.03)
	_noise_ring.global_transform = Transform3D(_basis_facing(Vector3.UP, item.noise * 2.0), landing_point + Vector3.UP * 0.04)


## A basis that turns a quad (facing +Z) to face `normal`, scaled to `size` metres wide.
func _basis_facing(normal: Vector3, size: float) -> Basis:
	var hint := Vector3.FORWARD if absf(normal.y) > 0.99 else Vector3.UP
	var turned := Basis.looking_at(-normal, hint)
	return turned.scaled_local(Vector3(size, size, 1.0))


func _make_ring(color: Color, offsets: PackedFloat32Array, alphas: PackedFloat32Array, priority: int) -> MeshInstance3D:
	var gradient := Gradient.new()
	gradient.offsets = offsets
	var colors := PackedColorArray()
	for alpha: float in alphas:
		colors.append(Color(1.0, 1.0, 1.0, alpha))
	gradient.colors = colors
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = QuadMesh.new()
	mesh_instance.material_override = _make_material(texture, color, priority)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.visible = false
	add_child(mesh_instance)
	return mesh_instance


func _make_material(texture: Texture2D, color: Color, priority: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = priority
	if texture != null:
		material.albedo_texture = texture
	return material
