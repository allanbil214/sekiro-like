class_name Fx
extends RefCounted
## One call per game event (Step 11): Fx.play(tree, kind, point, direction). Today it adds camera shake
## (11c); the sparks and effects (11b) and, later, the sound (11a) hang on the same call, so each event
## has a single call site. `point` is where it happened (HitData.point) and `direction` is the
## horizontal direction of the blow (HitData.direction, attacker to target), both optional.
## The shake finds the camera through the group "camera_rig" (CameraRig.add_trauma).

enum Kind {
	HIT_LANDED, HIT_LANDED_CHARGED, DEFLECT, GUARD, HURT, PERILOUS_HIT, GRAB, POSTURE_BREAK,
	MIKIRI, HEAD_STOMP, HELM_LAND, DEATHBLOW, BOSS_SLAIN, HARD_LAND,
}

## Camera trauma added per event (0 to 1). Placeholders: tune in play. A perilous hit through the
## guard (guard break) uses PERILOUS_HIT.
const TRAUMA: Dictionary = {
	Kind.HIT_LANDED: 0.15,
	Kind.HIT_LANDED_CHARGED: 0.3,
	Kind.DEFLECT: 0.2,
	Kind.GUARD: 0.25,
	Kind.HURT: 0.35,
	Kind.PERILOUS_HIT: 0.5,
	Kind.GRAB: 0.6,
	Kind.POSTURE_BREAK: 0.4,
	Kind.MIKIRI: 0.3,
	Kind.HEAD_STOMP: 0.3,
	Kind.HELM_LAND: 0.5,
	Kind.DEATHBLOW: 0.7,
	Kind.BOSS_SLAIN: 0.8,
	Kind.HARD_LAND: 0.2,
}


static func play(tree: SceneTree, kind: Kind, _point: Vector3 = Vector3.ZERO, direction: Vector3 = Vector3.ZERO) -> void:
	if tree == null:
		return
	var trauma: float = TRAUMA.get(kind, 0.0)
	if trauma > 0.0:
		tree.call_group("camera_rig", "add_trauma", trauma, direction)
