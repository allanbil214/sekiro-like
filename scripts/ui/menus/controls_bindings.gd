class_name ControlsBindings
extends RefCounted
## Rebinding the Input Map (Phase 2, item 6b). Static, no autoload; the Options menu's Controls pages use it
## and `Settings` calls `capture_defaults()`, `load_from()` and `save_to()`.
##
## Each rebindable action has two slots: KEYBOARD (one key or mouse button) and PAD (one controller button).
## Changing a slot replaces only the events of that kind, so the left stick on the move actions and every
## other event stay as they are. A binding is passed around as a small Array so it compares and saves
## easily: ["key", physical_keycode], ["mouse", button_index] or ["pad", button_index]. Keys are stored by
## physical position (like the Input Map in the project), so they do not depend on the keyboard layout.
## Reserved and never rebindable: Esc (pause and cancel), the controller's Start (pause) and Guide button,
## the mouse wheel, the sticks and triggers, and the `ui_*` menu actions. Gameplay code is untouched: it
## reads action names through `Actions`.
## The project's own bindings are recorded once (`capture_defaults()`, before anything is changed) so a reset
## needs no second table, and only the bindings that differ from them are written to the settings file.

enum Slot { KEYBOARD, PAD }

## The actions of each page, in the order they are listed. The move actions have no PAD slot (the left
## stick is fixed); look has none at all (the mouse and the right stick are fixed).
const KEYBOARD_ACTIONS: Array[StringName] = [
	Actions.MOVE_FORWARD, Actions.MOVE_BACK, Actions.MOVE_LEFT, Actions.MOVE_RIGHT,
	Actions.JUMP, Actions.DODGE, Actions.ATTACK, Actions.GUARD, Actions.HEAL,
	Actions.LOCK_ON, Actions.CROUCH, Actions.INTERACT, Actions.SHEATHE, Actions.REVERSE_BLADE,
	Actions.USE_ITEM, Actions.CYCLE_ITEM, Actions.TAUNT,
]
const PAD_ACTIONS: Array[StringName] = [
	Actions.JUMP, Actions.DODGE, Actions.ATTACK, Actions.GUARD, Actions.HEAL,
	Actions.LOCK_ON, Actions.CROUCH, Actions.INTERACT, Actions.SHEATHE, Actions.REVERSE_BLADE,
	Actions.USE_ITEM, Actions.CYCLE_ITEM, Actions.TAUNT,
]

const SECTION: String = "controls"

## Controller button names (Xbox first, PlayStation in brackets).
const PAD_NAMES: Dictionary = {
	0: "A (CROSS)", 1: "B (CIRCLE)", 2: "X (SQUARE)", 3: "Y (TRIANGLE)", 4: "BACK (SHARE)",
	7: "LEFT STICK CLICK (L3)", 8: "RIGHT STICK CLICK (R3)", 9: "LB (L1)", 10: "RB (R1)",
	11: "D-PAD UP", 12: "D-PAD DOWN", 13: "D-PAD LEFT", 14: "D-PAD RIGHT",
}

static var _defaults: Dictionary = {}


## Record the project's bindings. Call once before any binding is changed (`Settings.ensure_loaded()` does).
static func capture_defaults() -> void:
	if not _defaults.is_empty():
		return
	for slot: Slot in [Slot.KEYBOARD, Slot.PAD]:
		for action: StringName in actions_for(slot):
			_defaults[_id(action, slot)] = current(action, slot)


static func actions_for(slot: Slot) -> Array[StringName]:
	return KEYBOARD_ACTIONS if slot == Slot.KEYBOARD else PAD_ACTIONS


## "MOVE_FORWARD" -> "MOVE FORWARD".
static func title(action: StringName) -> String:
	return String(action).replace("_", " ").to_upper()


## The action's binding in a slot (an empty Array if it has none).
static func current(action: StringName, slot: Slot) -> Array:
	if not InputMap.has_action(action):
		return []
	for event: InputEvent in InputMap.action_get_events(action):
		if _is_slot_event(event, slot):
			return encode(event)
	return []


## The binding an input event would make in a slot, or an empty Array if that input cannot be used there
## (the wrong kind of input, Esc, the wheel, Start, Guide).
static func from_event(event: InputEvent, slot: Slot) -> Array:
	if not _is_slot_event(event, slot):
		return []
	var data := encode(event)
	return data if decode(data) != null else []


## Bind `data` to the action. If another action of the same slot already uses it, that action gets this
## action's old binding (a swap) and its name is returned; otherwise an empty StringName.
static func set_binding(action: StringName, slot: Slot, data: Array) -> StringName:
	var old := current(action, slot)
	var swapped: StringName = &""
	for other: StringName in actions_for(slot):
		if other != action and current(other, slot) == data:
			if not old.is_empty():
				_apply(other, slot, old)
			swapped = other
			break
	_apply(action, slot, data)
	return swapped


## Put every action of the slot back on the project's binding.
static func reset(slot: Slot) -> void:
	for action: StringName in actions_for(slot):
		var data: Array = _defaults.get(_id(action, slot), [])
		if not data.is_empty():
			_apply(action, slot, data)


## The text shown on a row: "SPACE", "LEFT CLICK", "A (CROSS)".
static func text_for(data: Array) -> String:
	if data.size() < 2:
		return "NONE"
	var code: int = int(data[1])
	match String(data[0]):
		"key":
			var keycode: Key = DisplayServer.keyboard_get_keycode_from_physical(code as Key)
			var text := OS.get_keycode_string(keycode)
			if text.is_empty():
				text = OS.get_keycode_string(code as Key)
			return text.to_upper() if not text.is_empty() else "KEY %d" % code
		"mouse":
			match code:
				MOUSE_BUTTON_LEFT:
					return "LEFT CLICK"
				MOUSE_BUTTON_RIGHT:
					return "RIGHT CLICK"
				MOUSE_BUTTON_MIDDLE:
					return "MIDDLE CLICK"
				MOUSE_BUTTON_XBUTTON1:
					return "MOUSE BUTTON 4"
				MOUSE_BUTTON_XBUTTON2:
					return "MOUSE BUTTON 5"
			return "MOUSE BUTTON %d" % code
		"pad":
			return String(PAD_NAMES.get(code, "BUTTON %d" % code))
	return "NONE"


## Write the bindings that differ from the project's.
static func save_to(config: ConfigFile) -> void:
	for slot: Slot in [Slot.KEYBOARD, Slot.PAD]:
		for action: StringName in actions_for(slot):
			var id := _id(action, slot)
			var data := current(action, slot)
			if not _defaults.has(id) or data != _defaults[id]:
				config.set_value(SECTION, id, data)


## Apply the saved bindings (a missing or unusable entry keeps the project's binding).
static func load_from(config: ConfigFile) -> void:
	for slot: Slot in [Slot.KEYBOARD, Slot.PAD]:
		for action: StringName in actions_for(slot):
			var id := _id(action, slot)
			if not config.has_section_key(SECTION, id):
				continue
			var value: Variant = config.get_value(SECTION, id)
			if value is Array and decode(value) != null:
				_apply(action, slot, value as Array)


static func encode(event: InputEvent) -> Array:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return ["key", code]
	if event is InputEventMouseButton:
		return ["mouse", (event as InputEventMouseButton).button_index]
	if event is InputEventJoypadButton:
		return ["pad", (event as InputEventJoypadButton).button_index]
	return []


## The InputEvent for a binding, or null if it is malformed or not allowed (Esc, the wheel, Start, Guide).
static func decode(data: Variant) -> InputEvent:
	if not data is Array:
		return null
	var list: Array = data
	if list.size() < 2:
		return null
	var code: int = int(list[1])
	match String(list[0]):
		"key":
			if code <= 0 or code == KEY_ESCAPE:
				return null
			var key := InputEventKey.new()
			key.physical_keycode = code as Key
			return key
		"mouse":
			if code != MOUSE_BUTTON_LEFT and code != MOUSE_BUTTON_RIGHT and code != MOUSE_BUTTON_MIDDLE \
					and code != MOUSE_BUTTON_XBUTTON1 and code != MOUSE_BUTTON_XBUTTON2:
				return null
			var click := InputEventMouseButton.new()
			click.button_index = code as MouseButton
			return click
		"pad":
			if code < 0 or code > JOY_BUTTON_DPAD_RIGHT or code == JOY_BUTTON_GUIDE or code == JOY_BUTTON_START:
				return null
			var button := InputEventJoypadButton.new()
			button.button_index = code as JoyButton
			return button
	return null


static func _is_slot_event(event: InputEvent, slot: Slot) -> bool:
	if slot == Slot.PAD:
		return event is InputEventJoypadButton
	return event is InputEventKey or event is InputEventMouseButton


## Replace the action's events of that slot with the binding.
static func _apply(action: StringName, slot: Slot, data: Array) -> void:
	var event := decode(data)
	if event == null or not InputMap.has_action(action):
		return
	for old: InputEvent in InputMap.action_get_events(action):
		if _is_slot_event(old, slot):
			InputMap.action_erase_event(action, old)
	InputMap.action_add_event(action, event)


static func _id(action: StringName, slot: Slot) -> String:
	return "%s_%s" % [action, "kb" if slot == Slot.KEYBOARD else "pad"]
