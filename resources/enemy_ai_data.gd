class_name EnemyAIData
extends Resource
## Tunable numbers for one enemy's behavior (Step 7). The enemy's attacks themselves are
## ActionData files taken from its WeaponData (the same combo the player uses); this resource says
## how it moves, how far it stays, how long its bursts are, and how hard its hits land.
## All times in seconds. Everything here is a placeholder to tune in play.

@export_group("Awareness and movement")
## It notices the player inside this distance (m) and gives up beyond 1.5x of it.
@export var aggro_range: float = 14.0
@export var run_speed: float = 5.0
## Speed of the sideways circling while it yields.
@export var strafe_speed: float = 2.0
@export var acceleration: float = 25.0
## How fast (rad/s, eased) it turns toward the player.
@export var turn_speed: float = 8.0
## Turn speed during an attack's wind-up (it locks when the hit window opens).
@export var attack_turn_speed: float = 4.0

@export_group("Spacing")
## It starts an attack burst once the player is this close (m, center to center).
@export var engage_distance: float = 2.4
## While yielding it circles about this far from the player.
@export var preferred_distance: float = 2.6
## A lunge stops this close (m) so it never walks into the player.
@export var lunge_min_distance: float = 1.3
## Share of the attack's move speed it uses for its lunge (the player's no-input lunge is 0.5).
@export var lunge_factor: float = 0.7
## Random time (s) between changes of strafe side.
@export var strafe_switch_time: Vector2 = Vector2(0.6, 1.4)

@export_group("Attack bursts")
## How many combo attacks in a row (random, inclusive). Capped by the weapon's combo length.
@export var attack_burst_count: Vector2i = Vector2i(2, 4)
## Random extra wait (s) after the earliest chain point before the next attack of a burst starts.
@export var chain_delay: Vector2 = Vector2(0.0, 0.1)
## Standing still after a burst ends (the player's opening).
@export var recovery_time: float = 0.6
## How long it yields (circles and defends) between bursts, random in this range (s).
## The range is scaled by lerp(1.5, 0.5, aggression): 0 = 1.5x longer, 1 = 0.5x as long.
@export var yield_time: Vector2 = Vector2(1.0, 2.5)
@export_range(0.0, 1.0) var aggression: float = 0.6
## Multiplies the weapon attacks' damage and posture damage (the player's numbers are small).
@export var damage_scale: float = 2.0
@export var posture_scale: float = 1.5

@export_group("Defense (used from Step 7b; not read yet)")
## Random delay (s) before it reacts to a threat.
@export var reaction_delay: Vector2 = Vector2(0.1, 0.3)
@export_range(0.0, 1.0) var guard_chance: float = 0.5
@export_range(0.0, 1.0) var deflect_chance: float = 0.3
## Added to the guard chance each time the player repeats the same attack.
@export var repeat_attack_guard_bonus: float = 0.1
## Posture (0 to 1) above which it may take the recovery pose.
@export_range(0.0, 1.0) var posture_pose_threshold: float = 0.6
