class_name Throwable
extends Node3D
## A thrown item in flight (Phase 2 item 11a). `ThrowState` spawns it with `Throwable.launch()`. Every physics
## frame it moves along its own arc (`ThrowableData.gravity`) and a ray from the last position to the next finds
## what it hit: the first enemy Hurtbox that can be hit (a HitData goes through the normal Hurtbox and Combatant,
## so guard, posture and the lethal flag work as for a sword hit) or the world. Where it stops it makes noise:
## every enemy with awareness within `ThrowableData.noise` turns suspicious and goes to look (a rock can lure a
## guard from his post). It is removed on impact or after `MAX_LIFE` seconds.
## The mesh is a placeholder built in code from the ItemData shape and color.
## The thrown item hits only enemies (the player's own body and every enemy body are excluded from the ray, so
## only hurtboxes and the world count). A thrown item cannot be deflected (it can be guarded).

const MAX_LIFE: float = 4.0
## Hurtboxes that cannot be hit (dead) are skipped; at most this many are skipped in one frame.
const MAX_PASSES: int = 4
const SPIN_SPEED: float = 18.0

var _data: ThrowableData
var _thrower: Player
var _velocity: Vector3 = Vector3.ZERO
var _life: float = 0.0
var _mesh: MeshInstance3D


## Spawns a projectile of `data` at `origin` (world space) flying with `velocity`.
static func launch(thrower: Player, data: ThrowableData, origin: Vector3, velocity: Vector3) -> Throwable:
	var projectile := Throwable.new()
	projectile._thrower = thrower
	projectile._data = data
	projectile._velocity = velocity
	thrower.get_tree().current_scene.add_child(projectile)
	projectile.global_position = origin
	return projectile


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _make_mesh(_data.shape)
	var material := StandardMaterial3D.new()
	material.albedo_color = _data.icon_color
	_mesh.material_override = material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_point_along_velocity()


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > MAX_LIFE:
		queue_free()
		return
	_velocity.y -= _data.gravity * delta
	var from := global_position
	var to := from + _velocity * delta
	var result := _cast(from, to)
	if not result.is_empty():
		global_position = result["position"]
		_impact(result)
		return
	global_position = to
	_spin(delta)


## The first thing between `from` and `to`: the world or an enemy Hurtbox that can be hit. Empty = nothing.
func _cast(from: Vector3, to: Vector3) -> Dictionary:
	return trace(_thrower, from, to, make_exclude(_thrower))


## The bodies a thrown item passes through: the thrower and every enemy body (only hurtboxes and the world count).
static func make_exclude(thrower: Player) -> Array[RID]:
	var exclude: Array[RID] = []
	exclude.append(thrower.get_rid())
	for node: Node3D in Enemies.all():
		var body := node as CollisionObject3D
		if body != null:
			exclude.append(body.get_rid())
	return exclude


## The ray a flying item uses, also used by the aim preview (item 11b) so the preview and the throw agree: the
## first world surface or enemy Hurtbox that can be hit between `from` and `to`. Hurtboxes that cannot be hit
## are added to `exclude` and skipped. Empty = nothing.
static func trace(thrower: Player, from: Vector3, to: Vector3, exclude: Array[RID]) -> Dictionary:
	var space := thrower.get_world_3d().direct_space_state
	for _pass in MAX_PASSES:
		var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.ENEMY_HURTBOX)
		query.collide_with_areas = true
		query.exclude = exclude
		var result := space.intersect_ray(query)
		if result.is_empty():
			return {}
		var hurtbox := result.get("collider") as Hurtbox
		if hurtbox == null or hurtbox.can_be_hit():
			return result
		exclude.append(hurtbox.get_rid())
	return {}


func _impact(result: Dictionary) -> void:
	var point: Vector3 = result["position"]
	var hurtbox := result.get("collider") as Hurtbox
	var tree := get_tree()
	if hurtbox != null:
		_hit_target(hurtbox, point)
	else:
		Fx.play(tree, Fx.Kind.LAND_DUST, point)
		# Placeholder sound for a landing (no thrown-item sound exists yet).
		Sfx.play_at(tree, Sfx.Id.LAND_HARD, point)
	_make_noise(point)
	queue_free()


func _hit_target(hurtbox: Hurtbox, point: Vector3) -> void:
	var hit := HitData.new()
	hit.attacker = _thrower
	hit.damage = _data.damage
	hit.posture_damage = _data.posture_damage
	hit.hitstop = 0.0
	hit.lethal = _data.lethal
	# A thrown item can be blocked but not deflected (a deflect would punish the thrower's posture).
	hit.deflectable = false
	hit.point = point
	var flat := Vector3(_velocity.x, 0.0, _velocity.z)
	if flat.length_squared() > 0.0001:
		hit.direction = flat.normalized()
	hurtbox.receive_hit(hit)
	var fx_kind := Fx.Kind.GUARD if hit.outcome == HitData.Outcome.GUARD else Fx.Kind.HIT_LANDED
	Fx.play(get_tree(), fx_kind, point, hit.direction)


## Tells every enemy with awareness that something landed at `point`.
func _make_noise(point: Vector3) -> void:
	for node: Node3D in Enemies.all():
		var enemy := node as Enemy
		if enemy != null:
			enemy.hear_noise_at(point, _data.noise)


func _point_along_velocity() -> void:
	if Vector2(_velocity.x, _velocity.z).length() < 0.01:
		return
	look_at(global_position + _velocity, Vector3.UP)


func _spin(delta: float) -> void:
	_point_along_velocity()
	if _data.shape == ItemData.Shape.STAR:
		_mesh.rotate_object_local(Vector3.UP, SPIN_SPEED * delta)
	elif _data.shape != ItemData.Shape.DART:
		_mesh.rotate_object_local(Vector3.RIGHT, SPIN_SPEED * 0.5 * delta)


static func _make_mesh(shape: ItemData.Shape) -> Mesh:
	match shape:
		ItemData.Shape.STAR:
			var disc := CylinderMesh.new()
			disc.top_radius = 0.12
			disc.bottom_radius = 0.12
			disc.height = 0.02
			return disc
		ItemData.Shape.DART:
			var dart := BoxMesh.new()
			dart.size = Vector3(0.03, 0.03, 0.26)
			return dart
		ItemData.Shape.SHARD:
			var shard := PrismMesh.new()
			shard.size = Vector3(0.14, 0.14, 0.04)
			return shard
	var ball := SphereMesh.new()
	ball.radius = 0.07
	ball.height = 0.14
	return ball
