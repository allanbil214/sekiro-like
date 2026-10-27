class_name ClipViewer
extends Node3D
## PLACEHOLDER(ER clip) tool, debug builds only (Phase 3a-3a): plays any converted Elden Ring clip on a figure of simple
## shapes, so the clips can be judged before anything uses them. Opened from the debug menu (F1, "Clip viewer"); it
## stands in the arena in front of the player, facing it. It has no link to gameplay.
## Keys: PageUp / PageDown = previous / next clip, Insert = pause, [ and ] = one frame back / forward (paused),
## Delete = loop on or off, Home = restart, End = play at the speed of the matching action (stretched to its length).

const MAPPED_ACTIONS: Dictionary = {
	"combo_1": "res://data/actions/player/attack_1.tres", "combo_2": "res://data/actions/player/attack_2.tres",
	"combo_3": "res://data/actions/player/attack_3.tres", "combo_4": "res://data/actions/player/attack_4.tres",
	"combo_5": "res://data/actions/player/attack_5.tres", "run_attack": "res://data/actions/player/dash_attack.tres",
	"crouch_attack": "res://data/actions/player/crouch_attack_a.tres", "air_light": "res://data/actions/player/air_attack_a.tres",
	"air_heavy": "res://data/actions/player/helm_splitter.tres",
	"backstep": "res://data/actions/player/dodge.tres", "roll_front": "res://data/actions/player/dodge.tres",
	"roll_back": "res://data/actions/player/dodge.tres", "roll_left": "res://data/actions/player/dodge.tres",
	"roll_right": "res://data/actions/player/dodge.tres",
}
const LOOPING: Array[String] = ["idle", "walk_front", "walk_back", "walk_left", "walk_right", "run_front", "sprint",
		"crouch_idle", "crouch_walk_front"]

@onready var _figure: MannequinFigure = $Figure
@onready var _text: Label = $Info/Text

var _clips: PlaceholderClips
var _names: PackedStringArray = PackedStringArray()
var _index: int = 0
var _time: float = 0.0
var _paused: bool = false
var _loop: bool = false
var _stretch: bool = false


func _ready() -> void:
	# Debug builds only: a release export never shows the viewer.
	if not OS.is_debug_build():
		queue_free()
		return
	_clips = PlaceholderClips.shared()
	if _clips == null:
		_text.text = "CLIP VIEWER: assets/placeholder/player_clips.bin is missing (see the Output panel)."
		return
	_figure.setup(_clips)
	_names = _clips.clip_names()
	_select(0)


func _process(delta: float) -> void:
	if _clips == null:
		return
	var clip_name := _names[_index]
	if not _paused:
		_time += delta * _speed(clip_name)
	var length := _clips.length_of(clip_name)
	if _loop and length > 0.0:
		_time = fposmod(_time, length)
	elif _time > length + 0.6:
		_time = 0.0  # hold the last pose for a moment, then play again
	_figure.show_pose(_clips.sample(clip_name, _time, _loop))
	_update_text(clip_name, length)


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if _clips == null or key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_PAGEUP:
			_select(_index - 1)
		KEY_PAGEDOWN:
			_select(_index + 1)
		KEY_INSERT:
			_paused = not _paused
		KEY_BRACKETLEFT:
			_paused = true
			_time = maxf(_time - 1.0 / PlaceholderClips.FPS, 0.0)
		KEY_BRACKETRIGHT:
			_paused = true
			_time += 1.0 / PlaceholderClips.FPS
		KEY_DELETE:
			_loop = not _loop
		KEY_HOME:
			_time = 0.0
		KEY_END:
			_stretch = not _stretch
		_:
			return
	get_viewport().set_input_as_handled()


func _select(index: int) -> void:
	_index = posmod(index, _names.size())
	_time = 0.0
	_loop = _names[_index] in LOOPING


## The playback speed: 1, or (with End) the clip's length over the matching action's duration, so the clip fits the action.
func _speed(clip_name: String) -> float:
	var action := _action_of(clip_name)
	if not _stretch or action == null or action.duration <= 0.0:
		return 1.0
	return _clips.length_of(clip_name) / action.duration


func _action_of(clip_name: String) -> ActionData:
	if not MAPPED_ACTIONS.has(clip_name):
		return null
	return load(MAPPED_ACTIONS[clip_name] as String) as ActionData


func _update_text(clip_name: String, length: float) -> void:
	var action := _action_of(clip_name)
	var lines := PackedStringArray()
	lines.append("CLIP VIEWER   %d / %d   %s" % [_index + 1, _names.size(), clip_name])
	lines.append("source %s   %d frames   %.2f s   time %.2f s" % [_clips.source_of(clip_name), _clips.frame_count(clip_name), length, _time])
	if action != null:
		lines.append("matches %s (%.2f s)   stretch to it: %s (x%.2f)" % [
				action.resource_path.get_file(), action.duration, "ON" if _stretch else "off", _speed(clip_name)])
	else:
		lines.append("no matching action yet")
	lines.append("%s   loop %s" % ["PAUSED" if _paused else "playing", "on" if _loop else "off"])
	lines.append("PgUp/PgDn clip   Ins pause   [ ] frame   Del loop   Home restart   End stretch")
	_text.text = "\n".join(lines)
