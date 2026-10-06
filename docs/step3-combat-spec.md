# Step 3 Spec: Attacks, Combos, and Variants (Godot 4)

> Companion to `HANDOFF_sekiro_like_prototype.md` (the main handoff). Paste this together with the handoff and the work agreement when working on **Step 3**. All design below is **agreed by the user (2026-10-05); 3a-1, 3a-2, 3b-1, 3b-2, and 3b-3 are built (section 7), the rest of 3b and 3c are not**. Update the status table (section 1) at the end of each session.

---

## 1. Status and phasing

| Phase | Content | Status |
|---|---|---|
| **3a-1** | Ground 5-attack combo, loop, TAE-style chain/cancel, follow-through flourish, blending, lunge, sword visual (arm swing, body twist, arm lead), `WeaponData` | **built**; the user approved the look; cancels, lunge, and the ledge stop not formally tested yet |
| **3a-2** | Hold detection, charged zigzag thrust, chaining in and out of the thrust | **built and tested by the user**; the zigzag connects to the combo (section 5) |
| **3b-1** | Dash attack: tap = slash that continues into the combo, hold = simple thrust | **built**; the user tuned the lunge speeds and the slash angle (section 7.9) |
| **3b-2** | Crouch and slide attacks (a 3:00 to 9:00 / 9:00 to 3:00 loop that keeps you crouched; hold = the upward slash, alternating sides), crouch visuals for the sword | **built and tested by the user**; as built differs from the first design (section 7.10) |
| **3b-3** | Air tap loop (2:00 to 10:00, then 10:00 to 2:00, repeating) | **built and tested by the user** (section 7.11) |
| **3b-4** | Helm splitter (hold in the air) | not started; design agreed (section 6), send a full check first |
| **3c** | Sheathing (visual only) and the draw slash | not started; design agreed (2026-10-06), see section 7b; do it after 3a-2 |

Each phase is its own chat: paste handoff + work agreement + this spec + a fresh snapshot (`python pack_for_claude.py`). Confirm quickly with the user before building (the work agreement still applies).

Hitboxes, damage, and hitstop are **Step 4**. Attacks in Step 3 swing and chain but do not hurt anything; damage and posture values in the `.tres` files stay at 0 until Step 4.

---

## 2. Reading conventions

- **Clock positions** are seen **from behind the player** (camera view): 12 = up, 3 = right, 6 = down, 9 = left. 12:45 is 22.5 degrees past 12 toward 1.
- A slash is the **sword tip passing from one clock pose to the other, across the front of the body**, swung by an **arm swing** (see below). The path bows forward in the middle (the **slash arc**) so it sweeps through the space in front of the player. The wind-up pose is cocked back (behind and above); the end of the slash is in front.
- **Clock pose** = a `Vector3` (hour, radius in m, forward in m) saying where the sword's **tip** should pass; it is turned into an **aim point** (radius and forward times `pose_scale`) that the arm points at.
- **Arm swing** = the placeholder sword motion: the arm points from the right shoulder to the aim point, the hand sits at arm's reach, the blade bends at the wrist (**wrist angle**: cocked at the start of a cut, straightening through it), and the cutting edge leads along the direction of travel. Details in section 7.4.
- **Tap** = the attack button released before the decision point. **Hold** = still held at the decision point (the end of the wind-up, where the active window would begin). Quick taps cost no extra latency because the wind-up exists anyway. A hold only counts if the button stayed down since the action began (rapid clicks never read as a hold).
- **TAE-style behavior:** with no input the whole action plays out (including the flourish). A buffered input cuts the action at the earliest allowed point for that input, and the next action blends from the current pose.

---

## 3. Core rules (all attacks)

- **Windows** (seconds, from `ActionData`): wind-up = 0 to `active_hit.x`; **active** = `active_hit`; recovery = after `active_hit.y`. `locked_until` = `active_hit.y` (locked during the swing).
- **Cancels:** dodge, jump, crouch (and guard, from Step 5) can cancel **at any time except while the hit window is active**. Wind-up and recovery are both cancellable.
- **Attack chaining:** an attack press is accepted inside `buffer_window` (presses within the input buffer time before the window opens also count). The chain happens at `max(press time, cancel_window.x)`, i.e. the earliest available point. Pressing too early does nothing extra.
- **Flourish:** after the active window the sword drifts through a relaxed follow-through pose, slightly behind the player. It plays only if the player does not chain or cancel.
- **Steering:** you can turn toward the movement input during the wind-up; locked once the active window starts. **Also locked while locked on** (Step 9; until then the `AttackState._can_steer()` hook just returns true).
- **Lunge (forward momentum):** each attack moves the player forward through the action's move window. Direction = movement input at the attack start; with **no input, half strength forward** (in the facing direction). **While steering is allowed (before the active window), a held input keeps updating the direction (full strength); releasing it keeps the last direction and strength.** Attack 5 and the thrust have the most momentum.
- **Ledge stop:** a lunge never carries the player off an edge. If there is no floor `ledge_check_distance` ahead in the lunge direction (0.4 m default, 1.4 m in the user's scene) or `ledge_check_time` (0.14 s) of travel at the current lunge speed, whichever is larger, the lunge is dropped for that frame.
- **Reset:** the combo counter only continues through direct chains. If the attack finishes without a chain, or any other action takes over, the counter resets to step 1.
- **Combo counter semantics:** every attack (slash or thrust) advances the same counter through steps 1 to 5 and wraps to 1. A **thrust takes the step it falls on**. Example: attack 1, thrust (step 2), attack 3, thrust (step 4), attack 5, thrust (step 6, wraps to 1), then the next tap is attack 2.

---

## 4. Ground combo (3a-1)

| # | Wind-up | Slash | Notes |
|---|---|---|---|
| 1 | 1:00 (raised, back) | 1:00 to 7:00, downward | |
| 2 | follows from 7:00 | 7:00 up to 12:45 | rising slash; **alignment slightly different from a plain mirror of attack 1**, to look different |
| 3 | blends to 8:30 (still wind-up, cancellable) | 8:30 to 2:30 | |
| 4 | blends to 3:30 | 3:30 to 9:00 | |
| 5 | 11:00 | 11:00 to 5:00, downward | finisher; most lunge; the swing follows through toward the player's back |
| loop | after 5 the next press goes to 1 | | |

**Flourish:** each attack's follow-through pose is slightly behind the player (like attack 5's), played only if the combo is not continued.

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

Attack 1 has a deliberately long wind-up (0.35s) like the opener in Souls-likes; it also applies when the combo loops back to attack 1.

**Placeholder clock poses** (hour, radius m, forward m; all tunable in `actions/attack_N.tres`):

| # | wind-up | slash end | follow-through |
|---|---|---|---|
| 1 | 1:00, 1.0, -0.5 | 7:00, 0.9, 0.9 | 7:30, 0.8, -0.3 |
| 2 | 7:00, 0.9, -0.2 | 12:45, 1.0, 0.9 | 1:30, 0.9, -0.3 |
| 3 | 8:30, 0.9, -0.3 | 2:30, 0.9, 0.9 | 3:00, 0.8, -0.3 |
| 4 | 3:30, 0.9, -0.3 | 9:00, 0.9, 0.9 | 9:30, 0.8, -0.3 |
| 5 | 11:00, 1.0, -0.4 | 5:00, 1.0, 1.0 | 6:00, 0.8, -0.6 |

---

## 5. Hold: charged zigzag thrust (3a-2)

- **Decision point:** at the end of the wind-up. Still held = charge; released = normal slash.
- **Charge:** a pulled-back charge pose that glows more as it fills. **Auto-fires at max charge** (placeholder 0.6s). Releasing earlier fires with the charge so far.
- **Charge scaling:** damage multiplier 1.0 to about 1.5 and lunge 1.0 to about 1.4 at full charge (placeholders). The damage multiplier is stored now and used in Step 4.
- **Zigzag (as built, connected to the combo):** a thrust chained from a slash starts on the side where that slash **ended** (attacks 1 and 4 end left, 2, 3, and 5 end right, read from each attack's `swing_end` pose), so the sword is already there. Chained from a thrust it takes the **opposite** side, so repeated thrusts still alternate. Started from idle it is right-aligned. (The first design said the side resets after any normal attack; the user replaced that with this rule.)
- **Repeatable:** holding again after a thrust charges the next one.
- **Chaining:** any combo attack can chain into a thrust (hold) and a thrust can chain into the next combo step (see the counter semantics in section 3).
- **Lunge:** similar to attack 5 (the most forward momentum), scaled by charge.

**As built (3a-2), thrust values** (`actions/thrust.tres`, first-guess numbers scaled to the tuned attacks so the thrust is slower than any slash: its hit window opens at least 0.10 s later than the slash it replaces, and it lasts longer overall): duration 1.2, active_hit 0.10 to 0.26, locked_until 0.26, cancel_window 0.62 to 1.2, buffer_window 0.20 to 1.2, lunge 10.0 m/s over 0 to 0.42 (about 2.1 m, up to 14 m/s and about 2.9 m at full charge), charge_time 0.6, damage max 1.5, lunge max 1.4. **The user later tuned the thrust's lunge speed to 20 m/s.** Details and rules are in section 7.8.

---

## 6. Variants by context (3b)

"Tap" and "hold" follow the same definitions as in section 2.

| Context | Tap | Hold |
|---|---|---|
| Ground (standing) | combo (section 4) | zigzag thrust (section 5) |
| **Dash** (attack while dashing) | simple slash, **2:45 to 8:45** (the user's choice), that continues into the combo | simple thrust |
| **Crouch** | **as built:** a loop, 3:00 to 9:00 then 9:00 to 3:00, repeating; you stay crouched (the first design was one slash that uncrouches) | upward slash: wind-up to 8:00, slash to 1:00, stands you up and chains into attack 1; starts on the side where the previous attack ended (section 7.10) |
| **Slide** (attack while sliding) | same as the crouch tap | same as the crouch hold |
| **Jump** (airborne) | 2-attack loop: slash 2:00 to 10:00, then 10:00 to 2:00, repeating | **helm splitter** (Dante style): faster fall, motion from 12:00 to 6:00, **hold the blade at 6:00 until landing**, then a wind-down that can be cancelled |

**Decisions (2026-10-06, discussed and agreed with the user):**
1. Dash, crouch, and slide **tap** variants count as combo step 1: the next tap is attack 2 (as in the first design).
2. **No charge on any variant hold.** Dash hold = a simple thrust; crouch and slide hold = the upward slash (8:00 to 1:00). Holding at the end of the wind-up just selects a different attack.
3. **Dash attack:** it ends the dash; the lunge keeps the dash direction at a fixed speed (first guess 7 m/s; the user tuned the dash slash to 15 and the dash thrust to 20).
4. **Slide attack** is allowed after the slide's locked window, the same rule as the dodge and jump cancels.
5. **After a crouch attack** you stay crouched (changed in 3b-2: the tap is a loop). Only the hold (the upward slash) stands you up, and it needs headroom.
6. **Air attacks:** no limit while airborne (the 2:00 to 10:00 / 10:00 to 2:00 loop, built in 3b-3 as its own `AirAttack` state; landing restarts the loop); the **helm splitter only once per airtime**.
7. **No hover:** no gravity reduction or upward-speed damping during air attacks (the game is not DMC-style juggling).
8. **Helm splitter:** gravity multiplier 2.5x while diving, the blade held at 6:00 until landing, then a wind-down that can be cancelled (cancel window from about 0.3 s after landing).
9. **Crouch visuals:** the sword and arm swing lower with the body when crouched (a `SwordVisual` tweak, done in 3b-2).

**Phases:** 3b-1 dash (also the shared plumbing: variants start through `AttackState.try_start_variant()`, and each action can name its own `hold_action`), 3b-2 crouch and slide, 3b-3 the air tap loop, 3b-4 the helm splitter. A full check before each phase.

---

## 7. Data and code design

### 7.1 Principles (apply to all new combat code)
- **SOLID-minded:** behavior reads **data resources**, not hard-coded values; new moves are new `.tres` files, new mechanics are new state classes.
- A **weapon** is data (`WeaponData`); adding a weapon with the same kinds of moves is mostly new `.tres` files.
- The cleanup refactor of the traversal code (moving wall/ledge sensing out of `player.gd`, state name constants, a shared base so the enemy can reuse `ActionState`) is **deferred until all of Phase 1 is done and tested by the user**.

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
- **Not hooked up:** attacking during the wall-jump action. **Hold in the air** does nothing until 3b-4.
- **Values:** in the handoff, "Step 3b-3: what exists".

---

## 7b. Sheathing and the draw slash (3c, design agreed 2026-10-06, nothing built)

- **Two states, visual only:** the sword is **sheathed** (resting in a scabbard at the left hip, edge up, like a katana in a belt) or **drawn** (held relaxed at the side, edge down: the current rest pose). Sheathing changes no movement, speed, or rules.
- **Data:** `WeaponData` gets `sheathed_pose` (where the sword rests when sheathed; its edge-up direction too) and `draw_attack: ActionData` (the draw slash). `rest_pose` stays the drawn pose. A simple box scabbard is added at the left hip as a visual-only placeholder.
- **Draw slash:** pressing attack while sheathed plays the draw slash, a slash from **8:00 to 2:00** (left to right), and the sword ends up drawn. It uses the same `ActionData` windows and clock poses as any attack. **It chains into the normal combo: the next attack press is attack 1**, then 2 to 5 as usual (it ends near 1:00, where attack 1 winds up, so the blend is smooth).
- **Sheathe:** a dedicated button, **R** (a new Input Map action, `sheathe`; Claude gives the editor steps when building). It also **auto-sheathes after some idle time** (placeholder 5 s without combat). Proposed default for R when the sword is sheathed: draw it without attacking.
- **Open items (ask before building):** whether the sword starts sheathed or drawn at spawn (default: sheathed); the sheathe and unsheathe transition time; whether crouch, slide, dash, and jump attacks from the sheathed state draw instantly (default: yes); whether getting hit or dodging counts as combat for the auto-sheathe timer (default: any attack, hit, or dodge restarts it).
- **Animation later:** with real animation, locomotion needs a **sheathed and a drawn set** (idle, walk, sprint, dash, crouch, slide, jump, and so on), chosen by the sheathed flag. See section 8.

---

## 8. Later: real animation (notes for when the user learns Blender)

- Export a rigged character as glTF with one animation per action, named to match `ActionData.animation` (`attack_1`, `dodge`, `slide`, ...). Author them **in place** (no root motion); lunge and dodge speeds stay in the data.
- Swap the placeholder visuals for the model. The sword becomes a mesh on the hand bone.
- `ActionState` plays `action.animation` and seeks it to `action_time` each frame (the data stays authoritative).
- Retune each action's windows (`active_hit`, `cancel_window`, lunge window, duration) to the animation's timeline in the Godot animation editor.
- Locomotion (idle, walk, run, crouch) needs an `AnimationTree` with blend spaces driven by speed; actions play on top.
- With sheathing (3c), locomotion needs **two sets of animations, sheathed and drawn** (idle, walk, sprint, dash, crouch, slide, jump, ...), switched by the sheathed flag, plus draw and sheathe transitions.
- Each weapon's `ActionData` names its own animations, so weapons stay data-driven.