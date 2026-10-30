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
## Item 21: an enemy can throw too (`EnemyThrow`). The thrower is any Node3D; an enemy's projectile checks the
## player's hurtbox instead of the enemies' (`hurt_mask_for()`), can scale the damage and can stay quiet.

const MAX_LIFE: float = 4.0
## Hurtboxes that cannot be hit (dead) are skipped; at most this many are skipped in one frame.
const MAX_PASSES: int = 4
const SPIN_SPEED: float = 18.0

var _data: ThrowableData
var _thrower: Node3D
## Item 21: which hurtbox layer this projectile can hit (the enemies' for the player's throw, the player's for an enemy's).
var _hurt_mask: int = Layers.ENEMY_HURTBOX
## Item 21: multiplies the item's damage and posture damage (an enemy's throw), and whether the landing makes noise.
var _damage_scale: float = 1.0
var _noisy: bool = true
## Item 20: where the thrower stood when it threw this (an unaware enemy it hits investigates there).
var _shot_from: Vector3 = Vector3.ZERO
var _velocity: Vector3 = Vector3.ZERO
var _life: float = 0.0
var _mesh: MeshInstance3D


## Spawns a projectile of `data` at `origin` (world space) flying with `velocity`. `damage_scale` and `noisy` are for
## an enemy's throw (item 21); the player's throw keeps the defaults.
static func launch(thrower: Node3D, data: ThrowableData, origin: Vector3, velocity: Vector3, damage_scale: float = 1.0, noisy: bool = true) -> Throwable:
	var projectile := Throwable.new()
	projectile._thrower = thrower
	projectile._hurt_mask = hurt_mask_for(thrower)
	projectile._damage_scale = damage_scale
	projectile._noisy = noisy
	projectile._shot_from = thrower.global_position
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
	if _life > MAX_LIFE or not is_instance_valid(_thrower):
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
	return trace(_thrower, from, to, make_exclude(_thrower), _hurt_mask)


## Item 21: the hurtbox layer a throw by `thrower` can hit: the enemies' for the player, the player's for an enemy.
static func hurt_mask_for(thrower: Node3D) -> int:
	return Layers.ENEMY_HURTBOX if thrower is Player else Layers.PLAYER_HURTBOX


## The bodies a thrown item passes through: the thrower, the player and every enemy body (only hurtboxes and the
## world count).
static func make_exclude(thrower: Node3D) -> Array[RID]:
	var exclude: Array[RID] = []
	var thrower_body := thrower as CollisionObject3D
	if thrower_body != null:
		exclude.append(thrower_body.get_rid())
	var player_body := thrower.get_tree().get_first_node_in_group(Groups.PLAYER) as CollisionObject3D
	if player_body != null:
		exclude.append(player_body.get_rid())
	for node: Node3D in Enemies.all():
		var body := node as CollisionObject3D
		if body != null:
			exclude.append(body.get_rid())
	return exclude


## The ray a flying item uses, also used by the aim preview (item 11b) so the preview and the throw agree: the
## first world surface or Hurtbox of `hurt_mask` (the enemies' by default, item 21: the player's for an enemy) that
## can be hit between `from` and `to`. Hurtboxes that cannot be hit are added to `exclude` and skipped. Empty = nothing.
static func trace(thrower: Node3D, from: Vector3, to: Vector3, exclude: Array[RID], hurt_mask: int = Layers.ENEMY_HURTBOX) -> Dictionary:
	var space := thrower.get_world_3d().direct_space_state
	for _pass in MAX_PASSES:
		var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.SMOOTH_RAMP | hurt_mask)
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
	if _noisy:
		_make_noise(point)
	queue_free()


func _hit_target(hurtbox: Hurtbox, point: Vector3) -> void:
	apply_hit(_thrower, _data, hurtbox, point, _velocity, _shot_from, _damage_scale)


## A thrown thing (an item, or a body: Phase 2 item 15c) hits `hurtbox` at `point`, flying with `velocity`; the numbers
## are `data`'s (times `damage_scale`, item 21). `shot_from` is where the thrower stood when throwing (item 20: the
## hit carries it as `HitData.origin`).
static func apply_hit(thrower: Node3D, data: ThrowableData, hurtbox: Hurtbox, point: Vector3, velocity: Vector3, shot_from: Vector3, damage_scale: float = 1.0) -> void:
	var hit := HitData.new()
	hit.attacker = thrower
	hit.damage = data.damage * damage_scale
	hit.posture_damage = data.posture_damage * damage_scale
	hit.hitstop = 0.0
	hit.lethal = data.lethal
	# A thrown item can be blocked but not deflected (a deflect would punish the thrower's posture).
	hit.deflectable = false
	hit.point = point
	hit.thrown = true
	hit.origin = shot_from
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length_squared() > 0.0001:
		hit.direction = flat.normalized()
	hurtbox.receive_hit(hit)
	var fx_kind := Fx.Kind.GUARD if hit.outcome == HitData.Outcome.GUARD else Fx.Kind.HIT_LANDED
	Fx.play(hurtbox.get_tree(), fx_kind, point, hit.direction)


## Tells every enemy with awareness that something landed at `point`.
func _make_noise(point: Vector3) -> void:
	broadcast_noise(point, _data.noise, _thrower)


## Every enemy with awareness hears `radius` m of noise at `point`, except `quiet` (item 21: an enemy that threw it
## does not hear its own throw).
static func broadcast_noise(point: Vector3, radius: float, quiet: Node = null) -> void:
	for node: Node3D in Enemies.all():
		var enemy := node as Enemy
		if enemy != null and enemy != quiet:
			enemy.hear_noise_at(point, radius)


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
