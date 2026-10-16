class_name MainMenu
extends Control
## The main menu (Phase 2, item 1). The scene `scenes/ui/main_menu.tscn` is the layout; the look (fonts,
## colors, sizes at a 1080 px high window, the brush-stroke highlight) is in `resources/ui_theme.tres`;
## this script is only behavior: the fades, the music, the "press any button" screen, the entries, the
## Options menu (the OptionsMenu scene, item 6a), and loading the default arena. Texts (the title, the kanji, the footer)
## are the Label nodes' own text in the scene.
## Flow: fade in from black, the music starts, "PRESS ANY BUTTON", then START / OPTIONS / QUIT.
## Keyboard, mouse and gamepad all work (ui_up, ui_down, ui_accept, ui_cancel).

## The arena START loads. A placeholder: the one place to change it.
const DEFAULT_ARENA: String = "res://scenes/arena/test_arena.tscn"
## The height the Theme's font sizes are written for (the same reference as the death screen).
const REFERENCE_HEIGHT: float = 1080.0

enum Phase { INTRO, TITLE, ENTRIES, OPTIONS, ARENAS, LEAVING }

@export_group("Timing")
## Seconds of the fade in from black at launch.
@export var fade_in_time: float = 1.0
## Seconds of the fade to black (and of the music fade) when START or QUIT is pressed.
@export var fade_out_time: float = 0.6
## Seconds the entries take to appear after "press any button".
@export var reveal_time: float = 0.5
## Seconds of one full pulse of "PRESS ANY BUTTON".
@export var press_pulse_time: float = 1.4

@export_group("Music")
## Loudness of the menu music, in dB. The stream itself is set on the Music node (loop it in the Import dock).
@export var music_volume_db: float = -4.0

@export_group("Entries (at a 1080 px high window)")
@export var row_width: float = 380.0
@export var row_height: float = 54.0

## Font size, font and letter spacing of a text control at the reference height (read from the Theme).
class TextBase extends RefCounted:
	var size_px: int = 0
	var spacing: int = 0
	## A copy of the Theme's FontVariation whose spacing follows the window height (null if the Theme font is not one).
	var scaled: FontVariation

@onready var _kanji: Label = %KanjiLabel
@onready var _title: Label = %TitleLabel
@onready var _subtitle: Label = %SubtitleLabel
@onready var _entries: VBoxContainer = %EntryList
@onready var _start_button: Button = %StartButton
@onready var _arenas_button: Button = %ArenasButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton
@onready var _press: Label = %PressLabel
@onready var _options: OptionsMenu = %OptionsMenu
@onready var _chooser: ArenaChooser = %ArenaChooser
@onready var _footer: Label = %FooterLabel
@onready var _version: Label = %VersionLabel
@onready var _fade: ColorRect = %FadeRect
@onready var _music: AudioStreamPlayer = %Music

var _phase: Phase = Phase.INTRO
var _pulse: Tween
var _quiet_focus: bool = false
var _text_bases: Dictionary = {}
var _buttons: Array[Button] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Settings.ensure_loaded()
	GameFlags.clear()
	_version.text = _version_text()
	_buttons = [_start_button, _arenas_button, _options_button, _quit_button]
	_remember_text_bases()
	resized.connect(_apply_scale)
	_apply_scale()
	_connect_buttons()
	_entries.visible = false
	# The ARENAS entry shows only if this build lists at least one arena (see ArenaLibrary).
	# In a release build START opens the chooser itself, so the ARENAS entry would only repeat it.
	_arenas_button.visible = ArenaLibrary.has_visible() and not _start_opens_chooser()

	_fade.color.a = 1.0
	var fade_tween := create_tween()
	fade_tween.tween_property(_fade, "color:a", 0.0, fade_in_time)
	fade_tween.tween_callback(_on_intro_done)
	_start_music()


func _input(event: InputEvent) -> void:
	if _phase != Phase.TITLE or not _is_any_button(event):
		return
	get_viewport().set_input_as_handled()
	_reveal_entries()


func _unhandled_input(event: InputEvent) -> void:
	if _phase == Phase.OPTIONS and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_options.request_close()
	elif _phase == Phase.ARENAS and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_chooser.request_close()


## A key, a mouse button or a gamepad button going down (not mouse motion, not a stick, not key repeat).
func _is_any_button(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false


func _on_intro_done() -> void:
	_phase = Phase.TITLE
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_press, "modulate:a", 1.0, press_pulse_time * 0.5)
	_pulse.tween_property(_press, "modulate:a", 0.25, press_pulse_time * 0.5)


func _reveal_entries() -> void:
	_phase = Phase.ENTRIES
	Sfx.play(get_tree(), Sfx.Id.MENU_OK)
	if _pulse != null:
		_pulse.kill()
	_entries.modulate.a = 0.0
	_entries.visible = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_press, "modulate:a", 0.0, reveal_time * 0.5)
	tween.tween_property(_entries, "modulate:a", 1.0, reveal_time)
	_focus_quietly(_start_button)


func _start_music() -> void:
	if _music.stream == null:
		push_warning("MainMenu: the Music node has no stream. Drag the menu music into its Stream field.")
		return
	_music.volume_db = -80.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", music_volume_db, fade_in_time)


func _connect_buttons() -> void:
	for button: Button in _buttons:
		button.mouse_entered.connect(_on_button_hovered.bind(button))
		button.focus_entered.connect(_on_button_focused)
	_start_button.pressed.connect(_on_start_pressed)
	_arenas_button.pressed.connect(_open_arenas)
	_options_button.pressed.connect(_open_options)
	_quit_button.pressed.connect(_on_quit_pressed)
	_options.closed.connect(_close_options)
	_chooser.arena_chosen.connect(_on_arena_chosen)
	_chooser.closed.connect(_close_arenas)
	# Up from the first row wraps to the last, and down from the last wraps to the first.
	_start_button.focus_neighbor_top = _start_button.get_path_to(_quit_button)
	_quit_button.focus_neighbor_bottom = _quit_button.get_path_to(_start_button)


func _on_button_hovered(button: Button) -> void:
	if _phase == Phase.ENTRIES and button.is_visible_in_tree():
		button.grab_focus()


func _on_button_focused() -> void:
	if not _quiet_focus and _phase != Phase.LEAVING:
		Sfx.play(get_tree(), Sfx.Id.MENU_MOVE)


## Focus a button without the move sound (the first focus after a screen change).
func _focus_quietly(button: Button) -> void:
	_quiet_focus = true
	button.grab_focus()
	_quiet_focus = false


func _on_start_pressed() -> void:
	if _phase != Phase.ENTRIES:
		return
	if _start_opens_chooser():
		_open_arenas()
		return
	Sfx.play(get_tree(), Sfx.Id.MENU_OK)
	_leave(_load_arena)


func _on_quit_pressed() -> void:
	if _phase != Phase.ENTRIES:
		return
	Sfx.play(get_tree(), Sfx.Id.MENU_OK)
	_leave(get_tree().quit)


## A release build sends START to the arena chooser (if it lists an arena); a debug build and the editor
## keep START loading DEFAULT_ARENA at once, for fast testing.
func _start_opens_chooser() -> bool:
	return not OS.is_debug_build() and ArenaLibrary.has_visible()


func _open_arenas() -> void:
	if _phase != Phase.ENTRIES:
		return
	Sfx.play(get_tree(), Sfx.Id.MENU_OK)
	_phase = Phase.ARENAS
	_entries.visible = false
	_chooser.open()


## The chooser was closed (Back or Esc): back to the entries.
func _close_arenas() -> void:
	if _phase != Phase.ARENAS:
		return
	_phase = Phase.ENTRIES
	_entries.visible = true
	_focus_quietly(_start_button if _start_opens_chooser() else _arenas_button)


func _on_arena_chosen(arena: ArenaData) -> void:
	if _phase != Phase.ARENAS:
		return
	_leave(_load_arena.bind(arena.scene_path))


func _open_options() -> void:
	if _phase != Phase.ENTRIES:
		return
	Sfx.play(get_tree(), Sfx.Id.MENU_OK)
	_phase = Phase.OPTIONS
	_entries.visible = false
	_options.open()


## The Options menu closed itself (Back or the cancel key; it plays the back sound).
func _close_options() -> void:
	if _phase != Phase.OPTIONS:
		return
	_phase = Phase.ENTRIES
	_entries.visible = true
	_focus_quietly(_options_button)


## Fade the screen and the music out, then run `then`.
func _leave(then: Callable) -> void:
	_phase = Phase.LEAVING
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_fade, "color:a", 1.0, fade_out_time)
	tween.tween_property(_music, "volume_db", -80.0, fade_out_time)
	tween.chain().tween_callback(then)


func _load_arena(path: String = DEFAULT_ARENA) -> void:
	var error := SceneLoader.go(get_tree(), path, SceneLoader.Kind.PROPER)
	if error != OK:
		push_error("MainMenu: could not load %s (error %d)." % [path, error])
		_fade.color.a = 0.0
		_music.volume_db = music_volume_db
		_chooser.unlock()
		_phase = Phase.ARENAS if _chooser.visible else Phase.ENTRIES


func _version_text() -> String:
	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	return "Ver. %s" % (version if version != "" else "?")


## Read each text control's Theme size, font and spacing once, so they can be scaled with the window.
func _remember_text_bases() -> void:
	var controls: Array[Control] = [
		_kanji, _title, _subtitle, _press, _footer, _version,
		_start_button, _arenas_button, _options_button, _quit_button,
	]
	for control: Control in controls:
		var base := TextBase.new()
		base.size_px = control.get_theme_font_size(&"font_size")
		var variation := control.get_theme_font(&"font") as FontVariation
		if variation != null:
			base.spacing = variation.spacing_glyph
			base.scaled = variation.duplicate() as FontVariation
			control.add_theme_font_override(&"font", base.scaled)
		_text_bases[control] = base


## Scale the font sizes, the letter spacing and the entry rows with the window height.
func _apply_scale() -> void:
	var s := size.y / REFERENCE_HEIGHT
	for control: Control in _text_bases:
		var base: TextBase = _text_bases[control]
		control.add_theme_font_size_override(&"font_size", maxi(1, roundi(float(base.size_px) * s)))
		if base.scaled != null:
			base.scaled.spacing_glyph = roundi(float(base.spacing) * s)
	for button: Button in _buttons:
		button.custom_minimum_size = Vector2(row_width * s, row_height * s)
