class_name Combatant
extends Node
## Health and guard rules for anything that can be hurt (the dummy now; the player and the enemy
## later share this component, so the rules match). Posture and health bars come in later steps.
##
## Guard (Step 5): the owner sets `guarding` while its guard is up and gives `guard_facing` (a
## Callable returning its facing direction). take_hit() then decides the outcome before any damage:
##   DEFLECT: inside the deflect window, in the guard cone, and the hit is deflectable. No damage.
##   GUARD:   in the cone and the hit is guardable. No damage, or chip damage if enabled.
##   HIT:     anything else (behind you, unguardable, not guarding): full damage.
## Every deflect needs a fresh press_guard(); each rapid re-press shrinks the window (not a
## lockout). The count resets at once when you act (attack, dodge...), and after
## deflect_reset_time of neither guarding nor acting.
## Step 6 plugs posture into the hit_guarded and hit_deflected signals.

signal damaged(hit: HitData, amount: float)
signal health_changed(current: float, maximum: float)
signal died
## A plain guard blocked the hit. `chip` is the health lost (0 unless chip damage is on).
signal hit_guarded(hit: HitData, chip: float)
signal hit_deflected(hit: HitData)

@export var max_health: float = 100.0

@export_group("Guard")
## The deflect window (s) opened by a fresh guard press.
@export var deflect_window: float = 0.2
## Each rapid re-press shortens the window by this much (s), down to deflect_floor.
@export var deflect_shrink: float = 0.04
@export var deflect_floor: float = 0.05
## Seconds of neither guarding nor acting after which the window is full size again.
@export var deflect_reset_time: float = 1.0
## Total width of the guarded cone in front (degrees).
@export var guard_cone_degrees: float = 90.0
## Off (the Sekiro default): a plain guard costs no health. On: it costs chip_ratio of the damage.
@export var chip_damage_enabled: bool = false
@export_range(0.0, 1.0) var chip_ratio: float = 0.15
## How strongly a hit's knockback applies to this combatant per outcome.
@export var knockback_multiplier_hit: float = 1.0
@export var knockback_multiplier_guard: float = 1.0
@export var knockback_multiplier_deflect: float = 0.6
## Print guard presses, spam resets, and outcomes to the Output panel. Off by default; tick it
## in the Inspector when tuning.
@export var debug_log: bool = false

var health: float = 0.0
var dead: bool = false

## Set by the owner's guard state.
var guarding: bool = false
## A Callable returning the owner's facing direction (Vector3). Without one, the cone is ignored.
var guard_facing: Callable = Callable()
## Seconds left in the current deflect window (0 = closed).
var deflect_left: float = 0.0
## Size (s) of the last window opened, and the rapid-press count behind it (debug overlay).
var current_window: float = 0.0
var press_count: int = 0
## The last outcome (HitData.Outcome), or -1 before any hit.
var last_outcome: int = -1

var _spam_idle: float = 0.0


func _ready() -> void:
	health = max_health


## Call once per physics frame. Acting (an attack, dodge, or any other action) resets the spam
## count at once, since a press after a different action is not a re-press. While guarding the
## count is held; after deflect_reset_time of neither it resets too.
func tick_guard(delta: float, guard_up: bool, acting: bool) -> void:
	deflect_left = maxf(deflect_left - delta, 0.0)
	if acting:
		if press_count > 0:
			if debug_log:
				print("[Guard] spam count reset by acting (was %d presses)" % press_count)
			press_count = 0
		_spam_idle = 0.0
		return
	if guard_up:
		_spam_idle = 0.0
		return
	_spam_idle += delta
	if _spam_idle >= deflect_reset_time and press_count > 0:
		if debug_log:
			print("[Guard] spam count reset after %.1f s idle (was %d presses)" % [_spam_idle, press_count])
		press_count = 0


## The size (s) the next press would open: what the spam count currently allows.
func next_window() -> float:
	return maxf(deflect_window - deflect_shrink * float(press_count), deflect_floor)


## Seconds of neither guarding nor acting so far (the spam count resets at deflect_reset_time).
func spam_idle() -> float:
	return _spam_idle


## A fresh guard press: open a new deflect window (shrunk by recent rapid presses). Returns its size.
func press_guard() -> float:
	var window := next_window()
	press_count += 1
	current_window = window
	deflect_left = window
	_spam_idle = 0.0
	if debug_log:
		print("[Guard] press #%d: window %.2f s" % [press_count, window])
	return window


## Apply a hit. Returns the health actually lost (never more than the health left).
func take_hit(hit: HitData) -> float:
	if dead:
		return 0.0
	var outcome := _resolve(hit)
	hit.outcome = outcome
	last_outcome = outcome
	if debug_log and guarding:
		print("[Guard] hit -> %s (window left %.2f s)" % [["HIT", "GUARD", "DEFLECT"][outcome], deflect_left])
	if outcome == HitData.Outcome.DEFLECT:
		hit_deflected.emit(hit)
		return 0.0
	if outcome == HitData.Outcome.GUARD:
		var chip := 0.0
		if chip_damage_enabled:
			chip = minf(hit.damage * chip_ratio, health)
		hit_guarded.emit(hit, chip)
		_lose_health(chip)
		return chip
	var amount := minf(hit.damage, health)
	health -= amount
	damaged.emit(hit, amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		dead = true
		died.emit()
	return amount


## Back to full health and alive.
func reset() -> void:
	health = max_health
	dead = false
	health_changed.emit(health, max_health)


func _lose_health(amount: float) -> void:
	if amount <= 0.0:
		return
	health -= amount
	health_changed.emit(health, max_health)
	if health <= 0.0 and not dead:
		dead = true
		died.emit()


func _resolve(hit: HitData) -> int:
	if not guarding or not _in_cone(hit):
		return HitData.Outcome.HIT
	if hit.deflectable and deflect_left > 0.0:
		return HitData.Outcome.DEFLECT
	if hit.guardable:
		return HitData.Outcome.GUARD
	return HitData.Outcome.HIT


## True if the attacker is inside the guarded cone in front (hit.direction runs attacker to target).
func _in_cone(hit: HitData) -> bool:
	if not guard_facing.is_valid():
		return true
	var facing: Vector3 = guard_facing.call()
	var to_attacker := -hit.direction
	facing.y = 0.0
	to_attacker.y = 0.0
	if facing.length_squared() < 0.0001 or to_attacker.length_squared() < 0.0001:
		return true
	return facing.normalized().dot(to_attacker.normalized()) >= cos(deg_to_rad(guard_cone_degrees * 0.5))
