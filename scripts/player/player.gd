class_name Player
extends CharacterBody3D
## Shared player data and helpers. Behavior lives in the states under StateMachine.

## Step 10: the death flow, for the death screen (DeadState emits them in this order).
## The player just died (the body goes down).
@warning_ignore("unused_signal")
signal death_started
## The Die / Resurrect prompt is up (`can_resurrect` false = the final death: no choice).
@warning_ignore("unused_signal")
signal death_prompt_shown(can_resurrect: bool)
## The player chose to die (or had no resurrection left): fade to black over `fade_time`, then the scene reloads.
@warning_ignore("unused_signal")
signal death_confirmed(fade_time: float)
## The player resurrected.
@warning_ignore("unused_signal")
signal resurrected

## The radius of the standing-room check capsule (m).
const HEADROOM_RADIUS: float = 0.38

@export_group("Movement")
@export var run_speed: float = 6.5
@export var walk_speed: float = 2.5
@export var dash_speed: float = 9.0
@export var acceleration: float = 50.0
@export var deceleration: float = 60.0
@export var turn_speed: float = 18.0

@export_group("Jump")
## 10.08 with gravity 2.0 and a 2.5x apex band of 3 m/s = the same ~2.46 m jump as before (9.88 with a 1.5x band
## of 2 m/s). If you change one of these (or the apex values below), change the others to keep the height.
@export var jump_velocity: float = 10.08
@export var gravity_multiplier: float = 2.0
## Gravity multiple while falling (1.5 = a 50% faster descent than the climb).
@export var fall_gravity_factor: float = 1.5
## Landing faster than this (m/s downward) is a hard landing: a small camera shake (Step 11c).
@export var hard_land_speed: float = 14.0
## Landing faster than this (m/s downward) puffs a little dust (Step 11b).
@export var land_dust_speed: float = 5.0
## Off: no red mist or flecks on flesh hits (Step 11b; the deathblow keeps its red sparks).
@export var show_blood: bool = true
## Near the top of a jump (rising, vertical speed between zero and this many m/s) gravity is multiplied by
## apex_gravity_factor, so there is no hang at the peak. It does not touch the fall (that is fall_gravity_factor).
@export var apex_speed_band: float = 3.0
@export var apex_gravity_factor: float = 2.5
@export var coyote_time: float = 0.1
## In the air your horizontal speed is kept; the move keys only add a push this strong (m/s^2) that can
## steer it or fight it (holding back slows you, left and right curve it) but never takes you above
## your run speed (or your current speed, if faster). Not used by the wall jump or air attacks.
@export var air_steer_acceleration: float = 8.0

@export_group("Personal space")
## Keeps the player from standing right on top of an enemy: inside this distance (m, flat, center to
## center; the bodies themselves touch at 0.8) the player is eased away. Off = the old behavior.
@export var personal_space_enabled: bool = true
@export var personal_space_distance: float = 2.0
## The fastest the player is pushed out (m/s).
@export var personal_space_push_speed: float = 4.0

@export_group("Footsteps (Step 11a)")
## Distance (m) walked between two footsteps, per gait. The sounds are in data/audio/sfx_data.tres.
@export var step_distance_walk: float = 1.0
@export var step_distance_run: float = 1.9
@export var step_distance_crouch: float = 0.9

@export_group("Crouch")
## Placeholder speed while crouched (m/s).
@export var crouch_speed: float = 2.0
## How fast you slow down to crouch_speed when entering crouch faster than that (m/s^2).
@export var crouch_decel: float = 12.0
## Seconds the mesh takes to ease between standing and crouched height (collision is instant).
@export var crouch_transition_time: float = 0.12
## Capsule height while standing and crouched. Crouch shrinks from the top; feet stay planted.
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.1
## Off = press to toggle crouch. On = crouch only while the button is held.
@export var crouch_is_hold: bool = false

@export_group("Reach and wall jump")
## Wall jump speed multiplier: up = jump_velocity * boost, sideways/back = run_speed * boost.
@export var wall_jump_boost: float = 1.2
## A wall counts if it is within this distance (m) of the capsule edge, at chest height.
@export var wall_range: float = 0.6
@export var max_wall_jumps: int = 2
## How directly the input must point toward/away from the wall (dot product, 0.5 = within 60 degrees).
@export var wall_input_threshold: float = 0.75
## Air jump presses this close to the floor (m) are left buffered for the landing jump.
@export var air_jump_ground_margin: float = 0.3

@export_group("Ledge")
## Hand zone: a ledge top counts if it is between these heights above the feet (m).
@export var ledge_zone_min: float = 1.4
@export var ledge_zone_max: float = 2.1
## How directly the input must point at the wall to grab a ledge (dot product, 0.5 = within 60 degrees).
@export var ledge_input_threshold: float = 0.5
## No ledge grab while rising faster than this (m/s). 99 = no limit (grab while rising too).
@export var ledge_max_rise_speed: float = 99.0
## Only grab a ledge while the jump button is held (stops accidental re-grabs after a drop).
@export var ledge_requires_jump_held: bool = true
## Gap (m) between the capsule and the wall edge at the landing spot on top.
@export var ledge_standoff: float = 0.1
## Hang: the capsule center hangs this far (m) below the ledge top, and this far (m) off the wall.
@export var hang_center_depth: float = 1.2
@export var hang_gap: float = 0.05
## Both hands must be on the ledge: two hand points this far (m) either side of the center.
@export var hang_hand_spacing: float = 0.3
## Thin ledges: the ledge top must be at least this deep (m) to be grabbed (also the inset of the
## hand probes), and the hands move closer together on a narrow pillar, down to a ledge this
## wide (m). A thin top with no room to stand on is hung from, never climbed.
@export var hang_min_depth: float = 0.1
@export var hang_min_width: float = 0.3
## At a grab near a ledge end, the hang spot may shift up to this far (m) along the wall
## so both hands are on the ledge. If that is not enough, it auto-climbs instead.
@export var hang_adjust_max: float = 0.6
## Seconds to snap into the hanging spot after a grab.
@export var hang_snap_time: float = 0.1
@export var shimmy_speed: float = 1.5
## Turning a square corner while hanging: how long the turn takes (s), and how far (m) past the
## hang spot the probes look for the next wall.
@export var corner_turn_time: float = 0.35
@export var corner_reach: float = 0.5
## After a drop or leap, no ledge grab for this long (s).
@export var ledge_regrab_cooldown: float = 0.3

@export_group("Input")
@export var input_buffer_time: float = 0.15

@export_group("Wall hug (Phase 2 item 9)")
## Sidle speed along the wall (m/s), the gap (m) between the body and the wall, and how far (m) past
## the body the wall may be before the hug ends.
@export var wall_hug_speed: float = 1.2
@export var wall_hug_gap: float = 0.05
## The body capsule's radius (m) while hugging: a slim "pillar" so the back sits close to the wall and
## she fits past corners. The normal radius comes back on leaving.
@export var wall_hug_radius: float = 0.2
@export var wall_hug_edge_reach: float = 0.3
## How squarely the player must face the wall to start a hug (1 = dead on), and how firmly the input must
## point away from it to leave (1 = straight away).
@export_range(0.0, 1.0, 0.05) var wall_hug_facing_dot: float = 0.6
@export_range(0.0, 1.0, 0.05) var wall_hug_exit_dot: float = 0.6
## Seconds to ease against the wall when the hug starts.
@export var wall_hug_snap_time: float = 0.1
## How far (m) the camera shifts past the end of a wall.
@export var wall_hug_peek_distance: float = 0.8
## While hugging: the noise radius (m), and the multiplier on how fast guards' sight fills (on top of
## crouching).
@export var wall_hug_noise: float = 0.5
@export_range(0.0, 1.0, 0.05) var wall_hug_sight_multiplier: float = 0.5
## Corners (item 14a): seconds the scripted turn around a square corner takes, and how far (m) past the
## end of a wall the side face of an outside corner is looked for.
@export var wall_hug_corner_time: float = 0.35
@export var wall_hug_corner_reach: float = 0.5
## The low-wall vault (item 14b): the highest wall top (m above the feet) and the thickest wall (m)
## that can be vaulted, and how long (s) the hop takes.
@export var wall_hug_vault_max_height: float = 1.8
@export var wall_hug_vault_max_thickness: float = 0.8
@export var wall_hug_vault_time: float = 0.5
## Peek up (item 14c): the highest wall top (m above the feet) that can be looked over, and how far (m) above
## the top the camera is raised.
@export var wall_hug_peek_up_max_height: float = 1.8
@export var wall_hug_peek_up_clearance: float = 0.35

@export_group("Reverse blade (Phase 2 item 10)")
## While the blade is reversed (the `reverse_blade` toggle): the multipliers on the health damage and the
## posture damage of the player's hits. Its blows cannot kill; at zero health the enemy is knocked out.
@export var reverse_damage_multiplier: float = 0.5
@export var reverse_posture_multiplier: float = 1.0

@export_group("Items (Phase 2 item 11)")
## The items carried at the start, in the order `cycle_item` steps through them (the four `data/items/*.tres`).
## The counts are each item's `start_count`.
@export var starting_items: Array[ItemData] = []
## How far (m) the player can be heard while throwing (the landing makes its own noise).
@export var noise_throw: float = 2.0
## Item 11b: holding `use_item` this long (s) starts the aim; a shorter tap throws on release.
@export var hold_to_aim_time: float = 0.2
## Item 11c: true = the aim stays when `use_item` is let go (press it again to end the aim); false = letting go
## ends it. Replaced by `Settings.sticky_aim` (the Options menu) in `_ready()`.
@export var sticky_aim: bool = true

@export_group("Taunt (Phase 2 item 11.5)")
## A taunt provokes the enemies in combat within this distance (m); see `EnemyAIData` (the Provoked group).
@export var taunt_range: float = 12.0
## Enemies that are not in combat hear the taunt like a noise of this radius (m): they may turn suspicious.
@export var taunt_noise_radius: float = 8.0
## Seconds from the start of a taunt until the next one can start.
@export var taunt_cooldown: float = 1.5

@export_group("Carry (Phase 2 item 15a)")
## The multiplier on the walk, run and crouch speeds while carrying a body. No extra noise: the normal
## speed-based rules apply.
@export_range(0.1, 1.0, 0.05) var carry_speed_multiplier: float = 0.7
## The body hangs over the right shoulder, its length along the player's front-to-back line, the head behind and
## tilted `carry_tilt_degrees` head-down. Where its middle rests: how far (m) to the right, and how high (m)
## above the feet standing and crouched; and the seconds the pick-up lift takes.
@export var carry_shoulder_right: float = 0.3
@export var carry_height: float = 1.35
@export var carry_height_crouched: float = 0.95
@export var carry_tilt_degrees: float = 25.0
@export var carry_pickup_time: float = 0.25
## Putting down: how far (m) ahead the body is set, how long (s) the motion takes, the footprint checked for room
## (length across the arms, height, depth, m), and the dip and its time (s) when the spot is blocked (the body
## goes back up and stays carried).
@export var carry_put_distance: float = 0.9
@export var carry_put_time: float = 0.25
@export var carry_room_size: Vector3 = Vector3(1.8, 0.6, 0.8)
## A safety gap (m) added to the footprint on every side, so the body never touches a wall.
@export var carry_room_margin: float = 0.1
## Debug (put-down check): log what the room check sees and draw its box for 3 s (red = blocked,
## green = clear) plus the body's real footprint after a put-down (blue). Turn it off when done.
@export var debug_carry: bool = false
@export var carry_blocked_dip: float = 0.15
@export var carry_blocked_time: float = 0.2
## Throwing a body (item 15c): the numbers of the throw (speed, gravity, the hit and the noise of the landing).
@export var body_throw: ThrowableData = preload("res://data/items/body_throw.tres")
## Cover volumes (item 15b): how far (m) from the player the volume and the spot may be, the seconds the glide to
## the spot takes, and the grid step (m) the best spot is searched on.
@export var cover_snap_reach: float = 1.5
@export var cover_glide_time: float = 0.3
@export var cover_grid_step: float = 0.25
## A floor must be found within this many metres below the feet, or the released body falls instead.
@export var carry_floor_reach: float = 1.0

@export_group("Interact (Phase 2 item 8)")
## How far (m) an interactable can be and still be picked, the largest height difference (m), and how far
## in front it must be (1 = dead ahead, 0.5 = within 60 degrees).
@export var interact_range: float = 2.5
@export var interact_height_range: float = 1.6
@export_range(-1.0, 1.0, 0.05) var interact_min_dot: float = 0.5

@export_group("Combat")
## The equipped weapon: its combo, blade size, and rest pose.
@export var weapon: WeaponData
## Clock speed inside a normal slash's hit window (ground combo, crouch, air, dash, and draw
## attacks; not the thrusts, helm splitters, or deathblow). Below 1 the swing is slower, so it does
## not look instant: the hit window and the attack are longer by duration x (1/speed - 1).
@export_range(0.2, 1.0, 0.05) var slash_active_speed: float = 0.7

@export_group("Sheath")
## The sword starts sheathed (in the scabbard at the left hip).
@export var start_sheathed: bool = true
## Seconds without an attack or dodge (counted only while in Locomotion or Crouch) before a
## drawn sword sheathes itself. 0 = never.
@export var auto_sheathe_time: float = 5.0

## True while the sword is in its scabbard. Visual only: it changes no movement or rules.
var sheathed: bool = false
@export_group("Hurtbox and health")
## The Area3D that takes hits (an Area3D with hurtbox.gd, Team = Player, and a CapsuleShape3D child).
@export var hurtbox: Hurtbox
## The player's health (a Node named Combatant with combatant.gd).
@export var combatant: Combatant
## Hurtbox shapes per posture (height / bottom offset). Crouched = crouch, in the air = air.
@export var stand_hurtbox: HurtboxProfile = preload("res://data/hurtbox/stand.tres")
@export var crouch_hurtbox: HurtboxProfile = preload("res://data/hurtbox/crouch.tres")
@export var air_hurtbox: HurtboxProfile = preload("res://data/hurtbox/air.tres")
@export var max_health: float = 100.0
@export_group("Heal and resurrection")
## Healing gourd charges per run (a scene reload gives them back) and the health one heal restores.
@export var max_heal_charges: int = 3
@export var heal_amount: float = 40.0
## Off: the heal does not start at full health (no charge wasted). On: it plays and costs a charge anyway.
@export var allow_heal_at_full_health: bool = false
## Resurrections per run, the share of max health you come back with, and the invulnerable time (s) after.
@export var max_resurrections: int = 2
@export_range(0.05, 1.0) var resurrect_health_fraction: float = 0.5
@export var resurrect_invulnerable_time: float = 2.0
## Invulnerable for this many seconds (0 = off) from the moment any scene with a Player starts (a loaded arena,
## the death reload, an F6 run), so the first moment after a fade-in or a reload cannot get you killed.
@export_range(0.0, 5.0, 0.1) var start_invulnerable_time: float = 1.0
@export_group("Fall zone (Phase 2, 3a)")
## A fall out of the world (FallZone): the screen fades to black over fall_fade_out (s), the player is put
## back at its start, then fades back in over fall_fade_in (s). Invulnerable for fall_invulnerable_time (s)
## after the fade-in. The health lost is FallZone.damage_fraction of the max (never lethal).
@export var fall_fade_out: float = 0.35
@export var fall_fade_in: float = 0.35
@export var fall_invulnerable_time: float = 1.0
## Hit wobble (cosmetic): the whole Visual shifts this far (m) away from the attacker, tilts this far
## (radians), and eases back over this many seconds.
@export var hit_recoil_distance: float = 0.15
@export var hit_recoil_tilt: float = 0.2
@export var hit_recoil_time: float = 0.25
@export_group("Noise (Phase 2 item 7a)")
## How far (m) the player can be heard by an enemy with awareness: crouch-walking, walking, running, any
## action (an attack, a dodge ...), and a hard landing (a short spike). Standing still makes no noise.
@export var noise_crouch: float = 1.2
@export var noise_walk: float = 5.0
@export var noise_run: float = 10.0
@export var noise_action: float = 8.0
@export var noise_hard_land: float = 12.0

@export_group("Stealth deathblow (Phase 2 item 7b)")
## A fresh attack press kills an enemy that has not started fighting you (see Enemy.can_be_stealth_killed)
## when it is within this distance (m, flat) ...
@export var stealth_kill_range: float = 2.2
## ... and within this height difference (m).
@export var stealth_kill_height: float = 1.2
## How far (m) the stealth deathblow can be heard while it plays (instead of the loud action radius).
@export var noise_stealth_kill: float = 3.0
## Death from above (item 7c): a fresh attack press in the air (within `aerial_kill_buffer_time`), at any point of
## the jump or fall, over a stealth target at least `aerial_kill_min_height`
## (m) above its feet, from any height, and within `aerial_kill_range` (m, flat). For the enemy you are locked
## onto the reach is the lock-on's own (`LockOn.release_range`), and it is preferred over other targets.
@export var aerial_kill_range: float = 3.0
@export var aerial_kill_min_height: float = 1.5
@export var aerial_kill_buffer_time: float = 0.25
@export_group("Debug")
## Debug: nobody can notice this player (no noise, no sight or hearing fill, no aggro range); a guard already
## in combat keeps fighting and a hit still alerts. Toggled with F4 in a debug build while playing.
@export var debug_undetectable: bool = false
@export_group("Posture and deathblow")
## A deathblow needs an enemy with an open window within this distance (m, flat, center to center) ...
## (Personal space keeps you about 2 m from a living enemy, so this leaves room to be pushed or to drift.)
@export var deathblow_range: float = 3.5
## ... and in front of you: within this total cone (degrees) around where you face.
@export var deathblow_facing_degrees: float = 180.0
## An attack press counts toward a deathblow for this long (s), longer than the normal input buffer, so a
## press made while the last swing is still recovering is not lost.
@export var deathblow_buffer_time: float = 0.4
## How far (radians) the body leans forward while staggered.
@export var stagger_lean: float = 0.5
## While staggered the body also sinks to a knee (visual only: how far, m, and how fast, per second),
## and sways side to side (radians, and speed in radians per second).
@export var stagger_kneel_drop: float = 0.45
@export var stagger_kneel_speed: float = 3.0
@export var stagger_sway_angle: float = 0.12
@export var stagger_sway_speed: float = 2.0
@export_group("Enemy heads")
## Landing on an enemy's head right after a jump-over (a sweep dodged in the air) bounces you up at
## this speed (m/s), so you can dive with a helm splitter. Any other landing on a head slides you off
## at head_slide_speed (m/s). It counts as a head when your feet are this far (m) above the enemy's origin.
@export var head_bounce_velocity: float = 7.6
@export var head_slide_speed: float = 4.0
@export var head_min_height: float = 1.2
@export_group("Guard")
## A guard or deflect uses this share of the hit's hitstop (the plain hit uses all of it).
@export var guard_hitstop_factor: float = 0.5
## The player wobble on a plain guard and on a deflect, as a share of the hit wobble.
@export var guard_recoil_scale: float = 0.7
@export var deflect_recoil_scale: float = 0.35
## Guard break: a perilous attack that hits you while you guard drops the guard. The body wobble is
## this many times a plain hit's, and guard presses are ignored for the lockout (s; 0 = none).
@export var guard_break_recoil_scale: float = 1.6
@export var guard_break_lockout: float = 0.0
## A grab that connects also sinks the player to a knee (visual only) for this long (s), on the ground.
@export var grab_kneel_time: float = 0.8
## Knockback is a push that eases out over this many seconds (the distance comes from the hit).
@export var knockback_time: float = 0.2
## Name of the hurtbox posture in use (debug overlay).
var hurtbox_profile_name: String = "stand"
## Seconds left in which guard presses are ignored (after a guard break).
var _guard_lockout: float = 0.0

## Seconds since the last attack or dodge (counts only in Locomotion or Crouch).
var sheathe_idle: float = 0.0
## Set by GuardState: forces walking.
var walk_only: bool = false
## Item 11b: a throwable's `use_item` press is waiting to become a tap (throws on release) or a hold (aims).
var _use_pending: bool = false
## Item 11.5: seconds until the next taunt may start.
var _taunt_cooldown_left: float = 0.0
var _use_held: float = 0.0
## Step 10: gourd charges and resurrections left (set in _ready from the exports).
var heal_charges: int = 0
var resurrections_left: int = 0
## The enemy that was locked when the player died (DeadState re-locks it on a resurrection).
var relock_target: Node3D
var _death_pending: bool = false
## Where the player started (recorded in _ready) and which way it faced: the fall respawn point.
var _spawn_position: Vector3 = Vector3.ZERO
var _spawn_yaw: float = 0.0
## The fall respawn: black out, teleport, fade back in. The player is locked (no states, no movement).
enum FallPhase { NONE, FADE_OUT, FADE_IN }
var _fall_phase: FallPhase = FallPhase.NONE
var _fall_timer: float = 0.0
var _revive_invulnerable_left: float = 0.0
## Set by actions during their i-frame window (read by the damage system in Step 4).
var invulnerable: bool = false
var coyote_timer: float = 0.0
var input_buffer: InputBuffer
## The carried items and their counts (item 11), made in `_ready()` from `starting_items`.
var item_belt: ItemBelt
## Finds walls, ledges, and hang spots (Step 12C). Created in _ready().
var ledge_sensor: LedgeSensor
## The interactable the press of `interact` would use right now (ground, Locomotion or Crouch only).
var interact_target: Interactable
## Phase 2 item 15a: the body being carried (null = none), and the put-down and pick-up motions.
var carried_body: Enemy
var _carry_height_now: float = 0.0
var _carry_blend: float = 1.0
var _carry_from: Vector3 = Vector3.ZERO
var _carry_from_rot: Vector3 = Vector3.ZERO
var _carry_dip_left: float = 0.0
var _put_left: float = 0.0
var _put_from: Vector3 = Vector3.ZERO
var _put_to: Vector3 = Vector3.ZERO
var _put_yaw: float = 0.0
var _put_from_rot: Vector3 = Vector3.ZERO
## The pick-up runs in two steps: the sheathe (the sword's own animation), then the lift. While the first runs the
## body stays where it lies; after PICKUP_SHEATHE_LIMIT seconds the lift starts anyway.
const PICKUP_SHEATHE_LIMIT: float = 1.0
var _pickup_waiting: bool = false
## Item 15c: with a body on the shoulder `interact` acts on release (a tap) or starts the body aim (a hold).
var _carry_interact_pending: bool = false
var _carry_interact_held: float = 0.0
var _carry_interact_firing: bool = false
var _pickup_wait_left: float = 0.0
var _put_scale: float = 1.0
var _put_from_scale: float = 1.0
## Item 15b: the spot `CoverPlaceState` glides to (see `CoverPlacement.find`), the finder and its short cache.
var cover_plan: Dictionary = {}
var _cover_placement: CoverPlacement
var _cover_cache: Dictionary = {}
var _cover_cache_id: int = 0
var _cover_cache_ms: int = -100000
var _cover_cache_pos: Vector3 = Vector3.ZERO
## Item 10: is the blade reversed? Kept in `GameFlags` (so it survives the death reload, not the main menu).
var blade_reversed: bool:
	get:
		return GameFlags.has_flag(GameFlags.BLADE_REVERSED)
var _interact_picker: InteractPicker
var is_crouched: bool = false
var _noise_spike: float = 0.0
var _noise_spike_left: float = 0.0
## Mid-air reach is once per airtime; a wall jump restores it. Landing resets both.
var reach_ready: bool = true
var wall_jumps_used: int = 0
## The next attack of the air tap loop (empty = start from the first). Landing resets it.
var air_loop_next: ActionData
## The helm splitter is once per airtime; landing (reset_air_actions) clears it.
var helm_used: bool = false
## Set by try_air_jump() when it returns true: the surface normal of the wall to jump from.
var wall_normal: Vector3 = Vector3.ZERO
## Set by LedgeSensor.try_ledge_grab() when it returns true (read by the LedgeClimb state).
var ledge_stand_pos: Vector3 = Vector3.ZERO
var ledge_wall_normal: Vector3 = Vector3.ZERO
## Debug: where the last ledge was found, and when (msec).
var ledge_hang_pos: Vector3 = Vector3.ZERO
var ledge_hang_fits: bool = false
## False for a thin ledge top with no room to stand: the grab always hangs, and climbing is refused.
var ledge_can_climb: bool = true
## True when the ledge top has room to crouch but not to stand: the climb is the low variant and
## ends in Crouch (item 13b).
var ledge_climb_low: bool = false
## How far apart (m) the hands are on the current ledge (full spacing, or less on a narrow one);
## the arm IK of the real animations can read it.
var ledge_hand_spacing: float = 0.3
var ledge_top_y: float = 0.0
var last_ledge_point: Vector3 = Vector3.ZERO
var last_ledge_ms: int = -100000
## No ledge grab until this time (msec); set by a drop or leap.
var ledge_block_until_ms: int = 0
## Set by the ledge hang state: the next WallJump goes away from the wall and is not counted.
var wall_jump_forced_away: bool = false

var _headroom_shape: CapsuleShape3D
var _crouch_headroom_shape: CapsuleShape3D
## The body capsule's radius from the scene (restored after a wall hug, item 9).
var _default_body_radius: float = 0.38
var _hurt_shape: CollisionShape3D
## A repulse (an enemy's special deflect, Step 7b) is waiting to cancel the current attack.
var _repulse_pending: bool = false
var _repulse_direction: Vector3 = Vector3.ZERO
## Metres walked since the last footstep.
var _step_travelled: float = 0.0
var _hurt_capsule: CapsuleShape3D
var _nose_drop: float = 0.4
var _visual_tween: Tween
var _reach_arms: ReachArms
## The enemy a deathblow was started on (read by DeathblowState).
var deathblow_target: Node3D
## True when the deathblow in progress is a stealth kill (item 7b).
var deathblow_stealth: bool = false
## True when it is a death from above (item 7c): the deathblow starts with a plunge onto the target.
var deathblow_aerial: bool = false
## True when the stealth kill in progress started from the wall hug (item 9): the target is pulled in first.
var deathblow_from_hug: bool = false
var _stagger_pending: bool = false
## Forced movement (knockback, head slide, personal space) and the placeholder body reactions (the hit
## wobble, the lean, the kneel), Phase 1.5 item 5c.
var _forced: PlayerForcedMovement
var _reaction: PlayerBodyReaction
## The placeholder sword (found in _ready). Null if the scene has no SwordVisual.
var sword_visual: SwordVisual

@onready var visual: Node3D = $Visual
@onready var camera_rig: Node3D = $CameraRig
@onready var lock_on: LockOn = $LockOn
## The aim solver and arc preview (item 11b), used by `AimState`.
@onready var aim_preview: AimPreview = $AimPreview
@onready var state_machine: StateMachine = $StateMachine
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _body_mesh: MeshInstance3D = $Visual/Body
@onready var _nose: MeshInstance3D = $Visual/Nose
## Phase 3a-3b-1: the mannequin that replaces the capsule and the nose while shown (a placeholder, P5).
@onready var figure: PlayerFigure = $Visual/Figure
## The left arm that lifts the gourd while healing (Step 11, HealState drives it).
@onready var heal_arm: HealArm = $Visual/HealArm
@onready var screen_fade: ScreenFade = $ScreenFade
@onready var _interact_prompt: InteractPrompt = $InteractPrompt
@onready var _traversal_hint: TraversalHint = $TraversalHint


func _ready() -> void:
	input_buffer = InputBuffer.new(input_buffer_time)
	item_belt = ItemBelt.new(starting_items)
	_spawn_position = global_position
	_spawn_yaw = visual.rotation.y
	_place_at_last_rest_point()
	ledge_sensor = LedgeSensor.new(self)
	_interact_picker = InteractPicker.new(self)
	_cover_placement = CoverPlacement.new(self)
	_forced = PlayerForcedMovement.new(self)
	_reaction = PlayerBodyReaction.new(self)
	Fx.blood_enabled = show_blood
	_nose_drop = stand_height - _nose.position.y
	figure.fit_to_height(stand_height)
	_reach_arms = get_node_or_null("Visual/ReachArms") as ReachArms
	sword_visual = get_node_or_null("Visual/SwordVisual") as SwordVisual
	figure.bind_arms(sword_visual, heal_arm, _reach_arms)
	set_figure_shown(true)
	if sword_visual != null and weapon != null:
		sword_visual.setup(weapon)
	sheathed = start_sheathed and weapon != null
	if sheathed and sword_visual != null:
		sword_visual.snap_sheathed()
	if sword_visual != null:
		sword_visual.set_reversed(blade_reversed, true)
	_default_body_radius = (_collision_shape.shape as CapsuleShape3D).radius
	_headroom_shape = CapsuleShape3D.new()
	_headroom_shape.radius = HEADROOM_RADIUS
	_headroom_shape.height = stand_height - 0.07
	_crouch_headroom_shape = CapsuleShape3D.new()
	_crouch_headroom_shape.radius = HEADROOM_RADIUS
	_crouch_headroom_shape.height = crouch_height - 0.07
	add_to_group(Groups.PLAYER)
	# The awareness HUD (item 7a): the triangles that show enemies noticing the player.
	var awareness_hud := AwarenessHud.new()
	awareness_hud.name = "AwarenessHud"
	add_child(awareness_hud)
	heal_charges = max_heal_charges
	resurrections_left = max_resurrections
	Settings.apply_gameplay(self)
	_reaction.capture_rest()
	_setup_hurtbox()
	if start_invulnerable_time > 0.0:
		grant_invulnerability(start_invulnerable_time)
	state_machine.setup(self)
	state_machine.start()


## The hit wobble: shift and tilt the Visual away from the hit, then ease back. The yaw (facing) is
## left alone; only the position and the tilt are set here.
func _process(delta: float) -> void:
	_reaction.update(delta * Hitstop.fighter_scale(self))


func _physics_process(delta: float) -> void:
	# 3c-1: a hit freezes this fighter (its clock runs at a small share) while the rest of the game keeps going.
	var hit_scale := Hitstop.fighter_scale(self)
	delta *= hit_scale
	input_buffer.tick(delta)
	_noise_spike_left = maxf(_noise_spike_left - delta, 0.0)
	if _guard_lockout > 0.0:
		_guard_lockout -= delta
		input_buffer.clear(Actions.GUARD)
	_reaction.update_grab_kneel(delta)
	combatant.tick_guard(delta, state_machine.current is GuardState, state_machine.current is ActionState)
	combatant.tick_posture(delta, _posture_regen_paused())
	_revive_invulnerable_left = maxf(_revive_invulnerable_left - delta, 0.0)
	_update_death()
	if _update_fall_respawn(delta):
		return
	_update_stagger()
	_update_repulse()
	_try_deathblow()
	_try_heal()
	_try_cycle_item()
	_try_use_item(delta)
	_try_taunt(delta)
	_update_interact_target()
	_update_traversal_hints()
	_try_carry_interact(delta)
	state_machine.physics_update(delta)
	# DeadState can reload the scene during the update; this node is out of the tree then.
	if not is_inside_tree():
		return
	_update_auto_sheathe(delta)
	# A knockback push is added on top of the state's own velocity for the move, then taken off
	# again, so the states never see it (they set or ease the velocity themselves).
	var push := _forced.add_push(delta)
	var was_airborne := not is_on_floor()
	var fall_speed := -velocity.y
	Hitstop.slide(self, hit_scale)
	if was_airborne and is_on_floor():
		if fall_speed >= hard_land_speed:
			Fx.play(get_tree(), Fx.Kind.HARD_LAND, global_position)
			make_noise(noise_hard_land)
		elif fall_speed >= land_dust_speed:
			Fx.play(get_tree(), Fx.Kind.LAND_DUST, global_position)
	velocity.x -= push.x
	velocity.z -= push.z
	_drive_figure_locomotion()
	_forced.update_enemy_head()
	_update_carried_body(delta)
	_update_footsteps(delta)
	_forced.update_personal_space(delta)
	_update_hurtbox()


## How far (m) the player can be heard right now (item 7a): the loudest of the current movement, any action,
## and a recent spike (`make_noise`). Enemies with awareness read this every frame.
func get_noise_radius() -> float:
	if debug_undetectable:
		return 0.0
	var radius := 0.0
	var current := state_machine.current
	if current is DeathblowState and deathblow_stealth:
		radius = noise_stealth_kill
	elif current is ThrowState or current is AimState:
		radius = noise_throw
	elif current is ActionState:
		radius = noise_action
	elif current is WallHugState:
		radius = wall_hug_noise if Vector2(velocity.x, velocity.z).length() >= 0.3 else 0.0
	elif is_on_floor() and (current is LocomotionState or current is CrouchState or current is GuardState \
			or current is DashState or current is HealState):
		var horizontal := Vector2(velocity.x, velocity.z).length()
		if horizontal >= 0.5:
			if is_crouched:
				radius = noise_crouch
			elif horizontal > walk_speed * 1.5:
				radius = noise_run
			else:
				radius = noise_walk
	if _noise_spike_left > 0.0:
		radius = maxf(radius, _noise_spike)
	return radius


## A short loud noise of `radius` m that fades after `duration` seconds (a hard landing).
func make_noise(radius: float, duration: float = 0.5) -> void:
	if _noise_spike_left <= 0.0 or radius > _noise_spike:
		_noise_spike = radius
	_noise_spike_left = maxf(_noise_spike_left, duration)


## Movement input in world space, relative to the camera. Length 0 to 1.
func get_move_input() -> Vector3:
	var input_dir := Input.get_vector(Actions.MOVE_LEFT, Actions.MOVE_RIGHT, Actions.MOVE_FORWARD, Actions.MOVE_BACK)
	var cam_basis := Basis(Vector3.UP, camera_rig.global_rotation.y)
	return cam_basis * Vector3(input_dir.x, 0.0, input_dir.y)


func get_move_speed() -> float:
	var speed := walk_speed if walk_only else run_speed
	return speed * carry_speed_multiplier if carried_body != null else speed


func get_crouch_speed() -> float:
	return crouch_speed * carry_speed_multiplier if carried_body != null else crouch_speed


## Picks the interactable in reach and in front (item 8) and feeds the prompt. Only on the ground in
## Locomotion or Crouch; everywhere else there is none.
## Item 16: the hint row shows what the current state offers (a ledge hang, a wall hug, the air, an aim, carrying a
## body), if the Options choice is not OFF.
func _update_traversal_hints() -> void:
	var hints: Array[Dictionary] = []
	var context: StringName = &""
	if Settings.traversal_hints_mode != Settings.HintMode.OFF and not combatant.dead and state_machine.current != null:
		hints = state_machine.current.get_hints()
		context = state_machine.current.name
		for hint in hints:
			if hint.has("toward"):
				hint["move_dir"] = ButtonPrompts.screen_direction(hint["toward"], camera_rig.global_rotation.y)
	_traversal_hint.set_hints(hints, context)


func _update_interact_target() -> void:
	var current := state_machine.current
	interact_target = null
	if current is LocomotionState or current is CrouchState:
		interact_target = _interact_picker.pick()
	_interact_prompt.set_target(interact_target, self)


## Called by Locomotion and Crouch on a fresh `interact` press: uses the picked interactable.
## Returns true if one was used (the press is then used up so it can't also grab a ledge).
func try_interact() -> bool:
	if carried_body != null and not _carry_interact_firing:
		# Carrying: the press is used up here and acts on release (`_try_carry_interact`).
		input_buffer.consume(Actions.INTERACT)
		return true
	if _put_left > 0.0:
		input_buffer.consume(Actions.INTERACT)
		return true
	if interact_target == null and carried_body != null:
		# Carrying: no wall hug; the press puts the body down.
		input_buffer.consume(Actions.INTERACT)
		try_put_down_body()
		return true
	if interact_target == null:
		# Nothing to use: a wall in front is a wall hug (item 9).
		var hug := state_machine.get_state(StateName.WALL_HUG) as WallHugState
		if hug == null:
			push_error("Player: no WallHug node under StateMachine (Phase 2 item 9, add it in the editor).")
			return false
		return hug.try_begin()
	input_buffer.consume(Actions.INTERACT)
	_face_interact_target(interact_target)
	interact_target.interact(self)
	return true


## Turns the player to the target on a press when it is not in front of the character (the camera may be the one
## looking at it). Instant, like an action start.
func _face_interact_target(target: Interactable) -> void:
	if not target.faces_on_press(self):
		return
	var offset := target.reach_point(self) - global_position
	offset.y = 0.0
	if offset.length() <= 0.3:
		return
	var dir := offset.normalized()
	if get_facing_direction().dot(dir) < interact_min_dot:
		snap_facing(dir)


## Item 15c: while carrying, `interact` tapped (released within `hold_to_aim_time`) acts on release (put down, hide,
## a door, a chest kick), and held starts the body aim.
func _try_carry_interact(delta: float) -> void:
	if carried_body == null or combatant.dead:
		_carry_interact_pending = false
		return
	if Input.is_action_just_pressed(Actions.INTERACT):
		_carry_interact_pending = _put_left <= 0.0 and not _pickup_waiting and can_start_throw()
		_carry_interact_held = 0.0
		return
	if not _carry_interact_pending:
		return
	if Input.is_action_pressed(Actions.INTERACT):
		_carry_interact_held += delta
		if _carry_interact_held >= hold_to_aim_time:
			_carry_interact_pending = false
			_try_aim()
		return
	_carry_interact_pending = false
	_carry_interact_firing = true
	try_interact()
	_carry_interact_firing = false


## Item 15c: the throwable the aim uses: the body throw while carrying, else the selected item.
func get_aim_item() -> ThrowableData:
	if carried_body != null:
		return body_throw
	return item_belt.selected() as ThrowableData


## Item 15c: throws the carried body from `origin` with `velocity`. False (nothing happens) when there is no
## body, or a wall is between the player and where the body would start.
func throw_carried_body(origin: Vector3, throw_velocity: Vector3) -> bool:
	if carried_body == null or body_throw == null or _pickup_waiting:
		return false
	var flat := Vector3(throw_velocity.x, 0.0, throw_velocity.z)
	var along := flat.normalized() if flat.length_squared() > 0.0001 else get_facing_direction()
	var mask := collision_mask & ~Layers.INVISIBLE_WALL
	var space := get_world_3d().direct_space_state
	for offset: float in [0.0, 0.9, -0.9]:
		var target := origin + along * offset
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, target, mask, [get_rid()])
		if not space.intersect_ray(query).is_empty():
			_carry_dip_left = carry_blocked_time
			return false
	var body := carried_body
	carried_body = null
	_put_left = 0.0
	_carry_dip_left = 0.0
	body.visible = true
	body.launch_body(self, body_throw, origin, throw_velocity)
	Sfx.play(get_tree(), Sfx.Id.SWING_ALT)
	return true


## Flips the blade (item 10): the blunt back becomes the striking side. Only the visual takes a moment.
func toggle_reverse_blade() -> void:
	if weapon == null:
		return
	var on := GameFlags.toggle_flag(GameFlags.BLADE_REVERSED)
	if sword_visual != null:
		sword_visual.set_reversed(on)
	Sfx.play_ui(get_tree(), Sfx.Id.MENU_OK)


# --- Carrying a body (Phase 2 item 15a) --------------------------------------------------------------

## The states that need both hands or the sword: entering one drops the carried body (the attack, the guard
## and the dodge then run as usual). Called by `StateMachine.transition_to`.
const CARRY_DROP_STATES: Array[StringName] = [
	StateName.DODGE, StateName.DASH, StateName.ATTACK, StateName.AIR_ATTACK, StateName.HELM_SPLITTER,
	StateName.GUARD, StateName.STAGGER, StateName.DEATHBLOW, StateName.DEAD, StateName.LEDGE_HANG,
	StateName.LEDGE_CLIMB,
]


func on_state_entering(state_name: StringName) -> void:
	if carried_body != null and CARRY_DROP_STATES.has(state_name):
		drop_carried_body()


func is_carrying() -> bool:
	return carried_body != null


## Picks the body up (`BodyPickup`): the sword is sheathed, the body lifts across the arms.
func pick_up_body(body: Enemy) -> void:
	if carried_body != null or body == null or combatant.dead or not is_on_floor():
		return
	carried_body = body
	body.set_carried(true)
	body.corpse_discovered = false
	_carry_dip_left = 0.0
	_put_left = 0.0
	_pickup_waiting = false
	if not sheathed:
		_begin_pickup_sheathe()
	else:
		_begin_pickup_lift()


## Pick-up step 1: the sword goes into the scabbard with its own animation (the same as the sheathe press).
func _begin_pickup_sheathe() -> void:
	_pickup_waiting = true
	_pickup_wait_left = PICKUP_SHEATHE_LIMIT
	set_sheathed(true)


## Pick-up step 2: the body lifts onto the shoulder (a placeholder motion; a real pick-up animation replaces this).
func _begin_pickup_lift() -> void:
	_pickup_waiting = false
	if carried_body == null:
		return
	_carry_from = carried_body.global_position
	_carry_from_rot = carried_body.global_rotation
	_carry_blend = 0.0
	_carry_height_now = carry_height_crouched if is_crouched else carry_height
	Sfx.play(get_tree(), Sfx.Id.MENU_OK)


## `interact` while carrying: puts the body down in front, or, when the spot is blocked, the body dips and comes
## back up (still carried: the player moves and tries again). With no floor ahead it is let go and falls.
func try_put_down_body() -> void:
	if carried_body == null or _put_left > 0.0 or _pickup_waiting:
		return
	var spot := global_position + get_facing_direction() * carry_put_distance
	_carry_log("put-down: pos=%s facing_yaw=%.1f spot=%s" % [global_position, rad_to_deg(visual.global_rotation.y), spot])
	# Room first, at the player's own floor height: a spot inside a wall must read as blocked, not as "no floor".
	if not _carry_room_at(Vector3(spot.x, global_position.y, spot.z)):
		_carry_log("  -> blocked (dip)")
		_carry_dip_left = carry_blocked_time
		return
	var floor_y := _find_floor_y(spot)
	_carry_log("  floor_y=%s" % ("none" if is_nan(floor_y) else "%.2f" % floor_y))
	if is_nan(floor_y):
		_carry_log("  -> no floor: forced drop")
		drop_carried_body()
		return
	spot.y = floor_y
	# A floor lower than the player's: the footprint is checked again at that height.
	if absf(floor_y - global_position.y) > 0.05 and not _carry_room_at(spot):
		_carry_log("  -> blocked at the lower floor (dip)")
		_carry_dip_left = carry_blocked_time
		return
	_carry_log("  -> clear: putting down")
	_begin_put_motion(spot, visual.global_rotation.y + PI * 0.5)


## Starts the body's motion from where it is to lying flat with its middle above `spot` (a floor point), turned
## to `body_yaw`; `_update_carried_body` runs it and `_finish_put_down` lets the body go.
func _begin_put_motion(spot: Vector3, body_yaw: float, body_scale: float = 1.0) -> void:
	_put_yaw = body_yaw
	_put_scale = body_scale
	_put_from_scale = carried_body.scale.x
	_put_from = carried_body.global_position
	_put_from_rot = carried_body.global_rotation
	_put_to = _flat_root_for(carried_body, spot, _put_yaw, body_scale)
	_put_left = carry_put_time
	if _put_left <= 0.0:
		_finish_put_down()


## Item 15b: where to lay the carried body in this cover volume (an empty Dictionary: nowhere). Kept for a
## moment, so the prompt can ask every frame.
func find_cover_placement(cover: CoverVolume, fresh: bool = false) -> Dictionary:
	var now := Time.get_ticks_msec()
	if not fresh and _cover_cache_id == cover.get_instance_id() and now - _cover_cache_ms < 200 \
			and global_position.distance_to(_cover_cache_pos) < 0.1:
		return _cover_cache
	_cover_cache = _cover_placement.find(cover)
	_cover_cache_id = cover.get_instance_id()
	_cover_cache_ms = now
	_cover_cache_pos = global_position
	return _cover_cache


## Item 15b: `interact` on a "Hide body" prompt: glide to the spot and lay the body in.
func begin_cover_place(cover: CoverVolume) -> void:
	if carried_body == null or _put_left > 0.0 or not is_on_floor():
		return
	var plan := find_cover_placement(cover, true)
	if plan.is_empty():
		return
	cover_plan = plan
	input_buffer.consume(Actions.INTERACT)
	state_machine.transition_to(StateName.COVER_PLACE)


## Item 15b: the glide is done: the body goes into the volume.
func finish_cover_place() -> void:
	var plan := cover_plan
	cover_plan = {}
	if carried_body == null or plan.is_empty():
		return
	_begin_put_motion(plan["spot"], plan["body_yaw"], float(plan.get("scale", 1.0)))


## Item 15b: can the player stand at `feet`, facing `facing_yaw`, and put the body down with its middle above
## `spot`? Floor under the feet, room for the body, a clear path there, room for the footprint.
func cover_spot_valid(feet: Vector3, facing_yaw: float, spot: Vector3) -> bool:
	var floor_y := _find_floor_y(feet)
	if is_nan(floor_y) or absf(floor_y - global_position.y) > 0.3:
		return false
	var at := Vector3(feet.x, floor_y, feet.z)
	var fits := fits_crouching_at(at + Vector3.UP * 0.02) if is_crouched else fits_standing_at(at + Vector3.UP * 0.02)
	if not fits:
		return false
	var mask := collision_mask & ~Layers.INVISIBLE_WALL
	var path := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, at + Vector3.UP * 0.5, mask,
			[get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(path).is_empty():
		return false
	return _carry_room_at(Vector3(spot.x, floor_y, spot.z), facing_yaw, at, true)


## Lets go of the body at once, in front of the feet (a dodge, an attack, a hit, a ledge). With no floor
## below it falls.
func drop_carried_body() -> void:
	if carried_body == null:
		return
	var body := carried_body
	carried_body = null
	_put_left = 0.0
	_carry_dip_left = 0.0
	if _pickup_waiting:
		# The pick-up was cancelled before the lift: the body stays where it lies.
		_pickup_waiting = false
		body.place_body(body.global_position, body.global_rotation.y, false)
		return
	var spot := global_position + get_facing_direction() * 0.4
	var yaw := visual.global_rotation.y + PI * 0.5
	var floor_y := _find_floor_y(spot)
	if is_nan(floor_y):
		body.place_body(body.global_position, yaw, true)
		return
	body.place_body(_flat_root_for(body, Vector3(spot.x, floor_y, spot.z), yaw), yaw, false)


func _finish_put_down() -> void:
	var body := carried_body
	if debug_carry and is_instance_valid(body):
		var body_basis := Basis(Vector3.UP, _put_yaw)
		_debug_box(_put_to + body_basis * Enemy.LYING_MIDDLE, Vector3(0.8, 0.8, 1.8), body_basis, Color(0.2, 0.3, 1.0, 0.35))
	carried_body = null
	_put_left = 0.0
	if is_instance_valid(body):
		body.place_body(_put_to, _put_yaw, false, _put_scale)


## The floor height under a spot (within `carry_floor_reach` below the feet), or NAN when there is none.
func _find_floor_y(at: Vector3) -> float:
	var mask := collision_mask & ~Layers.INVISIBLE_WALL
	var query := PhysicsRayQueryParameters3D.create(
			Vector3(at.x, global_position.y + 0.6, at.z),
			Vector3(at.x, global_position.y - carry_floor_reach, at.z), mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
		return NAN
	return (hit["position"] as Vector3).y


## The root for a body lying flat on the floor with its middle above `floor_spot` (a put-down or a drop).
func _flat_root_for(body: Enemy, floor_spot: Vector3, body_yaw: float, body_scale: float = 1.0) -> Vector3:
	var middle := floor_spot + Vector3.UP * Enemy.LYING_MIDDLE.y * body_scale
	return body.lying_root_for(middle, Basis(Vector3.UP, body_yaw).scaled(Vector3.ONE * body_scale))


## True when the body's footprint (lying across the facing direction) fits at the spot.
func _carry_room_at(floor_spot: Vector3, yaw: float = INF, origin: Vector3 = Vector3.INF, quiet: bool = false) -> bool:
	var box_yaw := visual.global_rotation.y if is_inf(yaw) else yaw
	var from_pos := global_position if not origin.is_finite() else origin
	var shape := BoxShape3D.new()
	shape.size = carry_room_size + Vector3.ONE * carry_room_margin * 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(Vector3.UP, box_yaw),
			floor_spot + Vector3.UP * (0.1 + shape.size.y * 0.5))
	query.collision_mask = collision_mask & ~Layers.INVISIBLE_WALL
	query.exclude = [get_rid()]
	var space := get_world_3d().direct_space_state
	var hits := space.intersect_shape(query, 8)
	# A wall's collision (a CSG box) is a one-sided surface: a shape whose middle is inside the wall's thickness
	# reads as clear. Rays from the player to the footprint's points catch those walls by their front face.
	var ray_hits: Array[String] = []
	var lateral := query.transform.basis * Vector3.RIGHT
	var forward := query.transform.basis * Vector3.FORWARD
	var half_length := shape.size.x * 0.5
	var half_depth := shape.size.z * 0.5
	for height: float in [0.2, shape.size.y * 0.5 + 0.1]:
		var from := Vector3(from_pos.x, from_pos.y + height, from_pos.z)
		var base := Vector3(floor_spot.x, floor_spot.y + height, floor_spot.z)
		for target: Vector3 in [base, base + lateral * half_length, base - lateral * half_length,
				base + forward * half_depth]:
			var ray := PhysicsRayQueryParameters3D.create(from, target, query.collision_mask, [get_rid()])
			var ray_hit := space.intersect_ray(ray)
			if not ray_hit.is_empty():
				var collider := ray_hit.get("collider") as Node
				ray_hits.append(str(collider.name) if collider != null else "?")
	var blocked := not hits.is_empty() or not ray_hits.is_empty()
	if debug_carry and not quiet:
		var names: Array[String] = []
		for hit: Dictionary in hits:
			var collider := hit.get("collider") as Node
			names.append(str(collider.name) if collider != null else "?")
		_carry_log("  room box center=%s size=%s yaw=%.1f mask=%d hits=%s ray_hits=%s" % [query.transform.origin,
				shape.size, rad_to_deg(box_yaw), query.collision_mask, names, ray_hits])
		_debug_box(query.transform.origin, shape.size, query.transform.basis,
				Color(1.0, 0.2, 0.2, 0.35) if blocked else Color(0.2, 1.0, 0.3, 0.35))
	return not blocked


func _carry_log(text: String) -> void:
	if debug_carry and OS.is_debug_build():
		print("[carry] ", text)


## Debug only: a see-through box in the world for 3 seconds.
func _debug_box(center: Vector3, size: Vector3, box_basis: Basis, color: Color) -> void:
	if not debug_carry or not OS.is_debug_build():
		return
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = material
	get_tree().current_scene.add_child(mesh)
	mesh.global_transform = Transform3D(box_basis, center)
	get_tree().create_timer(3.0).timeout.connect(mesh.queue_free)


## Keeps the carried body across the arms (a placeholder for a carry animation), runs the pick-up lift, the
## put-down motion and the dip of a blocked put-down.
func _update_carried_body(delta: float) -> void:
	if carried_body == null:
		return
	if not is_instance_valid(carried_body):
		carried_body = null
		_pickup_waiting = false
		return
	if _pickup_waiting:
		_pickup_wait_left -= delta
		if sword_visual == null or not sword_visual.is_busy() or _pickup_wait_left <= 0.0:
			_begin_pickup_lift()
		return
	if _put_left > 0.0:
		_put_left -= delta
		if _put_left <= 0.0:
			_finish_put_down()
			return
		var t := 1.0 - _put_left / maxf(carry_put_time, 0.001)
		carried_body.global_position = _put_from.lerp(_put_to, smoothstep(0.0, 1.0, t))
		carried_body.global_rotation = Vector3(lerpf(_put_from_rot.x, 0.0, smoothstep(0.0, 1.0, t)),
				lerp_angle(_put_from_rot.y, _put_yaw, smoothstep(0.0, 1.0, t)), 0.0)
		carried_body.scale = Vector3.ONE * lerpf(_put_from_scale, _put_scale, smoothstep(0.0, 1.0, t))
		return
	var height_goal := carry_height_crouched if is_crouched else carry_height
	_carry_height_now = lerpf(_carry_height_now, height_goal, 1.0 - exp(-12.0 * delta))
	var yaw := visual.global_rotation.y
	var right := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	var goal := global_position + right * carry_shoulder_right + Vector3.UP * _carry_height_now
	var hold_rot := Vector3(deg_to_rad(carry_tilt_degrees), yaw, 0.0)
	var hold_basis := Basis.from_euler(hold_rot)
	if _carry_dip_left > 0.0:
		_carry_dip_left = maxf(_carry_dip_left - delta, 0.0)
		var progress := 1.0 - _carry_dip_left / maxf(carry_blocked_time, 0.001)
		goal.y -= sin(PI * progress) * carry_blocked_dip
	if _carry_blend < 1.0:
		_carry_blend = minf(_carry_blend + delta / maxf(carry_pickup_time, 0.01), 1.0)
		var u := smoothstep(0.0, 1.0, _carry_blend)
		carried_body.global_position = _carry_from.lerp(carried_body.lying_root_for(goal, hold_basis), u)
		carried_body.global_rotation = Vector3(lerpf(_carry_from_rot.x, hold_rot.x, u),
				lerp_angle(_carry_from_rot.y, hold_rot.y, u), 0.0)
		return
	carried_body.global_position = carried_body.lying_root_for(goal, hold_basis)
	carried_body.global_rotation = hold_rot


func is_wall_hugging() -> bool:
	return state_machine.current is WallHugState


## Item 14c: hugging with the camera raised over a low wall (the hug's sight bonus is off).
func is_peeking_up() -> bool:
	var hug := state_machine.current as WallHugState
	return hug != null and hug.is_peeking_up()


## A line of text near the bottom of the screen (an NPC's line, "It is empty.").
func show_interact_line(text: String) -> void:
	_interact_prompt.show_line(text)


## The way the camera looks, flat (yaw only).
func get_camera_forward() -> Vector3:
	return Basis(Vector3.UP, camera_rig.global_rotation.y) * Vector3.FORWARD


func get_facing_direction() -> Vector3:
	# Yaw only, so the hit wobble's tilt never changes where attacks aim.
	return Basis(Vector3.UP, visual.global_rotation.y) * Vector3.FORWARD


func apply_gravity(delta: float) -> void:
	velocity += get_gravity_now() * delta


## The gravity pulling on the player right now (a vector like get_gravity()): the base gravity times
## the jump phase (faster near the apex, faster again while falling). The dive and the helm hover
## multiply this, so their factors keep their meaning.
func get_gravity_now() -> Vector3:
	var factor := 1.0
	if velocity.y >= 0.0 and velocity.y <= apex_speed_band:
		factor = apex_gravity_factor
	if velocity.y < 0.0:
		factor = maxf(factor, fall_gravity_factor)
	return get_gravity() * gravity_multiplier * factor


## Air control for a normal jump or fall: momentum stays, the move input only steers it.
func apply_air_steering(delta: float) -> void:
	var move_dir := get_move_input()
	if move_dir.length_squared() < 0.0001:
		return
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var cap := maxf(get_move_speed(), horizontal.length())
	horizontal += move_dir * air_steer_acceleration * delta
	if horizontal.length() > cap:
		horizontal = horizontal.normalized() * cap
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func start_jump() -> void:
	Sfx.play(get_tree(), Sfx.Id.JUMP)
	velocity.y = jump_velocity
	coyote_timer = 0.0


## If overspeed_decel > 0 and there is input while faster than speed, slow down at that rate.
func apply_horizontal_movement(delta: float, speed: float, overspeed_decel: float = -1.0) -> void:
	var move_dir := get_move_input()
	var target_vel := move_dir * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if move_dir.length_squared() > 0.0 else deceleration
	if overspeed_decel > 0.0 and move_dir.length_squared() > 0.0 and horizontal.length() > speed:
		rate = overspeed_decel
	horizontal = horizontal.move_toward(target_vel, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func decelerate(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(Vector3.ZERO, deceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func set_horizontal_velocity(v: Vector3) -> void:
	velocity.x = v.x
	velocity.z = v.z


## Step 9: the flat direction from the player to the locked target, or Vector3.ZERO when not locked on.
func get_lock_direction() -> Vector3:
	if not lock_on.has_target():
		return Vector3.ZERO
	var to := lock_on.get_target_position() - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return Vector3.ZERO
	return to.normalized()


## Turn smoothly toward the movement input (if any). While locked on, toward the target instead
## (so walking and dashing backward still face it).
func face_input(delta: float) -> void:
	var lock_dir := get_lock_direction()
	if lock_dir != Vector3.ZERO:
		face_direction(lock_dir, delta)
		return
	var move_dir := get_move_input()
	if move_dir.length_squared() > 0.01:
		face_direction(move_dir, delta)


func face_direction(dir: Vector3, delta: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


## 3b-2: like face_input(), but at a constant turn speed in degrees per second (a rate of 0 or less does not turn).
func face_input_rate(rate_deg: float, delta: float) -> void:
	var lock_dir := get_lock_direction()
	if lock_dir != Vector3.ZERO:
		face_direction_rate(lock_dir, rate_deg, delta)
		return
	var move_dir := get_move_input()
	if move_dir.length_squared() > 0.01:
		face_direction_rate(move_dir, rate_deg, delta)


## 3b-2: turn toward `dir` by at most `rate_deg` degrees per second (the attack turn control).
func face_direction_rate(dir: Vector3, rate_deg: float, delta: float) -> void:
	if rate_deg <= 0.0:
		return
	var target_yaw := atan2(-dir.x, -dir.z)
	var step := deg_to_rad(rate_deg) * delta
	visual.rotation.y += clampf(angle_difference(visual.rotation.y, target_yaw), -step, step)


## Turn instantly (used when an action starts).
func snap_facing(dir: Vector3) -> void:
	visual.rotation.y = atan2(-dir.x, -dir.z)


## Like snap_facing(), but while locked on the body faces the target instead of `dir` (the dodge and
## the slide still move along `dir`).
func snap_facing_lock_aware(dir: Vector3) -> void:
	var lock_dir := get_lock_direction()
	snap_facing(lock_dir if lock_dir != Vector3.ZERO else dir)


## Resize the body. The collision capsule changes instantly (sizes are set on the shape
## resource, never by scaling the node); the mesh and nose ease over crouch_transition_time.
## The bottom stays at the feet.
func set_crouched(crouched: bool) -> void:
	is_crouched = crouched
	figure.set_crouched(crouched, crouch_transition_time)
	var height := crouch_height if crouched else stand_height
	var shape := _collision_shape.shape as CapsuleShape3D
	shape.height = height
	_collision_shape.position.y = height * 0.5
	var mesh := _body_mesh.mesh as CapsuleMesh
	var nose_y := height - _nose_drop
	if _visual_tween != null:
		_visual_tween.kill()
	if crouch_transition_time <= 0.0:
		mesh.height = height
		_body_mesh.position.y = height * 0.5
		_nose.position.y = nose_y
		return
	_visual_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_visual_tween.tween_property(mesh, "height", height, crouch_transition_time)
	_visual_tween.tween_property(_body_mesh, "position:y", height * 0.5, crouch_transition_time)
	_visual_tween.tween_property(_nose, "position:y", nose_y, crouch_transition_time)


## Phase 3a-3b-1: show the mannequin (on) or the old capsule and nose (off). Stays off when the clips are missing.
func set_figure_shown(on: bool) -> void:
	var show_it: bool = on and figure.available
	figure.visible = show_it
	_body_mesh.visible = not show_it
	_nose.visible = not show_it
	# The figure has its own arms: the box arms stay hidden while it is shown (3a-3b-2).
	if sword_visual != null:
		sword_visual.set_arm_hidden(show_it)
	heal_arm.set_arm_hidden(show_it)
	if _reach_arms != null:
		_reach_arms.set_boxes_hidden(show_it)


func is_figure_shown() -> bool:
	return figure.visible


## 3c-2a PLACEHOLDER(ER clip): tell the figure how the body moves, so it plays the idle, walk, run, sprint and crouch clips
## (docs/placeholders.md P2). Once per physics frame; the figure fades back to its held pose in every state not listed.
## Locked on, the figure blends the four directions by the angle between the movement and where it faces; a dash faces its
## way. The right arm follows the clip while the sword is sheathed and at rest.
func _drive_figure_locomotion() -> void:
	var current := state_machine.current
	var walking: bool = is_on_floor() and (current is LocomotionState or current is CrouchState or current is GuardState \
			or current is DashState or current is HealState or current is AimState or current is TauntState \
			or current is AttackState)
	var dashing: bool = current is DashState
	var strafe: bool = lock_on.has_target() and not dashing
	var right_free: bool = sheathed and sword_visual != null and not sword_visual.is_busy()
	figure.drive_locomotion(walking, velocity, strafe, dashing, right_free)


## The radius of the body capsule (used by the LedgeSensor).
func get_body_radius() -> float:
	return (_collision_shape.shape as CapsuleShape3D).radius


## The body radius from the scene, whatever it is right now (a wall hug makes it slimmer).
func get_default_body_radius() -> float:
	return _default_body_radius


## Sets the body capsule's radius (on the shape resource). The wall hug uses it.
func set_body_radius(radius: float) -> void:
	(_collision_shape.shape as CapsuleShape3D).radius = radius


## True if there is room above to stand up (checked with a standing-sized capsule).
func can_stand() -> bool:
	return fits_standing_at(global_position)


## True if a standing capsule fits with its feet at the given point.
func fits_standing_at(feet: Vector3) -> bool:
	# A slimmer body (the wall hug) needs less room at the sides.
	_headroom_shape.radius = minf(HEADROOM_RADIUS, get_body_radius())
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _headroom_shape
	params.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (0.07 + _headroom_shape.height * 0.5))
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


## True if a crouched capsule fits with its feet at the given point (the low ledge climb).
func fits_crouching_at(feet: Vector3) -> bool:
	_crouch_headroom_shape.radius = minf(HEADROOM_RADIUS, get_body_radius())
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _crouch_headroom_shape
	params.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (0.07 + _crouch_headroom_shape.height * 0.5))
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func reset_air_actions() -> void:
	reach_ready = true
	wall_jumps_used = 0
	air_loop_next = null
	helm_used = false


func play_reach_arms() -> void:
	if _reach_arms != null:
		_reach_arms.play()


## Slide pose: arms held straight forward at crouched shoulder height until stop_slide_arms().
func play_choke_arms() -> void:
	if _reach_arms != null:
		_reach_arms.hold_choke(crouch_height - _nose_drop if is_crouched else stand_height - _nose_drop)


## Item 13c: the hit swing while hanging (the hit wobble along the ledge) and the arm jolt.
func play_hang_swing(direction: Vector3, recoil_scale: float) -> void:
	_reaction.start_recoil(direction, recoil_scale)
	if _reach_arms != null:
		_reach_arms.jolt()


func play_climb_arms() -> void:
	if _reach_arms != null:
		_reach_arms.hold_up()


func release_arms() -> void:
	if _reach_arms != null:
		_reach_arms.release()


func play_slide_arms() -> void:
	if _reach_arms != null:
		_reach_arms.hold_forward(crouch_height - _nose_drop)


func stop_slide_arms() -> void:
	if _reach_arms != null:
		_reach_arms.release()


## True if the equipped weapon has at least one combo attack.
## R: draw the sword (without attacking) or sheathe it. Ignored while it is still moving.
func toggle_sheathe() -> void:
	if weapon == null or carried_body != null or (sword_visual != null and sword_visual.is_busy()):
		return
	set_sheathed(not sheathed)


## Switch between sheathed and drawn (plays the arm animation). Changes no rules.
func set_sheathed(value: bool) -> void:
	if weapon == null or sheathed == value:
		return
	sheathed = value
	sheathe_idle = 0.0
	Sfx.play(get_tree(), Sfx.Id.SHEATHE if value else Sfx.Id.DRAW)
	if sword_visual == null:
		return
	if sheathed:
		sword_visual.play_sheathe()
	else:
		sword_visual.play_draw()


## Combat just happened: restart the auto-sheathe timer. Step 4 also calls this when hit.
func notify_combat() -> void:
	sheathe_idle = 0.0


## Find the Hurtbox and Combatant (both must be in the scene), and connect them (i-frames, damage, death).
func _setup_hurtbox() -> void:
	if combatant == null:
		combatant = get_node("Combatant") as Combatant
	combatant.max_health = max_health
	combatant.health = max_health
	combatant.fast_regen_on_guard = true
	if hurtbox == null:
		hurtbox = get_node("Hurtbox") as Hurtbox
	hurtbox.team = Layers.Team.PLAYER
	hurtbox.collision_layer = Layers.hurtbox_layer(Layers.Team.PLAYER)
	hurtbox.combatant = combatant
	hurtbox.is_invulnerable = func() -> bool: return invulnerable or _revive_invulnerable_left > 0.0
	for child: Node in hurtbox.get_children():
		if child is CollisionShape3D:
			_hurt_shape = child as CollisionShape3D
			break
	assert(_hurt_shape != null, "Player: the Hurtbox needs a CollisionShape3D child.")
	# This hurtbox owns its capsule (the height changes with the posture).
	_hurt_capsule = CapsuleShape3D.new()
	_hurt_capsule.radius = (_collision_shape.shape as CapsuleShape3D).radius
	_hurt_shape.shape = _hurt_capsule
	combatant.guard_facing = get_facing_direction
	combatant.damaged.connect(_on_damaged)
	combatant.hit_guarded.connect(_on_guarded)
	combatant.hit_deflected.connect(_on_deflected)
	combatant.guard_broken.connect(_on_guard_broken)
	combatant.repulsed.connect(_on_repulsed)
	combatant.posture_broken.connect(_on_posture_broken)
	combatant.died.connect(_on_died)
	_update_hurtbox()


## Resize the hurtbox for the current posture: crouched, in the air (not while hanging or climbing a
## ledge), or standing. The body capsule is not touched.
func _update_hurtbox() -> void:
	if _hurt_capsule == null:
		return
	var profile := stand_hurtbox
	var profile_name := "stand"
	var on_ledge := state_machine.current is LedgeHangState or state_machine.current is LedgeClimbState
	if is_crouched:
		profile = crouch_hurtbox
		profile_name = "crouch"
	elif not is_on_floor() and not on_ledge:
		profile = air_hurtbox
		profile_name = "air"
	var height := maxf(profile.height, _hurt_capsule.radius * 2.0)
	_hurt_capsule.height = height
	_hurt_shape.position.y = profile.bottom_offset + height * 0.5
	hurtbox_profile_name = profile_name


## Footsteps (Step 11a): one every step_distance_* metres walked on the floor, only in the walking
## states (not in actions, the air, or ledges). The gait comes from the speed (crouch, walk, run).
func _update_footsteps(delta: float) -> void:
	var current := state_machine.current
	var walking := current is LocomotionState or current is CrouchState or current is GuardState \
			or current is DashState or current is HealState or current is AimState
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if not walking or not is_on_floor() or horizontal < 0.5:
		# Standing still: the first step comes soon after setting off.
		_step_travelled = step_distance_walk * 0.6
		return
	var id := Sfx.Id.FOOTSTEP_WALK
	var stride := step_distance_walk
	if is_crouched:
		id = Sfx.Id.FOOTSTEP_CROUCH
		stride = step_distance_crouch
	elif horizontal > walk_speed * 1.5:
		id = Sfx.Id.FOOTSTEP_RUN
		stride = step_distance_run
	_step_travelled += horizontal * delta
	if _step_travelled >= stride:
		_step_travelled -= stride
		Sfx.play(get_tree(), id)


## Took a hit (the Combatant already lost the health): the combat timer restarts, the hitstop plays,
## and a hanging player is knocked off the ledge. A full posture staggers (_on_posture_broken).
func _on_damaged(hit: HitData, _amount: float) -> void:
	_reaction.start_recoil(hit.direction, 1.0)
	var hang := state_machine.current as LedgeHangState
	# Hanging: no knockback (it would push the body off the wall); a hit that drops you adds it below.
	if hang == null:
		apply_knockback(hit.direction, hit.knockback * combatant.knockback_multiplier_hit, hit.knockback_time)
	notify_combat()
	Hitstop.freeze(self, hit.hitstop)
	Hitstop.freeze(hit.attacker, hit.hitstop)
	var fx_kind := Fx.Kind.HURT
	if hit.grab:
		fx_kind = Fx.Kind.GRAB
	elif hit.perilous:
		fx_kind = Fx.Kind.PERILOUS_HIT
	Fx.play(get_tree(), fx_kind, hit.point, hit.direction)
	if hang != null and hang.take_hit(hit):
		apply_knockback(hit.direction, hit.knockback * combatant.knockback_multiplier_hit, hit.knockback_time)
	var hug := state_machine.current as WallHugState
	if hug != null:
		hug.knock_off()


## The guard blocked a hit (no health lost unless chip damage is on): a heavier wobble, an orange
## blade flash, a shorter hitstop, and the knockback. (The posture damage is added by the Combatant.)
func _on_guarded(hit: HitData, _chip: float) -> void:
	_guard_reaction(hit, false)
	apply_knockback(hit.direction, hit.knockback * combatant.knockback_multiplier_guard, hit.knockback_time)


## A perilous attack hit through the guard: the guard drops (back to Locomotion or Air) and the sword
## is knocked aside (SwordVisual.play_guard_break). The damage and the knockback are the plain hit's
## (_on_damaged ran just before this).
func _on_guard_broken(hit: HitData) -> void:
	Fx.play(get_tree(), Fx.Kind.GUARD_BREAK, hit.point, hit.direction)
	_reaction.recoil_scale = guard_break_recoil_scale
	if state_machine.current is GuardState:
		state_machine.transition_to(StateName.LOCOMOTION if is_on_floor() else StateName.AIR)
	_guard_lockout = guard_break_lockout
	if hit.grab and is_on_floor() and grab_kneel_time > 0.0:
		_reaction.start_grab_kneel()
	if sword_visual != null:
		var local_dir := Basis(Vector3.UP, visual.rotation.y).inverse() * -hit.direction
		sword_visual.play_guard_break(local_dir.x)


## A deflect: a lighter wobble, a white blade flash and the blade flick, and a softer knockback.
func _on_deflected(hit: HitData) -> void:
	_guard_reaction(hit, true)
	apply_knockback(hit.direction, hit.knockback * combatant.knockback_multiplier_deflect, hit.knockback_time)


func _guard_reaction(hit: HitData, deflect: bool) -> void:
	notify_combat()
	Hitstop.freeze(self, hit.hitstop * guard_hitstop_factor)
	Hitstop.freeze(hit.attacker, hit.hitstop * guard_hitstop_factor)
	var fx_kind := Fx.Kind.GUARD
	if deflect:
		fx_kind = Fx.Kind.DEFLECT_PERILOUS if hit.perilous else Fx.Kind.DEFLECT
	Fx.play(get_tree(), fx_kind, hit.point, hit.direction)
	_reaction.start_recoil(hit.direction, deflect_recoil_scale if deflect else guard_recoil_scale)
	if sword_visual != null:
		# Which side of the player the attacker is on, in the Visual's own frame.
		var local_dir := Basis(Vector3.UP, visual.rotation.y).inverse() * -hit.direction
		if deflect:
			sword_visual.play_deflect(hit, local_dir.x)
		else:
			sword_visual.play_guard_hit(false, local_dir.x)


## One of the player's hits was repulsed by an enemy (Step 7b): bounced back and the swing is cut
## short (applied at the start of the next physics frame, see _update_repulse). No stun: the player
## can guard, jump, or dodge at once, and the combo is back at attack 1.
func _on_repulsed(hit: HitData, distance: float) -> void:
	Fx.play(get_tree(), Fx.Kind.REPULSE, hit.point, hit.direction)
	notify_combat()
	apply_knockback(-hit.direction, distance)
	_reaction.start_recoil(-hit.direction, 1.0)
	_repulse_pending = true
	_repulse_direction = -hit.direction


## Cut the attack that was repulsed (the state machine is not touched in the middle of a sweep) and
## flick the blade. Leaving the attack resets the combo. Anything else the player is doing stays.
func _update_repulse() -> void:
	if not _repulse_pending:
		return
	_repulse_pending = false
	var current := state_machine.current
	if current is AttackState:
		state_machine.transition_to(StateName.CROUCH if is_crouched else StateName.LOCOMOTION)
	elif current is AirAttackState or current is HelmSplitterState:
		state_machine.transition_to(StateName.AIR)
	if sword_visual != null:
		var local_dir := Basis(Vector3.UP, visual.rotation.y).inverse() * -_repulse_direction
		sword_visual.play_guard_hit(true, local_dir.x)


## Posture is full: stagger as soon as nothing is in the way (a ledge climb finishes first).
func _on_posture_broken() -> void:
	_stagger_pending = true
	Fx.play(get_tree(), Fx.Kind.POSTURE_BREAK, global_position + Vector3.UP * 1.2)


func _update_stagger() -> void:
	if not _stagger_pending:
		return
	var current := state_machine.current
	if current is StaggerState or current is DeadState:
		_stagger_pending = false
		return
	if current is LedgeClimbState or current is DeathblowState:
		return
	_stagger_pending = false
	var hang := current as LedgeHangState
	if hang != null:
		hang.knock_off()
	state_machine.transition_to(StateName.STAGGER)


## Lean the body forward (radians; 0 = upright). Eases in and out. Used by the stagger and death.
func set_stagger_lean(angle: float) -> void:
	_reaction.set_lean(angle)


## Sink to a knee and sway (visual only; the capsules and the hurtbox are not touched). Used by the
## stagger, the grab and death.
func set_stagger_kneel(on: bool, sway: bool = true) -> void:
	_reaction.set_kneel(on, sway)


## Posture does not regenerate while attacking, dashing, or dodging.
func _posture_regen_paused() -> bool:
	var current := state_machine.current
	var action_state := current as ActionState
	if action_state != null:
		return action_state.action.pauses_posture_regen
	return current is DashState


## An enemy with an open deathblow window within reach and in front, or null.
func find_deathblow_target() -> Node3D:
	var best: Node3D = null
	var best_distance := deathblow_range
	var facing := get_facing_direction()
	facing.y = 0.0
	for node: Node in Enemies.all():
		var enemy := node as Node3D
		var enemy_combatant := Combatant.of(enemy)
		if enemy == null or enemy_combatant == null or not enemy_combatant.deathblow_open:
			continue
		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0.0
		var distance := to_enemy.length()
		if distance > best_distance:
			continue
		if distance > 0.01 and facing.length_squared() > 0.0001 and facing.normalized().dot(to_enemy.normalized()) \
				< cos(deg_to_rad(deathblow_facing_degrees * 0.5)):
			continue
		best = enemy
		best_distance = distance
	return best


## Item 7b: the nearest enemy this player could stealth-kill right now, or null.
func find_stealth_target() -> Node3D:
	var best: Node3D = null
	var best_distance := stealth_kill_range
	for node: Node in Enemies.all():
		var enemy := node as Enemy
		if enemy == null or not can_stealth_kill(enemy):
			continue
		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0.0
		var distance := to_enemy.length()
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## Item 7b: is `enemy` in a state that allows a stealth kill, and in reach: you on the floor, within
## stealth_kill_range and stealth_kill_height, facing it within deathblow_facing_degrees.
func can_stealth_kill(enemy: Enemy) -> bool:
	if not is_on_floor() or state_machine.current is DeadState or not enemy.can_be_stealth_killed():
		return false
	if absf(enemy.global_position.y - global_position.y) > stealth_kill_height:
		return false
	var to_enemy := enemy.global_position - global_position
	to_enemy.y = 0.0
	var distance := to_enemy.length()
	if distance > stealth_kill_range:
		return false
	var facing := get_facing_direction()
	facing.y = 0.0
	if distance > 0.01 and facing.length_squared() > 0.0001 and facing.normalized().dot(to_enemy.normalized()) \
			< cos(deg_to_rad(deathblow_facing_degrees * 0.5)):
		return false
	return true


## F4 flips `debug_undetectable`, F3 shows or hides the guards' sight cones (item 22). Debug builds only, the editor
## counts as one.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F4 and OS.is_debug_build():
		debug_undetectable = not debug_undetectable
		get_viewport().set_input_as_handled()
	elif key != null and key.pressed and not key.echo and key.keycode == KEY_F3 and OS.is_debug_build():
		EnemyAwareness.show_debug_cones = not EnemyAwareness.show_debug_cones
		get_viewport().set_input_as_handled()


## Item 7c: the nearest enemy a death from above could land on right now, or null.
func find_aerial_target() -> Node3D:
	var locked: Enemy = null
	if lock_on.has_target():
		locked = lock_on.target as Enemy
	if locked != null and can_aerial_kill(locked):
		return locked
	var best: Node3D = null
	var best_distance := aerial_kill_range
	for node: Node in Enemies.all():
		var enemy := node as Enemy
		if enemy == null or not can_aerial_kill(enemy):
			continue
		var to_enemy := enemy.global_position - global_position
		to_enemy.y = 0.0
		var distance := to_enemy.length()
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## Item 7c: in the Air state (rising or falling), above `enemy` (flat range and height band), and `enemy`
## can be aerial-killed (Enemy.can_be_aerial_killed: unaware or suspicious, not alert and not just spotted).
func can_aerial_kill(enemy: Enemy) -> bool:
	if not (state_machine.current is AirState) or is_on_floor():
		return false
	if not enemy.can_be_aerial_killed():
		return false
	var to_enemy := enemy.global_position - global_position
	var height := -to_enemy.y
	if height < aerial_kill_min_height:
		return false
	to_enemy.y = 0.0
	var locked := lock_on.has_target() and lock_on.target == enemy
	return to_enemy.length() <= (lock_on.release_range if locked else aerial_kill_range)


## Item 7c: called by AirState on a fresh attack press when find_aerial_target() found `target`.
func begin_aerial_kill(target: Node3D) -> void:
	input_buffer.clear(Actions.ATTACK)
	deathblow_target = target
	deathblow_stealth = true
	deathblow_aerial = true
	deathblow_from_hug = false
	state_machine.transition_to(StateName.DEATHBLOW)


## A fresh attack press next to a stunned enemy is a deathblow, not a normal attack.
func _try_deathblow() -> void:
	if weapon == null or not input_buffer.has_pressed(Actions.ATTACK, deathblow_buffer_time) or not is_on_floor():
		return
	var current := state_machine.current
	if current is StaggerState or current is DeathblowState or current is DeadState or current is AirState \
			or current is WallJumpState or current is LedgeHangState or current is LedgeClimbState \
			or current is AimState:
		return
	var action_state := current as ActionState
	if action_state != null and (not action_state.action.can_cancel(action_state.action_time) \
			or action_state.action.is_hit_active(action_state.action_time)):
		return
	if is_crouched and not can_stand():
		return
	var target := find_deathblow_target()
	var stealth := false
	if target == null:
		target = find_stealth_target()
		stealth = target != null
	if target == null:
		return
	input_buffer.clear(Actions.ATTACK)
	deathblow_target = target
	deathblow_stealth = stealth
	deathblow_aerial = false
	deathblow_from_hug = stealth and current is WallHugState
	state_machine.transition_to(StateName.DEATHBLOW)


## Push the player away along `direction` by about `distance` metres, easing out over `time` seconds
## (0 or less = knockback_time). See PlayerForcedMovement.
func apply_knockback(direction: Vector3, distance: float, time: float = -1.0) -> void:
	_forced.apply_knockback(direction, distance, time)


## Health hit 0 (Step 10): go to the Dead state as soon as nothing is in the way (see _update_death).
func _on_died() -> void:
	_death_pending = true


## A ledge climb finishes first (it is scripted); anything else is left at once for Dead.
func _update_death() -> void:
	if not _death_pending:
		return
	var current := state_machine.current
	if current is DeadState:
		_death_pending = false
		return
	if current is LedgeClimbState:
		return
	_death_pending = false
	state_machine.transition_to(StateName.DEAD)


## A FallZone calls this every frame the player is inside it. Starts the fall respawn: the control is
## locked, a share of max health is lost (never lethal), the hurt sound plays and the screen fades out.
## Ignored while dead, in a deathblow, or already respawning (it triggers once that ends, if the player
## is still inside the zone).
func begin_fall_respawn(damage_fraction: float) -> void:
	if _fall_phase != FallPhase.NONE or combatant.dead or _death_pending:
		return
	var current := state_machine.current
	if current is DeadState or current is DeathblowState:
		return
	drop_carried_body()
	combatant.take_flat_damage(combatant.max_health * damage_fraction, false)
	Sfx.play(get_tree(), Sfx.Id.PLAYER_HURT)
	_revive_invulnerable_left = fall_fade_out + fall_fade_in + fall_invulnerable_time
	velocity = Vector3.ZERO
	_fall_phase = FallPhase.FADE_OUT
	_fall_timer = fall_fade_out
	screen_fade.fade_out(fall_fade_out)


## Runs the fall respawn from _physics_process. Returns true while the player is locked (the rest of
## the frame is skipped).
func _update_fall_respawn(delta: float) -> bool:
	if _fall_phase == FallPhase.NONE:
		return false
	_fall_timer -= delta
	if _fall_phase == FallPhase.FADE_OUT:
		if _fall_timer <= 0.0:
			_teleport_to_spawn()
			_fall_phase = FallPhase.FADE_IN
			_fall_timer = fall_fade_in
			screen_fade.fade_in(fall_fade_in)
		return true
	if _fall_timer <= 0.0:
		_fall_phase = FallPhase.NONE
		return false
	return true


## Under black: back to the start spot and facing, velocity and knockback cleared, a normal state, and
## the camera put straight behind (no swoop).
func _teleport_to_spawn() -> void:
	global_position = _spawn_position
	velocity = Vector3.ZERO
	_forced.velocity = Vector3.ZERO
	_forced.decel = 0.0
	visual.rotation.y = _spawn_yaw
	coyote_timer = 0.0
	invulnerable = false
	reset_air_actions()
	for action in input_buffer.tracked:
		input_buffer.clear(action)
	state_machine.transition_to(StateName.LOCOMOTION)
	(camera_rig as CameraRig).snap_to_target()


## Item 18: after a death reload, start at the last rest point of this scene (if there is one), also for the
## fall respawn. The camera is put straight behind. Nothing happens before the first rest.
func _place_at_last_rest_point() -> void:
	if not RestPoints.has_last_in(RestPoints.scene_key(self)):
		return
	global_position = RestPoints.last_position
	visual.rotation.y = RestPoints.last_yaw
	_spawn_position = global_position
	_spawn_yaw = visual.rotation.y
	(camera_rig as CameraRig).snap_to_target()


## Item 18: starts the Rest state at a rest point (`RestPoint` calls this on a press).
func begin_rest(point: RestPoint) -> void:
	var rest_state := state_machine.get_state(StateName.REST) as RestState
	if rest_state == null:
		push_warning("Player: no Rest state under StateMachine; add a node named Rest and attach rest_state.gd.")
		return
	rest_state.point = point
	state_machine.transition_to(StateName.REST)


## Item 18: a rest. Full health and posture, the gourd and the resurrections back (what the arena reload gives).
func rest_refill() -> void:
	combatant.reset()
	heal_charges = max_heal_charges
	resurrections_left = max_resurrections


## Item 18: where the player starts after a death reload or a fall respawn.
func set_restart_point(point: Vector3, yaw: float) -> void:
	_spawn_position = point
	_spawn_yaw = yaw


## Called by DeadState when the player chooses to resurrect: spends one, comes back at a share of the
## max health with no posture, and is invulnerable for a moment. The enemy is not touched.
func resurrect() -> void:
	resurrections_left = maxi(resurrections_left - 1, 0)
	combatant.revive(resurrect_health_fraction)
	Fx.play(get_tree(), Fx.Kind.RESURRECT, global_position)
	_revive_invulnerable_left = resurrect_invulnerable_time
	notify_combat()


## Invulnerable for at least `seconds` more (the longer of this and what is already running). The same
## timer as the resurrection and the fall respawn.
func grant_invulnerability(seconds: float) -> void:
	_revive_invulnerable_left = maxf(_revive_invulnerable_left, seconds)


## Start the heal if `heal` was just pressed and the player is in a state that allows it (Locomotion,
## Crouch, or Dash). Crouched under a low ceiling cannot heal (it stands you up first).
func _try_heal() -> void:
	if not Input.is_action_just_pressed(Actions.HEAL):
		return
	if heal_charges <= 0 or combatant.dead or combatant.vulnerable:
		return
	if not allow_heal_at_full_health and combatant.health >= combatant.max_health:
		return
	var current := state_machine.current
	if not (current is LocomotionState or current is CrouchState or current is DashState or current is AimState \
			or _attack_allows_item()):
		return
	if is_crouched and not can_stand():
		return
	state_machine.transition_to(StateName.HEAL)


## 3b-1: an attack with a `cancel_item` time lets the gourd and the items start once that time is reached.
func _attack_allows_item() -> bool:
	var attack := state_machine.current as AttackState
	return attack != null and attack.allows_item_now()


## Steps to the next item (`cycle_item`). Works in any state except death.
func _try_cycle_item() -> void:
	if not Input.is_action_just_pressed(Actions.CYCLE_ITEM) or combatant.dead:
		return
	if item_belt.cycle():
		Sfx.play_ui(get_tree(), Sfx.Id.MENU_MOVE)


## Uses the selected item (item 11). What happens depends on the item's kind. A throwable waits to see what the
## press is: a tap (released within `hold_to_aim_time`) throws on release (`_try_throw`), a hold starts the aim
## (`_try_aim`, item 11b; `AimState` then throws on each attack press, item 11c).
func _try_use_item(delta: float) -> void:
	if combatant.dead or combatant.vulnerable or carried_body != null:
		_use_pending = false
		return
	if Input.is_action_just_pressed(Actions.USE_ITEM):
		var item := item_belt.selected()
		if item == null or item_belt.selected_count() <= 0:
			return
		match item.get_kind():
			ItemData.Kind.THROWABLE:
				_use_pending = can_start_throw()
				_use_held = 0.0
		return
	if not _use_pending:
		return
	if Input.is_action_pressed(Actions.USE_ITEM):
		_use_held += delta
		if _use_held >= hold_to_aim_time:
			_use_pending = false
			_try_aim()
	else:
		_use_pending = false
		_try_throw()


## True in the states a throw or an aim can start from (Locomotion, Crouch, Dash); a crouch needs headroom to stand.
func can_start_throw() -> bool:
	var current := state_machine.current
	if not (current is LocomotionState or current is CrouchState or current is DashState or _attack_allows_item()):
		return false
	return not is_crouched or can_stand()


## Item 16: can a held `interact` start a body throw now? (The checks `_try_aim()` makes for a carried body.)
func can_aim_body() -> bool:
	return carried_body != null and body_throw != null and not _pickup_waiting and _put_left <= 0.0 and can_start_throw()


## Item 16 (hints): would a jump press in mid-air be a wall jump right now? The checks of `try_air_jump()`, nothing used up.
func can_wall_jump_now() -> bool:
	if coyote_timer > 0.0 or is_near_ground() or wall_jumps_used >= max_wall_jumps:
		return false
	return not ledge_sensor.find_wall().is_empty()


## Starts the throw (a tap).
func _try_throw() -> void:
	if can_start_throw():
		state_machine.transition_to(StateName.THROW)


## The taunt (Phase 2 item 11.5): `taunt` on the ground from Locomotion or Crouch (a crouch needs headroom to stand),
## once the cooldown is over. `TauntState` does the rest.
func _try_taunt(delta: float) -> void:
	_taunt_cooldown_left = maxf(_taunt_cooldown_left - delta, 0.0)
	if not Input.is_action_just_pressed(Actions.TAUNT):
		return
	if carried_body != null:
		return
	if combatant.dead or combatant.vulnerable or _taunt_cooldown_left > 0.0 or not is_on_floor():
		return
	var current := state_machine.current
	if not (current is LocomotionState or current is CrouchState):
		return
	if is_crouched and not can_stand():
		return
	_taunt_cooldown_left = taunt_cooldown
	state_machine.transition_to(StateName.TAUNT)


## Starts the aim (a hold), if the item is still a throwable with some left.
func _try_aim() -> void:
	if carried_body != null:
		if can_aim_body():
			state_machine.transition_to(StateName.AIM)
		return
	var item := item_belt.selected()
	if item == null or item_belt.selected_count() <= 0 or item.get_kind() != ItemData.Kind.THROWABLE:
		return
	if can_start_throw():
		state_machine.transition_to(StateName.AIM)


## One of the player's attacks connected: restart the auto-sheathe timer and freeze the player and the fighter it hit
## (3c-1; the other fighters hit by the same swing are frozen by `ActionState`).
func on_hit_landed(hit: HitData) -> void:
	notify_combat()
	Hitstop.freeze(self, hit.hitstop)
	Hitstop.freeze(hit.target, hit.hitstop)
	var fx_kind := Fx.Kind.HIT_LANDED
	if hit.outcome == HitData.Outcome.DEFLECT:
		fx_kind = Fx.Kind.DEFLECT
	elif hit.outcome == HitData.Outcome.GUARD:
		fx_kind = Fx.Kind.GUARD
	elif hit.action != null and hit.action.charge_time > 0.0:
		fx_kind = Fx.Kind.HIT_LANDED_CHARGED
	Fx.play(get_tree(), fx_kind, hit.point, hit.direction)


## Called by ActionState when any action starts. Attacks leave the sword drawn; attacks and
## dodges restart the auto-sheathe timer.
func on_action_started(kind: ActionData.Kind) -> void:
	if kind == ActionData.Kind.ATTACK:
		sheathed = false
		notify_combat()
	elif kind == ActionData.Kind.DODGE:
		notify_combat()


func _update_auto_sheathe(delta: float) -> void:
	if sheathed or weapon == null or auto_sheathe_time <= 0.0:
		return
	var current := state_machine.get_current_name()
	if current != StateName.LOCOMOTION and current != StateName.CROUCH:
		return
	sheathe_idle += delta
	if sheathe_idle >= auto_sheathe_time:
		set_sheathed(true)


func has_combo() -> bool:
	return weapon != null and not weapon.combo.is_empty()


## True if there is floor a short way ahead in dir (within max_drop below the feet).
## Attacks use it to stop a lunge before an edge.
func has_ground_ahead(dir: Vector3, distance: float, max_drop: float = 0.5) -> bool:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return true
	var from := global_position + flat.normalized() * distance + Vector3.UP * 0.3
	var to := from + Vector3.DOWN * (0.3 + max_drop)
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## True if the floor is within air_jump_ground_margin below the feet.
func is_near_ground() -> bool:
	var from := global_position + Vector3.UP * 0.05
	var to := global_position + Vector3.DOWN * air_jump_ground_margin
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Handles a jump press made in mid-air (after the coyote jump had its chance).
## Returns true if a wall jump should start (wall_normal is set; the caller transitions
## to WallJump). Otherwise it may play the reach, and returns false.
func try_air_jump() -> bool:
	if not input_buffer.has_pressed(Actions.JUMP) or is_near_ground():
		return false
	input_buffer.consume(Actions.JUMP)
	if wall_jumps_used < max_wall_jumps:
		var wall := ledge_sensor.find_wall()
		if not wall.is_empty():
			wall_normal = wall["normal"]
			return true
	if reach_ready:
		reach_ready = false
		play_reach_arms()
		Sfx.play(get_tree(), Sfx.Id.REACH)
	return false


## Turn the body collision on or off (used during the scripted ledge climb).
func set_body_collision_enabled(enabled: bool) -> void:
	_collision_shape.set_deferred("disabled", not enabled)
