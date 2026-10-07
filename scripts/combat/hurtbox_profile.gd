class_name HurtboxProfile
extends Resource
## The shape of a character's hurtbox in one posture: how tall it is and how far its bottom is above
## the feet. Standing 1.8 / 0, crouching 1.1 / 0 (shrinks from the top), airborne 1.1 / 0.7 (shrinks
## from the bottom: the legs tuck, the top stays at 1.8). A low sweep passes under the air profile;
## a high attack passes over the crouch profile.

@export var height: float = 1.8
## Distance from the feet to the bottom of the hurtbox.
@export var bottom_offset: float = 0.0
