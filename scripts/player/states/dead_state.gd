class_name DeadState
extends State
## Death and resurrection (Step 10). Entered by Player._update_death() when health hits 0.
## The body lies down (the stagger lean and kneel, no sway), there is no control, and the enemies stand
## down (they see a dead player). The lock-on is released and locked out; the enemy that was locked is
## remembered. After `prompt_delay` the prompt shows: attack = Resurrect, guard = Die. With no
## resurrection left there is no choice: it dies by itself after `final_death_time`.
## Resurrect: Player.resurrect() (half health, no posture, brief invulnerability), the same enemy is
## locked again if it is alive, and the state ends. Die: `death_confirmed` starts the fade to black, and
## after `die_fade_time` the scene reloads (heal charges and resurrections come back with it).
## The death screen (DeathScreen) only listens to the Player's death signals.

## How long (s) after dying before the prompt appears.
@export var prompt_delay: float = 1.0
## With no resurrection left: how long (s) the "DEATH" screen stays before the fade starts.
@export var final_death_time: float = 3.0
## The fade to black (s) when dying for good; the scene reloads when it ends.
@export var die_fade_time: float = 1.0
## How far (radians) the body lies down (the stagger lean; the kneel sinks it too). Placeholder look.
@export var lie_lean: float = 1.3

var elapsed: float = 0.0

var _prompt_shown: bool = false
var _can_resurrect: bool = false
var _dying: bool = false
var _dying_time: float = 0.0


func enter(_previous: StringName) -> void:
	elapsed = 0.0
	_prompt_shown = false
	_dying = false
	_dying_time = 0.0
	_can_resurrect = player.resurrections_left > 0
	player.invulnerable = false
	player.walk_only = false
	player.combatant.guarding = false
	player.combatant.vulnerable = false
	for action_name: StringName in [&"jump", &"dodge", &"attack", &"guard", &"interact"]:
		player.input_buffer.clear(action_name)
	if player.sword_visual != null:
		player.sword_visual.end_combo()
	# The lock-on ends; remember the enemy for a resurrection.
	player.relock_target = player.lock_on.target if player.lock_on.has_target() else null
	player.lock_on.release()
	player.lock_on.locked_out = true
	player.set_stagger_lean(lie_lean)
	player.set_stagger_kneel(true, false)
	player.death_started.emit()


func exit(_next: StringName) -> void:
	player.lock_on.locked_out = false
	player.set_stagger_lean(0.0)
	player.set_stagger_kneel(false)


func physics_update(delta: float) -> void:
	elapsed += delta
	if not player.is_on_floor():
		player.apply_gravity(delta)
	player.decelerate(delta)
	for action_name: StringName in [&"jump", &"dodge", &"attack", &"guard"]:
		player.input_buffer.clear(action_name)
	if _dying:
		_dying_time += delta
		if _dying_time >= die_fade_time:
			Engine.time_scale = 1.0
			player.get_tree().reload_current_scene()
		return
	if not _prompt_shown:
		if elapsed >= prompt_delay:
			_prompt_shown = true
			player.death_prompt_shown.emit(_can_resurrect)
		return
	if _can_resurrect:
		# Fresh presses only: a button held since before the prompt does not count.
		if Input.is_action_just_pressed(&"attack"):
			_resurrect()
		elif Input.is_action_just_pressed(&"guard"):
			_die()
	elif elapsed >= final_death_time:
		_die()


func _resurrect() -> void:
	player.resurrect()
	var target := player.relock_target
	player.relock_target = null
	var on_floor := player.is_on_floor()
	# Leave the state first (exit() ends the lock-out), then lock the same enemy again if it is alive.
	machine.transition_to(&"Locomotion" if on_floor else &"Air")
	if target != null and is_instance_valid(target):
		player.lock_on.lock_onto(target)
	player.resurrected.emit()


func _die() -> void:
	_dying = true
	_dying_time = 0.0
	player.death_confirmed.emit(die_fade_time)
