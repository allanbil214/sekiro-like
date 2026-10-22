class_name ButtonPrompts
extends RefCounted
## Button prompts (Phase 2 item 16): how the HUD shows an input. One place turns an action into a glyph, in the
## style the player chose (Options > Gameplay > BUTTON PROMPTS: AUTO, KEYBOARD, XBOX, PLAYSTATION; AUTO follows
## the last device used and tells a PlayStation pad by its name). A glyph is a Dictionary {"kind", "text",
## "color", "arrow"} drawn in code (a key box, an Xbox letter, a PlayStation shape, a stick with an arrow), so
## there are no image files; the labels follow the Input Map, so a rebind shows correctly. Static, no node.

enum Style { AUTO, KEYBOARD, XBOX, PLAYSTATION }

const PAD_X: float = 12.0
const PAD_Y: float = 3.0
const FILL: Color = Color(0.05, 0.05, 0.06, 0.6)
const BORDER: Color = Color(0.96, 0.96, 0.9, 0.9)
const XBOX_GREEN: Color = Color(0.45, 0.82, 0.3)
const XBOX_RED: Color = Color(0.93, 0.3, 0.25)
const XBOX_BLUE: Color = Color(0.3, 0.58, 0.97)
const XBOX_YELLOW: Color = Color(0.97, 0.82, 0.2)
const PS_CROSS: Color = Color(0.55, 0.68, 0.97)
const PS_CIRCLE: Color = Color(0.97, 0.45, 0.5)
const PS_SQUARE: Color = Color(0.93, 0.58, 0.85)
const PS_TRIANGLE: Color = Color(0.42, 0.88, 0.72)
const PS_WORDS: Array[String] = ["playstation", "ps3", "ps4", "ps5", "dualshock", "dualsense", "sony"]

static var _using_pad: bool = false
static var _pad_device: int = 0
static var _box: StyleBoxFlat


## Remembers the last device used (call it from a node's `_input`).
static func note_event(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_using_pad = true
		_pad_device = (event as InputEventJoypadButton).device
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) > 0.5:
			_using_pad = true
			_pad_device = motion.device
	elif event is InputEventKey:
		if (event as InputEventKey).pressed:
			_using_pad = false
	elif event is InputEventMouseButton:
		_using_pad = false


## The style in use now (never AUTO).
static func style() -> Style:
	var chosen := clampi(Settings.button_prompts, 0, 3)
	if chosen != Style.AUTO:
		return chosen as Style
	if not _using_pad:
		return Style.KEYBOARD
	var joy := Input.get_joy_name(_pad_device).to_lower()
	for word in PS_WORDS:
		if joy.contains(word):
			return Style.PLAYSTATION
	return Style.XBOX


## The glyph for `action` in the current style (the keyboard one when no controller input is bound to it).
static func glyph_for(action: StringName) -> Dictionary:
	var current := style()
	if current != Style.KEYBOARD:
		var pad := _pad_glyph(action, current == Style.PLAYSTATION)
		if not pad.is_empty():
			return pad
	return _key_glyph(action)


## The glyph for pushing the stick or pressing the move key toward `direction` on the screen
## (0 up, 1 right, 2 down, 3 left).
static func move_glyph(direction: int) -> Dictionary:
	if style() == Style.KEYBOARD:
		var actions: Array[StringName] = [Actions.MOVE_FORWARD, Actions.MOVE_RIGHT, Actions.MOVE_BACK, Actions.MOVE_LEFT]
		return _key_glyph(actions[clampi(direction, 0, 3)])
	return {"kind": &"stick", "text": "L", "color": Color.WHITE, "arrow": clampi(direction, 0, 3)}


## Which way (0 up, 1 right, 2 down, 3 left) the world direction `toward` is on the screen, for a camera turned
## `camera_yaw` radians.
static func screen_direction(toward: Vector3, camera_yaw: float) -> int:
	var local := Basis(Vector3.UP, camera_yaw).inverse() * toward
	if absf(local.z) >= absf(local.x):
		return 0 if local.z < 0.0 else 2
	return 1 if local.x > 0.0 else 3


## A short text that changes when the glyph's look changes (to know when to redraw).
static func signature(glyph: Dictionary) -> String:
	return "%s|%s|%d" % [glyph["kind"], glyph["text"], int(glyph.get("arrow", -1))]


static func glyph_width(glyph: Dictionary, font: Font, px: int, s: float) -> float:
	var h := _height(font, px, s)
	match glyph["kind"]:
		&"key":
			return maxf(font.get_string_size(glyph["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + PAD_X * s * 2.0, h)
		&"stick":
			return h + (h * 0.55 if int(glyph.get("arrow", -1)) >= 0 else 0.0)
	return h


## Draws the glyph with its left edge at `x`, on the text baseline `baseline`.
static func draw_glyph(canvas: CanvasItem, glyph: Dictionary, x: float, baseline: float, font: Font, px: int, s: float,
		text_color: Color) -> void:
	var h := _height(font, px, s)
	var top := baseline - font.get_ascent(px) - PAD_Y * s
	var line := float(maxi(1, int(2.0 * s)))
	var kind: StringName = glyph["kind"]
	var text: String = glyph["text"]
	var color: Color = glyph["color"]
	if kind == &"key":
		if _box == null:
			_box = StyleBoxFlat.new()
			_box.bg_color = FILL
			_box.border_color = BORDER
			_box.set_corner_radius_all(6)
		_box.set_border_width_all(int(line))
		var w := glyph_width(glyph, font, px, s)
		canvas.draw_style_box(_box, Rect2(x, top, w, h))
		_draw_centered(canvas, text, x + w * 0.5, baseline, font, px, text_color)
		return
	var center := Vector2(x + h * 0.5, top + h * 0.5)
	var radius := h * 0.5
	canvas.draw_circle(center, radius, FILL)
	if kind == &"round":
		canvas.draw_arc(center, radius, 0.0, TAU, 32, color, line, true)
		_draw_centered(canvas, text, center.x, baseline, font, px, color)
	elif kind == &"shape":
		canvas.draw_arc(center, radius, 0.0, TAU, 32, BORDER, line, true)
		_draw_shape(canvas, text, center, radius * 0.5, color, line * 1.5)
	elif kind == &"stick":
		canvas.draw_arc(center, radius, 0.0, TAU, 32, BORDER, line, true)
		_draw_centered(canvas, text, center.x, baseline, font, px, text_color)
		var arrow := int(glyph.get("arrow", -1))
		if arrow >= 0:
			_draw_arrow(canvas, Vector2(x + h + h * 0.3, center.y), h * 0.22, arrow, text_color)


static func _height(font: Font, px: int, s: float) -> float:
	return font.get_height(px) + PAD_Y * s * 2.0


static func _draw_centered(canvas: CanvasItem, text: String, cx: float, baseline: float, font: Font, px: int,
		color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	canvas.draw_string(font, Vector2(cx - width * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


static func _draw_shape(canvas: CanvasItem, shape: String, center: Vector2, r: float, color: Color, width: float) -> void:
	match shape:
		"cross":
			canvas.draw_line(center + Vector2(-r, -r), center + Vector2(r, r), color, width, true)
			canvas.draw_line(center + Vector2(-r, r), center + Vector2(r, -r), color, width, true)
		"circle":
			canvas.draw_arc(center, r, 0.0, TAU, 24, color, width, true)
		"square":
			canvas.draw_rect(Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0), color, false, width)
		"triangle":
			var points := PackedVector2Array([center + Vector2(0.0, -r), center + Vector2(r, r * 0.8),
					center + Vector2(-r, r * 0.8), center + Vector2(0.0, -r)])
			canvas.draw_polyline(points, color, width, true)


static func _draw_arrow(canvas: CanvasItem, center: Vector2, r: float, direction: int, color: Color) -> void:
	var points: PackedVector2Array
	match direction:
		0: points = PackedVector2Array([center + Vector2(0.0, -r), center + Vector2(r, r), center + Vector2(-r, r)])
		1: points = PackedVector2Array([center + Vector2(r, 0.0), center + Vector2(-r, r), center + Vector2(-r, -r)])
		2: points = PackedVector2Array([center + Vector2(0.0, r), center + Vector2(-r, -r), center + Vector2(r, -r)])
		_: points = PackedVector2Array([center + Vector2(-r, 0.0), center + Vector2(r, -r), center + Vector2(r, r)])
	canvas.draw_colored_polygon(points, color)


static func _key_glyph(action: StringName) -> Dictionary:
	return {"kind": &"key", "text": InteractPrompt.key_name(action), "color": Color.WHITE, "arrow": -1}


static func _pad_glyph(action: StringName, playstation: bool) -> Dictionary:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			var glyph := _button_glyph((event as InputEventJoypadButton).button_index, playstation)
			if not glyph.is_empty():
				return glyph
		elif event is InputEventJoypadMotion:
			var axis := (event as InputEventJoypadMotion).axis
			if axis == JOY_AXIS_TRIGGER_LEFT:
				return _box_glyph("L2" if playstation else "LT")
			if axis == JOY_AXIS_TRIGGER_RIGHT:
				return _box_glyph("R2" if playstation else "RT")
			var left := axis == JOY_AXIS_LEFT_X or axis == JOY_AXIS_LEFT_Y
			return {"kind": &"stick", "text": "L" if left else "R", "color": Color.WHITE, "arrow": -1}
	return {}


static func _button_glyph(button: int, playstation: bool) -> Dictionary:
	match button:
		JOY_BUTTON_A:
			return _shape_glyph("cross", PS_CROSS) if playstation else _round_glyph("A", XBOX_GREEN)
		JOY_BUTTON_B:
			return _shape_glyph("circle", PS_CIRCLE) if playstation else _round_glyph("B", XBOX_RED)
		JOY_BUTTON_X:
			return _shape_glyph("square", PS_SQUARE) if playstation else _round_glyph("X", XBOX_BLUE)
		JOY_BUTTON_Y:
			return _shape_glyph("triangle", PS_TRIANGLE) if playstation else _round_glyph("Y", XBOX_YELLOW)
		JOY_BUTTON_LEFT_SHOULDER:
			return _box_glyph("L1" if playstation else "LB")
		JOY_BUTTON_RIGHT_SHOULDER:
			return _box_glyph("R1" if playstation else "RB")
		JOY_BUTTON_LEFT_STICK:
			return _box_glyph("L3")
		JOY_BUTTON_RIGHT_STICK:
			return _box_glyph("R3")
		JOY_BUTTON_START:
			return _box_glyph("Options" if playstation else "Menu")
		JOY_BUTTON_BACK:
			return _box_glyph("Share" if playstation else "View")
		JOY_BUTTON_DPAD_UP:
			return _box_glyph("D-Up")
		JOY_BUTTON_DPAD_DOWN:
			return _box_glyph("D-Down")
		JOY_BUTTON_DPAD_LEFT:
			return _box_glyph("D-Left")
		JOY_BUTTON_DPAD_RIGHT:
			return _box_glyph("D-Right")
	return {}


static func _box_glyph(text: String) -> Dictionary:
	return {"kind": &"key", "text": text, "color": Color.WHITE, "arrow": -1}


static func _round_glyph(text: String, color: Color) -> Dictionary:
	return {"kind": &"round", "text": text, "color": color, "arrow": -1}


static func _shape_glyph(shape: String, color: Color) -> Dictionary:
	return {"kind": &"shape", "text": shape, "color": color, "arrow": -1}
