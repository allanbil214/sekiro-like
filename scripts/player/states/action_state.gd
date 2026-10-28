class_name ActionState
extends State
## Runs any ActionData on an "action clock". Windows in the data are read against
## action_time, so a later AnimationPlayer can simply follow it. Dodge, attacks, and
## other actions extend this.
## Hits (Step 4): while an ATTACK action with damage above 0 is inside its active_hit window, the
## sword's Hitbox is swept every physics frame (damage x _hit_damage_multiplier()); each target is
## hit once per swing, and a connect restarts the auto-sheathe timer and asks for the hitstop.

@export var action: ActionData

## The shared core: the clock, the hit window, the swing, and the movement fade (Step 12D). The
## action is passed to it on every call because subclasses swap `action` while the state runs.
var runner: ActionRunner = ActionRunner.new()
## Seconds from the start of the action (the clock lives in the runner).
var action_time: float:
	get:
		return runner.time
	set(value):
		runner.time = value
var speed_scale: float = 1.0

var _move_dir: Vector3 = Vector3.ZERO
var _move_speed_multiplier: float = 1.0


func enter(previous: StringName) -> void:
	runner.reset()
	speed_scale = action.speed_scale
	_move_dir = Vector3.ZERO
	_move_speed_multiplier = 1.0
	player.on_action_started(action.kind)
	_on_action_enter(previous)


func exit(_next: StringName) -> void:
	player.invulnerable = false
	_end_hit()
	player.figure.stop_clip()
	_on_action_exit()


func physics_update(delta: float) -> void:
	_discard_early_presses()
	if _try_guard_cancel():
		return
	action_time += delta * speed_scale * _active_speed_factor()
	player.invulnerable = action.has_iframes(action_time)
	if not player.is_on_floor():
		player.apply_gravity(delta)
	_on_action_update(delta)
	if machine.current != self:
		return
	# 3a-3c: the figure plays this action's clip (if it has one) against the action clock.
	_drive_clip()
	_update_hit()
	_apply_action_movement(delta)
	if action_time >= action.duration:
		_on_action_finished()


## 3a-3c-3: shows this frame's clip on the figure. A subclass with a phase that has no action clock (the thrust's
## charge) drives the figure itself.
func _drive_clip() -> void:
	player.figure.drive_clip(action, action_time, _clip_rate(), _clip_name(), _clip_from())


## 3a-3c-3: seconds into the clip where this action's clip starts (the thrust plays only the second half of its clip).
func _clip_from() -> float:
	return 0.0


## 3a-3c-2: the clip the figure plays for this action. The action's `placeholder_clip` by default; a subclass picks another
## (the dodge picks the roll by direction). A name ending in ":upper" plays only the clip's upper body (the legs keep
## the held pose). An empty name plays nothing, and so does a cleared `placeholder_clip` on the action.
func _clip_name() -> StringName:
	return action.placeholder_clip


## 3a-3c: how fast the action clock runs now, for the figure's clip between two physics frames. A subclass whose
## clock is frozen returns 0.
func _clip_rate() -> float:
	return speed_scale * _active_speed_factor()


## 3b-1: until the action's `input_from` time, attack presses are thrown away instead of waiting in the buffer
## (stops mashing from chaining too early). Defensive presses (dodge, jump, guard) are never discarded. Does
## nothing when the field is not set.
func _discard_early_presses() -> void:
	if action == null:
		return
	var from := action.feel_input_from()
	if from < 0.0 or action_time >= from:
		return
	player.input_buffer.clear(Actions.ATTACK)


## Guard cancels any action except during its hit window (a press made then stays buffered and
## fires once the window closes, if it is still fresh). A crouched action under a low ceiling
## ignores it (guard stands you up).
func _try_guard_cancel() -> bool:
	if not _allows_guard_cancel() or not player.input_buffer.has_pressed(Actions.GUARD):
		return false
	if not action.feel_allows(ActionData.FeelInput.GUARD, action_time):
		return false
	if _hit_is_active():
		return false
	if player.is_crouched and not player.can_stand():
		player.input_buffer.clear(Actions.GUARD)
		return false
	machine.transition_to(StateName.GUARD)
	return true


## Slows the clock inside a normal slash's hit window (Player.slash_active_speed), so the swing
## itself does not look instant. The wind-up and everything after the window run at full speed.
func _active_speed_factor() -> float:
	if not _slows_active_window() or not _hit_is_active():
		return 1.0
	return player.slash_active_speed


## 3b-2: turns the body toward the movement input (or the lock-on target) for this frame. An action with turn
## fields (`ActionData.has_turn_fields()`) turns at the rate its data gives for the current time; any other action
## keeps the old rule (free steering until the hit window opens). Returns true when the body was allowed to turn, so
## the caller can steer the lunge direction with it.
func _turn_toward_input(delta: float) -> bool:
	if action.has_turn_fields():
		var rate := action.turn_rate_at(action_time)
		if rate <= 0.0:
			return false
		player.face_input_rate(rate, delta)
		return true
	if action_time < action.active_hit.x:
		player.face_input(delta)
		return true
	return false


## Subclasses return false for actions that keep their own speed (thrusts, helm splitters, the
## deathblow).
func _slows_active_window() -> bool:
	return true


## Subclasses return true to draw the glowing blade extension while the hit window is open (the helm
## splitter, Step 11e). Visual only.
func _shows_extension() -> bool:
	return false


## Called once when the hit window opens (after the Hitbox started its swing). Subclasses add visuals.
func _on_hit_window_opened(_hitbox: Hitbox) -> void:
	pass


## Subclasses return false for actions guard must not interrupt (the ledge climb).
func _allows_guard_cancel() -> bool:
	return true


func _apply_action_movement(delta: float) -> void:
	if _move_dir != Vector3.ZERO:
		if action.has_motion_curve():
			# 3b-3: the curves give the speed (forward along the move direction, side to its right).
			if runner.in_motion(action):
				var speed := runner.motion_velocity(action)
				var right := _move_dir.cross(Vector3.UP)
				player.set_horizontal_velocity((_move_dir * speed.x + right * speed.y) * _move_speed_multiplier)
				return
		elif runner.in_move_window(action):
			var factor := runner.move_fade_factor(action)
			player.set_horizontal_velocity(_move_dir * action.move_speed * _move_speed_multiplier * factor)
			return
	player.decelerate(delta)


## Open, sweep, and close the sword's hitbox for the current action.
func _update_hit() -> void:
	var hitbox := _get_hitbox()
	if hitbox == null:
		return
	if not _hit_is_active():
		_end_hit()
		return
	var index := -1
	var spec: HitSpec = null
	if action.has_hits():
		# 3b-4: the hitbox is open only inside a hit's window; it closes between hits and each hit forgets who was hit.
		index = action.hit_index_at(action_time)
		if runner.hit_open and runner.hit_index != index:
			runner.end_hit(hitbox)
		if index < 0:
			return
		spec = action.hits[index]
	if runner.open_hit(hitbox, action, _shows_extension(), index):
		# One swing sound and one visual hook per action: the first hit only.
		if index <= 0:
			Sfx.play(player.get_tree(), Sfx.swing_id(action))
			_on_hit_window_opened(hitbox)
	var template := runner.make_hit(action, player, _hit_damage_multiplier(), _hit_posture_multiplier(), spec)
	var landed := hitbox.sweep(template)
	if not landed.is_empty():
		player.on_hit_landed(landed[0])


func _end_hit() -> void:
	runner.end_hit(_get_hitbox())


func _get_hitbox() -> Hitbox:
	if player.sword_visual == null:
		return null
	return player.sword_visual.hitbox


func _hit_is_active() -> bool:
	return runner.hit_is_active(action)


## The horizontal direction this action is moving the player in (the dodge's direction), or
## Vector3.ZERO. Read-only: the enemy's mikiri check uses it.
func get_move_direction() -> Vector3:
	return _move_dir


## Hooks for subclasses.
func _on_action_enter(_previous: StringName) -> void:
	pass


func _on_action_exit() -> void:
	pass


func _on_action_update(_delta: float) -> void:
	pass


func _on_action_finished() -> void:
	machine.transition_to(StateName.LOCOMOTION)


## Multiplies the action's damage (a charged attack overrides this).
func _hit_damage_multiplier() -> float:
	return 1.0


## Multiplies the action's posture damage (a charged attack overrides this).
func _hit_posture_multiplier() -> float:
	return 1.0
