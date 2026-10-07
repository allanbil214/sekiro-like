class_name AttackState
extends ActionState
## Ground combo. Each attack is an ActionData taken from Player.weapon.combo. Pressing
## attack in Locomotion starts attack 1; a press inside the buffer window chains to the next
## attack at the earliest allowed point; after the last attack the next press loops to 1.
## Dodge, jump, and crouch cancel at any time except while the hit window is active.
##
## Hold: if the attack button is still held when the wind-up ends, the attack becomes a
## charge and fires Player.weapon.thrust when the button is released (or at max charge).
## A thrust takes the combo step it falls on. Its side connects to the combo: chained from a
## slash it starts on the side where that slash ended; chained from a thrust it takes the
## opposite side (zigzag); started from idle it is right-aligned.
## Variants (3b): Dash, Crouch, and Slide hand over a variant ActionData with
## try_start_variant(). A dash variant counts as combo step 1, so the next tap chains to
## attack 2. The crouch variant is a left/right loop (ActionData.combo_next, the second one
## loops back to the first) that keeps you crouched and ends back in Crouch; holding at the end
## of a wind-up swaps in the upward slash, which stands you up and chains on into attack 1.
## Sheathed (3c): the draw slash (Player.weapon.draw_attack) replaces every attack variant and the
## first ground attack. It counts as no combo step, so the next tap is attack 1 (after a crouched
## draw slash it is the crouch loop, since you stay crouched).
## Charged iai (3c-2): the draw slash's Hold Action. Holding attack at the end of its wind-up charges
## it (the blade half drawn, orange glow) and fires the charged draw slash on release or at full
## charge. It replaces the ground thrust and the dash, dodge, crouch, and slide holds while sheathed.
## From a crouch or slide it stands you up when it fires (no headroom: the hold is ignored). It is
## never mirrored and counts as no combo step, so the next tap is attack 1.
## No hitboxes or damage yet (Step 4).

enum Phase { NORMAL, WAITING, CHARGING }

## Lunge strength (fraction of the action's move speed) when there is no movement input.
@export var no_input_lunge_factor: float = 0.5
## A lunge stops this far (m) before an edge, so an attack never carries you off a ledge.
@export var ledge_check_distance: float = 0.4
## The lunge also stops this many seconds of travel before an edge (the larger distance wins).
@export var ledge_check_time: float = 0.14
## Grace at the end of the wind-up: if the attack button is still held then, wait up to this
## many seconds for it to be released (still a normal slash) before charging. 0 = decide at once.
@export var hold_extra_time: float = 0.0

## While charging, the action clock is frozen this far (s) before the hit window opens, so
## cancels (which are blocked during the hit window) stay allowed.
const FREEZE_MARGIN: float = 0.001

## Zero-based position in the combo (0 = attack 1).
var combo_index: int = 0
## Damage multiplier of the current attack (1.0, or up to the thrust's charge_damage_max).
## Stored for Step 4.
var damage_multiplier: float = 1.0

var _queued: bool = false
var _pending_variant: ActionData
## The pending variant is the draw slash: it counts as no combo step (the next tap is attack 1).
var _pending_uncounted: bool = false
## Set by try_continue_combo(): start the ground combo at this zero-based step (-1 = none).
var _pending_index: int = -1
var _is_variant: bool = false
var _hold_action: ActionData
var _variant_root: ActionData
## True while the attack plays crouched (it started from Crouch or Slide).
var _crouch_context: bool = false
## True after the upward slash stood you up: the next chain is attack 1.
var _rose: bool = false
var _phase: Phase = Phase.NORMAL
var _decided: bool = false
var _is_thrust: bool = false
var _hold_wait: float = 0.0
## True once the attack button was up at any time since this action began. A hold only counts
## if the button stayed down the whole time, so rapid clicks are never read as a hold.
var _released: bool = false
var _charge_time: float = 0.0
var _freeze_time: float = 0.0
var _lunge_scale: float = 1.0
var _thrust_side_left: bool = false
var _thrust_mirror: bool = false
## The hold in progress (or fired) is the charged iai, not a thrust or the upward slash.
var _iai_hold: bool = false


func enter(previous: StringName) -> void:
	var combo := player.weapon.combo
	_crouch_context = player.is_crouched
	if _pending_variant != null:
		# A variant (dash attack, crouch loop) counts as step 1 of the combo.
		action = _pending_variant
		_pending_variant = null
		_variant_root = action
		_is_variant = true
		_rose = false
		_thrust_side_left = false
		# The draw slash counts as no step (index -1), so a chained tap is attack 1.
		combo_index = -1 if _pending_uncounted else 0
		_pending_uncounted = false
	elif _pending_index >= 0:
		# Handed over from an air attack that landed: carry on with the ground combo.
		combo_index = clampi(_pending_index, 0, combo.size() - 1)
		_pending_index = -1
		_is_variant = false
		_rose = false
		_thrust_side_left = false
		action = combo[combo_index]
	elif previous == &"Attack" and _rose:
		# The upward slash stood you up: carry on with the combo from attack 1.
		_rose = false
		_is_variant = false
		_thrust_side_left = false
		combo_index = 0
		action = combo[0]
	elif previous == &"Attack" and _is_variant and _crouch_context \
			and _variant_root == player.weapon.draw_attack and player.weapon.crouch_attack != null:
		# A crouched draw slash: the next tap is the crouch loop (you stay crouched).
		_thrust_side_left = _side_left_after_previous()
		_variant_root = player.weapon.crouch_attack
		action = _variant_root
		combo_index = 0
	elif previous == &"Attack" and _is_variant and _variant_root != null \
			and _variant_root.combo_next != null:
		# A variant loop (the crouch attacks): follow combo_next, then back to the first.
		# A hold out of it starts on the side where the previous attack ended.
		_thrust_side_left = false if _is_thrust else _side_left_after_previous()
		if not _is_thrust and action.combo_next != null:
			action = action.combo_next
		else:
			action = _variant_root
		combo_index = 0
	else:
		_is_variant = false
		if previous == &"Attack":
			# `action` still holds the attack we are chaining from.
			_thrust_side_left = _side_left_after_previous()
			combo_index = (combo_index + 1) % combo.size()
		else:
			_thrust_side_left = false
			combo_index = 0
		action = combo[combo_index]
	super.enter(previous)


## Another state (Dash, Dodge, Crouch, Slide) asks to start a variant attack. Returns false if
## the weapon has none. The state calls this instead of transitioning itself. While sheathed
## the draw slash replaces the variant.
func try_start_variant(variant: ActionData) -> bool:
	if try_start_draw():
		return true
	if variant == null:
		return false
	_pending_variant = variant
	_pending_uncounted = false
	machine.transition_to(&"Attack")
	return true


## Attack pressed while sheathed: start the draw slash (iai). Returns false if the sword is
## drawn or the weapon has no draw slash. It counts as no combo step.
func try_start_draw() -> bool:
	if not player.sheathed or player.weapon == null or player.weapon.draw_attack == null:
		return false
	_pending_variant = player.weapon.draw_attack
	_pending_uncounted = true
	machine.transition_to(&"Attack")
	return true


## The air attack landed with a tap queued: continue the ground combo at this zero-based step
## (1 = attack 2, since an air attack counts as step 1). Returns false if there is no combo.
func try_continue_combo(index: int) -> bool:
	if player.weapon == null or player.weapon.combo.is_empty():
		return false
	_pending_index = index
	machine.transition_to(&"Attack")
	return true


func exit(next: StringName) -> void:
	super.exit(next)
	if next != &"Attack":
		combo_index = 0
		_thrust_side_left = false
		_phase = Phase.NORMAL
		_rose = false
		# Leaving a crouch attack for anything but Crouch: stand up (Crouch keeps you crouched).
		if _crouch_context and next != &"Crouch":
			player.set_crouched(false)
		_crouch_context = false
		if player.sword_visual != null:
			player.sword_visual.end_combo()


func get_debug_text() -> String:
	var phase := "wind-up"
	if action.is_hit_active(action_time):
		phase = "ACTIVE"
	elif action_time >= action.active_hit.y:
		phase = "recovery"
	var kind := "Combo"
	if _is_thrust:
		kind = "THRUST"
	elif _is_variant:
		kind = "DRAW" if action == player.weapon.draw_attack else "VARIANT"
	if _iai_hold and _phase == Phase.NORMAL:
		kind = "CHARGED IAI"
	if _crouch_context:
		kind += " (crouched)"
	var text := "%s: %d/%d (%s)\nBuffer: %s  Chain: %s  Queued: %s" % [
		kind, combo_index + 1, player.weapon.combo.size(), phase,
		"open" if _in_buffer_window() else "-",
		"open" if action_time >= _chain_time() else "-", _queued,
	]
	if _phase == Phase.WAITING:
		text += "\nHold: deciding..."
	elif _phase == Phase.CHARGING:
		if _iai_hold:
			text += "\nCHARGED IAI: %.2f / %.2f" % [_charge_time, _hold_action.charge_time]
		else:
			text += "\nCharge: %.2f / %.2f (%s next)" % [
				_charge_time, _hold_action.charge_time, "left" if _thrust_mirror else "right"]
	elif _is_thrust:
		text += "\nThrust: %s, damage x%.2f, lunge x%.2f" % [
			"left" if _thrust_mirror else "right", damage_multiplier, _lunge_scale]
	return text


func _on_action_enter(_previous: StringName) -> void:
	_queued = false
	_phase = Phase.NORMAL
	_decided = false
	_is_thrust = false
	_hold_wait = 0.0
	_released = false
	_charge_time = 0.0
	_hold_action = null
	_lunge_scale = 1.0
	damage_multiplier = 1.0
	_iai_hold = false
	# A new action is never mirrored unless its own hold sets it (the old mirror stuck after a left thrust).
	_thrust_mirror = false
	_update_lunge_direction(true)
	if player.sword_visual != null:
		player.sword_visual.begin_action(action)


## Crouch attacks end back in Crouch (you stay crouched); everything else ends standing.
func _on_action_finished() -> void:
	if _crouch_context:
		machine.transition_to(&"Crouch")
	else:
		super()


func _on_action_update(delta: float) -> void:
	if _phase == Phase.NORMAL and not Input.is_action_pressed("attack"):
		_released = true
	# The decision point is the end of the wind-up: still holding attack = charge a thrust.
	if _phase == Phase.NORMAL and not _is_thrust and not _decided \
			and action_time >= action.active_hit.x:
		_decide()
	if _phase != Phase.NORMAL:
		_update_hold(delta)
		return
	# Steering: during the wind-up the body turns toward the movement input, and the lunge
	# follows a held direction. Both lock when the active window starts.
	if action_time < action.active_hit.x and _can_steer():
		player.face_input(delta)
		_update_lunge_direction(false)
	if player.sword_visual != null:
		player.sword_visual.update_action(action, action_time, _thrust_mirror)
	_accept_attack_press()
	if action.is_hit_active(action_time):
		return
	if _try_cancel():
		return
	if _queued and action_time >= _chain_time():
		machine.transition_to(&"Attack")


## A charged thrust or iai hits harder (the stored charge multiplier).
func _hit_damage_multiplier() -> float:
	return damage_multiplier


## No hits while waiting or charging a hold: the clock is parked at the start of the hit window.
func _hit_is_active() -> bool:
	return _phase == Phase.NORMAL and super._hit_is_active()


## Step 9 (lock-on) will return false here while locked on, so lock-on locks the steering.
func _can_steer() -> bool:
	return true


## What replaces this attack when the button is held at the end of its wind-up: its own
## Hold Action, or (for a ground combo attack with none) the weapon's charged thrust.
func _hold_target() -> ActionData:
	# Standing up for the upward slash needs headroom.
	if _crouch_context and not player.can_stand():
		return null
	if action.hold_action != null:
		return action.hold_action
	if _is_variant:
		return null
	return player.weapon.thrust


## The wind-up just ended: hold = swap in the hold action, otherwise carry on as a slash.
func _decide() -> void:
	var target := _hold_target()
	if target != null and not _released and Input.is_action_pressed("attack"):
		_hold_action = target
		_iai_hold = action == player.weapon.draw_attack
		_hold_wait = 0.0
		_freeze_time = action.active_hit.x - FREEZE_MARGIN
		if hold_extra_time > 0.0:
			_phase = Phase.WAITING
		else:
			_begin_hold()
	else:
		_decided = true


## Start the hold action: charge first if it has a charge time, otherwise swap it in at once.
func _begin_hold() -> void:
	# Thrusts are authored right-handed (mirrored to start left); a slash-style hold action
	# (the crouch upward slash) is authored left-handed (mirrored to start right).
	if _iai_hold:
		_thrust_mirror = false
	elif _hold_action.blade_aims_at_end:
		_thrust_mirror = _thrust_side_left
	else:
		_thrust_mirror = not _thrust_side_left
	if _hold_action.charge_time <= 0.0:
		_fire_thrust(0.0)
		return
	_phase = Phase.CHARGING
	_charge_time = 0.0
	if player.sword_visual != null:
		player.sword_visual.begin_charge()


## Waiting (grace) or charging: the action clock is frozen at the end of the wind-up.
func _update_hold(delta: float) -> void:
	action_time = _freeze_time
	if _can_steer():
		player.face_input(delta)
	if _try_cancel():
		return
	var held := Input.is_action_pressed("attack")
	if _phase == Phase.WAITING:
		_hold_wait += delta
		if player.sword_visual != null:
			player.sword_visual.update_action(action, action_time)
		if not held:
			# Released inside the grace time: a normal slash after all.
			_phase = Phase.NORMAL
			_decided = true
		elif _hold_wait >= hold_extra_time:
			_begin_hold()
		return
	_charge_time += delta
	var thrust := _hold_action
	var fraction := clampf(_charge_time / thrust.charge_time, 0.0, 1.0)
	if player.sword_visual != null:
		if _iai_hold:
			player.sword_visual.update_charge_iai(thrust, _charge_time, fraction)
		else:
			player.sword_visual.update_charge(thrust, _thrust_mirror, _charge_time, fraction)
	if not held or fraction >= 1.0:
		_fire_thrust(fraction)


## Release (or max charge): swap the slash for the hold action (the thrust), scaled by the
## charge so far.
func _fire_thrust(fraction: float) -> void:
	var thrust := _hold_action
	damage_multiplier = lerpf(1.0, thrust.charge_damage_max, fraction)
	_lunge_scale = lerpf(1.0, thrust.charge_lunge_max, fraction)
	action = thrust
	action_time = 0.0
	speed_scale = thrust.speed_scale
	_phase = Phase.NORMAL
	_is_thrust = not _iai_hold
	_decided = true
	_queued = false
	if _crouch_context:
		# The upward slash or the charged iai out of a crouch: stand up now and carry on standing.
		_crouch_context = false
		_rose = true
		player.set_crouched(false)
	_move_dir = Vector3.ZERO
	_move_speed_multiplier = 1.0
	_update_lunge_direction(true)
	if player.sword_visual != null:
		player.sword_visual.begin_action(action)


## Which side a thrust chained from the previous attack starts on: the opposite of a previous
## thrust's side, or the side where a previous slash ended (from its swing_end pose; a slash
## ending near the center line counts as right).
func _side_left_after_previous() -> bool:
	if _is_thrust:
		return not _thrust_mirror
	var lateral := sin(deg_to_rad(action.swing_end.x * 30.0))
	return lateral < -0.1


## The lunge direction is the movement input at the attack start (no input: facing, at half
## strength). While steering is allowed, a held input keeps updating it; releasing the input
## keeps the last direction and strength. A charged thrust scales it by _lunge_scale.
func _update_lunge_direction(initial: bool) -> void:
	var input_dir := player.get_move_input()
	if input_dir.length_squared() > 0.01:
		input_dir.y = 0.0
		_move_dir = input_dir.normalized()
		_move_speed_multiplier = _lunge_scale
	elif initial:
		var facing := player.get_facing_direction()
		facing.y = 0.0
		_move_dir = facing.normalized()
		_move_speed_multiplier = no_input_lunge_factor * _lunge_scale


## Same as the base, but there is no lunge while charging, and the lunge stops short of an
## edge: at least ledge_check_distance, or ledge_check_time of travel at the lunge speed.
func _apply_action_movement(delta: float) -> void:
	if _phase != Phase.NORMAL:
		player.decelerate(delta)
		return
	if _move_dir != Vector3.ZERO and player.is_on_floor():
		var check := maxf(ledge_check_distance,
				action.move_speed * _move_speed_multiplier * ledge_check_time)
		if not player.has_ground_ahead(_move_dir, check):
			var saved := _move_dir
			_move_dir = Vector3.ZERO
			super(delta)
			_move_dir = saved
			return
	super(delta)


func _try_cancel() -> bool:
	if _crouch_context and player.is_on_floor():
		return _try_cancel_crouched()
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


## Cancels while crouched follow the Crouch state: dodge and jump need headroom, and pressing
## crouch (or releasing it, in hold mode) stands you up.
func _try_cancel_crouched() -> bool:
	var headroom := player.can_stand()
	if player.input_buffer.has_pressed(&"dodge"):
		if headroom:
			player.input_buffer.consume(&"dodge")
			machine.transition_to(&"Dodge")
			return true
		player.input_buffer.clear(&"dodge")
	if player.input_buffer.has_pressed(&"jump"):
		if headroom:
			player.input_buffer.consume(&"jump")
			player.start_jump()
			machine.transition_to(&"Air")
			return true
		player.input_buffer.clear(&"jump")
	if headroom:
		var wants_stand := not Input.is_action_pressed("crouch") if player.crouch_is_hold \
				else Input.is_action_just_pressed("crouch")
		if wants_stand:
			machine.transition_to(&"Locomotion")
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
