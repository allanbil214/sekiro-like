class_name VictoryScreen
extends CanvasLayer
## The boss-slain screen (Step 11d), drawn in code. Must be a direct child of Player (it listens to the
## Player's death_started and reads Player.combatant). It joins the group "victory_screen"; a boss
## Enemy calls show_victory(kanji, text) when its final deathblow lands (Enemy._on_died).
## Sequence (real seconds, so the slow motion does not stretch it): a long hitstop, a brief slow motion,
## a white flash, the screen darkens and loses its color, then the kanji (stacked top to bottom, white
## glow) and the spaced English line fade in; the spacing eases wider while it holds; then everything
## fades out and the player stays in the arena. Dying while it plays cancels it (the death screen wins).
## The kanji uses a system serif font (same list as DeathScreen); if it shows as a box, the machine has
## none of the font names in `fonts`.

const SCREEN_SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float desaturate = 0.0;
uniform float dim = 0.0;
uniform float flash = 0.0;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), desaturate);
	c = mix(c, vec3(0.0), dim);
	c = mix(c, vec3(1.0), flash);
	COLOR = vec4(c, 1.0);
}
"""

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
@export var fonts: PackedStringArray = PackedStringArray(["Yu Mincho", "MS Mincho", "Noto Serif CJK JP", "Noto Serif JP", "serif"])
## Font sizes (px) at a 1080 px high window; they scale with the real height.
@export var kanji_size: int = 220
@export var kanji_line_spacing: int = -20
@export var word_size: int = 30
@export var kanji_color: Color = Color(1.0, 1.0, 1.0)
@export var word_color: Color = Color(0.92, 0.92, 0.92)
## The soft halo around the kanji (an outline with low alpha) and its width (px at 1080).
@export var glow_color: Color = Color(1.0, 1.0, 1.0, 0.3)
@export var glow_size: int = 8
## Extra space between the letters of the English line (px at 1080): starts narrow, eases to the end value.
@export var word_spacing_start: int = 4
@export var word_spacing_end: int = 16
## Vertical positions as a share of the window height (top of the kanji stack and the English line).
@export_range(0.0, 1.0) var kanji_top: float = 0.1
@export_range(0.0, 1.0) var word_top: float = 0.64

var _player: Player
var _root: Control
var _rect: ColorRect
var _material: ShaderMaterial
var _kanji: Label
var _word: Label
var _word_font: FontVariation
var _word_spacing_now: int = -1
var _active: bool = false
var _start_ms: int = 0
var _token: int = 0
var _slow: bool = false


func _ready() -> void:
	layer = 19
	add_to_group("victory_screen")
	_player = get_parent() as Player
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.visible = false
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = SCREEN_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	_root.add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base := SystemFont.new()
	base.font_names = fonts
	_kanji = _make_label(base)
	_word_font = FontVariation.new()
	_word_font.base_font = base
	_word = _make_label(_word_font)
	_player.death_started.connect(_cancel)


func _exit_tree() -> void:
	_token += 1
	_restore_time()


func _make_label(font: Font) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	_root.add_child(label)
	return label


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
	_layout(alpha, lerpf(float(word_spacing_start), float(word_spacing_end), spread))


func _layout(alpha: float, spacing: float) -> void:
	var size := _root.size
	var s := size.y / 1080.0
	_kanji.add_theme_font_size_override("font_size", int(round(float(kanji_size) * s)))
	_kanji.add_theme_constant_override("line_spacing", int(round(float(kanji_line_spacing) * s)))
	_kanji.add_theme_constant_override("outline_size", int(round(float(glow_size) * s)))
	_kanji.add_theme_color_override("font_color", Color(kanji_color.r, kanji_color.g, kanji_color.b, alpha))
	_kanji.add_theme_color_override("font_outline_color", Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * alpha))
	_kanji.size = Vector2(size.x, 0.0)
	_kanji.position = Vector2(0.0, size.y * kanji_top)
	_kanji.visible = alpha > 0.001
	var gap := int(round(spacing * s))
	if gap != _word_spacing_now:
		_word_spacing_now = gap
		_word_font.spacing_glyph = gap
	_word.add_theme_font_size_override("font_size", int(round(float(word_size) * s)))
	_word.add_theme_color_override("font_color", Color(word_color.r, word_color.g, word_color.b, alpha))
	_word.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7 * alpha))
	_word.size = Vector2(size.x, 0.0)
	# The last letter also gets the spacing, so shift half of it back to keep the line centered.
	_word.position = Vector2(float(gap) * 0.5, size.y * word_top)
	_word.visible = alpha > 0.001
