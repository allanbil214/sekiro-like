class_name ItemHud
extends CanvasLayer
## The item slot (Phase 2 item 11), drawn in code (no art files). Must be a direct child of Player. Bottom right,
## where Sekiro keeps the prosthetic slot: a square with the selected item's placeholder icon, its name above it
## and its count in the corner. The icon dims at 0 and flashes briefly when the selection changes. Hidden when the
## player carries nothing. The gourd stays bottom left (`PlayerHud`). Everything is read from `Player.item_belt`
## every frame, and sized for a 1080 px high window and scaled with it.

@export_group("Layout")
## The window height (px) the sizes below are made for; the HUD scales with the real height.
@export var ui_reference_height: float = 1080.0
## Distance from the bottom-right corner to the slot (px).
@export var margin: Vector2 = Vector2(56.0, 48.0)
@export var slot_size: float = 72.0
@export var name_font_size: int = 22
@export var count_font_size: int = 24
## Space (px) between the slot and its name.
@export var name_gap: float = 8.0

@export_group("Colors")
@export var back_color: Color = Color(0.04, 0.04, 0.04, 0.6)
@export var frame_color: Color = Color(0.55, 0.5, 0.45, 0.55)
@export var text_color: Color = Color(1.0, 1.0, 1.0)
@export var outline_color: Color = Color(0.03, 0.03, 0.03, 0.9)
## The icon's opacity when none are left.
@export_range(0.0, 1.0) var empty_alpha: float = 0.3
@export var flash_color: Color = Color(1.0, 1.0, 1.0)
@export var flash_time: float = 0.25

var _player: Player
var _canvas: Control
var _last_item: ItemData
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
	var belt := _player.item_belt
	if belt != null:
		var item := belt.selected()
		if item != _last_item:
			if _last_item != null:
				_flash_left = flash_time
			_last_item = item
	_flash_left = maxf(_flash_left - delta, 0.0)
	_canvas.queue_redraw()


func _draw_hud() -> void:
	var belt := _player.item_belt
	if belt == null or belt.is_empty():
		return
	var item := belt.selected()
	var count := belt.selected_count()
	var size := _canvas.size
	var s := size.y / maxf(ui_reference_height, 1.0)
	var slot_px := slot_size * s
	var slot := Rect2(size.x - margin.x * s - slot_px, size.y - margin.y * s - slot_px, slot_px, slot_px)
	_canvas.draw_rect(slot, back_color)
	_canvas.draw_rect(slot, frame_color, false, maxf(1.0, 2.0 * s))
	var alpha := 1.0 if count > 0 else empty_alpha
	_draw_icon(item, slot.get_center(), slot_px, alpha)
	if _flash_left > 0.0:
		var flash := Color(flash_color.r, flash_color.g, flash_color.b, 0.5 * _flash_left / maxf(flash_time, 0.01))
		_canvas.draw_rect(slot, flash)
	var font := ThemeDB.fallback_font
	# The name above the slot, right-aligned to its edge.
	var name_px := int(name_font_size * s)
	var name_width := font.get_string_size(item.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_px).x
	_draw_text(font, item.display_name, Vector2(slot.end.x - name_width, slot.position.y - name_gap * s), name_px, s)
	# The count in the slot's bottom right corner.
	var count_px := int(count_font_size * s)
	var count_text := str(count)
	var count_width := font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, count_px).x
	_draw_text(font, count_text, Vector2(slot.end.x - count_width - 5.0 * s, slot.end.y - 5.0 * s), count_px, s)


func _draw_text(font: Font, text: String, pos: Vector2, px: int, s: float) -> void:
	_canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(5.0 * s), outline_color)
	_canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, text_color)


## The placeholder icon: a simple shape in the item's color, centered in the slot.
func _draw_icon(item: ItemData, center: Vector2, slot_px: float, alpha: float) -> void:
	var color := Color(item.icon_color.r, item.icon_color.g, item.icon_color.b, alpha)
	match item.shape:
		ItemData.Shape.STAR:
			var points := PackedVector2Array()
			for i in 8:
				var radius := slot_px * (0.36 if i % 2 == 0 else 0.13)
				var angle := float(i) * PI * 0.25 - PI * 0.5
				points.append(center + Vector2(cos(angle), sin(angle)) * radius)
			_canvas.draw_colored_polygon(points, color)
		ItemData.Shape.DART:
			var points := PackedVector2Array([
				center + Vector2(0.0, -0.4) * slot_px, center + Vector2(0.09, -0.06) * slot_px,
				center + Vector2(0.0, 0.4) * slot_px, center + Vector2(-0.09, -0.06) * slot_px])
			_canvas.draw_colored_polygon(points, color)
		ItemData.Shape.SHARD:
			var points := PackedVector2Array([
				center + Vector2(0.0, -0.34) * slot_px, center + Vector2(0.3, 0.28) * slot_px,
				center + Vector2(-0.28, 0.2) * slot_px])
			_canvas.draw_colored_polygon(points, color)
		_:
			_canvas.draw_circle(center, slot_px * 0.26, color)
