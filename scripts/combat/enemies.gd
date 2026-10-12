class_name Enemies
extends RefCounted
## The list of every enemy in the scene (`Enemy` and `Dummy`), kept so the code that needs "all the
## enemies" every frame does not ask the scene tree to build a new list each time.
## An enemy calls `register(self)` in `_ready()` and `unregister(self)` in `_exit_tree()`. The list
## holds every enemy in the tree, dead ones too (the callers check `dead` themselves), exactly like
## the `Groups.ENEMY` group, which the enemies also stay in.

static var _list: Array[Node3D] = []


static func register(node: Node3D) -> void:
	if not _list.has(node):
		_list.append(node)


static func unregister(node: Node3D) -> void:
	_list.erase(node)


## Every enemy in the scene. Read-only: do not add to or remove from the returned array. Freed
## instances (one that left without unregistering) are dropped first, so a stale entry can't survive.
static func all() -> Array[Node3D]:
	for i in range(_list.size() - 1, -1, -1):
		var item: Variant = _list[i]
		if not is_instance_valid(item):
			_list.remove_at(i)
	return _list
