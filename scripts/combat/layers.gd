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


static func hurtbox_layer(team: Team) -> int:
	return PLAYER_HURTBOX if team == Team.PLAYER else ENEMY_HURTBOX


static func hitbox_layer(team: Team) -> int:
	return PLAYER_HITBOX if team == Team.PLAYER else ENEMY_HITBOX


static func opposing(team: Team) -> Team:
	return Team.ENEMY if team == Team.PLAYER else Team.PLAYER
