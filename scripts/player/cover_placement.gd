class_name CoverPlacement
extends RefCounted
## Finds where the player should lay the carried body in a `CoverVolume` (Phase 2 item 15b). Made in
## `Player._ready()` like `LedgeSensor`. `find()` returns an empty Dictionary when there is no valid spot, or
## {"feet": where the player stands, "yaw": the facing, "spot": the floor point under the body's middle,
## "body_yaw": the body's yaw, "count": how many of its points are inside}.
##
## A bush (`player_enters`): the body's middle is tried on a grid inside the volume, with the player standing
## `carry_put_distance` behind it, in 16 facings, within `cover_snap_reach` of where the player is. The most
## body points inside win, the least walking breaks ties, and the best few are then checked for floor, room for
## the player, a clear path and room for the body (`Player.cover_spot_valid`). A solid container: the best
## body spot and yaw inside the volume, with the player staying put.

const YAW_STEPS: int = 16
const BODY_YAWS: int = 8
const MAX_CHECKED: int = 16

var _player: Player


func _init(player: Player) -> void:
	_player = player


func find(cover: CoverVolume) -> Dictionary:
	var half := cover.get_half_extents()
	var step := maxf(_player.cover_grid_step, 0.05)
	var floor_y := _player.global_position.y if cover.player_enters else cover.get_floor_y()
	var from := _player.global_position
	var candidates: Array[Dictionary] = []
	for lx in _axis_values(half.x, step):
		for lz in _axis_values(half.z, step):
			var spot := cover.local_to_world(Vector3(lx, 0.0, lz))
			spot.y = floor_y
			if cover.player_enters:
				for k in range(YAW_STEPS):
					var yaw := TAU * float(k) / float(YAW_STEPS)
					var forward := Basis(Vector3.UP, yaw) * Vector3.FORWARD
					var feet := spot - forward * _player.carry_put_distance
					var walk := Vector2(feet.x - from.x, feet.z - from.z).length()
					if walk > _player.cover_snap_reach:
						continue
					var count := _count(cover, spot, yaw + PI * 0.5)
					if count < CoverVolume.MIN_POINTS:
						continue
					candidates.append({"feet": feet, "yaw": yaw, "spot": spot, "body_yaw": yaw + PI * 0.5,
							"count": count, "score": float(count) * 10.0 - walk})
			else:
				var centre := cover.get_center()
				var fit := cover.get_fit_scale()
				for j in range(BODY_YAWS):
					var body_yaw := TAU * float(j) / float(BODY_YAWS)
					var count := _count(cover, spot, body_yaw, fit)
					if count < CoverVolume.MIN_POINTS:
						continue
					var off := Vector2(spot.x - centre.x, spot.z - centre.z).length()
					candidates.append({"feet": from, "yaw": _player.visual.global_rotation.y, "spot": spot,
							"body_yaw": body_yaw, "scale": fit, "count": count, "score": float(count) * 10.0 - off})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	if not cover.player_enters:
		return candidates[0]
	for i in range(mini(candidates.size(), MAX_CHECKED)):
		var c := candidates[i]
		if _player.cover_spot_valid(c["feet"], c["yaw"], c["spot"]):
			return c
	return {}


## The body points that fall inside this volume when its middle is above `floor_spot` (a body shrunk to
## `body_scale` is shorter and its middle lower).
func _count(cover: CoverVolume, floor_spot: Vector3, body_yaw: float, body_scale: float = 1.0) -> int:
	var middle := floor_spot + Vector3.UP * Enemy.LYING_MIDDLE.y * body_scale
	var along := Basis(Vector3.UP, body_yaw) * Vector3(0.0, 0.0, body_scale)
	var count := 0
	for t in CoverVolume.POINT_OFFSETS:
		if cover.contains_point(middle + along * t):
			count += 1
	return count


func _axis_values(half: float, step: float) -> Array[float]:
	var values: Array[float] = []
	var n := floori(half / step)
	for i in range(-n, n + 1):
		values.append(float(i) * step)
	return values
