class_name HitData
extends RefCounted
## Everything a hit carries from the attacker to the target's Hurtbox and Combatant.
## posture_damage is carried now and used from Step 6.

var damage: float = 0.0
var posture_damage: float = 0.0
## Seconds of hitstop requested when the hit connects.
var hitstop: float = 0.0
var attacker: Node
var action: ActionData
## Horizontal direction from the attacker to the target (for recoil, later knockback).
var direction: Vector3 = Vector3.FORWARD
## Where it connected (the middle of the hitbox), for sparks and sounds later.
var point: Vector3 = Vector3.ZERO


func copy() -> HitData:
	var other := HitData.new()
	other.damage = damage
	other.posture_damage = posture_damage
	other.hitstop = hitstop
	other.attacker = attacker
	other.action = action
	other.direction = direction
	other.point = point
	return other
