class_name EnemyThrow
extends RefCounted
## An enemy that SEES the player but cannot REACH it (a roof or ledge it cannot climb to, Phase 2 item 21) throws
## an item at it and calls for help. Only an Enemy with `use_awareness` and a `throw_item` or `call_for_help` in
## its EnemyAIData has one (made in `Enemy._ready()`).
##
## The hook: `EnemyAwareness._run_search()` has the branch "it sees you but cannot reach you: stand and watch". It
## calls `Enemy.throw_watch()` every frame there, which lands in `watch()` below; the enemy keeps standing and
## facing the player on its own. `tick()` runs every frame from the Enemy loop: a frame without `watch()` (the enemy
## lost sight, can reach the player now, was hit) cancels a wind-up.
## - The throw: when the cooldown is over, the player is inside `throw_range` and the arc to the player's chest is
##   clear (the same ray the aim preview uses), a wind-up of `throw_windup` seconds starts (the body glows). At its
##   end the aim is solved again with the player's current spot, a random spread of `throw_error` is added and the
##   item leaves the hand. The projectile is a `Throwable`: it can be guarded, not deflected, and dodged by i-frames.
##   Its landing makes the item's noise when `throw_makes_noise` is on (unaware guards come to look).
## - The call: every `call_interval` seconds (first one after CALL_FIRST_DELAY) the calm allies inside `call_radius`
##   hear it (`EnemyAwareness.hear_call()`): suspicious, or alert when close.
## Placeholders: the glow, the sounds. All numbers are in EnemyAIData ("Ranged throw and call for help").

## Seconds from the first frame of watching to the first call.
const CALL_FIRST_DELAY: float = 0.8
## Seconds to wait before checking again after a throw could not start (out of range, blocked).
const RETRY_DELAY: float = 0.5
## Where the item starts: this high above the feet and this far toward the player (m).
const RELEASE_HEIGHT: float = 1.3
const RELEASE_FORWARD: float = 0.5
## The aim point above the player's feet (the chest, as for the player's own locked throw).
const TARGET_HEIGHT: float = 1.0
## The arc check steps this many seconds at a time, up to `Throwable.MAX_LIFE`.
const ARC_STEP: float = 0.05

var _enemy: Enemy
var _ai: EnemyAIData
var _cooldown: float = 0.0
## Seconds into the wind-up; negative = not winding up.
var _windup: float = -1.0
var _call_left: float = CALL_FIRST_DELAY
## True when `watch()` ran since the last `tick()`.
var _watched: bool = false


func _init(enemy: Enemy) -> void:
	_enemy = enemy
	_ai = enemy.ai


## Every physics frame, before the awareness runs.
func tick(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not _watched:
		if _windup >= 0.0:
			cancel()
		_call_left = CALL_FIRST_DELAY
	_watched = false


## Called every frame while the enemy sees `target` and cannot reach it.
func watch(delta: float, target: Node3D) -> void:
	_watched = true
	if _ai.call_for_help:
		_call_left -= delta
		if _call_left <= 0.0:
			_call_left = _ai.call_interval
			_call_for_help(target)
	if _ai.throw_item == null:
		return
	if _windup >= 0.0:
		_windup += delta
		_enemy.set_windup_glow(clampf(_windup / maxf(_ai.throw_windup, 0.01), 0.0, 1.0))
		if _windup >= _ai.throw_windup:
			_release(target)
		return
	if _cooldown > 0.0:
		return
	if _enemy.global_position.distance_to(target.global_position) > _ai.throw_range:
		_cooldown = RETRY_DELAY
		return
	var origin := _release_point(target)
	var aim := _aim_point(target)
	if _arc_is_clear(origin, _ai.throw_item.velocity_to(origin, aim), aim):
		_windup = 0.0
	else:
		_cooldown = RETRY_DELAY


## Stops a wind-up (hit, died, lost sight): nothing is thrown and the glow goes out.
func cancel() -> void:
	_windup = -1.0
	_enemy.set_windup_glow(0.0)


func _release(target: Node3D) -> void:
	var item := _ai.throw_item
	var origin := _release_point(target)
	var aim := _aim_point(target)
	var clear := _arc_is_clear(origin, item.velocity_to(origin, aim), aim)
	cancel()
	if not clear:
		_cooldown = RETRY_DELAY
		return
	# The spread: a random point in a disc around the aim point, so it can miss.
	var angle := randf() * TAU
	var radius := sqrt(randf()) * _ai.throw_error
	var missed_aim := aim + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	Throwable.launch(_enemy, item, origin, item.velocity_to(origin, missed_aim), _ai.throw_damage_scale, _ai.throw_makes_noise)
	Sfx.play_at(_enemy.get_tree(), Sfx.Id.SWING_ALT, origin)
	_cooldown = _ai.throw_cooldown


func _release_point(target: Node3D) -> Vector3:
	var flat := target.global_position - _enemy.global_position
	flat.y = 0.0
	var forward := flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	return _enemy.global_position + Vector3.UP * RELEASE_HEIGHT + forward * RELEASE_FORWARD


func _aim_point(target: Node3D) -> Vector3:
	return target.global_position + Vector3.UP * TARGET_HEIGHT


## True when an item thrown from `origin` with `velocity` reaches the player's hurtbox before it hits the world
## (the same ray as the flying item and the aim preview). A throw that falls short or is out of range is not clear.
func _arc_is_clear(origin: Vector3, velocity: Vector3, aim: Vector3) -> bool:
	var item := _ai.throw_item
	var exclude := Throwable.make_exclude(_enemy)
	var position := origin
	var velocity_now := velocity
	var steps := int(Throwable.MAX_LIFE / ARC_STEP)
	for _step in steps:
		velocity_now.y -= item.gravity * ARC_STEP
		var next := position + velocity_now * ARC_STEP
		var result := Throwable.trace(_enemy, position, next, exclude, Layers.PLAYER_HURTBOX)
		if not result.is_empty():
			return result.get("collider") is Hurtbox
		position = next
		if position.y < aim.y - 4.0:
			return false
	return false


## The calm allies in earshot come to look (suspicious, or alert when close), told where the player is.
func _call_for_help(target: Node3D) -> void:
	Sfx.play_at(_enemy.get_tree(), Sfx.Id.ENEMY_PROVOKED, _enemy.global_position + Vector3.UP * 1.5)
	for other: Enemy in _enemy.calm_allies_within(_ai.call_radius):
		other.hear_call(_enemy.global_position, target.global_position, _ai.call_radius)
