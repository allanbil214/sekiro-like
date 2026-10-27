@tool
class_name ActionData
extends Resource
## Data for one action (dodge, attack, heal...). Edit the .tres in the Inspector.
## All times are in seconds from the start of the action. Windows are (start, end).

enum Kind { ATTACK, DODGE, GUARD, HEAL, JUMP, WALL_JUMP, LEDGE_CLIMB, PERILOUS_THRUST, PERILOUS_SWEEP, GRAB, OTHER }

## Where this action's numbers or animation came from (`docs/phase-3-plan.md`, section 8). Shown in the Inspector and in the
## feel overlay. Everything but NONE must be replaced by the user's own work before the project goes public.
enum PlaceholderSource { NONE, ER_NUMBERS, ER_CLIP, MADE_UP_POSE }

## The inputs that have their own "free from" time (Phase 3b-1, `cancel_*` fields below).
enum FeelInput { ATTACK, DODGE, JUMP, GUARD, MOVE, ITEM }

## Turn speed (deg/s) of an action that sets turn fields but no `turn_rate`.
## PLACEHOLDER(ER numbers): the sandbox's rate for "inside an action with no setting" (`docs/phase-3-feel-reference.md`, section 3).
const DEFAULT_TURN_RATE: float = 360.0

## Debug switch (Debug menu, FEEL group): false = actions tagged ER_NUMBERS ignore their 3b-1 test values and play
## with the original timing. Release builds ignore this and always use the values. Other actions are never affected.
static var er_feel_enabled: bool = true

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

@export_group("Feel (3b-1)")
## Per-input cancel times (seconds from the start of the action). -1 = off: the old rule applies to that input.
## A set value replaces the old rule for that one input only; the active hit window still blocks everything.
## Leave dodge, jump and guard at -1 for the Sekiro rule: they cancel in the wind-up and as soon as the hit ends.
## Attack presses made before this time are discarded, not buffered (defensive presses are never discarded). -1 = off.
@export var input_from: float = -1.0
## Earliest time the next attack of the combo may start (replaces the chain time, `cancel_window.x`).
@export var cancel_attack: float = -1.0
## Earliest time a dodge may cancel this action (-1 = the old rule: any time outside the hit window).
@export var cancel_dodge: float = -1.0
## Earliest time a jump may cancel this action (-1 = the old rule).
@export var cancel_jump: float = -1.0
## Earliest time guard may cancel this action (-1 = the old rule).
@export var cancel_guard: float = -1.0
## Earliest time held movement input ends this action (-1 = never: the action runs to its duration).
@export var cancel_move: float = -1.0
## Earliest time the gourd (`heal`) or an item (`use_item`: a throw or an aim, later pellets) may start out of this
## attack (ground attacks only). -1 = never: they wait until the attack ends. A press before the time is ignored.
@export var cancel_item: float = -1.0

@export_group("Feel (3b-2)")
## Turn control for player attacks (ground and air; `docs/phase-3-plan.md`, section 9). Setting any of the three fields
## below replaces the old rule (steer freely until the hit window opens) for this action. The rate in force at any
## time is: a `no_turn` span (0) beats a `turn_overrides` span, which beats `turn_rate`; with `turn_rate` at -1 the rest
## of the action turns at DEFAULT_TURN_RATE. All times are seconds from the start of the action.
## Default turn speed in degrees per second (-1 = off; 0 = no turning outside the overrides).
@export var turn_rate: float = -1.0
## Spans (from, to) in which the body cannot turn at all.
@export var no_turn: Array[Vector2] = []
## Spans (from, to, degrees per second) that turn faster or slower than the default; the first match wins.
@export var turn_overrides: Array[Vector3] = []

@export_group("Feel (3b-3)")
## Motion curves (`docs/phase-3-plan.md`, section 9). x = seconds from the start of the action, y = speed in m/s.
## A set curve replaces `move_speed`, the fade and `move_window` for this action's movement; after the end of the
## curve's domain the body decelerates as before. The curve's Max Domain must cover the action and its Min and Max Value
## must hold the speeds (a Curve clamps y to 0 to 1 by default); the validator checks both.
## Forward speed along the action's move direction (negative = backward).
@export var motion_forward: Curve
## Sideways speed, positive to the right of the move direction. Player only for now.
@export var motion_side: Curve

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
## Thrust style: the blade always points at the end pose while the hand moves from the wind-up
## pose to the end pose (a straight stab), instead of bending at the wrist like a slash.
@export var blade_aims_at_end: bool = false
## Scales the body twist for this action (a thrust keeps the body mostly square).
@export var twist_scale: float = 1.0

@export_group("Charge")
## Seconds to reach full charge when the attack button is held. 0 = cannot be charged.
@export var charge_time: float = 0.0
## Damage multiplier at full charge (1.0 at no charge).
@export var charge_damage_max: float = 1.5
## Posture damage multiplier at full charge (1.0 at no charge). Separate from the damage one so a
## charged move can be posture-heavy, health-heavy, or both.
@export var charge_posture_max: float = 1.5
## Lunge speed multiplier at full charge (1.0 at no charge).
@export var charge_lunge_max: float = 1.4
## What replaces this attack when the attack button is still held at the end of its wind-up.
## If that action has a charge_time above 0 it is charged first; at 0 it starts at once.
## Empty on a ground combo attack = the weapon's charged thrust; empty on a variant = no hold.
@export var hold_action: ActionData

@export_group("Combat")
@export var damage: float = 0.0
@export var posture_damage: float = 0.0
## How far the hitbox reaches along the blade, as a multiple of the blade length. It grows from the
## tip (the root stays at the hand), so 1.5 fakes the reach of a shockwave or aura. 1.0 = the blade.
@export var hitbox_length_scale: float = 1.0
## Seconds of hitstop (a brief near-freeze of the whole game) when this action's hit connects.
@export var hitstop: float = 0.06
## How far (m) a hit from this action pushes the target back (a heavy attack: 1 or more). 0 = none.
## The target scales it by outcome (Combatant knockback multipliers: hit, guard, deflect).
@export var knockback: float = 0.0
@export var guardable: bool = true
@export var deflectable: bool = true
@export var pauses_posture_regen: bool = true
## Next attack in a variant loop (the crouch loop; later the air loop). Empty = back to the
## first attack of the loop. Not used by the ground combo (WeaponData.combo holds that).
@export var combo_next: ActionData

@export_group("Multi-hit (3b-4)")
## A list of hits for one action: each opens the hitbox in its own window and can hit the same target again.
## Empty = the old single hit (`active_hit`, `damage`, ...). When set, `active_hit` stays the overall span (the sword
## visual, the cancel rules and the overlay read it) and every hit's window must lie inside it. Player attacks only.
@export var hits: Array[HitSpec] = []

@export_group("Placeholder")
## Phase 3: the source of this action's temporary numbers or animation. NONE = the user's own work.
@export var placeholder_source: PlaceholderSource = PlaceholderSource.NONE


## A read-only "Validation" line at the bottom of the Inspector (ActionValidator). Not stored in the .tres.
func _get_property_list() -> Array[Dictionary]:
	return [{
		"name": "validation",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_MULTILINE_TEXT,
		"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY,
	}]


func _get(property: StringName) -> Variant:
	if property == &"validation":
		return ActionValidator.report(self)
	return null


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


## True when this action's 3b-1 fields count right now (false only for an ER_NUMBERS action while the debug
## switch is off, in a debug build).
func feel_applies() -> bool:
	if placeholder_source != PlaceholderSource.ER_NUMBERS:
		return true
	return er_feel_enabled or not OS.is_debug_build()


## The set cancel time for `input`, or -1 when none is set (or the fields do not count right now).
func feel_cancel_time(input: FeelInput) -> float:
	var value := -1.0
	match input:
		FeelInput.ATTACK:
			value = cancel_attack
		FeelInput.DODGE:
			value = cancel_dodge
		FeelInput.JUMP:
			value = cancel_jump
		FeelInput.GUARD:
			value = cancel_guard
		FeelInput.MOVE:
			value = cancel_move
		FeelInput.ITEM:
			value = cancel_item
	return value if value >= 0.0 and feel_applies() else -1.0


## The set `input_from` time, or -1 when none is set (or the fields do not count right now).
func feel_input_from() -> float:
	return input_from if input_from >= 0.0 and feel_applies() else -1.0


## True when any 3b-1 field is set and counts right now.
func has_feel_fields() -> bool:
	if not feel_applies():
		return false
	return input_from >= 0.0 or cancel_attack >= 0.0 or cancel_dodge >= 0.0 or cancel_jump >= 0.0 \
			or cancel_guard >= 0.0 or cancel_move >= 0.0 or cancel_item >= 0.0


## True when any 3b-2 turn field is set and counts right now (ER_NUMBERS actions follow the debug switch).
func has_turn_fields() -> bool:
	if not feel_applies():
		return false
	return turn_rate >= 0.0 or not no_turn.is_empty() or not turn_overrides.is_empty()


## True when a 3b-3 motion curve is set and counts right now (ER_NUMBERS actions follow the debug switch).
func has_motion_curve() -> bool:
	return (motion_forward != null or motion_side != null) and feel_applies()


## The fastest forward speed the action moves at: the curve's peak when it has one, else `move_speed`. Used for the
## "do not lunge off an edge" check.
func lunge_speed() -> float:
	if not has_motion_curve() or motion_forward == null:
		return move_speed
	var peak := 0.0
	for i in motion_forward.point_count:
		peak = maxf(peak, absf(motion_forward.get_point_position(i).y))
	return peak


## The turn speed (deg/s) allowed at `time`. Only meaningful when has_turn_fields() is true.
func turn_rate_at(time: float) -> float:
	for span: Vector2 in no_turn:
		if in_window(span, time):
			return 0.0
	for entry: Vector3 in turn_overrides:
		if time >= entry.x and time < entry.y:
			return maxf(entry.z, 0.0)
	return turn_rate if turn_rate >= 0.0 else DEFAULT_TURN_RATE


## Whether `input` may cancel the action at `time` under the 3b-1 fields only: true when no time is set for it.
## States whose old rule is "any time outside the hit window" (an attack) use this directly.
func feel_allows(input: FeelInput, time: float) -> bool:
	var set_time := feel_cancel_time(input)
	return set_time < 0.0 or time >= set_time


## Like feel_allows(), but an input with no time set falls back to `can_cancel()` (the dodge's old rule).
func can_cancel_input(input: FeelInput, time: float) -> bool:
	var set_time := feel_cancel_time(input)
	if set_time < 0.0:
		return can_cancel(time)
	return time >= set_time


func has_iframes(time: float) -> bool:
	return in_window(iframes, time)


func is_hit_active(time: float) -> bool:
	return in_window(active_hit, time)


## True when a 3b-4 hit list is set and counts right now (ER_NUMBERS actions follow the debug switch).
func has_hits() -> bool:
	return not hits.is_empty() and feel_applies()


## 3b-4: the index of the hit whose window holds `time`, or -1 (between hits, or no list). The first match wins.
func hit_index_at(time: float) -> int:
	if not has_hits():
		return -1
	for i in hits.size():
		var spec := hits[i]
		if spec != null and in_window(spec.window, time):
			return i
	return -1
