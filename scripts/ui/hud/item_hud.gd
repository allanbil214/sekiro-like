class_name ItemHud
extends CanvasLayer
## The item slots (Phase 2 items 11 and 19), drawn in code (no art files). Must be a direct child of Player. A row
## at the bottom right that reads from left to right: the selected item in a big square (its placeholder icon and its
## count), then the next item and the one after it in smaller, fainter squares (the order `cycle_item` steps through).
## Up to three, never the same item twice. The big square stays in one place whatever the count (the row just ends
## sooner). When the selection changes the squares shift one place toward the big one like a conveyor: the old
## selected item fades out at the front (it slips left of the big square, it does not travel to the back), and a new
## square fades in at the back (also when the list wraps round with few items). The big square flashes, and the
## item's name fades in above it, stays a moment and fades out; the name is hidden the rest of the time. The icon
## dims at 0. Hidden when the player carries nothing. The gourd stays bottom left (`PlayerHud`). Everything is read
## from `Player.item_belt` every frame, and sized for a 1080 px high window and scaled with it.

## How many squares show at most (the selected one and the next ones).
const MAX_SHOWN: int = 3
## Slot numbers: -1 is the exit in front of the big square (invisible), 0 the selected item, 1 the next, 2 the one
## after, and 3 the entrance behind the last square (invisible).
const EXIT_SLOT: int = -1
const HIDDEN_SLOT: int = 3

@export_group("Layout")
## The window height (px) the sizes below are made for; the HUD scales with the real height.
@export var ui_reference_height: float = 1080.0
## Distance from the bottom-right corner to the end of the row (px).
@export var margin: Vector2 = Vector2(56.0, 48.0)
@export var slot_size: float = 72.0
## The size of the next square and of the one after it, as a share of `slot_size`.
@export_range(0.2, 1.0) var next_scale: float = 0.7
@export_range(0.2, 1.0) var after_next_scale: float = 0.5
## Space (px) between the squares.
@export var slot_gap: float = 10.0
@export var name_font_size: int = 22
@export var count_font_size: int = 24
## Space (px) between the big slot and its name.
@export var name_gap: float = 8.0

@export_group("Colors")
@export var back_color: Color = Color(0.04, 0.04, 0.04, 0.6)
@export var frame_color: Color = Color(0.55, 0.5, 0.45, 0.55)
@export var text_color: Color = Color(1.0, 1.0, 1.0)
@export var outline_color: Color = Color(0.03, 0.03, 0.03, 0.9)
## The icon's opacity when none are left.
@export_range(0.0, 1.0) var empty_alpha: float = 0.3
## How opaque the next square and the one after it are.
@export_range(0.0, 1.0) var next_alpha: float = 0.75
@export_range(0.0, 1.0) var after_next_alpha: float = 0.5
@export var flash_color: Color = Color(1.0, 1.0, 1.0)
@export var flash_time: float = 0.25

@export_group("Motion")
## Seconds the squares take to slide one place when the selection changes.
@export var slide_time: float = 0.15
## The name of the selected item: seconds to fade in, to stay, and to fade out after a change.
@export var name_fade_in: float = 0.12
@export var name_hold_time: float = 1.2
@export var name_fade_out: float = 0.35

var _player: Player
var _canvas: Control
var _last_item: ItemData
var _flash_left: float = 0.0
## Where each item is on its way: its slot number as a float (see the slot numbers above).
var _slots: Dictionary = {}
## Items that were selected and went round to the back: a copy fades out at the front while the item itself slides in
## at the back. Each is {"item": ItemData, "slot": float}.
var _ghosts: Array[Dictionary] = []
var _name_alpha: float = 0.0
var _name_hold_left: float = 0.0


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
				_name_hold_left = name_hold_time
			_last_item = item
		_update_slots(belt, delta)
	_flash_left = maxf(_flash_left - delta, 0.0)
	var name_goal := 1.0 if _name_hold_left > 0.0 else 0.0
	_name_hold_left = maxf(_name_hold_left - delta, 0.0)
	var fade_time := name_fade_in if name_goal > _name_alpha else name_fade_out
	_name_alpha = move_toward(_name_alpha, name_goal, delta / maxf(fade_time, 0.01))
	_canvas.queue_redraw()


## The selected item and the next ones, in the order the cycle button steps through them (no item twice).
func _shown_items(belt: ItemBelt) -> Array[ItemData]:
	var shown: Array[ItemData] = []
	var count := mini(MAX_SHOWN, belt.items.size())
	for i in count:
		shown.append(belt.items[posmod(belt.selected_index + i, belt.items.size())])
	return shown


## Moves every item's slot number toward where it belongs now (a new item starts there, no slide). An item that was
## shown and is not any more leaves through the front (or the back if it was far behind). An item that goes round to
## the back leaves a fading copy at the front and slides in at the back.
func _update_slots(belt: ItemBelt, delta: float) -> void:
	var shown := _shown_items(belt)
	var speed := 1.0 / maxf(slide_time, 0.01)
	for item: ItemData in belt.items:
		if not _slots.has(item):
			_slots[item] = float(shown.find(item)) if shown.has(item) else float(HIDDEN_SLOT)
			continue
		var slot := float(_slots[item])
		var goal: float
		if shown.has(item):
			goal = float(shown.find(item))
			if goal > slot + 0.5:
				if slot > float(EXIT_SLOT) + 0.1:
					_ghosts.append({"item": item, "slot": slot})
				slot = float(HIDDEN_SLOT)
		else:
			goal = float(EXIT_SLOT) if slot < 1.5 else float(HIDDEN_SLOT)
		_slots[item] = move_toward(slot, goal, speed * delta)
	for i in range(_ghosts.size() - 1, -1, -1):
		var ghost_slot := move_toward(float(_ghosts[i]["slot"]), float(EXIT_SLOT), speed * delta)
		_ghosts[i]["slot"] = ghost_slot
		if ghost_slot <= float(EXIT_SLOT) + 0.001:
			_ghosts.remove_at(i)


## The five places (exit, selected, next, after, entrance) as rectangles on the same bottom line. The row of three
## ends at the right margin, so the big square keeps its place whatever the count.
func _slot_rects(size: Vector2, s: float) -> Array[Rect2]:
	var big := slot_size * s
	var next_px := big * next_scale
	var after_px := big * after_next_scale
	var entrance_px := after_px * 0.7
	var gap := slot_gap * s
	var bottom := size.y - margin.y * s
	var row_left := size.x - margin.x * s - (big + gap + next_px + gap + after_px)
	var lefts: Array[float] = [row_left - big - gap, row_left, 0.0, 0.0, 0.0]
	lefts[2] = row_left + big + gap
	lefts[3] = lefts[2] + next_px + gap
	lefts[4] = lefts[3] + after_px + gap
	var sizes: Array[float] = [big, big, next_px, after_px, entrance_px]
	var rects: Array[Rect2] = []
	for i in lefts.size():
		rects.append(Rect2(lefts[i], bottom - sizes[i], sizes[i], sizes[i]))
	return rects


## Which two of the five places a float slot number lies between, and how far along (0 to 1).
func _span(slot: float) -> Vector2:
	var pos := clampf(slot, float(EXIT_SLOT), float(HIDDEN_SLOT)) - float(EXIT_SLOT)
	var index := mini(int(floor(pos)), 3)
	return Vector2(float(index), pos - float(index))


## The rectangle for a float slot number (between two places it is in between).
func _rect_at(rects: Array[Rect2], slot: float) -> Rect2:
	var span := _span(slot)
	var a := rects[int(span.x)]
	var b := rects[int(span.x) + 1]
	return Rect2(a.position.lerp(b.position, span.y), a.size.lerp(b.size, span.y))


## The opacity for a float slot number.
func _alpha_at(slot: float) -> float:
	var alphas: Array[float] = [0.0, 1.0, next_alpha, after_next_alpha, 0.0]
	var span := _span(slot)
	return lerpf(alphas[int(span.x)], alphas[int(span.x) + 1], span.y)


func _draw_hud() -> void:
	var belt := _player.item_belt
	if belt == null or belt.is_empty():
		return
	var size := _canvas.size
	var s := size.y / maxf(ui_reference_height, 1.0)
	var rects := _slot_rects(size, s)
	# The fading copies first, then the furthest squares, so the selected one is on top while they slide.
	for ghost in _ghosts:
		_draw_slot(belt, ghost["item"], float(ghost["slot"]), rects, s, false)
	var order: Array = belt.items.duplicate()
	order.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		return float(_slots.get(a, float(HIDDEN_SLOT))) > float(_slots.get(b, float(HIDDEN_SLOT))))
	for item: ItemData in order:
		_draw_slot(belt, item, float(_slots.get(item, float(HIDDEN_SLOT))), rects, s, true)
	# The selected item's name above the big square, left-aligned to its edge, only for a moment after a change.
	if _name_alpha > 0.01:
		var font := ThemeDB.fallback_font
		var big_rect := rects[1]
		var name_px := int(name_font_size * s)
		_draw_text(font, belt.selected().display_name, Vector2(big_rect.position.x, big_rect.position.y - name_gap * s), name_px, s, _name_alpha)


## One square: the back, the frame, the icon and the count, at a float slot number. Only the real selected item flashes.
func _draw_slot(belt: ItemBelt, item: ItemData, slot: float, rects: Array[Rect2], s: float, can_flash: bool) -> void:
	var shown_alpha := _alpha_at(slot)
	if shown_alpha <= 0.01:
		return
	var rect := _rect_at(rects, slot)
	var count := belt.count_of(item)
	_canvas.draw_rect(rect, Color(back_color, back_color.a * shown_alpha))
	_canvas.draw_rect(rect, Color(frame_color, frame_color.a * shown_alpha), false, maxf(1.0, 2.0 * s))
	var icon_alpha := shown_alpha * (1.0 if count > 0 else empty_alpha)
	_draw_icon(item, rect.get_center(), rect.size.x, icon_alpha)
	if can_flash and item == belt.selected() and _flash_left > 0.0:
		var flash := Color(flash_color.r, flash_color.g, flash_color.b, 0.5 * _flash_left / maxf(flash_time, 0.01))
		_canvas.draw_rect(rect, flash)
	# The count in the square's bottom right corner, smaller on the smaller squares.
	var font := ThemeDB.fallback_font
	var count_px := maxi(int(count_font_size * s * rect.size.x / (slot_size * s)), 9)
	var count_text := str(count)
	var count_width := font.get_string_size(count_text, HORIZONTAL_ALIGNMENT_LEFT, -1, count_px).x
	_draw_text(font, count_text, Vector2(rect.end.x - count_width - 5.0 * s, rect.end.y - 5.0 * s), count_px, s, shown_alpha)


func _draw_text(font: Font, text: String, pos: Vector2, px: int, s: float, alpha: float = 1.0) -> void:
	var outline := Color(outline_color, outline_color.a * alpha)
	var fill := Color(text_color, text_color.a * alpha)
	_canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, int(5.0 * s), outline)
	_canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, fill)


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
