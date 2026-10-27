class_name DebugOptions
extends RefCounted
## The registry behind the debug menu (Phase 3a-4). One `Option` per debug switch: a group, a label, and a
## getter and setter that read and write the live object. ADD A NEW DEBUG OPTION as one line in `build()`.
## A toggle's value is a bool; a choice's value is the index into `choices`.
## Values the user changed in the menu are remembered for the session (static) and re-applied when the
## next arena loads, so a toggle survives an arena change. Nothing is saved to disk.

class Option extends RefCounted:
	var id: StringName
	var group: String
	var label: String
	## Empty = a toggle (bool). Otherwise the names of the choices (int index).
	var choices: PackedStringArray
	var getter: Callable
	var setter: Callable

	func is_toggle() -> bool:
		return choices.is_empty()

	func get_value() -> Variant:
		return getter.call()

	func set_value(value: Variant) -> void:
		setter.call(value)


## id -> value, for the options the user changed in the menu this session.
static var _remembered: Dictionary = {}


static func remember(id: StringName, value: Variant) -> void:
	_remembered[id] = value


static func has_remembered(id: StringName) -> bool:
	return _remembered.has(id)


static func get_remembered(id: StringName) -> Variant:
	return _remembered[id]


## Every option, bound to this player. Order = the order in the menu; a new group starts a new header.
static func build(player: Player) -> Array[Option]:
	var list: Array[Option] = []
	var overlay := player.get_node_or_null("DebugOverlay") as DebugOverlay
	var feel := player.get_node_or_null("FeelOverlay") as FeelOverlay

	# --- VIEW ---
	if feel != null:
		list.append(_toggle(&"feel_overlay", "VIEW", "Feel overlay (F2)",
				func() -> bool: return feel.is_shown(),
				func(on: bool) -> void: feel.set_shown(on)))
	if overlay != null:
		list.append(_toggle(&"debug_text", "VIEW", "Debug text",
				func() -> bool: return overlay.show_debug_text,
				func(on: bool) -> void: overlay.show_debug_text = on))
		list.append(_toggle(&"wall_range", "VIEW", "Wall range ring",
				func() -> bool: return overlay.show_wall_range,
				func(on: bool) -> void: overlay.show_wall_range = on))
		list.append(_toggle(&"ledge_marker", "VIEW", "Ledge marker",
				func() -> bool: return overlay.show_ledge_marker,
				func(on: bool) -> void: overlay.show_ledge_marker = on))
	list.append(_toggle(&"hitbox_draw", "VIEW", "Hitbox drawing (player and enemies)",
			func() -> bool: return _any_hitbox_drawn(player),
			func(on: bool) -> void: _set_hitbox_draw(player, on)))
	list.append(_toggle(&"sight_cones", "VIEW", "Guard sight cones (F3)",
			func() -> bool: return EnemyAwareness.show_debug_cones,
			func(on: bool) -> void: EnemyAwareness.show_debug_cones = on))

	# --- PLAYER ---
	list.append(_toggle(&"undetectable", "PLAYER", "Undetectable (F4)",
			func() -> bool: return player.debug_undetectable,
			func(on: bool) -> void: player.debug_undetectable = on))

	# --- ENEMIES (apply to the enemies in the arena when you change them) ---
	list.append(_choice(&"force_perilous", "ENEMIES", "Forced perilous attack",
			PackedStringArray(["None", "Thrust", "Sweep", "Grab"]),
			func() -> int: return _first_enemy_perilous(),
			func(index: int) -> void: _set_enemy_perilous(index)))
	list.append(_toggle(&"enemy_log", "ENEMIES", "Enemy debug log",
			func() -> bool: return _first_enemy_log(),
			func(on: bool) -> void: _set_enemy_log(on)))
	return list


static func _toggle(id: StringName, group: String, label: String, getter: Callable, setter: Callable) -> Option:
	var option := Option.new()
	option.id = id
	option.group = group
	option.label = label
	option.getter = getter
	option.setter = setter
	return option


static func _choice(id: StringName, group: String, label: String, choices: PackedStringArray,
		getter: Callable, setter: Callable) -> Option:
	var option := _toggle(id, group, label, getter, setter)
	option.choices = choices
	return option


static func _enemies() -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node: Node3D in Enemies.all():
		var enemy := node as Enemy
		if enemy != null:
			found.append(enemy)
	return found


static func _any_hitbox_drawn(player: Player) -> bool:
	if player.sword_visual != null and player.sword_visual.hitbox != null:
		return player.sword_visual.hitbox.debug_draw
	return false


static func _set_hitbox_draw(player: Player, on: bool) -> void:
	if player.sword_visual != null and player.sword_visual.hitbox != null:
		player.sword_visual.hitbox.debug_draw = on
	for enemy: Enemy in _enemies():
		if enemy.sword_visual != null and enemy.sword_visual.hitbox != null:
			enemy.sword_visual.hitbox.debug_draw = on


static func _first_enemy_perilous() -> int:
	var found := _enemies()
	return found[0].debug_force_perilous if not found.is_empty() else 0


static func _set_enemy_perilous(index: int) -> void:
	for enemy: Enemy in _enemies():
		enemy.debug_force_perilous = index


static func _first_enemy_log() -> bool:
	var found := _enemies()
	return found[0].debug_log if not found.is_empty() else false


static func _set_enemy_log(on: bool) -> void:
	for enemy: Enemy in _enemies():
		enemy.debug_log = on
