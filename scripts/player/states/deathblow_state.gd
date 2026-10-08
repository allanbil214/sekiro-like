class_name DeathblowState
extends ActionState
## The deathblow (Step 6): started by Player._try_deathblow() (a fresh attack press near an enemy
## whose deathblow window is open, in front of you). A short scripted slash with no hitbox: the
## player steps toward the target (stopping stop_distance short), and halfway through the hit window
## the target's Combatant.execute_deathblow() is called. Guard cannot cancel it before then.
## The sword looks like a thrust (actions/deathblow_thrust.tres, visual only) when drawn, and like the
## iai draw slash (the weapon's draw attack poses) while sheathed. Timing always comes from `action`.
## The action defaults to res://actions/deathblow.tres if none is set in the Inspector.

const DEFAULT_ACTION: ActionData = preload("res://actions/deathblow.tres")
const THRUST_VISUAL: ActionData = preload("res://actions/deathblow_thrust.tres")

## The player stops this close (m, flat) to the target's center.
@export var stop_distance: float = 1.1
## Hitstop (s) when the deathblow lands.
@export var landing_hitstop: float = 0.15

var _target: Node3D
var _executed: bool = false
var _visual_action: ActionData


func _ready() -> void:
	if action == null:
		action = DEFAULT_ACTION


func _slows_active_window() -> bool:
	return false


func _on_action_enter(_previous: StringName) -> void:
	_executed = false
	_target = player.deathblow_target
	_visual_action = THRUST_VISUAL
	if player.sheathed and player.weapon != null and player.weapon.draw_attack != null:
		_visual_action = player.weapon.draw_attack
	if player.sword_visual != null:
		player.sword_visual.begin_action(_visual_action)
	if _target != null:
		var to_target := _target.global_position - player.global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.0001:
			_move_dir = to_target.normalized()
			player.snap_facing(_move_dir)


func _on_action_exit() -> void:
	_target = null
	if player.sword_visual != null:
		player.sword_visual.end_combo()


func _on_action_update(_delta: float) -> void:
	if _target != null and is_instance_valid(_target) and _move_dir != Vector3.ZERO:
		var to_target := _target.global_position - player.global_position
		to_target.y = 0.0
		if to_target.length() <= stop_distance:
			_move_dir = Vector3.ZERO
	if player.sword_visual != null:
		player.sword_visual.update_action(_visual_action, action_time)
	var strike_time := action.active_hit.x + (action.active_hit.y - action.active_hit.x) * 0.5
	if not _executed and action_time >= strike_time:
		_executed = true
		var combatant: Combatant = null
		if is_instance_valid(_target):
			combatant = Combatant.of(_target)
		if combatant != null and combatant.execute_deathblow():
			Hitstop.request(player.get_tree(), landing_hitstop)
			player.notify_combat()
		return
	if _executed and action.can_cancel(action_time):
		if player.input_buffer.consume(&"dodge"):
			machine.transition_to(&"Dodge")


func _allows_guard_cancel() -> bool:
	return _executed
