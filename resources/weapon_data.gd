class_name WeaponData
extends Resource
## Data for one weapon. Moves are ActionData files, so a new weapon with the same kinds of
## moves is mostly new .tres files. The dash, crouch, slide, and jump attacks are added here in later phases.

@export var display_name: String = "Katana"
## The ground combo, in order. After the last attack the next press goes back to the first.
@export var combo: Array[ActionData] = []
## The charged thrust (hold the attack button at the end of a wind-up). Empty = no thrust.
@export var thrust: ActionData

@export_group("Variants")
## Attack pressed while dashing (a slash that continues into the combo; hold = its Hold Action).
@export var dash_attack: ActionData
## Attack pressed while crouched or sliding: the first of a left/right loop (its Combo Next
## names the second; the second loops back to this one). Hold = its Hold Action, which stands you up.
@export var crouch_attack: ActionData
## Attack pressed while airborne: the first of a loop (its Combo Next names the second; the
## second loops back to this one). No hold variant yet (the helm splitter comes in 3b-4).
@export var air_attack: ActionData

@export_group("Blade")
## Placeholder box blade, in meters.
@export var blade_length: float = 1.1
@export var blade_thickness: float = 0.08

@export_group("Poses")
## Sword at rest, same format as the swing poses in ActionData: (clock hour, radius, forward).
@export var rest_pose: Vector3 = Vector3(5.0, 0.8, 0.0)

@export_group("Sheath")
## The draw slash: attack pressed while the sword is sheathed (in any context) plays this
## instead. It counts as no combo step, so the next tap is attack 1. Empty = no draw slash
## (an attack from the sheathed state just draws the sword and plays as normal).
@export var draw_attack: ActionData
## The dive played when the attack button is held in the air while sheathed (the helm splitter
## with the draw as its opening). Empty = no sheathed helm splitter. The charged iai (hold on the
## ground) is the Hold Action of the draw slash itself.
@export var draw_helm_action: ActionData
## Where the hand grips the sword while it sits in the scabbard, in the player's local space
## (-Z is forward, -X is the left side). The scabbard is built along the blade from here.
@export var sheathed_grip: Vector3 = Vector3(-0.46, 0.95, -0.18)
## Direction the blade points from the grip while sheathed (back and slightly down).
@export var sheathed_blade_direction: Vector3 = Vector3(-0.05, -0.25, 1.0)
## Which way the cutting edge faces while sheathed (up).
@export var sheathed_edge_direction: Vector3 = Vector3(0.0, 1.0, 0.0)
