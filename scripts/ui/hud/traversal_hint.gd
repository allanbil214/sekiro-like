class_name TraversalHint
extends CanvasLayer
## Traversal hints (Phase 2 item 16): a compact row along the bottom of the screen that shows what the current
## movement state can do, as "[button] : Verb" (a ledge hang: Climb, Leap, Drop down; a wall hug: Leave, ...).
## Drawn in code like `InteractPrompt`; the glyphs come from `ButtonPrompts` (keyboard, Xbox or PlayStation, from
## the Options setting), so a rebind shows correctly. The row fades in and out. The Player feeds it every frame
## (`set_hints`) from `State.get_hints()`; the Options toggle `Settings.traversal_hints` turns it off.
## A hint may carry "move_dir" (0 up, 1 right, 2 down, 3 left): then the move key or stick is shown first
## ("[W] + [Space] : Vault"). Sits under the Player.

@export var ui_reference_height: float = 1080.0
## Where the baseline of the row is, as a share of the screen height.
@export var row_y: float = 0.93
@export var font_size: int = 28
## The space (px at 1080p) between two hints.
@export var gap: float = 48.0
## The space (px at 1080p) between a glyph, the colon, the plus and the verb.
@export var inner_gap: float = 10.0
## Seconds to fade in and out.
@export var fade_in_time: float = 0.15
@export var fade_out_time: float = 0.25
@export var text_color: Color = Color(0.96, 0.96, 0.9)
@export var outline_color: Color = Color(0.03, 0.03, 0.03, 0.95)

var _canvas: Control
## What is drawn: one entry per hint, {"glyphs": Array of glyphs, "text": String}.
var _entries: Array[Dictionary] = []
var _signature: String = ""
var _alpha: float = 0.0
var _target: float = 0.0


func _ready() -> void:
	layer = 8
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_row)
	_canvas.modulate.a = 0.0
	add_child(_canvas)
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _input(event: InputEvent) -> void:
	ButtonPrompts.note_event(event)


## `hints` is a list of {"action": StringName, "text": String, optional "move_dir": int}; an empty list fades the
## row out (it keeps showing the last hints while it fades).
func set_hints(hints: Array[Dictionary]) -> void:
	if hints.is_empty():
		_target = 0.0
		return
	_target = 1.0
	var entries: Array[Dictionary] = []
	var signature := ""
	for hint in hints:
		var glyphs: Array[Dictionary] = []
		if hint.has("move_dir"):
			glyphs.append(ButtonPrompts.move_glyph(int(hint["move_dir"])))
		glyphs.append(ButtonPrompts.glyph_for(hint["action"]))
		for glyph in glyphs:
			signature += ButtonPrompts.signature(glyph) + ","
		signature += str(hint["text"]) + ";"
		entries.append({"glyphs": glyphs, "text": str(hint["text"])})
	if signature == _signature:
		return
	_signature = signature
	_entries = entries
	_canvas.queue_redraw()


func _process(delta: float) -> void:
	var time := fade_in_time if _target > _alpha else fade_out_time
	_alpha = move_toward(_alpha, _target, delta / maxf(time, 0.01))
	_canvas.modulate.a = _alpha
	if _alpha <= 0.0 and _target <= 0.0 and not _entries.is_empty():
		_entries.clear()
		_signature = ""
		_canvas.queue_redraw()


func _draw_row() -> void:
	if _entries.is_empty():
		return
	var size := _canvas.size
	var s := size.y / maxf(ui_reference_height, 1.0)
	var font := ThemeDB.fallback_font
	var px := int(font_size * s)
	var inner := inner_gap * s
	var colon_w := font.get_string_size(":", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var plus_w := font.get_string_size("+", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var widths := PackedFloat32Array()
	var total := 0.0
	for entry in _entries:
		var w := 0.0
		var glyphs: Array = entry["glyphs"]
		for i in glyphs.size():
			w += ButtonPrompts.glyph_width(glyphs[i], font, px, s)
			if i < glyphs.size() - 1:
				w += inner + plus_w + inner
		w += inner + colon_w + inner + font.get_string_size(entry["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		widths.append(w)
		total += w
	total += gap * s * float(_entries.size() - 1)
	var x := size.x * 0.5 - total * 0.5
	var baseline := size.y * row_y
	for e in _entries.size():
		var entry: Dictionary = _entries[e]
		var cx := x
		var glyphs: Array = entry["glyphs"]
		for i in glyphs.size():
			ButtonPrompts.draw_glyph(_canvas, glyphs[i], cx, baseline, font, px, s, text_color)
			cx += ButtonPrompts.glyph_width(glyphs[i], font, px, s)
			if i < glyphs.size() - 1:
				_draw_text(font, "+", Vector2(cx + inner, baseline), px, s)
				cx += inner + plus_w + inner
		_draw_text(font, ":", Vector2(cx + inner, baseline), px, s)
		_draw_text(font, entry["text"], Vector2(cx + inner + colon_w + inner, baseline), px, s)
		x += widths[e] + gap * s


func _draw_text(font: Font, text: String, pos: Vector2, px: int, s: float) -> void:
	_canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(6 * s), outline_color)
	_canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, text_color)
