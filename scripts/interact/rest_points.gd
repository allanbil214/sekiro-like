class_name RestPoints
extends RefCounted
## What the game remembers about rests (Phase 2 item 18), like `GameFlags`: where the player last rested, in which
## scene, and how many rests there were. Kept across the death reload (the Player starts at the last rest point of
## the scene it reloads), cleared when the main menu opens. Phase 4 adds saving to this class.
## Zones and NPCs listen to `RestPoints.bus.rested` (later phases: what regenerates, who comes back).

## The event bus (a static class cannot hold a signal itself).
class Bus extends RefCounted:
	## A rest ended (the refill is done) at `point`. `count` is the number of rests so far.
	signal rested(point: RestPoint, count: int)

static var bus: Bus = Bus.new()

static var last_scene: String = ""
static var last_id: StringName = &""
static var last_position: Vector3 = Vector3.ZERO
static var last_yaw: float = 0.0
static var rest_count: int = 0


## The key of the scene a node lives in: the scene it was placed in (its owner), so it is the same in `_ready`.
static func scene_key(node: Node) -> String:
	var root: Node = node.owner
	if root == null:
		root = node.get_tree().current_scene
	return root.scene_file_path if root != null else ""


## Is there a rest point remembered for this scene?
static func has_last_in(scene_path: String) -> bool:
	return last_id != &"" and last_scene == scene_path


## Remembers a rest at `point`; the player restarts at `position`, facing `yaw`. Announces it on the bus.
static func record(point: RestPoint, position: Vector3, yaw: float) -> void:
	last_scene = scene_key(point)
	last_id = point.get_rest_id()
	last_position = position
	last_yaw = yaw
	rest_count += 1
	bus.rested.emit(point, rest_count)


static func clear() -> void:
	last_scene = ""
	last_id = &""
	last_position = Vector3.ZERO
	last_yaw = 0.0
	rest_count = 0
