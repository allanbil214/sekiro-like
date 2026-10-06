# Step 3 Spec: Attacks, Combos, and Variants (Godot 4)

> Companion to `HANDOFF_sekiro_like_prototype.md` (the main handoff). Paste this together with the handoff and the work agreement when working on **Step 3**. All design below is **agreed by the user (2026-10-05); 3a-1 is built (section 7), 3a-2 and 3b are not**. Update the status table (section 1) at the end of each session.

---

## 1. Status and phasing

| Phase | Content | Status |
|---|---|---|
| **3a-1** | Ground 5-attack combo, loop, TAE-style chain/cancel, follow-through flourish, blending, lunge, sword visual (arm swing), `WeaponData` | **built**; the user approved the look; cancels, lunge, and the ledge stop not formally tested yet |
| **3a-2** | Hold detection, charged zigzag thrust, chaining in and out of the thrust | not started |
| **3b** | Crouch, slide, dash, and jump attack variants (tap and hold each) | not started; send a full check per variant group before building |

Each phase is its own chat: paste handoff + work agreement + this spec + a fresh snapshot (`python pack_for_claude.py`). Confirm quickly with the user before building (the work agreement still applies).

Hitboxes, damage, and hitstop are **Step 4**. Attacks in Step 3 swing and chain but do not hurt anything; damage and posture values in the `.tres` files stay at 0 until Step 4.

---

## 2. Reading conventions

- **Clock positions** are seen **from behind the player** (camera view): 12 = up, 3 = right, 6 = down, 9 = left. 12:45 is 22.5 degrees past 12 toward 1.
- A slash is the **sword tip passing from one clock pose to the other, across the front of the body**, swung by an **arm swing** (see below). The path bows forward in the middle (the **slash arc**) so it sweeps through the space in front of the player. The wind-up pose is cocked back (behind and above); the end of the slash is in front.
- **Clock pose** = a `Vector3` (hour, radius in m, forward in m) saying where the sword's **tip** should pass; it is turned into an **aim point** (radius and forward times `pose_scale`) that the arm points at.
- **Arm swing** = the placeholder sword motion: the arm points from the right shoulder to the aim point, the hand sits at arm's reach, the blade bends at the wrist (**wrist angle**: cocked at the start of a cut, straightening through it), and the cutting edge leads along the direction of travel. Details in section 7.4.
- **Tap** = the attack button released before the decision point. **Hold** = still held at the decision point (the end of the wind-up, where the active window would begin). Quick taps cost no extra latency because the wind-up exists anyway.
- **TAE-style behavior:** with no input the whole action plays out (including the flourish). A buffered input cuts the action at the earliest allowed point for that input, and the next action blends from the current pose.

---

## 3. Core rules (all attacks)

- **Windows** (seconds, from `ActionData`): wind-up = 0 to `active_hit.x`; **active** = `active_hit`; recovery = after `active_hit.y`. `locked_until` = `active_hit.y` (locked during the swing).
- **Cancels:** dodge, jump, crouch (and guard, from Step 5) can cancel **at any time except while the hit window is active**. Wind-up and recovery are both cancellable.
- **Attack chaining:** an attack press is accepted inside `buffer_window` (presses within the input buffer time before the window opens also count). The chain happens at `max(press time, cancel_window.x)`, i.e. the earliest available point. Pressing too early does nothing extra.
- **Flourish:** after the active window the sword drifts through a relaxed follow-through pose, slightly behind the player. It plays only if the player does not chain or cancel.
- **Steering:** you can turn toward the movement input during the wind-up; locked once the active window starts. **Also locked while locked on** (Step 9; until then the `AttackState._can_steer()` hook just returns true).
- **Lunge (forward momentum):** each attack moves the player forward through the action's move window. Direction = movement input at the attack start; with **no input, half strength forward** (in the facing direction). **While steering is allowed (before the active window), a held input keeps updating the direction (full strength); releasing it keeps the last direction and strength.** Attack 5 and the thrust have the most momentum.
- **Ledge stop:** a lunge never carries the player off an edge. If there is no floor 0.4 m ahead (a tunable export) in the lunge direction, the lunge is dropped for that frame.
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

**Placeholder clock poses** (hour, radius m, forward m; all tunable in `actions/attack_N.tres`):

| # | wind-up | slash end | follow-through |
|---|---|---|---|
| 1 | 1:00, 0.9, -0.3 | 7:00, 0.9, 0.9 | 7:30, 0.8, -0.3 |
| 2 | 7:00, 0.9, -0.2 | 12:45, 1.0, 0.9 | 1:30, 0.9, -0.3 |
| 3 | 8:30, 0.9, -0.3 | 2:30, 0.9, 0.9 | 3:00, 0.8, -0.3 |
| 4 | 3:30, 0.9, -0.3 | 9:00, 0.9, 0.9 | 9:30, 0.8, -0.3 |
| 5 | 11:00, 1.0, -0.4 | 5:00, 1.0, 1.0 | 6:00, 0.8, -0.6 |

---

## 5. Hold: charged zigzag thrust (3a-2)

- **Decision point:** at the end of the wind-up. Still held = charge; released = normal slash.
- **Charge:** a pulled-back charge pose that glows more as it fills. **Auto-fires at max charge** (placeholder 0.6s). Releasing earlier fires with the charge so far.
- **Charge scaling:** damage multiplier 1.0 to about 1.5 and lunge 1.0 to about 1.4 at full charge (placeholders). The damage multiplier is stored now and used in Step 4.
- **Zigzag:** thrusts alternate sides: **right-aligned first**, then left, then right, and so on. The side **resets after any action that is not a thrust**, including a normal attack.
- **Repeatable:** holding again after a thrust charges the next one.
- **Chaining:** any combo attack can chain into a thrust (hold) and a thrust can chain into the next combo step (see the counter semantics in section 3).
- **Lunge:** similar to attack 5 (the most forward momentum), scaled by charge.

---

## 6. Variants by context (3b)

"Tap" and "hold" follow the same definitions as in section 2.

| Context | Tap | Hold |
|---|---|---|
| Ground (standing) | combo (section 4) | zigzag thrust (section 5) |
| **Dash** (attack while dashing) | simple slash that continues into the combo | simple thrust |
| **Crouch** | one crouch attack: slash from 3:00 to 9:00, then **uncrouch**; can continue into the combo | upward slash: wind-up to 8:00, slash to 1:00 |
| **Slide** (attack while sliding) | same as the crouch tap | same as the crouch hold |
| **Jump** (airborne) | 2-attack loop: slash 2:00 to 10:00, then 10:00 to 2:00, repeating | **helm splitter** (Dante style): faster fall, motion from 12:00 to 6:00, **hold the blade at 6:00 until landing**, then a wind-down that can be cancelled |

Open items for 3b (ask before building): which combo step follows a crouch/slide/dash tap (default proposal: the variant counts as step 1, so the next tap is attack 2); how many air attacks per airtime; the helm splitter's fall-speed multiplier; whether the jump attack stops upward momentum briefly.

---

## 7. Data and code design

### 7.1 Principles (apply to all new combat code)
- **SOLID-minded:** behavior reads **data resources**, not hard-coded values; new moves are new `.tres` files, new mechanics are new state classes.
- A **weapon** is data (`WeaponData`); adding a weapon with the same kinds of moves is mostly new `.tres` files.
- The cleanup refactor of the traversal code (moving wall/ledge sensing out of `player.gd`, state name constants, a shared base so the enemy can reuse `ActionState`) is **deferred until all of Phase 1 is done and tested by the user**.

### 7.2 `WeaponData` (new resource, `resources/weapon_data.gd`)
- `display_name: String`
- `combo: Array[ActionData]` (the 5 ground attacks, in order)
- `blade_length: float` (1.1 m placeholder), `blade_thickness: float` (used as the blade's **width**, edge to spine; 0.14 m)
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
- Segments over `action_time` (data stays authoritative, no tweens): blend from the captured previous pose to the wind-up, wind-up to end (the active window, fast ease, the blade turns red), end to follow-through. Returns to `rest_pose` (hand on the arm line toward it, blade pointing down and forward, edge up) when the combo ends.
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
Thrust and hold (3a-2), all variants (3b), hitboxes and damage (Step 4), guard cancels (Step 5), real sword mesh and animation.

---

## 8. Later: real animation (notes for when the user learns Blender)

- Export a rigged character as glTF with one animation per action, named to match `ActionData.animation` (`attack_1`, `dodge`, `slide`, ...). Author them **in place** (no root motion); lunge and dodge speeds stay in the data.
- Swap the placeholder visuals for the model. The sword becomes a mesh on the hand bone.
- `ActionState` plays `action.animation` and seeks it to `action_time` each frame (the data stays authoritative).
- Retune each action's windows (`active_hit`, `cancel_window`, lunge window, duration) to the animation's timeline in the Godot animation editor.
- Locomotion (idle, walk, run, crouch) needs an `AnimationTree` with blend spaces driven by speed; actions play on top.
- Each weapon's `ActionData` names its own animations, so weapons stay data-driven.