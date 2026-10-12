class_name ArenaLibrary
extends RefCounted
## Finds the `ArenaData` resources (Phase 2, item 3b) in `res://arenas/` and applies the visibility
## rule: a debug build lists every arena, a release build lists only the ones that are not `debug_only`.
## The result is sorted by category, then `sort_order`, then name.

const FOLDER: String = "res://arenas"


## Every arena resource in the folder, sorted (visibility is not applied).
static func all() -> Array[ArenaData]:
	var result: Array[ArenaData] = []
	var dir := DirAccess.open(FOLDER)
	if dir == null:
		push_warning("ArenaLibrary: cannot open %s." % FOLDER)
		return result
	for file_name: String in dir.get_files():
		# An exported project lists resources as "name.tres.remap" (or "name.res"): strip the remap.
		var clean := file_name.trim_suffix(".remap")
		var extension := clean.get_extension()
		if extension != "tres" and extension != "res":
			continue
		var data := load(FOLDER.path_join(clean)) as ArenaData
		if data == null:
			continue
		if data.scene_path.is_empty():
			push_warning("ArenaLibrary: %s has no scene path, skipped." % clean)
			continue
		result.append(data)
	result.sort_custom(_is_before)
	return result


## The arenas this build lists.
static func visible_arenas() -> Array[ArenaData]:
	var debug := OS.is_debug_build()
	var result: Array[ArenaData] = []
	for data: ArenaData in all():
		if debug or not data.debug_only:
			result.append(data)
	return result


## True if this build lists at least one arena (the ARENAS entry shows only then).
static func has_visible() -> bool:
	return not visible_arenas().is_empty()


static func _is_before(a: ArenaData, b: ArenaData) -> bool:
	if a.category != b.category:
		return a.category < b.category
	if a.sort_order != b.sort_order:
		return a.sort_order < b.sort_order
	return a.display_name.naturalnocasecmp_to(b.display_name) < 0
