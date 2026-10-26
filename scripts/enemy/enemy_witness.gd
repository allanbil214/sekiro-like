class_name EnemyWitness
extends RefCounted
## A guard that notices its allies (Phase 2 item 23). Only an Enemy with `use_awareness` and `witnesses_allies` has one
## (made in `Enemy._ready()` after its EnemyAwareness). `EnemyAwareness.update()` calls `Enemy.witness_scan()` every
## IDLE frame, which lands in `scan()` below, four times a second.
##
## - WITNESS: a guard that is not alert (`EnemyAwareness.can_witness()`) looks for the nearest ally it can SEE (inside
##   `witness_range`, both sight cones and a clear line: `can_see_ally()`) that is in combat, or alert and searching
##   (`Enemy.share_knowledge()` is not empty). It turns suspicious about the ally's position and goes to look, retargeting
##   while it still sees the ally, so it follows it. Out of sight, the normal spot check and the return to the patrol
##   follow (the suspicious routine of `EnemyAwareness`).
## - RELAY: an ally inside `relay_distance` that has news (where the player is, or the spot it searches) tells it: the
##   guard goes alert and searches there. The news passes on `relay_max_depth` hops at most (a guard that saw the player
##   itself is depth 0), and a guard that was told is not told again for `relay_cooldown` seconds.
## Not here: the shout when a guard spots the player, a call for help (item 21) and the noise of a fight (item 23,
## `Combatant`), which reach guards that do not see anyone.
## All numbers are in EnemyAIData ("Witness and relay").

## Seconds between two scans (a few rays each).
const SCAN_INTERVAL: float = 0.25

var _enemy: Enemy
var _ai: EnemyAIData
var _awareness: EnemyAwareness
var _timer: float = 0.0


func _init(enemy: Enemy, awareness: EnemyAwareness) -> void:
	_enemy = enemy
	_ai = enemy.ai
	_awareness = awareness
	_timer = randf() * SCAN_INTERVAL


func scan(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = SCAN_INTERVAL
	if not _awareness.can_witness() or _awareness.is_player_undetectable():
		return
	var best: Enemy = null
	var best_distance := INF
	var best_news: Dictionary = {}
	for node: Node3D in Enemies.all():
		var other := node as Enemy
		if other == null or other == _enemy or not other.use_awareness:
			continue
		var news := other.share_knowledge()
		if news.is_empty():
			continue
		var distance := _enemy.global_position.distance_to(other.global_position)
		if distance >= best_distance or not _awareness.can_see_ally(other):
			continue
		best = other
		best_distance = distance
		best_news = news
	if best == null:
		return
	var depth: int = best_news["depth"]
	var told_again := Time.get_ticks_msec() >= _awareness.told_until_msec
	if best_distance <= _ai.relay_distance and depth < _ai.relay_max_depth and told_again:
		_awareness.receive_relay(best, best_news["position"], depth)
	else:
		_awareness.follow_ally(best)
