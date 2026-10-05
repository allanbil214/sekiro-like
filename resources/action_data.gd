class_name ActionData
extends Resource
## Data for one action (dodge, attack, heal...). Edit the .tres in the Inspector.
## All times are in seconds from the start of the action. Windows are (start, end).

enum Kind { ATTACK, DODGE, GUARD, HEAL, JUMP, WALL_JUMP, LEDGE_CLIMB, PERILOUS_THRUST, PERILOUS_SWEEP, GRAB, OTHER }

@export var kind: Kind = Kind.ATTACK
@export var animation: StringName
@export var duration: float = 0.8
## Speed of the action clock. Animations will follow this later.
@export var speed_scale: float = 1.0

@export_group("Windows")
## No other action is allowed before this time.
@export var locked_until: float = 0.5
## When the action may be interrupted. (0, 0) means from locked_until to the end.
@export var cancel_window: Vector2 = Vector2.ZERO
## Span in which an attack press is accepted for chaining (Step 3). (0, 0) = the whole action.
@export var buffer_window: Vector2 = Vector2.ZERO
## Hitbox active window (used from Step 4).
@export var active_hit: Vector2 = Vector2.ZERO
## Invulnerable window.
@export var iframes: Vector2 = Vector2.ZERO

@export_group("Movement")
@export var move_speed: float = 0.0
@export var move_window: Vector2 = Vector2.ZERO
## Speed fades linearly across move_window (down to move_end_factor).
@export var move_fade: bool = true
## Speed at the end of move_window as a fraction of move_speed (needs Move Fade). 0 = fades to a stop.
@export var move_end_factor: float = 0.0

@export_group("Swing visual")
## Placeholder sword poses, each (clock hour, radius in m, forward in m). Hour 12 = up, 3 = right,
## 6 = down, 9 = left, seen from behind the player. Forward is in front of the player (negative = behind).
## They only drive the placeholder sword; real animation will replace them.
## Wind-up pose = where the slash starts.
@export var swing_windup: Vector3 = Vector3.ZERO
## Where the slash ends.
@export var swing_end: Vector3 = Vector3.ZERO
## Relaxed follow-through pose, played only if the combo is not continued.
@export var swing_follow: Vector3 = Vector3.ZERO

@export_group("Combat")
@export var damage: float = 0.0
@export var posture_damage: float = 0.0
@export var guardable: bool = true
@export var deflectable: bool = true
@export var pauses_posture_regen: bool = true
## Next action in a combo. Loop back to the first one for the combo loop.
@export var combo_next: ActionData


static func in_window(window: Vector2, time: float) -> bool:
	return time >= window.x and time < window.y


func is_locked(time: float) -> bool:
	return time < locked_until


func can_cancel(time: float) -> bool:
	if time < locked_until:
		return false
	if cancel_window == Vector2.ZERO:
		return true
	return in_window(cancel_window, time)


func has_iframes(time: float) -> bool:
	return in_window(iframes, time)


func is_hit_active(time: float) -> bool:
	return in_window(active_hit, time)
