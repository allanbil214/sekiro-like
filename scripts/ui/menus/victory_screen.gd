class_name VictoryScreen
extends CanvasLayer
## The boss-slain screen (Step 11d; a scene since Phase 2 item 4). Instance scenes/ui/victory_screen.tscn
## as a direct child of Player, named VictoryScreen (it listens to the Player's death_started and reads
## Player.combatant). It joins the group "victory_screen"; a boss Enemy calls show_victory(kanji, text)
## when its final deathblow lands (Enemy._on_died).
## Sequence (real seconds, so the slow motion does not stretch it): a long hitstop, a brief slow motion,
## a white flash, the screen darkens and loses its color (assets/shaders/victory_screen.gdshader), then the
## kanji (stacked top to bottom, white glow) and the spaced English line fade in; the spacing eases wider
## while it holds; then everything fades out and the player stays in the arena. Dying while it plays
## cancels it (the death screen wins).
## The scene holds the look: colors, font sizes, the kanji's line spacing and glow, and the vertical
## positions (anchors) are on the Kanji and Word nodes. Their sizes and spacings are written for a
## 1080 px high window and scale with the real height. Both labels use the Theme's KanjiLabel font
## (Yu Mincho / MS Mincho on Windows). This script keeps the behavior and the timings.

@export_group("Game feel")
## Real seconds of near-freeze when the final blow lands (Hitstop), then the slow motion.
@export var hitstop_time: float = 0.3
@export_range(0.05, 1.0) var slowmo_scale: float = 0.35
@export var slowmo_time: float = 0.8

@export_group("Screen")
## How dark the screen gets (1 = black) and how much color is removed (1 = gray).
@export_range(0.0, 1.0) var dim_amount: float = 0.8
@export_range(0.0, 1.0) var desaturate_amount: float = 1.0
@export var flash_strength: float = 0.6
@export var flash_time: float = 0.2
## Seconds for the darkening and the color loss to come in.
@export var screen_fade_in: float = 0.9

@export_group("Timing")
## The banner starts this long after the blow, fades in over banner_fade_in, holds, then everything fades out.
@export var banner_delay: float = 1.0
@export var banner_fade_in: float = 0.8
@export var hold_time: float = 3.0
@export var fade_out_time: float = 1.2

@export_group("Text")
## Extra space between the letters of the English line (px at 1080): starts narrow, eases to the end value.
@export var word_spacing_start: int = 4
@export var word_spacing_end: int = 16

const REFERENCE_HEIGHT: float = 1080.0

@onready var _root: Control = %Root
@onready var _rect: ColorRect = %ScreenRect
@onready var _kanji: Label = %Kanji
@onready var _word: Label = %Word

var _player: Player
var _material: ShaderMaterial
var _word_font: FontVariation
var _word_spacing_now: int = -1
var _ui_scale: float = 1.0
# The sizes written in the scene (px at a 1080 px high window), read once in _ready().
var _kanji_size: int = 0
var _kanji_line_spacing: int = 0
var _kanji_outline: int = 0
var _word_size: int = 0
var _active: bool = false
var _start_ms: int = 0
var _token: int = 0
var _slow: bool = false


func _ready() -> void:
	add_to_group(Groups.VICTORY_SCREEN)
	_player = get_parent() as Player
	_material = _rect.material as ShaderMaterial
	_root.visible = false
	_kanji_size = _kanji.get_theme_font_size(&"font_size")
	_kanji_line_spacing = _kanji.get_theme_constant(&"line_spacing")
	_kanji_outline = _kanji.get_theme_constant(&"outline_size")
	_word_size = _word.get_theme_font_size(&"font_size")
	# The English line's letter spacing eases while it holds, so it has its own font variation.
	_word_font = FontVariation.new()
	_word_font.base_font = _word.get_theme_font(&"font")
	_word.add_theme_font_override(&"font", _word_font)
	_root.resized.connect(_apply_scale)
	_apply_scale()
	_player.death_started.connect(_cancel)


func _exit_tree() -> void:
	_token += 1
	_restore_time()


## True while the boss-slain screen is showing (the pause menu does not open then).
func is_active() -> bool:
	return _active


## Called by a boss Enemy when it dies of its final deathblow. `kanji` is stacked one character per line.
func show_victory(kanji: String, word: String) -> void:
	if _player.combatant.dead:
		return
	var chars := PackedStringArray()
	for i in kanji.length():
		chars.append(kanji[i])
	_kanji.text = "\n".join(chars)
	_word.text = word
	# Deferred so the player's own hitstop request of the same frame cannot cut ours short.
	call_deferred("_begin")


func _begin() -> void:
	_restore_time()
	_token += 1
	var token := _token
	_start_ms = Time.get_ticks_msec()
	_active = true
	Fx.play(get_tree(), Fx.Kind.BOSS_SLAIN)
	_word_spacing_now = -1
	if hitstop_time > 0.0:
		Hitstop.request(get_tree(), hitstop_time)
	if slowmo_time <= 0.0 or slowmo_scale >= 1.0:
		return
	await get_tree().create_timer(hitstop_time + 0.03, true, false, true).timeout
	if token != _token:
		return
	Engine.time_scale = slowmo_scale
	_slow = true
	await get_tree().create_timer(slowmo_time, true, false, true).timeout
	if token != _token:
		return
	_restore_time()


func _restore_time() -> void:
	if _slow:
		Engine.time_scale = 1.0
		_slow = false


## The player died: drop everything at once (the death screen takes over).
func _cancel() -> void:
	_token += 1
	_restore_time()
	_active = false
	_root.visible = false


func _process(_delta: float) -> void:
	if not _active:
		return
	var t := float(Time.get_ticks_msec() - _start_ms) / 1000.0
	var out_start := banner_delay + banner_fade_in + hold_time
	var out_k := clampf((t - out_start) / maxf(fade_out_time, 0.01), 0.0, 1.0)
	if out_k >= 1.0:
		_active = false
		_root.visible = false
		return
	_root.visible = true
	if not is_equal_approx(_root.size.y / REFERENCE_HEIGHT, _ui_scale):
		_apply_scale()
	var screen := smoothstep(0.0, 1.0, clampf(t / maxf(screen_fade_in, 0.01), 0.0, 1.0)) * (1.0 - out_k)
	var flash := 0.0
	if t < flash_time:
		flash = flash_strength * pow(1.0 - t / maxf(flash_time, 0.01), 2.0)
	_material.set_shader_parameter("dim", dim_amount * screen)
	_material.set_shader_parameter("desaturate", desaturate_amount * screen)
	_material.set_shader_parameter("flash", flash)
	var appear := clampf((t - banner_delay) / maxf(banner_fade_in, 0.01), 0.0, 1.0)
	var alpha := smoothstep(0.0, 1.0, appear) * (1.0 - out_k)
	var spread := clampf((t - banner_delay) / maxf(banner_fade_in + hold_time, 0.01), 0.0, 1.0)
	spread = 1.0 - pow(1.0 - spread, 3.0)
	_fade_banner(alpha, lerpf(float(word_spacing_start), float(word_spacing_end), spread))


## Fade the two texts with `alpha` and set the English line's letter spacing (px at 1080).
func _fade_banner(alpha: float, spacing: float) -> void:
	_kanji.modulate.a = alpha
	_kanji.visible = alpha > 0.001
	var gap := roundi(spacing * _ui_scale)
	if gap != _word_spacing_now:
		_word_spacing_now = gap
		_word_font.spacing_glyph = gap
	_word.modulate.a = alpha
	# The last letter also gets the spacing, so shift half of it back to keep the line centered.
	_word.offset_left = float(gap) * 0.5
	_word.offset_right = float(gap) * 0.5
	_word.visible = alpha > 0.001


## Scale the font sizes, the kanji's line spacing and glow with the window height.
func _apply_scale() -> void:
	_ui_scale = _root.size.y / REFERENCE_HEIGHT
	_kanji.add_theme_font_size_override(&"font_size", maxi(1, roundi(float(_kanji_size) * _ui_scale)))
	_kanji.add_theme_constant_override(&"line_spacing", roundi(float(_kanji_line_spacing) * _ui_scale))
	_kanji.add_theme_constant_override(&"outline_size", roundi(float(_kanji_outline) * _ui_scale))
	_word.add_theme_font_size_override(&"font_size", maxi(1, roundi(float(_word_size) * _ui_scale)))
	_word_spacing_now = -1
