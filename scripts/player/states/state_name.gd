class_name StateName
extends RefCounted
## The names of the player's states: each value is the name of a node under StateMachine.
## Use these instead of typing the strings, so a typo is a parse error at startup.

const LOCOMOTION: StringName = &"Locomotion"
const AIR: StringName = &"Air"
const DODGE: StringName = &"Dodge"
const DASH: StringName = &"Dash"
const CROUCH: StringName = &"Crouch"
const SLIDE: StringName = &"Slide"
const WALL_JUMP: StringName = &"WallJump"
const LEDGE_CLIMB: StringName = &"LedgeClimb"
const LEDGE_HANG: StringName = &"LedgeHang"
const ATTACK: StringName = &"Attack"
const AIR_ATTACK: StringName = &"AirAttack"
const HELM_SPLITTER: StringName = &"HelmSplitter"
const GUARD: StringName = &"Guard"
const STAGGER: StringName = &"Stagger"
const DEATHBLOW: StringName = &"Deathblow"
const HEAL: StringName = &"Heal"
const DEAD: StringName = &"Dead"
const WALL_HUG: StringName = &"WallHug"
