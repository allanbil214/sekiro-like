class_name DebugMenu
extends CanvasLayer
## The debug menu (Phase 3a-4). F1 opens and closes it, in debug builds only (the editor counts as one);
## Esc or Cancel closes it too. The game pauses while it is open. A child of Player: add it in the editor as
## the LAST child, so it sees Esc before the pause menu does. The entries come from `DebugOptions.build()`;
## the rows are built here in code, because the list is data. The look is `data/ui/ui_theme.tres`.
## Options changed here are remembered for the session and re-applied when the next arena loads.

const OPEN_KEY: Key = KEY_F1
const THEME_PATH: String = "res://data/ui/ui_theme.tres"
const FONT_SIZE: int = 20
const HEADER_SIZE: int = 22
const ROW_HEIGHT: float = 34.0

var _player: Player
var _options: Array[DebugOptions.Option] = []
var _controls: Dictionary = {}
var _touched: Dictionary = {}
var _root: Control
var _list: VBoxContainer
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
	_root.theme = load(THEME_PATH) as Theme
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_left = 0.3
	panel.anchor_right = 0.7
	panel.anchor_top = 0.1
	panel.anchor_bottom = 0.9
	_root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	column.add_child(_make_label("DEBUG MENU", HEADER_SIZE, true))
	column.add_child(_make_label("F1 or Esc closes. Debug builds only.", 16, false))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)
	var last_group := ""
	for option: DebugOptions.Option in _options:
		if option.group != last_group:
			last_group = option.group
			_list.add_child(_make_label(option.group, FONT_SIZE, true))
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
		control.add_theme_font_size_override("font_size", FONT_SIZE)
		control.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
		_list.add_child(control)
		_controls[option.id] = control
		if _first_focus == null:
			_first_focus = control


func _make_label(text: String, size: int, subtitle: bool) -> Label:
	var label := Label.new()
	label.text = text
	if subtitle:
		label.theme_type_variation = &"SubtitleLabel"
	label.add_theme_font_size_override("font_size", size)
	return label
