class_name TauntState
extends ActionState
## The taunt (Phase 2 item 11.5), started by `Player._try_taunt()` from Locomotion or Crouch (a crouch is stood up
## first). Driven by `data/actions/player/taunt.tres` like any action: a locked wind-up, the shout at `provoke_time`, a locked
## flourish, then a wind-down where dodge, jump and attack cancel (`cancel_window`). Guard, or a hit, cancels it
## before the shout and then nothing is provoked.
## At `provoke_time` the player shouts (`Sfx.Id.TAUNT`) and every enemy hears it (`Enemy.hear_taunt()`): an enemy in
## combat within `Player.taunt_range` is provoked, one that is not in combat hears a noise of
## `Player.taunt_noise_radius`. The numbers of the provoked state are in `EnemyAIData` (the Provoked group).
## The player stands still. Placeholder visual: the body leans back in the wind-up and forward at the shout (the
## stagger lean helper); the sword is not animated.

## Seconds from the start when the shout lands (keep it inside the locked window).
@export var provoke_time: float = 0.35
## Body lean in radians (positive = forward): back during the wind-up, forward from the shout on.
@export var windup_lean: float = -0.25
@export var shout_lean: float = 0.2
## Seconds before the end of the action when the body straightens up again (the wind-down).
@export var straighten_time: float = 0.3

var _provoked: bool = false
var _straightened: bool = false


func _on_action_enter(_previous: StringName) -> void:
	_provoked = false
	_straightened = false
	if player.is_crouched:
		player.set_crouched(false)
	for buffered: StringName in [Actions.DODGE, Actions.JUMP, Actions.ATTACK, Actions.GUARD]:
		player.input_buffer.consume(buffered)
	player.set_stagger_lean(windup_lean)


func _on_action_exit() -> void:
	player.set_stagger_lean(0.0)


func _on_action_update(_delta: float) -> void:
	if not _provoked and action_time >= provoke_time:
		_provoke()
	if not _straightened and action_time >= action.duration - straighten_time:
		_straightened = true
		player.set_stagger_lean(0.0)
	if not action.can_cancel(action_time):
		return
	if player.is_on_floor():
		if player.input_buffer.consume(Actions.JUMP):
			player.start_jump()
			machine.transition_to(StateName.AIR)
			return
		if player.input_buffer.consume(Actions.DODGE):
			machine.transition_to(StateName.DODGE)
			return
		if player.has_combo() and player.input_buffer.consume(Actions.ATTACK):
			machine.transition_to(StateName.ATTACK)
			return


## The shout: the player's voice line, then every enemy hears it.
func _provoke() -> void:
	_provoked = true
	player.set_stagger_lean(shout_lean)
	Sfx.play(player.get_tree(), Sfx.Id.TAUNT)
	for node: Node3D in Enemies.all():
		var enemy := node as Enemy
		if enemy != null:
			enemy.hear_taunt(player.global_position, player.taunt_range, player.taunt_noise_radius)
