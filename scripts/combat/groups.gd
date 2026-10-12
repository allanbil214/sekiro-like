class_name Groups
extends RefCounted
## The scene-tree group names the game uses. Use these constants instead of typing the strings:
## a typo in a constant is an error when the script loads, a typo in a string finds nothing and
## fails silently. (Same idea as `StateName` and `Layers`.)

## The player (`Player`); the enemies look it up with `get_first_node_in_group`.
const PLAYER: StringName = &"player"
## Every enemy and the dummy (`Enemy`, `Dummy`).
const ENEMY: StringName = &"enemy"
## The perilous-attack warning symbol under the Player (`DangerSymbol`).
const DANGER_SYMBOL: StringName = &"danger_symbol"
## The camera rig, called for camera shake (`CameraRig.add_trauma`).
const CAMERA_RIG: StringName = &"camera_rig"
## The boss-slain screen (`VictoryScreen.show_victory`).
const VICTORY_SCREEN: StringName = &"victory_screen"
