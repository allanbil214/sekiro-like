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


## Start a new action: the clock to 0. An open swing is not closed here (the owner calls end_hit()).
func reset() -> void:
	time = 0.0
	hit_open = false


## True while the action is an ATTACK with damage and its hit window is open at the current time.
func hit_is_active(action: ActionData) -> bool:
	return action != null and action.kind == ActionData.Kind.ATTACK and action.damage > 0.0 \
			and action.is_hit_active(time)


## Opens the hitbox swing if it is not open yet. Returns true on the call that opened it (the owner
## then plays its swing sound and runs its own hook).
func open_hit(hitbox: Hitbox, action: ActionData, show_extension: bool = false) -> bool:
	if hit_open:
		return false
	hitbox.begin_swing(action.hitbox_length_scale, show_extension)
	hit_open = true
	return true


## Closes the swing if one is open. The hitbox may be null (the owner has no sword).
func end_hit(hitbox: Hitbox) -> void:
	if not hit_open:
		return
	hit_open = false
	if hitbox != null:
		hitbox.end_swing()


## A HitData with the fields every attack copies from its ActionData. The owner may change it
## afterwards (the enemy's perilous attacks override some fields).
func make_hit(action: ActionData, attacker: Node, damage_multiplier: float, posture_multiplier: float) -> HitData:
	var hit := HitData.new()
	hit.attacker = attacker
	hit.damage = action.damage * damage_multiplier
	hit.posture_damage = action.posture_damage * posture_multiplier
	hit.hitstop = action.hitstop
	hit.guardable = action.guardable
	hit.deflectable = action.deflectable
	hit.knockback = action.knockback
	hit.action = action
	# The player's reversed blade (item 10): half the health damage, full posture, and it cannot kill.
	var player := attacker as Player
	if player != null and player.blade_reversed:
		hit.lethal = false
		hit.damage *= player.reverse_damage_multiplier
		hit.posture_damage *= player.reverse_posture_multiplier
	return hit


## True while the clock is inside the action's movement window.
func in_move_window(action: ActionData) -> bool:
	return ActionData.in_window(action.move_window, time)


## The speed factor of the movement at the current time: 1 without a fade, else it eases from 1 to
## move_end_factor across the movement window.
func move_fade_factor(action: ActionData) -> float:
	if not action.move_fade:
		return 1.0
	var window := action.move_window
	var progress := clampf((time - window.x) / maxf(window.y - window.x, 0.001), 0.0, 1.0)
	return lerpf(1.0, action.move_end_factor, progress)
