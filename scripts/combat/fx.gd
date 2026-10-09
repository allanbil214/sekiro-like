class_name Fx
extends RefCounted
## One call per game event (Step 11): Fx.play(tree, kind, point, direction). It adds the camera shake
## (11c), the sparks and effects (11b), and the sound (11a, `Sfx`, see `_sound()` below), so each
## event has a single call site. `point` is where it happened (HitData.point or a body position) and
## `direction` is the horizontal direction of the blow (HitData.direction, attacker to target); both are
## optional. The shake finds the camera through the group "camera_rig" (CameraRig.add_trauma). The
## effects are short CPUParticles3D bursts and expanding rings made at runtime and freed when they end
## (no scenes); everything is parented to the current scene, so a scene reload clears them.

enum Kind {
	HIT_LANDED, HIT_LANDED_CHARGED, DEFLECT, DEFLECT_PERILOUS, GUARD, GUARD_BREAK, REPULSE, HURT,
	PERILOUS_HIT, GRAB, POSTURE_BREAK, MIKIRI, HEAD_STOMP, HELM_LAND, DEATHBLOW, BOSS_SLAIN,
	HARD_LAND, LAND_DUST, SLIDE_DUST, HEAL_TICK, HEAL, RESURRECT,
}

## Camera trauma added per event (0 to 1). Placeholders: tune in play. A perilous hit through the
## guard (guard break) shakes as PERILOUS_HIT; GUARD_BREAK is only the sparks.
const TRAUMA: Dictionary = {
	Kind.HIT_LANDED: 0.15,
	Kind.HIT_LANDED_CHARGED: 0.3,
	Kind.DEFLECT: 0.2,
	Kind.DEFLECT_PERILOUS: 0.3,
	Kind.GUARD: 0.25,
	Kind.HURT: 0.35,
	Kind.PERILOUS_HIT: 0.5,
	Kind.GRAB: 0.6,
	Kind.POSTURE_BREAK: 0.4,
	Kind.MIKIRI: 0.3,
	Kind.HEAD_STOMP: 0.3,
	Kind.HELM_LAND: 0.5,
	Kind.DEATHBLOW: 0.7,
	Kind.BOSS_SLAIN: 0.8,
	Kind.HARD_LAND: 0.2,
}

## Off: no red mist or red flecks on flesh hits, and no mist on a deathblow (its red sparks stay).
## Set from Player.show_blood at startup.
static var blood_enabled: bool = true

## The deathblow's blood jet (Sekiro style, like a burst pipe): it pulses every DEATHBLOW_PULSE_INTERVAL
## seconds for DEATHBLOW_BLOOD_TIME seconds, strongest at the start and tapering to a trickle.
const DEATHBLOW_BLOOD_TIME: float = 2.0
const DEATHBLOW_PULSE_INTERVAL: float = 0.1

static var _soft_texture: Texture2D
static var _cache: Dictionary = {}


## `attach` (optional): a node the effect's source follows while it lasts (the deathblow's blood jet
## stays on the enemy's body).
static func play(tree: SceneTree, kind: Kind, point: Vector3 = Vector3.ZERO, direction: Vector3 = Vector3.ZERO,
		attach: Node3D = null) -> void:
	if tree == null:
		return
	var trauma: float = TRAUMA.get(kind, 0.0)
	if trauma > 0.0:
		tree.call_group("camera_rig", "add_trauma", trauma, direction)
	_sound(tree, kind, point)
	var scene := tree.current_scene
	if scene != null:
		_spawn(scene, kind, point, direction, attach)


# --- Which sound each event makes (Step 11a) ---------------------------------------------------

## World events play at `point`; the player's own sounds (hurt, landing, heal) are not placed.
static func _sound(tree: SceneTree, kind: Kind, point: Vector3) -> void:
	match kind:
		Kind.HIT_LANDED:
			Sfx.play_at(tree, Sfx.Id.HIT_FLESH, point)
		Kind.HIT_LANDED_CHARGED:
			Sfx.play_at(tree, Sfx.Id.HIT_FLESH_HEAVY, point)
		Kind.DEFLECT:
			Sfx.play_at(tree, Sfx.Id.DEFLECT, point)
		Kind.DEFLECT_PERILOUS:
			Sfx.play_at(tree, Sfx.Id.DEFLECT_PERILOUS, point)
		Kind.GUARD:
			Sfx.play_at(tree, Sfx.Id.GUARD_BLOCK, point)
		Kind.GUARD_BREAK:
			Sfx.play_at(tree, Sfx.Id.GUARD_BREAK, point)
		Kind.REPULSE:
			Sfx.play_at(tree, Sfx.Id.REPULSE, point)
		Kind.HURT, Kind.PERILOUS_HIT:
			Sfx.play(tree, Sfx.Id.PLAYER_HURT)
		Kind.GRAB:
			Sfx.play(tree, Sfx.Id.GRAB_HIT)
		Kind.POSTURE_BREAK:
			Sfx.play_at(tree, Sfx.Id.POSTURE_BREAK, point)
		Kind.MIKIRI:
			Sfx.play_at(tree, Sfx.Id.MIKIRI, point)
		Kind.HEAD_STOMP:
			Sfx.play_at(tree, Sfx.Id.HEAD_STOMP, point)
		Kind.DEATHBLOW:
			Sfx.play_at(tree, Sfx.Id.HIT_FLESH_HEAVY, point)
			Sfx.play_at(tree, Sfx.Id.BLOOD_BURST, point)
		Kind.HARD_LAND:
			Sfx.play(tree, Sfx.Id.LAND_HARD)
		Kind.HEAL:
			Sfx.play(tree, Sfx.Id.HEAL_DONE)
		Kind.RESURRECT:
			Sfx.play(tree, Sfx.Id.RESURRECT)
		_:
			pass


# --- Which effect each event makes ------------------------------------------------------------

static func _spawn(scene: Node, kind: Kind, point: Vector3, direction: Vector3, attach: Node3D = null) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	# Sparks fly back toward the attacker and up a little.
	var back := Vector3.UP
	if flat.length_squared() > 0.0001:
		back = (-flat.normalized() + Vector3.UP * 0.6).normalized()
	match kind:
		Kind.DEFLECT:
			# The big one: many, fast, bright yellow into yellow-orange.
			_sparks(scene, point, back, 38, 0.4, Vector2(5.0, 11.0), 60.0, 0.16,
					[Color(1.0, 0.97, 0.55), Color(1.0, 0.75, 0.2), Color(1.0, 0.5, 0.08, 0.0)])
		Kind.DEFLECT_PERILOUS:
			_sparks(scene, point, back, 32, 0.42, Vector2(5.0, 11.0), 60.0, 0.17,
					[Color(1.0, 0.97, 0.55), Color(1.0, 0.75, 0.2), Color(1.0, 0.5, 0.08, 0.0)])
			_sparks(scene, point, back, 24, 0.45, Vector2(4.0, 10.0), 70.0, 0.15,
					[Color(1.0, 0.55, 0.15), Color(1.0, 0.25, 0.05), Color(0.7, 0.05, 0.0, 0.0)])
		Kind.GUARD:
			# White, fewer, duller.
			_sparks(scene, point, back, 14, 0.28, Vector2(2.5, 5.5), 55.0, 0.09,
					[Color(0.92, 0.92, 0.9), Color(0.72, 0.72, 0.72), Color(0.5, 0.5, 0.5, 0.0)])
		Kind.GUARD_BREAK:
			_sparks(scene, point, back, 46, 0.5, Vector2(4.0, 11.0), 85.0, 0.18,
					[Color(1.0, 0.8, 0.35), Color(1.0, 0.5, 0.1), Color(0.8, 0.2, 0.02, 0.0)])
		Kind.POSTURE_BREAK:
			_sparks(scene, point, Vector3.UP, 42, 0.5, Vector2(3.0, 8.0), 180.0, 0.14,
					[Color(0.92, 0.96, 1.0), Color(0.55, 0.75, 1.0), Color(0.3, 0.5, 1.0, 0.0)])
			_ring(scene, point, Color(0.75, 0.88, 1.0, 0.85), 1.8, 0.45)
		Kind.REPULSE:
			_ring(scene, point, Color(1.0, 1.0, 1.0, 0.8), 1.6, 0.3)
			_sparks(scene, point, back, 10, 0.25, Vector2(3.0, 6.0), 70.0, 0.1,
					[Color(1.0, 1.0, 1.0), Color(0.8, 0.85, 1.0), Color(0.6, 0.7, 1.0, 0.0)])
		Kind.MIKIRI, Kind.HEAD_STOMP:
			# A shockwave instead of sparks, plus dust.
			_ring(scene, point, Color(1.0, 1.0, 1.0, 0.85), 2.4, 0.4)
			_ring(scene, point, Color(1.0, 0.95, 0.85, 0.5), 1.4, 0.3)
			_dust(scene, point, 10, 0.3, Vector3.ZERO)
		Kind.DEATHBLOW:
			_sparks(scene, point, Vector3.UP, 46, 0.6, Vector2(3.0, 9.0), 150.0, 0.16,
					[Color(1.0, 0.25, 0.15), Color(0.8, 0.05, 0.05), Color(0.35, 0.0, 0.02, 0.0)])
			if blood_enabled:
				_mist(scene, point, Vector3.UP, 16, 0.7, 0.28, 150.0)
				# `direction` runs from the player to the enemy; the jet comes out of the wound toward the player.
				_blood_jet(scene, point, -flat, attach)
		Kind.HIT_LANDED, Kind.HIT_LANDED_CHARGED, Kind.HURT, Kind.PERILOUS_HIT, Kind.GRAB:
			if blood_enabled:
				var big := kind == Kind.HIT_LANDED_CHARGED or kind == Kind.PERILOUS_HIT or kind == Kind.GRAB
				_mist(scene, point, back, 11 if big else 7, 0.5, 0.2, 70.0)
				_sparks(scene, point, back, 8 if big else 5, 0.3, Vector2(2.0, 5.0), 60.0, 0.07,
						[Color(0.8, 0.05, 0.05), Color(0.5, 0.0, 0.03), Color(0.3, 0.0, 0.02, 0.0)])
		Kind.HARD_LAND:
			_dust(scene, point, 14, 0.4, Vector3.ZERO)
		Kind.LAND_DUST:
			_dust(scene, point, 6, 0.26, Vector3.ZERO)
		Kind.SLIDE_DUST:
			_dust(scene, point, 2, 0.22, flat)
		Kind.HEAL_TICK:
			_motes(scene, point, 2, 0.9, 0.07, 0.45, 0.0,
					[Color(0.55, 1.0, 0.65, 0.9), Color(0.3, 0.95, 0.45, 0.6), Color(0.2, 0.8, 0.3, 0.0)])
		Kind.HEAL:
			_motes(scene, point, 26, 1.0, 0.08, 0.5, 0.6,
					[Color(0.6, 1.0, 0.7, 0.95), Color(0.3, 0.95, 0.45, 0.65), Color(0.2, 0.8, 0.3, 0.0)])
		Kind.RESURRECT:
			_motes(scene, point, 50, 1.5, 0.12, 0.35, 0.25,
					[Color(1.0, 0.88, 0.94, 0.95), Color(1.0, 0.72, 0.86, 0.7), Color(1.0, 0.9, 1.0, 0.0)], 1.8, 3.6)
			_glow(scene, point + Vector3.UP * 0.9, Color(1.0, 0.85, 0.92, 0.5), 2.2, 0.7)
		_:
			pass


# --- Building blocks --------------------------------------------------------------------------

## A burst of thin streaks stretched along their flight (the particle's long axis follows its velocity).
static func _sparks(scene: Node, point: Vector3, direction: Vector3, amount: int, life: float, speed: Vector2,
		spread: float, length: float, colors: Array[Color], width: float = 0.012, gravity: float = 7.0,
		additive: bool = true) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.mesh = _streak_mesh(length, width, additive)
	p.particle_flag_align_y = true
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector3(0.0, -gravity, 0.0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.color_ramp = _ramp(colors)
	p.scale_amount_curve = _curve(1.0, 0.2)
	_launch(scene, p, point)


## The deathblow's blood jet: a series of pulses out of the wound toward the player (`flat` is the
## horizontal direction from the target to the player), thick red streams that arc and fall, with mist.
## Each pulse starts from the same spot on `attach` (the enemy's body), so the source follows its
## recoil and sway; the blood already in the air flies on in world space.
static func _blood_jet(scene: Node, point: Vector3, flat: Vector3, attach: Node3D) -> void:
	var jet := Vector3.UP
	if flat.length_squared() > 0.0001:
		jet = (flat.normalized() * 0.8 + Vector3.UP * 0.5).normalized()
	var local := Vector3.ZERO
	if attach != null:
		local = attach.to_local(point)
	var count := maxi(int(DEATHBLOW_BLOOD_TIME / DEATHBLOW_PULSE_INTERVAL), 1)
	var tween := scene.create_tween()
	for i in count:
		var fade := pow(1.0 - float(i) / float(count), 1.4)
		var strength := fade * (0.75 + 0.25 * sin(float(i) * 1.9))
		tween.tween_callback(_blood_pulse.bind(scene, point, local, attach, jet, strength))
		tween.tween_interval(DEATHBLOW_PULSE_INTERVAL)


static func _blood_pulse(scene: Node, point: Vector3, local: Vector3, attach: Node3D, jet: Vector3, strength: float) -> void:
	if not is_instance_valid(scene):
		return
	if attach != null:
		if not is_instance_valid(attach) or not attach.is_inside_tree():
			return
		point = attach.to_global(local)
	_sparks(scene, point, jet, int(8.0 + 22.0 * strength), 0.7, Vector2(3.0 + 4.0 * strength, 6.0 + 8.0 * strength),
			22.0, 0.22, [Color(0.85, 0.05, 0.05), Color(0.6, 0.02, 0.03), Color(0.3, 0.0, 0.02, 0.0)],
			0.04, 12.0, false)
	_mist(scene, point, jet, int(2.0 + 4.0 * strength), 0.7, 0.3, 40.0)


## Soft round puffs (alpha-blended, or additive for light), flying out then settling.
static func _puffs(scene: Node, point: Vector3, direction: Vector3, amount: int, life: float, size: float,
		speed: Vector2, spread: float, colors: Array[Color], additive: bool, gravity_y: float, damping: float,
		start_scale: float, end_scale: float, explosiveness: float, radius: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.explosiveness = explosiveness
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	mesh.material = _puff_material(additive)
	p.mesh = mesh
	if radius > 0.0:
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = radius
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.gravity = Vector3(0.0, gravity_y, 0.0)
	p.damping_min = damping
	p.damping_max = damping * 1.5
	p.color_ramp = _ramp(colors)
	p.scale_amount_curve = _curve(start_scale, end_scale)
	_launch(scene, p, point)


static func _mist(scene: Node, point: Vector3, direction: Vector3, amount: int, life: float, size: float, spread: float) -> void:
	_puffs(scene, point, direction, amount, life, size, Vector2(1.0, 3.0), spread,
			[Color(0.6, 0.02, 0.03, 0.8), Color(0.38, 0.0, 0.02, 0.45), Color(0.2, 0.0, 0.01, 0.0)],
			false, -2.0, 2.0, 0.5, 1.6, 1.0, 0.05)


static func _dust(scene: Node, point: Vector3, amount: int, size: float, drift: Vector3) -> void:
	var direction := Vector3.UP
	var speed := Vector2(0.8, 2.2)
	if drift.length_squared() > 0.0001:
		direction = (drift.normalized() + Vector3.UP * 0.4).normalized()
		speed = Vector2(0.6, 1.4)
	_puffs(scene, point + Vector3.UP * 0.05, direction, amount, 0.6, size, speed, 80.0 if drift == Vector3.ZERO else 40.0,
			[Color(0.72, 0.66, 0.56, 0.55), Color(0.65, 0.6, 0.52, 0.3), Color(0.6, 0.55, 0.5, 0.0)],
			false, 0.0, 4.0, 0.5, 1.8, 1.0, 0.1)


## Glowing motes rising around a point (heal, resurrection). `rise_min` and `rise_max` are the rising speeds.
static func _motes(scene: Node, point: Vector3, amount: int, life: float, size: float, radius: float,
		explosiveness: float, colors: Array[Color], rise_min: float = 0.6, rise_max: float = 1.5) -> void:
	_puffs(scene, point, Vector3.UP, amount, life, size, Vector2(rise_min, rise_max), 25.0, colors,
			true, 0.0, 0.3, 1.0, 0.3, explosiveness, radius)


## One big soft flash of light that fades (the resurrection's glow).
static func _glow(scene: Node, point: Vector3, color: Color, size: float, life: float) -> void:
	_puffs(scene, point, Vector3.UP, 1, life, size, Vector2(0.0, 0.0), 0.0,
			[color, Color(color.r, color.g, color.b, 0.0)], true, 0.0, 0.0, 0.6, 1.2, 1.0, 0.0)


## A flat ring on the horizontal plane that grows to `radius` (m) and fades over `time`.
static func _ring(scene: Node, point: Vector3, color: Color, radius: float, time: float) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.93
	torus.outer_radius = 1.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	var band := MeshInstance3D.new()
	band.mesh = torus
	band.material_override = material
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	band.scale = Vector3(0.15, 1.0, 0.15)
	scene.add_child(band)
	band.global_position = point
	var tween := band.create_tween()
	tween.set_parallel(true)
	tween.tween_property(band, "scale", Vector3(radius, 1.0, radius), time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, time)
	tween.chain().tween_callback(band.queue_free)


## Public wrappers for Shockwave: a growing ground ring and a puff of dust at `point`.
static func ring(tree: SceneTree, point: Vector3, color: Color, radius: float, time: float) -> void:
	if tree != null and tree.current_scene != null:
		_ring(tree.current_scene, point, color, radius, time)


static func dust(tree: SceneTree, point: Vector3, amount: int, size: float) -> void:
	if tree != null and tree.current_scene != null:
		_dust(tree.current_scene, point, amount, size, Vector3.ZERO)


static func _launch(scene: Node, particles: CPUParticles3D, point: Vector3) -> void:
	particles.one_shot = true
	particles.emitting = false
	particles.finished.connect(particles.queue_free)
	scene.add_child(particles)
	particles.global_position = point
	particles.emitting = true


# --- Shared resources (built once) ------------------------------------------------------------

static func _streak_mesh(length: float, width: float = 0.012, additive: bool = true) -> Mesh:
	var key := "streak_%.3f_%.3f_%s" % [length, width, additive]
	if not _cache.has(key):
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, length, width)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if additive:
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mesh.material = material
		_cache[key] = mesh
	return _cache[key]


static func _puff_material(additive: bool) -> Material:
	var key := "puff_add" if additive else "puff_mix"
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_texture = _soft()
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.billboard_keep_scale = true
		material.particles_anim_h_frames = 1
		material.particles_anim_v_frames = 1
		material.particles_anim_loop = false
		if additive:
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_cache[key] = material
	return _cache[key]


## A white disc that fades toward the edge (used for every puff).
static func _soft() -> Texture2D:
	if _soft_texture == null:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.0)])
		gradient.offsets = PackedFloat32Array([0.0, 1.0])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 64
		texture.height = 64
		_soft_texture = texture
	return _soft_texture


static func _ramp(colors: Array[Color]) -> Gradient:
	var gradient := Gradient.new()
	var count := colors.size()
	var packed_colors := PackedColorArray()
	var offsets := PackedFloat32Array()
	for i in count:
		packed_colors.append(colors[i])
		offsets.append(float(i) / float(maxi(count - 1, 1)))
	gradient.colors = packed_colors
	gradient.offsets = offsets
	return gradient


static func _curve(from_value: float, to_value: float) -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, from_value))
	curve.add_point(Vector2(1.0, to_value))
	return curve
