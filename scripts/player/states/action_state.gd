class_name ActionState
extends State
## Runs any ActionData on an "action clock". Windows in the data are read against
## action_time, so a later AnimationPlayer can simply follow it. Dodge, attacks, and
## other actions extend this.
## Hits (Step 4): while an ATTACK action with damage above 0 is inside its active_hit window, the
## sword's Hitbox is swept every physics frame (damage x _hit_damage_multiplier()); each target is
## hit once per swing, and a connect restarts the auto-sheathe timer and asks for the hitstop.

@export var action: ActionData

var action_time: float = 0.0
var speed_scale: float = 1.0

var _move_dir: Vector3 = Vector3.ZERO
var _move_speed_multiplier: float = 1.0
var _hit_was_active: bool = false


func enter(previous: StringName) -> void:
	action_time = 0.0
	speed_scale = action.speed_scale
	_move_dir = Vector3.ZERO
	_move_speed_multiplier = 1.0
	_hit_was_active = false
	player.on_action_started(action.kind)
	_on_action_enter(previous)


func exit(_next: StringName) -> void:
	player.invulnerable = false
	_end_hit()
	_on_action_exit()


func physics_update(delta: float) -> void:
	if _try_guard_cancel():
		return
	action_time += delta * speed_scale
	player.invulnerable = action.has_iframes(action_time)
	if not player.is_on_floor():
		player.apply_gravity(delta)
	_on_action_update(delta)
	if machine.current != self:
		return
	_update_hit()
	_apply_action_movement(delta)
	if action_time >= action.duration:
		_on_action_finished()


## Guard cancels any action except during its hit window (a press made then stays buffered and
## fires once the window closes, if it is still fresh). A crouched action under a low ceiling
## ignores it (guard stands you up).
func _try_guard_cancel() -> bool:
	if not _allows_guard_cancel() or not player.input_buffer.has_pressed(&"guard"):
		return false
	if _hit_is_active():
		return false
	if player.is_crouched and not player.can_stand():
		player.input_buffer.clear(&"guard")
		return false
	machine.transition_to(&"Guard")
	return true


## Subclasses return false for actions guard must not interrupt (the ledge climb).
func _allows_guard_cancel() -> bool:
	return true


func _apply_action_movement(delta: float) -> void:
	var window := action.move_window
	if _move_dir != Vector3.ZERO and ActionData.in_window(window, action_time):
		var factor := 1.0
		if action.move_fade:
			var progress := clampf((action_time - window.x) / maxf(window.y - window.x, 0.001), 0.0, 1.0)
			factor = lerpf(1.0, action.move_end_factor, progress)
		player.set_horizontal_velocity(_move_dir * action.move_speed * _move_speed_multiplier * factor)
	else:
		player.decelerate(delta)


## Open, sweep, and close the sword's hitbox for the current action.
func _update_hit() -> void:
	var hitbox := _get_hitbox()
	if hitbox == null:
		return
	if not _hit_is_active():
		_end_hit()
		return
	if not _hit_was_active:
		hitbox.begin_swing(action.hitbox_length_scale)
		_hit_was_active = true
	var template := HitData.new()
	template.attacker = player
	template.damage = action.damage * _hit_damage_multiplier()
	template.posture_damage = action.posture_damage
	template.hitstop = action.hitstop
	template.guardable = action.guardable
	template.deflectable = action.deflectable
	template.knockback = action.knockback
	template.action = action
	var landed := hitbox.sweep(template)
	if not landed.is_empty():
		player.on_hit_landed(landed[0])


func _end_hit() -> void:
	if not _hit_was_active:
		return
	_hit_was_active = false
	var hitbox := _get_hitbox()
	if hitbox != null:
		hitbox.end_swing()


func _get_hitbox() -> Hitbox:
	if player.sword_visual == null:
		return null
	return player.sword_visual.hitbox


func _hit_is_active() -> bool:
	return action.kind == ActionData.Kind.ATTACK and action.damage > 0.0 \
			and action.is_hit_active(action_time)


## Hooks for subclasses.
func _on_action_enter(_previous: StringName) -> void:
	pass


func _on_action_exit() -> void:
	pass


func _on_action_update(_delta: float) -> void:
	pass


func _on_action_finished() -> void:
	machine.transition_to(&"Locomotion")


## Multiplies the action's damage (a charged attack overrides this).
func _hit_damage_multiplier() -> float:
	return 1.0
