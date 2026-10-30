class_name ActionRunner
extends RefCounted
## The part of running an action that the player and the enemy share (Step 12D): the action clock,
## "is the hit window open", the hitbox swing open and close, the HitData fields copied from the
## ActionData, and the movement fade. It knows nothing about Player or Enemy. The action itself is
## passed in on every call (the owner may swap it mid-state), so the runner holds only the clock and
## whether a swing is open. What differs per owner (sounds, speed rules, perilous overrides, chain
## timing) stays with the owner.

## Seconds from the start of the current action (the owner advances it).
var time: float = 0.0
## True while a swing is open (open_hit() was called and end_hit() has not been).
var hit_open: bool = false
## 3b-4: the index of the open hit in the action's `hits` list, or -1 (a single-hit action, or no swing open).
var hit_index: int = -1


## Start a new action: the clock to 0. An open swing is not closed here (the owner calls end_hit()).
func reset() -> void:
	time = 0.0
	hit_open = false
	hit_index = -1


## True while the action is an ATTACK with damage and its hit window is open at the current time.
func hit_is_active(action: ActionData) -> bool:
	return action != null and action.kind == ActionData.Kind.ATTACK and action.damage > 0.0 \
			and action.is_hit_active(time)


## Opens the hitbox swing if it is not open yet. Returns true on the call that opened it (the owner
## then plays its swing sound and runs its own hook).
## `index` is the hit of a multi-hit list that is opening (3b-4), -1 for a single-hit action.
func open_hit(hitbox: Hitbox, action: ActionData, show_extension: bool = false, index: int = -1) -> bool:
	if hit_open:
		return false
	hitbox.begin_swing(action.hitbox_length_scale, show_extension)
	hit_open = true
	hit_index = index
	return true


## Closes the swing if one is open. The hitbox may be null (the owner has no sword).
func end_hit(hitbox: Hitbox) -> void:
	if not hit_open:
		return
	hit_open = false
	hit_index = -1
	if hitbox != null:
		hitbox.end_swing()


## A HitData with the fields every attack copies from its ActionData. The owner may change it
## afterwards (the enemy's perilous attacks override some fields). `spec` (3b-4) is the hit of a multi-hit list; its
## set fields (0 or more) replace the action's own.
func make_hit(action: ActionData, attacker: Node, damage_multiplier: float, posture_multiplier: float,
		spec: HitSpec = null) -> HitData:
	var hit := HitData.new()
	hit.attacker = attacker
	var base_damage := action.damage
	var base_posture := action.posture_damage
	var base_hitstop := action.hitstop
	var base_knockback := action.knockback
	if spec != null:
		base_damage = spec.damage if spec.damage >= 0.0 else base_damage
		base_posture = spec.posture_damage if spec.posture_damage >= 0.0 else base_posture
		base_hitstop = spec.hitstop if spec.hitstop >= 0.0 else base_hitstop
		base_knockback = spec.knockback if spec.knockback >= 0.0 else base_knockback
	hit.damage = base_damage * damage_multiplier
	hit.posture_damage = base_posture * posture_multiplier
	hit.hitstop = base_hitstop
	hit.guardable = action.guardable
	hit.deflectable = action.deflectable
	hit.knockback = base_knockback
	hit.hurt_level = spec.hurt_level if spec != null and spec.hurt_level >= 0 else action.hurt_level
	hit.action = action
	# The player's reversed blade (item 10): half the health damage, full posture, and it cannot kill.
	var player := attacker as Player
	if player != null and player.blade_reversed:
		hit.lethal = false
		hit.damage *= player.reverse_damage_multiplier
		hit.posture_damage *= player.reverse_posture_multiplier
	return hit


## 3d-1: plays the action's `sound_events` whose time lies in [from, to) (the clock's step of this frame; a parked clock
## has none). `at` null = flat sounds (the player's own), else positional sounds at that node (an enemy).
func fire_sound_events(tree: SceneTree, action: ActionData, from: float, to: float, at: Node3D = null) -> void:
	if action == null or action.sound_events.is_empty() or to <= from:
		return
	for event: SoundEvent in action.sound_events:
		if event == null or event.time < from or event.time >= to:
			continue
		if at == null:
			Sfx.play(tree, event.sound, event.volume_db, event.pitch)
		else:
			Sfx.play_at(tree, event.sound, at.global_position + Vector3.UP, event.volume_db, event.pitch)


## True while the clock is inside the action's movement window.
func in_move_window(action: ActionData) -> bool:
	return ActionData.in_window(action.move_window, time)


## 3b-3: true while the clock is inside a set motion curve (before the end of its domain).
func in_motion(action: ActionData) -> bool:
	for curve: Curve in [action.motion_forward, action.motion_side]:
		if curve != null and time < curve.max_domain:
			return true
	return false


## 3b-3: the speeds of the motion curves at the current time as (forward, side) in m/s; a curve that has ended gives 0.
func motion_velocity(action: ActionData) -> Vector2:
	var speed := Vector2.ZERO
	if action.motion_forward != null and time < action.motion_forward.max_domain:
		speed.x = action.motion_forward.sample(time)
	if action.motion_side != null and time < action.motion_side.max_domain:
		speed.y = action.motion_side.sample(time)
	return speed


## The speed factor of the movement at the current time: 1 without a fade, else it eases from 1 to
## move_end_factor across the movement window.
func move_fade_factor(action: ActionData) -> float:
	if not action.move_fade:
		return 1.0
	var window := action.move_window
	var progress := clampf((time - window.x) / maxf(window.y - window.x, 0.001), 0.0, 1.0)
	return lerpf(1.0, action.move_end_factor, progress)
