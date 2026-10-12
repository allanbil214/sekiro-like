class_name EnemyDefense
extends RefCounted
## The enemy's defense decisions (Phase 1.5, item 5b), moved out of Enemy: it reads the player's attack,
## rolls the plan for a new threat (guard or not, deflect or not, repulse or not, reaction delay), carries
## the plan out on time, and keeps the memory the plan depends on (the hit streak, the guarded-hit streak
## and its break-out, the repeat bonus, the riposte timer). The guard itself (stance, deflect press) is done
## by the Enemy through raise_guard() and drop_guard(); this class only decides when. All tuning stays in
## the EnemyAIData on the Enemy (`ai`). Every number and every debug line is as it was in enemy.gd.

## The hit streak (see EnemyAIData.hit_streak_limit) resets after this long (s) without a hit.
const STREAK_RESET_TIME: float = 3.0
## Random jitter (s) on when a planned deflect presses, so it is not machine-perfect.
const PRESS_JITTER: float = 0.03

var enemy: Enemy

## Seconds since the player last hit it, and how many unguarded hits in a row (reset by a guarded hit).
var since_hit: float = 999.0
var hit_streak: int = 0
## Pressure break-out: guarded hits in a row, how many it takes, and the forced defense it arms.
var guarded_streak: int = 0
var break_threshold: int = 1
var break_armed: bool = false
var break_riposte: bool = false
var since_guard_reaction: float = 999.0
## Seconds since the player was last in the damaging part of an attack (the recovery pose reads this).
var since_player_attack: float = 999.0
## The guard stays up this much longer (s) after a guarded or deflected hit.
var guard_hold: float = 0.0
var riposte_pending: bool = false
var riposte_timer: float = 0.0

var _seen_action: ActionData
var _seen_time: float = 0.0
var _threat_active: bool = false
var _threat_action: ActionData
var _threat_time: float = 0.0
var _last_attack_action: ActionData
var _repeat_count: int = 0
var _react_timer: float = 0.0
var _press_lead: float = 0.0
var _plan_guard: bool = false
var _plan_deflect: bool = false
var _plan_repulse: bool = false
var _pressed: bool = false


func _init(owner_enemy: Enemy) -> void:
	enemy = owner_enemy


## It can only guard in IDLE, CHASE, and YIELD: never in its own attack, recovery, a flinch, the
## pose, or a stun. That is where the player's openings come from.
static func phase_allows_guard(p: Enemy.Phase) -> bool:
	return p == Enemy.Phase.IDLE or p == Enemy.Phase.CHASE or p == Enemy.Phase.YIELD


## The streak timers (every physics frame): the hit streak and the guarded-hit streak both lapse.
func tick(delta: float) -> void:
	since_hit += delta
	if since_hit > STREAK_RESET_TIME:
		hit_streak = 0
	since_guard_reaction += delta
	if since_guard_reaction > STREAK_RESET_TIME and (guarded_streak > 0 or break_armed):
		break_armed = false
		reset_guard_streak()


## Read the player's current attack (`state` is its current action state, or null: no target). A new threat rolls
## the plan (guard or not, deflect or not, repulse or not) and a reaction delay; then the plan is
## carried out while the threat lasts.
func update(delta: float, distance: float, state: ActionState) -> void:
	var ai := enemy.ai
	var idle_before := since_player_attack
	var attack: ActionData = null
	if state != null:
		attack = state.action
	var attacking := attack != null and attack.kind == ActionData.Kind.ATTACK \
			and attack.damage > 0.0 and state.action_time < attack.active_hit.y
	if attacking:
		since_player_attack = 0.0
	else:
		since_player_attack += delta
	# A charge holds the player's clock still: that is not a hit coming yet.
	var frozen := attacking and attack == _seen_action and is_equal_approx(state.action_time, _seen_time)
	_seen_action = attack if attacking else null
	_seen_time = state.action_time if attacking else 0.0
	var threat := attacking and not frozen and distance <= ai.threat_range
	var time_to_hit: float = INF
	if threat:
		time_to_hit = maxf((attack.active_hit.x - state.action_time) / maxf(state.speed_scale, 0.01), 0.0)
		if not _threat_active or attack != _threat_action or state.action_time < _threat_time:
			_begin_threat(attack, idle_before)
		_threat_time = state.action_time
		_threat_action = attack
	_threat_active = threat
	var can_guard := phase_allows_guard(enemy.phase)
	if threat and _plan_guard and can_guard:
		_react_timer -= delta
		# A planned deflect presses on time whatever the reaction delay; only a plain guard waits for it.
		var pressing := _plan_deflect and not _pressed and time_to_hit <= _press_lead
		if _react_timer <= 0.0 or pressing:
			guard_hold = ai.guard_hold_time
			enemy.raise_guard(false, false)
			if pressing:
				_pressed = true
				enemy.raise_guard(true, _plan_repulse)
				if enemy.debug_log and OS.is_debug_build():
					print("[Enemy] deflect press (%s), %.2f s before the hit" % [
						"repulse" if _plan_repulse else "normal", time_to_hit])
		return
	if enemy.is_guarding():
		guard_hold -= delta
		if guard_hold <= 0.0 or not can_guard:
			enemy.drop_guard()


func _begin_threat(attack: ActionData, idle_before: float) -> void:
	var ai := enemy.ai
	if idle_before > 3.0 or attack != _last_attack_action:
		_repeat_count = 0
	else:
		_repeat_count += 1
	_last_attack_action = attack
	_pressed = false
	var pressured := since_hit <= ai.retry_window
	# Retry: after a landed hit the guard comes up at once (no reaction delay).
	_react_timer = 0.0 if pressured else randf_range(ai.reaction_delay.x, ai.reaction_delay.y)
	_press_lead = maxf(enemy.combatant.next_window() * 0.5 + randf_range(-PRESS_JITTER, PRESS_JITTER), 0.0)
	var guard_chance := ai.pressured_guard_chance if pressured else ai.neutral_guard_chance
	var deflect_chance := ai.pressured_deflect_chance if pressured else ai.neutral_deflect_chance
	guard_chance = clampf(guard_chance + ai.repeat_attack_guard_bonus * float(_repeat_count), 0.0, 1.0)
	_plan_guard = randf() < guard_chance
	var forced := ai.hit_streak_limit > 0 and hit_streak >= ai.hit_streak_limit
	if forced:
		_plan_guard = true
	var breaking := break_armed
	break_armed = false
	break_riposte = breaking
	if breaking:
		_plan_guard = true
	_plan_deflect = _plan_guard and (breaking or randf() < deflect_chance)
	_plan_repulse = _plan_deflect and randf() < ai.repulse_chance
	if enemy.debug_log and OS.is_debug_build():
		print("[Enemy] threat (%s, repeat %d, streak %d%s): guard=%s deflect=%s repulse=%s react %.2f s" % [
			"pressured" if pressured else "neutral", _repeat_count, hit_streak,
			(", forced guard" if forced else "") + (", BREAK-OUT" if breaking else ""),
			_plan_guard, _plan_deflect, _plan_repulse, _react_timer])


## Run the riposte timer. Returns true on the frame the riposte should start (the Enemy starts the burst).
func tick_riposte(delta: float, has_target: bool) -> bool:
	if not riposte_pending:
		return false
	if not has_target or not phase_allows_guard(enemy.phase):
		riposte_pending = false
		return false
	riposte_timer -= delta
	if riposte_timer <= 0.0:
		riposte_pending = false
		if enemy.debug_log and OS.is_debug_build():
			print("[Enemy] riposte")
		return true
	return false


## Pressure break-out: how many of the player's hits in a row it takes before the next defense is
## forced (mostly pressure_break_hits, sometimes a random lower number).
func roll_break_threshold() -> void:
	var hits := enemy.ai.pressure_break_hits
	if hits <= 1 or randf() >= enemy.ai.pressure_break_early_chance:
		break_threshold = maxi(hits, 1)
	else:
		break_threshold = randi_range(1, hits - 1)


func reset_guard_streak() -> void:
	guarded_streak = 0
	roll_break_threshold()


func count_guarded_hit() -> void:
	since_guard_reaction = 0.0
	if enemy.ai.pressure_break_hits <= 0:
		return
	guarded_streak += 1
	if guarded_streak >= break_threshold:
		break_armed = true
		if enemy.debug_log and OS.is_debug_build():
			print("[Enemy] pressure: %d guarded hits in a row, next defense is a break-out" % guarded_streak)
		reset_guard_streak()


## An unguarded hit landed: it counts toward the hit streak, and the guarded-hit streak starts over.
func on_unguarded_hit() -> void:
	since_hit = 0.0
	hit_streak += 1
	reset_guard_streak()


## A guarded or deflected hit: the hit streak ends, the guarded-hit streak grows, the guard stays up a bit.
func on_guard_reaction() -> void:
	hit_streak = 0
	count_guarded_hit()
	guard_hold = maxf(guard_hold, enemy.ai.guard_hold_time)


## A deflect: it may earn a riposte (always the one the break-out armed).
func on_deflected() -> void:
	if break_riposte or randf() < enemy.ai.riposte_chance:
		riposte_pending = true
		riposte_timer = enemy.ai.riposte_delay
	break_riposte = false


## Back to a fresh start after the enemy respawns.
func reset_for_respawn() -> void:
	since_hit = 999.0
	hit_streak = 0
	break_armed = false
	break_riposte = false
	reset_guard_streak()
	since_player_attack = 999.0
