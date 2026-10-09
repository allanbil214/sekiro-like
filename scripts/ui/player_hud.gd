class_name PlayerHud
extends CanvasLayer
## The player's HUD (Step 10), drawn in code (no art files). Must be a direct child of Player.
## Bottom-left: the red health bar, the resurrection pips above it (pink; a used one is only a dim
## ring), and the healing gourd with its charge count below it (where Sekiro keeps its status icons;
## future status effects can line up to its right). Bottom-center: the posture bar, which grows from
## the middle out to both ends, yellow blending to reddish orange, pops to solid red with a flash at a
## posture break and then drains back (the same look as EnemyBar). The posture bar is hidden at 0.
## Everything is read from the Player every frame, and sized for a 1080 px high window and scaled with it.

@export_group("Layout")
## The window height (px) the sizes below are made for; the HUD scales with the real height.
@export var ui_reference_height: float = 1080.0
## Distance from the bottom-left corner to the HUD block (px).
@export var margin: Vector2 = Vector2(56.0, 48.0)
@export var health_bar_size: Vector2 = Vector2(440.0, 12.0)
@export var pip_radius: float = 10.0
@export var pip_gap: float = 8.0
## Space (px) between the pips and the bar, and between the bar and the gourd.
@export var pip_lift: float = 10.0
@export var gourd_gap: float = 14.0
@export var gourd_size: float = 34.0
@export var count_font_size: int = 26
@export var posture_bar_size: Vector2 = Vector2(520.0, 10.0)
@export var posture_bottom_margin: float = 72.0

@export_group("Health")
@export var health_color: Color = Color(0.78, 0.06, 0.06)
@export var back_color: Color = Color(0.04, 0.04, 0.04, 0.8)
@export var frame_color: Color = Color(0.55, 0.5, 0.45, 0.55)
## How fast the bar follows a heal (share of the bar per second); damage shows at once.
@export var health_rise_speed: float = 0.6

@export_group("Resurrection pips and gourd")
@export var pip_color: Color = Color(0.96, 0.45, 0.62)
@export var pip_ring_color: Color = Color(1.0, 0.8, 0.86)
@export var pip_used_color: Color = Color(0.45, 0.35, 0.4, 0.45)
@export var gourd_color: Color = Color(0.82, 0.66, 0.34)
@export var gourd_dark_color: Color = Color(0.35, 0.22, 0.1)
@export var count_color: Color = Color(1.0, 1.0, 1.0)

@export_group("Posture bar")
@export var posture_color_low: Color = Color(1.0, 0.85, 0.1)
@export var posture_color_high: Color = Color(1.0, 0.35, 0.05)
@export_range(0.2, 4.0) var posture_color_curve: float = 1.0
@export var posture_color_full: Color = Color(0.95, 0.04, 0.04)
@export var posture_flash_color: Color = Color(1.0, 0.85, 0.8)
@export var posture_flash_time: float = 0.35
@export var posture_drain_speed: float = 1.2
@export var posture_rise_speed: float = 8.0
@export var posture_back_color: Color = Color(0.04, 0.04, 0.04, 0.6)

var _player: Player
var _canvas: Control
var _time: float = 0.0
var _health_shown: float = 1.0
var _posture_shown: float = 0.0
var _posture_was_full: bool = false
var _flash_left: float = 0.0


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
	_time += delta
	var combatant := _player.combatant
	if combatant == null:
		return
	var health_fraction := combatant.health / maxf(combatant.max_health, 0.001)
	if health_fraction < _health_shown:
		_health_shown = health_fraction
	else:
		_health_shown = minf(_health_shown + health_rise_speed * delta, health_fraction)
	var target := clampf(combatant.posture / maxf(combatant.max_posture, 0.001), 0.0, 1.0)
	var full := combatant.posture_full
	if full and not _posture_was_full:
		_posture_shown = 1.0
		_flash_left = posture_flash_time
	_posture_was_full = full
	if _posture_shown < target:
		_posture_shown = minf(_posture_shown + posture_rise_speed * delta, target)
	elif _posture_shown > target and not full:
		_posture_shown = maxf(_posture_shown - posture_drain_speed * delta, target)
	if _flash_left > 0.0:
		_flash_left -= delta
	_canvas.queue_redraw()


func _draw_hud() -> void:
	if _player == null or _player.combatant == null:
		return
	var size := _canvas.size
	var s := size.y / maxf(ui_reference_height, 1.0)
	_draw_status(size, s)
	_draw_posture(size, s)


## Pips, health bar, and gourd, from the bottom-left corner upward.
func _draw_status(size: Vector2, s: float) -> void:
	var x0 := margin.x * s
	var gourd_px := gourd_size * s
	var gourd_top := size.y - margin.y * s - gourd_px
	var bar_w := health_bar_size.x * s
	var bar_h := health_bar_size.y * s
	var bar_y := gourd_top - gourd_gap * s - bar_h
	# Health bar: a dark back, the red fill, and a thin frame.
	var back := Rect2(x0 - 2.0 * s, bar_y - 2.0 * s, bar_w + 4.0 * s, bar_h + 4.0 * s)
	_canvas.draw_rect(back, back_color)
	_canvas.draw_rect(Rect2(x0, bar_y, bar_w * clampf(_health_shown, 0.0, 1.0), bar_h), health_color)
	_canvas.draw_rect(back, frame_color, false, maxf(1.0, s))
	# Resurrection pips above the bar's left end: pink while available, a dim ring once used.
	var radius := pip_radius * s
	var pip_y := bar_y - 2.0 * s - pip_lift * s - radius
	for i in _player.max_resurrections:
		var center := Vector2(x0 + radius + float(i) * (radius * 2.0 + pip_gap * s), pip_y)
		if i < _player.resurrections_left:
			_canvas.draw_circle(center, radius, pip_color)
			_canvas.draw_arc(center, radius, 0.0, TAU, 32, pip_ring_color, maxf(1.5, 2.0 * s), true)
		else:
			_canvas.draw_arc(center, radius, 0.0, TAU, 32, pip_used_color, maxf(1.5, 2.0 * s), true)
	# The gourd and its charge count, below the bar.
	var empty := _player.heal_charges <= 0
	var healing := _player.state_machine.current is HealState
	var alpha := 0.35 if empty else 1.0
	if healing:
		alpha = 0.65 + 0.35 * sin(_time * 14.0)
	var slot := Rect2(x0, gourd_top, gourd_px, gourd_px)
	_canvas.draw_rect(slot, Color(0.0, 0.0, 0.0, 0.45 * alpha))
	_canvas.draw_rect(slot, Color(frame_color.r, frame_color.g, frame_color.b, frame_color.a * alpha), false, maxf(1.0, s))
	var body_color := Color(gourd_color.r, gourd_color.g, gourd_color.b, alpha)
	var dark_color := Color(gourd_dark_color.r, gourd_dark_color.g, gourd_dark_color.b, alpha)
	var center_x := x0 + gourd_px * 0.5
	_canvas.draw_circle(Vector2(center_x, gourd_top + gourd_px * 0.66), gourd_px * 0.27, body_color)
	_canvas.draw_circle(Vector2(center_x, gourd_top + gourd_px * 0.36), gourd_px * 0.17, body_color)
	_canvas.draw_rect(Rect2(center_x - gourd_px * 0.05, gourd_top + gourd_px * 0.12, gourd_px * 0.1, gourd_px * 0.1), dark_color)
	_canvas.draw_line(Vector2(center_x - gourd_px * 0.14, gourd_top + gourd_px * 0.5),
			Vector2(center_x + gourd_px * 0.14, gourd_top + gourd_px * 0.5), dark_color, maxf(1.0, 1.5 * s))
	var font := ThemeDB.fallback_font
	var font_px := int(round(float(count_font_size) * s))
	var text_pos := Vector2(x0 + gourd_px + 12.0 * s, gourd_top + gourd_px * 0.5 + float(font_px) * 0.35)
	var text := str(_player.heal_charges)
	var text_color := Color(count_color.r, count_color.g, count_color.b, alpha)
	_canvas.draw_string(font, text_pos + Vector2(1.5, 1.5) * s, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px, Color(0.0, 0.0, 0.0, 0.8 * alpha))
	_canvas.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_px, text_color)


## The posture bar: bottom-center, growing from the middle out to both ends.
func _draw_posture(size: Vector2, s: float) -> void:
	if _posture_shown < 0.0005:
		return
	var width := posture_bar_size.x * s
	var height := posture_bar_size.y * s
	var center_x := size.x * 0.5
	var y := size.y - posture_bottom_margin * s - height
	_canvas.draw_rect(Rect2(center_x - width * 0.5 - 2.0 * s, y - 2.0 * s, width + 4.0 * s, height + 4.0 * s), posture_back_color)
	var color := EnemyBar.posture_gradient(_posture_shown, posture_color_low, posture_color_high, posture_color_curve)
	if _player.combatant.posture_full and _posture_shown >= 0.999:
		color = posture_color_full
		if _flash_left > 0.0 and int(_flash_left * 20.0) % 2 == 0:
			color = posture_flash_color
	var half := width * 0.5 * _posture_shown
	_canvas.draw_rect(Rect2(center_x - half, y, half * 2.0, height), color)
	# A thin tick at the middle, where it grows from.
	_canvas.draw_rect(Rect2(center_x - maxf(1.0, s), y - 3.0 * s, maxf(2.0, 2.0 * s), height + 6.0 * s), Color(1.0, 1.0, 1.0, 0.7))
