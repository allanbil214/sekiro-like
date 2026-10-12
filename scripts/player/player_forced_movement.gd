class_name PlayerForcedMovement
extends RefCounted
## The ways the player is moved without asking (Phase 1.5, item 5c), moved out of Player: the knockback
## push (eased out over time), the slide off an enemy's head or the bounce after a jump-over, and the
## personal space that eases the player away from a close enemy. The tuned exports (knockback_time,
## personal_space_*, head_*) stay on the Player; this class reads them. Player.apply_knockback() is the
## public call (its callers are unchanged), and Player._physics_process keeps the order: the push goes on
## the velocity before move_and_slide() and is taken off again after it, so the states never see it.

var player: Player

## The knockback push (m/s, flat) and how fast it dies out (m/s per second).
var velocity: Vector3 = Vector3.ZERO
var decel: float = 0.0


func _init(owner_player: Player) -> void:
	player = owner_player


## Push the player away along `direction` by about `distance` metres, easing out over `time` seconds
## (a heavy hit can ask for a longer one; 0 or less = knockback_time).
func apply_knockback(direction: Vector3, distance: float, time: float = -1.0) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	var duration := time if time > 0.0 else player.knockback_time
	if distance <= 0.0 or duration <= 0.0 or flat.length_squared() < 0.0001:
		return
	velocity = flat.normalized() * (2.0 * distance / duration)
	decel = velocity.length() / duration


## A knockback push is added on top of the state's own velocity for the move (and taken off again by the
## Player after it, using the returned push), so the states never see it. No push during a ledge climb.
func add_push(delta: float) -> Vector3:
	var push := velocity
	if push != Vector3.ZERO and not player.state_machine.current is LedgeClimbState:
		player.velocity.x += push.x
		player.velocity.z += push.z
		velocity = push.move_toward(Vector3.ZERO, decel * delta)
	else:
		push = Vector3.ZERO
		velocity = Vector3.ZERO
	return push


## Standing on an enemy's head: after a jump-over the landing is the counter and bounces you up (a
## helm splitter from there), otherwise you are pushed off sideways. Uses the same easing push as knockback.
func update_enemy_head() -> void:
	for i in player.get_slide_collision_count():
		var collision := player.get_slide_collision(i)
		var body := collision.get_collider() as Node3D
		if body == null or not body.is_in_group(Groups.ENEMY) or collision.get_normal().y < 0.35:
			continue
		if player.global_position.y < body.global_position.y + player.head_min_height:
			continue
		var enemy := body as Enemy
		if enemy != null and player.state_machine.current is AirState and player.velocity.y <= 0.0 \
				and enemy.on_stomped():
			player.velocity.y = player.head_bounce_velocity
			return
		var away := player.global_position - body.global_position
		away.y = 0.0
		if away.length_squared() < 0.0001:
			away = -player.get_facing_direction()
		away.y = 0.0
		velocity = away.normalized() * player.head_slide_speed
		decel = player.head_slide_speed / 0.15
		return


## Personal space: eases the player away from any living enemy (or the dummy) that is closer than
## personal_space_distance on the flat. Skipped when the player is well above or below it (a head stomp
## or bounce), during the deathblow approach, on ledges, and while dead. The push goes through
## move_and_collide, so it never pushes the player through a wall.
func update_personal_space(delta: float) -> void:
	if not player.personal_space_enabled:
		return
	var current := player.state_machine.current
	if current is DeathblowState or current is DeadState or current is LedgeHangState \
			or current is LedgeClimbState:
		return
	var push := Vector3.ZERO
	for node: Node in Enemies.all():
		var other := node as Node3D
		if other == null or other == player:
			continue
		var other_combatant := Combatant.of(other)
		if other_combatant != null and other_combatant.dead:
			continue
		var away := player.global_position - other.global_position
		if absf(away.y) > 1.0:
			continue
		away.y = 0.0
		var distance := away.length()
		if distance >= player.personal_space_distance:
			continue
		if distance < 0.001:
			away = -player.get_facing_direction()
			distance = 0.001
		push += away / distance * (player.personal_space_distance - distance)
	if push == Vector3.ZERO:
		return
	var step := push.limit_length(player.personal_space_push_speed * delta)
	player.move_and_collide(step)
