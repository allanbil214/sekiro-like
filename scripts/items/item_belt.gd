class_name ItemBelt
extends RefCounted
## The items the player carries (Phase 2 item 11): the list, which one is selected, and how many of each are left.
## In memory only: a new Player (the scene reload after a death) starts with the full counts again; saving and
## pickups come with Phase 4. The gourd is not here: it keeps its own button (`heal`). `Player` makes the belt
## in `_ready()` from its `starting_items`; `ItemHud` reads it.

var items: Array[ItemData] = []
var selected_index: int = 0

var _counts: Array[int] = []


func _init(starting: Array[ItemData]) -> void:
	for item: ItemData in starting:
		if item == null:
			continue
		items.append(item)
		_counts.append(maxi(item.start_count, 0))


func is_empty() -> bool:
	return items.is_empty()


## The selected item, or null when the belt is empty.
func selected() -> ItemData:
	if items.is_empty():
		return null
	return items[selected_index]


func selected_count() -> int:
	if items.is_empty():
		return 0
	return _counts[selected_index]


func count_of(item: ItemData) -> int:
	var index := items.find(item)
	return _counts[index] if index >= 0 else 0


## Select the next item (wraps around). Returns false when there is nothing to change to.
func cycle(step: int = 1) -> bool:
	if items.size() < 2:
		return false
	selected_index = posmod(selected_index + step, items.size())
	return true


## Use up `amount` of `item`. Returns false (and spends nothing) when there are not enough.
func spend(item: ItemData, amount: int = 1) -> bool:
	var index := items.find(item)
	if index < 0 or _counts[index] < amount:
		return false
	_counts[index] -= amount
	return true
