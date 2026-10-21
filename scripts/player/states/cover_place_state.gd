class_name CoverPlaceState
extends State
## Hiding a carried body in a `CoverVolume` (Phase 2 item 15b). Started by `Player.begin_cover_place()` with the
## plan in `Player.cover_plan`: the player glides to the spot (`cover_glide_time`, nothing for a solid
## container), turns to face the body's place, and the body is laid in (`Player.finish_cover_place`). The
## stance (standing or crouched) is kept. A dodge or jump press, or pushing the stick away from the spot,
## cancels it: the body stays carried and the player stays where it is (the press stays in the buffer).

var _plan: Dictionary = {}
var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _glide: float = 0.0
var _was_crouched: bool = false


func enter(_previous: StringName) -> void:
	_plan = player.cover_plan
	_was_crouched = player.is_crouched
	_from = player.global_position
	_to = _plan["feet"] if not _plan.is_empty() else _from
	_time = 0.0
	var distance := Vector2(_to.x - _from.x, _to.z - _from.z).length()
	_glide = player.cover_glide_time if distance > 0.05 else 0.0
	player.velocity = Vector3.ZERO


func physics_update(delta: float) -> void:
	player.velocity = Vector3.ZERO
	if _plan.is_empty():
		_back()
		return
	if player.input_buffer.has_pressed(Actions.JUMP) or player.input_buffer.has_pressed(Actions.DODGE):
		_cancel()
		return
	var way := _to - _from
	way.y = 0.0
	var want := player.get_move_input()
	want.y = 0.0
	if way.length() > 0.05 and want.length() > 0.5 and want.normalized().dot(way.normalized()) < -0.5:
		_cancel()
		return
	_time += delta
	var u := 1.0 if _glide <= 0.0 else clampf(_time / _glide, 0.0, 1.0)
	player.global_position = _from.lerp(_to, smoothstep(0.0, 1.0, u))
	var facing := Basis(Vector3.UP, float(_plan["yaw"])) * Vector3.FORWARD
	player.face_direction(facing, delta)
	if u >= 1.0:
		player.snap_facing(facing)
		player.finish_cover_place()
		_back()


func _cancel() -> void:
	player.cover_plan = {}
	_back()


func _back() -> void:
	machine.transition_to(StateName.CROUCH if _was_crouched else StateName.LOCOMOTION)
