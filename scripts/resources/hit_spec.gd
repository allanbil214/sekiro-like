class_name HitSpec
extends Resource
## One hit of a multi-hit action (Phase 3b-4): its own window and numbers. A value of -1 means "use the action's own
## value" (`ActionData.damage` and so on), so a hit lists only what differs. See `ActionData.hits`.

## Seconds from the start of the action in which this hit's hitbox is open. Must lie inside `ActionData.active_hit`.
@export var window: Vector2 = Vector2.ZERO
## Health damage of this hit. -1 = the action's `damage`.
@export var damage: float = -1.0
## Posture damage of this hit. -1 = the action's `posture_damage`.
@export var posture_damage: float = -1.0
## Push-back (m) of this hit. -1 = the action's `knockback`.
@export var knockback: float = -1.0
## Hitstop (s) when this hit connects. -1 = the action's `hitstop`.
@export var hitstop: float = -1.0
