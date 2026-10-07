# Step 3 Spec: Attacks, Combos, and Variants (Godot 4)

> Companion to `HANDOFF_sekiro_like_prototype.md` (the main handoff). Paste this together with the handoff and the work agreement when working on **Step 3**. All design below is **agreed by the user (2026-10-05); 3a-1, 3a-2, 3b-1, 3b-2, 3b-3, 3b-4, 3c-1, and 3c-2 are built (section 7), so all of Step 3 is done**. Update the status table (section 1) at the end of each session.

---

## 1. Status and phasing

| Phase | Content | Status |
|---|---|---|
| **3a-1** | Ground 5-attack combo, loop, TAE-style chain/cancel, follow-through flourish, blending, lunge, sword visual (arm swing, body twist, arm lead), `WeaponData` | **built**; the user approved the look; cancels, lunge, and the ledge stop not formally tested yet |
| **3a-2** | Hold detection, charged zigzag thrust, chaining in and out of the thrust | **built and tested by the user**; the zigzag connects to the combo (section 5) |
| **3b-1** | Dash attack: tap = slash that continues into the combo, hold = simple thrust | **built**; the user tuned the lunge speeds and the slash angle (section 7.9) |
| **3b-2** | Crouch and slide attacks (a 3:00 to 9:00 / 9:00 to 3:00 loop that keeps you crouched; hold = the upward slash, alternating sides), crouch visuals for the sword | **built and tested by the user**; as built differs from the first design (section 7.10) |
| **3b-3** | Air tap loop (2:00 to 10:00, then 10:00 to 2:00, repeating) | **built and tested by the user** (section 7.11) |
| **3b-4** | Helm splitter (hold in the air), plus the air tap loop sped up 1.5x | **built and tested by the user**; the dive is a slash-style swing with a crouched body (section 7.12) |
| **3c-1** | Sheathing (visual only), R, auto-sheathe, the animated hand reach, the draw slash (iai) replacing every attack while sheathed, and the dodge attack | **built and tested by the user** (2026-10-07), see section 7b |
| **3c-2** | The charged iai (hold while sheathed) and the sheathed helm splitter | **built and tested by the user** (2026-10-07), see section 7b |

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

Attack 1 has a deliberately long wind-up (0.35s) like the opener in Souls-likes; it also applies when the combo loops back to attack 1.

---

Timings, lunge speeds, and clock poses live in `actions/attack_1..5.tres` (the truth, tuned by the user). The original first-guess tables and the old tuned snapshot are in `docs/archive/build-log.md`, Part 5.

---

## 5. Hold: charged zigzag thrust (3a-2)

- **Decision point:** at the end of the wind-up. Still held = charge; released = normal slash.
- **Charge:** a pulled-back charge pose that glows more as it fills. **Auto-fires at max charge** (placeholder 0.6s). Releasing earlier fires with the charge so far.
- **Charge scaling:** damage multiplier 1.0 to about 1.5 and lunge 1.0 to about 1.4 at full charge (placeholders). The damage multiplier is stored now and used in Step 4.
- **Zigzag (as built, connected to the combo):** a thrust chained from a slash starts on the side where that slash **ended** (attacks 1 and 4 end left, 2, 3, and 5 end right, read from each attack's `swing_end` pose), so the sword is already there. Chained from a thrust it takes the **opposite** side, so repeated thrusts still alternate. Started from idle it is right-aligned. (The first design said the side resets after any normal attack; the user replaced that with this rule.)
- **Repeatable:** holding again after a thrust charges the next one.
- **Chaining:** any combo attack can chain into a thrust (hold) and a thrust can chain into the next combo step (see the counter semantics in section 3).
- **Lunge:** similar to attack 5 (the most forward momentum), scaled by charge.

---

The thrust's values are in `actions/thrust.tres`.

---

## 6. Variants by context (3b)

"Tap" and "hold" follow the same definitions as in section 2.

| Context | Tap | Hold |
|---|---|---|
| Ground (standing) | combo (section 4) | zigzag thrust (section 5) |
| **Dash** (attack while dashing) | simple slash, **2:45 to 8:45** (the user's choice), that continues into the combo | simple thrust |
| **Dodge** (attack after the dodge's locked window, added in 3c-1) | the dash slash (same action; counts as step 1) | the dash thrust |
| **Crouch** | **as built:** a loop, 3:00 to 9:00 then 9:00 to 3:00, repeating; you stay crouched (the first design was one slash that uncrouches) | upward slash: wind-up to 8:00, slash to 1:00, stands you up and chains into attack 1; starts on the side where the previous attack ended (section 7.10) |
| **Slide** (attack while sliding) | same as the crouch tap | same as the crouch hold |
| **Jump** (airborne) | 2-attack loop: slash 2:00 to 10:00, then 10:00 to 2:00, repeating (**Speed Scale 1.5**) | **helm splitter** (Dante style, **built**): faster fall, a slash-style swing from 12:00 to 6:00, **the blade held at 6:00 until landing**, the body crouched, then a wind-down that can be cancelled |

**Decisions (2026-10-06, discussed and agreed with the user):**
1. Dash, crouch, and slide **tap** variants count as combo step 1: the next tap is attack 2 (as in the first design).
2. **No charge on any variant hold.** Dash hold = a simple thrust; crouch and slide hold = the upward slash (8:00 to 1:00). Holding at the end of the wind-up just selects a different attack.
3. **Dash attack:** it ends the dash; the lunge keeps the dash direction at a fixed speed (first guess 7 m/s; the user tuned the dash slash to 15 and the dash thrust to 20).
4. **Slide attack** is allowed after the slide's locked window, the same rule as the dodge and jump cancels.
5. **After a crouch attack** you stay crouched (changed in 3b-2: the tap is a loop). Only the hold (the upward slash) stands you up, and it needs headroom.
6. **Air attacks:** no limit while airborne (the 2:00 to 10:00 / 10:00 to 2:00 loop, built in 3b-3 as its own `AirAttack` state; landing restarts the loop); the **helm splitter only once per airtime**.
7. **No hover:** no gravity reduction or upward-speed damping during air attacks (the game is not DMC-style juggling).
8. **Helm splitter:** gravity 2.5x the player's current gravity while diving, the blade held at 6:00 until landing, then a wind-down that can be cancelled (cancel window from about 0.3 s after landing). **As built:** the body crouches for the whole dive and wind-down, and the swing is slash style (see section 7.12).
9. **Crouch visuals:** the sword and arm swing lower with the body when crouched (a `SwordVisual` tweak, done in 3b-2).
10. **Sheathed (3c-1):** while the sword is sheathed, an attack in any of these contexts plays the **draw slash** instead (section 7b). The dodge attack reuses the dash attack.

**Phases:** 3b-1 dash (also the shared plumbing: variants start through `AttackState.try_start_variant()`, and each action can name its own `hold_action`), 3b-2 crouch and slide, 3b-3 the air tap loop, 3b-4 the helm splitter. A full check before each phase.

---

---

## 7. Code design

### 7.1 Principles (apply to all new combat code)
- **SOLID-minded:** behavior reads **data resources**, not hard-coded values; new moves are new `.tres` files, new mechanics are new state classes.
- A **weapon** is data (`WeaponData`); adding a weapon with the same kinds of moves is mostly new `.tres` files.
- The cleanup refactor of the traversal code (moving wall/ledge sensing out of `player.gd`, state name constants, a shared base so the enemy can reuse `ActionState`) is **deferred until all of Phase 1 is done and tested by the user**.

### 7.2 Code map
`WeaponData` (`resources/weapon_data.gd`), `ActionData` (`resources/action_data.gd`), `SwordVisual` (`scripts/player/sword_visual.gd`), `AttackState`, `AirAttackState`, `HelmSplitterState`, and `DodgeState` (`scripts/player/states/`). Each script's header comment is the as-built description; the step-by-step history (3a-1 to 3c-1) is in `docs/archive/build-log.md`, Part 5.

---

## 7b. Sheathing and the draw slash (3c-1 and 3c-2 built and tested 2026-10-07)

### As built (3c-1), summary (full detail in the build log, Part 5)

- **Two visual states:** sheathed (box scabbard at the left hip, edge up, arm hanging relaxed) or drawn (the rest pose). It **spawns sheathed**. `Player.sheathed` changes no movement or rules.
- **Draw slash (iai, `actions/draw_attack.tres`, 8:00 to 2:00):** an attack while sheathed plays it in **every context** (ground, dash, dodge, crouch and slide staying crouched, air without a lunge), **replacing** the dash, crouch, slide, and air attacks; the dodge itself never draws. It counts as **no combo step**: the next tap is attack 1 (crouched: the crouch loop A; in the air: the first air attack, or attack 1 if you landed mid-swing). No hold yet.
- **R / D-pad Down (`sheathe`):** draws without attacking, or sheathes; Locomotion and Crouch only, ignored while the animation moves. **Auto-sheathe** after 5 s with no attack or dodge (counted only in Locomotion or Crouch); a hit restarts it in Step 4 (`Player.notify_combat()`).
- **Animated arm (visual only):** the hand reaches the grip first, then the blade slides out and swings to the rest pose; sheathing reverses it (approach, slide in, let go). The draw slash's wind-up does the same reach and pull. The arm stretches to reach the hip. Attacking mid-animation interrupts and blends from the current pose.
- **Dodge attack:** an attack after a dodge's locked window starts the dash attack (the draw slash while sheathed).
- **Data:** `WeaponData` Sheath group: `draw_attack`, `sheathed_grip` (a local position, not a clock pose), `sheathed_blade_direction`, `sheathed_edge_direction`.

### As built (3c-2)

- **Charged iai:** while sheathed, **holding** attack in any ground context (replacing the ground thrust and the dash, dodge, crouch, and slide holds) charges the draw slash: the blade half drawn, the orange glow, auto-fire at full charge (0.6 s), and a stored damage multiplier, through the draw slash's Hold Action (`draw_attack_charged.tres`). It is never mirrored and counts as no combo step (the next tap is attack 1). The **shockwave and the extra damage come later** (Step 4 and the polish step). **From crouch or slide it stands you up when it fires** (changed from the first design; with no headroom the hold is ignored and the plain draw slash plays).
- **Sheathed helm splitter:** holding attack in the air while sheathed plays the draw slash's wind-up (the reach and the pull), then the helm splitter through `WeaponData.draw_helm_action` (`helm_splitter_draw.tres`, a 0.4 s raise to 12:00), then the usual dive and landing. **Gravity is halved** (`HelmSplitterState.opening_gravity_factor`, 0.5) while holding during the draw wind-up and through the raise; this is a deliberate exception to the "no hover" decision, and only for the sheathed version. Once per airtime as usual. An air charge (hold longer) was not built.

### Animation later

- With real animation, locomotion needs a **sheathed and a drawn set** (idle, walk, sprint, dash, crouch, slide, jump, and so on), chosen by the sheathed flag. See section 8.
---

---

## 8. Later: real animation (notes for when the user learns Blender)

- Export a rigged character as glTF with one animation per action, named to match `ActionData.animation` (`attack_1`, `dodge`, `slide`, ...). Author them **in place** (no root motion); lunge and dodge speeds stay in the data.
- Swap the placeholder visuals for the model. The sword becomes a mesh on the hand bone.
- `ActionState` plays `action.animation` and seeks it to `action_time` each frame (the data stays authoritative).
- Retune each action's windows (`active_hit`, `cancel_window`, lunge window, duration) to the animation's timeline in the Godot animation editor.
- Locomotion (idle, walk, run, crouch) needs an `AnimationTree` with blend spaces driven by speed; actions play on top.
- With sheathing (3c), locomotion needs **two sets of animations, sheathed and drawn** (idle, walk, sprint, dash, crouch, slide, jump, ...), switched by the sheathed flag, plus draw and sheathe transitions.
- Each weapon's `ActionData` names its own animations, so weapons stay data-driven.