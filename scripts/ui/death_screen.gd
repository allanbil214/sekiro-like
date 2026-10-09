class_name DeathScreen
extends CanvasLayer
## The death screen (Step 10), drawn in code. Must be a direct child of Player; it only listens to the
## Player's death signals (death_started, death_prompt_shown, death_confirmed, resurrected).
## On death the screen darkens a little and a blood-red vignette (a small shader, with a wobbling edge and
## a slow pulse) creeps in from the edges; the 死 and "D E A T H" fade in; when the prompt shows,
## "RMB / LB : Die" and "LMB / RB : Resurrect" appear (only with a resurrection left). Resurrecting fades
## it all out; dying fades to black (the Player reloads the scene when that ends). The new scene starts
## black and fades in (fade_in_on_start).
## The 死 uses a system serif font (Yu Mincho / MS Mincho on Windows); if it shows as a box, the machine
## has none of the font names in `kanji_fonts`.

const VIGNETTE_SHADER: String = """
shader_type canvas_item;
uniform vec4 vignette_color : source_color = vec4(0.5, 0.0, 0.02, 1.0);
uniform float strength = 0.0;
uniform float inner = 0.3;
uniform float outer = 0.95;
uniform float pulse = 0.08;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float angle = atan(p.y, p.x);
	float d = length(p) / 1.4142;
	d += 0.05 * sin(angle * 5.0 + TIME * 0.5) + 0.03 * sin(angle * 11.0 - TIME * 0.8);
	float v = smoothstep(inner, outer, d);
	float beat = 1.0 + pulse * sin(TIME * 3.0);
	COLOR = vec4(vignette_color.rgb, clamp(v * strength * beat, 0.0, 1.0));
}
"""

@export_group("Look")
## How much the whole screen darkens on death (0 to 1).
@export_range(0.0, 1.0) var darken: float = 0.35
@export var vignette_color: Color = Color(0.5, 0.0, 0.02)
@export_range(0.0, 1.0) var vignette_strength: float = 0.9
## Where the red starts and where it is full, measured from the center (0) to the corners (1).
@export_range(0.0, 1.0) var vignette_inner: float = 0.3
@export_range(0.1, 1.5) var vignette_outer: float = 0.95
@export_range(0.0, 0.3) var vignette_pulse: float = 0.08

@export_group("Timing")
## Seconds for the darkening and the vignette to come in after dying.
@export var fade_in_time: float = 0.8
## The 死 comes in this many seconds after dying, over text_fade_time.
@export var text_delay: float = 0.4
@export var text_fade_time: float = 0.6
@export var prompt_fade_time: float = 0.3
## Seconds for everything to clear after a resurrection.
@export var clear_time: float = 0.35
## Start each scene black and fade in (it also smooths the reload after dying).
@export var fade_in_on_start: bool = true
@export var start_fade_time: float = 0.7

@export_group("Text")
@export var kanji_color: Color = Color(0.78, 0.78, 0.76)
@export var word_color: Color = Color(0.6, 0.6, 0.58)
@export var prompt_color: Color = Color(0.9, 0.9, 0.88)
## Font sizes (px) at a 1080 px high window; they scale with the real height.
## Font names tried in order for the 死 (system fonts).
@export var kanji_fonts: PackedStringArray = PackedStringArray(["Yu Mincho", "MS Mincho", "Noto Serif CJK JP", "Noto Serif JP", "serif"])
@export var kanji_size: int = 220
@export var word_size: int = 22
@export var prompt_size: int = 26
@export var die_text: String = "RMB / LB : Die"
@export var resurrect_text: String = "LMB / RB : Resurrect"

var _player: Player
var _root: Control
var _vignette: ColorRect
var _vignette_material: ShaderMaterial
var _dim: ColorRect
var _kanji: Label
var _word: Label
var _die_label: Label
var _resurrect_label: Label

var _dim_alpha: float = 0.0
var _dim_target: float = 0.0
var _dim_speed: float = 1.0
var _vig: float = 0.0
var _vig_target: float = 0.0
var _vig_speed: float = 1.0
var _text_alpha: float = 0.0
var _text_target: float = 0.0
var _text_speed: float = 1.0
var _text_delay_left: float = -1.0
var _prompt_alpha: float = 0.0
var _prompt_target: float = 0.0
var _prompt_speed: float = 1.0


func _ready() -> void:
	layer = 20
	_player = get_parent() as Player
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = shader
	_vignette = ColorRect.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.material = _vignette_material
	_root.add_child(_vignette)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var kanji_font := SystemFont.new()
	kanji_font.font_names = kanji_fonts
	_kanji = _make_label("死", kanji_font)
	_word = _make_label("D E A T H", null)
	_die_label = _make_label(die_text, null)
	_resurrect_label = _make_label(resurrect_text, null)
	_player.death_started.connect(_on_death_started)
	_player.death_prompt_shown.connect(_on_prompt_shown)
	_player.death_confirmed.connect(_on_death_confirmed)
	_player.resurrected.connect(_on_resurrected)
	if fade_in_on_start and start_fade_time > 0.0:
		_dim_alpha = 1.0
		_dim_target = 0.0
		_dim_speed = 1.0 / start_fade_time


func _make_label(text: String, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		label.add_theme_font_override("font", font)
	_root.add_child(label)
	return label


func _on_death_started() -> void:
	_dim_target = darken
	_dim_speed = absf(darken - _dim_alpha) / maxf(fade_in_time, 0.01)
	_vig_target = 1.0
	_vig_speed = 1.0 / maxf(fade_in_time, 0.01)
	_text_delay_left = text_delay


func _on_prompt_shown(can_resurrect: bool) -> void:
	if can_resurrect:
		_prompt_target = 1.0
		_prompt_speed = 1.0 / maxf(prompt_fade_time, 0.01)


## Dying for good: the prompt goes, the screen fades to black over `fade_time`.
func _on_death_confirmed(fade_time: float) -> void:
	_prompt_target = 0.0
	_prompt_speed = 4.0
	_dim_target = 1.0
	_dim_speed = (1.0 - _dim_alpha) / maxf(fade_time, 0.01)


func _on_resurrected() -> void:
	var speed := 1.0 / maxf(clear_time, 0.01)
	_dim_target = 0.0
	_dim_speed = maxf(_dim_alpha, 0.01) * speed
	_vig_target = 0.0
	_vig_speed = speed
	_text_target = 0.0
	_text_speed = speed
	_text_delay_left = -1.0
	_prompt_target = 0.0
	_prompt_speed = speed * 2.0


func _process(delta: float) -> void:
	if _text_delay_left >= 0.0:
		_text_delay_left -= delta
		if _text_delay_left < 0.0:
			_text_target = 1.0
			_text_speed = 1.0 / maxf(text_fade_time, 0.01)
	_dim_alpha = move_toward(_dim_alpha, _dim_target, _dim_speed * delta)
	_vig = move_toward(_vig, _vig_target, _vig_speed * delta)
	_text_alpha = move_toward(_text_alpha, _text_target, _text_speed * delta)
	_prompt_alpha = move_toward(_prompt_alpha, _prompt_target, _prompt_speed * delta)
	_root.visible = _dim_alpha > 0.001 or _vig > 0.001 or _text_alpha > 0.001
	if not _root.visible:
		return
	_dim.color = Color(0.0, 0.0, 0.0, _dim_alpha)
	_vignette_material.set_shader_parameter("vignette_color", vignette_color)
	_vignette_material.set_shader_parameter("strength", _vig * vignette_strength)
	_vignette_material.set_shader_parameter("inner", vignette_inner)
	_vignette_material.set_shader_parameter("outer", vignette_outer)
	_vignette_material.set_shader_parameter("pulse", vignette_pulse)
	_layout()


## Place and color the texts for the current window size.
func _layout() -> void:
	var size := _root.size
	var s := size.y / 1080.0
	_place(_kanji, kanji_size, size, 0.5, size.y * 0.43 - float(kanji_size) * s * 0.55, 1.0, kanji_color, _text_alpha, s)
	_place(_word, word_size, size, 0.5, size.y * 0.43 + float(kanji_size) * s * 0.5, 1.0, word_color, _text_alpha, s)
	var prompt_y := size.y * 0.925
	_place(_die_label, prompt_size, size, 0.38, prompt_y, 0.3, prompt_color, _prompt_alpha, s)
	_place(_resurrect_label, prompt_size, size, 0.62, prompt_y, 0.3, prompt_color, _prompt_alpha, s)


func _place(label: Label, font_px: int, size: Vector2, center_x: float, y: float, width_share: float, color: Color, alpha: float, s: float) -> void:
	label.add_theme_font_size_override("font_size", int(round(float(font_px) * s)))
	label.add_theme_color_override("font_color", Color(color.r, color.g, color.b, color.a * alpha))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7 * alpha))
	label.size = Vector2(size.x * width_share, 0.0)
	label.position = Vector2(size.x * center_x - size.x * width_share * 0.5, y)
	label.visible = alpha > 0.001