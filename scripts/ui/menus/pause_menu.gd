class_name PauseMenu
extends CanvasLayer
## The pause menu (Phase 2, item 2). A scene (`scenes/ui/pause_menu.tscn`) instanced as a child of the
## Player, so every arena has it. Esc or gamepad Start (the `pause` action) opens it: the game pauses
## (`SceneTree.paused`), the arena stays visible under a dark dim, the mouse is shown. Entries: RESUME,
## CHANGE ARENA (debug builds only: the arena chooser, then a short fade and the picked arena), OPTIONS
## (the OptionsMenu scene, item 6a, shared with the main menu) and QUIT TO TITLE (a short fade, then the
## main menu). The look is `data/ui/ui_theme.tres`; this script is behavior only.
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
@onready var _arenas_button: Button = %ArenasButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton
@onready var _hint: Label = %HintLabel
@onready var _options: OptionsMenu = %OptionsMenu
@onready var _chooser: ArenaChooser = %ArenaChooser
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
	_fade.color.a = 0.0
	_buttons = [_resume_button, _arenas_button, _options_button, _quit_button]
	# CHANGE ARENA is a debug tool: only in a debug build, and only if an arena is listed.
	_arenas_button.visible = OS.is_debug_build() and ArenaLibrary.has_visible()
	var texts: Array[Control] = [
		_paused_label, _hint, _resume_button, _arenas_button, _options_button, _quit_button,
	]
	for control: Control in texts:
		_scaler.add(control)
	_root.resized.connect(_apply_scale)
	_apply_scale()
	_connect_buttons()


func _input(event: InputEvent) -> void:
	# While a Controls row waits for a key, Esc and Start belong to it (Esc cancels the capture).
	if _options.is_capturing() or not event.is_action_pressed(Actions.PAUSE):
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
	if _is_open and not _leaving and not _options.is_capturing() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_back_or_resume()


func _can_open() -> bool:
	if _player == null or _player.combatant.dead or _player.state_machine.current is DeadState:
		return false
	if not is_equal_approx(Engine.time_scale, Hitstop.base_scale):
		return false
	var victory := get_tree().get_first_node_in_group(Groups.VICTORY_SCREEN) as VictoryScreen
	return victory == null or not victory.is_active()


func _open_menu() -> void:
	_is_open = true
	_mouse_mode_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
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


## Esc or Cancel: close the arena chooser or the Options menu (one page back first) if one is showing, else resume.
func _back_or_resume() -> void:
	if _chooser.visible:
		_chooser.request_close()
	elif _options.visible:
		_options.request_close()
	else:
		_resume()


func _connect_buttons() -> void:
	for button: Button in _buttons:
		button.mouse_entered.connect(_on_button_hovered.bind(button))
		button.focus_entered.connect(_on_button_focused)
	_resume_button.pressed.connect(_resume)
	_arenas_button.pressed.connect(_open_arenas)
	_options_button.pressed.connect(_open_options)
	_quit_button.pressed.connect(_on_quit_pressed)
	_options.closed.connect(_close_options)
	_chooser.arena_chosen.connect(_on_arena_chosen)
	_chooser.closed.connect(_close_arenas)
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


func _open_arenas() -> void:
	if not _is_open or _leaving:
		return
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_OK)
	_entries.visible = false
	_paused_label.visible = false
	_divider.visible = false
	_chooser.open()


## The chooser was closed (Back or Esc): back to the entries.
func _close_arenas() -> void:
	_paused_label.visible = true
	_divider.visible = true
	_entries.visible = true
	_focus_quietly(_arenas_button)


func _on_arena_chosen(arena: ArenaData) -> void:
	if not _is_open or _leaving:
		return
	_start_leaving(arena.scene_path)


func _open_options() -> void:
	if not _is_open or _leaving:
		return
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_OK)
	_entries.visible = false
	_paused_label.visible = false
	_divider.visible = false
	_options.open()


## The Options menu closed itself (Back or the cancel key; it plays the back sound).
func _close_options() -> void:
	_paused_label.visible = true
	_divider.visible = true
	_entries.visible = true
	_focus_quietly(_options_button)


func _on_quit_pressed() -> void:
	if not _is_open or _leaving:
		return
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_OK)
	_start_leaving(MAIN_MENU_SCENE)


## Fade to black, then leave for the scene at `path` (the main menu, or a picked arena).
func _start_leaving(path: String) -> void:
	_leaving = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, fade_out_time)
	tween.tween_callback(_change_scene.bind(path))


func _change_scene(path: String) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	var error := SceneLoader.go(get_tree(), path, SceneLoader.Kind.BLACK)
	if error != OK:
		push_error("PauseMenu: could not load %s (error %d)." % [path, error])
		get_tree().paused = true
		_fade.color.a = 0.0
		_leaving = false
		_chooser.unlock()


## Scale the font sizes, the letter spacing and the rows with the window height.
func _apply_scale() -> void:
	var s := _root.size.y / REFERENCE_HEIGHT
	_scaler.apply(s)
	for button: Button in _buttons:
		button.custom_minimum_size = Vector2(row_width * s, row_height * s)
	_divider.custom_minimum_size = Vector2(divider_width * s, maxf(1.0, roundf(s)))
