# Step 3 Spec: Attacks, Combos, and Variants (Godot 4)

> Companion to `HANDOFF_sekiro_like_prototype.md` (the main handoff). Paste this together with the handoff and the work agreement when working on **Step 3**. All design below is **agreed by the user (2026-10-05); nothing in it is built yet**. Update the status table (section 1) at the end of each session.

---

## 1. Status and phasing

| Phase | Content | Status |
|---|---|---|
| **3a-1** | Ground 5-attack combo, loop, TAE-style chain/cancel, follow-through flourish, blending, lunge, sword visual, `WeaponData` | not started (design agreed, full check sent) |
| **3a-2** | Hold detection, charged zigzag thrust, chaining in and out of the thrust | not started |
| **3b** | Crouch, slide, dash, and jump attack variants (tap and hold each) | not started; send a full check per variant group before building |

Each phase is its own chat: paste handoff + work agreement + this spec + a fresh snapshot (`python pack_for_claude.py`). Confirm quickly with the user before building (the work agreement still applies).

Hitboxes, damage, and hitstop are **Step 4**. Attacks in Step 3 swing and chain but do not hurt anything; damage and posture values in the `.tres` files stay at 0 until Step 4.

---

## 2. Reading conventions

- **Clock positions** are seen **from behind the player** (camera view): 12 = up, 3 = right, 6 = down, 9 = left. 12:45 is 22.5 degrees past 12 toward 1.
- A slash is the **sword tip moving in a straight line (a chord) across the front of the body** from one clock position to the other. The wind-up pose is cocked back (behind and above); the end of the slash is in front.
- **Tap** = the attack button released before the decision point. **Hold** = still held at the decision point (the end of the wind-up, where the active window would begin). Quick taps cost no extra latency because the wind-up exists anyway.
- **TAE-style behavior:** with no input the whole action plays out (including the flourish). A buffered input cuts the action at the earliest allowed point for that input, and the next action blends from the current pose.

---

## 3. Core rules (all attacks)

- **Windows** (seconds, from `ActionData`): wind-up = 0 to `active_hit.x`; **active** = `active_hit`; recovery = after `active_hit.y`. `locked_until` = `active_hit.y` (locked during the swing).
- **Cancels:** dodge, jump, crouch (and guard, from Step 5) can cancel **at any time except while the hit window is active**. Wind-up and recovery are both cancellable.
- **Attack chaining:** an attack press is accepted inside `buffer_window` (presses within the input buffer time before the window opens also count). The chain happens at `max(press time, cancel_window.x)`, i.e. the earliest available point. Pressing too early does nothing extra.
- **Flourish:** after the active window the sword drifts through a relaxed follow-through pose, slightly behind the player. It plays only if the player does not chain or cancel.
- **Steering:** you can turn toward the movement input during the wind-up; locked once the active window starts.
- **Lunge (forward momentum):** each attack moves the player forward through the action's move window. Direction = movement input at the attack start; with **no input, half strength forward** (in the facing direction). Attack 5 and the thrust have the most momentum.
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
- `blade_length: float` (1.1 m placeholder), `blade_thickness: float`
- `rest_pose: Vector3` (sword at rest, same pose format as below)
- Later phases add: `thrust: ActionData`, `dash_attack`, `crouch_attack`, and so on.
- The Player gets `@export var weapon: WeaponData`; `weapons/katana.tres` is the first weapon.

### 7.3 `ActionData` additions (placeholder visual poses)
Each pose is a `Vector3`: **(clock hour, radius in m, forward in m)**; forward is in front of the player (negative = behind).
- `swing_windup` (wind-up pose = slash start), `swing_end` (slash end), `swing_follow` (flourish pose).
- These only drive the placeholder sword. When real animation arrives they become unused (the `animation` name takes over).

### 7.4 `SwordVisual` (new, `scripts/player/sword_visual.gd`, `Node3D` under `Visual`)
- Builds a box blade in code (like `ReachArms`). Pivot at the right shoulder. The blade points from the hand toward the pose's tip position.
- Pose to position: tip = (sin(hour*30deg)*radius, center height + cos(hour*30deg)*radius, -forward) in the player's local space.
- Segments over `action_time`: blend from the captured previous pose to `swing_windup` (wind-up), `swing_windup` to `swing_end` (active window, fast ease), `swing_end` to `swing_follow` (flourish). Positions are interpolated as points, so slashes are chords.
- Turns red during the active window. Returns to `rest_pose` when the combo ends.

### 7.5 `AttackState` (new, `scripts/player/states/attack_state.gd`, extends `ActionState`)
- Overrides `enter` to pick `action = weapon.combo[index]` (index 0 when coming from another state, the next index when chaining from `Attack`), then calls the base.
- Handles steering during the wind-up, the lunge direction and half-strength rule, the buffer window, the chain at the earliest allowed point, and the cancel rules (section 3).
- On exit to anything but `Attack`, resets the counter and releases the sword.

### 7.6 3a-1 files and editor steps
- **New:** `resources/weapon_data.gd`, `weapons/katana.tres`, `actions/attack_1.tres` to `attack_5.tres`, `scripts/player/states/attack_state.gd`, `scripts/player/sword_visual.gd`.
- **Modified:** `resources/action_data.gd`, `scripts/player/player.gd`, `scripts/player/input_buffer.gd` (track `attack`), `scripts/player/states/locomotion_state.gd` (attack starts the combo), `scripts/ui/debug_overlay.gd` (combo step and open windows).
- **Editor:** under `Player/StateMachine` add a `Node` named exactly `Attack` (script `attack_state.gd`); under `Player/Visual` add a `Node3D` named `SwordVisual` (script `sword_visual.gd`); on the `Player` root set **Weapon** to `weapons/katana.tres`. No Input Map changes (`attack` already exists).
- Delivered as a zip `sekiro-like_attack-combo.zip` (complete files, real paths).

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