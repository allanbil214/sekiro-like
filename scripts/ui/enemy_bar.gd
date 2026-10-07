class_name EnemyBar
extends Node3D
## A floating, camera-facing health bar above an enemy, Sekiro style: damage cuts the red bar at
## once, and a yellow segment stays where the red was to show how much was just taken, then
## drains after a short delay. Damage numbers are a debug aid (Sekiro shows none): they appear at
## the top right of the bar.
##
## Step 6: small pips at the top left show the health bars left (shown when there are 2 or more),
## and a posture bar sits under the health bar. It fills from both ends toward the middle: white,
## turning orange as it nears full, red while full (a posture break or an open deathblow window).
## While a deathblow window is open a big deathblow marker shows on the enemy's body: a white-reddish
## dot with a thick dark-red outline and a soft red glow, pulsing gently (the texture is drawn in code).

@export var bar_width: float = 1.2
@export var bar_height: float = 0.08
## Seconds the yellow segment stays before draining (restarts on every hit).
@export var yellow_delay: float = 1.0
## Yellow drain speed, as a fraction of the whole bar per second.
@export var yellow_drain_speed: float = 0.5
@export var show_damage_numbers: bool = true
@export var back_color: Color = Color(0.05, 0.05, 0.05, 0.85)
@export var red_color: Color = Color(0.75, 0.08, 0.08)
@export var yellow_color: Color = Color(0.95, 0.8, 0.15)
@export var posture_height: float = 0.05
@export var posture_gap: float = 0.04
@export var pip_size: float = 0.07
@export var pip_color: Color = Color(0.95, 0.95, 0.95)
@export var pip_lost_color: Color = Color(0.2, 0.2, 0.2, 0.8)
@export_group("Deathblow marker")
## Width (m) of the whole marker including the glow (the dot itself is about 55% of it).
@export var marker_size: float = 0.65
## Where the marker sits, relative to this bar (the default is about chest height).
@export var marker_offset: Vector3 = Vector3(0.0, -1.1, 0.0)
@export var marker_pulse: bool = true

var _back: MeshInstance3D
var _yellow: MeshInstance3D
var _red: MeshInstance3D
var _red_fraction: float = 1.0
var _yellow_fraction: float = 1.0
var _hold: float = 0.0
var _posture_back: MeshInstance3D
var _posture_left: MeshInstance3D
var _posture_right: MeshInstance3D
var _posture_fraction: float = 0.0
var _posture_full: bool = false
var _pips: Array[MeshInstance3D] = []
var _marker: Sprite3D
var _marker_time: float = 0.0

static var _marker_texture: ImageTexture


func _ready() -> void:
	_back = _make_quad(back_color, 0)
	_yellow = _make_quad(yellow_color, 1)
	_red = _make_quad(red_color, 2)
	var back_mesh := _back.mesh as QuadMesh
	back_mesh.size = Vector2(bar_width + 0.03, bar_height + 0.03)
	_set_fill(_yellow, 1.0)
	_set_fill(_red, 1.0)
	var posture_y := -(bar_height * 0.5 + posture_gap + posture_height * 0.5)
	_posture_back = _make_quad(back_color, 0)
	_posture_back.position.y = posture_y
	(_posture_back.mesh as QuadMesh).size = Vector2(bar_width + 0.03, posture_height + 0.03)
	_posture_left = _make_quad(Color.WHITE, 3)
	_posture_right = _make_quad(Color.WHITE, 3)
	_posture_left.position.y = posture_y
	_posture_right.position.y = posture_y
	_set_posture(0.0, false)
	_marker = Sprite3D.new()
	_marker.texture = _get_marker_texture()
	_marker.pixel_size = marker_size / float(_marker_texture.get_width())
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.shaded = false
	_marker.render_priority = 6
	_marker.position = marker_offset
	_marker.visible = false
	add_child(_marker)


## Follow a Combatant's health.
func bind(combatant: Combatant) -> void:
	combatant.health_changed.connect(_on_health_changed)
	combatant.damaged.connect(_on_damaged)
	combatant.posture_changed.connect(_on_posture_changed)
	combatant.bars_changed.connect(_on_bars_changed)
	combatant.deathblow_opened.connect(_on_deathblow_opened)
	combatant.deathblow_closed.connect(_on_deathblow_closed)
	_on_health_changed(combatant.health, combatant.max_health)
	_build_pips(combatant.health_bars)
	_on_bars_changed(combatant.bars_left, combatant.health_bars)
	_on_posture_changed(combatant.posture, combatant.max_posture)


func _process(delta: float) -> void:
	if _marker.visible and marker_pulse:
		_marker_time += delta
		var beat := 0.5 + 0.5 * sin(_marker_time * 9.0)
		_marker.scale = Vector3.ONE * lerpf(0.94, 1.08, beat)
		_marker.modulate.a = lerpf(0.85, 1.0, beat)
	if _hold > 0.0:
		_hold -= delta
	elif _yellow_fraction > _red_fraction:
		_yellow_fraction = maxf(_red_fraction, _yellow_fraction - yellow_drain_speed * delta)
	_set_fill(_yellow, _yellow_fraction)


func _on_health_changed(current: float, maximum: float) -> void:
	var fraction := current / maxf(maximum, 0.001)
	if fraction < _red_fraction:
		_hold = yellow_delay
	else:
		# Healed or reset: no yellow trail.
		_yellow_fraction = fraction
	_red_fraction = fraction
	_set_fill(_red, _red_fraction)


func _on_deathblow_opened() -> void:
	_marker_time = 0.0
	_marker.scale = Vector3.ONE
	_marker.modulate.a = 1.0
	_marker.visible = true


func _on_deathblow_closed(_executed: bool, _killed: bool) -> void:
	_marker.visible = false


## The marker image, built once: a red glow, a thick dark-red outline, and a white-reddish dot.
static func _get_marker_texture() -> ImageTexture:
	if _marker_texture != null:
		return _marker_texture
	var size := 256
	var half := float(size) * 0.5
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var dot_radius := 0.55
	var stroke := 0.13
	var fill_radius := dot_radius - stroke
	var edge := 1.5 / half
	var glow_color := Color(0.95, 0.1, 0.08)
	var stroke_color := Color(0.4, 0.02, 0.03)
	var center_color := Color(1.0, 0.96, 0.93)
	var rim_color := Color(1.0, 0.6, 0.55)
	for y in size:
		for x in size:
			var d := Vector2(float(x) + 0.5 - half, float(y) + 0.5 - half).length() / half
			var glow_fade := clampf(1.0 - maxf(d - dot_radius, 0.0) / (1.0 - dot_radius), 0.0, 1.0)
			var pixel := Color(glow_color.r, glow_color.g, glow_color.b, 0.55 * glow_fade * glow_fade)
			if d >= 1.0:
				pixel.a = 0.0
			pixel = _over(Color(stroke_color.r, stroke_color.g, stroke_color.b,
					1.0 - smoothstep(dot_radius - edge, dot_radius, d)), pixel)
			var fill := center_color.lerp(rim_color, clampf(d / fill_radius, 0.0, 1.0))
			pixel = _over(Color(fill.r, fill.g, fill.b,
					1.0 - smoothstep(fill_radius - edge, fill_radius, d)), pixel)
			image.set_pixel(x, y, pixel)
	_marker_texture = ImageTexture.create_from_image(image)
	return _marker_texture


## `top` drawn over `bottom` (straight alpha).
static func _over(top: Color, bottom: Color) -> Color:
	var alpha := top.a + bottom.a * (1.0 - top.a)
	if alpha <= 0.0:
		return Color(0.0, 0.0, 0.0, 0.0)
	var rgb := (Vector3(top.r, top.g, top.b) * top.a
			+ Vector3(bottom.r, bottom.g, bottom.b) * bottom.a * (1.0 - top.a)) / alpha
	return Color(rgb.x, rgb.y, rgb.z, alpha)


func _on_posture_changed(current: float, maximum: float) -> void:
	var fraction := current / maxf(maximum, 0.001)
	_set_posture(fraction, fraction >= 0.999)


func _on_bars_changed(left: int, _total: int) -> void:
	for i in _pips.size():
		var material := _pips[i].material_override as StandardMaterial3D
		material.albedo_color = pip_color if i < left else pip_lost_color


## One small pip per health bar, above the top left of the bar (only when there are 2 or more).
func _build_pips(total: int) -> void:
	for pip in _pips:
		pip.queue_free()
	_pips.clear()
	if total < 2:
		return
	for i in total:
		var pip := _make_quad(pip_color, 4)
		(pip.mesh as QuadMesh).size = Vector2(pip_size, pip_size)
		pip.position = Vector3(-bar_width * 0.5 + pip_size * 0.5 + float(i) * (pip_size + 0.03),
				bar_height * 0.5 + pip_size * 0.5 + 0.03, 0.0)
		_pips.append(pip)


## Fill the posture bar from both ends toward the middle.
func _set_posture(fraction: float, full: bool) -> void:
	_posture_fraction = clampf(fraction, 0.0, 1.0)
	_posture_full = full
	var color := Color.WHITE.lerp(Color(1.0, 0.55, 0.1), clampf(_posture_fraction / 0.8, 0.0, 1.0))
	if full:
		color = Color(0.9, 0.05, 0.05)
	var half_width := bar_width * 0.5 * _posture_fraction
	for side: float in [-1.0, 1.0]:
		var instance := _posture_left if side < 0.0 else _posture_right
		var quad := instance.mesh as QuadMesh
		quad.size = Vector2(maxf(half_width, 0.0001), posture_height)
		quad.center_offset = Vector3(side * (bar_width * 0.5 - half_width * 0.5), 0.0, 0.0)
		instance.visible = _posture_fraction > 0.0005
		(instance.material_override as StandardMaterial3D).albedo_color = color


func _on_damaged(_hit: HitData, amount: float) -> void:
	if show_damage_numbers and amount > 0.0:
		_spawn_number(amount)


## A flat quad that always faces the camera, drawn on top (the render priority orders the layers).
func _make_quad(color: Color, priority: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = QuadMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.render_priority = priority
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


## Fill the bar from the left edge to `fraction` of its width.
func _set_fill(instance: MeshInstance3D, fraction: float) -> void:
	var clamped := clampf(fraction, 0.0, 1.0)
	var fill_width := bar_width * clamped
	var quad := instance.mesh as QuadMesh
	quad.size = Vector2(maxf(fill_width, 0.0001), bar_height)
	quad.center_offset = Vector3(-bar_width * 0.5 + fill_width * 0.5, 0.0, 0.0)
	instance.visible = clamped > 0.0005


func _spawn_number(amount: float) -> void:
	var label := Label3D.new()
	label.text = str(roundi(amount))
	label.font_size = 48
	label.outline_size = 10
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.top_level = true
	var right := Vector3.RIGHT
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		right = camera.global_transform.basis.x
	var start := global_position + right * (bar_width * 0.5 + 0.1) \
			+ Vector3.UP * (0.12 + randf_range(-0.04, 0.04))
	label.position = start
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position:y", start.y + 0.4, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)
