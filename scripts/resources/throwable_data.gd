class_name ThrowableData
extends ItemData
## One kind of thrown ammo (Phase 2 item 11a): a rock, a shuriken, a kunai, a piece of broken ceramic.
## Edit the `.tres` files under `data/items/` in the Inspector; every number here is a placeholder to tune by playing.
## Defaults: small damage and a short stun (posture damage), not a killing tool, so close-range stealth stays
## the focus. A lethal throwable can kill; a non-lethal one knocks out at zero health (like the reversed blade).

@export_group("Hit")
@export var damage: float = 4.0
## The stun: posture damage (the target scales it like any hit).
@export var posture_damage: float = 12.0
@export var lethal: bool = false

@export_group("Flight")
## Launch speed (m/s).
@export var speed: float = 16.0
## Its own gravity (m/s^2). 0 = flies straight (shuriken, kunai).
@export var gravity: float = 14.0
## Elevation of an unlocked throw above the flat aim direction (degrees). Ignored when locked on: the throw
## then solves the arc to the target's chest.
@export var launch_angle_degrees: float = 8.0

@export_group("Noise")
## How far (m) the landing is heard by enemies with awareness (less through a wall).
@export var noise: float = 12.0


func get_kind() -> Kind:
	return Kind.THROWABLE


## The launch velocity for an unlocked throw: along `aim_flat`, raised by `launch_angle_degrees`.
func velocity_forward(aim_flat: Vector3) -> Vector3:
	var flat := Vector3(aim_flat.x, 0.0, aim_flat.z).normalized()
	var angle := deg_to_rad(launch_angle_degrees)
	return flat * speed * cos(angle) + Vector3.UP * speed * sin(angle)


## The launch velocity that lands on `target` (the lower arc). A straight flyer goes straight at it; a target
## out of range gets the 45 degree throw, the farthest one.
func velocity_to(origin: Vector3, target: Vector3) -> Vector3:
	var to := target - origin
	if gravity <= 0.0:
		return to.normalized() * speed
	var flat := Vector3(to.x, 0.0, to.z)
	var distance := flat.length()
	if distance < 0.01:
		return velocity_forward(Vector3.FORWARD)
	var speed_squared := speed * speed
	var discriminant := speed_squared * speed_squared - gravity * (gravity * distance * distance + 2.0 * to.y * speed_squared)
	var angle := deg_to_rad(45.0)
	if discriminant >= 0.0:
		angle = atan((speed_squared - sqrt(discriminant)) / (gravity * distance))
	return flat.normalized() * speed * cos(angle) + Vector3.UP * speed * sin(angle)
