class_name LandState
extends ActionState
## 3c-3a PLACEHOLDER(ER numbers) and PLACEHOLDER(ER clip): the landing after a fall or a jump, in two tiers (docs/phase-3-plan.md
## section 14, docs/placeholders.md P1 and P2). `AirState` calls `begin()` the frame the feet touch down.
## - Light (`action`, data/actions/player/land_light.tres): the landing clip of the speed (standing, run or sprint, and the standing one
##   again after walking off a ledge). It never blocks an attack, dodge, jump or guard; walking on is allowed after a very short
##   lockout. The body keeps most of its momentum meanwhile.
## - Heavy (`heavy_action`, land_heavy.tres): a fall of `heavy_fall_height` metres or more. The body stops and stays upright in
##   a deep, slow crouch (the sandbox's fall-landing clip `land_fall`, stretched; its own heavy clip drops the body flat to the
##   ground, so it is not used), dodge is allowed early and everything else at the end.
## Falls under `min_fall_height` make no landing action at all. The cancels are the action's own `cancel_*` times, handed
## back to Locomotion (a press stays buffered, so Locomotion starts it). The debug menu's "Elden Ring-like feel" switch turns
## the whole landing action off in a debug build (OFF = the old straight landing).

## Falls shorter than this (m) make no landing action.
@export var min_fall_height: float = 0.5
## Falls of this height (m) or more are heavy landings. PLACEHOLDER(ER numbers): the sandbox's heavy landing starts at 8 m
## of its own physics; ours is a guess, tuned by playing (a normal jump falls about 2.5 m).
@export var heavy_fall_height: float = 7.5
## The landing of a heavy fall.
@export var heavy_action: ActionData
## Flat speeds (m/s) from which a landing is a run or a sprint landing (the player walks at 2.5, runs at 6.5, dashes at 9.0).
@export var run_land_from: float = 3.75
@export var sprint_land_from: float = 8.0
## A light landing coasts: the body slows by this share of the usual deceleration.
@export var light_coast: float = 0.35
## 3c-4b PLACEHOLDER(ER clip): while locked on, a landing after a jump at a walking or running speed plays the clip of the
## direction the body moves in (front, right, back, left, the order of `FigureLocomotion.direction_index()`). The sprint
## landing, the standing landing, the landing after walking off a ledge and the heavy landing stay as they are.
const STRAFE_WALK_CLIPS: Array = ["land_strafe_walk_front", "land_strafe_walk_right", "land_strafe_walk_back", "land_strafe_walk_left"]
const STRAFE_RUN_CLIPS: Array = ["land_strafe_run_front", "land_strafe_run_right", "land_strafe_run_back", "land_strafe_run_left"]

var _light_action: ActionData
var _heavy: bool = false
var _jumped: bool = true
var _flat_speed: float = 0.0
var _pending_height: float = 0.0
var _pending_jumped: bool = true
var _pending_speed: float = 0.0
var _pending_strafe: bool = false
var _pending_local: Vector2 = Vector2.ZERO
var _strafe: bool = false
var _local: Vector2 = Vector2.ZERO


func _ready() -> void:
	_light_action = action


## True when landings use this action right now (always in a release build).
static func landings_enabled() -> bool:
	return ActionData.er_feel_enabled or not OS.is_debug_build()


## Starts the landing for a fall of `height` metres, after a jump or after walking off a ledge, at `flat_speed` m/s. Returns
## false (and does nothing) when the fall is too short or the switch is off, so the caller lands the old way.
func begin(height: float, jumped: bool, flat_speed: float) -> bool:
	if not landings_enabled() or height < min_fall_height:
		return false
	_pending_height = height
	_pending_jumped = jumped
	_pending_speed = flat_speed
	_pending_strafe = player.lock_on.has_target()
	_pending_local = player.figure.local_flat_velocity(player.velocity)
	machine.transition_to(StateName.LAND)
	return true


func _on_action_enter(_previous: StringName) -> void:
	_heavy = _pending_height >= heavy_fall_height and heavy_action != null
	_jumped = _pending_jumped
	_flat_speed = _pending_speed
	_strafe = _pending_strafe
	_local = _pending_local
	action = heavy_action if _heavy else _light_action
	speed_scale = action.speed_scale


func _clip_name() -> StringName:
	if _heavy:
		return &"land_fall"
	if not _jumped:
		return &"land_light"
	if _strafe and _flat_speed >= FigureLocomotion.JUMP_WALK_FROM and _flat_speed < sprint_land_from:
		var names: Array = STRAFE_RUN_CLIPS if _flat_speed >= run_land_from else STRAFE_WALK_CLIPS
		var chosen: StringName = StringName(String(names[FigureLocomotion.direction_index(_local)]))
		var clips := PlaceholderClips.shared()
		if clips != null and clips.has_clip(String(chosen)):
			return chosen
	if _flat_speed >= sprint_land_from:
		return &"land_sprint"
	if _flat_speed >= run_land_from:
		return &"land_run"
	return &"land_light"


func _slows_active_window() -> bool:
	return false


func _on_action_update(_delta: float) -> void:
	if _wants_out():
		machine.transition_to(StateName.LOCOMOTION)


## An input the action's times allow now (a press waits in the buffer for Locomotion; movement is read live).
func _wants_out() -> bool:
	var buffer := player.input_buffer
	if buffer.has_pressed(Actions.DODGE) and action.can_cancel_input(ActionData.FeelInput.DODGE, action_time):
		return true
	if buffer.has_pressed(Actions.JUMP) and action.can_cancel_input(ActionData.FeelInput.JUMP, action_time):
		return true
	if buffer.has_pressed(Actions.ATTACK) and action.can_cancel_input(ActionData.FeelInput.ATTACK, action_time):
		return true
	if player.get_move_input().length_squared() > 0.01 and action.can_cancel_input(ActionData.FeelInput.MOVE, action_time):
		return true
	return false


func _apply_action_movement(delta: float) -> void:
	if _heavy:
		player.decelerate(delta)
	else:
		player.decelerate(delta * light_coast)
