# Design for later steps (Step 4 and beyond)

> **Paste this when starting Step 4 or any later step** (hitboxes, guard, posture, enemy AI, clash, lock-on, heal). Until then Claude does not read it (see `docs/work-agreements.md`, section 7). Section numbers match the handoff (3.x, 5.x). Moved out of the handoff on 2026-10-07; nothing here is built yet except where noted.

---

## Design decisions (confirmed by the user)

### 3.1 Health, posture, deathblow
> **Built in Step 6** (numbers are placeholders; rules and files in the build log, "Step 6"). Confirmed rules that go beyond the text below: when health reaches 0 posture fills too and the deathblow window opens; a missed window on a non-final bar (or a boss's final bar) returns the enemy to 1 HP and posture to 0, and the next damage empties it again, repeating until a deathblow lands (a landed one removes a bar and the next starts full); a missed window on a non-boss final bar kills; a posture break at any health opens the same window. The enemy's health is one bar with pips for the bars left.
- **Enemy has 2 health bars.** Emptying a bar leaves the enemy **standing stunned** for a deathblow window. Posture break also opens a deathblow.
- If the deathblow isn't taken, the enemy falls and dies (as stated by the user, like Sekiro). **See open question O1** for non-final bars.
- **Posture regenerates over time** for both sides, but **pauses** while attacking, dashing, or dodging. It regenerates normally when idle or moving.
- **Posture regen slows at low HP.**
- **Player only:** holding guard for a few seconds switches posture regen to a faster rate.
- **Enemy only:** instead of guarding to recover, it has a **recovery pose state** (plays a pose with a white aura, Owl-style). The AI chooses it when its posture is high and the player isn't pressuring it. **A hit interrupts it** (it's an opening for the player).
- **Player posture break:** plays a stagger animation lasting its full length (placeholder **6s**, tunable 5-8s). **Dodge is locked for the first 2s**, then dodge can cancel the stagger. If the player does nothing, they stay staggered until the animation ends. **The player takes extra damage while staggered** (placeholder 1.5x).

### 3.2 Guard and deflect
- Deflect window is **time-based, 0.2s** (placeholder; the Sekiro value is 12 frames at 60 FPS).
- **Spam penalty = shrinking window** (Sekiro style), **not a lockout** (Lies of P style). A press shrinks the window only when it is a rapid tap (under 0.35 s after the previous press) or the 4th press or later of the run (so slow tapping is free for the first 3 presses); it **resets after 1s of not guarding or acting**, after **3s of holding the guard** since the last press, **at once when any other action starts** (attack, dodge...; confirmed in Step 5 testing), and on a **deflect** or an **unguarded hit** (a plain guard does not reset it; changed after 7d).
- **Edge-triggered:** every deflect needs its own button press. Holding guard does **not** auto-deflect later attacks. Holding doesn't extend the window either; a new attempt means release and press again.
- **Snappy re-deflect:** a fresh press always starts a new window, even mid-deflect animation or recovery. Deflect is cancellable into a new deflect. Use input buffering so a slightly-early press still counts.
- Normal guard blocks but adds posture damage and chip damage; a successful deflect adds almost none (and damages the attacker's posture).
- **While guarding:** forced walk (no jog). Guard covers a **~90° cone in front** only.
- **Jump guard and jump deflect** exist.
- Grabs are **unguardable and undeflectable**.

### 3.3 Clash (new mechanic)
- In Sekiro, whoever's hitbox connects first wins. This prototype adds a **clash**: if both sides' hitboxes become active within a short overlap window (placeholder **0.1s**), it's a clash instead.
- On clash: both bounce back, each takes a small posture hit, play sparks and sound.
- Otherwise, first connect wins.

### 3.4 Enemy behavior
- Enemy **guards and deflects** (this is a key requirement: no mindless attack-spam enemies; the fight should feel like a dance).
- **Guard logic:** reacts to the threat (a wind-up or an active player hitbox), after a randomized **reaction delay** (placeholder 0.1-0.3s, the main difficulty knob). **Cannot guard while mid-attack or in recovery**, which creates the openings.
- **Deflect vs. plain guard** is driven by a skill parameter/chance.
- **Adaptive pressure:** repeating the same attack raises the enemy's guard chance. Variety (jumps, dodges, counters) is rewarded.
- **Riposte** after a successful enemy deflect.
- **Aggression budget:** attack for a few hits, then yield and defend, alternating phases.
- **Posture is the answer to turtling:** guarding costs posture.
- Tunable via `EnemyAIData` (see 5.2).

### 3.5 Perilous attacks and grab
| Attack | Warning symbol | Counter |
|---|---|---|
| Thrust | **Red** danger symbol | **Mikiri:** dodge forward while the thrust is active. Very forgiving; no tight timing. |
| Sweep | **Red** danger symbol | **Jump-over:** jump toward the enemy's head any time while the sweep animation is playing |
| Grab | **Yellow** symbol (deliberately different, for readability) | **Dodge.** Unguardable. If it connects, deals **HP damage** |

- The symbol appears **above the player's head**, as in Sekiro.
- **Built in 7c-1 (thrust and sweep; the grab is 7c-2):** the thrust and the sweep are also unguardable and undeflectable (user-approved default). The symbol shows 0.5 s before the hit window and stays until it closes. The jump-over counter is "in the air while the symbol shows" to arm it, and landing on the enemy's head is the parry (posture, stun, the bobblehead flinch) that also bounces the player up so a helm splitter can follow; any other landing on a head slides the player off. The thrust (not the sweep) can still be deflected, but only within a 0.1 s window after the guard press. In the air the player keeps its momentum and the move keys only steer it. Mikiri: +50 posture and a 1 s stun; jump-over: +30 posture and a 0.6 s stun (placeholders). A perilous attack can start a burst or continue a combo (chain chance per preset).
- **No body flashing** on the character (explicitly disliked as unimmersive).

- **Built in 7c-2 (the grab; answers O5, numbers are placeholders):** yellow `!` (`EnemyAIData.grab_symbol_color`), shown `perilous_symbol_lead` before the hit window like the others. Wind-up about 0.8 s, active window 0.25 s, starts within `grab_range` 2.4 m with a short lunge, 45 damage, 0 posture, a 2.0 m throw, super armor like the other perilous attacks. Unguardable and undeflectable; **only a dodge answers it** (its i-frames; no posture reward), and a whiff leaves the enemy open for `grab_whiff_recovery` 1.2 s. It hits crouched and airborne players too. A grab that connects always **breaks the guard** (whether or not the player was guarding): `HitData.grab` makes `Combatant` emit `guard_broken`, and on the ground the player also sinks to a knee for `Player.grab_kneel_time` 0.8 s (visual only; the capsules and the hurtbox do not change; any jump, fall, or action ends it). No held-in-hand animation yet.

### 3.6 Heal and resurrection
- **Heal:** 3 charges (adjustable). **Instant heal when the animation finishes** (charge is consumed on completion). **Movement is allowed** while healing. **A hit interrupts it.**
- **Resurrection:** 2 uses per run, revive at **half HP**. Presented as a **prompt** like Sekiro (the player chooses).
  - On resurrect: the enemy **keeps its state** (HP, posture), stays locked on, and keeps its distance/moves a bit.
  - On choosing final death: the enemy **unlocks and returns to a non-combat state**, then **reset the scene**.
  - After the final death with no resurrections left: reset the scene.

### 3.11 Hurtbox profiles
- The player's **hurtbox** (`Area3D` that takes hits) is separate from the **body collision capsule**.
- **Crouch** shrinks from the top down toward the feet (bottom stays planted). **Jump/airborne** shrinks from the bottom up toward the head (top stays in place), as if the legs tuck.
- Only the hurtbox changes in the air; the body capsule stays full-size while airborne (shrinking it mid-air would make landing and wall contact unstable). Crouch shrinks both.
- This lets a low sweep pass under a jumping player (the jump-over counter) and a high attack pass over a crouching one.

---

## Data designs

### 5.2 `EnemyAIData` (sketch)

```gdscript
class_name EnemyAIData extends Resource

@export var reaction_delay: Vector2 = Vector2(0.1, 0.3)  # random range, seconds
@export var guard_chance: float = 0.5
@export var deflect_chance: float = 0.3
@export var aggression: float = 0.6
@export var attack_burst_count: Vector2i = Vector2i(2, 4)
@export var recovery_time: float = 0.6
@export var repeat_attack_guard_bonus: float = 0.1
@export var posture_pose_threshold: float = 0.6
```

### 5.3 `Combatant` component (shared by player and enemy)
Holds: HP (and health bars), posture, guard state, deflect window and spam-shrink tracking, hit reaction handling, posture regen rules. Both the player and the enemy use the same component so the rules match.

### 5.4 `HurtboxProfile` (sketch; one per state)

```gdscript
class_name HurtboxProfile extends Resource

@export var height: float = 1.8
@export var bottom_offset: float = 0.0   # distance from the feet to the bottom of the hurtbox
```

Placeholders: standing 1.8 tall, offset 0. Crouching 1.1 tall, offset 0. Airborne 1.1 tall, offset 0.7 (top stays at 1.8).

---

## Placeholder numbers (not built yet; all tunable, NOT final decisions)

| Parameter | Placeholder |
|---|---|
| Deflect window | 0.2s |
| Deflect spam shrink per shrinking press | -0.04s linear, floor 0.05s (Step 5); only rapid taps (< 0.35s apart) or presses after the 3rd shrink |
| Deflect window reset | 1.0s of no guard/actions |
| Clash overlap window | 0.1s |
| Enemy reaction delay | 0.1-0.3s random |
| Player stagger duration | 6s (range 5-8s) (built in Step 6) |
| Dodge locked during stagger | first 2s (built) |
| Staggered damage multiplier | 1.5x (built) |
| Deathblow window | 4s (built) |
| Heal charges | 3 |
| Resurrections | 2 (at 50% HP) |
| Enemy health bars | 2 |
| Posture amounts, regen rates, low-HP slowdown | Built in Step 6 as placeholders: max 100; attack posture about 1.5x damage; guard 100%, deflect 10% (+50% on the attacker), unguarded hit 50%; regen 15/s after 1 s; x0.5 at 0 HP; player x2 after 3 s of guarding; the dummy's swing 25 |
| Guard cone | 90° front |
| Hurtbox profiles | stand 1.8/0, crouch 1.1/0, air 1.1/0.7 (height/offset) |

---

## Open questions (unresolved; ask the user before assuming)

- ~~**O1**~~ Resolved in Step 6 (see the note under 3.1). Original question: When a **non-final** health bar empties and the deathblow window is missed, what happens? (Sekiro: the enemy recovers. The user said the enemy "falls and dies" on a missed deathblow, which clearly applies to the final bar. Confirm the non-final behavior.)
- **O2:** Exact posture numbers and regen rates: placeholders are built in Step 6 (see the table); tune them in play. (The spam-shrink amount was settled in Step 5.)
- ~~O3~~ Resolved in Step 5: linear, -0.04 s per rapid re-press, floor 0.05 s.
- **O4:** Camera and lock-on details (e.g. lock-on range, how target switching feels).
- ~~O5~~ Resolved in 7c-2 (placeholders): damage 45, range 2.4 m, wind-up about 0.8 s, active 0.25 s; see 3.5.
