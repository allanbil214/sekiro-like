class_name LoadingScreen
extends Control
## The proper loading screen (Phase 2, item 5). `SceneLoader.go(..., Kind.PROPER)` opens this scene; it
## fades in from black, loads the target arena on a thread (`ResourceLoader.load_threaded_request`), shows a
## tip (cross-fading to the next every `tip_interval` s, or on Enter, A or a click) and an eased progress
## bar, waits for the load and for `min_time`, fades out to full black, and only then calls
## `change_scene_to_packed`. The loaded arena is inert data until that call: nothing in it runs behind this
## screen. The arena fades in from black with its own start fade, and the player has control from the first frame.
## If the load fails it logs an error and returns to the main menu.
## The look is in `scenes/ui/loading_screen.tscn` (shared Theme); this script is behavior only.

enum Phase { FADE_IN, LOADING, FADE_OUT, FAILED }

@export_group("Timing")
## Seconds of the fade in from black, and of the fade out to black before the switch.
@export var fade_in_time: float = 0.5
@export var fade_out_time: float = 0.5
## The least time (s) the screen stays, counted from its start, so a fast load does not flash by.
@export var min_time: float = 2.5
## How fast the bar eases toward its target (higher is quicker).
@export var bar_ease_speed: float = 6.0

@export_group("Tips")
@export_file("*.csv") var tips_path: String = "res://data/loading_tips.csv"
## Seconds a tip stays (after it has faded in) before the next one cross-fades in.
@export var tip_interval: float = 8.0
## Seconds of each half of a tip change (old fades out, text swaps while invisible, new fades in).
@export var tip_fade_time: float = 0.45

@export_group("Background pictures (empty = none)")
## Pictures that cross-fade behind the tips and drift slowly (a slight zoom). Leave empty for a black screen.
@export var backgrounds: Array[Texture2D] = []
@export var background_interval: float = 12.0
@export var background_fade_time: float = 1.5
## How much a picture zooms in over the time it is shown (0.06 = 6 percent).
@export var drift_zoom: float = 0.06

@export_group("Layout (at a 1080 px high window)")
@export var line_width: float = 260.0
@export var line_height: float = 2.0

const REFERENCE_HEIGHT: float = 1080.0

@onready var _picture_a: TextureRect = %PictureA
@onready var _picture_b: TextureRect = %PictureB
@onready var _dim: ColorRect = %Dim
@onready var _kanji: Label = %KanjiLabel
@onready var _tip_block: VBoxContainer = %TipBlock
@onready var _tip_title: Label = %TipTitle
@onready var _tip_line: ColorRect = %TipLine
@onready var _tip_text: Label = %TipText
@onready var _bar: ProgressBar = %LoadBar
@onready var _fade: ColorRect = %FadeRect

var _phase: Phase = Phase.FADE_IN
var _path: String = ""
var _elapsed: float = 0.0
var _real_progress: float = 0.0
var _target_progress: float = 0.0
var _shown_progress: float = 0.0
var _loaded: bool = false
var _tips: LoadingTips = LoadingTips.new()
var _tip_timer: float = 0.0
var _tip_tween: Tween
var _scaler: UiTextScaler = UiTextScaler.new()
var _front_picture: TextureRect
var _background_index: int = 0
var _background_timer: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_scaler.add(_kanji)
	_scaler.add(_tip_title)
	_scaler.add(_tip_text)
	resized.connect(_apply_scale)
	_apply_scale()
	_picture_a.resized.connect(_center_pivot.bind(_picture_a))
	_picture_b.resized.connect(_center_pivot.bind(_picture_b))

	_path = SceneLoader.take_target()
	_setup_tips()
	_setup_backgrounds()
	_bar.value = 0.0

	_fade.color.a = 1.0
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, fade_in_time)
	tween.tween_callback(_begin_loading)


func _process(delta: float) -> void:
	_elapsed += delta
	_ease_bar(delta)
	if _phase == Phase.FADE_IN or _phase == Phase.LOADING:
		_update_tips(delta)
		_update_backgrounds(delta)
	if _phase != Phase.LOADING:
		return
	_poll_load()
	if _phase == Phase.LOADING and _loaded and _elapsed >= min_time and _shown_progress >= 0.995:
		_begin_leaving()


## Enter, A (ui_accept) or a left click skips to the next tip.
func _input(event: InputEvent) -> void:
	if _phase != Phase.FADE_IN and _phase != Phase.LOADING:
		return
	var skip := event.is_action_pressed(&"ui_accept")
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		skip = skip or (click.pressed and click.button_index == MOUSE_BUTTON_LEFT)
	if skip:
		get_viewport().set_input_as_handled()
		_next_tip()


func _begin_loading() -> void:
	if _path.is_empty():
		_fail("LoadingScreen: no target scene was set (open this screen through SceneLoader.go).")
		return
	var error := ResourceLoader.load_threaded_request(_path)
	if error != OK:
		_fail("LoadingScreen: could not start loading %s (error %d)." % [_path, error])
		return
	_phase = Phase.LOADING


func _poll_load() -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_path, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if progress.size() > 0:
				_real_progress = clampf(float(progress[0]), 0.0, 1.0)
		ResourceLoader.THREAD_LOAD_LOADED:
			_real_progress = 1.0
			_loaded = true
		_:
			_fail("LoadingScreen: loading %s failed." % _path)
	# The bar never runs ahead of the minimum time, so it fills smoothly over the whole stay.
	_target_progress = minf(_real_progress, clampf(_elapsed / maxf(min_time, 0.01), 0.0, 1.0))


func _ease_bar(delta: float) -> void:
	_shown_progress = lerpf(_shown_progress, _target_progress, 1.0 - exp(-bar_ease_speed * delta))
	_bar.value = _shown_progress


func _begin_leaving() -> void:
	_phase = Phase.FADE_OUT
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, fade_out_time)
	tween.tween_callback(_switch_scene)


## Under full black: hand the loaded arena to the tree. It starts running only now.
func _switch_scene() -> void:
	var packed := ResourceLoader.load_threaded_get(_path) as PackedScene
	if packed == null:
		_go_to_menu("LoadingScreen: %s did not load as a PackedScene." % _path)
		return
	var error := get_tree().change_scene_to_packed(packed)
	if error != OK:
		_go_to_menu("LoadingScreen: could not switch to %s (error %d)." % [_path, error])


## The load failed: log it, fade to black, and go back to the main menu so the player is never stuck.
func _fail(message: String) -> void:
	if _phase == Phase.FAILED:
		return
	_phase = Phase.FAILED
	push_error(message)
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, fade_out_time)
	tween.tween_callback(_go_to_menu.bind(""))


func _go_to_menu(message: String) -> void:
	if not message.is_empty():
		push_error(message)
	get_tree().change_scene_to_file(SceneLoader.MAIN_MENU_SCENE)


# ---- Tips ----

func _setup_tips() -> void:
	_tips.load_file(tips_path, _arena_context(_path))
	if _tips.is_empty():
		_tip_block.visible = false
		push_warning("LoadingScreen: no tips found in %s." % tips_path)
		return
	_apply_tip()


## The arena category of the target scene as lowercase text (`fighting`, `movement`, `test`), or `any`.
func _arena_context(scene_path: String) -> String:
	for data: ArenaData in ArenaLibrary.all():
		if data.scene_path == scene_path:
			return str(ArenaData.Category.keys()[data.category]).to_lower()
	return "any"


func _update_tips(delta: float) -> void:
	if _tips.is_empty() or (_tip_tween != null and _tip_tween.is_running()):
		return
	_tip_timer += delta
	if _tip_timer >= tip_interval:
		_next_tip()


## Old tip fades out, the text swaps while it is invisible, the new one fades in.
func _next_tip() -> void:
	if _tips.is_empty() or (_tip_tween != null and _tip_tween.is_running()):
		return
	_tip_timer = 0.0
	_tip_tween = create_tween()
	_tip_tween.tween_property(_tip_block, "modulate:a", 0.0, tip_fade_time)
	_tip_tween.tween_callback(_apply_tip)
	_tip_tween.tween_property(_tip_block, "modulate:a", 1.0, tip_fade_time)


func _apply_tip() -> void:
	var tip := _tips.next()
	if tip == null:
		return
	_tip_title.text = tip.title
	_tip_title.visible = not tip.title.is_empty()
	_tip_text.text = tip.text


# ---- Background pictures ----

func _setup_backgrounds() -> void:
	_picture_a.modulate.a = 0.0
	_picture_b.modulate.a = 0.0
	_dim.visible = not backgrounds.is_empty()
	if backgrounds.is_empty():
		return
	_front_picture = _picture_a
	_picture_a.texture = backgrounds[0]
	_picture_a.modulate.a = 1.0
	_start_drift(_picture_a)


func _update_backgrounds(delta: float) -> void:
	if backgrounds.size() < 2:
		return
	_background_timer += delta
	if _background_timer < background_interval:
		return
	_background_timer = 0.0
	_background_index = (_background_index + 1) % backgrounds.size()
	var outgoing := _front_picture
	var incoming := _picture_b if outgoing == _picture_a else _picture_a
	incoming.texture = backgrounds[_background_index]
	incoming.modulate.a = 0.0
	move_child(incoming, outgoing.get_index() + 1)
	_start_drift(incoming)
	var tween := create_tween()
	tween.tween_property(incoming, "modulate:a", 1.0, background_fade_time)
	tween.tween_callback(func() -> void: outgoing.modulate.a = 0.0)
	_front_picture = incoming


## A very slow zoom so the picture never looks frozen.
func _start_drift(picture: TextureRect) -> void:
	picture.scale = Vector2.ONE
	_center_pivot(picture)
	if drift_zoom <= 0.0:
		return
	var duration := background_interval + background_fade_time * 2.0
	create_tween().tween_property(picture, "scale", Vector2.ONE * (1.0 + drift_zoom), duration)


func _center_pivot(picture: TextureRect) -> void:
	picture.pivot_offset = picture.size * 0.5


# ---- Layout ----

func _apply_scale() -> void:
	var s := size.y / REFERENCE_HEIGHT
	_scaler.apply(s)
	_tip_line.custom_minimum_size = Vector2(line_width * s, maxf(1.0, roundf(line_height * s)))
