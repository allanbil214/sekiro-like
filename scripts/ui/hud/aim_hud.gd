class_name AimHud
extends CanvasLayer
## The crosshair while aiming a throwable (Phase 2 item 11b), drawn in code (no art files). Must be a direct
## child of Player. A straight flyer (shuriken, kunai) gets four ticks around a center dot; an item that arcs
## (rock, ceramic) gets a small ring, because its landing ring in the world (`AimPreview`) is the real marker.
## It fades in and out with the aim. Sized for a 1080 px high window and scaled with it.

@export var ui_reference_height: float = 1080.0
@export var color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var outline_color: Color = Color(0.03, 0.03, 0.03, 0.7)
## Crosshair ticks: the gap from the center, the tick length and the line width (px).
@export var tick_gap: float = 9.0
@export var tick_length: float = 12.0
@export var line_width: float = 2.0
@export var dot_radius: float = 2.5
@export var ring_radius: float = 7.0
## How fast the crosshair fades in and out (alpha per second).
@export var fade_speed: float = 12.0

var _player: Player
var _canvas: Control
var _alpha: float = 0.0
var _straight: bool = true


func _ready() -> void:
	layer = 10
	_player = get_parent() as Player
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var aiming := _player.state_machine.current is AimState
	if aiming:
		var item := _player.get_aim_item()
		_straight = item == null or item.gravity <= 0.0
	_alpha = move_toward(_alpha, 1.0 if aiming else 0.0, fade_speed * delta)
	_canvas.visible = _alpha > 0.0
	if _canvas.visible:
		_canvas.queue_redraw()


func _draw_hud() -> void:
	var size := _canvas.size
	var s := size.y / ui_reference_height
	var center := size * 0.5
	var tint := Color(color.r, color.g, color.b, color.a * _alpha)
	var shade := Color(outline_color.r, outline_color.g, outline_color.b, outline_color.a * _alpha)
	if _straight:
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var start := center + direction * tick_gap * s
			var end := center + direction * (tick_gap + tick_length) * s
			_canvas.draw_line(start, end, shade, (line_width + 2.0) * s)
			_canvas.draw_line(start, end, tint, line_width * s)
		_canvas.draw_circle(center, (dot_radius + 1.0) * s, shade)
		_canvas.draw_circle(center, dot_radius * s, tint)
	else:
		_canvas.draw_arc(center, ring_radius * s, 0.0, TAU, 32, shade, (line_width + 2.0) * s, true)
		_canvas.draw_arc(center, ring_radius * s, 0.0, TAU, 32, tint, line_width * s, true)
		_canvas.draw_circle(center, dot_radius * s, tint)
