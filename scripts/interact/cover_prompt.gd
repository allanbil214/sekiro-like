class_name CoverPrompt
extends Interactable
## The "Hide body" prompt of a `CoverVolume` (Phase 2 item 15b); a child of the volume. It shows only while
## the player carries a body, is within `Player.cover_snap_reach` of the volume, the volume has room, and a
## valid spot exists (`Player.find_cover_placement`). The press starts the placement (`CoverPlaceState`).

var _cover: CoverVolume


func _ready() -> void:
	_cover = get_parent() as CoverVolume
	if _cover == null:
		push_error("CoverPrompt: it must be a child of a CoverVolume (Phase 2 item 15b).")
	if prompt_text == "Use":
		prompt_text = "Hide body"
	usable_while_carrying = true
	needs_facing = false
	priority = 10


func can_interact(player: Player) -> bool:
	if _cover == null or not player.is_carrying():
		return false
	var near := _cover.nearest_point_to(player.global_position)
	if Vector2(near.x - player.global_position.x, near.z - player.global_position.z).length() > player.cover_snap_reach \
			or absf(near.y - player.global_position.y) > 2.0:
		return false
	if not _cover.has_room():
		return false
	return not player.find_cover_placement(_cover).is_empty()


## The picker measures from the nearest point of the volume, so a big bush can be used from its edge.
func reach_point(player: Player) -> Vector3:
	return _cover.nearest_point_to(player.global_position) if _cover != null else global_position


func _on_interact(player: Player) -> void:
	if _cover != null:
		player.begin_cover_place(_cover)
