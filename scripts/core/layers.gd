class_name Layers
extends RefCounted
## The 3D physics layers used by combat, and which team's hitboxes can touch which hurtboxes.
## Name them in Project Settings > Layer Names > 3D Physics (layers 1 to 5, same order) so the
## Inspector shows the names. The scripts set their own layers, so naming them is optional.

enum Team { PLAYER, ENEMY }

## Layer bit values (layer 1 = 1, layer 2 = 2, layer 3 = 4, layer 4 = 8, layer 5 = 16).
const WORLD: int = 1
const PLAYER_HURTBOX: int = 2
const ENEMY_HURTBOX: int = 4
const PLAYER_HITBOX: int = 8
const ENEMY_HITBOX: int = 16
## Invisible walls (layer 6, Phase 2 item 3c): a solid for the Player and the Enemy bodies only. The
## camera's spring arm and the ledge and wall sensing do not see it. Tick layer 6 in the mask of the
## Player and Enemy root nodes.
const INVISIBLE_WALL: int = 32
## Smooth ramps (layer 7, Phase 3d-2): the invisible ramp a body walks on over visible stairs. A solid for the Player and
## Enemy bodies only (tick layer 7 in their masks); the camera, the sensors and the foot rays do not see it.
const SMOOTH_RAMP: int = 64
## Foot surfaces (layer 8, Phase 3d-2): the detailed visible surface (the real steps) that only the figure's foot rays read.
## No body collides with it (a CSG or static body on layer 8 with mask 0).
const FOOT_SURFACE: int = 128


static func hurtbox_layer(team: Team) -> int:
	return PLAYER_HURTBOX if team == Team.PLAYER else ENEMY_HURTBOX


static func hitbox_layer(team: Team) -> int:
	return PLAYER_HITBOX if team == Team.PLAYER else ENEMY_HITBOX


static func opposing(team: Team) -> Team:
	return Team.ENEMY if team == Team.PLAYER else Team.PLAYER
