class_name StaggerState
extends State
## Posture break on the player (Step 6): a long stagger. No walking, guarding, or attacking; you
## take Combatant.staggered_damage_multiplier x damage (the Combatant's `vulnerable` flag).
## Dodge is locked for the first dodge_locked_time seconds, then a dodge cancels the stagger. If
## you do nothing it lasts the full duration. Posture is back to 0 when it ends (any way).
## Placeholder visual: the body leans forward (Player.set_stagger_lean).

@export var duration: float = 6.0
@export var dodge_locked_time: float = 2.0

var elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	elapsed = 0.0
	player.invulnerable = false
	player.walk_only = false
	player.combatant.vulnerable = true
	for action_name: StringName in [&"jump", &"dodge", &"attack", &"guard"]:
		player.input_buffer.clear(action_name)
	if player.sword_visual != null:
		player.sword_visual.end_combo()
	player.set_stagger_lean(player.stagger_lean)


func exit(_next: StringName) -> void:
	player.combatant.vulnerable = false
	player.combatant.reset_posture()
	player.set_stagger_lean(0.0)


func physics_update(delta: float) -> void:
	elapsed += delta
	var on_floor := player.is_on_floor()
	if not on_floor:
		player.apply_gravity(delta)
	player.decelerate(delta)
	player.input_buffer.clear(&"jump")
	player.input_buffer.clear(&"attack")
	player.input_buffer.clear(&"guard")
	if elapsed >= dodge_locked_time and on_floor and player.input_buffer.consume(&"dodge"):
		machine.transition_to(&"Dodge")
		return
	if elapsed >= duration:
		machine.transition_to(&"Locomotion")
