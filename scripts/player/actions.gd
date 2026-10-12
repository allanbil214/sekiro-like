class_name Actions
extends RefCounted
## The Input Map action names (Project > Project Settings > Input Map). Use these constants instead of
## typing the strings: a typo in a constant is an error when the script loads, while a typo in a string
## fails silently in places like `InputBuffer.has_pressed()` (the button just never counts). The values
## must match the Input Map names exactly. Built-in Godot actions (`ui_cancel`) stay as they are.

const ATTACK: StringName = &"attack"
const JUMP: StringName = &"jump"
const DODGE: StringName = &"dodge"
const GUARD: StringName = &"guard"
const HEAL: StringName = &"heal"
const CROUCH: StringName = &"crouch"
const INTERACT: StringName = &"interact"
const SHEATHE: StringName = &"sheathe"
const LOCK_ON: StringName = &"lock_on"
const MOVE_LEFT: StringName = &"move_left"
const MOVE_RIGHT: StringName = &"move_right"
const MOVE_FORWARD: StringName = &"move_forward"
const MOVE_BACK: StringName = &"move_back"
const LOOK_LEFT: StringName = &"look_left"
const LOOK_RIGHT: StringName = &"look_right"
const LOOK_UP: StringName = &"look_up"
const LOOK_DOWN: StringName = &"look_down"
const PAUSE: StringName = &"pause"
