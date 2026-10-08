class_name EnemyAIData
extends Resource
## Tunable numbers for one enemy's behavior (Step 7). The enemy's attacks themselves are
## ActionData files taken from its WeaponData (the same combo the player uses); this resource says
## how it moves, how far it stays, how long its bursts are, how hard its hits land, and how it
## defends. Different enemy types are different copies of this resource (see the ai/ presets).
## All times in seconds. Everything here is a placeholder to tune in play.

@export_group("Awareness and movement")
## It notices the player inside this distance (m) and gives up beyond 1.5x of it.
@export var aggro_range: float = 14.0
@export var run_speed: float = 5.0
## Speed of the sideways circling while it yields (and of any movement while it guards).
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

@export_group("Attack tempo (combo attacks)")
## Speed of the attack clock before the hit window opens (1 = the action's own timing). Lower =
## a longer wind-up, so each hit in a combo gives more warning.
@export_range(0.2, 1.5, 0.05) var windup_speed: float = 0.65
## Speed of the attack clock inside the hit window. Lower = a slower, more readable slash.
@export_range(0.2, 1.5, 0.05) var active_speed: float = 0.7

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

@export_group("Defense: reaction (Step 7b)")
## It sees a threat when the player is this close (m) and inside an attack (before its hit window ends).
@export var threat_range: float = 3.5
## Random delay (s) between a threat appearing and a plain guard coming up (a planned deflect and a
## guard while pressured ignore it). The main difficulty knob for plain guards.
@export var reaction_delay: Vector2 = Vector2(0.1, 0.3)
## It keeps its guard up this long (s) after the threat ends.
@export var guard_hold_time: float = 0.3
## Chance a repeated player attack (the same attack twice or more in a row) adds to the guard chance.
@export var repeat_attack_guard_bonus: float = 0.1
## After it takes this many unguarded hits in a row, its next threat is always guarded (whether it
## deflects is still rolled). The streak resets when a guard or deflect happens, or after 3 s without
## a hit. 0 = off.
@export var hit_streak_limit: int = 2

@export_group("Defense: neutral (it has not been hit lately)")
## Chance it guards a threat at all, and (if it guards) that the guard is a timed deflect. So the
## chance of taking the hit is 1 - guard, and of deflecting is guard x deflect.
@export_range(0.0, 1.0) var neutral_guard_chance: float = 0.6
@export_range(0.0, 1.0) var neutral_deflect_chance: float = 0.3

@export_group("Defense: pressured (hit within retry_window)")
## After a hit that landed it can retry: these replace the neutral chances for retry_window seconds,
## and its reaction delay is skipped (the guard comes up at once).
@export var retry_window: float = 1.0
@export_range(0.0, 1.0) var pressured_guard_chance: float = 0.5
@export_range(0.0, 1.0) var pressured_deflect_chance: float = 0.4

@export_group("Deflect kind")
## Share of its deflects that are repulses (the attacker bounces back and its combo resets).
## 0 = it only deflects normally.
@export_range(0.0, 1.0) var repulse_chance: float = 0.0

@export_group("Flinch (only unguarded hits that land)")
## How long (s) a flinch lasts: it cannot act or guard.
@export var hit_stun_time: float = 0.35
## After a flinch ends, a landed hit cannot flinch it again for this long (s): it still takes the
## damage, but it gets time to act (retry a guard, attack). 0 = no immunity (stunlock possible).
@export var flinch_immunity_time: float = 0.6
## Which of its moments a landed hit flinches it in. A hit during its own hit window never flinches.
@export var flinch_in_windup: bool = true
## After its hit window ends, and while recovering from a burst.
@export var flinch_in_recovery: bool = true
## While chasing, circling, or idle (and when a guard failed).
@export var flinch_in_neutral: bool = true

@export_group("Riposte")
## Chance it counterattacks after it deflects a hit, the delay (s), and the burst length.
@export_range(0.0, 1.0) var riposte_chance: float = 0.7
@export var riposte_delay: float = 0.15
@export var riposte_burst_count: Vector2i = Vector2i(1, 2)

@export_group("Pressure (taking the initiative back)")
## While it ripostes (from the deflect to the end of the riposte burst) a landed hit cannot flinch it:
## your hits still do damage and posture, but they do not stop its swing.
@export var riposte_armor: bool = false
## After it has guarded or deflected this many of your hits in a row, its next defense is a forced
## deflect with a guaranteed riposte. 0 = off. The streak resets when a hit lands on it, when it
## attacks, or after 3 s without a guarded hit.
@export var pressure_break_hits: int = 0
## Chance the number is lower this time (a random 1 to hits - 1), so it is not always the same.
@export_range(0.0, 1.0) var pressure_break_early_chance: float = 0.3

@export_group("Recovery pose")
@export var pose_enabled: bool = true
## Posture (0 to 1 of the maximum) from which it may take the pose.
@export_range(0.0, 1.0) var posture_pose_threshold: float = 0.6
## The player must not have attacked for this long (s): it is not under pressure.
@export var pose_idle_time: float = 1.5
## Posture regen multiplier while posing.
@export var pose_regen_factor: float = 3.0
## It ends the pose at this posture (0 to 1 of the maximum), or after pose_max_time (s).
@export_range(0.0, 1.0) var pose_end_posture: float = 0.1
@export var pose_max_time: float = 3.0
## Wait (s) before it may pose again.
@export var pose_cooldown: float = 3.0

@export_group("Look (optional, per enemy type)")
## Multiplies the weapon's blade length and thickness for this enemy only (the weapon file is not
## changed). The hitbox grows with the blade, so a longer blade really reaches farther.
@export var blade_length_scale: float = 1.0
@export var blade_thickness_scale: float = 1.0
## Extra length (m) behind the hand, like the handle end of a spear. It has a visible shaft and
## its hitbox is part of the weapon's damage box (it can hit too). 0 = none.
@export var blade_back_length: float = 0.0
## Blade color. Alpha 0 = keep the default color.
@export var blade_color: Color = Color(0.0, 0.0, 0.0, 0.0)

@export_group("Perilous attacks (Step 7c)")
## Which perilous attacks this enemy has. The thrust is the weapon's charged thrust (orange glow).
@export var perilous_thrust: bool = false
## The sweep needs `sweep_action` (actions/enemy_sweep.tres).
@export var perilous_sweep: bool = false
@export var sweep_action: ActionData
## Chance it starts a perilous attack (instead of a normal burst) each time it would start a burst,
## the wait (s) after one ends before another is possible, and how close the player must be (m).
@export_range(0.0, 1.0) var perilous_chance: float = 0.35
@export var perilous_cooldown: float = 6.0
@export var perilous_range: float = 3.2
## Chance it continues a combo into a perilous attack: rolled once at each chain point of a burst
## (after the hit's cancel window opens, including after the last hit). Needs the same switches,
## range, and cooldown as above. 0 = bursts never turn perilous.
@export_range(0.0, 1.0) var perilous_chain_chance: float = 0.0
## It never picks the same perilous attack more than this many times in a row (when it has another).
@export var perilous_repeat_limit: int = 2
## Damage and posture damage of a perilous attack (they replace the action's own numbers and are
## not scaled by damage_scale). It cannot be guarded or deflected.
@export var perilous_damage: float = 35.0
@export var perilous_posture: float = 40.0
## The perilous thrust (not the sweep) can still be deflected, but only by a guard press this recent (s)
## when it hits: a much tighter window than a normal attack's. A late press or a plain guard just takes the hit.
@export var perilous_deflect_window: float = 0.1
## The perilous thrust is the heaviest attack: it pushes the player back this far (m), easing out
## over this long (s), whether it lands or is deflected (a deflect pushes the player's own deflect
## share of it, 0.6 by default).
@export var perilous_thrust_knockback: float = 3.0
@export var perilous_knockback_time: float = 0.4
## The danger symbol shows this long (s) before the hit window opens, and stays until it closes.
@export var perilous_symbol_lead: float = 0.5
## How far (m) the sweep lowers the whole swing so the hitbox travels near the floor.
@export var sweep_drop: float = 1.0

@export_group("Grab (Step 7c-2)")
## The grab: a yellow symbol, unguardable and undeflectable; only a dodge (its i-frames) avoids it. If it
## connects it breaks the guard and the player kneels (visual only). Off by default; the Debug Force
## Perilous = Grab option works on every preset.
@export var perilous_grab: bool = false
@export var grab_action: ActionData = preload("res://actions/enemy_grab.tres")
## It only starts a grab inside this distance (m).
@export var grab_range: float = 2.4
## The grab's own numbers (they replace the action's): health damage, posture damage, and the throw (m).
@export var grab_damage: float = 45.0
@export var grab_posture: float = 0.0
@export var grab_knockback: float = 2.0
## Recovery (s) when the grab misses (a dodge): the opening. A connected grab uses recovery_time.
@export var grab_whiff_recovery: float = 1.2
@export var grab_symbol_color: Color = Color(1.0, 0.85, 0.1)

@export_group("Counters (Step 7c)")
## Mikiri (against the thrust): the player is dodging toward the enemy (inside this angle, degrees,
## from the line to it) within this distance (m) at any moment from the symbol to the end of the hit window.
@export var mikiri_range: float = 3.5
@export_range(0.0, 180.0) var mikiri_angle: float = 70.0
## What a mikiri does: posture added to the enemy and how long (s) it is stunned (no guard, no flinch).
@export var mikiri_posture: float = 50.0
@export var mikiri_stun: float = 1.0
## The jump-over (against the sweep): the player is in the air within mikiri_range in the same span.
@export var jump_over_posture: float = 30.0
@export var jump_over_stun: float = 0.6
## After a jump-over (jumping while the sweep's symbol shows), landing on this enemy's head within this
## long (s) is the counter: the sweep is cut, posture added, the enemy stunned, and the player bounces.
@export var head_bounce_window: float = 1.5
