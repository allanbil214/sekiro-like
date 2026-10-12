class_name ScreenFade
extends CanvasLayer
## A full-screen black fade (Phase 2, item 3a). A direct child of Player; the fall respawn uses it to
## cover the teleport, and later checkpoints can reuse it. Layer 25: above the HUD, the death screen and
## the vignette, under the pause menu (30). It starts clear and never blocks the mouse.

@export var fade_color: Color = Color(0.0, 0.0, 0.0)

var _rect: ColorRect
var _tween: Tween


func _ready() -> void:
	layer = 25
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = fade_color
	_rect.modulate.a = 0.0
	_rect.visible = false
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Fade from clear to black over `time` seconds (0 or less = at once).
func fade_out(time: float) -> void:
	_fade_to(1.0, time)


## Fade from black back to clear over `time` seconds (0 or less = at once).
func fade_in(time: float) -> void:
	_fade_to(0.0, time)


func _fade_to(alpha: float, time: float) -> void:
	if _tween != null:
		_tween.kill()
	_rect.color = fade_color
	_rect.visible = true
	if time <= 0.0:
		_rect.modulate.a = alpha
		_rect.visible = alpha > 0.0
		return
	_tween = create_tween()
	_tween.tween_property(_rect, "modulate:a", alpha, time)
	if alpha <= 0.0:
		_tween.tween_callback(func() -> void: _rect.visible = false)
