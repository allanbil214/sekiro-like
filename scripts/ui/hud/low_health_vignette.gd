class_name LowHealthVignette
extends CanvasLayer
## A red warning on the screen edges while the player's health is low (Phase 2 item 17), drawn in code like
## `CrouchVignette`. Must be a direct child of Player; it reads `Player.combatant`. It starts at
## `start_fraction` of max health, grows to full strength at `full_fraction`, and pulses slowly. It fades out
## when health returns (a heal, a regen), is hidden while dead (the death screen takes over) and with the Options
## toggle `Settings.low_health_warning` off. It sits above the crouch vignette (layer 5) and under the HUD (10).

const VIGNETTE_SHADER: String = """
shader_type canvas_item;
uniform vec4 vignette_color : source_color = vec4(0.6, 0.0, 0.02, 1.0);
uniform float strength = 0.0;
uniform float inner = 0.4;
uniform float outer = 1.0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p) / 1.4142;
	COLOR = vec4(vignette_color.rgb, clamp(smoothstep(inner, outer, d) * strength, 0.0, 1.0));
}
"""

## Health fraction (0 to 1) where the warning starts to appear (placeholder).
@export_range(0.0, 1.0) var start_fraction: float = 0.3
## Health fraction where it is at full strength (placeholder). Lower than `start_fraction`.
@export_range(0.0, 1.0) var full_fraction: float = 0.1
## How opaque the screen edges get at full strength (0 to 1).
@export_range(0.0, 1.0) var strength: float = 0.5
@export var vignette_color: Color = Color(0.6, 0.0, 0.02)
## Where the red starts and where it is full, from the center (0) to the corners (1).
@export_range(0.0, 1.0) var inner: float = 0.4
@export_range(0.1, 1.5) var outer: float = 1.0
## Seconds for one slow pulse (a heartbeat).
@export_range(0.4, 4.0) var pulse_period: float = 1.2
## How deep the pulse dips: 0 is steady, 1 fades to nothing between beats.
@export_range(0.0, 1.0) var pulse_depth: float = 0.35
## Seconds to fade in when health drops and out when it returns.
@export var fade_in_time: float = 0.5
@export var fade_out_time: float = 0.8

var _player: Player
var _rect: ColorRect
var _material: ShaderMaterial
var _amount: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	layer = 6
	_player = get_parent() as Player
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.material = _material
	_rect.visible = false
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var goal := _severity()
	var time := fade_in_time if goal > _amount else fade_out_time
	_amount = move_toward(_amount, goal, delta / maxf(time, 0.01))
	_rect.visible = _amount > 0.001
	if not _rect.visible:
		return
	_clock += delta
	var beat := 0.5 + 0.5 * sin(TAU * _clock / maxf(pulse_period, 0.1))
	var pulse := 1.0 - pulse_depth * (1.0 - beat)
	_material.set_shader_parameter("vignette_color", vignette_color)
	_material.set_shader_parameter("strength", strength * smoothstep(0.0, 1.0, _amount) * pulse)
	_material.set_shader_parameter("inner", inner)
	_material.set_shader_parameter("outer", outer)


## 0 (no warning) to 1 (full): how far health is below `start_fraction`, down to `full_fraction`.
func _severity() -> float:
	if not Settings.low_health_warning or _player == null or _player.combatant == null:
		return 0.0
	var combatant := _player.combatant
	if combatant.dead or combatant.max_health <= 0.0:
		return 0.0
	var fraction := combatant.health / combatant.max_health
	var span := maxf(start_fraction - full_fraction, 0.001)
	return clampf((start_fraction - fraction) / span, 0.0, 1.0)
