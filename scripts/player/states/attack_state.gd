class_name AttackState
extends ActionState
## Ground combo. Each attack is an ActionData taken from Player.weapon.combo. Pressing
## attack in Locomotion starts attack 1; a press inside the buffer window chains to the next
## attack at the earliest allowed point; after the last attack the next press loops to 1.
## Dodge, jump, and crouch cancel at any time except while the hit window is active.
## No hitboxes or damage yet (Step 4).

## Lunge strength (fraction of the action's move speed) when there is no movement input.
@export var no_input_lunge_factor: float = 0.5
## A lunge stops this far (m) before an edge, so an attack never carries you off a ledge.
@export var ledge_check_distance: float = 0.4

## Zero-based position in the combo (0 = attack 1).
var combo_index: int = 0

var _queued: bool = false


func enter(previous: StringName) -> void:
	var combo := player.weapon.combo
	if previous == &"Attack":
		combo_index = (combo_index + 1) % combo.size()
	else:
		combo_index = 0
	action = combo[combo_index]
	super.enter(previous)


func exit(next: StringName) -> void:
	super.exit(next)
	if next != &"Attack":
		combo_index = 0
		if player.sword_visual != null:
			player.sword_visual.end_combo()


func get_debug_text() -> String:
	var phase := "wind-up"
	if action.is_hit_active(action_time):
		phase = "ACTIVE"
	elif action_time >= action.active_hit.y:
		phase = "recovery"
	var buffer_open := _in_buffer_window()
	var chain_open := action_time >= _chain_time()
	return "Combo: %d/%d (%s)\nBuffer: %s  Chain: %s  Queued: %s" % [
		combo_index + 1, player.weapon.combo.size(), phase,
		"open" if buffer_open else "-", "open" if chain_open else "-", _queued,
	]


func _on_action_enter(_previous: StringName) -> void:
	_queued = false
	_update_lunge_direction(true)
	if player.sword_visual != null:
		player.sword_visual.begin_action(action)


func _on_action_update(delta: float) -> void:
	# Steering: during the wind-up the body turns toward the input, and the lunge follows
	# a held direction. Both lock when the active window starts.
	if action_time < action.active_hit.x and _can_steer():
		player.face_input(delta)
		_update_lunge_direction(false)
	if player.sword_visual != null:
		player.sword_visual.update_action(action, action_time)
	_accept_attack_press()
	if action.is_hit_active(action_time):
		return
	if _try_cancel():
		return
	if _queued and action_time >= _chain_time():
		machine.transition_to(&"Attack")


## Step 9 (lock-on) will return false here while locked on, so lock-on locks the steering.
func _can_steer() -> bool:
	return true


## The lunge direction is the movement input at the attack start (no input: facing, at half
## strength). While steering is allowed, a held input keeps updating it; releasing the input
## keeps the last direction and strength.
func _update_lunge_direction(initial: bool) -> void:
	var input_dir := player.get_move_input()
	if input_dir.length_squared() > 0.01:
		input_dir.y = 0.0
		_move_dir = input_dir.normalized()
		_move_speed_multiplier = 1.0
	elif initial:
		var facing := player.get_facing_direction()
		facing.y = 0.0
		_move_dir = facing.normalized()
		_move_speed_multiplier = no_input_lunge_factor


## Same as the base, but the lunge stops short of an edge.
func _apply_action_movement(delta: float) -> void:
	if _move_dir != Vector3.ZERO and player.is_on_floor() \
			and not player.has_ground_ahead(_move_dir, ledge_check_distance):
		var saved := _move_dir
		_move_dir = Vector3.ZERO
		super(delta)
		_move_dir = saved
		return
	super(delta)


func _try_cancel() -> bool:
	if player.is_on_floor():
		if player.input_buffer.consume(&"dodge"):
			machine.transition_to(&"Dodge")
			return true
		if player.input_buffer.consume(&"jump"):
			player.start_jump()
			machine.transition_to(&"Air")
			return true
		if Input.is_action_just_pressed("crouch"):
			machine.transition_to(&"Crouch")
			return true
	return false


## An attack press counts if it lands inside the buffer window, or up to the input buffer
## time before the window opens (the buffer remembers it).
func _accept_attack_press() -> void:
	if _queued:
		return
	if _in_buffer_window() and player.input_buffer.consume(&"attack"):
		_queued = true


func _in_buffer_window() -> bool:
	var window := action.buffer_window
	if window == Vector2.ZERO:
		return true
	return action_time >= window.x and action_time <= window.y


## Earliest time the next attack may start: where the cancel window opens.
func _chain_time() -> float:
	if action.cancel_window == Vector2.ZERO:
		return action.locked_until
	return action.cancel_window.x
