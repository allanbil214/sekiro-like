class_name HelmSplitterState
extends ActionState
## Helm splitter (3b-4): hold attack in the air (at the end of an air attack's wind-up) to dive.
## DIVE: the blade goes from 12:00 to 6:00 and is held there while gravity is multiplied, until
## you land. LAND: a wind-down (land_action) that can be cancelled from its cancel window, or
## chained into the ground combo at attack 2 (the helm splitter counts as combo step 1).
##
## The body crouches (Player.set_crouched, the same shrink as the crouch) for the whole dive and
## wind-down, so the blade lies low on the ground. It stands up when the state exits; with no
## headroom it ends in Crouch, and dodge, jump, and chain presses are ignored until there is room.
##
## Sheathed (3c-2): the dive can start from the draw slash's hold (start(..., opening = true)). Its
## longer wind-up then plays under reduced gravity (opening_gravity_factor), then the usual dive.
##
## Once per airtime (Player.helm_used, cleared by reset_air_actions). No hover, no cancels during
## the dive, normal air control. No hitboxes or damage yet (Step 4): the dive action's active_hit
## is a placeholder, and the clock is held inside it for the whole fall.

enum Phase { DIVE, LAND }

## The wind-down played after landing (its own ActionData).
@export var land_action: ActionData
## Extra gravity while diving, as a multiple of the player's current gravity (2.5 = 2.5x).
@export var dive_gravity_factor: float = 2.5
## Gravity multiple (0.5 = half) while the sheathed helm splitter's wind-up plays, and while the
## attack is held during the draw slash's wind-up in the air. Only used for the sheathed version.
@export var opening_gravity_factor: float = 0.5

## Keeps the held clock just inside the active window so the pose stays at 6:00.
const HOLD_MARGIN: float = 0.002

var _phase: Phase = Phase.DIVE
var _queued: bool = false
var _pending: ActionData
var _dive_default: ActionData
var _pending_opening: bool = false
## True for the sheathed version: the wind-up is played under opening_gravity_factor.
var _opening: bool = false


func _ready() -> void:
	_dive_default = action


## Called by AirAttackState when the hold is decided. Returns false if it cannot start.
func start(dive: ActionData, opening: bool = false) -> bool:
	if land_action == null or (dive == null and _dive_default == null):
		return false
	_pending = dive
	_pending_opening = opening
	machine.transition_to(&"HelmSplitter")
	return true


func enter(previous: StringName) -> void:
	_phase = Phase.DIVE
	action = _pending if _pending != null else _dive_default
	_pending = null
	_opening = _pending_opening
	_pending_opening = false
	player.helm_used = true
	player.set_crouched(true)
	super.enter(previous)


func exit(next: StringName) -> void:
	super.exit(next)
	# Stand up, unless we are going to Crouch (callers check headroom first).
	if next != &"Crouch":
		player.set_crouched(false)
	# Chaining into the ground combo carries the sword's pose over; anything else lets it rest.
	if next != &"Attack" and player.sword_visual != null:
		player.sword_visual.end_combo()


func get_debug_text() -> String:
	if _phase == Phase.DIVE:
		return "Helm splitter (DIVE) vel.y: %.1f" % player.velocity.y
	return "Helm splitter (wind-down)\nCancel: %s  Queued: %s" % [
		"open" if action.can_cancel(action_time) else "-", _queued,
	]


func _on_action_enter(_previous: StringName) -> void:
	_queued = false
	if player.sword_visual != null:
		player.sword_visual.begin_action(action)


func _on_action_update(delta: float) -> void:
	if _phase == Phase.DIVE:
		_update_dive(delta)
	else:
		_update_land()


func _update_dive(delta: float) -> void:
	# ActionState already applied normal gravity; add the rest of the dive's pull.
	if not player.is_on_floor():
		var factor := dive_gravity_factor
		if _opening and action_time < action.active_hit.x:
			factor = opening_gravity_factor
		player.velocity += player.get_gravity() * player.gravity_multiplier \
				* (factor - 1.0) * delta
	if action_time < action.active_hit.x:
		player.face_input(delta)
	# Hold the blade at the end of the stab until landing.
	action_time = minf(action_time, action.active_hit.y - HOLD_MARGIN)
	if player.sword_visual != null:
		player.sword_visual.update_action(action, action_time)
	if player.is_on_floor() and player.velocity.y <= 0.0:
		_begin_land()


func _begin_land() -> void:
	player.reset_air_actions()
	_phase = Phase.LAND
	action = land_action
	action_time = 0.0
	speed_scale = action.speed_scale
	_queued = false
	if player.sword_visual != null:
		player.sword_visual.begin_action(action)


func _update_land() -> void:
	# Walked off an edge during the wind-down.
	if not player.is_on_floor():
		machine.transition_to(&"Air" if player.can_stand() else &"Crouch")
		return
	if player.sword_visual != null:
		player.sword_visual.update_action(action, action_time)
	_accept_attack_press()
	if not action.can_cancel(action_time):
		return
	if _try_cancel():
		return
	if _queued:
		if not player.can_stand():
			_queued = false
			return
		var attack := machine.get_node_or_null("Attack") as AttackState
		if attack != null and attack.try_continue_combo(1):
			return
		_queued = false


## Air control during the dive; braking after landing.
func _apply_action_movement(delta: float) -> void:
	if _phase == Phase.DIVE and not player.is_on_floor():
		player.apply_horizontal_movement(delta, player.get_move_speed())
	else:
		player.decelerate(delta)


func _on_action_finished() -> void:
	# The dive clock is held, so only the wind-down ever finishes.
	if _phase != Phase.LAND:
		return
	if not player.can_stand():
		machine.transition_to(&"Crouch")
	elif player.is_on_floor():
		machine.transition_to(&"Locomotion")
	else:
		machine.transition_to(&"Air")


func _try_cancel() -> bool:
	# Dodge and jump stand you up, so they need headroom (otherwise the press is discarded).
	var headroom := player.can_stand()
	if player.input_buffer.consume(&"dodge") and headroom:
		machine.transition_to(&"Dodge")
		return true
	if player.input_buffer.consume(&"jump") and headroom:
		player.start_jump()
		machine.transition_to(&"Air")
		return true
	if Input.is_action_just_pressed("crouch"):
		machine.transition_to(&"Crouch")
		return true
	return false


func _accept_attack_press() -> void:
	if _queued:
		return
	var window := action.buffer_window
	var open := window == Vector2.ZERO or (action_time >= window.x and action_time <= window.y)
	if open and player.input_buffer.consume(&"attack"):
		_queued = true
