class_name SlideState
extends ActionState
## Slide: a low burst of movement with i-frames, started by pressing crouch while
## dashing. Ends in Crouch. Jump and dodge cancel it after the locked window, but
## only when there is headroom to stand up. Attack (after the locked window) starts the
## weapon's crouch attack loop.

var _dust_timer: float = 0.0


func exit(next: StringName) -> void:
	super.exit(next)
	player.stop_slide_arms()
	if next != &"Crouch" and next != &"Attack":
		player.set_crouched(false)


func _on_action_enter(_previous: StringName) -> void:
	_dust_timer = 0.0
	player.set_crouched(true)
	player.play_slide_arms()
	var dir := player.get_move_input()
	if dir.length_squared() <= 0.01:
		dir = player.get_facing_direction()
	dir.y = 0.0
	_move_dir = dir.normalized()
	player.snap_facing_lock_aware(_move_dir)


func _on_action_update(delta: float) -> void:
	if not player.is_on_floor():
		player.coyote_timer = player.coyote_time
		machine.transition_to(&"Air")
		return
	_dust_timer -= delta
	if _dust_timer <= 0.0:
		_dust_timer = 0.07
		Fx.play(player.get_tree(), Fx.Kind.SLIDE_DUST, player.global_position, -_move_dir)
	if not action.can_cancel(action_time):
		return
	if player.weapon != null and player.input_buffer.has_pressed(&"attack"):
		var attack := machine.get_node_or_null("Attack") as AttackState
		if attack != null and attack.try_start_variant(player.weapon.crouch_attack):
			player.input_buffer.consume(&"attack")
			return
	var headroom := player.can_stand()
	if player.input_buffer.has_pressed(&"jump"):
		if headroom:
			player.input_buffer.consume(&"jump")
			player.start_jump()
			machine.transition_to(&"Air")
			return
		player.input_buffer.clear(&"jump")
	if player.input_buffer.has_pressed(&"dodge"):
		if headroom:
			player.input_buffer.consume(&"dodge")
			machine.transition_to(&"Dodge")
			return
		player.input_buffer.clear(&"dodge")


func _on_action_finished() -> void:
	machine.transition_to(&"Crouch")
