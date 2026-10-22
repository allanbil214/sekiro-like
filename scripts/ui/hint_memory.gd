class_name HintMemory
extends RefCounted
## What the player has already seen of the traversal hints (Phase 2 item 16 extras, the FIRST TIMES mode).
## A hint is known by a key made of the state it belongs to and its text ("ledgehang_leap"). Each time a hint
## has stayed on screen for `MIN_VISIBLE_TIME` seconds during one stay in a state, its count goes up by one;
## in FIRST TIMES mode (`Settings.traversal_hints_mode`) a hint with `SHOWS_BEFORE_HIDDEN` counts is not shown
## any more. The counts are kept in `user://settings.cfg` (section `hints_seen`), written by `Settings.save()`;
## Options > Gameplay > RESET HINTS clears them. Static, no node.

const SECTION: String = "hints_seen"
## How many times a hint must have been seen before FIRST TIMES hides it (placeholder, tune by playing).
const SHOWS_BEFORE_HIDDEN: int = 3
## Seconds a hint must stay on screen to count as one time (placeholder).
const MIN_VISIBLE_TIME: float = 1.0

static var _counts: Dictionary = {}


## The key of a hint: the state's name and the hint's text, lowercase, with underscores for spaces.
static func key_for(context: StringName, text: String) -> String:
	return ("%s_%s" % [context, text]).to_lower().replace(" ", "_")


static func is_learned(key: String) -> bool:
	return int(_counts.get(key, 0)) >= SHOWS_BEFORE_HIDDEN


## Counts one more time and saves the settings file.
static func note_seen(key: String) -> void:
	_counts[key] = int(_counts.get(key, 0)) + 1
	Settings.save()


## Forgets everything (the caller saves).
static func reset() -> void:
	_counts.clear()


static func load_from(config: ConfigFile) -> void:
	_counts.clear()
	if not config.has_section(SECTION):
		return
	for key: String in config.get_section_keys(SECTION):
		_counts[key] = maxi(int(config.get_value(SECTION, key, 0)), 0)


static func save_to(config: ConfigFile) -> void:
	for key: String in _counts:
		config.set_value(SECTION, key, int(_counts[key]))
