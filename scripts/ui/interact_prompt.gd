class_name InteractPrompt
extends CanvasLayer
## The interact prompt (Phase 2 item 8), drawn in code: "E: Open" near the lower middle of the screen while
## an interactable is picked, and a one-line text (an NPC's line, "It is empty.") that stays about
## `line_time` seconds. The key name is read from the Input Map, so a rebind shows correctly. Sits under
## the Player; the Player feeds it (`set_target`, `show_line`).

@export var ui_reference_height: float = 1080.0
@export var prompt_y: float = 0.68
@export var line_y: float = 0.82
@export var font_size: int = 30
@export var line_time: float = 2.5
@export var text_color: Color = Color(0.96, 0.96, 0.9)
@export var outline_color: Color = Color(0.03, 0.03, 0.03, 0.95)

var _canvas: Control
var _text: String = ""
var _line: String = ""
var _line_left: float = 0.0


func _ready() -> void:
	layer = 8
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_prompt)
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## `target` null hides the prompt.
func set_target(target: Interactable, player: Player) -> void:
	var text := ""
	if target != null:
		text = "%s: %s" % [_key_name(), target.get_prompt_text(player)]
	if text != _text:
		_text = text
		_canvas.queue_redraw()


func show_line(text: String) -> void:
	_line = text
	_line_left = line_time
	_canvas.queue_redraw()


func _process(delta: float) -> void:
	if _line_left > 0.0:
		_line_left -= delta
		if _line_left <= 0.0:
			_line = ""
			_canvas.queue_redraw()


func _key_name() -> String:
	for event in InputMap.action_get_events(Actions.INTERACT):
		if event is InputEventKey:
			var key := event as InputEventKey
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code)
	return "E"


func _draw_prompt() -> void:
	var size := _canvas.size
	var s := size.y / maxf(ui_reference_height, 1.0)
	var font := ThemeDB.fallback_font
	var px := int(font_size * s)
	_draw_centered(font, _text, Vector2(size.x * 0.5, size.y * prompt_y), px, s)
	_draw_centered(font, _line, Vector2(size.x * 0.5, size.y * line_y), px, s)


func _draw_centered(font: Font, text: String, center: Vector2, px: int, s: float) -> void:
	if text.is_empty():
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var pos := Vector2(center.x - width * 0.5, center.y)
	_canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(6 * s), outline_color)
	_canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, text_color)
