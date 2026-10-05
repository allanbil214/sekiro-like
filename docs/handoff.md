# Handoff: Sekiro-Like Combat Prototype (Godot 4)

> Paste this whole file at the start of a new chat. Update the **Progress checklist** (section 10) at the end of each session and re-paste it next time.
>
> **Reminder:** deferred ideas live in the **Phase 2 backlog** (section 13). Don't forget them.
>
> **Docs to paste in a new chat:** this handoff, `docs/work-agreements.md`, and the spec for the current step (**Step 3: `docs/step3-combat-spec.md`**), plus a fresh snapshot (see section 12). Start a new chat per phase.

---

## 1. Project summary

- **Engine:** Godot 4.7.2 stable, standard (non-.NET) build, **GDScript** (typed)
- **Genre:** 3D third-person, Sekiro-style posture combat
- **Scope (prototype):** 1 player, 1 enemy, 1 arena, 1 weapon (katana-style samurai), no inventory. The goal is to validate the **core movement + combat loop**. Traversal moves (crouch, wall jump, ledges) are in Phase 1 by the user's choice; everything deferred is in section 13 (Phase 2).
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
- Attack, attack combo (5 attacks), combo loop (last attack chains back to the first), hold-attack charged zigzag thrust
- Attack variants by context: dash, crouch, slide, and jump attacks (tap and hold each, including a helm-splitter dive), all designed in `docs/step3-combat-spec.md`
- Guard, deflect, jump guard, jump deflect
- Shrinking deflect window when spammed
- Heal (limited charges), resurrection
- Action "locks" and "cancel windows" tunable as data
- Crouch (toggle by default): duck under attacks, crouch attack
- Crouch slide (press `crouch` while dashing; has i-frames)
- Mid-air reach and wall jump (no extra height), ledge grab, hang, shimmy (one straight line), climb up
- Generic `interact` button (ledges in Phase 1; doors, chests, NPCs in Phase 2)

**Enemy**
- Same combat rules as player (shared `Combatant` component)
- AI that guards, deflects, ripostes, attacks, and recovers posture
- Perilous attacks (thrust, sweep) and a grab
- 2 health bars with deathblows between

**Systems**
- Posture (both sides), posture break, deathblow
- Hitboxes/hurtboxes, damage data, hit reactions
- Hurtbox profiles per state (stand, crouch, air)
- Clash mechanic (new, see 3.3)
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
- Dodge can't be used during locked parts of other actions (see action windows). **Ground only** (no air dodge).
- **Direction:** follows the movement input (relative to the camera). With no input it is a **backstep** (no turning, 0.7x speed).
- **Dash:** if the dodge button is still held when the dodge unlocks (0.30s) and there is movement input, the dodge flows into a dash. The dodge's burst fades to a floor speed (`move_end_factor`, 0.3), not to zero, so there is no full stop. The dash ends on button release, no movement input, leaving the ground, or jumping. A quick tap ends with a short slide.
- After the locked window, jump, a new dodge, and movement are all allowed (presses just before are buffered, 0.15s).

### 3.8 Controls
- **KBM first, controller from the start in the Input Map.** Code only ever checks **action names**, never raw keys.
- Movement via `Input.get_vector(...)`.
- Differences needing extra handling: camera (mouse delta vs. stick with deadzone/sensitivity), lock-on target switching (mouse flick vs. right stick). UI button prompts are skipped for the prototype.
- **Input Map** (all actions below now exist in Project Settings, including `crouch` and `interact` added in Step 2b):

| Action | KBM | Controller |
|---|---|---|
| `move_forward/back/left/right` | W / S / A / D | Left stick |
| `look_left/right/up/down` | (mouse read directly) | Right stick |
| `jump` | Space | Bottom Action (A / Cross) |
| `dodge` | Left Shift | Right Action (B / Circle) |
| `attack` | Left Mouse Button | **Right Shoulder (R1 / RB)** |
| `guard` | Right Mouse Button | **Left Shoulder (L1 / LB)** |
| `heal` | Q | Top Action (Y / Triangle) |
| `lock_on` | Middle Mouse Button | Right Stick click |
| `crouch` | Left Ctrl | Left Stick click |
| `interact` | E | Left Action (X / Square) |

  Move, look, jump, dodge, crouch, and interact (ledge hang and climb) are wired up so far.

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

### 3.11 Hurtbox profiles
- The player's **hurtbox** (`Area3D` that takes hits) is separate from the **body collision capsule**.
- **Crouch** shrinks from the top down toward the feet (bottom stays planted). **Jump/airborne** shrinks from the bottom up toward the head (top stays in place), as if the legs tuck.
- Only the hurtbox changes in the air; the body capsule stays full-size while airborne (shrinking it mid-air would make landing and wall contact unstable). Crouch shrinks both.
- This lets a low sweep pass under a jumping player (the jump-over counter) and a high attack pass over a crouching one.

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

### 4.3 The action clock (how this compares to FromSoft)
- FromSoft: the **animation is the clock**, and timing windows (TAE, edited in DS Anim Studio) sit on its timeline. State logic lives in the behavior graph and script side.
- Ours: **`ActionState` keeps an `action_time`** that advances by `delta * speed_scale`, and every window in `ActionData` is read against it. Later, the `AnimationPlayer` is seeked to `action_time` with the same speed scale, so adding real animations changes data, not code.
- **Adding a new action = a new `ActionData` `.tres` plus a state extending `ActionState`** (override the `_on_action_*` hooks). Attacks in Step 3 reuse this.
- There is no visual timeline editor; windows are tuned as numbers in the Inspector.

---

## 5. Data designs

### 5.1 `ActionData` (implemented in Step 2a: `resources/action_data.gd`)

All times are seconds from the start of the action; windows are `Vector2(start, end)`.

- **Identity:** `kind` (enum: ATTACK, DODGE, GUARD, HEAL, JUMP, WALL_JUMP, LEDGE_CLIMB, PERILOUS_THRUST, PERILOUS_SWEEP, GRAB, OTHER), `animation`, `duration`, `speed_scale` (action clock speed)
- **Windows:** `locked_until`, `cancel_window` ((0,0) = from `locked_until` to the end), `buffer_window` (attack chaining: where an attack press is accepted, (0,0) = the whole action; used from 3a-1), `active_hit` (the swing's wind-up / active / recovery split, used from 3a-1; the hitbox itself comes in Step 4), `iframes`
- **Swing visual (3a-1):** `swing_windup`, `swing_end`, `swing_follow` (clock poses, see the terminology in section 11; they only drive the placeholder sword)
- **Movement:** `move_speed`, `move_window`, `move_fade`, `move_end_factor` (speed at the window's end as a fraction of `move_speed`; 0 = fade to a stop)
- **Combat:** `damage`, `posture_damage`, `guardable`, `deflectable`, `pauses_posture_regen`, `combo_next` (unused: `WeaponData.combo` holds the combo order and the loop)
- **Helpers:** `in_window()`, `is_locked()`, `can_cancel()`, `has_iframes()`, `is_hit_active()`

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
| Hurtbox profiles | stand 1.8/0, crouch 1.1/0, air 1.1/0.7 (height/offset) |
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
| Attack timings and lunge speeds | see the Step 3 spec (section 4); the tuned values live in `actions/attack_1..5.tres` |
| Attack lunge: no-input strength / ledge stop distance | 0.5x / 0.4 m (`AttackState` exports) |
| Sword: pose scale / arm reach | 1.5 / 0.6 m |
| Sword: shoulder offset / shoulder height / clock center height | 0.35 m / 1.4 m / 1.2 m |
| Sword: slash arc / wind-up arc (forward bow of the tip path) | 0.5 m / 0.25 m |
| Sword: wrist angle start / end / follow overshoot / follow relax | 50 deg / -10 deg / 15 deg / 0.5 |
| Blade length / width | 1.1 m / 0.14 m (the shipped `katana.tres` had 0.08; widened so the edge reads) |
| Sword rest | clock pose (4, 0.9, 0.3), blade direction (0.15, -0.5, -0.85), edge up (tune in `katana.tres` and `SwordVisual`) |

---

## 7. Architecture notes

- Scenes composed from nodes; shared `Combatant` component on both player and enemy.
- State machine for player and enemy (states read `ActionData`). **Implemented for the player in Step 2a**; the Player drives it from `_physics_process` so the update order is deterministic.
- Hitboxes and hurtboxes as `Area3D`; damage info passed as data.
- Player body: `CharacterBody3D`. Third-person camera with collision (SpringArm3D). Lock-on camera mode.
- Resolve order: first connect wins, unless both hitboxes go active within the clash window (then clash).
- Animation: timer-driven; `AnimationPlayer` follows later.
- Debug overlay from early on (current state, active windows, hitbox visibility).
- Traversal as states in the same state machine: Crouch, Slide, WallJump (the mid-air reach lives in the Air state), LedgeHang (a plain state, no data), LedgeClimb (scripted, reads `ActionData`).
- Player hurtbox (`Area3D`) separate from the body capsule; both resized per state (see 3.11).
- Combat states: `Attack` (ground combo, extends `ActionState`) reads `Player.weapon` (`WeaponData`); the sword is a separate placeholder visual (`SwordVisual`) driven by the attack's action clock.

---

## 8. Build order

1. Third-person movement and camera (snappy), plus jump. Set up the Input Map for KBM and controller.
2. **2a.** State machine and `ActionData`; dodge with dash-hold and i-frames. **(done)**
   - **2b.** Crouch (toggle/hold setting, shrunk capsule and hurtbox), crouch slide, animated crouch; add `crouch` and `interact` to the Input Map. **(done)**
   - **2c.** Mid-air reach and wall jump. **(done)**
   - **2d.** Ledges: auto-climb, hang (hold `interact`), one-line shimmy, climb, drop, leap. **(done: 2d-1 detect and auto-climb, 2d-2 hang, shimmy, drop, leap)**
3. Attacks. **Full design in `docs/step3-combat-spec.md`** (5-attack combo with loop, TAE-style chain/cancel rules, charged zigzag thrust, lunge momentum, a `WeaponData` resource, and dash/crouch/slide/jump variants). Built in phases:
   - **3a-1.** Ground 5-attack combo, loop, chain/cancel, flourish, lunge, sword visual, `WeaponData`. **(done)**
   - **3a-2.** Hold detection, charged zigzag thrust, chaining in and out of the thrust.
   - **3b.** Dash, crouch, slide, and jump attack variants (tap and hold).
4. Hitboxes, damage, hitstop on a dummy enemy; player hurtbox profiles (stand/crouch/air) and duck-under whiffs.
5. Guard, deflect, shrinking window, jump versions.
6. Posture, posture break, deathblow (+ player stagger rules).
7. Enemy AI: attacks, guard/deflect, riposte, recovery pose, perilous attacks and grab, danger symbols; place enemy hitboxes high/mid/low so ducking matters.
8. Clash mechanic.
9. Lock-on.
10. Heal and resurrection (prompt, final death, scene reset).
11. Polish: sound, sparks, camera shake.

*Note: traversal (2b-2d) comes before combat by the user's choice, which delays the combat loop. Move it later if scope becomes a problem.*

---

## 9. Open questions (unresolved; ask the user before assuming)

- **O1:** When a **non-final** health bar empties and the deathblow window is missed, what happens? (Sekiro: the enemy recovers. The user said the enemy "falls and dies" on a missed deathblow, which clearly applies to the final bar. Confirm the non-final behavior.)
- **O2:** Exact posture numbers, spam-shrink amount, regen rates.
- **O3:** Which deflect-spam shrink curve (linear or stepped)?
- **O4:** Camera and lock-on details (e.g. lock-on range, how target switching feels).
- **O5:** Enemy grab damage amount and exact grab range/wind-up.
- ~~**O6:** Ledge details~~ **Resolved in Step 2d**: values are in the placeholders table (all tunable exports).
- ~~**O7:** Slide attack~~ **Resolved: yes**, with tap and hold variants (see the Step 3 spec).
- **O8:** Which combo step follows a crouch, slide, or dash attack tap? (Default proposal: the variant counts as step 1, so the next tap is attack 2.) Also the jump attack details (air attacks per airtime, helm splitter fall speed). Ask at 3b.

---

## 10. Progress checklist (update each session)

- [x] 1. Movement, camera, jump, Input Map (KBM and controller) **(done and tested by the user)**
- [x] 2a. State machine, ActionData, dodge, dash-hold **(done and tested by the user)**
- [x] 2b. Crouch, crouch slide, animated crouch (+ `crouch` / `interact` input actions) **(done and tested by the user)**
- [x] 2c. Mid-air reach, wall jump **(done and tested by the user)**
- [x] 2d. Ledges (auto-climb, hang, one-line shimmy, climb, drop, leap) **(done and tested by the user)**
- [x] 3a-1. Ground 5-attack combo, loop, chain/cancel, arm-swing sword visual, `WeaponData` (see the Step 3 spec) **(built; the user saw the combo and the arm-swing sword working and approved the look; cancels, the lunge, and the ledge stop were not formally tested yet)**
- [ ] 3a-2. Hold, charged zigzag thrust
- [ ] 3b. Dash, crouch, slide, and jump attack variants
- [ ] 4. Hitboxes, damage, hitstop
- [ ] 5. Guard, deflect, shrinking window, jump versions
- [ ] 6. Posture, deathblow, player stagger
- [ ] 7. Enemy AI and perilous attacks
- [ ] 8. Clash
- [ ] 9. Lock-on
- [ ] 10. Heal and resurrection
- [ ] 11. Polish

**Current state:** Steps 1 to 2d (all traversal) are complete and tested, and **Step 3a-1 is built** (ground combo and the arm-swing sword; see "Step 3a-1: what exists" below). **Next: Step 3a-2** (hold, charged zigzag thrust). The design is in `docs/step3-combat-spec.md` (sections 5 and 7). Start a **new chat** for 3a-2 and paste the handoff, the work agreement, the Step 3 spec, and a fresh snapshot (`python pack_for_claude.py`). Before building, give a quick sanity test of the 3a-1 combat details (cancels, lunge, ledge stop) and report anything off.

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
- `actions/slide.tres`: `ActionData`, kind `OTHER`, duration 0.6, locked until 0.35, i-frames 0.05 to 0.28, move 18 (tuned by the user) over 0 to 0.45 fading to 0.3x. **Never overwrite; changes come as "change X to Y".**
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
- `actions/wall_jump.tres`: `ActionData`, kind `WALL_JUMP`. **Never overwrite; changes come as "change X to Y".**
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
- `actions/ledge_climb.tres`: `ActionData`, kind `LEDGE_CLIMB`, duration 0.6, locked until 0.6. **Never overwrite; changes come as "change X to Y".**
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
- `resources/weapon_data.gd`: `WeaponData`: `display_name`, `combo: Array[ActionData]`, `blade_length`, `blade_thickness` (used as the blade's **width**), `rest_pose` (a clock pose). `weapons/katana.tres` is the first weapon. **Never overwrite; changes come as "change X to Y".**
- `resources/action_data.gd`: added `swing_windup`, `swing_end`, `swing_follow` (clock poses); `buffer_window` is now used.
- `actions/attack_1.tres` to `attack_5.tres`: `ActionData`, kind `ATTACK`, first-guess timings from the spec (section 4), `locked_until` = `active_hit.y`, damage 0. **Never overwrite; changes come as "change X to Y".**
- `scripts/player/states/attack_state.gd`: `AttackState` (extends `ActionState`), see below.
- `scripts/player/sword_visual.gd`: `SwordVisual`, the arm-swing placeholder sword, see below.
- `scripts/player/player.gd` additions: `weapon` export (Combat group), `sword_visual` (found in `_ready`, `setup(weapon)` called there), `has_combo()`, `has_ground_ahead(dir, distance, max_drop)` (short ray down ahead of the feet).
- `scripts/player/input_buffer.gd`: also tracks `attack`. `locomotion_state.gd`: a buffered attack press (with `has_combo()`) goes to `Attack`. `scripts/ui/debug_overlay.gd`: a `Combo: n/5 (wind-up | ACTIVE | recovery)` line plus `Buffer / Chain / Queued` flags.

**`AttackState` rules (as built)**
- Entering from any state except `Attack` picks attack 1; entering from `Attack` (a chain) picks the next index, wrapping to 1 after attack 5. Exiting to anything except `Attack` resets the counter and sends the sword back to rest.
- **Chain:** a press is accepted inside `buffer_window` (the input buffer also remembers a press up to 0.15s before the window opens) and marks the attack `_queued`. The chain happens at `cancel_window.x` (or `locked_until` if the cancel window is unset), never while the active window is open.
- **Cancels:** dodge, jump, and crouch cancel at any time except while the hit window is active (wind-up and recovery both cancel), and only on the floor. `ActionData.can_cancel()` is not used for these.
- **Steering and lunge:** before `active_hit.x` the body turns toward the movement input (`face_input`). The lunge direction is the movement input at the attack start (no input: facing, at `no_input_lunge_factor` = 0.5). While steering is allowed, a held input keeps updating the lunge direction; releasing keeps the last direction and strength. Both lock when the active window starts. `_can_steer()` is a hook that returns true; **Step 9 (lock-on) makes it return false while locked on**.
- **Ledge stop:** if there is no floor within `ledge_check_distance` (0.4 m) ahead in the lunge direction, the lunge is dropped for that frame, so an attack never carries you off a ledge. Leaving the floor any other way just continues the action with gravity, and it ends in Air via Locomotion.
- The action finishes into `Locomotion`. No hitboxes or damage yet.

**`SwordVisual`: the arm swing (placeholder)**
- A **clock pose** (hour, radius, forward) is converted to an **aim point** (radius and forward multiplied by `pose_scale`). The poses say where the **tip** should pass.
- An arm (a gray box, `show_arm`) points from the right shoulder to the aim point; the hand sits `arm_reach` along it; the blade extends from the hand and bends at the **wrist angle** (positive = the tip trails behind the travel direction, cocked; negative = leading). The wrist goes from `wrist_start_angle` (50) to `wrist_end_angle` (-10) across the slash.
- The aim point travels along a path bowed forward in the middle (**slash arc**, `slash_arc_forward` 0.5; `windup_arc_forward` 0.25 for the wind-up and follow-through), so a slash sweeps through the space in front of the player.
- The cutting edge (a bright yellow strip on the blade) **leads along the direction of travel** (the path's tangent). `flip_edge` flips it if it is on the wrong side.
- Segments over `action_time`: previous pose to wind-up (blends from the captured current pose, so chains are smooth), wind-up to end (the active window, fast ease; the blade turns red), end to follow-through (a small wrist overshoot, then it relaxes toward the rest direction by `follow_relax`). With no chain the sword returns to rest over `rest_return_time`.
- The first version put the **grip** at the pose point; the sword then hung beside the body and swung up and down. The fix was to make the poses aim the arm and keep the tip path in front of the player. Keep this in mind when tuning: the real tip only roughly follows the aim point (the blade bends at the wrist).

**Hooks for later:** `_can_steer()` (Step 9); `active_hit` becomes the hitbox window and `damage` / `posture_damage` get real values in Step 4; guard joins the cancel list in Step 5; 3a-2 adds the thrust to `WeaponData`; 3b adds the variants.

**Not done in 3a-1:** hold and thrust (3a-2), dash, crouch, slide, and jump attack variants (3b), hitboxes and damage (Step 4), the lock-on steering lock (Step 9), a real sword mesh and animation.

**Player scene additions**
```
Visual
  SwordVisual (Node3D, sword_visual.gd)
StateMachine
  (earlier states unchanged)
  Attack (attack_state.gd)
```
Set **Weapon** on the `Player` root to `weapons/katana.tres`. State node names must match exactly (`Attack`).

---

## 11. Conventions

- Typed GDScript throughout (`var x: float`, typed function signatures). Type loop variables when they feed a `:=` line (`for side: float in [-1.0, 1.0]`), or inference fails.
- `@export` and custom `Resource` classes for tunable data.
- Signals for events between components; autoload only when truly global.
- Input checked by **action name** only.
- Timings in **seconds**, never frames.
- **Never scale a `CollisionShape3D` node.** Set sizes on the shape resource itself (radius, height, size).
- The player scene root is the `CharacterBody3D` itself (no wrapper node).
- States never call `move_and_slide()`; the Player does it once per frame. After `machine.transition_to(...)`, `return` immediately.
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

### Terminology (shared shorthand)

- **Clock pose:** a `Vector3` (hour, radius in m, forward in m). The hour is read **from behind the player**: 12 = up, 3 = right, 6 = down, 9 = left (12:45 is 22.5 degrees past 12). Forward is in front of the player (negative = behind). Poses are authored as `swing_windup`, `swing_end`, `swing_follow` in `ActionData` and `rest_pose` in `WeaponData`.
- **Arm swing:** the placeholder sword motion in `SwordVisual`: the arm points from the shoulder to the aim point, the hand sits at arm's reach, the blade bends at the wrist, the tip follows a forward-bowed arc, and the cutting edge leads.
- **Aim point:** the 3D point a clock pose converts to (scaled by `pose_scale`); where the arm points.
- **Wrist angle:** the angle between the blade and the arm; positive = trailing (cocked), negative = leading.
- **Slash arc:** the forward bow of the tip's path during a slash.
- **Edge-leading:** the cutting edge (the yellow strip) faces the direction of travel.
- **Chain, flourish, lunge, TAE-style:** defined in `docs/step3-combat-spec.md`.

---

## 12. How Claude should work with me

- I'm on the **free web chat**, so **keep replies concise** to save usage. No long preambles.
- **Delivery:** follow `docs/work-agreements.md` (a zip of complete files for 3+ files). For a **single file**, edit the file for real and **present it** (no zip, no pasted code block in the reply). Don't send loose snippets unless I ask.
- When something needs scene setup, **list the nodes to create explicitly** (node type, name, parent, key properties).
- Tell me **where each script is attached** and what to name it.
- I can't be assumed to know Godot well; briefly explain the *why* of new concepts, but keep it short.
- **Don't assume decisions for me.** If something isn't in this doc, ask. Mark guesses as placeholders.
- I can't be tested by Claude: Claude can't run Godot, so I'll report results and errors. I'll give my Godot version (4.7.2) and paste error text.
- One build-order step at a time. Confirm it works before moving on.
- **Docs per chat:** handoff + work agreement + the current step's spec (Step 3: `docs/step3-combat-spec.md`) + a fresh snapshot. Start a new chat per phase so sessions stay small.
- **SOLID-minded new code:** new combat code reads data resources and keeps jobs separate (weapon data, a separate `Combatant`, attack data from resources). The cleanup refactor of the traversal code is **deferred until all of Phase 1 is done and tested by the user** (see the backlog).
- To share the project, run `python pack_for_claude.py` (in the project root; use `--only <paths>` to pack just the relevant folders) and upload the zip it creates in `snapshots/`. It includes the docs and skips binary assets (listing their names).
- The controller layout is Xbox/PlayStation style (see the Input Map table in 3.8).
- Feature creep is a known risk: flag it gently, and keep Phase 2 items deferred until Phase 1 works.

---

## 13. Phase 2 backlog (deferred on purpose)

- [ ] Corner shimmy and other ledge enhancements
- [ ] Enemy awareness system (sight cone, noise; states unaware, suspicious, alert, combat)
- [ ] Stealth deathblow from crouch (behind an unaware enemy, within ~2 m, removes one health bar)
- [ ] Enemy variety (jumpers/chasers, ranged rock throwers) as data flags in `EnemyAIData`
- [ ] Generic interact system (doors, chests, NPCs; nearest-in-front priority, on-screen prompt)

- [ ] **Cleanup refactor (after ALL of Phase 1 is done and tested by the user):** move wall and ledge sensing out of `player.gd`, replace hard-coded state name strings with constants, give the states a shared base (not typed to `Player`) so the enemy can reuse `ActionState` and the `Combatant` rules
- [ ] Real animation integration (Blender, glTF, `AnimationPlayer` following the action clock); notes in section 8 of `docs/step3-combat-spec.md`