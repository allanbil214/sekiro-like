class_name FeelOverlay
extends CanvasLayer
## Phase 3a: a timeline of the action that is running, top left, to tune feel by eye. F2 shows or hides it (debug
## builds only, the editor counts as one). Must be a direct child of Player.
## 3b-1: an INPUT row (the red stretch = presses are discarded until `input_from`; letters A D J G M I = the earliest
## attack, dodge, jump, guard, movement and item cancel), the header shows "ER FEEL: ON/OFF", and a small "ER FEEL OFF"
## tag stays on screen in debug builds while the debug-menu switch is off, even when the timeline is hidden.
## One block for the player's action and one for the locked-on enemy (else the nearest enemy that is
## attacking). Rows: LOCK, CANCEL, BUFFER, HIT, IFRAMES, MOVE; a row label turns bright while its window is
## open, and a white line is the action clock. An empty cancel window is drawn from `locked_until` to the end
## and an empty buffer window as the whole action, as the code reads them. Nothing here changes gameplay.

const FONT_SIZE: int = 14
const LABEL_W: float = 70.0
const BAR_W: float = 440.0
const ROW_H: float = 11.0
const ROW_GAP: float = 2.0
const ROW_COUNT: int = 7
const BLOCK_GAP: float = 10.0

const COLOR_LOCK := Color(0.85, 0.3, 0.3)
const COLOR_CANCEL := Color(0.3, 0.8, 0.4)
const COLOR_BUFFER := Color(0.9, 0.8, 0.3)
const COLOR_HIT := Color(1.0, 0.5, 0.1)
const COLOR_IFRAMES := Color(0.3, 0.7, 1.0)
const COLOR_MOVE := Color(0.7, 0.5, 0.95)
const COLOR_INPUT := Color(0.9, 0.4, 0.4)
const INPUT_ROW: int = 6
const INPUT_LETTERS: Array[String] = ["A", "D", "J", "G", "M", "I"]
const COLOR_WARN := Color(1.0, 0.35, 0.35)
const COLOR_PLACEHOLDER := Color(1.0, 0.85, 0.3)
const NO_SPAN := Vector2(-1.0, -1.0)

## Top-left corner of the panel, in pixels. The blocks stack downward from here.
@export var panel_origin: Vector2 = Vector2(16.0, 16.0)

var _player: Player
var _canvas: Control
var _font: Font
## True while the timeline is shown (F2 or the debug menu). The layer itself always stays visible for the tag.
var _shown: bool = false
## Whether the "ER FEEL OFF" tag was drawn last frame, so a change redraws even while the timeline is hidden.
var _tag_drawn: bool = false
## Validator results per action, so the check does not run every frame.
var _warnings: Dictionary = {}


func _ready() -> void:
	_player = get_parent() as Player
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_panel)
	add_child(_canvas)
	if OS.is_debug_build():
		ActionValidator.scan_once()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F2 and OS.is_debug_build():
		set_shown(not _shown)
		get_viewport().set_input_as_handled()


## Show or hide the timeline (the F2 key and the debug menu both use this).
func set_shown(shown: bool) -> void:
	_shown = shown
	_canvas.queue_redraw()


func is_shown() -> bool:
	return _shown


## True in a debug build while the debug-menu switch for the Elden Ring-like test values is off.
func _tag_wanted() -> bool:
	return OS.is_debug_build() and not ActionData.er_feel_enabled


func _process(_delta: float) -> void:
	var tag := _tag_wanted()
	if _shown or tag != _tag_drawn:
		_tag_drawn = tag
		_canvas.queue_redraw()


func _draw_panel() -> void:
	if _tag_wanted():
		var text := "ER FEEL OFF"
		var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var tag_pos := Vector2((_canvas.size.x - width) * 0.5, 8.0)
		_canvas.draw_rect(Rect2(tag_pos - Vector2(6, 2), Vector2(width + 12, FONT_SIZE + 8)), Color(0, 0, 0, 0.55))
		_text(tag_pos, text, COLOR_WARN)
	if not _shown:
		return
	var blocks: Array = []
	var action_state := _player.state_machine.current as ActionState
	if action_state != null and action_state.action != null:
		blocks.append(["PLAYER", action_state.action, action_state.action_time, ""])
	else:
		blocks.append(["PLAYER", null, 0.0, "state: %s (no action running)" % _player.state_machine.get_current_name()])
	var enemy := _find_enemy()
	if enemy != null:
		var enemy_action := enemy.get_feel_action()
		var title := "ENEMY (locked)" if _player.lock_on.target == enemy else "ENEMY (nearest attacking)"
		if enemy_action != null:
			blocks.append([title, enemy_action, enemy.get_feel_time(), ""])
		else:
			blocks.append([title, null, 0.0, "phase: %s (not attacking)" % Enemy.Phase.keys()[enemy.phase]])
	var y := panel_origin.y
	for block: Array in blocks:
		y += _draw_block(Vector2(panel_origin.x, y), block[0], block[1], block[2], block[3]) + BLOCK_GAP


func _block_height(action: ActionData) -> float:
	var header := FONT_SIZE + 8.0
	if action == null:
		return header
	var warn_lines := 1.0 if not _warnings_for(action).is_empty() else 0.0
	return header + ROW_COUNT * (ROW_H + ROW_GAP) + warn_lines * (FONT_SIZE + 4.0) + 4.0


## Draws one timeline and returns its height.
func _draw_block(origin: Vector2, title: String, action: ActionData, time: float, note: String) -> float:
	var height := _block_height(action)
	var panel := Rect2(origin - Vector2(6, 4), Vector2(LABEL_W + BAR_W + 16, height + 4))
	_canvas.draw_rect(panel, Color(0, 0, 0, 0.55))
	if action == null:
		_text(origin, "%s   %s" % [title, note], Color.WHITE)
		return height
	var action_name := action.resource_path.get_file().get_basename()
	if action_name.is_empty():
		action_name = str(action.animation)
	var kind_name: String = ActionData.Kind.keys()[action.kind]
	var head := "%s   %s (%s)   %.2f / %.2f s" % [title, action_name, kind_name, time, action.duration]
	_text(origin, head, Color.WHITE)
	if title == "PLAYER":
		var feel_text := "ER FEEL: %s" % ("ON" if ActionData.er_feel_enabled else "OFF")
		var feel_width := _font.get_string_size(feel_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		_text(origin + Vector2(LABEL_W + BAR_W - feel_width, 0),
				feel_text, COLOR_PLACEHOLDER if ActionData.er_feel_enabled else COLOR_WARN)
	if action.placeholder_source != ActionData.PlaceholderSource.NONE:
		var tag := "  PLACEHOLDER(%s)" % _source_label(action.placeholder_source)
		var head_width := _font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		_text(origin + Vector2(head_width, 0), tag, COLOR_PLACEHOLDER)
	var top := origin.y + FONT_SIZE + 8.0
	var bar_x := origin.x + LABEL_W
	var duration := maxf(action.duration, 0.001)
	var locked := Vector2(0.0, action.locked_until) if action.locked_until > 0.0 else NO_SPAN
	var cancel := NO_SPAN
	if action.cancel_window != Vector2.ZERO:
		cancel = Vector2(maxf(action.cancel_window.x, action.locked_until), action.cancel_window.y)
	else:
		cancel = Vector2(action.locked_until, action.duration)
	var buffer := action.buffer_window if action.buffer_window != Vector2.ZERO else Vector2(0.0, action.duration)
	var rows: Array = [
		["LOCK", locked, COLOR_LOCK],
		["CANCEL", cancel, COLOR_CANCEL],
		["BUFFER", buffer, COLOR_BUFFER],
		["HIT", _window_or_none(action.active_hit), COLOR_HIT],
		["IFRAMES", _window_or_none(action.iframes), COLOR_IFRAMES],
		["MOVE", _window_or_none(action.move_window), COLOR_MOVE],
		["INPUT", _input_zone(action), COLOR_INPUT],
	]
	for i in rows.size():
		var row: Array = rows[i]
		var span: Vector2 = row[1]
		var row_y := top + i * (ROW_H + ROW_GAP)
		_canvas.draw_rect(Rect2(bar_x, row_y, BAR_W, ROW_H), Color(1, 1, 1, 0.08))
		var open := span != NO_SPAN and time >= span.x and time < span.y
		if span != NO_SPAN and span.y > span.x:
			var x0 := bar_x + clampf(span.x / duration, 0.0, 1.0) * BAR_W
			var x1 := bar_x + clampf(span.y / duration, 0.0, 1.0) * BAR_W
			var color: Color = row[2]
			color.a = 0.95 if open else 0.55
			_canvas.draw_rect(Rect2(x0, row_y, maxf(x1 - x0, 1.0), ROW_H), color)
		_canvas.draw_string(_font, Vector2(origin.x, row_y + ROW_H), row[0],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE if open else Color(1, 1, 1, 0.45))
		if i == INPUT_ROW:
			_draw_cancel_ticks(action, time, bar_x, row_y, duration)
	var line_x := bar_x + clampf(time / duration, 0.0, 1.0) * BAR_W
	_canvas.draw_line(Vector2(line_x, top - 2.0), Vector2(line_x, top + ROW_COUNT * (ROW_H + ROW_GAP)), Color.WHITE, 2.0)
	var found := _warnings_for(action)
	if not found.is_empty():
		var warn_y := top + ROW_COUNT * (ROW_H + ROW_GAP) + 2.0
		_text(Vector2(origin.x, warn_y), "! %d validator warning(s): %s" % [found.size(), found[0]], COLOR_WARN)
	return height


func _text(pos: Vector2, text: String, color: Color) -> void:
	_canvas.draw_string(_font, pos + Vector2(0, FONT_SIZE), text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


## The stretch where presses are discarded (0 to `input_from`), or NO_SPAN when the field is not set or off.
func _input_zone(action: ActionData) -> Vector2:
	var from := action.feel_input_from()
	return Vector2(0.0, from) if from > 0.0 else NO_SPAN


## A tick and a letter (A D J G M I) at each set per-input cancel time; the letter is bright once the time is reached.
func _draw_cancel_ticks(action: ActionData, time: float, bar_x: float, row_y: float, duration: float) -> void:
	var next_free := 0.0
	for index in INPUT_LETTERS.size():
		var at := action.feel_cancel_time(index as ActionData.FeelInput)
		if at < 0.0:
			continue
		var x := bar_x + clampf(at / duration, 0.0, 1.0) * BAR_W
		var reached := time >= at
		_canvas.draw_line(Vector2(x, row_y), Vector2(x, row_y + ROW_H), COLOR_CANCEL if reached else Color(1, 1, 1, 0.6), 2.0)
		var letter_x := maxf(x + 2.0, next_free)
		_canvas.draw_string(_font, Vector2(letter_x, row_y + ROW_H), INPUT_LETTERS[index],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE if reached else Color(1, 1, 1, 0.7))
		next_free = letter_x + 8.0


func _window_or_none(window: Vector2) -> Vector2:
	return NO_SPAN if window == Vector2.ZERO else window


func _warnings_for(action: ActionData) -> PackedStringArray:
	if not _warnings.has(action):
		_warnings[action] = ActionValidator.check(action)
	return _warnings[action]


func _source_label(source: ActionData.PlaceholderSource) -> String:
	match source:
		ActionData.PlaceholderSource.ER_NUMBERS:
			return "ER numbers"
		ActionData.PlaceholderSource.ER_CLIP:
			return "ER clip"
		ActionData.PlaceholderSource.MADE_UP_POSE:
			return "made-up pose"
	return ""


## The locked-on enemy, else the nearest enemy that is attacking right now, else null.
func _find_enemy() -> Enemy:
	if _player.lock_on.has_target():
		var locked := _player.lock_on.target as Enemy
		if locked != null:
			return locked
	var best: Enemy = null
	var best_distance := INF
	for node: Node3D in Enemies.all():
		var enemy := node as Enemy
		if enemy == null or enemy.get_feel_action() == null:
			continue
		var distance := _player.global_position.distance_squared_to(enemy.global_position)
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best
