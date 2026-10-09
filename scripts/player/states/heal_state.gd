class_name HealState
extends State
## The heal (Step 10): drink the gourd. You keep walking (walk speed only). When `duration` runs out the
## health is restored (Player.heal_amount) and one charge is spent; the charge is spent only then.
## A hit that does damage interrupts it and the charge is kept. Dodge, jump, attack, and guard cancel it
## for free. Started by Player._try_heal() from Locomotion, Crouch, or Dash (a crouch is stood up first).
## Placeholder visual: the left arm lifts a gourd to the mouth (HealArm, driven by elapsed / duration),
## and the HUD gourd pulses while this state runs.

@export var duration: float = 1.0

var elapsed: float = 0.0

var _interrupted: bool = false


func enter(_previous: StringName) -> void:
	elapsed = 0.0
	_interrupted = false
	player.walk_only = true
	player.invulnerable = false
	if player.is_crouched:
		player.set_crouched(false)
	player.input_buffer.consume(&"dodge")
	player.input_buffer.consume(&"jump")
	player.input_buffer.consume(&"attack")
	player.input_buffer.consume(&"guard")
	if not player.combatant.damaged.is_connected(_on_damaged):
		player.combatant.damaged.connect(_on_damaged)
	player.heal_arm.begin()


func exit(_next: StringName) -> void:
	player.walk_only = false
	player.heal_arm.end()
	player.notify_combat()
	if player.combatant.damaged.is_connected(_on_damaged):
		player.combatant.damaged.disconnect(_on_damaged)


## A hit that took health ends the heal (handled in physics_update, not in the middle of a hit).
func _on_damaged(_hit: HitData, amount: float) -> void:
	if amount > 0.0:
		_interrupted = true


func physics_update(delta: float) -> void:
	var on_floor := player.is_on_floor()
	if _interrupted:
		machine.transition_to(&"Locomotion" if on_floor else &"Air")
		return
	elapsed += delta
	player.heal_arm.set_progress(elapsed / maxf(duration, 0.01))
	if not on_floor:
		player.apply_gravity(delta)
	# Free cancels.
	if on_floor:
		if player.input_buffer.consume(&"jump"):
			player.start_jump()
			machine.transition_to(&"Air")
			return
		if player.input_buffer.consume(&"dodge"):
			machine.transition_to(&"Dodge")
			return
		if player.input_buffer.has_pressed(&"guard"):
			machine.transition_to(&"Guard")
			return
		if player.has_combo() and player.input_buffer.consume(&"attack"):
			machine.transition_to(&"Attack")
			return
	else:
		if player.input_buffer.has_pressed(&"guard"):
			machine.transition_to(&"Guard")
			return
		player.input_buffer.clear(&"jump")
		player.input_buffer.clear(&"dodge")
	player.apply_horizontal_movement(delta, player.get_move_speed())
	player.face_input(delta)
	if elapsed >= duration:
		player.combatant.heal(player.heal_amount)
		player.heal_charges = maxi(player.heal_charges - 1, 0)
		machine.transition_to(&"Locomotion" if on_floor else &"Air")
