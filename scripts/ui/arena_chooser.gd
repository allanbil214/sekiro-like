class_name ArenaChooser
extends Control
## The arena chooser (Phase 2, item 3b): a list of the arenas on the left, grouped by category, and the
## focused arena's picture, name and description on the right. One scene (`scenes/ui/arena_chooser.tscn`)
## instanced by both the main menu and the pause menu, which do the fade and the loading: this only
## sends `arena_chosen` (an arena was picked) and `closed` (Back or the cancel key). The arenas come
## from `ArenaLibrary.visible_arenas()`. The look is `resources/ui_theme.tres`; keyboard, mouse and
## gamepad work through Button focus. Sounds use `Sfx.play_ui` so they also work while paused.
## The hosts call `open()` to show it, `request_close()` for the cancel key, and `unlock()` if the load
## failed (after a pick, further picks are ignored until then).

signal arena_chosen(arena: ArenaData)
signal closed

## The height the Theme's font sizes are written for (the same reference as the menus).
const REFERENCE_HEIGHT: float = 1080.0

@export_group("Layout (at a 1080 px high window)")
## Font sizes of an arena row and of a category heading.
@export var row_font_size: int = 28
@export var heading_font_size: int = 22
@export var row_height: float = 46.0
## Height of the picture frame (its width follows the panel).
@export var image_height: float = 280.0
@export var back_width: float = 240.0
@export var back_height: float = 54.0

@onready var _heading: Label = %Heading
@onready var _list: VBoxContainer = %List
@onready var _image_frame: Control = %ImageFrame
@onready var _image: TextureRect = %Image
@onready var _no_image: Label = %NoImageLabel
@onready var _name: Label = %NameLabel
@onready var _category: Label = %CategoryLabel
@onready var _description: Label = %DescriptionLabel
@onready var _back: Button = %BackButton

var _static_scaler := UiTextScaler.new()
var _row_scaler := UiTextScaler.new()
var _rows: Array[Button] = []
var _quiet_focus: bool = false
var _is_open: bool = false
var _chosen: bool = false


func _ready() -> void:
	visible = false
	var texts: Array[Control] = [_heading, _name, _category, _description, _no_image, _back]
	for control: Control in texts:
		_static_scaler.add(control)
	resized.connect(_apply_scale)
	_back.pressed.connect(request_close)
	_back.mouse_entered.connect(_on_hovered.bind(_back))
	_back.focus_entered.connect(_on_back_focused)
	_apply_scale()


## Show the chooser with a fresh list and focus the first arena.
func open() -> void:
	_chosen = false
	_is_open = true
	visible = true
	_build_list()
	_apply_scale()
	if _rows.is_empty():
		_show_detail(null)
		_focus_quietly(_back)
	else:
		_focus_quietly(_rows[0])


## Back or the cancel key: close and tell the host. Ignored while closed or after a pick.
func request_close() -> void:
	if not _is_open or _chosen:
		return
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_BACK)
	_is_open = false
	visible = false
	closed.emit()


## The host could not load the picked arena: picking works again.
func unlock() -> void:
	_chosen = false


func _build_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()
	_row_scaler = UiTextScaler.new()
	var last_category: int = -1
	for arena: ArenaData in ArenaLibrary.visible_arenas():
		if int(arena.category) != last_category:
			last_category = int(arena.category)
			_list.add_child(_make_heading(ArenaData.category_label(arena.category)))
		var row := _make_row(arena)
		_list.add_child(row)
		_rows.append(row)
	_wrap_focus()


func _make_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"SubtitleLabel"
	label.add_theme_font_size_override(&"font_size", heading_font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row_scaler.add(label)
	return label


func _make_row(arena: ArenaData) -> Button:
	var button := Button.new()
	button.text = arena.display_name
	button.theme_type_variation = &"EntryButton"
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.add_theme_font_size_override(&"font_size", row_font_size)
	button.focus_entered.connect(_on_row_focused.bind(arena))
	button.mouse_entered.connect(_on_hovered.bind(button))
	button.pressed.connect(_on_row_pressed.bind(arena))
	_row_scaler.add(button)
	return button


## Up from the first row goes to Back, down from Back goes to the first row, and the ends wrap.
func _wrap_focus() -> void:
	if _rows.is_empty():
		return
	var first := _rows[0]
	var last := _rows[_rows.size() - 1]
	first.focus_neighbor_top = first.get_path_to(_back)
	last.focus_neighbor_bottom = last.get_path_to(_back)
	_back.focus_neighbor_top = _back.get_path_to(last)
	_back.focus_neighbor_bottom = _back.get_path_to(first)


func _on_hovered(button: Button) -> void:
	if _is_open and not _chosen and button.is_visible_in_tree():
		button.grab_focus()


func _on_row_focused(arena: ArenaData) -> void:
	_show_detail(arena)
	if _is_open and not _chosen and not _quiet_focus:
		Sfx.play_ui(get_tree(), Sfx.Id.MENU_MOVE)


func _on_back_focused() -> void:
	if _rows.is_empty():
		_show_detail(null)
	if _is_open and not _chosen and not _quiet_focus:
		Sfx.play_ui(get_tree(), Sfx.Id.MENU_MOVE)


func _on_row_pressed(arena: ArenaData) -> void:
	if not _is_open or _chosen:
		return
	_chosen = true
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_OK)
	arena_chosen.emit(arena)


## The right side: the picture (or the placeholder), the name, the category and the description.
func _show_detail(arena: ArenaData) -> void:
	if arena == null:
		_image.texture = null
		_no_image.visible = true
		_name.text = ""
		_category.text = ""
		_description.text = "No arenas found."
		return
	_image.texture = arena.image
	_no_image.visible = arena.image == null
	_name.text = arena.display_name
	_category.text = ArenaData.category_label(arena.category) + ("  ·  DEBUG ONLY" if arena.debug_only else "")
	_description.text = arena.description


## Focus a button without the move sound (the first focus after opening).
func _focus_quietly(button: Button) -> void:
	_quiet_focus = true
	button.grab_focus()
	_quiet_focus = false


## Scale the font sizes, the letter spacing and the sizes with the window height.
func _apply_scale() -> void:
	var s := size.y / REFERENCE_HEIGHT
	_static_scaler.apply(s)
	_row_scaler.apply(s)
	for row: Button in _rows:
		row.custom_minimum_size = Vector2(0.0, row_height * s)
	_image_frame.custom_minimum_size = Vector2(0.0, image_height * s)
	_back.custom_minimum_size = Vector2(back_width * s, back_height * s)
