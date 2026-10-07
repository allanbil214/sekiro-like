class_name EnemyBar
extends Node3D
## A floating, camera-facing health bar above an enemy, Sekiro style: damage cuts the red bar at
## once, and a yellow segment stays where the red was to show how much was just taken, then
## drains after a short delay. Damage numbers are a debug aid (Sekiro shows none): they appear at
## the top right of the bar. The posture bar will sit under it in Step 6.

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

var _back: MeshInstance3D
var _yellow: MeshInstance3D
var _red: MeshInstance3D
var _red_fraction: float = 1.0
var _yellow_fraction: float = 1.0
var _hold: float = 0.0


func _ready() -> void:
	_back = _make_quad(back_color, 0)
	_yellow = _make_quad(yellow_color, 1)
	_red = _make_quad(red_color, 2)
	var back_mesh := _back.mesh as QuadMesh
	back_mesh.size = Vector2(bar_width + 0.03, bar_height + 0.03)
	_set_fill(_yellow, 1.0)
	_set_fill(_red, 1.0)


## Follow a Combatant's health.
func bind(combatant: Combatant) -> void:
	combatant.health_changed.connect(_on_health_changed)
	combatant.damaged.connect(_on_damaged)
	_on_health_changed(combatant.max_health, combatant.max_health)


func _process(delta: float) -> void:
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
