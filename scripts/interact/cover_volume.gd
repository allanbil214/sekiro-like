class_name CoverVolume
extends Area3D
## A place where a body can lie unseen (Phase 2 item 15b): a bush, a crate, a closet. The node needs one
## `CollisionShape3D` child with a `BoxShape3D` (it is the volume; keep it upright, you may turn it about Y).
## The volume only measures (it has no collision of its own). A lying body is hidden when most of it is
## inside a volume (`MIN_POINTS` of its `POINT_OFFSETS` points), however it got there; guards cannot discover
## a hidden body by sight (`Enemy.is_hidden_in_cover`). A `CoverPrompt` child lets the player hide a carried
## body here. A bush (`player_enters` true) is walked up to and the body is laid inside it with the player at
## its edge; a solid container (false) takes the body straight in.

## True: the player stands next to the body (a bush). False: the body goes straight in (a crate or closet).
@export var player_enters: bool = true
## How many bodies the volume holds.
@export var capacity: int = 1
## True: the body is shrunk to fit (a placeholder for folding it into the crate or closet). A bush leaves it off:
## the player is in a hurry and just drops the body.
@export var shrink_body: bool = false

## The points along a lying body (m from its middle, along its length) that are tested, and how many must be
## inside the volume for the body to be hidden (3 of 5 = 0.6; a leg sticking out is fine).
const POINT_OFFSETS: Array[float] = [-0.8, -0.4, 0.0, 0.4, 0.8]
const MIN_POINTS: int = 3
## Shrinking: the body's length (m), the share of the volume's longest side it may fill, and the smallest scale.
const BODY_LENGTH: float = 1.8
const FIT_SHARE: float = 0.95
const MIN_SCALE: float = 0.5

var _shape_node: CollisionShape3D
var _half: Vector3 = Vector3.ONE * 0.5


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	add_to_group(Groups.COVER)
	for child in get_children():
		var shape_node := child as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			_shape_node = shape_node
			_half = (shape_node.shape as BoxShape3D).size * 0.5
			break
	if _shape_node == null:
		push_error("CoverVolume: it needs a CollisionShape3D child with a BoxShape3D (Phase 2 item 15b).")


## Half the box's size (m), along its own axes.
func get_half_extents() -> Vector3:
	return _half


## The world height of the box's bottom face.
func get_floor_y() -> float:
	return (_shape_node.global_position.y if _shape_node != null else global_position.y) - _half.y


## The scale a body gets in here: 1 when `shrink_body` is off, otherwise what makes its length fit the volume's
## longest horizontal side (never below MIN_SCALE, never above 1).
func get_fit_scale() -> float:
	if not shrink_body:
		return 1.0
	return clampf(maxf(_half.x, _half.z) * 2.0 * FIT_SHARE / BODY_LENGTH, MIN_SCALE, 1.0)


## A point in the box's own axes (its centre is the origin) as a world point.
func local_to_world(local_point: Vector3) -> Vector3:
	return _shape_node.global_transform * local_point if _shape_node != null else global_transform * local_point


func get_center() -> Vector3:
	return local_to_world(Vector3.ZERO)


func contains_point(point: Vector3) -> bool:
	if _shape_node == null:
		return false
	var local := _shape_node.global_transform.affine_inverse() * point
	return absf(local.x) <= _half.x and absf(local.y) <= _half.y and absf(local.z) <= _half.z


## The closest point of the box to `point` (the point itself when it is inside).
func nearest_point_to(point: Vector3) -> Vector3:
	if _shape_node == null:
		return global_position
	var local := _shape_node.global_transform.affine_inverse() * point
	local = Vector3(clampf(local.x, -_half.x, _half.x), clampf(local.y, -_half.y, _half.y),
			clampf(local.z, -_half.z, _half.z))
	return _shape_node.global_transform * local


## Item 15d: a spot on the floor just outside the box, on the side `point` is nearest to (a body waking up inside).
func exit_point_for(point: Vector3, margin: float) -> Vector3:
	if _shape_node == null:
		return point
	var local := _shape_node.global_transform.affine_inverse() * point
	var out := Vector3(local.x, 0.0, local.z)
	var room_x := _half.x - absf(local.x)
	var room_z := _half.z - absf(local.z)
	if room_x <= room_z:
		out.x = signf(local.x if local.x != 0.0 else 1.0) * (_half.x + margin)
	else:
		out.z = signf(local.z if local.z != 0.0 else 1.0) * (_half.z + margin)
	out.y = -_half.y
	return _shape_node.global_transform * out


## How many bodies lie in the volume now (a carried body does not count).
func bodies_inside() -> int:
	var count := 0
	for node: Node3D in Enemies.all():
		var enemy := node as Enemy
		if enemy == null or enemy.is_carried() or not (enemy.is_corpse() or enemy.is_unconscious()):
			continue
		if contains_point(enemy.get_lying_middle()):
			count += 1
	return count


func has_room() -> bool:
	return bodies_inside() < capacity


## How many of the points are inside any cover volume of the scene.
static func count_inside(tree: SceneTree, points: Array[Vector3]) -> int:
	var covers := tree.get_nodes_in_group(Groups.COVER)
	var count := 0
	for point in points:
		for node in covers:
			var cover := node as CoverVolume
			if cover != null and cover.contains_point(point):
				count += 1
				break
	return count
