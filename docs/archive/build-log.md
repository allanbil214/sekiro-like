# Build log (history, append-only)

> **Not pasted into new chats, and not read by Claude unless asked** (see `docs/work-agreements.md`, section 7). It holds the detailed "what exists" notes of every finished step, plus design text, tables, and numbers moved out of the handoff and the Step 3 spec on 2026-10-07 to keep those short. Where this file and the code disagree, the code (and the `.tres` files) win.
>
> **New entries are appended at the very end** (newest last) when a step is finished. Format: `### Step <id>: what exists (<date>)` with the decisions, the files, the rules that are not obvious from the code, what was not done, and anything noticed but not fixed.

---

## Part 1: Step logs (moved from the handoff, section 10)

### Step 1: what exists

**Files**
- `scripts/player/player.gd`: attached to the Player root. Restructured in Step 2a (see below).
- `scripts/player/camera_rig.gd`: attached to CameraRig. `top_level = true` so it doesn't inherit the player's rotation; follows the player with smoothing at `follow_height`; mouse look (captured; Esc releases, click recaptures) plus right-stick look; pitch clamped; the SpringArm excludes the player's body.
- `scenes/player/player.tscn`, `scenes/arena/test_arena.tscn` (set as the main scene)

**Player scene tree**
```
Player (CharacterBody3D, root, player.gd)
  CollisionShape3D (CapsuleShape3D r=0.4 h=1.8, position y=0.9)
  Visual (Node3D)
    Body (MeshInstance3D, CapsuleMesh)
    Nose (MeshInstance3D, BoxMesh, marks the front)
  CameraRig (Node3D, camera_rig.gd)
    SpringArm3D (length 4.0, SphereShape3D r=0.2)
      Camera3D
```

**Test arena:** Floor plus color-coded test blocks (low, tight, and high platforms, a pillar, walls), a DirectionalLight3D, a WorldEnvironment, and the Player instance. Block heights are sized to the current jump numbers, so they need resizing if the jump is retuned.

### Step 2a: what exists

**Files**
- `scripts/player/player.gd`: `class_name Player`. Shared data and helpers (`get_move_input`, `get_move_speed`, `get_facing_direction`, `apply_gravity`, `start_jump`, `apply_horizontal_movement`, `decelerate`, `set_horizontal_velocity`, `face_input`, `face_direction`, `snap_facing`), the `invulnerable` flag, and `coyote_timer`. It owns the `InputBuffer` and each physics frame does: buffer tick, state update, `move_and_slide()`. Keeps `walk_only` for guard.
- `scripts/player/input_buffer.gd`: `InputBuffer` (RefCounted). Tracks `jump` and `dodge` presses for 0.15s; `consume(action)` uses a press up.
- `scripts/player/states/`:
  - `state.gd` (base class), `state_machine.gd` (`setup`, `start`, `physics_update`, `transition_to(&"Name")`; states are its child nodes, found by node name)
  - `action_state.gd`: generic state that runs any `ActionData` on the action clock (iframes, movement burst, cancel/lock windows, hooks `_on_action_enter/_update/_finished/_exit`)
  - `locomotion_state.gd`, `air_state.gd` (gravity, air control, coyote jump, landing), `dodge_state.gd` (extends `ActionState`), `dash_state.gd`
- `resources/action_data.gd`, `actions/dodge.tres`
- `scripts/ui/debug_overlay.gd`: label showing state, invulnerable, and action time; blue body tint during i-frames (`tint_on_iframes`, debug only).

**Player scene additions**
```
Player
  (Step 1 nodes unchanged)
  StateMachine (state_machine.gd, Initial State = Locomotion)
    Locomotion (locomotion_state.gd)
    Air (air_state.gd)
    Dodge (dodge_state.gd, Action = actions/dodge.tres)
    Dash (dash_state.gd)
  DebugOverlay (CanvasLayer, debug_overlay.gd)
```
State node names must match exactly (`Locomotion`, `Air`, `Dodge`, `Dash`), since transitions use them.

**Not used in 2a:** `buffer_window` and `active_hit` in `ActionData` (3a-1 now uses both for attacks; hitboxes are Step 4).

### Step 2b: what exists

**Files**
- `scripts/player/player.gd` additions: exports `crouch_speed` (2.0), `crouch_decel` (12.0), `crouch_transition_time` (0.12), `stand_height` (1.8), `crouch_height` (1.1), `crouch_is_hold` (false = toggle); `is_crouched`; `set_crouched(bool)` (collision capsule instant; mesh and Nose tween); `can_stand()` (headroom check with a physics shape query in code, so there is **no HeadCheck node**); `apply_horizontal_movement(delta, speed, overspeed_decel = -1.0)` gained an optional third argument that slows you at that rate when you have input and are faster than `speed`.
- `scripts/player/states/crouch_state.gd`: `CrouchState`. Toggle or hold exit (needs headroom), jump and dodge need headroom (otherwise discarded), falling off the floor goes to Air, moves at `crouch_speed` with `crouch_decel`.
- `scripts/player/states/slide_state.gd`: `SlideState` (extends `ActionState`). Enters crouched, direction = movement input else facing, ends in Crouch, cancel to jump/dodge after the locked window (needs headroom), stands up on any exit other than to Crouch.
- `actions/slide.tres`: `ActionData`, kind `OTHER`, duration 0.6, locked until 0.35, i-frames 0.05 to 0.28, move 18 (tuned by the user) over 0 to 0.45 fading to 0.3x. **Tuned values are kept (work agreement, section 3).**
- `locomotion_state.gd`: `crouch` just pressed goes to Crouch. `dash_state.gd`: `crouch` just pressed with input goes to Slide.

**Player scene additions**
```
StateMachine
  (Step 2a states unchanged)
  Crouch (crouch_state.gd)
  Slide (slide_state.gd, Action = actions/slide.tres)
```
State node names must match exactly (`Crouch`, `Slide`).

### Step 2c: what exists

**Files**
- `scripts/player/player.gd` additions: exports `wall_jump_boost` (1.2), `wall_range` (0.6), `max_wall_jumps` (2), `wall_input_threshold` (user-tuned, see placeholders), `air_jump_ground_margin` (0.3); state `reach_ready`, `wall_jumps_used`, `wall_normal`; `reset_air_actions()` (called on landing), `play_reach_arms()`, `is_near_ground()` (ray down), `find_wall()` (8 horizontal rays at chest height, ignores non-vertical surfaces, returns the nearest `{normal, distance}`), `try_air_jump()` (consumes the buffered jump press; returns true if a wall jump should start, otherwise may play the reach).
- `scripts/player/states/air_state.gd`: after the coyote jump check, a jump press with no coyote calls `try_air_jump()` and transitions to `WallJump` when it returns true; landing calls `reset_air_actions()`.
- `scripts/player/states/wall_jump_state.gd`: `WallJumpState` (extends `ActionState`). Picks the direction from the input versus `wall_normal`, sets `velocity.y`, multiplies the action's horizontal move speed by `wall_jump_boost`, counts the jump, restores the reach. After the locked window another wall jump (or reach) can chain. Finishes into Air; landing resets and goes to Locomotion.
- `scripts/player/reach_arms.gd`: `ReachArms` (Node3D, debug-grade). Builds two box arms in code; `play()` raises them (up and forward, `raised_angle_deg` 140) for about 0.3s. `hold_forward(shoulder_y)` swings them straight forward (`slide_angle_deg`, 90) and holds until `release()`; the slide uses this (via `Player.play_slide_arms()` / `stop_slide_arms()`, called from `SlideState` on enter and exit, with the shoulder at crouched height).
- `actions/wall_jump.tres`: `ActionData`, kind `WALL_JUMP`. **Tuned values are kept (work agreement, section 3).**
- `scripts/ui/debug_overlay.gd` additions: lines `Reach`, `Wall jumps n/max`, `vel.y`, and a translucent wall-range ring at chest height (`show_wall_range` export).

**Player scene additions**
```
Visual
  ReachArms (Node3D, reach_arms.gd)
StateMachine
  (earlier states unchanged)
  WallJump (wall_jump_state.gd, Action = actions/wall_jump.tres)
```
State node names must match exactly (`WallJump`).

### Step 2d: what exists

**Files**
- `scripts/player/player.gd` additions (Ledge export group): `ledge_zone_min/max` (1.4/2.1), `ledge_input_threshold` (0.5), `ledge_max_rise_speed` (99), `ledge_requires_jump_held` (true), `ledge_standoff` (0.1), `hang_center_depth` (1.2), `hang_gap` (0.05), `hang_hand_spacing` (0.3), `hang_adjust_max` (0.6), `hang_snap_time` (0.1), `shimmy_speed` (1.5), `ledge_regrab_cooldown` (0.3). Functions: `find_ledge()` (needs airborne, input toward the wall, wall from `find_wall()`, ray down for the ledge top, ray at the landing spot, standing-capsule fit, plus the hang spot), `try_ledge_grab()`, `ledge_grab_state()` (LedgeHang if interact held/buffered and the hang spot fits, else LedgeClimb), `probe_hang_ledge()` (while hanging: ledge top, both hands, stand spot and fit), `can_hang_at()`, `_hands_on_ledge()`, `_find_hang_spot()`, `_fits_standing_at()` (shared with `can_stand()`), `set_body_collision_enabled()`, `play_climb_arms()` / `release_arms()`. State: `ledge_stand_pos`, `ledge_wall_normal`, `ledge_hang_pos`, `ledge_hang_fits`, `ledge_top_y`, `ledge_block_until_ms`, `wall_jump_forced_away`. `find_wall()` also returns the hit position.
- `scripts/player/states/ledge_climb_state.gd`: `LedgeClimbState` (extends `ActionState`). Moves the position directly (rise, then forward) with collision off; resets air actions and goes to Locomotion at the end; `rise_fraction` export (0.6).
- `scripts/player/states/ledge_hang_state.gd`: `LedgeHangState` (extends `State`). Snaps into the hang spot, then: crouch = drop, jump = leap (sets `wall_jump_forced_away` and goes to WallJump), fresh interact = climb (re-probes the ledge and room), otherwise shimmy. `knock_off()` hook for Step 4.
- `actions/ledge_climb.tres`: `ActionData`, kind `LEDGE_CLIMB`, duration 0.6, locked until 0.6. **Tuned values are kept (work agreement, section 3).**
- `scripts/player/states/air_state.gd` and `wall_jump_state.gd`: call `try_ledge_grab()` first (before air jumps) and transition to `ledge_grab_state()`. `wall_jump_state.gd` honors `wall_jump_forced_away` (always away, not counted).
- `scripts/player/input_buffer.gd`: now also tracks `interact`.
- `scripts/player/reach_arms.gd`: added `hold_up()` (arms straight up, `climb_angle_deg` 180), used by hang and climb.
- `scripts/ui/debug_overlay.gd`: `Ledge: found` line and a magenta marker at the last found ledge edge (`show_ledge_marker`).

**Player scene additions**
```
StateMachine
  (earlier states unchanged)
  LedgeClimb (ledge_climb_state.gd, Action = actions/ledge_climb.tres)
  LedgeHang (ledge_hang_state.gd)
```
State node names must match exactly (`LedgeClimb`, `LedgeHang`).

**Not done in 2d:** corners (Phase 2), real hang/shimmy/climb animation, hang on moving geometry, the hit-knock-off logic (Step 4 calls `knock_off()`).

**Not done in 2c:** real reach animation, wall slide/cling, wall run, slanted walls, sound.

**Not done in 2b:** the shrunk hurtbox (Step 4, `HurtboxProfile`), the crouch and slide attacks (Step 3b, see the spec).

### Step 3a-1: what exists

**Files**
- `resources/weapon_data.gd`: `WeaponData`: `display_name`, `combo: Array[ActionData]`, `blade_length`, `blade_thickness` (used as the blade's **width**), `rest_pose` (a clock pose). `weapons/katana.tres` is the first weapon. **Tuned values are kept (work agreement, section 3).**
- `resources/action_data.gd`: added `swing_windup`, `swing_end`, `swing_follow` (clock poses); `buffer_window` is now used.
- `actions/attack_1.tres` to `attack_5.tres`: `ActionData`, kind `ATTACK`, first-guess timings from the spec (section 4), `locked_until` = `active_hit.y`, damage 0. **Tuned values are kept (work agreement, section 3).**
- `scripts/player/states/attack_state.gd`: `AttackState` (extends `ActionState`), see below.
- `scripts/player/sword_visual.gd`: `SwordVisual`, the arm-swing placeholder sword, see below.
- `scripts/player/player.gd` additions: `weapon` export (Combat group), `sword_visual` (found in `_ready`, `setup(weapon)` called there), `has_combo()`, `has_ground_ahead(dir, distance, max_drop)` (short ray down ahead of the feet).
- `scripts/player/input_buffer.gd`: also tracks `attack`. `locomotion_state.gd`: a buffered attack press (with `has_combo()`) goes to `Attack`. `scripts/ui/debug_overlay.gd`: a `Combo: n/5 (wind-up | ACTIVE | recovery)` line plus `Buffer / Chain / Queued` flags.

**`AttackState` rules (as built)**
- Entering from any state except `Attack` picks attack 1; entering from `Attack` (a chain) picks the next index, wrapping to 1 after attack 5. Exiting to anything except `Attack` resets the counter and sends the sword back to rest.
- **Chain:** a press is accepted inside `buffer_window` (the input buffer also remembers a press up to 0.15s before the window opens) and marks the attack `_queued`. The chain happens at `cancel_window.x` (or `locked_until` if the cancel window is unset), never while the active window is open.
- **Cancels:** dodge, jump, and crouch cancel at any time except while the hit window is active (wind-up and recovery both cancel), and only on the floor. `ActionData.can_cancel()` is not used for these.
- **Steering and lunge:** before `active_hit.x` the body turns toward the movement input (`face_input`). The lunge direction is the movement input at the attack start (no input: facing, at `no_input_lunge_factor` = 0.5). While steering is allowed, a held input keeps updating the lunge direction; releasing keeps the last direction and strength. Both lock when the active window starts. `_can_steer()` is a hook that returns true; **Step 9 (lock-on) makes it return false while locked on**.
- **Ledge stop:** if there is no floor within `ledge_check_distance` (default 0.4 m, 1.4 m in the scene; since 3a-2 also at least `ledge_check_time` = 0.14 s of travel at the lunge speed) ahead in the lunge direction, the lunge is dropped for that frame, so an attack never carries you off a ledge. Leaving the floor any other way just continues the action with gravity, and it ends in Air via Locomotion.
- The action finishes into `Locomotion`. No hitboxes or damage yet.

**`SwordVisual`: the arm swing (placeholder)**
- A **clock pose** (hour, radius, forward) is converted to an **aim point** (radius and forward multiplied by `pose_scale`). The poses say where the **tip** should pass.
- An arm (a gray box, `show_arm`) points from the right shoulder to the aim point; the hand sits `arm_reach` along it; the blade extends from the hand and bends at the **wrist angle** (positive = the tip trails behind the travel direction, cocked; negative = leading). The wrist goes from `wrist_start_angle` (50) to `wrist_end_angle` (-10) across the slash.
- The aim point travels along a path bowed forward in the middle (**slash arc**, `slash_arc_forward` 0.5; `windup_arc_forward` 0.25 for the wind-up and follow-through), so a slash sweeps through the space in front of the player.
- The cutting edge (a bright yellow strip on the blade) **leads along the direction of travel** (the path's tangent). `flip_edge` flips it if it is on the wrong side.
- Segments over `action_time`: previous pose to wind-up (blends from the captured current pose, so chains are smooth), wind-up to end (the active window, fast ease; the blade turns red), end to follow-through (a small wrist overshoot, then it relaxes toward the rest direction by `follow_relax`). With no chain the sword returns to rest over `rest_return_time`.
- **Body twist (visual only, added after the first arm swing):** the whole arm swing and the capsule's `Nose` rotate around the body's vertical axis, driven by the clock poses (a pose's left/right position sets the twist: `max_twist_degrees` 30 x sin(hour angle), so 3:00 and 9:00 are the strongest, 1:00 and 7:00 half). The twist builds in the wind-up, swings with the slash on the same eases, eases to the follow-through side, and returns to neutral at the end of the combo; a chain starts from the previous twist. The **arms lead the torso**: the arm swing turns `arm_twist_factor` (2.0 now; first 1.5) times the body twist, while the nose follows the plain body twist. It does not change facing, lunge, steering, or any hitbox (Step 4 decides what the hitbox follows). The nose position is only touched in x and z (the crouch code owns its y).
- The first version put the **grip** at the pose point; the sword then hung beside the body and swung up and down. The fix was to make the poses aim the arm and keep the tip path in front of the player. Keep this in mind when tuning: the real tip only roughly follows the aim point (the blade bends at the wrist).

**Tuning history (3a-1):** the attacks were slowed twice (about 1.2x each time, with the chain window opening a little later), the lunge distance was raised about 3x in total (attack 5 moves at 11.5 m/s), and attack 1 got a longer wind-up (souls-like opener; this applies when the combo loops back to it). Attack 1's wind-up pose is also drawn back further. The current numbers are in the Step 3 spec, section 4.

**Hooks for later:** `_can_steer()` (Step 9); `active_hit` becomes the hitbox window and `damage` / `posture_damage` get real values in Step 4; guard joins the cancel list in Step 5; 3b adds the variants (and the dash, crouch, slide, and jump attacks go on `WeaponData` next to `thrust`).

**Not done in 3a-1:** hold and thrust (built later, see 3a-2 below), dash, crouch, slide, and jump attack variants (3b), hitboxes and damage (Step 4), the lock-on steering lock (Step 9), a real sword mesh and animation.

**Player scene additions**
```
Visual
  SwordVisual (Node3D, sword_visual.gd)
StateMachine
  (earlier states unchanged)
  Attack (attack_state.gd)
```
Set **Weapon** on the `Player` root to `weapons/katana.tres`. State node names must match exactly (`Attack`).

### Step 3a-2: what exists

**Files** (editor step: on `weapons/katana.tres` set **Thrust** to `actions/thrust.tres`)
- `actions/thrust.tres`: `ActionData`, right-aligned poses. Windup (the charge pose) `(3, 0.5, -0.4)`, end `(2.5, 0.35, 1.3)`, follow `(3.5, 0.5, 0.2)`; `blade_aims_at_end` true, `twist_scale` 0.25; timings and charge values are in the placeholder table. **Tuned values are kept (work agreement, section 3).**
- `resources/action_data.gd`: added `blade_aims_at_end`, `twist_scale`, and a Charge group (`charge_time`, `charge_damage_max`, `charge_lunge_max`). `charge_time` 0 means the action cannot be charged.
- `resources/weapon_data.gd`: added `thrust: ActionData` (empty = no thrust, attacks behave as before).
- `scripts/player/states/attack_state.gd`: new `Phase` enum (NORMAL, WAITING, CHARGING), `hold_extra_time`, `ledge_check_time`, `damage_multiplier` (stored for Step 4), see the rules below.
- `scripts/player/sword_visual.gd`: `begin_charge()`, `update_charge()`, `_update_thrust()`, `_thrust_pose()`, a charge glow (emission), and a `mirror` flag for left-aligned poses.

**Rules as built**
- **Decision point:** when the action clock reaches `active_hit.x` (the end of the wind-up). Attack button still held (and the weapon has a chargeable thrust) = charge; released = the normal slash. `hold_extra_time` (default 0) optionally waits that long for a release before charging, for sloppy taps.
- **Charging:** the action clock is frozen `0.001` s before the hit window opens, so steering and the dodge, jump, and crouch cancels still work (they are blocked inside the hit window). There is no lunge while charging (the player decelerates). Charge time counts real seconds.
- **Fire:** on release, or automatically at `charge_time` (0.6 s). The slot's slash is swapped for `weapon.thrust` (the action clock restarts at 0). Damage multiplier = lerp(1, `charge_damage_max`, charge fraction); lunge multiplier = lerp(1, `charge_lunge_max`, fraction). The lunge direction and no-input half strength use the input at the moment of firing.
- **Combo counter:** the swap does not change `combo_index`, so a thrust takes the step it falls on (attack 1, then a held chain is a thrust at step 2, and the next tap is attack 3; a thrust from idle is step 1, so the next tap is attack 2). Chaining out of a thrust uses the normal chain rules (buffer window, chain from `cancel_window.x`).
- **Zigzag connects to the combo:** a thrust chained from a slash starts on the side where that slash ended (from its `swing_end` pose: lateral = sin(hour x 30 deg), below -0.1 is left, else right; so attacks 1 and 4 end left, 2, 3, and 5 end right). Chained from a thrust it takes the opposite side. Started from idle it is right. Leaving the `Attack` state resets it.
- **Left side:** the right-aligned poses mirrored (clock hour becomes 12 minus hour), including the body twist direction.
- **Ledge stop:** now speed-aware: the larger of `ledge_check_distance` and `ledge_check_time` (0.14 s) of travel at the current lunge speed.
- **Sword visuals:** thrust style = the hand moves in a straight line from the wind-up pose to the end pose, the blade always points at the end pose, and the edge faces down. While charging, the sword pulls back from the slash wind-up pose to the thrust wind-up pose over `charge_blend_time` (0.15 s) and the blade blends toward `charge_color` (orange) and glows more as the charge fills; the glow fades after firing.
- **Known quirk:** the slash's lunge window usually starts before the decision point, so there can be a small step forward before a charge begins.
- **Debug overlay:** the combo line shows `THRUST` when firing, plus `Charge: x / 0.60 (left or right next)` while charging and the damage and lunge multipliers after firing.

**Not done in 3a-2:** the dash, crouch, slide, and jump variants (3b), sheathing (3c), hitboxes and damage (Step 4).

### Step 3b-1: what exists

**Discussion and decisions (2026-10-06):** 3b was split into four phases (3b-1 dash, 3b-2 crouch and slide, 3b-3 air tap loop, 3b-4 helm splitter), and the user answered the open items: variants count as step 1; no charge on any variant hold (the hold just selects a different attack); dash lunge keeps the dash direction at a fixed speed; slide attacks after the slide's locked window; stand up after a crouch attack only with headroom; unlimited air attacks while airborne, the helm splitter once per airtime; **no hover**; helm splitter gravity 2.5x with the blade held at 6:00 until landing and a cancellable wind-down; the sword lowers with the body when crouched. The full list is in the spec, section 6.

**Files** (editor step: on `weapons/katana.tres` set **Dash Attack** (Variants group) to `actions/dash_attack.tres`)
- `actions/dash_attack.tres` and `actions/dash_thrust.tres`: `ActionData`. The dash slash's Hold Action points at the dash thrust. Numbers are in the placeholder table. **The user tuned them (dash slash move_speed 15, dash thrust 20, and the dash slash now runs 2:45 to 8:45). Tuned values are kept (work agreement, section 3).**
- `resources/action_data.gd`: new `hold_action` (what replaces the attack when held at the decision point; `charge_time` 0 on it = swapped in at once, above 0 = charged first; empty on a ground combo attack = the weapon's thrust; empty on a variant = no hold).
- `resources/weapon_data.gd`: new Variants group with `dash_attack`.
- `scripts/player/states/attack_state.gd`: `try_start_variant(variant)` (other states hand over a variant), `_is_variant`, `_hold_target()`, `_begin_hold()`; a variant counts as `combo_index` 0 so the next chained tap is attack 2; the debug line shows `VARIANT` for it.
- `scripts/player/states/dash_state.gd`: an attack press (after the jump check) calls `AttackState.try_start_variant(weapon.dash_attack)`. The dash does not restart after the attack even if dodge is held (a dash only starts from a dodge).

**Ledge stop with big lunges:** the lunge looks ahead `ledge_check_time` (0.14 s) of travel at the lunge speed, so at 20 m/s (up to 1.4x for a charged thrust) it checks about 3 to 4 m ahead and stops earlier near edges. Lower `ledge_check_time` on `StateMachine/Attack` (for example 0.08) if that is too cautious.

**Not done in 3b-1:** crouch and slide attacks (3b-2), the air tap loop (3b-3), the helm splitter (3b-4), sheathing (3c), hitboxes and damage (Step 4).

### Step 3b-2: what exists

**As built (differs from the first design):** crouch and slide attacks are a **two-attack left/right loop that keeps you crouched**, not a single attack that stands you up.
- **Tap loop:** attack A (3:00 to 9:00, left-ward) then attack B (9:00 to 3:00, right-ward), then back to A, as long as you keep tapping. After each one you end back in Crouch. Every crouch or slide tap counts as combo step 1 (`combo_index` 0).
- **Hold = the upward slash** (`crouch_upward`, authored 8:00 to 1:00): held at the end of any crouch attack's wind-up it replaces that attack (no charge). It **stands you up** (needs headroom; without headroom a hold does nothing) and the next chained tap is **attack 1** of the standing combo.
- **Alternating sides (2026-10-06):** the upward slash starts on the side where the previous attack ended: after A (ended left) from the left (8:00 to 1:00, as authored); after B (ended right) from the right (mirrored, 4:00 to 11:00); from crouch idle or slide, or in the first attack of the loop after idle, from the right (mirrored). Thrusts are authored right-handed and mirrored to start left; a slash-style hold action (no `blade_aims_at_end`) is authored left-handed and mirrored to start right.
- **Slide attack:** the same loop, allowed after the slide's locked window (`SlideState` calls `try_start_variant(weapon.crouch_attack)` like `CrouchState`).
- **Hold detection fix (2026-10-06):** `AttackState` tracks `_released`, true once the attack button was up at any time since the action began. A hold counts only if the button was never released, so rapid clicks are no longer read as a hold (previously only `is_action_pressed` at the decision point was checked, so a second quick click landing at the decision point counted). It applies to every attack, including the ground and dash thrusts.
- **Crouch visuals:** `SwordVisual._update_crouch_drop` lowers the whole arm swing with the body while crouched (stored aim points shift by the same amount, so nothing jumps).

**Files** (editor step: on `weapons/katana.tres` set **Crouch Attack** (Variants group) to `actions/crouch_attack_a.tres`)
- `actions/crouch_attack_a.tres`, `crouch_attack_b.tres`, `crouch_upward.tres`: `ActionData`. A's Combo Next = B, A's and B's Hold Action = the upward slash. **Tuned values are kept (work agreement, section 3).**
- `resources/action_data.gd`: new `combo_next` (next attack in a variant loop; empty = back to the first). `resources/weapon_data.gd`: `crouch_attack`.
- `scripts/player/states/attack_state.gd`: `_crouch_context` (the attack plays crouched; it ends in Crouch, and leaving to anything but Crouch stands you up), `_rose` (after the upward slash the next chain is attack 1), `_released`, `_hold_target()` (headroom check), crouched cancels follow the Crouch state's rules (dodge and jump need headroom, crouch press or hold-release stands you up).
- `scripts/player/states/crouch_state.gd` and `slide_state.gd`: an attack press starts the crouch loop.
- `scripts/player/sword_visual.gd`: the slash path now honors the `mirror` flag (poses and body twist), used by the mirrored upward slash.

**Values in the snapshot (2026-10-06, seconds and m/s):**

| Action | duration | active_hit | cancel_window | buffer_window | lunge | poses |
|---|---|---|---|---|---|---|
| crouch A | 0.80 | 0.20 to 0.34 | 0.45 to 0.80 | 0.10 to 0.80 | 6.0, 0.05 to 0.30 | 3:00 to 9:00, follow 9:30 |
| crouch B | 1.25 | 0.18 to 0.32 | 0.95 to 1.25 | 0.10 to 1.25 | 6.0, 0.05 to 0.28 | 9:00 to 3:00, follow 3:30 |
| crouch upward | 1.00 | 0.22 to 0.38 | 0.55 to 1.00 | 0.12 to 1.00 | 6.0, 0.05 to 0.35 | 8:00 to 1:00, follow 1:30 |

**Not done in 3b-2:** the air tap loop (3b-3), the helm splitter (3b-4), sheathing (3c), hitboxes and damage (Step 4).

### Step 3b-3: what exists

- **Behavior:** attack pressed while airborne starts the **air tap loop**: A (2:00 to 10:00), then B (10:00 to 2:00), then A again, with no limit while airborne. It is its own state, `AirAttack` (`AirAttackState extends ActionState`), not part of `AttackState`.
- **Loop reset:** `Player.air_loop_next` holds the next attack of the loop (empty = the first); `reset_air_actions()` clears it, so **landing restarts the loop at A**. A swing that ends without a chain does not reset it.
- **Movement:** no lunge, no hover. Normal air control (`apply_horizontal_movement`), gravity as usual, and the body turns toward the movement input during the wind-up. After landing mid-swing the player brakes with `decelerate`.
- **Entry:** `AirState` starts it on an attack press (buffered press) when `is_near_ground()` is false. Near the ground the press stays buffered, so landing makes it a normal ground attack. Coyote time and falling off a ledge count as airborne. **Not hooked up:** attacking during the wall-jump action itself (it works once the wall jump has finished and you are in `Air`).
- **Cancels (outside the hit window):** in the air a ledge grab and jump (wall jump, else the mid-air reach); on the floor dodge, jump, and crouch. **No air dodge.**
- **Landing mid-swing:** the swing plays out. A tap queued by then continues the ground combo at **attack 2** through `AttackState.try_continue_combo(1)` (an air attack counts as combo step 1); with no queued tap it ends in Locomotion.
- **Hold in the air:** the helm splitter (built in 3b-4, see below).

**Files** (editor steps: under `Player/StateMachine` add a `Node` named exactly `AirAttack` with `scripts/player/states/air_attack_state.gd`; on `weapons/katana.tres` set **Air Attack** (Variants group) to `actions/air_attack_a.tres`)
- `actions/air_attack_a.tres` and `air_attack_b.tres`: `ActionData` (A's Combo Next = B). Hold Action = the helm splitter since 3b-4. **Tuned values are kept (work agreement, section 3).**
- `scripts/player/states/air_attack_state.gd` (new), `air_state.gd` (the entry), `attack_state.gd` (`try_continue_combo`, `_pending_index`), `player.gd` (`air_loop_next`, cleared in `reset_air_actions`), `resources/weapon_data.gd` (`air_attack`), `scripts/ui/debug_overlay.gd` (shows the air attack line).

**First-guess values** (A and B alike, seconds; **both now run at Speed Scale 1.5 since 3b-4**): duration 0.85, locked_until 0.32, active_hit 0.18 to 0.32, cancel_window 0.45 to 0.85, buffer_window 0.10 to 0.85, move_speed 0. Poses: A wind-up 2:00 `(2, 0.9, -0.3)`, end 10:00 `(10, 0.9, 0.9)`, follow `(10.5, 0.8, -0.3)`; B the mirror (10:00 to 2:00, follow `(2.5, 0.8, -0.3)`). Retune freely; the user has not changed them yet.

**Not done in 3b-3:** sheathing (3c), hitboxes and damage (Step 4). (The helm splitter was built in 3b-4.)

### Step 3b-4: what exists

**Discussion and decisions (2026-10-06):** the air tap loop was sped up 1.5x (uniquely for the air attacks) by setting `speed_scale` on `air_attack_a` and `air_attack_b`, with no code. The helm splitter was agreed with these defaults: gravity 2.5x the player's current gravity, no damping of upward speed on entry, dive at Speed Scale 1.5 and the wind-down at 1.0, the hit window a placeholder for Step 4, and no helm splitter if you land before the decision point. After testing: the first version was a thrust-style stab with a 0.08 s window and looked like the tip just moved top to bottom, so it became a **slash-style swing** (an arc, the wrist snapping, the edge leading) with a longer window; then the user asked for the **body to crouch** during the dive so the sword lies flat on the ground, like Dante.

- **Trigger:** hold attack in the air. `AirAttackState` tracks `_released` and `_decided` (like `AttackState`): at the end of the wind-up (`active_hit.x`), if the button was never released since the action began, the player is airborne, `Player.helm_used` is false, and the air attack has a **Hold Action**, it hands over to `HelmSplitterState.start(action.hold_action)`. Rapid taps never trigger it. Landing before the decision point means no helm splitter.
- **Once per airtime:** `Player.helm_used` is set on entry and cleared by `reset_air_actions()` (landing, and also a ledge hang). A second hold in the same airtime just plays the normal air attack.
- **`HelmSplitterState`** (`extends ActionState`, node `HelmSplitter`): exports `land_action` and `dive_gravity_factor` (2.5). Two phases:
  - **DIVE:** `action` = the Hold Action (falls back to the node's own Action). Extra gravity is added on top of the base (`dive_gravity_factor - 1` times the player's gravity), upward speed is kept (no hover, no damping), normal air control, the body turns toward the input during the wind-up. The action clock is **held** just inside the active window (`active_hit.y - 0.002`), so the blade stays at the end pose (6:00) and the hit window stays open for the whole fall (placeholder for Step 4). No cancels during the dive.
  - **LAND:** on landing (`is_on_floor` and `velocity.y <= 0`) `reset_air_actions()` runs and the state swaps to `land_action` (clock restarts, the sword blends from the held pose). Cancels (dodge, jump, crouch) work from the cancel window (0.3 s). A tap queued in the buffer window continues the ground combo at **attack 2** (`AttackState.try_continue_combo(1)`; the helm splitter counts as combo step 1). Otherwise it ends in Locomotion. Walking off an edge during the wind-down goes to Air.
- **Crouched body (visual and collision, by the user's choice):** `set_crouched(true)` on entry (the normal 1.1 m crouch shrink, feet planted; the sword and arm swing lower with the body through the existing crouch drop), kept through the wind-down; `exit()` stands up unless the next state is `Crouch`. **This is an exception to design note 3.11** (the body capsule stays full size in the air): shrinking from the top with the feet planted does not affect landing. **Headroom rules** (same as the crouch): without room to stand, dodge, jump, and a chained tap are ignored (the press is discarded) and the state ends in `Crouch`.
- **Visuals:** slash style (`blade_aims_at_end` off) on both actions. The dive swings 12:00 to 6:00 with the arc, the wrist snap, and the red blade, then holds at the end pose `(6, 0.3, 1)` (low and forward, flat near the floor when crouched). The wind-down starts at the same pose (its wind-up and end are equal, active hit 0 to 0.01, so no second arc plays) and relaxes to the follow pose.
- **Debug overlay:** a `Helm splitter (DIVE)` line with `vel.y`, or `Helm splitter (wind-down)` with `Cancel` and `Queued` flags.
- **Editor setup done by the user:** a `Node` named `HelmSplitter` under `StateMachine` (script `helm_splitter_state.gd`, Action = `helm_splitter.tres`, Land Action = `helm_splitter_land.tres`); Speed Scale 1.5 and Hold Action = `helm_splitter.tres` on `air_attack_a.tres` and `air_attack_b.tres`.
- **Values:** in the placeholders table (section 6).

**Files:** new `scripts/player/states/helm_splitter_state.gd`, `actions/helm_splitter.tres`, `actions/helm_splitter_land.tres`; modified `air_attack_state.gd`, `player.gd` (`helm_used`), `scripts/ui/debug_overlay.gd`. **The `.tres` files: tuned values are kept (work agreement, section 3).**

**Not done in 3b-4:** hitboxes and damage (Step 4: the dive's active window spans the fall and the landing has a tiny placeholder impact window), a separate crouched hurtbox profile (Step 4), a swing trail or smear effect (no trail exists for any attack yet; it was offered and deferred, see the backlog), the helm splitter from the wall-jump action itself, a deeper bow than the 1.1 m crouch, sound and camera shake.

---

### Step 3c-1: what exists

**Discussion and decisions (2026-10-06, built and tested 2026-10-07):** the sword spawns **sheathed**; the scabbard is on the **left** of the capsule with the blade's **edge up**; the right hand **reaches across to the grip first** (on R and on an attack while sheathed) and the arm animates the sheathing too; `sheathe` is R and D-pad Down; the **draw slash replaces every attack** from the sheathed state (ground, dash, dodge, crouch, slide, air), the dodge itself never draws; the draw slash counts as **no combo step** (the next tap is attack 1); and a **dodge attack** was added (it reuses the dash attack). The sheathed pose is a real local position plus blade and edge directions on `WeaponData`, not a clock pose (a clock pose, scaled 1.5x, cannot pin the hand to a hip point). The hold on the draw slash (charged iai) and the sheathed helm splitter were split off as **3c-2**.

- **State (`player.gd`):** `sheathed` (true at spawn, `start_sheathed`), `sheathe_idle`, `auto_sheathe_time` (5), `set_sheathed()`, `toggle_sheathe()` (ignored while `SwordVisual.is_busy()`), `notify_combat()` (Step 4 will call it on a hit), and `on_action_started(kind)`, called from `ActionState.enter()`: any attack sets `sheathed` false and restarts the timer, a dodge restarts the timer. `_update_auto_sheathe()` counts only while the state is Locomotion or Crouch. Sheathing changes no movement or rules.
- **R:** `LocomotionState` and `CrouchState` call `toggle_sheathe()` on a fresh `sheathe` press (ignored in every other state). Sheathed becomes drawn **without attacking**.
- **Draw slash:** `WeaponData.draw_attack` (`actions/draw_attack.tres`). `AttackState.try_start_draw()` starts it (Locomotion calls it directly); `try_start_variant()` calls it first, so the Dash, Crouch, Slide states and the new dodge hook all get the draw slash with no change of their own. `_pending_uncounted` sets `combo_index` to -1, so a chained tap is attack 1. A **crouched** draw slash chains into the crouch loop A (you stay crouched). `AirAttackState` plays it in the air (`_can_draw()`, `_is_draw`; no lunge, no hold): the next tap is the first air attack, or attack 1 if you landed mid-swing.
- **Dodge attack:** `DodgeState` starts `weapon.dash_attack` through `try_start_variant()` when attack is pressed after the locked window (0.30 s; an earlier press is buffered 0.15 s). It counts as combo step 1, the lunge follows the movement input (a backstep lunges forward at half strength), and the hold gives the dash thrust.
- **`SwordVisual` additions:** a box **scabbard** (built in code under `Visual`, named `Scabbard`; it turns with the body twist and lowers with the crouch); a **variable arm length** (`_arm_len`, the arm box stretches to reach the hip); a **pin** (`_pin`: 0 = the blade root is in the hand, 1 = pinned to the sheathed grip while the arm hangs relaxed); `play_draw()`, `play_sheathe()`, `snap_sheathed()`, `is_busy()`; the draw slash's wind-up is a custom reach, then slide-out, then swing to the 8:00 wind-up (`_update_draw_windup`); edges that are nearly opposite (up in the scabbard, down at rest) **roll around the blade axis** instead of snapping (`_roll_edge`). Attacking during a draw or sheathe animation cancels it and blends from the current pose.
- **Debug overlay:** a `Sword: sheathed / drawn` line, `(moving)` during an animation, and `(auto-sheathe in x.x s)` while drawn.
- **Editor setup done by the user:** `sheathe` in the Input Map (R and D-pad Down), and Draw Attack set on `weapons/katana.tres`. No new nodes.
- **Values:** in the placeholders table (section 6).

**Files:** new `actions/draw_attack.tres`; modified `resources/weapon_data.gd`, `scripts/player/sword_visual.gd`, `scripts/player/player.gd`, `scripts/player/states/attack_state.gd`, `air_attack_state.gd`, `locomotion_state.gd`, `crouch_state.gd`, `dodge_state.gd`, `action_state.gd`, `scripts/ui/debug_overlay.gd`. Claude also ran headless Godot smoke tests before delivering (see the work agreement, section 4). **The `.tres` files: tuned values are kept (work agreement, section 3).**

**Noticed, not fixed:** `AttackState._thrust_mirror` is never reset after a mirrored (left-side) thrust, so the next ground slash may draw mirrored (read from the code, not seen in play; the draw slash ignores it).

**Not done in 3c-1:** the hold on the draw slash (charged iai) and the sheathed helm splitter (3c-2), hitboxes and damage (Step 4), a real scabbard mesh, sound, the sheathed and drawn animation sets, sheathing mid-air.

---

---

## Part 2: Design text of built features (moved from the handoff)

### 3.9 Crouch
- **Toggle by default**, with a setting to switch to hold. Bound to Left Ctrl / left-stick click.
- Slower speed, shorter body capsule (set on the shape resource), and a shrunk hurtbox (the hurtbox part arrives in Step 4; only the body capsule shrinks in 2b).
- Can't crouch in the air. You stay crouched if there's a low ceiling overhead.
- **Dodge and jump cancel crouch** (you stand up into the action). Under a low ceiling those presses are ignored (and discarded, not buffered).
- **Deceleration:** entering crouch faster than crouch speed slows you down at `crouch_decel` instead of snapping to crouch speed.
- **Mesh animation (placeholder polish):** the body mesh and nose ease between heights over `crouch_transition_time`. The **collision capsule changes instantly**.
- **Crouch slide:** pressing `crouch` **while dashing** (Dash state, with movement input) starts a slide. It is an `ActionState` driven by `actions/slide.tres`, moves in the input direction at a speed above the dash, has **i-frames like the dodge**, shows the debug arms held **straight forward** for the whole slide (flair, replaced by real animation later), and ends in Crouch. After its locked window, jump and dodge cancel it (they need headroom). Sliding off an edge goes to Air and stands up. Pressing crouch while merely running or standing is a normal crouch, not a slide.
- **Slide attack: yes** (decided at the Step 3 design: tap and hold variants like the crouch attack). Details in `docs/step3-combat-spec.md`.
- **Combat:** duck under enemy attacks, then counter with a **crouch attack**. There is **no `attack_height` variable**: ducking works because the hurtbox shrinks and an attack whose hitbox doesn't overlap it whiffs. Placement of each attack's hitbox (high, mid, low) decides what can be ducked.
- Stealth use (sneak up for a stealth deathblow) is Phase 2.

### 3.10 Mid-air reach, wall jump, and ledges
- **Pressing jump in mid-air gives no extra height.** The character reaches for a surface:
  - Wall in range (within `wall_range` of the capsule edge, near-vertical surfaces only): **wall jump**, which restores the reach. Capped per airtime (placeholder **2**). The direction comes from the **camera-relative movement input versus the wall normal** (not the player's facing):
    - Input **toward** the wall (within the `wall_input_threshold` cone): straight **up**, facing the wall.
    - Input **away** from the wall (same cone): **backward**, off the wall.
    - Input **sideways** (everything else, including diagonals): **along the wall** in that direction.
    - **No input:** off the wall (away).
  - **Boost:** up speed = `jump_velocity * wall_jump_boost`; push speed = `run_speed * wall_jump_boost` (boost 1.2, so about 8.4 up, which peaks higher than a normal jump).
  - Nothing in range (or the wall-jump cap is reached): plays the **reach** (once per airtime; a wall jump restores it) and nothing else happens. The reach shows as debug arms until real animation exists.
  - **Near-ground rule:** an air jump press within `air_jump_ground_margin` (0.3 m) of the floor is ignored, so it stays buffered for the landing jump.
  - **Tuning note:** a narrower "toward" cone makes diagonals count as sideways, but needs the camera to be roughly square to the wall.
- **Ledges** (the `interact` button):
  - **Grab condition:** airborne, movement input toward a wall (`ledge_input_threshold` cone), a flat ledge top in the **hand zone** (1.4 to 2.1 m above the feet, so one normal jump reaches ledges up to about 3.3 m), enough depth and headroom on top to stand, and either `jump` held (auto-climb) or `interact` held / pressed within 0.15s (hang). There is no rise-speed limit (`ledge_max_rise_speed` = 99), so a jump beside a ledge grabs it while rising. The `jump`-held requirement (`ledge_requires_jump_held`) stops accidental grabs after dropping or walking off an edge.
  - Reaching a ledge **without** holding `interact` makes the character **auto-climb** up (Nightreign style). The climb is scripted (`LedgeClimb`, `ActionData` kind `LEDGE_CLIMB`, 0.6s): up along the wall, then forward onto the top, with body collision off and the landing spot checked first.
  - Holding/pressing `interact` at the ledge makes the character **hang** instead (`LedgeHang`), unless the hanging body would not fit (low ledges, floor too close), in which case it auto-climbs.
  - **Releasing `interact` does nothing**: you stay hanging until you act. Hanging resets reach and wall jumps.
  - **Hang spot:** capsule center 1.2 m below the ledge top, 0.05 m off the wall, snapped in over 0.1s. **Both hands must be on the ledge** (two hand points 0.3 m either side); at a grab near a ledge end the spot shifts sideways (up to 0.6 m) to satisfy this, otherwise it auto-climbs.
  - **While hanging:** a **fresh `interact` press** = climb up (holding toward the wall does nothing; needs room on top), crouch = drop, jump = leap away from the wall (uses the wall-jump action and boost, restores reach, does not use a wall-jump count), left/right = **shimmy along one straight line** at 1.5 m/s (stops when either hand would leave the ledge, and at inside corners).
  - After a drop or leap, **no ledge grab for 0.3s**.
  - A hit knocks the player off the ledge: `LedgeHangState.knock_off()` exists as the hook; it is called from the damage system in Step 4.
- All air actions (jump attack, jump guard/deflect) stay available after a wall jump. A hanging player can be hit, and a hit knocks them off.
- **Arena rule:** the combat arena stays reachable by the single melee enemy; traversal gets its own test area. Parkour must not become a free escape from the enemy.
- Corner shimmy and other ledge enhancements are Phase 2.

### 5.1 `ActionData` (implemented in Step 2a: `resources/action_data.gd`)

All times are seconds from the start of the action; windows are `Vector2(start, end)`.

- **Identity:** `kind` (enum: ATTACK, DODGE, GUARD, HEAL, JUMP, WALL_JUMP, LEDGE_CLIMB, PERILOUS_THRUST, PERILOUS_SWEEP, GRAB, OTHER), `animation`, `duration`, `speed_scale` (action clock speed)
- **Windows:** `locked_until`, `cancel_window` ((0,0) = from `locked_until` to the end), `buffer_window` (attack chaining: where an attack press is accepted, (0,0) = the whole action; used from 3a-1), `active_hit` (the swing's wind-up / active / recovery split, used from 3a-1; the hitbox itself comes in Step 4), `iframes`
- **Swing visual (3a-1):** `swing_windup`, `swing_end`, `swing_follow` (clock poses, see the terminology in section 11; they only drive the placeholder sword)
- **Movement:** `move_speed`, `move_window`, `move_fade`, `move_end_factor` (speed at the window's end as a fraction of `move_speed`; 0 = fade to a stop)
- **Combat:** `damage`, `posture_damage`, `guardable`, `deflectable`, `pauses_posture_regen`, `combo_next` (unused: `WeaponData.combo` holds the combo order and the loop)
- **Helpers:** `in_window()`, `is_locked()`, `can_cancel()`, `has_iframes()`, `is_hit_active()`

*(5.1 above is stale: `ActionData` has since gained the hold, charge, thrust, and sheath-related fields. `resources/action_data.gd` documents every field.)*

---

## Part 3: Placeholder numbers of built features (moved from the handoff, section 6)

> History only. The truth is in the Player and SwordVisual exports (Inspector) and in the `.tres` files.

| Parameter | Placeholder |
|---|---|
| Input buffer time | 0.15s |
| Run speed / walk speed | 6.5 / 2.5 (step 1, still tunable) |
| Acceleration / deceleration | 50 / 60 |
| Turn speed | 18 |
| Jump velocity / gravity multiplier | 7.0 / 2.0 |
| Coyote time / jump buffer | 0.1s / 0.15s |
| Camera: follow height / smoothing | 1.5 / 20 |
| Camera: mouse sens / stick sens | 0.0025 / 3.0 |
| Camera: pitch range / spring length | -60° to 30° / 4.0 m |
| Crouch: speed / body capsule height | 2.0 m/s / 1.1 m |
| Crouch: deceleration into crouch / mesh transition | 12 m/s^2 / 0.12s |
| Slide: duration / locked until | 0.6s / 0.35s |
| Slide: i-frames | 0.05s to 0.28s (same as dodge) |
| Slide: speed / window / end factor | 18 m/s (tuned by the user, feels good) / 0 to 0.45s / 0.3 |
| Slide arms pose | 90 degrees (straight forward), `slide_angle_deg` on `ReachArms` |
| Jump height | `jump_velocity` 7.0 with `gravity_multiplier` 2.0 gives about 1.25 m (height = v^2 / (2 x 9.8 x multiplier)); raising it also raises ledge reach, the wall jump up speed, and needs the arena blocks resized |
| Wall jumps per airtime | 2 |
| Wall jump boost | 1.2x (up = jump_velocity x boost, push = run_speed x boost) |
| Wall range / input threshold | 0.6 m / 0.75 (user-tuned; higher = narrower "toward" cone; 0.5 was the first value) |
| Air jump ground margin | 0.3 m |
| Wall jump action | duration 0.25s, locked until 0.12s, move 6.5 over 0 to 0.25s, end factor 0.6 |
| Ledge hand zone / input cone | 1.4 to 2.1 m above the feet / 0.5 (60 degrees) |
| Ledge grab rise-speed limit / jump held | 99 (off) / required for the auto-climb |
| Ledge landing standoff | 0.1 m |
| Ledge climb | 0.6s (rise 60%, then forward) |
| Hang: center depth / wall gap / snap time | 1.2 m / 0.05 m / 0.1s |
| Hang: hand spacing / max sideways adjust | 0.3 m / 0.6 m |
| Shimmy speed | 1.5 m/s |
| Ledge regrab cooldown (after drop or leap) | 0.3s |
| Dodge: duration / locked until | 0.45s / 0.30s |
| Dodge: i-frames | 0.05s to 0.28s |
| Dodge: speed / window / end factor | 11 m/s / 0 to 0.30s / 0.3 (current, feels good to the user) |
| Backstep speed multiplier | 0.7 |
| Dash speed | 9.0 m/s |
| Attack timings and lunge speeds | tuned by the user; the current values are in the Step 3 spec (section 4) and live in `actions/attack_1..5.tres` |
| Attack lunge: no-input strength / ledge stop distance / ledge stop time | 0.5x / 1.4 m (the user's scene value) / 0.14 s (`AttackState` exports; the check is the larger of the distance and 0.14 s of travel at the lunge speed) |
| Sword: pose scale / arm reach | 1.5 / 0.6 m |
| Sword: shoulder offset / shoulder height / clock center height | 0.35 m / 1.4 m / 1.2 m |
| Sword: slash arc / wind-up arc (forward bow of the tip path) | 0.5 m / 0.25 m |
| Sword: wrist angle start / end / follow overshoot / follow relax | 50 deg / -10 deg / 15 deg / 0.5 |
| Sword: body twist max / arm twist factor | 30 deg / 2.0 (the user raised it from 1.5; the arms turn 2x as far as the body) |
| Thrust: duration / active hit / chain from / lunge | 1.2 s / 0.10 to 0.26 / 0.62 / first guess 10.0 m/s (**the user tuned it to 20**) over 0 to 0.42; up to 1.4x at full charge |
| Thrust charge: time / damage max / lunge max / hold grace | 0.6 s / 1.5x / 1.4x / 0 s (`hold_extra_time`) |
| Dash slash: duration / active hit / chain from / lunge | 0.95 s / 0.22 to 0.38 / 0.50 / first guess 7.0 m/s (**the user tuned it to 15**) over 0.05 to 0.40 |
| Dash slash poses | wind-up 2:45 `(2.75, 0.9, -0.3)`, end 8:45 `(8.75, 0.9, 0.9)`, follow `(9.25, 0.8, -0.3)` (the user's angle) |
| Dash thrust: duration / active hit / chain from / lunge | 1.0 s / 0.10 to 0.26 / 0.55 / first guess 8.5 m/s (**the user tuned it to 20**) over 0 to 0.35, no charge |
| Blade length / width | 1.1 m / 0.08 m (the script default; 0.14 m was suggested to make the edge easier to see but was not applied) |
| Air tap loop speed | `speed_scale` 1.5 on `air_attack_a` and `air_attack_b` (about 0.57 s per swing instead of 0.85 s; the active window is about 0.09 s real) |
| Helm splitter dive | `helm_splitter.tres`: duration 1.0, `speed_scale` 1.5, locked until 0.4, active hit 0.15 to 0.40, slash style (not a thrust); poses wind-up 12:00 `(12, 1, -0.3)`, end and follow 6:00 `(6, 0.3, 1)` |
| Helm splitter dive gravity | `dive_gravity_factor` 2.5 on `StateMachine/HelmSplitter` (2.5x the player's current gravity, so about 5x normal with the multiplier of 2.0) |
| Helm splitter wind-down | `helm_splitter_land.tres`: duration 0.7, speed 1.0, locked until 0.3, cancel 0.3 to 0.7, buffer 0.05 to 0.7, active hit 0 to 0.01 (placeholder impact), poses wind-up and end `(6, 0.3, 1)`, follow `(4.5, 0.8, 0.2)` |
| Draw slash (iai) | `draw_attack.tres`: duration 1.0, locked until 0.42, active hit 0.30 to 0.42 (wind-up 0.30 s = the reach and the pull), cancel 0.55 to 1.0, buffer 0.10 to 1.0, lunge 6 m/s over 0.20 to 0.50 (fading), poses wind-up 8:00 `(8, 0.9, -0.3)`, end 2:00 `(2, 0.9, 0.9)`, follow `(1, 0.9, -0.3)` (first guesses; retune freely) |
| Sheathed pose | grip `(-0.46, 0.95, -0.18)` (left hip, local meters), blade direction `(-0.05, -0.25, 1)` (back, slightly down), edge up; set on `katana.tres` (`WeaponData` Sheath group). The arm hangs along `relaxed_arm_direction` `(0.1, -1, -0.1)` on `SwordVisual` |
| Draw and sheathe timing | R draw: reach 0.15 s + pull 0.25 s (`draw_slide_fraction` 0.3 of the pull slides the blade out along its line by `draw_slide_distance` 0.3 m, the rest swings it away); R sheathe: approach 0.2 s + slide-in 0.25 s + release 0.15 s; the draw slash's wind-up spends `draw_reach_share` 0.5 on the reach. All exports on `SwordVisual` |
| Auto-sheathe | `auto_sheathe_time` 5 s on the Player (counted only in Locomotion or Crouch; attack or dodge restarts it; 0 = never); `start_sheathed` true |
| Sword rest | clock pose (4, 0.9, 0.3), blade direction (0.15, -0.5, -0.85), edge down (Rest Edge Direction = (0, -1, 0), set by the user; tune in `katana.tres` and `SwordVisual`) |

---

## Part 4: Resolved open questions (moved from the handoff, section 9)

- ~~**O6:** Ledge details~~ **Resolved in Step 2d**: values are in the placeholders table (all tunable exports).
- ~~**O7:** Slide attack~~ **Resolved: yes**, with tap and hold variants (see the Step 3 spec).
- ~~**O9:** the 3c open items~~ **Resolved 2026-10-06/07**: spawn sheathed; the draw slash replaces all attack variants while sheathed; attack or dodge restarts the auto-sheathe timer (a hit joins in Step 4); sheathe transition times in the placeholders table.
- **O8 (resolved 2026-10-06):** a crouch, slide, or dash attack tap counts as combo step 1 (the next tap is attack 2); air attacks are unlimited while airborne, the helm splitter once per airtime, no hover, helm splitter gravity 2.5x. See the spec, section 6.

---

## Part 5: Step 3 spec, original and as-built detail (moved from `docs/step3-combat-spec.md`)

### Section 4 tables: first-guess timings, current tuned values, clock poses

**First-guess timings** (seconds, all tunable `.tres` values, chosen to fit the swing):

| # | duration | active_hit | cancel_window (chain from) | buffer_window | lunge speed / window |
|---|---|---|---|---|---|
| 1 | 0.70 | 0.14 to 0.26 | 0.30 to 0.70 | 0.10 to 0.70 | 3.0 m/s, 0.05 to 0.25 |
| 2 | 0.70 | 0.12 to 0.24 | 0.28 to 0.70 | 0.10 to 0.70 | 3.0 m/s, 0.05 to 0.22 |
| 3 | 0.75 | 0.16 to 0.28 | 0.32 to 0.75 | 0.10 to 0.75 | 3.5 m/s, 0.06 to 0.26 |
| 4 | 0.75 | 0.14 to 0.26 | 0.30 to 0.75 | 0.10 to 0.75 | 3.5 m/s, 0.06 to 0.24 |
| 5 | 1.00 | 0.26 to 0.42 | 0.52 to 1.00 | 0.15 to 1.00 | 5.5 m/s, 0.08 to 0.40 |

**Current tuned values** (the user approved these after two slow-down passes and a longer wind-up on attack 1; the first-guess table above is the original design). Seconds and m/s; the lunge distance is about 3x the first guess, attack 5 is faster than the dash (9.0 m/s):

| # | duration | locked_until | active_hit | cancel_window | buffer_window | lunge speed / window |
|---|---|---|---|---|---|---|
| 1 | 1.16 | 0.52 | 0.35 to 0.52 | 0.64 to 1.16 | 0.14 to 1.16 | 6.3, 0.22 to 0.51 |
| 2 | 1.01 | 0.35 | 0.17 to 0.35 | 0.47 to 1.01 | 0.14 to 1.01 | 6.3, 0.07 to 0.31 |
| 3 | 1.08 | 0.41 | 0.23 to 0.41 | 0.52 to 1.08 | 0.14 to 1.08 | 7.3, 0.08 to 0.37 |
| 4 | 1.08 | 0.37 | 0.20 to 0.37 | 0.49 to 1.08 | 0.14 to 1.08 | 7.3, 0.08 to 0.35 |
| 5 | 1.44 | 0.60 | 0.37 to 0.60 | 0.80 to 1.44 | 0.22 to 1.44 | 11.5, 0.12 to 0.58 |

**Placeholder clock poses** (hour, radius m, forward m; all tunable in `actions/attack_N.tres`):

| # | wind-up | slash end | follow-through |
|---|---|---|---|
| 1 | 1:00, 1.0, -0.5 | 7:00, 0.9, 0.9 | 7:30, 0.8, -0.3 |
| 2 | 7:00, 0.9, -0.2 | 12:45, 1.0, 0.9 | 1:30, 0.9, -0.3 |
| 3 | 8:30, 0.9, -0.3 | 2:30, 0.9, 0.9 | 3:00, 0.8, -0.3 |
| 4 | 3:30, 0.9, -0.3 | 9:00, 0.9, 0.9 | 9:30, 0.8, -0.3 |
| 5 | 11:00, 1.0, -0.4 | 5:00, 1.0, 1.0 | 6:00, 0.8, -0.6 |

### Section 5: thrust values as built (3a-2)

**As built (3a-2), thrust values** (`actions/thrust.tres`, first-guess numbers scaled to the tuned attacks so the thrust is slower than any slash: its hit window opens at least 0.10 s later than the slash it replaces, and it lasts longer overall): duration 1.2, active_hit 0.10 to 0.26, locked_until 0.26, cancel_window 0.62 to 1.2, buffer_window 0.20 to 1.2, lunge 10.0 m/s over 0 to 0.42 (about 2.1 m, up to 14 m/s and about 2.9 m at full charge), charge_time 0.6, damage max 1.5, lunge max 1.4. **The user later tuned the thrust's lunge speed to 20 m/s.** Details and rules are in section 7.8.

### Sections 7.2 to 7.12: code design and as-built notes

### 7.2 `WeaponData` (new resource, `resources/weapon_data.gd`)
- `display_name: String`
- `combo: Array[ActionData]` (the 5 ground attacks, in order)
- `blade_length: float` (1.1 m placeholder), `blade_thickness: float` (used as the blade's **width**, edge to spine; 0.08 m, the script default)
- `rest_pose: Vector3` (sword at rest, same pose format as below)
- Later phases add: `thrust: ActionData`, `dash_attack`, `crouch_attack`, and so on.
- The Player gets `@export var weapon: WeaponData`; `weapons/katana.tres` is the first weapon.

### 7.3 `ActionData` additions (placeholder visual poses) **(built)**
Each pose is a clock pose, a `Vector3`: **(clock hour, radius in m, forward in m)**; forward is in front of the player (negative = behind).
- `swing_windup` (the aim point at the slash start), `swing_end` (slash end), `swing_follow` (flourish).
- They say where the sword's **tip** should pass; the arm swing (7.4) aims at them. They only drive the placeholder sword. When real animation arrives they become unused (the `animation` name takes over).

### 7.4 `SwordVisual` (`scripts/player/sword_visual.gd`, `Node3D` under `Visual`) **(built: the arm swing)**
- Builds a gray arm, a flat box blade, and a bright yellow strip on the cutting edge, all in code (like `ReachArms`). `Player` calls `setup(weapon)` in `_ready`.
- **Pose to aim point:** (sin(hour*30deg)*radius, center height + cos(hour*30deg)*radius, -forward), with radius and forward multiplied by `pose_scale` (1.5) around the clock center (1.2 m up).
- **The arm:** from the right shoulder (0.35 m right, 1.4 m up) toward the aim point; the hand sits `arm_reach` (0.6 m) along it; the blade extends from the hand.
- **Wrist angle:** the blade bends away from the arm by `wrist_start_angle` (50 deg, trailing) at the slash start, easing to `wrist_end_angle` (-10 deg, slightly leading) at the end. A small `follow_overshoot` (15 deg) at the start of the flourish, then the blade relaxes toward the rest direction (`follow_relax` 0.5).
- **Path:** the aim point travels from the wind-up pose to the end pose along a chord bowed forward in the middle (`slash_arc_forward` 0.5 m); the wind-up and follow-through use `windup_arc_forward` (0.25 m). The travel direction at each moment is the path's slope.
- **Edge:** the strip leads along the travel direction (the edge side is the part of the travel direction perpendicular to the blade). `flip_edge` if it is on the wrong side.
- Segments over `action_time` (data stays authoritative, no tweens): blend from the captured previous pose to the wind-up, wind-up to end (the active window, fast ease, the blade turns red), end to follow-through. Returns to `rest_pose` (hand on the arm line toward it, blade pointing down and forward, **edge down**: the user set Rest Edge Direction to (0, -1, 0); an edge-up sheathed pose comes in 3c) when the combo ends.
- **Body twist (visual only):** the arm swing and the capsule's `Nose` rotate around the body's vertical axis. A pose's twist = `max_twist_degrees` (30) x sin(hour angle), positive = to the right, so attack 1 twists right in the wind-up and left with the cut, attack 2 starts left and goes slightly right, attacks 3 and 4 are the strongest, attack 5 is slight. The twist follows the same segments and eases as the sword, chains start from the previous twist, and it returns to neutral when the combo ends. **Arm lead:** the arm swing turns `arm_twist_factor` (now 2.0, the user raised it from 1.5) times the body twist; the nose follows the plain body twist. It changes no facing, lunge, steering, or hitbox (Step 4 decides what the hitbox follows). The Nose is only moved in x and z, because the crouch code owns its y.
- The real tip only roughly follows the aim point, since the blade bends at the wrist and its length is fixed.
- History: the first version placed the **grip** at the pose point and the sword hung beside the body. The poses now aim the arm instead.

### 7.5 `AttackState` (`scripts/player/states/attack_state.gd`, extends `ActionState`) **(built)**
- Overrides `enter` to pick `action = weapon.combo[index]` (index 0 when coming from another state, the next index, wrapping, when chaining from `Attack`), then calls the base. `exit` to anything but `Attack` resets the counter and releases the sword.
- Steering and lunge direction during the wind-up (a held input keeps updating the lunge; both lock at the active window), the half-strength no-input lunge, the ledge stop, the buffer window, the chain at the earliest allowed point (`cancel_window.x`), and the cancel rules (dodge, jump, crouch outside the active window; floor only).
- `_can_steer()` is the hook Step 9 (lock-on) will override. `get_debug_text()` feeds the debug overlay.

### 7.6 3a-1 files and editor steps **(delivered)**
- **New:** `resources/weapon_data.gd`, `weapons/katana.tres`, `actions/attack_1.tres` to `attack_5.tres`, `scripts/player/states/attack_state.gd`, `scripts/player/sword_visual.gd`.
- **Modified:** `resources/action_data.gd`, `scripts/player/player.gd` (the `weapon` export, `sword_visual`, `has_combo()`, `has_ground_ahead()`), `scripts/player/input_buffer.gd` (track `attack`), `scripts/player/states/locomotion_state.gd` (attack starts the combo), `scripts/ui/debug_overlay.gd` (combo step and open windows).
- **Editor:** under `Player/StateMachine` a `Node` named exactly `Attack` (script `attack_state.gd`); under `Player/Visual` a `Node3D` named `SwordVisual` (script `sword_visual.gd`); on the `Player` root **Weapon** set to `weapons/katana.tres`. No Input Map changes.

### 7.7 Not in 3a-1
Thrust and hold (built later in 3a-2, see 7.8), all variants (3b), hitboxes and damage (Step 4), guard cancels (Step 5), real sword mesh and animation.

### 7.8 3a-2 as built (hold and the charged thrust)
- **Files:** new `actions/thrust.tres`; modified `resources/action_data.gd` (`blade_aims_at_end`, `twist_scale`, the Charge group), `resources/weapon_data.gd` (`thrust`), `scripts/player/states/attack_state.gd`, `scripts/player/sword_visual.gd`. **Editor:** set **Thrust** on `weapons/katana.tres` to `actions/thrust.tres`. No new nodes or Input Map changes.
- **Decision point:** when the action clock reaches `active_hit.x`, a held attack button (with a chargeable thrust on the weapon) starts a charge; otherwise the slash continues. `hold_extra_time` (default 0) can wait for a release first.
- **Charging:** the action clock is frozen 0.001 s before the hit window opens, so steering and the dodge, jump, and crouch cancels still work. No lunge while charging.
- **Fire:** release or `charge_time` swaps the slot's slash for the thrust (clock restarts at 0), with damage and lunge multipliers from the charge fraction. `combo_index` is unchanged, so the thrust takes the step it falls on.
- **Sides:** from the previous slash's `swing_end` side, the opposite of a previous thrust, or right from idle. Left = the right poses mirrored (hour becomes 12 minus hour).
- **Visuals:** thrust style (hand moves straight from the wind-up pose to the end pose, blade points at the end pose, edge down, body twist scaled by `twist_scale` 0.25); the charge pose is pulled back with an orange glow that grows with the charge. Known quirk: the slash's lunge window usually starts before the decision point, so there can be a small step forward before a charge.
- **Ledge stop:** speed-aware (see section 3).

### 7.9 3b-1 as built (the dash attack)
- **Files:** new `actions/dash_attack.tres` and `actions/dash_thrust.tres`; modified `resources/action_data.gd` (`hold_action`), `resources/weapon_data.gd` (a Variants group with `dash_attack`), `scripts/player/states/attack_state.gd`, `scripts/player/states/dash_state.gd`. **Editor:** set **Dash Attack** on `weapons/katana.tres` to `actions/dash_attack.tres` (its Hold Action already points at `dash_thrust.tres`).
- **Entry:** `DashState` takes an attack press (after the jump check) and calls `AttackState.try_start_variant(weapon.dash_attack)`, which sets a pending variant and transitions to `Attack`. The variant counts as step 1 (`combo_index` 0), so chaining goes to attack 2. A variant's side for a thrust is right; after a chain the connected zigzag rule applies as usual.
- **`hold_action` (new, on `ActionData`):** what replaces the attack when the button is held at the decision point. `charge_time` 0 on that action = swapped in at once (no charge phase, no glow); above 0 = charged first. Empty on a ground combo attack = the weapon's charged thrust (unchanged); empty on a variant = no hold.
- **Dash slash (first guess):** duration 0.95, active 0.22 to 0.38, locked_until 0.38, cancel_window 0.50 to 0.95, buffer_window 0.10 to 0.95, lunge 7.0 m/s over 0.05 to 0.40. **Poses (user's change): wind-up 2:45 `(2.75, 0.9, -0.3)`, end 8:45 `(8.75, 0.9, 0.9)`, follow `(9.25, 0.8, -0.3)`.** Because it now ends at 8:45, a held chain out of it starts the thrust on the left.
- **Dash thrust (first guess):** duration 1.0, active 0.10 to 0.26, cancel_window 0.55 to 1.0, buffer_window 0.20 to 1.0, lunge 8.5 m/s over 0 to 0.35, same poses as the ground thrust, no charge.
- **User tuning:** `dash_attack` move_speed 15, `dash_thrust` move_speed 20, `thrust` move_speed 20 (it feels good).
- **Ledge stop note:** it looks ahead `ledge_check_time` (0.14 s) of travel at the lunge speed, so at 20 m/s (times up to 1.4 for a charged thrust) it checks about 3 to 4 m ahead and stops earlier near edges. Lower `ledge_check_time` (for example 0.08) if that is too cautious, at the risk of lunging over an edge.

### 7.10 3b-2 as built (crouch and slide attacks)
- **Files:** new `actions/crouch_attack_a.tres`, `crouch_attack_b.tres`, `crouch_upward.tres`; modified `resources/action_data.gd` (`combo_next`), `resources/weapon_data.gd` (`crouch_attack`), `scripts/player/states/attack_state.gd`, `crouch_state.gd`, `slide_state.gd`, `scripts/player/sword_visual.gd`. **Editor:** set **Crouch Attack** on `weapons/katana.tres` to `actions/crouch_attack_a.tres`.
- **Loop:** crouch or slide + attack starts A (3:00 to 9:00); a chained tap goes to B (9:00 to 3:00), then back to A. Each ends in Crouch. Slide attacks are allowed after the slide's locked window. Taps count as combo step 1.
- **Hold:** at the end of any crouch attack's wind-up it is replaced by the upward slash (8:00 to 1:00, no charge); it stands you up (needs headroom, otherwise a hold does nothing) and the next tap is attack 1.
- **Alternating sides:** the upward slash starts where the previous attack ended: after A from the left (as authored), after B from the right (mirrored 4:00 to 11:00), from crouch idle or slide from the right (mirrored). The mirror rule: thrusts (`blade_aims_at_end`) are authored right-handed, slash-style hold actions left-handed; `SwordVisual` now honors `mirror` on the slash path (poses and body twist).
- **Hold fix:** `_released` in `AttackState` makes a hold require a continuously held button since the action began; applies to all attacks.
- **Crouch visuals:** `SwordVisual._update_crouch_drop` lowers the arm swing with the body.
- **Values:** in the handoff, "Step 3b-2: what exists".

### 7.11 3b-3 as built (the air tap loop)
- **Files:** new `scripts/player/states/air_attack_state.gd`, `actions/air_attack_a.tres`, `actions/air_attack_b.tres`; modified `air_state.gd` (entry), `attack_state.gd` (`try_continue_combo`), `player.gd` (`air_loop_next`), `resources/weapon_data.gd` (`air_attack`), `scripts/ui/debug_overlay.gd`. **Editor:** a `Node` named `AirAttack` under `StateMachine` with the new script; set **Air Attack** on `weapons/katana.tres`.
- **Design as built:** a separate state (`AirAttackState extends ActionState`). A press in the air (not near the ground) starts A; chained taps follow `combo_next`, then loop. `Player.air_loop_next` tracks the loop and `reset_air_actions()` (landing) restarts it. No lunge, no hover, normal air control, steering during the wind-up.
- **Cancels** (outside the hit window): ledge grab, jump (wall jump or the reach), and on the floor dodge, jump, crouch. No air dodge.
- **Landing mid-swing:** the swing plays out; a queued tap continues the ground combo at attack 2.
- **Not hooked up:** attacking during the wall-jump action. **Hold in the air** starts the helm splitter (3b-4, section 7.12).
- **Values:** in the handoff, "Step 3b-3: what exists".

### 7.12 3b-4 as built (the helm splitter, and the air loop speed)
- **Air loop speed:** `speed_scale` 1.5 on `actions/air_attack_a.tres` and `air_attack_b.tres` (the action clock runs 1.5x, so every window and the sword visual compress together; no code).
- **Files:** new `scripts/player/states/helm_splitter_state.gd` (`HelmSplitterState extends ActionState`), `actions/helm_splitter.tres`, `actions/helm_splitter_land.tres`; modified `air_attack_state.gd` (the hold decision), `player.gd` (`helm_used`, cleared in `reset_air_actions`), `scripts/ui/debug_overlay.gd`. **Editor:** a `Node` named `HelmSplitter` under `StateMachine` with the new script (Action = `helm_splitter.tres`, Land Action = `helm_splitter_land.tres`); on `air_attack_a` and `air_attack_b` set Speed Scale 1.5 and Hold Action = `helm_splitter.tres`.
- **Trigger:** hold attack in the air. At the end of the air attack's wind-up (`active_hit.x`), a button that was never released since the action began, an airborne player, `helm_used` false, and a Hold Action on the attack hand over to the helm splitter. Rapid taps never trigger it; landing first means no helm splitter. **Once per airtime** (`Player.helm_used`).
- **DIVE:** extra gravity on top of the base (`dive_gravity_factor` 2.5 on the state, a multiple of the player's current gravity), upward speed kept (no hover, no damping), normal air control, no cancels. The action clock is held just inside the active window, so the blade stays at 6:00 and the hit window stays open for the whole fall (placeholder for Step 4).
- **LAND:** on landing the state swaps to `helm_splitter_land` (duration 0.7, cancel window 0.3 to 0.7, buffer window 0.05 to 0.7, a tiny active window 0 to 0.01 as the impact placeholder). Dodge, jump, and crouch cancel from 0.3 s; a queued tap continues the ground combo at **attack 2** (the helm splitter counts as combo step 1); otherwise it ends in Locomotion.
- **Crouched body:** `set_crouched(true)` for the whole dive and wind-down (the normal crouch shrink, feet planted; the sword and arm swing lower through the existing crouch drop); `exit()` stands up unless going to `Crouch`. Without headroom, dodge, jump, and chain are ignored and it ends in `Crouch`. This is an exception to the handoff's 3.11 (the body capsule stays full size in the air): it shrinks from the top with the feet planted, so landing is unaffected.
- **Visuals:** slash style (`blade_aims_at_end` off); the first thrust-style stab looked like the tip just moved top to bottom. Dive poses: wind-up 12:00 `(12, 1, -0.3)`, end and follow 6:00 `(6, 0.3, 1)` (low and forward, flat near the floor while crouched). Active hit 0.15 to 0.40, locked until 0.4, speed scale 1.5, so the swing takes about 0.17 s real. The wind-down's poses start at the same end pose (its active window is nearly zero, so no second arc plays) and relax to `(4.5, 0.8, 0.2)`.
- **Not done:** hitboxes and damage and a crouched hurtbox profile (Step 4), a swing trail or smear effect (none exists for any attack; deferred to the handoff backlog), the helm splitter from the wall-jump action, sound and camera shake.

---

### Section 7b: sheathing, as built (3c-1)

### As built (3c-1)

- **Two states, visual only:** the sword is **sheathed** (in a box scabbard at the left hip, edge up, the blade pointing back and slightly down, the arm hanging relaxed) or **drawn** (the rest pose, edge down). It **spawns sheathed**. Sheathing changes no movement, speed, or rules (`Player.sheathed`).
- **Data:** `WeaponData` gets `draw_attack: ActionData`, `sheathed_grip` (a real local position in meters, `(-0.46, 0.95, -0.18)`; **not** a clock pose, because a clock pose cannot pin the hand to a hip point), `sheathed_blade_direction`, and `sheathed_edge_direction`. `rest_pose` stays the drawn pose.
- **Draw slash (iai):** `actions/draw_attack.tres`, a slash from **8:00 to 2:00**. An attack while sheathed plays it in **every context**: ground, dash, dodge, crouch, slide (you stay crouched), and air (no lunge). It **replaces** the dash, crouch, slide, and air attacks, and the dodge itself never draws. It counts as **no combo step**: the next tap is **attack 1** (after a crouched draw slash it is the crouch loop A; in the air it is the first air attack, or attack 1 if you landed mid-swing). It has no hold yet (3c-2): holding while sheathed just plays the tap. Values (first guesses): wind-up 0.30 s (the hand reaches the grip, then pulls the blade), active hit 0.30 to 0.42, duration 1.0, cancel from 0.55, buffer 0.10 to 1.0, lunge 6 m/s over 0.20 to 0.50; poses wind-up `(8, 0.9, -0.3)`, end `(2, 0.9, 0.9)`, follow `(1, 0.9, -0.3)`, so it flows into attack 1's 1:00 wind-up.
- **R (`sheathe`; R and D-pad Down):** sheathed becomes drawn **without attacking**, drawn becomes sheathed. It works in Locomotion and Crouch only and is ignored while the animation is still moving.
- **Animated arm (visual only):** **draw** = the arm lifts from its relaxed hang and the hand reaches across to the grip (0.15 s), then the blade slides out along its own line and swings to the rest pose (0.25 s). **Sheathe** = the hand brings the sword to the scabbard mouth (0.2 s), the blade slides in (0.25 s), then the hand lets go and the arm relaxes (0.15 s). The draw slash's wind-up does the same reach and pull. The arm **stretches** so the hand actually reaches the hip. Attacking during an animation interrupts it and blends from wherever the sword is.
- **Auto-sheathe:** 5 s with no attack or dodge, counted only while in Locomotion or Crouch (`Player.auto_sheathe_time`, 0 = never). A hit will restart it in Step 4 through `Player.notify_combat()`.
- **Dodge attack:** attack pressed after a dodge's locked window starts the **dash attack** (tap = slash, hold = thrust), counts as step 1, and becomes the draw slash while sheathed.

---

## Part 6: Entries added after the trim (newest last)

### Step 3c-2: charged iai and sheathed helm splitter (2026-10-07)

Tested and approved by the user ("cool"). Docs: handoff checklist and Step 3 spec updated.

**Decisions (agreed with the user before building)**
- The charged iai stands you up when it fires from a crouch or slide (the first design kept you crouched). No headroom: the hold is ignored and the plain draw slash plays.
- The sheathed helm splitter gets half gravity as a deliberate exception to "no hover" (spec decision 7): option A, during the opening only. An air charge (option B) was not built.
- The `_thrust_mirror` bug was fixed inside this step, because the iai depends on it.

**What exists**
- `draw_attack.tres` has `hold_action` = `draw_attack_charged.tres` (charge_time 0.6, damage x1.5, lunge x1.4, wind-up 0.1 s, slash 0.1 to 0.22). Every sheathed ground hold (standing, dash, dodge, crouch, slide) picks it up through `AttackState._hold_target()`, replacing the thrust and the other holds.
- `AttackState`: `_iai_hold` marks the iai hold; its mirror is always false; `_is_thrust` stays false for it, so the next tap is attack 1 and a later thrust starts on the side where the iai ended (right). From a crouch, `_fire_thrust` reuses the upward slash's stand-up path (`_rose`).
- `SwordVisual.update_charge_iai()`: eases to a half-drawn pose (hand at `_front_pos()`, blade along the scabbard line, body twist held) and glows with the charge. Firing blends from it to 8:00 through the charged action's own wind-up.
- `WeaponData.draw_helm_action` (Sheath group) = `helm_splitter_draw.tres` (wind-up 12:00 over 0.4 s, active 0.4 to 0.65, then the usual dive and `helm_splitter_land.tres`).
- `AirAttackState._try_helm_splitter()` uses `draw_helm_action` when the current action is the draw slash (its own `hold_action` is the ground iai). `_apply_hold_gravity()` halves gravity while holding before the decision point (sheathed, helm not used, `draw_helm_action` set).
- `HelmSplitterState.start(dive, opening)`: for the sheathed version the wind-up (`action_time < active_hit.x`) uses `opening_gravity_factor` (export, 0.5) instead of the dive's 2.5x.
- `_thrust_mirror` is reset to false in `AttackState._on_action_enter()` (it ran after the side logic in `enter()`, so the side rules still read the old value). A thrust or upward slash sets it again in `_begin_hold()`.

**Rules not obvious from the code**
- The reach and pull of the sheathed helm splitter are shown by the draw slash's wind-up (0.3 s), before the hold is decided; `helm_splitter_draw.tres` is only the longer raise. Hang time is the draw wind-up (while held) plus the raise, about 0.7 s at half gravity.
- Releasing attack early in the air means no helm splitter: the draw slash plays as a normal air slash.
- The iai charge has no lunge; the lunge starts when it fires (`move_speed` 9, scaled by charge).

**Not done**
- The shockwave and the extra damage (Step 4 and polish); `damage_multiplier` is stored only.
- An air charge for the sheathed helm splitter.
- Sheathed and drawn animation sets.
- Tuning the new numbers (charge pose, 0.4 s raise, 0.5 gravity): the user may tune them in the Inspector.
- No headless check was run (not asked); only the user's play test.

**Noticed, not fixed**
- None new.

### Step 4a: hitboxes, damage, hitstop on a dummy (2026-10-07)

Tested and approved by the user ("awesome, all works fine"). Docs: handoff updated (4a ticked, 4b added).

**Decisions (agreed with the user before building)**
- Split of Step 4 into 4a (this) and 4b (player hurtbox profiles, the dummy attacking, the player taking damage).
- Enemy bars follow Sekiro: a floating bar above the enemy, damage cuts the red at once, a yellow segment shows the damage and drains after a delay. No white flash on enemies. Damage numbers exist only as a debug aid, at the top right of the bar.
- The helm splitter, draw slash, and charged iai get a hitbox 1.5x the blade, grown from the tip (data: `hitbox_length_scale`).
- The standard Godot way: the user adds the `Hitbox` node in the editor and names the layers; the scripts still set their own layers and fall back to code if the node is missing.

**What exists**
- `scripts/combat/`: `Layers` (team enum, layer bit values), `HitData` (damage, posture_damage, hitstop, attacker, action, direction, point), `Combatant` (HP, `take_hit`, `reset`, signals), `Hurtbox`, `Hitbox`, `Hitstop`.
- `Hitbox.sweep()` tests the box with `intersect_shape` at steps (at most every 0.15 m of travel) between the last and current transform, so fast swings cannot skip a target. `begin_swing(scale)` clears the hit set; `end_swing()` hides the debug box.
- `ActionState._update_hit()` runs every frame after `_on_action_update()`; `_hit_was_active` marks the swing; `exit()` closes it. Hook `_hit_damage_multiplier()` (overridden in `AttackState`).
- `SwordVisual.hitbox` (export) follows `_hand.transform`; created in code with a warning if unset. `Player.on_hit_landed()` calls `notify_combat()` and `Hitstop.request()`.
- Damage in the `.tres` files: attacks 1 to 4 = 10, attack 5 = 15, thrust = 15, dash slash = 10, dash thrust = 15, crouch loop = 8, upward slash = 12, air loop = 10, helm splitter (both) = 25, draw slash = 15, charged iai = 20. All placeholders.
- Dummy: `scenes/enemy/dummy.tscn`, `scripts/enemy/dummy.gd`, `scripts/ui/enemy_bar.gd`.

**Rules not obvious from the code**
- While a hold is waiting or charging, the action clock is parked at the start of the hit window, so `AttackState._hit_is_active()` requires `_phase == NORMAL`.
- The helm splitter dive keeps its clock inside the active window, so the box is open the whole dive and hits once; the landing action has damage 0 and does not hit.
- Hitstop slows `Engine.time_scale` with a real-time timer; overlapping requests extend it (a token check restores the scale only after the last).
- Godot rewrites some `.tres` files after saving (adds uids, drops properties equal to the default, such as `charge_damage_max`); that is not a gameplay change.

**Not done**
- The player's hurtbox and the player taking damage (4b); the dummy attacking (4b).
- Posture and its bar (Step 6); sparks, sound, and camera shake (Step 11, hitstop is the hook).
- The iai shockwave; sheathed and drawn animation sets.

**Noticed, not fixed**
- None.

### Step 4b: player hurtbox profiles, taking damage, dummy attacks, hit wobble (2026-10-07)

Tested and approved by the user. The player hit wobble was added afterwards at the user's request and documented here on the user's word that it works (not separately play-tested by Claude, and Godot was not run). Docs: handoff updated (4b ticked, Step 5 next).

**Decisions (agreed with the user before building)**
- The dummy attacks now (an exception to "does not fight back yet"), because duck-under cannot be tested otherwise; the real enemy is Step 7.
- Stand 1.8/0, crouch 1.1/0, air 1.1/0.7 hurtbox profiles, as `HurtboxProfile` resources (`resources/hurtbox/`), set as defaults on the Player exports.
- Taking a hit: HP loss, `notify_combat()`, hitstop, ledge knock-off, wobble; no stun (Step 6) and no death (Step 10).
- The standard Godot way again: the user adds `Hurtbox` and `Combatant` nodes in `player.tscn` and fills the two Player slots; code creates them with a warning if missing.

**What exists**
- `Player`: `_setup_hurtbox()` (finds or creates the nodes, forces team and layer to Player, sets `hurtbox.is_invulnerable`, gives the hurtbox its own capsule with the body's radius), `_update_hurtbox()` (called after `move_and_slide()`), `_on_damaged()`, `_on_died()` (temporary refill), `_process()` (wobble), group `player`.
- `Player.max_health` overrides the Combatant node's own value.
- `Dummy`: phases IDLE, WINDUP, ACTIVE, RECOVER; `attack_mode` OFF, CYCLE (high, low, mid), HIGH, MID, LOW; exports for range (2.6), reach (2.0 from its center, the arm starts 0.3 m out), arc (120), timings (0.6 / 0.25 / 0.7, pause 1.2), damage 20, hitstop 0.08, heights, turn speed. It faces the player while idle only. Hits are passed through `Hitbox.sweep()`; the hitstop comes from the player's `_on_damaged`, so a hit never requests it twice.
- Debug overlay line: HP and the hurtbox posture name.

**Rules not obvious from the code**
- While the player is invulnerable, a swing is not recorded as having hit: if the i-frames end while the arm still overlaps, the hit lands (the hit set only records real hits).
- The air profile applies the moment the feet leave the floor (also during the helm splitter dive, wall jump and mid-air reach), so a low sweep clears a jumping player at once; hanging and climbing a ledge use the stand profile.
- The wobble sets only `Visual.position` and the x and z rotation; the yaw (facing) stays with `face_direction()`.

**Not done**
- Stun and hit reactions (Step 6), death and retry (Step 10), guard and deflect (Step 5), posture (Step 6).
- Real enemy attack data, danger symbols, and AI (Step 7); sparks, sound, and camera shake (Step 11).

**Noticed, not fixed**
- None.

### Jump tuning, 2x (2026-10-07, after Step 4b)

Tested and approved by the user ("it finally feels like Sekiro"). Docs: handoff updated.

**Decisions**
- The user first asked for a 3x jump distance. Option A (gravity to a third, same take-off speed) was built and felt floaty, so it was undone and redone at 2x with a middle option: faster take-off and a little less gravity.
- The arena was restored from the user's snapshot before the 2x edit, so no 3x edits remain.

**What exists**
- `Player.jump_velocity` 8.5, `gravity_multiplier` 1.5 (were 7.0 and 2.0): about 2.5 m high, 1.2 s air time, 7.5 m run jump.
- `test_arena.tscn`: tops above the floor doubled for LowPlatform (1.85), TightPlatform (2.40), HighPlatform (3.30), Pillar (8.11), Wall and Wall2 (6.36), Gap (3.44, a slab that moved up and kept its thickness). Bottoms and horizontal positions unchanged.

**Rules not obvious from the code**
- Wall jump up speed is `jump_velocity` x `wall_jump_boost` (1.2), so it rose too (about 3.5 m). The helm splitter dive (2.5x) and the half-gravity opening (0.5x) are multiples of `gravity_multiplier`, so they follow any change to it.
- Jump height = speed squared over (2 x 9.8 x `gravity_multiplier`); air time grows with speed over gravity, so lowering gravity stretches the whole arc and is what made the 3x feel floaty.

**Not done**
- A heavier fall than rise (`fall_gravity_factor`, around 1.5) was offered and not built.
- The horizontal gaps between platforms were not widened.

**Noticed, not fixed**
- None.


### Step 5: guard, deflect, shrinking window, jump versions (2026-10-07)
**Decisions (user)**
- Spam shrink (O3) is linear: -0.04 s per rapid re-press, floor 0.05 s, reset after 1 s of neither guarding nor acting. Same in the air.
- Chip damage is a toggle, off by default (the Sekiro default); 15% of the hit when on. Until Step 6, a plain guard therefore costs nothing.
- Guard from sheathed snaps the sword out into a guard-draw pose; later presses are plain deflects. Only the right arm is modelled, so the left hand on the scabbard is not shown.
- Knockback applies on a hit, a plain guard, and a deflect, scaled per outcome (1.0, 1.0, 0.6). It is an easing push, not a stun, so a re-deflect stays snappy.
- The deflect window keeps running after the button is released (like Sekiro).
- One step, not split into 5a and 5b.
**Files:** new `scripts/player/states/guard_state.gd`. Changed `combatant.gd` (guard rules, signals), `hit_data.gd` (`Outcome`, guardable, deflectable, knockback), `action_data.gd` (`knockback`), `input_buffer.gd` (tracks guard), `player.gd`, `sword_visual.gd`, `action_state.gd`, `locomotion_state.gd`, `crouch_state.gd`, `air_state.gd`, `dash_state.gd`, `ledge_climb_state.gd`, `dummy.gd`, `debug_overlay.gd`. No `actions/guard.tres` was made (the numbers are exports on `Combatant`).
**Rules not obvious from the code**
- Guard cancels any action outside its own hit window; a press during the window stays buffered (0.15 s). Crouched actions under a low ceiling ignore it. The ledge climb and hang are excluded.
- `GuardState` ends on release only after `deflect_left` is 0, so a quick tap keeps its whole window (and the cone guard for that tail).
- Combatant outcome order: DEFLECT (guarding, in the cone, deflectable, window open), then GUARD (in the cone, guardable), else HIT. Behind you or unguardable = full hit.
- Knockback is added to the velocity only for `move_and_slide()` and taken off again, so states never see it (not applied during the ledge climb).
- `Player` creates a `Guard` state in code if the scene has none (a warning is logged); this runs once at startup, not per frame.
**Not done:** posture and its effects (Step 6), enemy guard and deflect and grabs (Step 7), clash (Step 8), lock-on (Step 9), sparks, sound, shake (Step 11); the left hand of the guard-draw pose.
**Noticed, not fixed**
- None.

### Step 5 follow-up: spam reset check (2026-10-07)
- The user thought the shrinking window did not reset after an attack. By design (3.2: it resets after 1 s of neither guarding nor acting), acting holds the count and the 1 s starts once the action ends. The overlay also showed the last window opened, not the next one, so it looked stuck.
- Added: the overlay shows the next window, the press count, and the idle time toward the 1 s reset; `Combatant.debug_log` prints presses, resets, and outcomes. Awaiting the user's result; if "acting resets it at once" is wanted instead, that is a one-line change in `Combatant.tick_guard()`.
- Cleanup added to the backlog (remove the create-if-missing fallbacks in `player.gd`); rule added to the conventions and the work agreement: no node-creation fallbacks.

### Step 5 follow-up 2: acting resets the spam count (2026-10-07)
- The log showed attack, deflect, attack, deflect still shrinking the window to the 0.05 s floor (16 presses), because acting only held the count. Not spam, so it must not shrink.
- `Combatant.tick_guard(delta, guard_up, acting)`: any action (every `ActionState`) resets the count at once; guarding holds it; 1 s of neither still resets it. Debug log line: `spam count reset by acting`.

### Step 5 follow-up 3: log off by default (2026-10-07)
- The user confirmed the spam reset works (attack resets the count; only back-to-back presses shrink the window). `Combatant.debug_log` now defaults to off; the on-screen overlay line is unchanged. Step 5 is closed.

### Step 6: posture, posture break, deathblow, player stagger (2026-10-07)
Built in the main zip, then three follow-ups (fix1: charged posture and defense; fix2: the deathblow thrust and the marker; marker look exports). All tested by the user.

**Decisions (confirmed by the user):**
- Posture is a 0 to 100 meter on the shared `Combatant`, filling up. Full = posture break. Per outcome the defender takes: plain guard 100% of the hit's `posture_damage`, deflect 10%, unguarded hit 50%; on a deflect the ATTACKER takes 50% (found with `Combatant.of(hit.attacker)`, which reads a `combatant` property on the attacker).
- Placeholder amounts: every attack's `posture_damage` is about 1.5x its `damage` (set in the 17 attack `.tres` files); the dummy's swing carries 25 (`attack_posture_damage`).
- Regen: 15 per second after 1 s without posture damage; paused while the owner attacks, dashes, or dodges (`ActionData.pauses_posture_regen`, `DashState`); x0.5 at 0 HP, linear to x1 at full HP; player only: x2 after guarding for 3 s (`fast_regen_on_guard`, set by `Player._setup_hurtbox()`).
- Player stagger (`StaggerState`): posture full leads to 6 s, no walking, guard, or attack; dodge locked for the first 2 s, then a dodge cancels it; `Combatant.vulnerable` makes unguarded hits do x1.5 damage; posture resets to 0 when it ends (any way). Placeholder visual: a forward lean (`Player.set_stagger_lean`, `stagger_lean` 0.5 rad). A break during a ledge climb waits for it to finish (`_stagger_pending`); hanging is knocked off first.
- Enemy side (the dummy for now; the Step 7 enemy reuses it): `health_bars` (dummy 2, `Combatant.health_bars`) shown as pips on one bar. An empty bar fills posture and opens a deathblow window (4 s, `deathblow_window`); a posture break at any health opens the same window. `execute_deathblow()` inside it removes a bar (the next starts full, posture 0); on the last bar it kills. Missed: health returns to 1 (not refilled) and posture to 0, so the next damage empties it again, repeating until a deathblow. A missed window on the final bar of a non-boss kills it; `boss` (off by default) loops at 1 HP instead. This settles O1.
- Deathblow input: a fresh `attack` press within 2.5 m, inside a 120 degree cone in front, of an enemy in group `enemy` whose window is open (`Player._try_deathblow()`, checked before the state update, from any state that can cancel and is not in a hit window; ground only). `DeathblowState` is an `ActionState` with no hitbox: it steps toward the target (stops 1.1 m short) and calls `execute_deathblow()` halfway through `active_hit`; guard cannot cancel before that. Visual: thrust poses (`deathblow_thrust.tres`) when drawn, the draw slash poses when sheathed; timing always comes from `deathblow.tres`.
- UI: posture bar under the health bar, filling from both ends toward the middle (white to orange, red when full); pips top left (only with 2 or more bars); a deathblow marker on the enemy's chest while the window is open (a code-drawn dot with a thick dark-red outline, white-reddish fill, red glow, gentle pulse; all looks are `EnemyBar` exports: size, offset, pulse, dot ratio, outline thickness, glow alpha, four colors). The player's posture is on the debug overlay only (Posture line, Deathblow target, a STAGGER line).
- fix1: `ActionData.charge_posture_max` (default 1.5, like `charge_damage_max`) scales posture damage with the charge, separate from damage (`AttackState.posture_multiplier`, `ActionState._hit_posture_multiplier()`). `Combatant` Defense group: `health_taken_multiplier` and `posture_taken_multiplier` (both 1.0), applied last (health covers damage and chip; posture covers every posture hit, including a deflect's posture on an attacker). For the Step 7 `EnemyAIData`.

**Files:** new `scripts/player/states/stagger_state.gd`, `deathblow_state.gd`, `actions/deathblow.tres`, `actions/deathblow_thrust.tres`. Changed `combatant.gd`, `hit_data.gd`, `player.gd`, `dummy.gd`, `enemy_bar.gd`, `debug_overlay.gd`, `action_state.gd`, `attack_state.gd`, `action_data.gd`, and the 17 attack `.tres` files (one `posture_damage` line each). Editor: `Stagger` and `Deathblow` nodes under the player's StateMachine.

**Not obvious from the code:**
- `DeathblowState` sets its own `action` to `deathblow.tres` in `_ready()` if the Inspector's Action is empty.
- `Dummy._ready()` copies `health_bars`, `boss`, and `deathblow_window` to its Combatant, then calls `combatant.reset()` before binding the bar (children are ready before the parent, so `Combatant._ready()` runs first).
- Hits during an open window do no health damage (health is already 0) and add no posture (already full).
- All the resets to 0 (window end, stagger end, a landed deathblow) are instant on purpose; regen is the only gradual part.
- Posture breaks only on posture damage; the old rule that HP 0 on the player refills after 1.5 s is unchanged (Step 10).

**Not done:** a player HUD posture bar (Step 11), a stagger animation, sparks and sounds, the enemy's recovery pose and AI (Step 7), a countdown ring on the marker.
**Noticed, not fixed:** staggering under a low ceiling stands the player up (the Crouch and Slide `exit()` do it, no headroom check).

### Step 7a: enemy core (2026-10-07)
Decisions: Step 7 is split into 7a (enemy core, done), 7b (guard, deflect, riposte, recovery pose, adaptive guard chance) and 7c (perilous thrust, sweep, grab, danger symbols, mikiri and jump-over). The enemy is a new scene (`scenes/enemy/enemy.tscn`, root `Enemy`, a `CharacterBody3D`); the `Dummy` stays as a test target (set its Attack Mode to OFF to test the enemy alone). Its normal attacks are the PLAYER's ground combo (`weapon.combo`, `katana.tres`: attack_1 to attack_5) played through a second `SwordVisual` (arm-swing sword), so the wind-up pose is the telegraph; `EnemyAIData.damage_scale` (2.0) and `posture_scale` (1.5) scale the player-sized numbers so no attack `.tres` was touched. Hits keep the visual recoil wobble but never interrupt the enemy (only a posture break or an empty bar stuns it).
Files: new `scripts/enemy/enemy.gd`, `resources/enemy_ai_data.gd`, `ai/enemy_default.tres`, `scenes/enemy/enemy.tscn` (hand-written, shipped in the fix1 zip after the node list was asked for). No existing file changed: `SwordVisual` already works with no Player parent (`_player` stays null).
Rules not obvious from the code: the AI loop is IDLE, CHASE, ATTACK, RECOVER, YIELD, STUNNED. A burst is 2 to 4 combo hits (`attack_burst_count`, capped by the combo length); each chains at the action's cancel window start plus `chain_delay`, never inside the hit window. It turns toward the player and aims its lunge only during an attack's wind-up (locks when the hit window opens, like the player); the lunge stops at `lunge_min_distance`. After a burst: `recovery_time` standing still, then YIELD (circles at `preferred_distance`, length from `yield_time` scaled by `aggression`), then CHASE. The Hitbox team is set in code (`Layers.Team.ENEMY`); `Hurtbox.team` must be Enemy in the scene. It joins group `enemy` (the player's deathblow finds it). Posture regen is paused only while attacking. A missing `ai`, `weapon`, or Hitbox assignment is a `push_error` and the enemy stays idle.
Not done: guard, deflect, riposte, recovery pose (7b); the perilous thrust, sweep, grab, danger symbols and their counters (7c); knockback onto the enemy; a ledge check or NavMesh (it steers straight at the player and slides along walls); the `EnemyAIData` defense fields exist but are not read yet.
Noticed, not fixed: all numbers are untuned placeholders; the enemy keeps chasing a player standing on an unreachable platform; the dummy's recoil direction ignores the dummy's rotation (the enemy's does not).

### Step 7b: enemy defense (2026-10-08)
Decisions: the enemy defends by situation, all in `EnemyAIData` so each enemy type is a different `.tres` (presets in `ai/`: `enemy_soldier` is the user-approved generic guard-and-let-me-attack enemy; `enemy_duelist`, `enemy_aura`, `enemy_repulser` are tuned by feel and not yet play-tested by the user). Chances are per situation: neutral, and pressured (a hit landed within `retry_window` 1 s); `guard_chance` is the chance of guarding at all and `deflect_chance` the chance that the guard is a timed deflect (take = 1 - guard, deflect = guard x deflect). A deflect may be a repulse (`repulse_chance`). Repulse as the user defined it: the attacker is bounced back and its swing is CUT (visual blade bounce), but it is not stunned and can guard, jump or dodge at once; the combo is back at attack 1.
Files: new `ai/enemy_soldier.tres`, `enemy_duelist.tres`, `enemy_aura.tres`, `enemy_repulser.tres`; changed `scripts/enemy/enemy.gd`, `resources/enemy_ai_data.gd`, `scenes/enemy/enemy.tscn` (new `Aura` node, a translucent sphere under the root), `scripts/combat/combatant.gd`, `scripts/player/player.gd`. `enemy_default.tres` is the old 7a file (the script defaults apply).
Rules not obvious from the code: the enemy reads the player's current attack (`player.state_machine.current as ActionState`: kind ATTACK, damage > 0, before `active_hit.y`, within `threat_range` 3.5 m); a charge with a frozen action clock is not a threat. A new threat rolls the plan once: guard (plus `repeat_attack_guard_bonus` per repeat of the same player attack, reset after 3 s idle), deflect, repulse. A plain guard waits `reaction_delay`; a planned deflect presses so the Combatant window (`next_window()`) is centered on the hit (`active_hit.x` minus half the window, +-0.03 s jitter) whatever the reaction delay; while pressured the guard comes up at once. It can guard only in IDLE, CHASE and YIELD (never in its own attack, RECOVER, FLINCH, POSE or STUNNED): that is where openings come from. `Combatant.press_guard(repulse := false)` opens a repulse window; a deflect inside it adds `repulse_attacker_posture_extra` (0.5 of the hit's posture) to the attacker and emits `Combatant.repulsed(hit, knockback)` on the attacker (`repulse_knockback` 1.5 m). The player handles it in `Player._on_repulsed` (knockback, recoil) and `_update_repulse()` at the start of the next physics frame (not inside the sweep): AttackState goes to Locomotion (Crouch if crouched), AirAttack and HelmSplitter go to Air, then `SwordVisual.play_guard_hit(true, side)`. Flinch: only unguarded hits that land; `hit_stun_time`, per moment `flinch_in_windup`, `flinch_in_recovery`, `flinch_in_neutral`, never during its own hit window; after a flinch `flinch_immunity_time` 0.6 s (no stunlock). `hit_streak_limit` 2: after two unguarded hits in a row the next threat is guarded (resets on a guard, or after 3 s). Riposte: after a deflect, `riposte_chance`, `riposte_delay` 0.15 s, then a burst of `riposte_burst_count` combo hits. Recovery pose: posture >= `posture_pose_threshold` of max, no player attack for `pose_idle_time` 1.5 s, in YIELD: stands in the white aura, posture regen x`pose_regen_factor`, ends at `pose_end_posture` or `pose_max_time`, any damage ends it, `pose_cooldown` 3 s.
Pressure update (fix3, shipped but NOT yet tested by the user): `riposte_armor` (a landed hit cannot flinch it from the deflect to the end of the riposte burst; your hits still do damage and posture) and `pressure_break_hits` (after that many of your hits guarded or deflected in a row, mostly the set number and with `pressure_break_early_chance` 0.3 a random lower one, its next defense is a forced deflect with a guaranteed riposte; resets when a hit lands on it, when it attacks, or after 3 s). Tempo per preset: duelist aggression 0.85, yield 0.8 to 1.8, recovery 0.5, armor on, break-out 4; aura aggression 0.3, yield 1.5 to 3.0, burst 1 to 3, recovery 0.8, no armor; repulser aggression 0.7, yield 1.0 to 2.0, burst 1 to 3, recovery 0.6, armor on, break-out 3; the soldier is unchanged.
Not done: the Shura-style dodge defense; the enemy's held (charged) attack, planned with 7c for the perilous thrust; the perilous attacks, danger symbols and counters (7c); varied deflect animations (7d); a repulse-specific animation.
Noticed, not fixed: the first play log (soldier) showed stunlock and almost no deflects (fixed in fix2: flinch immunity, a deflect press independent of the reaction delay, a retry with no delay, the hit-streak limit, retuned chances); all numbers are placeholders; the pressure update is untested.

### Step 7c-1: perilous thrust and sweep, the monk, and the follow-up batch (2026-10-08)
The user tested 7c-1 ("works well") and confirmed the 7b pressure update (armored riposte, break-out, per-preset tempo) is fine too. Decisions: the perilous thrust and sweep are unguardable and undeflectable (the design doc only said it of the grab); the thrust is the weapon's charged thrust with the pull-back and orange glow as the telegraph, the sweep is `actions/enemy_sweep.tres` with the whole swing lowered by `SwordVisual.set_drop_target()`; a red `DangerSymbol` (Label3D under the Player, group `danger_symbol`) shows 0.5 s before the hit window until it closes; `Debug Force Perilous` on the Enemy forces one. Option A was taken: the sweep moved into 7c-1 so the monk is fully testable; the grab (open question O5) and enemy hitboxes at high/mid/low are 7c-2.
Files: new `scripts/ui/danger_symbol.gd`, `actions/enemy_sweep.tres`, `ai/enemy_monk.tres`; changed `scripts/enemy/enemy.gd` (phases `PERILOUS` and `COUNTERED`, `_pick_perilous`, `_check_counter`, `_countered`), `resources/enemy_ai_data.gd` (look, perilous and counter groups), `scripts/player/sword_visual.gd` (`setup(weapon, back_length)`, tail, `set_drop_target`), `scripts/combat/hitbox.gd` (`configure(length, back)`), `scripts/player/states/action_state.gd` (`get_move_direction()`), the duelist and repulser presets (thrust only).
Rules not obvious from the code: mikiri = the player is in `DodgeState` moving within 70 degrees of the line to the enemy, within `mikiri_range`, at any frame from the symbol until the hit window closes; jump-over = the player is not on the floor in the same span; both cut the attack, add posture (50 / 30) and stun it (1.0 s / 0.6 s, no guard, no flinch), and a posture break opens the deathblow instead. Super armor lasts until the hit window ends; after that the preset's `flinch_in_recovery` applies. Perilous damage and posture come from `EnemyAIData` (35 / 40, not scaled), applied on the enemy's own `HitData`, so `thrust.tres` stays guardable for the player. The monk's weapon is a copy of `WeaponData` (blade x2, `blade_back_length` 0.8 m); the tail's hitbox is part of the single damage box, so any swing's tail can connect.
Follow-up batch, shipped untested: `perilous_chain_chance` (a combo can continue into a perilous attack at each chain point; monk 0.5, duelist and repulser 0.25); the head bounce (`Enemy.take_head_bounce()` armed for `head_bounce_window` 1.5 s after a jump-over, `Player._update_enemy_head()` bounces the player at `head_bounce_velocity` 6.5 if it lands on that head in `AirState`, and otherwise slides it off at `head_slide_speed` 4); the enemy bobblehead flinch (visual only, pivoting `Visual` at the feet: after a jump-over, a shorter one on mikiri, a slow heavy sway with a drooping head during the deathblow stun); `EnemyBar` health dots are round red with a maroon outline in a strip attached to the bar's left end, lost ones hidden (`pip_lost_color` removed); the player's posture break also sinks to a knee and sways (visual only, `Player.set_stagger_kneel()`, planted).
Not done: the grab (7c-2); high/mid/low enemy hitboxes; other enemy body feedback (head snap per hit, recovery slump and breathing, a coil while charging; listed in the Phase 2 backlog); sounds and effects (Step 11); 7d. All numbers are placeholders; the sweep poses and its lowered hitbox height were guessed and may need tuning (`sweep_drop`).

### Step 7c-1 follow-up 2: stomp counter, air steering, tight thrust deflect (2026-10-08)
The user tested the first follow-up batch ("oke good") and asked for three changes. Decisions: the jump-over no longer cuts the sweep or wobbles the enemy when the player leaves the ground; jumping while the symbol shows only arms the counter (`_head_bounce_time`, `head_bounce_window` 1.5 s), the sweep goes on under the player, and landing on the head is the parry (`Enemy.on_stomped()` runs `_countered`: posture 30, stun 0.6 s, the bobble) and bounces the player; with no head landing it is only a dodge. Air movement: `AirState` now calls `Player.apply_air_steering()`, which keeps the horizontal velocity and adds the move input as a push of `air_steer_acceleration` 8 m/s^2, capped at the run speed (or the current speed if higher); facing still follows the input, so holding back faces backward while fighting the momentum; wall jump and air attacks are unchanged. The perilous thrust can be deflected again, but only if the hit lands within `perilous_deflect_window` (0.1 s) of the guard press (`HitData.deflect_within`, `Combatant._resolve` compares `current_window - deflect_left`); a plain guard does nothing, the sweep stays undeflectable, and the deflect is a normal one (no extra stun or cut).
Files: `enemy.gd`, `enemy_ai_data.gd`, `hit_data.gd`, `combatant.gd`, `player.gd`, `air_state.gd`. Shipped untested. Not done: an extra reward for the tight deflect (the user did not ask for one); the placeholders (steer 8, window 0.1) will need tuning.

### Step 7d: varied deflect poses and the perilous thrust knockback (2026-10-08)
The user tested the second follow-up batch ("good job") and chose the hybrid for 7d: four authored deflect poses, each aimed partly at where the attack connected. Decisions: kinds are side (one pose, mirrored for the left), high, low, and the thrust's slap (charged thrusts and `PERILOUS_THRUST` actions); a plain guard keeps its flick; the sweep needs none (it is not deflectable). The kind comes from the incoming `HitData` (action and contact height), the aim turns `deflect_aim_follow` (0.4) toward `hit.point`, and timings are snap 0.05 s, hold 0.12 s, return 0.15 s on top of the existing flick (0.6x, or 1x for the thrust) and white flash. A new guard press cancels the pose, so the snappy re-deflect still works. The same call serves the player and the enemy. Heavy thrust: `EnemyAIData.perilous_thrust_knockback` 3.0 m and `perilous_knockback_time` 0.4 s go on the thrust's `HitData` (new field `knockback_time`, -1 = the target's default); a landed thrust pushes 3.0 m and a deflected one 1.8 m (the player's 0.6 deflect multiplier); no stun. The weapon's `thrust.tres` is untouched.
Files: `scripts/player/sword_visual.gd` (`play_deflect`, `_deflect_kind_for`, `_apply_deflect_overlay`, exports under "Deflect poses (Step 7d)", `debug_force_deflect`), `scripts/player/player.gd`, `scripts/enemy/enemy.gd`, `scripts/combat/hit_data.gd`, `resources/enemy_ai_data.gd`. Shipped untested. Not done: sparks and sounds on contact (Step 11); the poses are guesses (use `debug_force_deflect` to see each one); the sweep and grab have no deflect pose; the knockback numbers are placeholders.

### Centered thrust and the new deflect spam rule (2026-10-08)
Decisions (user-approved): the thrust was visibly off to the right (windup at hour 3, end at hour 2.5, body twist to the right), so the three thrust actions (`thrust.tres`, `dash_thrust.tres`, `deathblow_thrust.tres`, which share their numbers) now use windup `(12, 0.1, -0.4)` and end `(12, 0.1, 1.3)`: the tip ends on the center line like the helm splitter, with no twist; the hand still sits at the right shoulder, so the blade slants a little (moving the hand to center was not done). The enemy's perilous thrust uses the same action. The deflect window now shrinks (0.04 s per step, floor 0.05 s) only on a rapid tap (under `deflect_rapid_interval` 0.35 s after the previous press) or from the 4th press of a run on (`deflect_free_presses` 3), so slow taps give 0.20, 0.20, 0.20, 0.16, 0.12 and rapid ones 0.20, 0.16, 0.12, 0.08, 0.05. The run resets on acting, 1 s idle without guarding, 3 s of holding the guard since the last press (`deflect_hold_reset_time`), a deflect, and an unguarded hit; a plain guard does not (it would let spam-blocking refresh itself). Enemies use the same rules (same `Combatant`).
Files: `scripts/combat/combatant.gd` (`shrink_steps`, `_since_press`, `_hold_time`, `_reset_spam`, `_next_press_shrinks`), the three thrust `.tres`, `docs/design-later-steps.md`, `docs/handoff.md`. Shipped untested. Noticed, not fixed: the thrust blade still starts at the right shoulder; the 7d deflect poses are still untested.
