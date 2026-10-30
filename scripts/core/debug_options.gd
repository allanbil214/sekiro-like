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

	list.append(_choice(&"slow_motion", "VIEW", "Slow motion (to watch swings and hitboxes)",
			PackedStringArray(["Off", "50%", "25%", "10%"]),
			func() -> int: return _slowmo_index(),
			func(index: int) -> void: _set_slowmo(index)))

	# --- FEEL (Phase 3b) ---
	list.append(_toggle(&"er_feel", "FEEL", "Elden Ring-like feel (test values on attack 1 to 5)",
			func() -> bool: return ActionData.er_feel_enabled,
			func(on: bool) -> void: ActionData.er_feel_enabled = on))

	# --- PLACEHOLDER CLIPS (Phase 3a-3a) ---
	list.append(_toggle(&"clip_viewer", "PLACEHOLDER", "Clip viewer (the converted Elden Ring clips, in front of you)",
			func() -> bool: return is_instance_valid(_clip_viewer),
			func(on: bool) -> void: _set_clip_viewer(player, on)))

	list.append(_toggle(&"mannequin_figure", "PLACEHOLDER", "Mannequin figure (player and enemies; off = the capsule)",
			func() -> bool: return player.is_figure_shown(),
			func(on: bool) -> void: _set_figure_shown(player, on)))

	list.append(_toggle(&"clips_drive_figure", "PLACEHOLDER", "Clips drive the figure (player attacks; off = held pose and the code sword)",
			func() -> bool: return PlayerFigure.clips_enabled,
			func(on: bool) -> void: PlayerFigure.clips_enabled = on))

	list.append(_toggle(&"locomotion_clips", "PLACEHOLDER", "Locomotion clips (walk, run, sprint, crouch on the player and enemies; off = held pose)",
			func() -> bool: return PlayerFigure.locomotion_enabled,
			func(on: bool) -> void: PlayerFigure.locomotion_enabled = on))

	list.append(_toggle(&"frame_footsteps", "PLACEHOLDER", "Frame-driven footsteps (on the clips' foot plants, player and enemies; off = the old distance steps)",
			func() -> bool: return PlayerFigure.frame_footsteps_enabled,
			func(on: bool) -> void: PlayerFigure.frame_footsteps_enabled = on))

	list.append(_toggle(&"foot_placement", "PLACEHOLDER", "Foot placement (legs fitted to stairs and slopes, player and enemies; off = the clips' own legs)",
			func() -> bool: return PlayerFigure.foot_placement_enabled,
			func(on: bool) -> void: PlayerFigure.foot_placement_enabled = on))

	list.append(_toggle(&"figure_shadow", "PLACEHOLDER", "Figure shadow (the mannequin's shapes cast a real shadow)",
			func() -> bool: return PlayerFigure.shadow_enabled,
			func(on: bool) -> void: PlayerFigure.shadow_enabled = on))

	list.append(_toggle(&"blob_shadow", "PLACEHOLDER", "Blob shadow (a soft dark disc on the ground under the figure)",
			func() -> bool: return PlayerFigure.blob_enabled,
			func(on: bool) -> void: PlayerFigure.blob_enabled = on))

	# --- PLAYER ---
	list.append(_toggle(&"undetectable", "PLAYER", "Undetectable (F4)",
			func() -> bool: return player.debug_undetectable,
			func(on: bool) -> void: player.debug_undetectable = on))

	# --- ENEMIES (apply to the enemies in the arena when you change them) ---
	list.append(_choice(&"force_perilous", "ENEMIES", "Forced perilous attack",
			PackedStringArray(["None", "Thrust", "Sweep", "Grab"]),
			func() -> int: return _first_enemy_perilous(),
			func(index: int) -> void: _set_enemy_perilous(index)))
	list.append(_choice(&"dummy_strength", "ENEMIES", "Dummy swing strength (3c-3b)",
			PackedStringArray(["Cycle", "Small", "Middle", "Large", "Knockdown"]),
			func() -> int: return _first_dummy_strength(),
			func(index: int) -> void: _set_dummy_strength(index)))
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


const SLOWMO_SCALES: Array[float] = [1.0, 0.5, 0.25, 0.1]


static func _slowmo_index() -> int:
	for i: int in SLOWMO_SCALES.size():
		if is_equal_approx(Hitstop.base_scale, SLOWMO_SCALES[i]):
			return i
	return 0


## Debug slow motion: the game's base speed (hitstop and the victory slow-mo come back to it, and the pause menu
## still opens). A scene change or a death resets the engine speed; the menu re-applies the choice in the next arena.
static func _set_slowmo(index: int) -> void:
	Hitstop.base_scale = SLOWMO_SCALES[clampi(index, 0, SLOWMO_SCALES.size() - 1)]
	Engine.time_scale = Hitstop.base_scale


const CLIP_VIEWER_SCENE: String = "res://scenes/debug/clip_viewer.tscn"
## The clip viewer standing in the arena, or null.
static var _clip_viewer: Node3D


## On: stand the viewer 2.5 m in front of the player, facing it. Off: remove it.
static func _set_clip_viewer(player: Player, on: bool) -> void:
	if not on:
		if is_instance_valid(_clip_viewer):
			_clip_viewer.queue_free()
		_clip_viewer = null
		return
	if is_instance_valid(_clip_viewer):
		return
	var scene := load(CLIP_VIEWER_SCENE) as PackedScene
	if scene == null:
		return
	_clip_viewer = scene.instantiate() as Node3D
	player.get_parent().add_child(_clip_viewer)
	var spot := player.global_position + player.get_facing_direction() * 2.5
	_clip_viewer.global_position = spot
	var toward := player.global_position
	toward.y = spot.y
	if toward.distance_squared_to(spot) > 0.01:
		_clip_viewer.look_at(toward, Vector3.UP)


## The mannequin on the player and on every enemy in the arena (3a-3b-3).
static func _set_figure_shown(player: Player, on: bool) -> void:
	player.set_figure_shown(on)
	for enemy: Enemy in _enemies():
		enemy.set_figure_shown(on)


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


static func _first_dummy_strength() -> int:
	for node: Node3D in Enemies.all():
		var dummy := node as Dummy
		if dummy != null:
			return int(dummy.hurt_mode)
	return 0


static func _set_dummy_strength(index: int) -> void:
	for node: Node3D in Enemies.all():
		var dummy := node as Dummy
		if dummy != null:
			dummy.hurt_mode = index as Dummy.HurtMode


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
