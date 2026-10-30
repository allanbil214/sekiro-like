class_name HurtState
extends ActionState
## 3c-3b-1 PLACEHOLDER(ER numbers) and PLACEHOLDER(ER clip): the player's reaction to a hit, in four strengths (small, middle,
## large, knockdown; HitData.HurtLevel) from four sides, and to a guard break (docs/phase-3-plan.md section 15, docs/placeholders.md
## P1 and P2). `Player._update_hurt()` starts it from the hit that landed.
## - Which hits react: small ones only while the player is free (locomotion, crouch, landing); middle, large and knockdown also
##   interrupt an attack, a heal, a guard and the like. Never in the air, in a dodge, on a ledge, in a stagger, a deathblow,
##   resting or dead. A hit during a reaction restarts it only when it is stronger (no stunlock).
## - The lockout is the action's own `cancel_*` times (dodge opens first); an input they allow hands back to Locomotion and the
##   press stays buffered (as `LandState`).
## - Knockdown: thrown back, and invulnerable for the action's `iframes` window.
## - The debug menu's "Elden Ring-like feel" switch turns it all off in a debug build (OFF = the old wobble only).
## Each action's duration is the sandbox's clip scaled to about 0.6, so the clip plays faster than the original.

## The five reactions. Set in the editor on the `Hurt` node (data/actions/player/hurt_*.tres).
@export var small_action: ActionData
@export var middle_action: ActionData
@export var large_action: ActionData
@export var knockdown_action: ActionData
@export var guard_break_action: ActionData
## How far (m) and over how long (s) a knockdown throws the body back, on top of the hit's own knockback.
@export var knockdown_throw: float = 2.5
@export var knockdown_throw_time: float = 0.5

const LEVEL_NAMES: Array[String] = ["small", "middle", "large", "knockdown"]
## States that never react: they handle a hit themselves or must not be interrupted.
const NEVER: Array[StringName] = [StateName.DODGE, StateName.DEAD, StateName.DEATHBLOW, StateName.STAGGER, StateName.AIR,
		StateName.WALL_JUMP, StateName.AIR_ATTACK, StateName.HELM_SPLITTER, StateName.LEDGE_HANG, StateName.LEDGE_CLIMB,
		StateName.WALL_HUG, StateName.REST, StateName.COVER_PLACE]
## States a small hit may react in: the player is free.
const FREE: Array[StringName] = [StateName.LOCOMOTION, StateName.CROUCH, StateName.LAND]

var level: int = HitData.HurtLevel.SMALL
var guard_break: bool = false
var _side: StringName = &"front"
var _push: Vector3 = Vector3.ZERO
var _pending_level: int = HitData.HurtLevel.SMALL
var _pending_guard_break: bool = false
var _pending_side: StringName = &"front"
var _pending_push: Vector3 = Vector3.ZERO


## True when reactions are on right now (always in a release build).
static func reactions_enabled() -> bool:
	return ActionData.er_feel_enabled or not OS.is_debug_build()


## Would a hit of this strength react now?
func can_react(hit_level: int) -> bool:
	if not reactions_enabled() or player.combatant.dead:
		return false
	var current := machine.current
	if current == self:
		return hit_level > level and level != HitData.HurtLevel.KNOCKDOWN and not guard_break
	if current == null or NEVER.has(current.name):
		return false
	if hit_level <= HitData.HurtLevel.SMALL:
		return FREE.has(current.name)
	return true


## Would a guard break react now? (It runs after the guard dropped, so the state is already Locomotion or Air.)
func can_react_guard_break() -> bool:
	if not reactions_enabled() or player.combatant.dead:
		return false
	var current := machine.current
	return current != null and current != self and not NEVER.has(current.name)


## Starts the reaction for this hit (its strength and the side it came from).
func begin(hit: HitData) -> void:
	_pending_level = clampi(hit.hurt_level, HitData.HurtLevel.SMALL, HitData.HurtLevel.KNOCKDOWN)
	_pending_guard_break = false
	_pending_side = _side_of(hit)
	_pending_push = hit.direction
	machine.transition_to(StateName.HURT)


## Starts the guard break reaction.
func begin_guard_break(hit: HitData) -> void:
	_pending_level = HitData.HurtLevel.LARGE
	_pending_guard_break = true
	_pending_side = _side_of(hit)
	_pending_push = hit.direction
	machine.transition_to(StateName.HURT)


## The side the hit came from, relative to where the player faces.
func _side_of(hit: HitData) -> StringName:
	var local := player.global_transform.basis.inverse() * (-hit.direction)
	if absf(local.z) >= absf(local.x):
		return &"front" if local.z < 0.0 else &"back"
	return &"right" if local.x > 0.0 else &"left"


## The base class reads `action` the moment the state starts, so the reaction is chosen here first (the `action` set in the
## editor is never used, and may stay empty).
func enter(previous: StringName) -> void:
	level = _pending_level
	guard_break = _pending_guard_break
	_side = _pending_side
	_push = _pending_push
	if guard_break:
		action = guard_break_action
	else:
		match level:
			HitData.HurtLevel.SMALL:
				action = small_action
			HitData.HurtLevel.MIDDLE:
				action = middle_action
			HitData.HurtLevel.LARGE:
				action = large_action
			_:
				action = knockdown_action
	super.enter(previous)


func _on_action_enter(_previous: StringName) -> void:
	# A press made before the hit must not fire the moment the reaction lets go.
	for action_name: StringName in [Actions.JUMP, Actions.DODGE, Actions.ATTACK, Actions.GUARD]:
		player.input_buffer.clear(action_name)
	if player.sword_visual != null:
		player.sword_visual.end_combo()
	if level == HitData.HurtLevel.KNOCKDOWN and not guard_break and knockdown_throw > 0.0 and _push.length_squared() > 0.0001:
		player.apply_knockback(_push, knockdown_throw, knockdown_throw_time)


func _clip_name() -> StringName:
	if guard_break:
		return &"guard_break"
	return StringName("hurt_%s_%s" % [LEVEL_NAMES[level], _side])


func _slows_active_window() -> bool:
	return false


func _on_action_update(_delta: float) -> void:
	if _wants_out():
		machine.transition_to(StateName.LOCOMOTION if player.is_on_floor() else StateName.AIR)


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
	player.decelerate(delta)
