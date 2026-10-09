class_name CrouchVignette
extends CanvasLayer
## A subtle dark vignette while the player is crouched or sliding (Step 11g), drawn in code. Must be a
## direct child of Player; it reads Player.is_crouched and eases in and out. It sits under the HUD
## (layer 5, the HUD is 10) and the death and victory screens.

const VIGNETTE_SHADER: String = """
shader_type canvas_item;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float strength = 0.0;
uniform float inner = 0.45;
uniform float outer = 1.0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p) / 1.4142;
	COLOR = vec4(vignette_color.rgb, clamp(smoothstep(inner, outer, d) * strength, 0.0, 1.0));
}
"""

## How dark the corners get at most (0 to 1). Kept low on purpose: it should be felt, not noticed.
@export_range(0.0, 1.0) var strength: float = 0.25
@export var vignette_color: Color = Color(0.0, 0.0, 0.0)
## Where the darkening starts and where it is full, from the center (0) to the corners (1).
@export_range(0.0, 1.0) var inner: float = 0.45
@export_range(0.1, 1.5) var outer: float = 1.0
## Seconds to fade in when crouching and out when standing.
@export var fade_in_time: float = 0.25
@export var fade_out_time: float = 0.25

var _player: Player
var _rect: ColorRect
var _material: ShaderMaterial
var _amount: float = 0.0


func _ready() -> void:
	layer = 5
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
	var goal := 1.0 if _player.is_crouched else 0.0
	var time := fade_in_time if goal > _amount else fade_out_time
	_amount = move_toward(_amount, goal, delta / maxf(time, 0.01))
	_rect.visible = _amount > 0.001
	if not _rect.visible:
		return
	var eased := smoothstep(0.0, 1.0, _amount)
	_material.set_shader_parameter("vignette_color", vignette_color)
	_material.set_shader_parameter("strength", strength * eased)
	_material.set_shader_parameter("inner", inner)
	_material.set_shader_parameter("outer", outer)