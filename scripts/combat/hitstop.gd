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


static func request(tree: SceneTree, duration: float) -> void:
	if tree == null or duration <= 0.0:
		return
	_token += 1
	var token := _token
	Engine.time_scale = slow_scale * base_scale
	await tree.create_timer(duration, true, false, true).timeout
	if token == _token:
		Engine.time_scale = base_scale
