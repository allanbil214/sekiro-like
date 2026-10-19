class_name Settings
extends RefCounted
## The player's settings (Phase 2, item 6a): the audio volumes and the gameplay options of the Options
## menu. Static, no autoload. They are stored in `user://settings.cfg` (a ConfigFile) and loaded once, on
## first use (`ensure_loaded()`), which also applies the volumes to the audio buses. The gameplay values
## are applied to the Player, its camera rig and its lock-on in `Player._ready()` (`apply_gameplay()`), and
## again live from the Options menu (`apply_to_scene()`). These values replace the Inspector values of
## `Player.crouch_is_hold`, `CameraRig.shake_enabled` and `LockOn.recenter_when_no_target` / `auto_lock_next`,
## which stay in the scene only as the fallback when the settings file does not exist yet.
## Volumes and sensitivities are stored as fractions (1.0 = 100 percent).
## Item 6b: the rebound keys and buttons (`ControlsBindings`) are saved in the same file, in a `[controls]`
## section that holds only the bindings that differ from the project's, and applied to the Input Map here.
## The buses (Master, Music, Sfx) come from `res://default_bus_layout.tres`.

const PATH: String = "user://settings.cfg"

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"Sfx"

# Audio
static var master_volume: float = 1.0
static var music_volume: float = 1.0
static var sfx_volume: float = 1.0

# Gameplay
static var camera_shake: bool = true
static var crouch_hold: bool = false
static var sticky_aim: bool = true
static var recenter_camera: bool = false
static var lock_next: bool = true
static var mouse_sensitivity: float = 1.0
static var stick_sensitivity: float = 1.0
static var invert_y: bool = false

static var _loaded: bool = false
static var _warned_bus: bool = false


## Load the file once (a missing file keeps the defaults) and apply the volumes.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	ControlsBindings.capture_defaults()
	var config := ConfigFile.new()
	var error := config.load(PATH)
	if error == OK:
		master_volume = _fraction(config, "audio", "master", master_volume, 0.0, 1.0)
		music_volume = _fraction(config, "audio", "music", music_volume, 0.0, 1.0)
		sfx_volume = _fraction(config, "audio", "sfx", sfx_volume, 0.0, 1.0)
		camera_shake = bool(config.get_value("gameplay", "camera_shake", camera_shake))
		crouch_hold = bool(config.get_value("gameplay", "crouch_hold", crouch_hold))
		sticky_aim = bool(config.get_value("gameplay", "sticky_aim", sticky_aim))
		recenter_camera = bool(config.get_value("gameplay", "recenter_camera", recenter_camera))
		lock_next = bool(config.get_value("gameplay", "lock_next", lock_next))
		mouse_sensitivity = _fraction(config, "gameplay", "mouse_sensitivity", mouse_sensitivity, 0.25, 2.0)
		stick_sensitivity = _fraction(config, "gameplay", "stick_sensitivity", stick_sensitivity, 0.25, 2.0)
		invert_y = bool(config.get_value("gameplay", "invert_y", invert_y))
		ControlsBindings.load_from(config)
	elif error != ERR_FILE_NOT_FOUND:
		push_warning("Settings: could not read %s (error %d); using the defaults." % [PATH, error])
	apply_audio()


## Write every setting to the file.
static func save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("gameplay", "camera_shake", camera_shake)
	config.set_value("gameplay", "crouch_hold", crouch_hold)
	config.set_value("gameplay", "sticky_aim", sticky_aim)
	config.set_value("gameplay", "recenter_camera", recenter_camera)
	config.set_value("gameplay", "lock_next", lock_next)
	config.set_value("gameplay", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("gameplay", "stick_sensitivity", stick_sensitivity)
	config.set_value("gameplay", "invert_y", invert_y)
	ControlsBindings.save_to(config)
	var error := config.save(PATH)
	if error != OK:
		push_error("Settings: could not write %s (error %d)." % [PATH, error])


## Set the three bus volumes (0 is muted).
static func apply_audio() -> void:
	_apply_bus(BUS_MASTER, master_volume)
	_apply_bus(BUS_MUSIC, music_volume)
	_apply_bus(BUS_SFX, sfx_volume)


## Give the Player, its camera rig and its lock-on the gameplay settings.
static func apply_gameplay(player: Player) -> void:
	ensure_loaded()
	player.crouch_is_hold = crouch_hold
	player.sticky_aim = sticky_aim
	var rig := player.camera_rig as CameraRig
	rig.shake_enabled = camera_shake
	rig.mouse_scale = mouse_sensitivity
	rig.stick_scale = stick_sensitivity
	rig.invert_y = invert_y
	player.lock_on.recenter_when_no_target = recenter_camera
	player.lock_on.auto_lock_next = lock_next


## The same for the Player in the current scene, if there is one (the main menu has none).
static func apply_to_scene(tree: SceneTree) -> void:
	var player := tree.get_first_node_in_group(Groups.PLAYER) as Player
	if player != null:
		apply_gameplay(player)


static func _apply_bus(bus: StringName, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		if not _warned_bus:
			_warned_bus = true
			push_error("Settings: no audio bus named \"%s\". Is res://default_bus_layout.tres in the project?" % bus)
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, volume <= 0.001)


static func _fraction(config: ConfigFile, section: String, key: String, fallback: float, low: float, high: float) -> float:
	return clampf(float(config.get_value(section, key, fallback)), low, high)
