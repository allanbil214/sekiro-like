class_name WeaponData
extends Resource
## Data for one weapon. Moves are ActionData files, so a new weapon with the same kinds of
## moves is mostly new .tres files. The dash, crouch, slide, and jump attacks are added here in later phases.

@export var display_name: String = "Katana"
## The ground combo, in order. After the last attack the next press goes back to the first.
@export var combo: Array[ActionData] = []
## The charged thrust (hold the attack button at the end of a wind-up). Empty = no thrust.
@export var thrust: ActionData

@export_group("Blade")
## Placeholder box blade, in meters.
@export var blade_length: float = 1.1
@export var blade_thickness: float = 0.08

@export_group("Poses")
## Sword at rest, same format as the swing poses in ActionData: (clock hour, radius, forward).
@export var rest_pose: Vector3 = Vector3(5.0, 0.8, 0.0)
