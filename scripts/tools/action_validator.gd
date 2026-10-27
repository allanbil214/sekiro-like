@tool
class_name ActionValidator
extends RefCounted
## Checks an ActionData for broken timing (Phase 3a). Warnings only: nothing here blocks anything.
## Used by the Inspector line on ActionData ("Validation"), by the feel overlay, and by a one-time scan of
## `res://data/actions` when a debug build starts (the editor counts as one).

const EPS: float = 0.001
const ACTIONS_FOLDER: String = "res://data/actions"

## True once the startup scan has run in this session, so a second Player does not scan again.
static var scanned: bool = false


## Every problem found in the action, one short sentence each. Empty = nothing to report.
static func check(a: ActionData) -> PackedStringArray:
	var w := PackedStringArray()
	if a == null:
		return w
	if a.duration <= 0.0:
		w.append("duration is 0 or less")
	if a.speed_scale <= 0.0:
		w.append("speed_scale is 0 or less (the clock never runs)")
	if a.locked_until < 0.0:
		w.append("locked_until is negative")
	elif a.duration > 0.0 and a.locked_until > a.duration + EPS:
		w.append("locked_until (%.2f) is past the duration (%.2f)" % [a.locked_until, a.duration])
	var windows: Array = [
		["cancel_window", a.cancel_window],
		["buffer_window", a.buffer_window],
		["active_hit", a.active_hit],
		["iframes", a.iframes],
		["move_window", a.move_window],
	]
	for entry: Array in windows:
		var label: String = entry[0]
		var window: Vector2 = entry[1]
		if window == Vector2.ZERO:
			continue
		if window.y < window.x:
			w.append("%s ends (%.2f) before it starts (%.2f)" % [label, window.y, window.x])
		if window.x < 0.0:
			w.append("%s starts before 0" % label)
		if a.duration > 0.0 and window.y > a.duration + EPS:
			w.append("%s ends at %.2f, after the duration (%.2f)" % [label, window.y, a.duration])
	if a.cancel_window != Vector2.ZERO and a.cancel_window.x < a.locked_until - EPS:
		w.append("cancel_window starts at %.2f, before locked_until (%.2f); it cannot open before the lock ends"
				% [a.cancel_window.x, a.locked_until])
	# No rule for "active_hit set but damage 0": the deathblows and the helm splitter landing do that on purpose.
	if a.kind == ActionData.Kind.ATTACK and a.damage > 0.0 and a.active_hit == Vector2.ZERO:
		w.append("an attack with damage but no active_hit window (it never hits)")
	if a.move_speed > 0.0 and a.move_window == Vector2.ZERO:
		w.append("move_speed is set but move_window is empty (no movement happens)")
	_check_feel_fields(a, w)
	_check_turn_fields(a, w)
	if a.hitstop < 0.0:
		w.append("hitstop is negative")
	if a.knockback < 0.0:
		w.append("knockback is negative")
	return w


## The 3b-1 fields: -1 is off; a set time must lie inside the action, and a cancel time inside the hit window can
## only fire once the window closes.
static func _check_feel_fields(a: ActionData, w: PackedStringArray) -> void:
	var fields: Array = [
		["input_from", a.input_from], ["cancel_attack", a.cancel_attack], ["cancel_dodge", a.cancel_dodge],
		["cancel_jump", a.cancel_jump], ["cancel_guard", a.cancel_guard], ["cancel_move", a.cancel_move],
		["cancel_item", a.cancel_item],
	]
	for entry: Array in fields:
		var label: String = entry[0]
		var value: float = entry[1]
		if value < 0.0:
			if not is_equal_approx(value, -1.0):
				w.append("%s is %.2f (use -1 for off)" % [label, value])
			continue
		if a.duration > 0.0 and value > a.duration + EPS:
			w.append("%s (%.2f) is past the duration (%.2f)" % [label, value, a.duration])
		if label != "input_from" and a.kind == ActionData.Kind.ATTACK and a.active_hit != Vector2.ZERO \
				and value >= a.active_hit.x and value < a.active_hit.y - EPS:
			w.append("%s (%.2f) is inside the hit window; it can only fire once the window closes (%.2f)"
					% [label, value, a.active_hit.y])


## The 3b-2 turn fields: spans inside the action, from before to, no negative rates, overrides that do not overlap
## each other, and a note when a no-turn span hides an override. Only player attacks read these fields.
static func _check_turn_fields(a: ActionData, w: PackedStringArray) -> void:
	if a.turn_rate < 0.0 and not is_equal_approx(a.turn_rate, -1.0):
		w.append("turn_rate is %.0f (use -1 for off)" % a.turn_rate)
	if a.turn_rate >= 0.0 or not a.no_turn.is_empty() or not a.turn_overrides.is_empty():
		if a.kind != ActionData.Kind.ATTACK:
			w.append("turn fields are set on a non-attack action (only player ground and air attacks read them)")
	for span: Vector2 in a.no_turn:
		if span.y <= span.x:
			w.append("no_turn span (%.2f, %.2f) ends before it starts" % [span.x, span.y])
		if span.x < 0.0:
			w.append("no_turn span starts before 0 (%.2f)" % span.x)
		if a.duration > 0.0 and span.y > a.duration + EPS:
			w.append("no_turn span ends at %.2f, after the duration (%.2f)" % [span.y, a.duration])
	for i in a.turn_overrides.size():
		var entry := a.turn_overrides[i]
		if entry.y <= entry.x:
			w.append("turn_overrides[%d] (%.2f, %.2f) ends before it starts" % [i, entry.x, entry.y])
		if entry.x < 0.0:
			w.append("turn_overrides[%d] starts before 0 (%.2f)" % [i, entry.x])
		if entry.z < 0.0:
			w.append("turn_overrides[%d] has a negative rate (%.0f)" % [i, entry.z])
		if a.duration > 0.0 and entry.y > a.duration + EPS:
			w.append("turn_overrides[%d] ends at %.2f, after the duration (%.2f)" % [i, entry.y, a.duration])
		for j in range(i + 1, a.turn_overrides.size()):
			var other := a.turn_overrides[j]
			if entry.x < other.y and other.x < entry.y:
				w.append("turn_overrides[%d] and [%d] overlap (the first one wins)" % [i, j])
		for span: Vector2 in a.no_turn:
			if entry.x >= span.x and entry.y <= span.y + EPS:
				w.append("turn_overrides[%d] lies inside a no_turn span (no_turn wins, the override does nothing)" % i)
				break


## The text for the Inspector: "OK", or a count and one line per problem.
static func report(a: ActionData) -> String:
	var found := check(a)
	if found.is_empty():
		return "OK"
	return "%d warning(s):\n- %s" % [found.size(), "\n- ".join(found)]


## Loads every ActionData under `folder` (recursively) once per session and prints a warning for each
## problem. Debug builds only; a release export skips it.
static func scan_once(folder: String = ACTIONS_FOLDER) -> void:
	if scanned or not OS.is_debug_build():
		return
	scanned = true
	var counts := [0, 0]
	_scan_folder(folder, counts)
	print("[ActionValidator] %d action(s) checked, %d warning(s)." % counts)


static func _scan_folder(folder: String, counts: Array) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_scan_folder(folder.path_join(sub), counts)
	for file: String in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var path := folder.path_join(file)
		var action := load(path) as ActionData
		if action == null:
			continue
		counts[0] += 1
		for message: String in check(action):
			counts[1] += 1
			push_warning("[ActionValidator] %s: %s" % [path.trim_prefix("res://"), message])
