class_name ArenaData
extends Resource
## One arena the chooser can list (Phase 2, item 3b). A new arena is one new `.tres` of this type in
## `res://data/arenas/`; `ArenaLibrary` finds it, no code changes. The scene is a path (not a PackedScene)
## so listing the arenas does not load every one of them.

enum Category { TEST, MOVEMENT, FIGHTING, STEALTH }

## The name shown in the chooser.
@export var display_name: String = "Arena"
## The scene to load, picked with the file dialog.
@export_file("*.tscn") var scene_path: String = ""
## An optional picture (16:9 looks best). A plain "NO IMAGE" placeholder shows when it is empty.
@export var image: Texture2D
@export_multiline var description: String = ""
## The section the arena is listed under.
@export var category: Category = Category.TEST
## A debug build lists every arena; a release build lists only the ones with this off.
@export var debug_only: bool = false
## Order inside the section (lower first); equal values sort by name.
@export var sort_order: int = 0


## The section heading for a category.
static func category_label(value: Category) -> String:
	match value:
		Category.TEST:
			return "TEST"
		Category.MOVEMENT:
			return "MOVEMENT"
		Category.FIGHTING:
			return "FIGHTING"
		Category.STEALTH:
			return "STEALTH"
	return ""
