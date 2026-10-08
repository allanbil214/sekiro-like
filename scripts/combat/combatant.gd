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
##
## Posture (Step 6): a meter from 0 to max_posture. Guarded hits, deflects (a little, and the
## attacker takes some), and unguarded hits add to it (HitData.posture_damage x a factor per
## outcome). Full = posture break: posture_broken is emitted and it stays full until
## reset_posture() (the player's StaggerState does that; with deathblow_enabled the Combatant
## opens a deathblow window instead). Regen: tick_posture() each physics frame.
## Deathblow (deathblow_enabled, the dummy now, the enemy later): health_bars bars; emptying a bar
## fills posture and opens a window (deathblow_window s). execute_deathblow() inside it removes a
## bar (the next starts full; on the last bar it kills). Missed: health returns to 1 (not refilled)
## and posture to 0, so the next damage empties it again; a missed window on the final bar of a
## non-boss kills. A posture break at any health opens the same window (a miss just resets posture).

signal damaged(hit: HitData, amount: float)
signal health_changed(current: float, maximum: float)
signal died
## A plain guard blocked the hit. `chip` is the health lost (0 unless chip damage is on).
signal hit_guarded(hit: HitData, chip: float)
signal hit_deflected(hit: HitData)
## A perilous attack landed as a plain hit on a guard that was up and facing it, or a grab landed: the
## guard is broken.
signal guard_broken(hit: HitData)
## A hit of THIS combatant's was repulsed by its target (a repulse deflect, Step 7b): `knockback` is
## how far (m) to push this combatant back. The owner also cuts its current swing (the player does).
signal repulsed(hit: HitData, knockback: float)
signal posture_changed(current: float, maximum: float)
## Posture just reached the maximum.
signal posture_broken
signal bars_changed(left: int, total: int)
signal deathblow_opened
## The window ended: executed (a deathblow landed) and killed (the combatant died of it).
signal deathblow_closed(executed: bool, killed: bool)

@export var max_health: float = 100.0

@export_group("Health bars and deathblow")
## How many health bars (Sekiro pips). The player has 1.
@export var health_bars: int = 1
## On: an empty bar or a posture break opens a deathblow window (instead of dying). Off: the old
## behavior, health 0 = died.
@export var deathblow_enabled: bool = false
## A boss's final bar never dies of a missed deathblow: it returns to 1 HP and goes on.
@export var boss: bool = false
## How long (s) the deathblow window stays open.
@export var deathblow_window: float = 4.0

@export_group("Defense")
## Multipliers on what this combatant takes, applied last (1.0 = normal, 0.5 = takes half, 1.5 =
## weak). Health covers damage and chip damage; posture covers every posture hit, including the
## posture a deflect puts on an attacker.
@export var health_taken_multiplier: float = 1.0
@export var posture_taken_multiplier: float = 1.0

@export_group("Posture")
@export var max_posture: float = 100.0
## Posture lost per second while regenerating (starts after posture_regen_delay).
@export var posture_regen: float = 15.0
@export var posture_regen_delay: float = 1.0
## Regen multiplier at 0 health (linear up to 1.0 at full health).
@export_range(0.0, 1.0) var low_health_regen_factor: float = 0.5
## Player only: guarding for fast_regen_guard_time seconds multiplies regen by fast_regen_factor.
@export var fast_regen_on_guard: bool = false
@export var fast_regen_guard_time: float = 3.0
@export var fast_regen_factor: float = 2.0
## Share of the hit's posture_damage the defender takes per outcome.
@export var posture_factor_hit: float = 0.5
@export var posture_factor_guard: float = 1.0
@export var posture_factor_deflect: float = 0.1
## Share of the hit's posture_damage the ATTACKER takes when its hit is deflected.
@export var attacker_posture_factor_deflect: float = 0.5
## Damage multiplier on unguarded hits while `vulnerable` (the player's stagger sets it).
@export var staggered_damage_multiplier: float = 1.5

@export_group("Guard")
## The deflect window (s) opened by a fresh guard press.
@export var deflect_window: float = 0.2
## A press shortens the window by this much (s), down to deflect_floor, when it is a rapid tap (less
## than deflect_rapid_interval s after the previous press) or comes after deflect_free_presses presses
## in the same run (so slow tapping is free for the first few presses, then shrinks too).
@export var deflect_shrink: float = 0.04
@export var deflect_floor: float = 0.05
@export var deflect_rapid_interval: float = 0.35
@export var deflect_free_presses: int = 3
## The run resets (a full window again): after this many seconds of neither guarding nor acting, after
## holding the guard this long since the last press, at once when the owner acts, deflects a hit, or
## takes an unguarded hit. A plain guard does not reset it.
@export var deflect_reset_time: float = 1.0
@export var deflect_hold_reset_time: float = 3.0
## Total width of the guarded cone in front (degrees).
@export var guard_cone_degrees: float = 90.0
## Off (the Sekiro default): a plain guard costs no health. On: it costs chip_ratio of the damage.
@export var chip_damage_enabled: bool = false
@export_range(0.0, 1.0) var chip_ratio: float = 0.15
## How strongly a hit's knockback applies to this combatant per outcome.
@export var knockback_multiplier_hit: float = 1.0
@export var knockback_multiplier_guard: float = 1.0
@export var knockback_multiplier_deflect: float = 0.6
## Repulse (Step 7b): when a deflect window was opened with press_guard(true), the attacker is also
## pushed back repulse_knockback m, takes this share of the hit's posture damage on top of the
## normal deflect posture, and gets `repulsed`: the player's swing is cut and its blade bounces, and
## the combo is back at attack 1. It is not stunned: it can guard, jump, or dodge at once.
@export var repulse_knockback: float = 1.5
@export var repulse_attacker_posture_extra: float = 0.5
## Print guard presses, spam resets, and outcomes to the Output panel. Off by default; tick it
## in the Inspector when tuning.
@export var debug_log: bool = false

var health: float = 0.0
var dead: bool = false
var bars_left: int = 1
var posture: float = 0.0
## True from the moment posture is full until reset_posture() (or the deathblow window ends).
var posture_full: bool = false
var deathblow_open: bool = false
var deathblow_left: float = 0.0
## Set by the owner (the player's stagger): unguarded hits do staggered_damage_multiplier x damage.
var vulnerable: bool = false

## Set by the owner's guard state.
var guarding: bool = false
## A Callable returning the owner's facing direction (Vector3). Without one, the cone is ignored.
var guard_facing: Callable = Callable()
## Seconds left in the current deflect window (0 = closed).
var deflect_left: float = 0.0
## Size (s) of the last window opened, and the rapid-press count behind it (debug overlay).
var current_window: float = 0.0
var press_count: int = 0
## How many shrink steps the current run has (each takes deflect_shrink off the window).
var shrink_steps: int = 0
## The last outcome (HitData.Outcome), or -1 before any hit.
var last_outcome: int = -1

var _spam_idle: float = 0.0
var _since_press: float = 999.0
var _hold_time: float = 0.0
var _since_posture_hit: float = 0.0
## The current deflect window was opened as a repulse (press_guard(true)).
var _window_repulse: bool = false
var _guard_hold: float = 0.0


func _ready() -> void:
	health = max_health
	bars_left = health_bars


func _physics_process(delta: float) -> void:
	if not deathblow_open:
		return
	deathblow_left -= delta
	if deathblow_left <= 0.0:
		_deathblow_missed()


## Call once per physics frame. Acting (an attack, dodge, or any other action) resets the spam
## count at once, since a press after a different action is not a re-press. While guarding the
## count is held; after deflect_reset_time of neither it resets too.
func tick_guard(delta: float, guard_up: bool, acting: bool) -> void:
	deflect_left = maxf(deflect_left - delta, 0.0)
	_since_press += delta
	if acting:
		_reset_spam("acting")
		_spam_idle = 0.0
		_hold_time = 0.0
		return
	if guard_up:
		_spam_idle = 0.0
		_hold_time += delta
		if _hold_time >= deflect_hold_reset_time:
			_reset_spam("a long hold")
		return
	_hold_time = 0.0
	_spam_idle += delta
	if _spam_idle >= deflect_reset_time:
		_reset_spam("%.1f s idle" % _spam_idle)


## Start a fresh run: the next press opens a full window.
func _reset_spam(reason: String) -> void:
	if press_count <= 0 and shrink_steps <= 0:
		return
	if debug_log:
		print("[Guard] spam run reset by %s (was %d presses, %d steps)" % [reason, press_count, shrink_steps])
	press_count = 0
	shrink_steps = 0


## Would the next press shrink the window: a rapid tap, or past the free presses of this run.
func _next_press_shrinks() -> bool:
	return press_count > 0 and (_since_press < deflect_rapid_interval or press_count >= deflect_free_presses)


## The size (s) the next press would open: what the spam count currently allows.
func next_window() -> float:
	var steps := shrink_steps + (1 if _next_press_shrinks() else 0)
	return maxf(deflect_window - deflect_shrink * float(steps), deflect_floor)


## Seconds of neither guarding nor acting so far (the spam count resets at deflect_reset_time).
func spam_idle() -> float:
	return _spam_idle


## A fresh guard press: open a new deflect window (shrunk by recent rapid presses). Returns its size.
## `repulse`: a deflect inside this window is a repulse (see repulse_knockback).
func press_guard(repulse: bool = false) -> float:
	var window := next_window()
	if _next_press_shrinks():
		shrink_steps += 1
	_window_repulse = repulse
	press_count += 1
	_since_press = 0.0
	_hold_time = 0.0
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
		_reset_spam("a deflect")
		hit_deflected.emit(hit)
		add_posture(hit.posture_damage * posture_factor_deflect)
		var attacker := Combatant.of(hit.attacker)
		if attacker != null:
			attacker.add_posture(hit.posture_damage * attacker_posture_factor_deflect)
			if _window_repulse:
				attacker.add_posture(hit.posture_damage * repulse_attacker_posture_extra)
				attacker.repulsed.emit(hit, repulse_knockback)
		return 0.0
	if outcome == HitData.Outcome.GUARD:
		var chip := 0.0
		if chip_damage_enabled:
			chip = minf(hit.damage * chip_ratio * health_taken_multiplier, health)
		hit_guarded.emit(hit, chip)
		_lose_health(chip)
		add_posture(hit.posture_damage * posture_factor_guard)
		return chip
	_reset_spam("taking a hit")
	var breaks_guard := hit.grab or (guarding and hit.perilous and _in_cone(hit))
	var multiplier := staggered_damage_multiplier if vulnerable else 1.0
	var amount := minf(hit.damage * multiplier * health_taken_multiplier, health)
	health -= amount
	damaged.emit(hit, amount)
	health_changed.emit(health, max_health)
	if breaks_guard:
		guard_broken.emit(hit)
	add_posture(hit.posture_damage * posture_factor_hit)
	if health <= 0.0:
		_health_empty()
	return amount


## The Combatant of a node that exposes one as `combatant` (the player, the dummy), or null.
static func of(node: Object) -> Combatant:
	if node == null:
		return null
	return node.get("combatant") as Combatant


## Add posture (ignored while dead, or once it is already full). Full = a posture break.
func add_posture(amount: float) -> void:
	if amount <= 0.0 or dead or posture_full:
		return
	amount *= posture_taken_multiplier
	if amount <= 0.0:
		return
	posture = minf(posture + amount, max_posture)
	_since_posture_hit = 0.0
	posture_changed.emit(posture, max_posture)
	if posture >= max_posture:
		posture_full = true
		posture_broken.emit()
		if deathblow_enabled:
			_open_deathblow()


## Back to 0 posture (the end of a stagger).
func reset_posture() -> void:
	posture = 0.0
	posture_full = false
	_since_posture_hit = 0.0
	posture_changed.emit(posture, max_posture)


## Call once per physics frame. `paused`: the owner is attacking, dashing, or dodging.
func tick_posture(delta: float, paused: bool) -> void:
	if fast_regen_on_guard and guarding:
		_guard_hold += delta
	else:
		_guard_hold = 0.0
	if paused or dead or posture_full or deathblow_open or posture <= 0.0:
		return
	_since_posture_hit += delta
	if _since_posture_hit < posture_regen_delay:
		return
	var rate := posture_regen * lerpf(low_health_regen_factor, 1.0, clampf(health / maxf(max_health, 0.001), 0.0, 1.0))
	if fast_regen_on_guard and _guard_hold >= fast_regen_guard_time:
		rate *= fast_regen_factor
	posture = maxf(posture - rate * delta, 0.0)
	posture_changed.emit(posture, max_posture)


## A deathblow lands inside the window. Returns false if none is open.
func execute_deathblow() -> bool:
	if not deathblow_open:
		return false
	deathblow_open = false
	if bars_left > 1:
		bars_left -= 1
		health = max_health
		reset_posture()
		health_changed.emit(health, max_health)
		bars_changed.emit(bars_left, health_bars)
		deathblow_closed.emit(true, false)
		return true
	bars_left = 0
	health = 0.0
	dead = true
	health_changed.emit(health, max_health)
	bars_changed.emit(bars_left, health_bars)
	deathblow_closed.emit(true, true)
	died.emit()
	return true


## Back to full health, all bars, no posture, and alive.
func reset() -> void:
	health = max_health
	dead = false
	bars_left = health_bars
	deathblow_open = false
	reset_posture()
	health_changed.emit(health, max_health)
	bars_changed.emit(bars_left, health_bars)


func _lose_health(amount: float) -> void:
	if amount <= 0.0:
		return
	health -= amount
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_health_empty()


## Health reached 0: open the deathblow window, or die (no deathblow for this combatant).
func _health_empty() -> void:
	if dead:
		return
	if deathblow_enabled:
		health = 0.0
		_open_deathblow()
		return
	dead = true
	died.emit()


## Fill posture and start the window (once).
func _open_deathblow() -> void:
	if deathblow_open:
		return
	deathblow_open = true
	deathblow_left = deathblow_window
	if not posture_full:
		posture = max_posture
		posture_full = true
		posture_changed.emit(posture, max_posture)
	deathblow_opened.emit()


## The window ran out. Empty health: die on a non-boss final bar, else recover at 1 HP. Either way
## posture goes back to 0.
func _deathblow_missed() -> void:
	deathblow_open = false
	if health <= 0.0:
		if bars_left <= 1 and not boss:
			dead = true
			deathblow_closed.emit(false, true)
			died.emit()
			return
		health = 1.0
		health_changed.emit(health, max_health)
	reset_posture()
	deathblow_closed.emit(false, false)


func _resolve(hit: HitData) -> int:
	if not guarding or not _in_cone(hit):
		return HitData.Outcome.HIT
	if hit.deflectable and deflect_left > 0.0 \
			and (hit.deflect_within < 0.0 or current_window - deflect_left <= hit.deflect_within):
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
