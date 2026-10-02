# Handoff: Sekiro-Like Combat Prototype (Godot 4)

> Paste this whole file at the start of a new chat. Update the **Progress checklist** (section 10) at the end of each session and re-paste it next time.

---

## 1. Project summary

- **Engine:** Godot 4.7.2 stable, standard (non-.NET) build, **GDScript** (typed)
- **Genre:** 3D third-person, Sekiro-style posture combat
- **Scope (prototype):** 1 player, 1 enemy, 1 arena, 1 weapon (katana-style samurai), no inventory. The goal is to validate the **core combat loop** only.
- **Platform:** Windows, **KBM first**, controller bindings added to the Input Map from day one.
- **Feel target:** Sekiro-snappy.
- **Art:** No animations or models yet. Use capsules and a box "sword". The user plans to learn Blender later.

### Core principle: data-driven, animation-independent
Gameplay is driven by **timings in `ActionData` resources**, not by animation events. A timer runs each action; `AnimationPlayer` (or placeholder visuals) just follows. When real animations arrive later, the combat code doesn't change, only the numbers get retuned.

**All windows are defined in seconds, never frames** (so behavior is frame-rate independent).

---

## 2. Feature list

**Player**
- Smooth, snappy movement; jump
- Dodge (small i-frames, no stamina); dash if dodge button is held after dodge
- Lock-on (with target switching)
- Attack, attack combo, combo loop (last attack chains back to the first)
- Jump attack
- Guard, deflect, jump guard, jump deflect
- Shrinking deflect window when spammed
- Heal (limited charges), resurrection
- Action "locks" and "cancel windows" tunable as data
- No crouch (samurai, not shinobi)

**Enemy**
- Same combat rules as player (shared `Combatant` component)
- AI that guards, deflects, ripostes, attacks, and recovers posture
- Perilous attacks (thrust, sweep) and a grab
- 2 health bars with deathblows between

**Systems**
- Posture (both sides), posture break, deathblow
- Hitboxes/hurtboxes, damage data, hit reactions
- Clash mechanic (new, see 4.5)
- Input buffering
- Third-person camera with collision, lock-on camera
- Hitstop, camera shake, spark/sound hooks
- Debug overlay (state, active windows, hitboxes)

---

## 3. Design decisions (confirmed by the user)

### 3.1 Health, posture, deathblow
- **Enemy has 2 health bars.** Emptying a bar leaves the enemy **standing stunned** for a deathblow window. Posture break also opens a deathblow.
- If the deathblow isn't taken, the enemy falls and dies (as stated by the user, like Sekiro). **See open question O1** for non-final bars.
- **Posture regenerates over time** for both sides, but **pauses** while attacking, dashing, or dodging. It regenerates normally when idle or moving.
- **Posture regen slows at low HP.**
- **Player only:** holding guard for a few seconds switches posture regen to a faster rate.
- **Enemy only:** instead of guarding to recover, it has a **recovery pose state** (plays a pose with a white aura, Owl-style). The AI chooses it when its posture is high and the player isn't pressuring it. **A hit interrupts it** (it's an opening for the player).
- **Player posture break:** plays a stagger animation lasting its full length (placeholder **6s**, tunable 5-8s). **Dodge is locked for the first 2s**, then dodge can cancel the stagger. If the player does nothing, they stay staggered until the animation ends. **The player takes extra damage while staggered** (placeholder 1.5x).

### 3.2 Guard and deflect
- Deflect window is **time-based, 0.2s** (placeholder; the Sekiro value is 12 frames at 60 FPS).
- **Spam penalty = shrinking window** (Sekiro style), **not a lockout** (Lies of P style). Each rapid re-press shrinks the window; it **resets after 1s of not guarding or acting**.
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
- **No body flashing** on the character (explicitly disliked as unimmersive).

### 3.6 Heal and resurrection
- **Heal:** 3 charges (adjustable). **Instant heal when the animation finishes** (charge is consumed on completion). **Movement is allowed** while healing. **A hit interrupts it.**
- **Resurrection:** 2 uses per run, revive at **half HP**. Presented as a **prompt** like Sekiro (the player chooses).
  - On resurrect: the enemy **keeps its state** (HP, posture), stays locked on, and keeps its distance/moves a bit.
  - On choosing final death: the enemy **unlocks and returns to a non-combat state**, then **reset the scene**.
  - After the final death with no resurrections left: reset the scene.

### 3.7 Dodge
- Small i-frames, **no stamina system at all**.
- Hold the dodge button after dodging to dash.
- Dodge can't be used during locked parts of other actions (see action windows).

### 3.8 Controls
- **KBM first, controller from the start in the Input Map.** Code only ever checks **action names**, never raw keys.
- Movement via `Input.get_vector(...)`.
- Differences needing extra handling: camera (mouse delta vs. stick with deadzone/sensitivity), lock-on target switching (mouse flick vs. right stick). UI button prompts are skipped for the prototype.

---

## 4. Action windows system (the "DS Anim Studio" equivalent)

Each action (attack 1, dodge, guard, heal, etc.) is a `.tres` file edited in the Inspector. A state machine reads the data to decide what is locked, what can cancel, and what is buffered. All values are seconds from action start.

### 4.1 Window types
- **Locked:** no other action allowed until this time
- **Cancel window:** a span in which the action may be interrupted by another
- **Buffer window:** a span in which an input is stored and played when allowed
- **Active hit window:** hitbox on
- **I-frame window:** invulnerable (dodge)
- **Deflect window:** guard-start span that counts as a deflect

### 4.2 Rules
- Input buffering: ~0.15s store time (placeholder).
- The same system powers **enemy attacks**.
- Hitstop: ~2-4 frames' worth of time on contact (placeholder; define in seconds).

---

## 5. Data designs

### 5.1 `ActionData` (starting sketch; extend as needed)

```gdscript
class_name ActionData extends Resource

enum Kind { ATTACK, DODGE, GUARD, HEAL, JUMP, PERILOUS_THRUST, PERILOUS_SWEEP, GRAB, OTHER }

@export var kind: Kind = Kind.ATTACK
@export var animation: StringName
@export var duration: float = 0.8
@export var locked_until: float = 0.5
@export var cancel_window: Vector2 = Vector2(0.5, 0.8)
@export var buffer_window: Vector2 = Vector2(0.4, 0.8)
@export var active_hit: Vector2 = Vector2(0.25, 0.4)
@export var iframes: Vector2 = Vector2.ZERO
@export var damage: float = 10.0
@export var posture_damage: float = 15.0
@export var guardable: bool = true
@export var deflectable: bool = true
@export var pauses_posture_regen: bool = true
@export var combo_next: ActionData   # loop back to the first for the combo loop
```

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

---

## 6. Placeholder numbers (all tunable; NOT final decisions)

| Parameter | Placeholder |
|---|---|
| Deflect window | 0.2s |
| Deflect spam shrink per re-press | TBD (e.g. -0.04s, with a floor) |
| Deflect window reset | 1.0s of no guard/actions |
| Clash overlap window | 0.1s |
| Input buffer time | 0.15s |
| Enemy reaction delay | 0.1-0.3s random |
| Player stagger duration | 6s (range 5-8s) |
| Dodge locked during stagger | first 2s |
| Staggered damage multiplier | 1.5x |
| Heal charges | 3 |
| Resurrections | 2 (at 50% HP) |
| Enemy health bars | 2 |
| Posture amounts, regen rates, low-HP slowdown | TBD during tuning |
| Guard cone | 90° front |

---

## 7. Architecture notes

- Scenes composed from nodes; shared `Combatant` component on both player and enemy.
- State machine for player and enemy (states read `ActionData`).
- Hitboxes and hurtboxes as `Area3D`; damage info passed as data.
- Player body: `CharacterBody3D`. Third-person camera with collision (SpringArm3D). Lock-on camera mode.
- Resolve order: first connect wins, unless both hitboxes go active within the clash window (then clash).
- Animation: timer-driven; `AnimationPlayer` follows later.
- Debug overlay from early on (current state, active windows, hitbox visibility).

---

## 8. Build order

1. Third-person movement and camera (snappy), plus jump. Set up the Input Map for KBM and controller.
2. State machine and `ActionData`; dodge with dash-hold and i-frames.
3. Attack, combo, and combo loop, using buffering and cancel windows.
4. Hitboxes, damage, hitstop on a dummy enemy.
5. Guard, deflect, shrinking window, jump versions.
6. Posture, posture break, deathblow (+ player stagger rules).
7. Enemy AI: attacks, guard/deflect, riposte, recovery pose, perilous attacks and grab, danger symbols.
8. Clash mechanic.
9. Lock-on.
10. Heal and resurrection (prompt, final death, scene reset).
11. Polish: sound, sparks, camera shake.

---

## 9. Open questions (unresolved; ask the user before assuming)

- **O1:** When a **non-final** health bar empties and the deathblow window is missed, what happens? (Sekiro: the enemy recovers. The user said the enemy "falls and dies" on a missed deathblow, which clearly applies to the final bar. Confirm the non-final behavior.)
- **O2:** Exact posture numbers, spam-shrink amount, regen rates.
- **O3:** Which deflect-spam shrink curve (linear or stepped)?
- **O4:** Camera and lock-on details (e.g. lock-on range, how target switching feels).
- **O5:** Enemy grab damage amount and exact grab range/wind-up.

---

## 10. Progress checklist (update each session)

- [ ] 1. Movement, camera, jump, Input Map (KBM and controller)
- [ ] 2. State machine, ActionData, dodge, dash-hold
- [ ] 3. Attack, combo, combo loop
- [ ] 4. Hitboxes, damage, hitstop
- [ ] 5. Guard, deflect, shrinking window, jump versions
- [ ] 6. Posture, deathblow, player stagger
- [ ] 7. Enemy AI and perilous attacks
- [ ] 8. Clash
- [ ] 9. Lock-on
- [ ] 10. Heal and resurrection
- [ ] 11. Polish

**Current state:** Nothing built yet. Design phase complete. Godot 4.7.2 standard is being downloaded or installed.

---

## 11. Conventions

- Typed GDScript throughout (`var x: float`, typed function signatures).
- `@export` and custom `Resource` classes for tunable data.
- Signals for events between components; autoload only when truly global.
- Input checked by **action name** only.
- Timings in **seconds**, never frames.
- Suggested folder structure:
  ```
  res://
    actions/        # ActionData .tres files
    ai/             # EnemyAIData .tres files
    scenes/         # player, enemy, arena
    scripts/
      combat/       # Combatant, hitbox, hurtbox
      player/
      enemy/
      ui/
    resources/      # Resource class scripts
  ```

---

## 12. How Claude should work with me

- I'm on the **free web chat**, so **keep replies concise** to save usage. No long preambles.
- When something needs scene setup, **list the nodes to create explicitly** (node type, name, parent, key properties).
- Tell me **where each script is attached** and what to name it.
- I can't be assumed to know Godot well; briefly explain the *why* of new concepts, but keep it short.
- **Don't assume decisions for me.** If something isn't in this doc, ask. Mark guesses as placeholders.
- I can't be tested by Claude: Claude can't run Godot, so I'll report results and errors. I'll give my Godot version (4.7.2) and paste error text.
- One build-order step at a time. Confirm it works before moving on.
- Please read the work-agreements.md