class_name SceneLoader
extends RefCounted
## Changes scenes in one of two ways (Phase 2, item 5). Static, no autoload.
## BLACK is the plain change: the caller fades to black first, then this changes the scene at once.
## PROPER goes through the loading screen: the target path is stored here, the loading scene is opened,
## and that scene loads the target on a thread, shows tips and a bar, and switches when it is ready.

enum Kind { PROPER, BLACK }

const LOADING_SCENE: String = "res://scenes/ui/loading_screen.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"

## The scene the loading screen should load (set by `go()`, read once by `take_target()`).
static var _target_path: String = ""


## Change to the scene at `path`. Returns the error of the scene change (OK on success), so the caller
## keeps its own error handling. The caller fades to black before calling this.
static func go(tree: SceneTree, path: String, kind: Kind) -> Error:
	if kind == Kind.BLACK:
		return tree.change_scene_to_file(path)
	_target_path = path
	return tree.change_scene_to_file(LOADING_SCENE)


## The loading screen asks for its target here (and clears it).
static func take_target() -> String:
	var path := _target_path
	_target_path = ""
	return path
