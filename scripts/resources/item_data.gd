class_name ItemData
extends Resource
## One kind of item the player can carry and use (Phase 2 item 11, the item system). The base class: a name,
## a placeholder icon (a shape and a color, drawn in code by `ItemHud` and on the flying projectile), and the
## count at the start. What the item DOES is in the subclass (`ThrowableData` for the throwables); later items
## (onigiri, marking rice, ...) extend this the same way and add a kind. The counts are not stored here: a
## resource is shared, so the live counts live in `ItemBelt` (in memory for now; saving is Phase 3).

enum Kind { OTHER, THROWABLE }
## The placeholder icon shapes (until real art exists).
enum Shape { ROUND, STAR, DART, SHARD }

@export var display_name: String = "Item"
@export var shape: Shape = Shape.ROUND
@export var icon_color: Color = Color(0.6, 0.6, 0.6)
## How many the player carries at the start (placeholder).
@export var start_count: int = 10


## What kind of item this is; `Player._try_use_item()` picks the state by it. Subclasses override.
func get_kind() -> Kind:
	return Kind.OTHER
