class_name PlaceholderClips
extends RefCounted
## PLACEHOLDER(ER clip): loads `assets/placeholder/player_clips.bin`, the Elden Ring clips of the Bevy sandbox that
## `tools/placeholder/convert_clips.py` converted (docs/placeholders.md, P2 and P3; docs/phase-3-plan.md, section 10).
## A clip is the position of every joint per frame at 30 fps (model space, metres, feet near y = 0, the character
## faces -Z) plus the X, Y and Z axes of the Head and the two weapon points. `sample()` gives the interpolated pose at
## a time. Nothing here touches gameplay: the clock stays `ActionData`'s.
## Deleting `assets/placeholder/` removes every Elden Ring clip; `shared()` then returns null and the callers do nothing.

const PATH: String = "res://assets/placeholder/player_clips.bin"
const FPS: float = 30.0

## One sampled moment: `points` follows `joint_names`; `axes` holds three unit vectors (X, Y, Z) per entry of
## `oriented_names`, in that order. The weapon joints' Y axis runs along the blade; the Head's Z axis faces forward.
class Pose extends RefCounted:
	var points: PackedVector3Array = PackedVector3Array()
	var axes: PackedVector3Array = PackedVector3Array()


class Clip extends RefCounted:
	var name: String = ""
	## The sandbox's own id of the clip (for the register and for debugging).
	var source: String = ""
	## The sandbox's blend length in frames (a hint for later, not used yet).
	var blend: float = 0.0
	var frames: int = 0
	var data: PackedFloat32Array = PackedFloat32Array()


static var _shared: PlaceholderClips
static var _tried: bool = false

var joint_names: PackedStringArray = PackedStringArray()
var oriented_names: PackedStringArray = PackedStringArray()
var _clips: Dictionary = {}
var _order: PackedStringArray = PackedStringArray()
var _stride: int = 0


## The one loaded library, or null when the file is missing (the first call loads it).
static func shared() -> PlaceholderClips:
	if not _tried:
		_tried = true
		_shared = load_file(PATH)
	return _shared


static func load_file(path: String) -> PlaceholderClips:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[PlaceholderClips] %s not found (run tools/placeholder/convert_clips.py)" % path)
		return null
	if file.get_buffer(4).get_string_from_ascii() != "PCLP":
		push_warning("[PlaceholderClips] %s is not a clip file" % path)
		return null
	var version := file.get_32()
	if version != 1:
		push_warning("[PlaceholderClips] %s has version %d, expected 1" % [path, version])
		return null
	var library := PlaceholderClips.new()
	var joint_count := file.get_32()
	var oriented_count := file.get_32()
	var clip_count := file.get_32()
	for i in joint_count:
		library.joint_names.append(_read_name(file))
	for i in oriented_count:
		library.oriented_names.append(_read_name(file))
	library._stride = joint_count * 3 + oriented_count * 9
	for i in clip_count:
		var clip := Clip.new()
		clip.name = _read_name(file)
		clip.source = _read_name(file)
		clip.blend = file.get_float()
		clip.frames = file.get_32()
		clip.data = file.get_buffer(clip.frames * library._stride * 4).to_float32_array()
		library._clips[clip.name] = clip
		library._order.append(clip.name)
	return library


static func _read_name(file: FileAccess) -> String:
	var length := file.get_8()
	return file.get_buffer(length).get_string_from_utf8()


## Every clip name, in the file's order.
func clip_names() -> PackedStringArray:
	return _order


func has_clip(clip_name: String) -> bool:
	return _clips.has(clip_name)


## The index of a joint in `Pose.points`, or -1.
func joint_index(joint: String) -> int:
	return joint_names.find(joint)


## The index of an oriented joint (Head, R_Weapon, L_Weapon): its axes are `Pose.axes[index * 3 + 0..2]`. -1 if unknown.
func oriented_index(joint: String) -> int:
	return oriented_names.find(joint)


func source_of(clip_name: String) -> String:
	var clip := _clips.get(clip_name) as Clip
	return clip.source if clip != null else ""


func frame_count(clip_name: String) -> int:
	var clip := _clips.get(clip_name) as Clip
	return clip.frames if clip != null else 0


## The clip's length in seconds (first frame to last frame).
func length_of(clip_name: String) -> float:
	var clip := _clips.get(clip_name) as Clip
	if clip == null or clip.frames < 2:
		return 0.0
	return float(clip.frames - 1) / FPS


## The pose at `time` seconds (frames blended linearly). Past the end it holds the last pose, or wraps when `loop`.
## Returns null for an unknown clip.
func sample(clip_name: String, time: float, loop: bool = false) -> Pose:
	var clip := _clips.get(clip_name) as Clip
	if clip == null or clip.frames == 0:
		return null
	var frame_time := time * FPS
	if loop:
		frame_time = fposmod(frame_time, float(clip.frames))
	frame_time = clampf(frame_time, 0.0, float(clip.frames - 1))
	var f0 := int(floorf(frame_time))
	var f1 := mini(f0 + 1, clip.frames - 1)
	if loop and f0 == clip.frames - 1:
		f1 = 0
	var weight := frame_time - float(f0)
	var pose := Pose.new()
	var joint_count := joint_names.size()
	pose.points.resize(joint_count)
	for j in joint_count:
		pose.points[j] = _vector(clip, f0, j * 3).lerp(_vector(clip, f1, j * 3), weight)
	var axis_count := oriented_names.size() * 3
	pose.axes.resize(axis_count)
	for a in axis_count:
		var offset := joint_count * 3 + a * 3
		pose.axes[a] = _vector(clip, f0, offset).lerp(_vector(clip, f1, offset), weight).normalized()
	return pose


func _vector(clip: Clip, frame: int, offset: int) -> Vector3:
	var at := frame * _stride + offset
	return Vector3(clip.data[at], clip.data[at + 1], clip.data[at + 2])
