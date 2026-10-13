class_name OptionsMenu
extends Control
## The Options menu (Phase 2, item 6a): one scene (`scenes/ui/options_menu.tscn`) instanced by both the
## main menu and the pause menu, which only call `open()` and listen for `closed` (the same pattern as
## the ArenaChooser). Three pages: the main one (AUDIO, GAMEPLAY), AUDIO (three volume sliders) and
## GAMEPLAY (toggles and sliders). The containers, the heading and the buttons are in the scene; the rows
## are built here from a small table of getters and setters on `Settings`, so a new option is one call.
## Every change is applied at once (volumes now, gameplay values to the Player in the scene, if any) and
## saved to `user://settings.cfg` when a toggle is pressed, a slider is released, a page changes or the
## menu closes. Esc or Cancel (`request_close()`) goes back one page, then closes. Keyboard, mouse and
## gamepad work through Button and slider focus; sounds use `Sfx.play_ui` so they work while paused.
## Controls (remapping) is item 6b and is not here.

signal closed

## The height the Theme's font sizes are written for (the same reference as the menus).
const REFERENCE_HEIGHT: float = 1080.0

enum Page { MAIN, AUDIO, GAMEPLAY }

@export_group("Layout (at a 1080 px high window)")
## Font size of a row (the body font, like the arena chooser's rows).
@export var row_font_size: int = 26
@export var row_height: float = 48.0
## Width of a slider's name, of its value text, and the least width of the slider itself.
@export var label_width: float = 290.0
@export var value_width: float = 90.0
@export var slider_min_width: float = 200.0
@export var page_button_width: float = 320.0
@export var back_width: float = 240.0
@export var back_height: float = 54.0

class ToggleRow extends RefCounted:
	var button: Button
	var title: String
	var on_text: String
	var off_text: String
	var getter: Callable
	var setter: Callable

class SliderRow extends RefCounted:
	var label: Label
	var slider: HSlider
	var value_label: Label
	var getter: Callable
	var setter: Callable

@onready var _heading: Label = %Heading
@onready var _main_page: VBoxContainer = %MainPage
@onready var _audio_page: VBoxContainer = %AudioPage
@onready var _gameplay_page: VBoxContainer = %GameplayPage
@onready var _audio_button: Button = %AudioButton
@onready var _gameplay_button: Button = %GameplayButton
@onready var _back: Button = %BackButton

var _static_scaler := UiTextScaler.new()
var _row_scaler := UiTextScaler.new()
var _toggles: Array[ToggleRow] = []
var _sliders: Array[SliderRow] = []
var _page_controls: Dictionary = {}
var _page: Page = Page.MAIN
var _is_open: bool = false
var _quiet_focus: bool = false
var _dragging: bool = false
var _dirty: bool = false


func _ready() -> void:
	visible = false
	var texts: Array[Control] = [_heading, _audio_button, _gameplay_button, _back]
	for control: Control in texts:
		_static_scaler.add(control)
	_build_audio_page()
	_build_gameplay_page()
	var main_controls: Array[Control] = [_audio_button, _gameplay_button]
	_page_controls[Page.MAIN] = main_controls
	for button: Button in [_audio_button, _gameplay_button, _back]:
		button.mouse_entered.connect(_on_hovered.bind(button))
		button.focus_entered.connect(_on_focused)
	_audio_button.pressed.connect(_on_page_button_pressed.bind(Page.AUDIO))
	_gameplay_button.pressed.connect(_on_page_button_pressed.bind(Page.GAMEPLAY))
	_back.pressed.connect(request_close)
	resized.connect(_apply_scale)
	_apply_scale()


func _exit_tree() -> void:
	_save_if_dirty()


## Show the menu on its main page with the current values.
func open() -> void:
	Settings.ensure_loaded()
	_refresh_rows()
	_is_open = true
	visible = true
	_show_page(Page.MAIN, _audio_button)
	_apply_scale()


## Back or the cancel key: one page back, or close and tell the host. Ignored while closed.
func request_close() -> void:
	if not _is_open:
		return
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_BACK)
	_save_if_dirty()
	if _page != Page.MAIN:
		var button: Button = _audio_button if _page == Page.AUDIO else _gameplay_button
		_show_page(Page.MAIN, button)
		return
	_is_open = false
	visible = false
	closed.emit()


# --- Pages --------------------------------------------------------------------------------------

func _build_audio_page() -> void:
	var controls: Array[Control] = []
	controls.append(_add_slider(_audio_page, "MASTER", 0.0, 100.0, 5.0,
		func() -> float: return Settings.master_volume,
		func(value: float) -> void: Settings.master_volume = value))
	controls.append(_add_slider(_audio_page, "MUSIC", 0.0, 100.0, 5.0,
		func() -> float: return Settings.music_volume,
		func(value: float) -> void: Settings.music_volume = value))
	controls.append(_add_slider(_audio_page, "SOUND EFFECTS", 0.0, 100.0, 5.0,
		func() -> float: return Settings.sfx_volume,
		func(value: float) -> void: Settings.sfx_volume = value))
	_page_controls[Page.AUDIO] = controls


func _build_gameplay_page() -> void:
	var controls: Array[Control] = []
	controls.append(_add_toggle(_gameplay_page, "CAMERA SHAKE", "ON", "OFF",
		func() -> bool: return Settings.camera_shake,
		func(value: bool) -> void: Settings.camera_shake = value))
	controls.append(_add_toggle(_gameplay_page, "CROUCH", "HOLD", "TOGGLE",
		func() -> bool: return Settings.crouch_hold,
		func(value: bool) -> void: Settings.crouch_hold = value))
	controls.append(_add_toggle(_gameplay_page, "RECENTER CAMERA", "ON", "OFF",
		func() -> bool: return Settings.recenter_camera,
		func(value: bool) -> void: Settings.recenter_camera = value))
	controls.append(_add_toggle(_gameplay_page, "LOCK NEXT ENEMY", "ON", "OFF",
		func() -> bool: return Settings.lock_next,
		func(value: bool) -> void: Settings.lock_next = value))
	controls.append(_add_slider(_gameplay_page, "MOUSE SPEED", 25.0, 200.0, 5.0,
		func() -> float: return Settings.mouse_sensitivity,
		func(value: float) -> void: Settings.mouse_sensitivity = value))
	controls.append(_add_slider(_gameplay_page, "STICK SPEED", 25.0, 200.0, 5.0,
		func() -> float: return Settings.stick_sensitivity,
		func(value: float) -> void: Settings.stick_sensitivity = value))
	controls.append(_add_toggle(_gameplay_page, "INVERT Y", "ON", "OFF",
		func() -> bool: return Settings.invert_y,
		func(value: bool) -> void: Settings.invert_y = value))
	_page_controls[Page.GAMEPLAY] = controls


func _show_page(page: Page, focus: Control) -> void:
	_page = page
	_main_page.visible = page == Page.MAIN
	_audio_page.visible = page == Page.AUDIO
	_gameplay_page.visible = page == Page.GAMEPLAY
	match page:
		Page.AUDIO:
			_heading.text = "AUDIO"
		Page.GAMEPLAY:
			_heading.text = "GAMEPLAY"
		_:
			_heading.text = "OPTIONS"
	var controls: Array[Control] = _page_controls[page]
	_wire_focus(controls)
	if page != Page.MAIN:
		focus = controls[0]
	_focus_quietly(focus)


func _on_page_button_pressed(page: Page) -> void:
	if not _is_open or _page != Page.MAIN:
		return
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_OK)
	_show_page(page, null)


## Chain the focus through the page's rows and the Back button, wrapping at both ends.
func _wire_focus(controls: Array[Control]) -> void:
	var count := controls.size()
	for i in count:
		var control := controls[i]
		var above: Control = _back if i == 0 else controls[i - 1]
		var below: Control = _back if i == count - 1 else controls[i + 1]
		control.focus_neighbor_top = control.get_path_to(above)
		control.focus_neighbor_bottom = control.get_path_to(below)
	_back.focus_neighbor_top = _back.get_path_to(controls[count - 1])
	_back.focus_neighbor_bottom = _back.get_path_to(controls[0])


# --- Rows ---------------------------------------------------------------------------------------

func _add_toggle(page: VBoxContainer, title: String, on_text: String, off_text: String, getter: Callable, setter: Callable) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"EntryButton"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.add_theme_font_size_override(&"font_size", row_font_size)
	# The body font (tight letter spacing), not the wide menu font.
	button.add_theme_font_override(&"font", get_theme_font(&"font", &"PanelText"))
	page.add_child(button)
	_row_scaler.add(button)
	var row := ToggleRow.new()
	row.button = button
	row.title = title
	row.on_text = on_text
	row.off_text = off_text
	row.getter = getter
	row.setter = setter
	_toggles.append(row)
	button.pressed.connect(_on_toggle_pressed.bind(row))
	button.mouse_entered.connect(_on_hovered.bind(button))
	button.focus_entered.connect(_on_focused)
	return button


func _add_slider(page: VBoxContainer, title: String, min_percent: float, max_percent: float, step_percent: float, getter: Callable, setter: Callable) -> HSlider:
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 16)
	var label := Label.new()
	label.theme_type_variation = &"PanelText"
	label.add_theme_font_size_override(&"font_size", row_font_size)
	label.text = title
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slider := HSlider.new()
	slider.theme_type_variation = &"OptionsSlider"
	slider.min_value = min_percent
	slider.max_value = max_percent
	slider.step = step_percent
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := Label.new()
	value_label.theme_type_variation = &"PanelText"
	value_label.add_theme_font_size_override(&"font_size", row_font_size)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	box.add_child(slider)
	box.add_child(value_label)
	page.add_child(box)
	# Added to the tree first, so the scaler reads the Theme's font (and its letter spacing).
	_row_scaler.add(label)
	_row_scaler.add(value_label)
	var row := SliderRow.new()
	row.label = label
	row.slider = slider
	row.value_label = value_label
	row.getter = getter
	row.setter = setter
	_sliders.append(row)
	slider.value_changed.connect(_on_slider_changed.bind(row))
	slider.drag_started.connect(_on_drag_started)
	slider.drag_ended.connect(_on_drag_ended)
	slider.mouse_entered.connect(_on_hovered.bind(slider))
	slider.focus_entered.connect(_on_focused)
	return slider


## Put every row on the current setting (without firing the rows' own signals).
func _refresh_rows() -> void:
	for row: ToggleRow in _toggles:
		_update_toggle_text(row)
	for row: SliderRow in _sliders:
		var percent := float(row.getter.call()) * 100.0
		row.slider.set_value_no_signal(percent)
		row.value_label.text = "%d%%" % roundi(row.slider.value)


func _update_toggle_text(row: ToggleRow) -> void:
	var on: bool = bool(row.getter.call())
	row.button.text = "%s: %s" % [row.title, row.on_text if on else row.off_text]


func _on_toggle_pressed(row: ToggleRow) -> void:
	if not _is_open:
		return
	row.setter.call(not bool(row.getter.call()))
	_update_toggle_text(row)
	_changed()
	_save_if_dirty()
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_OK)


func _on_slider_changed(value: float, row: SliderRow) -> void:
	row.value_label.text = "%d%%" % roundi(value)
	row.setter.call(value / 100.0)
	_changed()
	# A drag plays its sound when it is released; a key or stick step plays it now.
	if _is_open and not _dragging:
		Sfx.play_ui(get_tree(), Sfx.Id.MENU_MOVE)


func _on_drag_started() -> void:
	_dragging = true


func _on_drag_ended(_value_changed: bool) -> void:
	_dragging = false
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_MOVE)
	_save_if_dirty()


## A setting changed: apply it now (the volumes, and the Player in the scene if there is one).
func _changed() -> void:
	_dirty = true
	Settings.apply_audio()
	Settings.apply_to_scene(get_tree())


func _save_if_dirty() -> void:
	if _dirty:
		_dirty = false
		Settings.save()


# --- Focus and scale ----------------------------------------------------------------------------

func _on_hovered(control: Control) -> void:
	if _is_open and control.is_visible_in_tree():
		control.grab_focus()


func _on_focused() -> void:
	if _is_open and not _quiet_focus:
		Sfx.play_ui(get_tree(), Sfx.Id.MENU_MOVE)


## Focus a control without the move sound (the first focus after a page change).
func _focus_quietly(control: Control) -> void:
	_quiet_focus = true
	control.grab_focus()
	_quiet_focus = false


## Scale the font sizes, the letter spacing and the row sizes with the window height.
func _apply_scale() -> void:
	var s := size.y / REFERENCE_HEIGHT
	_static_scaler.apply(s)
	_row_scaler.apply(s)
	for row: ToggleRow in _toggles:
		row.button.custom_minimum_size = Vector2(0.0, row_height * s)
	for row: SliderRow in _sliders:
		row.label.custom_minimum_size = Vector2(label_width * s, 0.0)
		row.value_label.custom_minimum_size = Vector2(value_width * s, 0.0)
		row.slider.custom_minimum_size = Vector2(slider_min_width * s, row_height * s)
	for button: Button in [_audio_button, _gameplay_button]:
		button.custom_minimum_size = Vector2(page_button_width * s, row_height * s)
	_back.custom_minimum_size = Vector2(back_width * s, back_height * s)
