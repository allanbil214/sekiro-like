class_name HitData
extends RefCounted
## Everything a hit carries from the attacker to the target's Hurtbox and Combatant.
## posture_damage is used from Step 6 (Combatant.add_posture, scaled per outcome).

## What the target's guard made of the hit (set by Combatant.take_hit).
enum Outcome { HIT, GUARD, DEFLECT }

var damage: float = 0.0
var posture_damage: float = 0.0
## Seconds of hitstop requested when the hit connects.
var hitstop: float = 0.0
var attacker: Node
var action: ActionData
## Horizontal direction from the attacker to the target (for recoil, later knockback).
var direction: Vector3 = Vector3.FORWARD
## Copied from the attacker's action: can a guard block it, can a deflect turn it away.
## A grab (Step 7) sets both to false.
var guardable: bool = true
var deflectable: bool = true
## How far (m) the hit pushes the target back, before the target's own multipliers.
var knockback: float = 0.0
## Filled in by the target's Combatant: an Outcome value.
var outcome: int = Outcome.HIT
## Where it connected (the middle of the hitbox), for sparks and sounds later.
var point: Vector3 = Vector3.ZERO


func copy() -> HitData:
	var other := HitData.new()
	other.damage = damage
	other.posture_damage = posture_damage
	other.hitstop = hitstop
	other.attacker = attacker
	other.action = action
	other.guardable = guardable
	other.deflectable = deflectable
	other.knockback = knockback
	other.outcome = outcome
	other.direction = direction
	other.point = point
	return other
