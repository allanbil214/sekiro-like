class_name DeathScreen
extends CanvasLayer
## The death screen (Step 10; a scene since Phase 2 item 4). Instance scenes/ui/death_screen.tscn as a
## direct child of Player, named DeathScreen; it only listens to the Player's death signals
## (death_started, death_prompt_shown, death_confirmed, resurrected).
## On death the screen darkens a little and a blood-red vignette (shaders/death_vignette.gdshader, with a
## wobbling edge and a slow pulse) creeps in from the edges; the 死 and "D E A T H" fade in; when the
## prompt shows, "RMB / LB : Die" and "LMB / RB : Resurrect" appear (only with a resurrection left).
## Resurrecting fades it all out; dying fades to black (the Player reloads the scene when that ends).
## The new scene starts black and fades in (fade_in_on_start).
## The scene holds the look: the texts, colors, font sizes and positions (anchors) are on the nodes, and
## the vignette's color, inner, outer and pulse are parameters of the Vignette node's material. This
## script keeps the behavior: the fades, the strengths and the timings below. Font sizes and letter
## spacing are written for a 1080 px high window and scale with the real height (UiTextScaler).
## The 死 uses the Theme's KanjiLabel font (Yu Mincho / MS Mincho on Windows).

@export_group("Look")
## How much the whole screen darkens on death (0 to 1).
@export_range(0.0, 1.0) var darken: float = 0.35
## The vignette's strongest alpha (the shader's `strength` at the end of the fade-in).
@export_range(0.0, 1.0) var vignette_strength: float = 0.9

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
## Seconds the screen stays fully black at the start before the fade-in begins (0 = no hold). It hides the
## first frames of a scene while the camera and the bodies settle.
@export var start_hold_time: float = 0.3

const REFERENCE_HEIGHT: float = 1080.0

@onready var _root: Control = %Root
@onready var _vignette: ColorRect = %Vignette
@onready var _dim: ColorRect = %Dim
@onready var _kanji: Label = %Kanji
@onready var _word: Label = %Word
@onready var _die_label: Label = %DieLabel
@onready var _resurrect_label: Label = %ResurrectLabel

var _player: Player
var _vignette_material: ShaderMaterial
var _scaler := UiTextScaler.new()
var _scaled_height: float = -1.0

var _dim_alpha: float = 0.0
var _dim_target: float = 0.0
var _dim_speed: float = 1.0
var _start_hold_left: float = 0.0
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
	_player = get_parent() as Player
	_vignette_material = _vignette.material as ShaderMaterial
	_root.visible = false
	for label: Label in [_kanji, _word, _die_label, _resurrect_label]:
		_scaler.add(label)
	_root.resized.connect(_apply_scale)
	_apply_scale()
	_player.death_started.connect(_on_death_started)
	_player.death_prompt_shown.connect(_on_prompt_shown)
	_player.death_confirmed.connect(_on_death_confirmed)
	_player.resurrected.connect(_on_resurrected)
	if fade_in_on_start and start_fade_time > 0.0:
		_dim_alpha = 1.0
		_dim_target = 0.0
		_dim_speed = 1.0 / start_fade_time
		_start_hold_left = start_hold_time
		# Cover the very first frame too: _process has not run yet, so show the black now (texts stay hidden).
		_dim.modulate.a = 1.0
		_root.visible = true
		for label: Label in [_kanji, _word, _die_label, _resurrect_label]:
			_show(label, 0.0)


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
	if _start_hold_left > 0.0:
		_start_hold_left -= delta
	else:
		_dim_alpha = move_toward(_dim_alpha, _dim_target, _dim_speed * delta)
	_vig = move_toward(_vig, _vig_target, _vig_speed * delta)
	_text_alpha = move_toward(_text_alpha, _text_target, _text_speed * delta)
	_prompt_alpha = move_toward(_prompt_alpha, _prompt_target, _prompt_speed * delta)
	_root.visible = _dim_alpha > 0.001 or _vig > 0.001 or _text_alpha > 0.001
	if not _root.visible:
		return
	if not is_equal_approx(_root.size.y, _scaled_height):
		_apply_scale()
	_dim.modulate.a = _dim_alpha
	_vignette_material.set_shader_parameter("strength", _vig * vignette_strength)
	_show(_kanji, _text_alpha)
	_show(_word, _text_alpha)
	_show(_die_label, _prompt_alpha)
	_show(_resurrect_label, _prompt_alpha)


## Fade a label with its own alpha (its color and shadow come from the scene).
func _show(label: Label, alpha: float) -> void:
	label.modulate.a = alpha
	label.visible = alpha > 0.001


## Scale the font sizes and the letter spacing with the window height.
func _apply_scale() -> void:
	_scaled_height = _root.size.y
	_scaler.apply(_scaled_height / REFERENCE_HEIGHT)