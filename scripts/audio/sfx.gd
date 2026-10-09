class_name Sfx
extends RefCounted
## All the game's sound (Step 11a). One static call per sound: Sfx.play(tree, Sfx.Id.JUMP) (not tied to a
## place: the player's own sounds, menu sounds) or Sfx.play_at(tree, Sfx.Id.DEFLECT, point) (a sound in the
## world, louder near the camera). The table (wavs, volume, pitch, cut-off groups) is `audio/sfx_data.tres`
## (SfxData). A slot with no wav is silent. Most game events reach it through `Fx.play()`; the rest are
## one-line calls in the states. Nothing here changes a game rule.
## Players are added to the current scene and freed when they finish, so a scene reload clears them.

enum Id {
	SWING, SWING_ALT, SWING_SUPER, THRUST, CHARGE_LOOP,
	HIT_FLESH, HIT_FLESH_HEAVY, PLAYER_HURT, ENEMY_FLINCH,
	GUARD_BLOCK, GUARD_RAISE, DEFLECT, DEFLECT_PERILOUS, GUARD_BREAK, REPULSE, POSTURE_BREAK,
	DEATHBLOW_OPEN, BLOOD_BURST, ENEMY_DEATH,
	DANGER_RED, DANGER_YELLOW, GRAB_HIT, MIKIRI, HEAD_STOMP,
	AURA_START, AURA_LOOP,
	FOOTSTEP_WALK, FOOTSTEP_RUN, FOOTSTEP_CROUCH,
	JUMP, DODGE, REACH, WALL_JUMP, LEDGE_GRAB, LEDGE_CLIMB, SLIDE, CROUCH, LAND_SOFT, LAND_HARD,
	DRAW, SHEATHE,
	HEAL_DRINK, HEAL_DONE, RESURRECT,
	DEATH_HIT, DEATH_TOLL, PROMPT_OPEN, DIE_CONFIRM,
}

const DATA_PATH: String = "res://audio/sfx_data.tres"

## Combo steps 1 to 3 always use the main swing, 4 and 5 the second one (the same animation names the
## weapon's combo uses). Other slashes pick at random (SfxData.swing_alt_chance).
const MAIN_SWING_ANIMATIONS: Array[StringName] = [&"attack_1", &"attack_2", &"attack_3"]
const ALT_SWING_ANIMATIONS: Array[StringName] = [&"attack_4", &"attack_5"]
## The draw slash, the charged iai, and the helm splitters.
const SUPER_SWING_ANIMATIONS: Array[StringName] = [
	&"draw_attack", &"draw_attack_charged", &"helm_splitter", &"helm_splitter_draw",
]

static var _data: SfxData
static var _slots: Dictionary = {}
static var _last_pick: Dictionary = {}
static var _voices: Dictionary = {}
static var _loaded: bool = false


## Play a sound that has no place in the world (the player's own sounds, menus).
static func play(tree: SceneTree, id: Id, volume_offset_db: float = 0.0, pitch_multiplier: float = 1.0) -> void:
	_start(tree, id, false, Vector3.ZERO, volume_offset_db, pitch_multiplier)


## Play a sound at a point in the world.
static func play_at(tree: SceneTree, id: Id, point: Vector3, volume_offset_db: float = 0.0,
		pitch_multiplier: float = 1.0) -> void:
	_start(tree, id, true, point, volume_offset_db, pitch_multiplier)


## Which sound an attack makes when its hit window opens: thrusts, the super swing, or the swing pair.
static func swing_id(action: ActionData) -> Id:
	if action.blade_aims_at_end:
		return Id.THRUST
	if SUPER_SWING_ANIMATIONS.has(action.animation):
		return Id.SWING_SUPER
	if ALT_SWING_ANIMATIONS.has(action.animation):
		return Id.SWING_ALT
	if MAIN_SWING_ANIMATIONS.has(action.animation):
		return Id.SWING
	_ensure_loaded()
	var chance := _data.swing_alt_chance if _data != null else 0.0
	return Id.SWING_ALT if randf() < chance else Id.SWING


## True when the deathblow_opening sounds are switched on (SfxData.deathblow_open_enabled).
static func deathblow_open_enabled() -> bool:
	_ensure_loaded()
	return _data != null and _data.deathblow_open_enabled


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_data = load(DATA_PATH) as SfxData
	if _data == null:
		push_error("Sfx: could not load %s (the sound table); all sounds stay silent." % DATA_PATH)
		return
	for slot: SfxSlot in _data.slots:
		if slot == null:
			continue
		var key := slot.slot_name.to_upper()
		if Id.has(key):
			_slots[Id[key]] = slot
		else:
			push_warning("Sfx: slot \"%s\" in sfx_data.tres matches no Sfx.Id." % slot.slot_name)
	for key: String in Id.keys():
		if not _slots.has(Id[key]):
			push_warning("Sfx: Sfx.Id.%s has no slot in sfx_data.tres (silent)." % key)


static func _start(tree: SceneTree, id: Id, positional: bool, point: Vector3, volume_offset: float,
		pitch_multiplier: float) -> void:
	if tree == null:
		return
	_ensure_loaded()
	var slot: SfxSlot = _slots.get(id)
	if slot == null or slot.streams.is_empty():
		return
	var scene := tree.current_scene
	if scene == null:
		return
	var index := 0
	var count := slot.streams.size()
	if count > 1:
		index = randi() % count
		if index == int(_last_pick.get(id, -1)):
			index = (index + 1 + randi() % (count - 1)) % count
	_last_pick[id] = index
	var stream := slot.streams[index]
	if stream == null:
		return
	if slot.group != &"":
		# Untyped on purpose: a finished voice frees itself, and a freed object cannot be put in a Node variable.
		var old: Variant = _voices.get(slot.group)
		if old != null and is_instance_valid(old):
			(old as Node).queue_free()
	var volume := slot.volume_db + _data.master_volume_db + volume_offset
	var pitch := maxf(randf_range(slot.pitch_min, slot.pitch_max) * pitch_multiplier, 0.05)
	var voice: Node
	if positional:
		var player3d := AudioStreamPlayer3D.new()
		player3d.stream = stream
		player3d.volume_db = volume
		player3d.pitch_scale = pitch
		player3d.unit_size = _data.world_unit_size
		scene.add_child(player3d)
		player3d.global_position = point
		player3d.finished.connect(player3d.queue_free)
		player3d.play()
		voice = player3d
	else:
		var player2d := AudioStreamPlayer.new()
		player2d.stream = stream
		player2d.volume_db = volume
		player2d.pitch_scale = pitch
		scene.add_child(player2d)
		player2d.finished.connect(player2d.queue_free)
		player2d.play()
		voice = player2d
	if slot.group != &"":
		_voices[slot.group] = voice
