# Handoff: Sekiro-Like Combat Prototype (Godot 4)

> Paste this whole file at the start of a new chat. Update the **Progress checklist** (section 10) at the end of each session and re-paste it next time.
>
> **Reminder:** deferred ideas live in the **Phase 2 backlog** (section 13). Don't forget them.

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
- Attack, attack combo, combo loop (last attack chains back to the first)
- Jump attack
- Guard, deflect, jump guard, jump deflect
- Shrinking deflect window when spammed
- Heal (limited charges), resurrection
- Action "locks" and "cancel windows" tunable as data
- Crouch (toggle by default): duck under attacks, crouch attack
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
- **Input Map** (everything except `crouch` and `interact` is already created in Project Settings; add those two in Step 2b):

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
| `crouch` (new) | Left Ctrl | Left Stick click |
| `interact` (new) | E | Left Action (X / Square) |

  Move, look, jump, and dodge are wired up so far.

### 3.9 Crouch
- **Toggle by default**, with a setting to switch to hold. Bound to Left Ctrl / left-stick click.
- Slower speed, shorter body capsule (set on the shape resource), and a shrunk hurtbox.
- Can't crouch in the air. You stay crouched if there's a low ceiling overhead.
- **Dodge and jump cancel crouch** (you stand up into the action).
- **Combat:** duck under enemy attacks, then counter with a **crouch attack**. There is **no `attack_height` variable**: ducking works because the hurtbox shrinks and an attack whose hitbox doesn't overlap it whiffs. Placement of each attack's hitbox (high, mid, low) decides what can be ducked.
- Stealth use (sneak up for a stealth deathblow) is Phase 2.

### 3.10 Mid-air reach, wall jump, and ledges
- **Pressing jump in mid-air gives no extra height.** The character reaches for a surface:
  - Wall in range: **wall jump** (kicks away from the wall and upward), which restores the reach. Capped per airtime (placeholder **2**).
  - Nothing in range: plays the reach and nothing else happens.
- **Ledges** (the `interact` button):
  - Reaching a ledge **without** pressing/holding `interact` makes the character **auto-climb** up (Nightreign style).
  - Pressing/holding `interact` at the ledge makes the character **hang** instead.
  - **Releasing `interact` does nothing**: you stay hanging until you act.
  - While hanging: forward = climb up, crouch = drop, jump = leap away, left/right = **shimmy along one straight line** (stops at corners).
  - The climb-up is an action with locked windows in `ActionData` (kind `LEDGE_CLIMB`).
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
- **Windows:** `locked_until`, `cancel_window` ((0,0) = from `locked_until` to the end), `buffer_window` (**not used yet**, for attack chaining in Step 3), `active_hit` (used from Step 4), `iframes`
- **Movement:** `move_speed`, `move_window`, `move_fade`, `move_end_factor` (speed at the window's end as a fraction of `move_speed`; 0 = fade to a stop)
- **Combat:** `damage`, `posture_damage`, `guardable`, `deflectable`, `pauses_posture_regen`, `combo_next` (loop back to the first for the combo loop)
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
| Crouch: speed / body capsule height | TBD / 1.1 m |
| Hurtbox profiles | stand 1.8/0, crouch 1.1/0, air 1.1/0.7 (height/offset) |
| Wall jumps per airtime | 2 |
| Ledge reach distances, climb-up duration, shimmy speed | TBD during tuning |
| Dodge: duration / locked until | 0.45s / 0.30s |
| Dodge: i-frames | 0.05s to 0.28s |
| Dodge: speed / window / end factor | 11 m/s / 0 to 0.30s / 0.3 (current, feels good to the user) |
| Backstep speed multiplier | 0.7 |
| Dash speed | 9.0 m/s |

---

## 7. Architecture notes

- Scenes composed from nodes; shared `Combatant` component on both player and enemy.
- State machine for player and enemy (states read `ActionData`). **Implemented for the player in Step 2a**; the Player drives it from `_physics_process` so the update order is deterministic.
- Hitboxes and hurtboxes as `Area3D`; damage info passed as data.
- Player body: `CharacterBody3D`. Third-person camera with collision (SpringArm3D). Lock-on camera mode.
- Resolve order: first connect wins, unless both hitboxes go active within the clash window (then clash).
- Animation: timer-driven; `AnimationPlayer` follows later.
- Debug overlay from early on (current state, active windows, hitbox visibility).
- Traversal as states in the same state machine: Crouch, AirReach/WallJump, LedgeHang, LedgeClimb (climb-up reads `ActionData`).
- Player hurtbox (`Area3D`) separate from the body capsule; both resized per state (see 3.11).

---

## 8. Build order

1. Third-person movement and camera (snappy), plus jump. Set up the Input Map for KBM and controller.
2. **2a.** State machine and `ActionData`; dodge with dash-hold and i-frames. **(done)**
   - **2b.** Crouch (toggle/hold setting, shrunk capsule and hurtbox); add `crouch` and `interact` to the Input Map.
   - **2c.** Mid-air reach and wall jump.
   - **2d.** Ledges: auto-climb, hang (hold `interact`), one-line shimmy, climb, drop, leap.
3. Attack, combo, and combo loop, using buffering and cancel windows; crouch attack.
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
- **O6:** Ledge details: grab reach, hang height, climb-up duration, shimmy speed.

---

## 10. Progress checklist (update each session)

- [x] 1. Movement, camera, jump, Input Map (KBM and controller) **(done and tested by the user)**
- [x] 2a. State machine, ActionData, dodge, dash-hold **(done and tested by the user)**
- [ ] 2b. Crouch (+ `crouch` / `interact` input actions)
- [ ] 2c. Mid-air reach, wall jump
- [ ] 2d. Ledges (auto-climb, hang, one-line shimmy)
- [ ] 3. Attack, combo, combo loop
- [ ] 4. Hitboxes, damage, hitstop
- [ ] 5. Guard, deflect, shrinking window, jump versions
- [ ] 6. Posture, deathblow, player stagger
- [ ] 7. Enemy AI and perilous attacks
- [ ] 8. Clash
- [ ] 9. Lock-on
- [ ] 10. Heal and resurrection
- [ ] 11. Polish

**Current state:** Steps 1 and 2a are complete and tested. **Next: Step 2b** (crouch, plus the `crouch` and `interact` input actions), then 2c and 2d.

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

**Not used yet:** `buffer_window` and `active_hit` in `ActionData` (Steps 3 and 4).

---

## 11. Conventions

- Typed GDScript throughout (`var x: float`, typed function signatures).
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

---

## 12. How Claude should work with me

- I'm on the **free web chat**, so **keep replies concise** to save usage. No long preambles.
- **Only send changed functions or snippets**, not whole scripts, unless I ask.
- When something needs scene setup, **list the nodes to create explicitly** (node type, name, parent, key properties).
- Tell me **where each script is attached** and what to name it.
- I can't be assumed to know Godot well; briefly explain the *why* of new concepts, but keep it short.
- **Don't assume decisions for me.** If something isn't in this doc, ask. Mark guesses as placeholders.
- I can't be tested by Claude: Claude can't run Godot, so I'll report results and errors. I'll give my Godot version (4.7.2) and paste error text.
- One build-order step at a time. Confirm it works before moving on.
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