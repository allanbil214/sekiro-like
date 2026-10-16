class_name InteractPicker
extends RefCounted
## Picks the interactable the player would use right now (Phase 2 item 8): in reach and in front, the
## highest priority first, then the nearest. Made in `Player._ready()` like `LedgeSensor`.

var _player: Player


func _init(player: Player) -> void:
	_player = player


## Returns the best usable Interactable, or null.
func pick() -> Interactable:
	var forward := _player.get_facing_direction()
	var best: Interactable = null
	var best_distance := 0.0
	for item: Interactable in Interactable.all():
		if not item.can_interact(_player):
			continue
		var offset := item.global_position - _player.global_position
		if absf(offset.y) > _player.interact_height_range:
			continue
		offset.y = 0.0
		var distance := offset.length()
		if distance > _player.interact_range:
			continue
		# Very close is always "in front" (no angle for a zero-length offset).
		if distance > 0.3 and forward.dot(offset / distance) < _player.interact_min_dot:
			continue
		if best == null or item.priority > best.priority \
				or (item.priority == best.priority and distance < best_distance):
			best = item
			best_distance = distance
	return best
