class_name DangerSymbol
extends Label3D
## The perilous-attack warning (Step 7c): a big "!" above the player's head. Red for a thrust or
## sweep (yellow for the grab, 7c-2). Add a Label3D named DangerSymbol under the Player at about
## (0, 2.6, 0) and attach this script; it sets its own look and starts hidden. The enemy finds it
## by group and calls show_danger() when the symbol should appear and hide_danger() when the hit
## window closes. No body flashing (a design rule), only this symbol.

## How long (s) the "pop" at the start takes, and how big it starts (x its size).
@export var pop_time: float = 0.12
@export var pop_scale: float = 1.6
@export var symbol_font_size: int = 180
@export var symbol_pixel_size: float = 0.006

var _source: Object
var _pop: float = 0.0


func _ready() -> void:
	add_to_group(&"danger_symbol")
	text = "!"
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	font_size = symbol_font_size
	pixel_size = symbol_pixel_size
	outline_size = 48
	outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	render_priority = 10
	outline_render_priority = 9
	visible = false


func _process(delta: float) -> void:
	if not visible or _pop <= 0.0:
		return
	_pop = maxf(_pop - delta / maxf(pop_time, 0.001), 0.0)
	scale = Vector3.ONE * lerpf(1.0, pop_scale, _pop)


## Show the symbol for `source` (the enemy that is attacking), in the given color.
func show_danger(source: Object, color: Color) -> void:
	_source = source
	modulate = color
	_pop = 1.0
	scale = Vector3.ONE * pop_scale
	visible = true


## Hide it, but only if `source` is the one that showed it.
func hide_danger(source: Object) -> void:
	if source != _source:
		return
	_source = null
	visible = false
