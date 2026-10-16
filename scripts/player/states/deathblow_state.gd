class_name DeathblowState
extends ActionState
## The deathblow (Step 6): started by Player._try_deathblow() (a fresh attack press near an enemy
## whose deathblow window is open, in front of you). A short scripted slash with no hitbox: the
## player steps toward the target (stopping stop_distance short), and halfway through the hit window
## the target's Combatant.execute_deathblow() is called. Guard cannot cancel it before then.
## The sword looks like a thrust (actions/deathblow_thrust.tres, visual only) when drawn, and like the
## iai draw slash (the weapon's draw attack poses) while sheathed. Timing always comes from `action`.
## The action defaults to res://actions/deathblow.tres if none is set in the Inspector.

const DEFAULT_ACTION: ActionData = preload("res://actions/deathblow.tres")
## The choke (Phase 2 item 10): the stealth kill with the blade reversed. A longer action: the target is pulled
## in front of the player and held (arms squeezing, the target struggling and then limp), then knocked out.
const CHOKE_ACTION: ActionData = preload("res://actions/choke.tres")
const THRUST_VISUAL: ActionData = preload("res://actions/deathblow_thrust.tres")
## The helm splitter's dive pose, drawn during a death from above (item 7c).
const HELM_VISUAL: ActionData = preload("res://actions/helm_splitter.tres")

## The player stops this close (m, flat) to the target's center.
@export var stop_distance: float = 1.1
## The thrust sound starts this long (s) before the strike.
@export var swing_sound_lead: float = 0.1
## Death from above (item 7c): the plunge speed (m/s) toward the target, the flat and height (m above its feet)
## at which it counts as contact, the base time (s) the plunge may take before it is given up (the trip itself is added), and how close
## (m, flat) a landing on the floor still counts as a hit.
@export var plunge_speed: float = 18.0
@export var plunge_contact_flat: float = 1.4
@export var plunge_contact_height: float = 2.2
@export var plunge_timeout: float = 1.2
@export var plunge_land_flat: float = 2.5
## Stealth kill from the wall hug (item 9): the target glides to `hug_pull_distance` (m) in front of the
## player over `hug_pull_time` (s) before the thrust, so it reads as a grab and stab.
@export var hug_pull_time: float = 0.15
@export var hug_pull_distance: float = 0.9
## Hitstop (s) when the deathblow lands.
@export var landing_hitstop: float = 0.15
## The player is invulnerable for the whole deathblow (the `iframes` window of its ActionData), and for
## this many more seconds after it, but only if the deathblow actually landed (0 = none).
@export var invulnerable_after: float = 1.0

var _target: Node3D
var _executed: bool = false
var _swing_played: bool = false
var _landed: bool = false
var _visual_action: ActionData
var _stealth: bool = false
## Death from above (item 7c): the plunge onto the target runs first; the action clock waits at 0 meanwhile.
var _aerial: bool = false
var _plunging: bool = false
var _plunge_time: float = 0.0
var _plunge_limit: float = 1.2
var _visual_clock: float = 0.0
## Item 10: this run is a choke, and the action the node was given (the choke swaps `action` while it runs).
var _choke: bool = false
var _default_action: ActionData
## The wall hug pull (item 9).
var _pull: bool = false
var _pull_time: float = 0.0
var _pull_from: Vector3 = Vector3.ZERO


func _ready() -> void:
	if action == null:
		action = DEFAULT_ACTION
	_default_action = action


func enter(previous: StringName) -> void:
	action = CHOKE_ACTION if _wants_choke() else _default_action
	super(previous)


## A ground stealth kill with the blade reversed on an enemy is a choke.
func _wants_choke() -> bool:
	return player.blade_reversed and player.deathblow_stealth and not player.deathblow_aerial \
			and player.deathblow_target is Enemy


func _slows_active_window() -> bool:
	return false


func _on_action_enter(_previous: StringName) -> void:
	_executed = false
	_landed = false
	_swing_played = false
	if Sfx.deathblow_open_enabled():
		Sfx.play(player.get_tree(), Sfx.Id.DEATHBLOW_OPEN)
	_target = player.deathblow_target
	_stealth = player.deathblow_stealth
	_aerial = player.deathblow_aerial
	_plunging = _aerial
	_plunge_time = 0.0
	_plunge_limit = plunge_timeout
	if _aerial and is_instance_valid(_target):
		# A long drop needs longer than the base time: add the trip at the capped dive speed.
		_plunge_limit += (_target.global_position - player.global_position).length() \
			/ maxf(minf(plunge_speed, player.hard_land_speed - 1.0), 1.0)
	_visual_clock = 0.0
	_choke = action == CHOKE_ACTION
	_visual_action = THRUST_VISUAL
	if player.sheathed and player.weapon != null and player.weapon.draw_attack != null:
		_visual_action = player.weapon.draw_attack
	if _aerial:
		_visual_action = HELM_VISUAL
		if player.sheathed and player.weapon != null and player.weapon.draw_helm_action != null:
			_visual_action = player.weapon.draw_helm_action
	if player.sword_visual != null and not _choke:
		player.sword_visual.begin_action(_visual_action)
	if _choke:
		# No swing sound, the arms reach out, and the target is held.
		_swing_played = true
		player.play_choke_arms()
		(_target as Enemy).set_held(true)
	if _target != null:
		var to_target := _target.global_position - player.global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.0001:
			_move_dir = to_target.normalized()
			player.snap_facing(_move_dir)
		if _aerial:
			_move_dir = Vector3.ZERO
	_pull = (player.deathblow_from_hug or _choke) and _stealth and not _aerial and is_instance_valid(_target)
	_pull_time = 0.0
	if _pull:
		_pull_from = _target.global_position
		_move_dir = Vector3.ZERO


func _on_action_exit() -> void:
	var held_target := _target as Enemy
	_target = null
	if _landed:
		player.grant_invulnerability(invulnerable_after)
	if _aerial and player.is_on_floor():
		player.reset_air_actions()
	_aerial = false
	_plunging = false
	_pull = false
	if _choke:
		_choke = false
		player.release_arms()
		if held_target != null and is_instance_valid(held_target):
			held_target.set_held(false)
	if player.sword_visual != null:
		player.sword_visual.end_combo()


func _apply_action_movement(delta: float) -> void:
	if _plunging:
		return
	super(delta)


func _visual_time() -> float:
	return _visual_clock if _aerial else action_time


## The plunge (item 7c): fly at the target, hold the action clock at 0, invulnerable. Contact strikes at once.
func _update_plunge(delta: float) -> void:
	action_time = 0.0
	player.invulnerable = true
	_plunge_time += delta
	var combatant: Combatant = null
	if is_instance_valid(_target):
		combatant = Combatant.of(_target)
	if combatant == null or combatant.dead:
		_abort_plunge()
		return
	var to_target := _target.global_position - player.global_position
	var flat := Vector2(to_target.x, to_target.z).length()
	if flat > 0.01:
		player.snap_facing(Vector3(to_target.x, 0.0, to_target.z).normalized())
	if flat <= plunge_contact_flat and -to_target.y <= plunge_contact_height:
		_aerial_contact()
		return
	if player.is_on_floor():
		if flat <= plunge_land_flat:
			_aerial_contact()
		else:
			_abort_plunge()
		return
	if _plunge_time >= _plunge_limit:
		_abort_plunge()
		return
	var dive_velocity := (to_target + Vector3.UP * 0.3).normalized() * plunge_speed
	# Never fast enough to count as a hard landing (a loud spike) if it meets the floor first.
	dive_velocity.y = maxf(dive_velocity.y, -(player.hard_land_speed - 1.0))
	player.velocity = dive_velocity
	if player.sword_visual != null:
		player.sword_visual.update_action(_visual_action, _visual_clock)


## The wall hug pull (item 9): the target glides to the front of the player before the strike.
func _update_pull(delta: float) -> void:
	if not is_instance_valid(_target):
		_pull = false
		return
	_pull_time += delta
	var to_target := _pull_from - player.global_position
	to_target.y = 0.0
	var direction := to_target.normalized() if to_target.length_squared() > 0.0001 else player.get_facing_direction()
	var goal := player.global_position + direction * hug_pull_distance
	goal.y = _pull_from.y
	var u := smoothstep(0.0, 1.0, clampf(_pull_time / maxf(hug_pull_time, 0.001), 0.0, 1.0))
	_target.global_position = _pull_from.lerp(goal, u)
	var body := _target as CharacterBody3D
	if body != null:
		body.velocity = Vector3.ZERO
	if u >= 1.0 and not _choke:
		_pull = false


func _abort_plunge() -> void:
	_plunging = false
	machine.transition_to(StateName.LOCOMOTION if player.is_on_floor() else StateName.AIR)


## The plunge reached the target: a small dust, the thrust sound, the stealth kill, then the follow-through.
func _aerial_contact() -> void:
	_plunging = false
	_move_dir = Vector3.ZERO
	player.velocity = Vector3(0.0, -2.0, 0.0)
	_swing_played = true
	Sfx.play(player.get_tree(), Sfx.Id.THRUST)
	Fx.play(player.get_tree(), Fx.Kind.LAND_DUST, player.global_position)
	_strike()
	action_time = maxf(action_time, action.active_hit.y)


func _on_action_update(delta: float) -> void:
	if _aerial and _visual_action != null:
		_visual_clock = minf(_visual_clock + delta, _visual_action.active_hit.y - 0.002)
	if _plunging:
		_update_plunge(delta)
		return
	if _pull:
		_update_pull(delta)
	if _choke and is_instance_valid(_target):
		var strike := action.active_hit.x + (action.active_hit.y - action.active_hit.x) * 0.5
		(_target as Enemy).set_held_amount(action_time / maxf(strike, 0.001))
	if _target != null and is_instance_valid(_target) and _move_dir != Vector3.ZERO:
		var to_target := _target.global_position - player.global_position
		to_target.y = 0.0
		if to_target.length() <= stop_distance:
			_move_dir = Vector3.ZERO
	if player.sword_visual != null and not _choke:
		player.sword_visual.update_action(_visual_action, _visual_time())
	if not _swing_played and action_time >= maxf(action.active_hit.x - swing_sound_lead, 0.0):
		_swing_played = true
		Sfx.play(player.get_tree(), Sfx.Id.THRUST)
	var strike_time := action.active_hit.x + (action.active_hit.y - action.active_hit.x) * 0.5
	if not _executed and action_time >= strike_time:
		_strike()
		return
	if _executed and action.can_cancel(action_time):
		if player.input_buffer.consume(Actions.DODGE):
			machine.transition_to(StateName.DODGE)


## The blow itself: the target's Combatant takes the deathblow (or the stealth kill).
func _strike() -> void:
	_executed = true
	var combatant: Combatant = null
	if is_instance_valid(_target):
		combatant = Combatant.of(_target)
	var landed := false
	if _choke and is_instance_valid(_target):
		(_target as Enemy).set_held(false)
	if combatant != null:
		var lethal := not player.blade_reversed
		landed = combatant.execute_stealth_kill(lethal) if _stealth else combatant.execute_deathblow(lethal)
	if landed:
		_landed = true
		Hitstop.request(player.get_tree(), landing_hitstop)
		player.notify_combat()


func _allows_guard_cancel() -> bool:
	return _executed and not _plunging
