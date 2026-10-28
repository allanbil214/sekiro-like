class_name Hitstop
extends RefCounted
## Hitstop: a very short near-freeze of the whole game when a hit connects. Time is measured in
## real seconds (the timer ignores the time scale). Several requests in a row keep the freeze going
## until the last one ends. Step 11 can hang camera shake, sparks, and sound on the same call.

## How slow the game runs during a hitstop (0.05 = 5% speed).
static var slow_scale: float = 0.05

## 3a-3c: the speed the game returns to after a hitstop or a victory slow-mo: 1.0, or the debug menu's slow motion.
static var base_scale: float = 1.0

static var _token: int = 0

## 3c-1: the freeze of single fighters (a hit freezes its attacker and its target, not the whole game).
## Fighter instance id -> the real time (msec) the freeze ends.
static var _frozen_until: Dictionary = {}


## Freeze one fighter (the player, an enemy or the dummy) for `duration` real seconds. Its own clock runs at `slow_scale`
## (a fighter reads `fighter_scale()` and multiplies its delta); everything else keeps running. Several requests keep it
## frozen until the last one ends. `request()` below is still the whole-game freeze (the deathblow and the boss-slain screen).
static func freeze(fighter: Node, duration: float) -> void:
	if duration <= 0.0 or fighter == null or not is_instance_valid(fighter):
		return
	var now := Time.get_ticks_msec()
	var end := now + int(duration * 1000.0)
	for id: int in _frozen_until.keys():
		if int(_frozen_until[id]) <= now:
			_frozen_until.erase(id)
	var key := fighter.get_instance_id()
	if end > int(_frozen_until.get(key, 0)):
		_frozen_until[key] = end


## 1.0 normally, `slow_scale` while this fighter is frozen. Multiply the fighter's delta by it.
static func fighter_scale(fighter: Node) -> float:
	if fighter == null or _frozen_until.is_empty():
		return 1.0
	var key := fighter.get_instance_id()
	if not _frozen_until.has(key):
		return 1.0
	if int(_frozen_until[key]) <= Time.get_ticks_msec():
		_frozen_until.erase(key)
		return 1.0
	return slow_scale


## `move_and_slide()` for a fighter that may be frozen: the velocity is scaled down for the move and back up after it, so
## the body creeps at the same share as its clock and collisions still work.
static func slide(body: CharacterBody3D, scale: float) -> void:
	if scale >= 1.0:
		body.move_and_slide()
		return
	var safe := maxf(scale, 0.001)
	body.velocity *= safe
	body.move_and_slide()
	body.velocity /= safe


static func request(tree: SceneTree, duration: float) -> void:
	if tree == null or duration <= 0.0:
		return
	_token += 1
	var token := _token
	Engine.time_scale = slow_scale * base_scale
	await tree.create_timer(duration, true, false, true).timeout
	if token == _token:
		Engine.time_scale = base_scale
