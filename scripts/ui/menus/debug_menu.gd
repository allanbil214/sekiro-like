class_name DebugMenu
extends CanvasLayer
## The debug menu (Phase 3a-4). F1 opens and closes it, in debug builds only (the editor counts as one);
## Esc or Cancel closes it too. The game pauses while it is open. A child of Player: add it in the editor as
## the LAST child, so it sees Esc before the pause menu does. The entries come from `DebugOptions.build()`;
## the rows are built here in code, because the list is data. The look is deliberately plain and NOT the game's
## `ui_theme.tres`: Godot's default theme and font, a solid dark panel, text sized from the window height.
## Options changed here are remembered for the session and re-applied when the next arena loads.

const OPEN_KEY: Key = KEY_F1
## Text size as a fraction of the window height, clamped, so the menu stays readable on any screen.
const TEXT_HEIGHT_FRACTION: float = 0.018
const TEXT_MIN: int = 14
const TEXT_MAX: int = 30
const COLOR_PANEL := Color(0.10, 0.11, 0.13, 0.98)
const COLOR_BORDER := Color(0.35, 0.38, 0.45)
const COLOR_TITLE := Color(1.0, 1.0, 1.0)
const COLOR_GROUP := Color(0.55, 0.8, 1.0)
const COLOR_HINT := Color(0.65, 0.68, 0.72)

var _player: Player
var _options: Array[DebugOptions.Option] = []
var _controls: Dictionary = {}
var _touched: Dictionary = {}
var _root: Control
var _list: VBoxContainer
var _column: VBoxContainer
var _panel_style: StyleBoxFlat
## Each entry is [control, size factor]: re-sized when the window changes.
var _sized: Array = []
var _first_focus: Control
var _is_open: bool = false
var _mouse_mode_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	# Debug builds only: a release export has no debug menu at all.
	if not OS.is_debug_build():
		queue_free()
		return
	_player = get_parent() as Player
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40
	_options = DebugOptions.build(_player)
	_build_ui()
	_root.visible = false
	_apply_remembered.call_deferred()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == OPEN_KEY:
		get_viewport().set_input_as_handled()
		if _is_open:
			_close()
		elif not get_tree().paused:
			_open()
		return
	if _is_open and (event.is_action_pressed(Actions.PAUSE) or event.is_action_pressed(&"ui_cancel")):
		get_viewport().set_input_as_handled()
		_close()


func _open() -> void:
	_is_open = true
	_mouse_mode_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_refresh()
	_root.visible = true
	if _first_focus != null:
		_first_focus.grab_focus()


func _close() -> void:
	_is_open = false
	_root.visible = false
	# A shortcut key (F2, F3, F4) may have changed a value since: keep what the game really has.
	for option: DebugOptions.Option in _options:
		if _touched.has(option.id):
			DebugOptions.remember(option.id, option.get_value())
	Input.mouse_mode = _mouse_mode_before
	get_tree().paused = false


## A new arena: put back what the user changed in the menu earlier this session.
func _apply_remembered() -> void:
	for option: DebugOptions.Option in _options:
		if DebugOptions.has_remembered(option.id):
			option.set_value(DebugOptions.get_remembered(option.id))
			_touched[option.id] = true
	_refresh()


func _refresh() -> void:
	for option: DebugOptions.Option in _options:
		var control: Control = _controls[option.id]
		if option.is_toggle():
			(control as CheckButton).set_pressed_no_signal(option.get_value() as bool)
		else:
			(control as Button).text = _choice_text(option)


func _choice_text(option: DebugOptions.Option) -> String:
	var index: int = clampi(option.get_value() as int, 0, option.choices.size() - 1)
	return "%s:  < %s >" % [option.label, option.choices[index]]


func _on_toggled(pressed: bool, option: DebugOptions.Option) -> void:
	option.set_value(pressed)
	_touched[option.id] = true
	DebugOptions.remember(option.id, pressed)


func _on_cycled(option: DebugOptions.Option, button: Button) -> void:
	var next: int = (clampi(option.get_value() as int, 0, option.choices.size() - 1) + 1) % option.choices.size()
	option.set_value(next)
	_touched[option.id] = true
	DebugOptions.remember(option.id, next)
	button.text = _choice_text(option)


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)  # no theme: Godot's default look, on purpose
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.2
	panel.anchor_right = 0.8
	panel.anchor_top = 0.05
	panel.anchor_bottom = 0.95
	panel.custom_minimum_size = Vector2(520.0, 0.0)
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = COLOR_PANEL
	_panel_style.border_color = COLOR_BORDER
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", _panel_style)
	_root.add_child(panel)
	_column = VBoxContainer.new()
	panel.add_child(_column)
	_column.add_child(_make_label("DEBUG MENU", 1.3, COLOR_TITLE))
	_column.add_child(_make_label("F1 or Esc closes. Debug builds only.", 0.85, COLOR_HINT))
	_column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var last_group := ""
	for option: DebugOptions.Option in _options:
		if option.group != last_group:
			if not last_group.is_empty():
				_list.add_child(HSeparator.new())
			last_group = option.group
			_list.add_child(_make_label(option.group, 1.1, COLOR_GROUP))
		var control: Control
		if option.is_toggle():
			var check := CheckButton.new()
			check.text = option.label
			check.toggled.connect(_on_toggled.bind(option))
			control = check
		else:
			var button := Button.new()
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_on_cycled.bind(option, button))
			control = button
		_list.add_child(control)
		_controls[option.id] = control
		_sized.append([control, 1.0])
		if _first_focus == null:
			_first_focus = control
	get_viewport().size_changed.connect(_apply_sizes)
	_apply_sizes()


## Text size from the window height; spacing, margins and row heights follow the text size.
func _text_size() -> int:
	var height: float = get_viewport().get_visible_rect().size.y
	return clampi(roundi(height * TEXT_HEIGHT_FRACTION), TEXT_MIN, TEXT_MAX)


func _apply_sizes() -> void:
	var text_size: int = _text_size()
	for entry: Array in _sized:
		var control: Control = entry[0]
		var factor: float = entry[1]
		var text_px: int = roundi(float(text_size) * factor)
		control.add_theme_font_size_override("font_size", text_px)
		if control is BaseButton:
			control.custom_minimum_size = Vector2(0.0, roundf(float(text_size) * 1.9))
	var margin: float = float(text_size) * 0.9
	_panel_style.content_margin_left = margin
	_panel_style.content_margin_right = margin
	_panel_style.content_margin_top = margin * 0.8
	_panel_style.content_margin_bottom = margin * 0.8
	_column.add_theme_constant_override("separation", roundi(float(text_size) * 0.35))
	_list.add_theme_constant_override("separation", roundi(float(text_size) * 0.25))


func _make_label(text: String, factor: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	_sized.append([label, factor])
	return label
