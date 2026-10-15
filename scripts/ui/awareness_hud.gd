class_name AwarenessHud
extends CanvasLayer
## The awareness indicator (Phase 2, item 7a), drawn in code (no art files). Player creates it as its child.
## For every enemy that is noticing the player (an `Enemy` with `use_awareness` and a meter above 0, not yet in
## combat) it draws a plain triangle on an invisible ring around the screen center, its tip pointing toward the
## enemy (relative to where the camera looks: straight ahead is the top, behind you the bottom). The triangle
## fills from its base as the enemy's meter rises, going from whitish through yellowish to red, and drains if
## the enemy loses interest. When the enemy spots the player the triangle pops ("bwah!": it punches up in size
## and flashes red) and vanishes, and it stays gone for the fight (the 3D "?" and "!" over the enemy's head are
## separate). At most `max_marks` triangles, the nearest enemies first. Sized for a 1080 px high window and
## scaled with it. It reads `Enemy.get_awareness_info()` through `Enemies.all()`.

@export_group("Layout (at a 1080 px high window)")
@export var ui_reference_height: float = 1080.0
## Distance from the screen center to the middle of a triangle (px).
@export var ring_radius: float = 190.0
## The triangle's base width (px) and the outline widths (dark outer, light inner).
@export var triangle_size: float = 46.0
@export var outline_width: float = 6.0
@export var inner_outline_width: float = 2.0
@export var max_marks: int = 6

@export_group("Look")
@export var color_low: Color = Color(0.96, 0.96, 0.9)
@export var color_mid: Color = Color(1.0, 0.85, 0.2)
@export var color_high: Color = Color(0.95, 0.1, 0.08)
@export var back_color: Color = Color(0.0, 0.0, 0.0, 0.4)
@export var outline_color: Color = Color(0.03, 0.03, 0.03, 0.95)
@export var inner_outline_color: Color = Color(1.0, 1.0, 1.0, 0.8)
## How fast (fill per second) the shown fill follows the enemy's meter.
@export var fill_follow_speed: float = 6.0
## The wavy top of the fill: height as a fraction of the triangle, and speed.
@export var wave_amount: float = 0.06
@export var wave_speed: float = 6.0

@export_group("Pop")
## Seconds the pop takes (grow, flash red, fade out), and how much bigger it gets (0.9 = +90 percent).
@export var pop_time: float = 0.4
@export var pop_scale: float = 0.9

class Mark extends RefCounted:
	var fill: float = 0.0
	var target: float = 0.0
	var pop_t: float = -1.0
	var angle: float = 0.0
	var distance: float = 0.0

var _canvas: Control
var _marks: Dictionary = {}
var _stamps: Dictionary = {}
var _player: Player


func _ready() -> void:
	layer = 8
	_player = get_parent() as Player
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_update_marks(delta)
	_canvas.queue_redraw()


func _update_marks(delta: float) -> void:
	var seen: Dictionary = {}
	var camera := get_viewport().get_camera_3d()
	var forward := Vector3.ZERO
	if camera != null:
		forward = -camera.global_transform.basis.z
		forward.y = 0.0
	for node: Node3D in Enemies.all():
		var enemy := node as Enemy
		if enemy == null or not enemy.use_awareness:
			continue
		var info := enemy.get_awareness_info()
		if info.is_empty():
			continue
		var id := enemy.get_instance_id()
		var mark: Mark = _marks.get(id)
		var meter: float = info["meter"]
		var combat: bool = info["combat"]
		var stamp: int = info["stamp"]
		if stamp != int(_stamps.get(id, 0)):
			# It just spotted the player (or was hit): the pop, even if no triangle was showing yet.
			_stamps[id] = stamp
			if mark == null:
				mark = Mark.new()
				_marks[id] = mark
			mark.fill = 1.0
			mark.pop_t = 0.0
		elif mark == null and meter > 0.02 and not combat:
			mark = Mark.new()
			_marks[id] = mark
		if mark == null:
			continue
		mark.target = 0.0 if combat else meter
		seen[id] = true
		if _player != null:
			var to_enemy := enemy.global_position - _player.global_position
			to_enemy.y = 0.0
			mark.distance = to_enemy.length()
			if forward.length_squared() > 0.0001 and to_enemy.length_squared() > 0.0001:
				# Clockwise from the top of the screen.
				mark.angle = -forward.normalized().signed_angle_to(to_enemy.normalized(), Vector3.UP)
	for id: int in _marks.keys():
		var mark: Mark = _marks[id]
		if not seen.has(id):
			_marks.erase(id)
			continue
		if mark.pop_t >= 0.0:
			mark.pop_t += delta / maxf(pop_time, 0.01)
			mark.fill = 1.0
			if mark.pop_t >= 1.0:
				_marks.erase(id)
		else:
			mark.fill = move_toward(mark.fill, mark.target, fill_follow_speed * delta)
			if mark.fill <= 0.005 and mark.target <= 0.005:
				_marks.erase(id)


func _draw_hud() -> void:
	if _marks.is_empty():
		return
	var size := _canvas.size
	var s := size.y / maxf(ui_reference_height, 1.0)
	var list: Array[Mark] = []
	for mark: Mark in _marks.values():
		list.append(mark)
	list.sort_custom(func(a: Mark, b: Mark) -> bool: return a.distance < b.distance)
	var shown := mini(list.size(), max_marks)
	for i in range(shown):
		_draw_mark(list[i], size * 0.5, s)


func _meter_color(value: float) -> Color:
	if value < 0.5:
		return color_low.lerp(color_mid, value / 0.5)
	return color_mid.lerp(color_high, (value - 0.5) / 0.5)


func _draw_mark(mark: Mark, center: Vector2, s: float) -> void:
	var direction := Vector2(sin(mark.angle), -cos(mark.angle))
	var side := Vector2(-direction.y, direction.x)
	var grow := 1.0
	var alpha := 1.0
	var fill_color := _meter_color(mark.fill)
	if mark.pop_t >= 0.0:
		var t := clampf(mark.pop_t, 0.0, 1.0)
		# Punch up fast, ease back a little, fade out in the second half; white flashes to red at the start.
		grow = 1.0 + pop_scale * sin(minf(t / 0.35, 1.0) * PI * 0.5) * (1.0 - 0.25 * t)
		alpha = 1.0 - clampf((t - 0.5) / 0.5, 0.0, 1.0)
		fill_color = Color.WHITE.lerp(color_high, clampf(t / 0.15, 0.0, 1.0))
	var base := triangle_size * s * grow
	var height := base * 0.866
	var middle := center + direction * ring_radius * s
	var apex := middle + direction * (height * 2.0 / 3.0)
	var base_middle := middle - direction * (height / 3.0)
	var left := base_middle + side * (base * 0.5)
	var right := base_middle - side * (base * 0.5)
	_canvas.draw_colored_polygon(PackedVector2Array([apex, right, left]), Color(back_color, back_color.a * alpha))
	var fill := clampf(mark.fill, 0.0, 1.0)
	if fill > 0.02:
		var edge_left := left.lerp(apex, fill)
		var edge_right := right.lerp(apex, fill)
		var points := PackedVector2Array([left, right])
		var amplitude := wave_amount * height * clampf(minf(fill, 1.0 - fill) * 4.0, 0.0, 1.0)
		var clock := float(Time.get_ticks_msec()) / 1000.0
		var steps := 6
		for i in range(steps + 1):
			var p := float(i) / float(steps)
			var wave := sin(clock * wave_speed + p * TAU * 1.5) * amplitude * sin(p * PI)
			points.append(edge_right.lerp(edge_left, p) + direction * wave)
		_canvas.draw_colored_polygon(points, Color(fill_color, alpha))
	var outline := PackedVector2Array([apex, left, right, apex])
	_canvas.draw_polyline(outline, Color(outline_color, outline_color.a * alpha), outline_width * s, true)
	_canvas.draw_polyline(outline, Color(inner_outline_color, inner_outline_color.a * alpha), inner_outline_width * s, true)
