class_name PauseMenu
extends CanvasLayer
## The pause menu (Phase 2, item 2). A scene (`scenes/ui/pause_menu.tscn`) instanced as a child of the
## Player, so every arena has it. Esc or gamepad Start (the `pause` action) opens it: the game pauses
## (`SceneTree.paused`), the arena stays visible under a dark dim, the mouse is shown. Entries: RESUME,
## OPTIONS (the same empty placeholder panel as the main menu) and QUIT TO TITLE (a short fade, then the
## main menu). The look is `resources/ui_theme.tres`; this script is behavior only.
## The scene's process mode is "Always", so the menu runs while the tree is paused.
## It does not open while the player is dead (the death prompt and the final death), while the
## boss-slain screen shows, or during a hitstop or slow motion (the time scale is not 1).
## Esc is consumed here (in `_input`), so the camera rig's old "Esc frees the mouse" never sees it.

const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
## The height the Theme's font sizes are written for (the same reference as the main menu).
const REFERENCE_HEIGHT: float = 1080.0

## Seconds of the fade to black when QUIT TO TITLE is chosen.
@export var fade_out_time: float = 0.4
@export_group("Layout (at a 1080 px high window)")
@export var row_width: float = 300.0
@export var row_height: float = 46.0
@export var divider_width: float = 46.0

@onready var _root: Control = %Root
@onready var _paused_label: Label = %PausedLabel
@onready var _divider: ColorRect = %Divider
@onready var _entries: VBoxContainer = %EntryList
@onready var _resume_button: Button = %ResumeButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton
@onready var _hint: Label = %HintLabel
@onready var _options_panel: PanelContainer = %OptionsPanel
@onready var _panel_heading: Label = %PanelHeading
@onready var _panel_text: Label = %PanelText
@onready var _back_button: Button = %BackButton
@onready var _fade: ColorRect = %FadeRect

var _player: Player
var _is_open: bool = false
var _leaving: bool = false
var _quiet_focus: bool = false
var _mouse_mode_before: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _scaler := UiTextScaler.new()
var _buttons: Array[Button] = []


func _ready() -> void:
	_player = get_parent() as Player
	_root.visible = false
	_options_panel.visible = false
	_fade.color.a = 0.0
	_buttons = [_resume_button, _options_button, _quit_button, _back_button]
	var texts: Array[Control] = [
		_paused_label, _hint, _resume_button, _options_button, _quit_button,
		_back_button, _panel_heading, _panel_text,
	]
	for control: Control in texts:
		_scaler.add(control)
	_root.resized.connect(_apply_scale)
	_apply_scale()
	_connect_buttons()


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed(Actions.PAUSE):
		return
	if _leaving:
		get_viewport().set_input_as_handled()
		return
	if _is_open:
		get_viewport().set_input_as_handled()
		_back_or_resume()
	elif _can_open():
		get_viewport().set_input_as_handled()
		_open_menu()


## The gamepad's Cancel button (Esc is already taken by the `pause` action above).
func _unhandled_input(event: InputEvent) -> void:
	if _is_open and not _leaving and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_back_or_resume()


func _can_open() -> bool:
	if _player == null or _player.combatant.dead or _player.state_machine.current is DeadState:
		return false
	if not is_equal_approx(Engine.time_scale, 1.0):
		return false
	var victory := get_tree().get_first_node_in_group(Groups.VICTORY_SCREEN) as VictoryScreen
	return victory == null or not victory.is_active()


func _open_menu() -> void:
	_is_open = true
	_mouse_mode_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_options_panel.visible = false
	_entries.visible = true
	_root.visible = true
	_apply_scale()
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_OK)
	_focus_quietly(_resume_button)


func _resume() -> void:
	if not _is_open:
		return
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_BACK)
	_is_open = false
	_root.visible = false
	Input.mouse_mode = _mouse_mode_before
	get_tree().paused = false


## Esc or Cancel: close the Options panel if it is showing, else resume.
func _back_or_resume() -> void:
	if _options_panel.visible:
		_close_options()
	else:
		_resume()


func _connect_buttons() -> void:
	for button: Button in _buttons:
		button.mouse_entered.connect(_on_button_hovered.bind(button))
		button.focus_entered.connect(_on_button_focused)
	_resume_button.pressed.connect(_resume)
	_options_button.pressed.connect(_open_options)
	_quit_button.pressed.connect(_on_quit_pressed)
	_back_button.pressed.connect(_close_options)
	# Up from the first row wraps to the last, and down from the last wraps to the first.
	_resume_button.focus_neighbor_top = _resume_button.get_path_to(_quit_button)
	_quit_button.focus_neighbor_bottom = _quit_button.get_path_to(_resume_button)


func _on_button_hovered(button: Button) -> void:
	if _is_open and not _leaving and button.is_visible_in_tree():
		button.grab_focus()


func _on_button_focused() -> void:
	if _is_open and not _leaving and not _quiet_focus:
		Sfx.play_ui(get_tree(), Sfx.Id.MENU_MOVE)


## Focus a button without the move sound (the first focus after a screen change).
func _focus_quietly(button: Button) -> void:
	_quiet_focus = true
	button.grab_focus()
	_quiet_focus = false


func _open_options() -> void:
	if not _is_open or _leaving:
		return
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_OK)
	_entries.visible = false
	_paused_label.visible = false
	_divider.visible = false
	_options_panel.visible = true
	_focus_quietly(_back_button)


func _close_options() -> void:
	if not _options_panel.visible:
		return
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_BACK)
	_options_panel.visible = false
	_paused_label.visible = true
	_divider.visible = true
	_entries.visible = true
	_focus_quietly(_options_button)


func _on_quit_pressed() -> void:
	if not _is_open or _leaving:
		return
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_OK)
	_leaving = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, fade_out_time)
	tween.tween_callback(_go_to_title)


func _go_to_title() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	var error := get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	if error != OK:
		push_error("PauseMenu: could not load %s (error %d)." % [MAIN_MENU_SCENE, error])
		get_tree().paused = true
		_fade.color.a = 0.0
		_leaving = false


## Scale the font sizes, the letter spacing and the rows with the window height.
func _apply_scale() -> void:
	var s := _root.size.y / REFERENCE_HEIGHT
	_scaler.apply(s)
	for button: Button in _buttons:
		button.custom_minimum_size = Vector2(row_width * s, row_height * s)
	_divider.custom_minimum_size = Vector2(divider_width * s, maxf(1.0, roundf(s)))
