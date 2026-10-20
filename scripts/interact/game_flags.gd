class_name GameFlags
extends RefCounted
## A small in-memory flag store (Phase 2 item 8). A door's lock, a switch and later the quests read
## and write flags here. Kept across the death reload, cleared when the main menu opens. Phase 4 adds
## saving and loading to this class without changing any door.

## The reversed blade (Phase 2 item 10) is a flag too.
const BLADE_REVERSED: StringName = &"blade_reversed"

static var _flags: Dictionary = {}


static func set_flag(flag: StringName, value: bool = true) -> void:
	if value:
		_flags[flag] = true
	else:
		_flags.erase(flag)


static func has_flag(flag: StringName) -> bool:
	return _flags.has(flag)


static func toggle_flag(flag: StringName) -> bool:
	set_flag(flag, not has_flag(flag))
	return has_flag(flag)


static func clear() -> void:
	_flags.clear()
