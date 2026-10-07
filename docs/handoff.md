# Handoff: Sekiro-Like Combat Prototype (Godot 4)

> Paste this whole file at the start of a new chat. Update the **Progress checklist** (section 10) at the end of each session.
>
> **Docs.** Section numbers are kept stable; a moved section leaves a pointer.
>
> | File | Paste it? |
> |---|---|
> | `docs/handoff.md` (this file) | always |
> | `docs/work-agreements.md` | always |
> | `docs/step3-combat-spec.md` | when working on Step 3 (attacks, sheathing) |
> | `docs/design-later-steps.md` | when starting Step 4 or later (hitboxes, guard, posture, enemy, clash, lock-on, heal) |
> | `docs/archive/build-log.md` | **never** (history; Claude only appends to it) |
>
> Plus a fresh snapshot (section 12). Start a new chat per phase.
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
- Clash mechanic (new, see 3.3 in `docs/design-later-steps.md`)
- Input buffering
- Third-person camera with collision, lock-on camera
- Hitstop, camera shake, spark/sound hooks
- Debug overlay (state, active windows, hitboxes)

---

## 3. Design decisions (confirmed by the user)

> 3.1 to 3.6 (health, posture, deathblow, guard, deflect, clash, enemy behavior, perilous attacks, grab, heal) and 3.11 (hurtbox profiles) are in `docs/design-later-steps.md`.

### 3.7 Dodge
- Small i-frames, **no stamina system at all**.
- Hold the dodge button after dodging to dash.
- Dodge can't be used during locked parts of other actions (see action windows). **Ground only** (no air dodge).
- **Direction:** follows the movement input (relative to the camera). With no input it is a **backstep** (no turning, 0.7x speed).
- **Dash:** if the dodge button is still held when the dodge unlocks (0.30s) and there is movement input, the dodge flows into a dash. The dodge's burst fades to a floor speed (`move_end_factor`, 0.3), not to zero, so there is no full stop. The dash ends on button release, no movement input, leaving the ground, or jumping. A quick tap ends with a short slide.
- After the locked window, jump, a new dodge, and movement are all allowed (presses just before are buffered, 0.15s).
- **Dodge attack (3c-1):** attack pressed after the locked window starts the **dash attack** (the draw slash while sheathed).

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
| `sheathe` | R | D-pad Down |

  Move, look, jump, dodge, crouch, interact (ledge hang and climb), attack, and sheathe are wired up so far.

### 3.9 Crouch (built; full original text in the build log, Part 2)
- **Toggle by default** (a setting switches to hold); Left Ctrl / left-stick click. Slower, with a shorter body capsule (set on the shape resource, changes instantly; the mesh eases over `crouch_transition_time`). No crouching in the air. A low ceiling keeps you crouched.
- **Dodge and jump cancel crouch** (they need headroom; under a low ceiling the presses are ignored and discarded).
- **Crouch slide:** `crouch` pressed **while dashing** starts a slide (`ActionState` driven by `actions/slide.tres`, i-frames like the dodge, ends in Crouch; jump and dodge cancel it after its locked window, with headroom).
- **Crouch and slide attacks:** a tap loop that keeps you crouched, hold = the upward slash (spec, section 6).
- **Ducking works because the hurtbox shrinks** (Step 4; 3.11 in `docs/design-later-steps.md`); there is no `attack_height` variable. Stealth use is Phase 2.

### 3.10 Mid-air reach, wall jump, and ledges (built; full original text in the build log, Part 2)
- **Jump in mid-air gives no extra height:** the character reaches for a surface. A wall within `wall_range` gives a **wall jump** (restores the reach, capped per airtime at 2; direction from the camera-relative input versus the wall normal: toward = up, away = backward, sideways = along the wall, no input = away; boost 1.2x). Otherwise the **reach** plays once per airtime. An air jump press within 0.3 m of the floor is ignored (it stays buffered for the landing jump).
- **Ledges** (`interact`): grab needs airborne, input toward a wall, a flat ledge top in the hand zone (1.4 to 2.1 m above the feet) with room to stand. Reaching it without `interact` **auto-climbs** (scripted `LedgeClimb`); with `interact` the character **hangs** (`LedgeHang`): a fresh `interact` = climb, crouch = drop, jump = leap away, left/right = shimmy 1.5 m/s along one straight line. Releasing `interact` does nothing. After a drop or leap there is no grab for 0.3 s. A hit knocks the player off the ledge (`LedgeHangState.knock_off()`, called from the damage system in Step 4).
- Air actions stay available after a wall jump. **Arena rule:** the combat arena stays reachable by the single melee enemy; traversal gets its own test area. Corner shimmy and other ledge enhancements are Phase 2.

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

### 5.1 `ActionData` (`resources/action_data.gd`)

Every field has a doc comment in the script; that file is the reference. All times are seconds from the start of the action, windows are `Vector2(start, end)`. Groups: identity (`kind`, `animation`, `duration`, `speed_scale`), windows (`locked_until`, `cancel_window`, `buffer_window`, `active_hit`, `iframes`), movement, swing visual (clock poses), charge, hold action, combat (`damage`, `posture_damage`, ...), and `combo_next` (variant loops). Helpers: `in_window()`, `is_locked()`, `can_cancel()`, `has_iframes()`, `is_hit_active()`.

`EnemyAIData`, `Combatant`, and `HurtboxProfile` (sketches) are in `docs/design-later-steps.md`.

---

## 6. Placeholder numbers

Moved. The numbers for **built** features live in the Player and SwordVisual exports (Inspector) and in the `.tres` files (the truth); the old table is in the build log, Part 3. Placeholders for **not-yet-built** features (deflect, clash, stagger, heal, posture, hurtbox profiles) are in `docs/design-later-steps.md`.

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
- Player hurtbox (`Area3D`) separate from the body capsule; both resized per state (see 3.11 in `docs/design-later-steps.md`).
- Combat states: `Attack` (ground combo, extends `ActionState`) reads `Player.weapon` (`WeaponData`); the sword is a separate placeholder visual (`SwordVisual`) driven by the attack's action clock. Air combat: `AirAttack` (the tap loop) and `HelmSplitter` (the hold dive, then a wind-down), both `ActionState` subclasses. Sheathing is a plain flag on the Player (`sheathed`); `SwordVisual` animates the draw and sheathe, and `AttackState.try_start_variant()` swaps in the draw slash while sheathed.

---

## 8. Build order

1. Third-person movement and camera, jump, Input Map for KBM and controller. **(done)**
2. **2a** state machine, `ActionData`, dodge with dash-hold; **2b** crouch and slide; **2c** mid-air reach and wall jump; **2d** ledges (auto-climb, hang, shimmy, climb, drop, leap). **(all done)**
3. Attacks, full design in `docs/step3-combat-spec.md`:
   - **3a-1** ground 5-attack combo, **3a-2** hold and charged zigzag thrust. **(done)**
   - **3b-1 to 3b-4** dash attack, crouch and slide attacks, air tap loop, helm splitter. **(done)**
   - **3c-1** sheathing (visual only: scabbard, `sheathe` button R, auto-sheathe, animated hand reach), the draw slash (iai) replacing every attack while sheathed, and the dodge attack. **(done)**
   - **3c-2** the charged iai (hold while sheathed; the shockwave and extra damage come in Step 4 and the polish) and the sheathed helm splitter (hold in the air while sheathed: the draw, a raised blade under half gravity, then the dive). **(done)** Needs sheathed and drawn animation sets later.
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

## 9. Open questions

The unresolved ones (O1 to O5, all about later steps) are in `docs/design-later-steps.md`. Resolved ones are in the build log, Part 4. Ask the user before assuming.

---

## 10. Progress checklist (update each session)

- [x] 1. Movement, camera, jump, Input Map (KBM and controller) **(done and tested by the user)**
- [x] 2a. State machine, ActionData, dodge, dash-hold **(done and tested by the user)**
- [x] 2b. Crouch, crouch slide, animated crouch (+ `crouch` / `interact` input actions) **(done and tested by the user)**
- [x] 2c. Mid-air reach, wall jump **(done and tested by the user)**
- [x] 2d. Ledges (auto-climb, hang, one-line shimmy, climb, drop, leap) **(done and tested by the user)**
- [x] 3a-1. Ground 5-attack combo, loop, chain/cancel, arm-swing sword visual, `WeaponData` (see the Step 3 spec) **(built; the user saw the combo and the arm-swing sword working and approved the look; cancels, the lunge, and the ledge stop were not formally tested yet)**
- [x] 3a-2. Hold, charged zigzag thrust that connects to the combo (see the build log, "Step 3a-2") **(done and tested by the user)**
- [x] 3b-1. Dash attack (tap and hold) and the shared variant plumbing **(done and tested by the user; lunge speeds and the 2:45 to 8:45 angle tuned by the user)**
- [x] 3b-2. Crouch and slide attacks, crouch visuals for the sword (see the build log, "Step 3b-2") **(done and tested by the user; the rapid-click hold fix and the alternating upward slash were added and tested 2026-10-06)**
- [x] 3b-3. Air tap loop (see the build log, "Step 3b-3") **(done and tested by the user)**
- [x] 3b-4. Helm splitter, and the air tap loop sped up 1.5x (see the build log, "Step 3b-4") **(done and tested by the user)**
- [x] 3c-1. Sheathing (visual), R, auto-sheathe, the animated reach, the draw slash replacing every attack while sheathed, and the dodge attack (see the build log, "Step 3c-1") **(done and tested by the user 2026-10-07)**
- [x] 3c-2. The charged iai (hold) and the sheathed helm splitter, plus the `_thrust_mirror` fix (see the build log, "Step 3c-2") **(done and tested by the user 2026-10-07)**
- [ ] 4. Hitboxes, damage, hitstop
- [ ] 5. Guard, deflect, shrinking window, jump versions
- [ ] 6. Posture, deathblow, player stagger
- [ ] 7. Enemy AI and perilous attacks
- [ ] 8. Clash
- [ ] 9. Lock-on
- [ ] 10. Heal and resurrection
- [ ] 11. Polish

**Current state:** Steps 1 to 3c-2 are built and tested (all of Step 3). **Next: Step 4** (hitboxes, damage, hitstop). Start a **new chat** for each phase and paste the files listed at the top of this handoff, plus a fresh snapshot (`python pack_for_claude.py`). Send a full check before building each phase.

### What the finished steps built (details: `docs/archive/build-log.md`; each script's header comment describes its behavior)

- **1 Movement and camera:** `player.gd` (the `CharacterBody3D` root), `camera_rig.gd` (`top_level`, spring arm), test arena as the main scene, Input Map for KBM and controller.
- **2a State machine:** `StateMachine` and `State` nodes under the Player; `ActionState` runs an `ActionData` clock (`action_time`, `speed_scale`) and reads its windows; `InputBuffer` (0.15 s, tracks jump, dodge, interact, attack); the dodge with i-frames and dash-hold; `DebugOverlay`. States never call `move_and_slide()`.
- **2b to 2d Traversal:** `CrouchState`, `SlideState` (an `ActionState`), `WallJumpState` and the mid-air reach (`ReachArms`, debug-grade), `LedgeClimbState` and `LedgeHangState` (`knock_off()` is the hook for Step 4). Rules in 3.9 and 3.10.
- **3a Ground combo and thrust:** `WeaponData` (the katana), `AttackState` (combo, chain, cancels, lunge with ledge stop, hold becomes the charged zigzag thrust), `SwordVisual` (the placeholder arm-swing sword: clock poses, edge-leading blade, body twist). Rules in the Step 3 spec.
- **3b Variants:** other states hand over through `AttackState.try_start_variant()`; dash, crouch and slide attacks, `AirAttackState` (the air loop), `HelmSplitterState` (hold in the air). Variants count as combo step 1; `ActionData.hold_action` names what a hold selects.
- **3c-1 Sheathing:** `Player.sheathed` (spawns true), R and D-pad Down (`sheathe`), auto-sheathe (`auto_sheathe_time`, 5 s, counted only in Locomotion or Crouch), the draw slash (`WeaponData.draw_attack`; `try_start_variant()` swaps it in while sheathed; it counts as no combo step), the dodge attack (`DodgeState`), and the `SwordVisual` scabbard, pin, stretching arm, and draw and sheathe animations.
- **3c-2 Charged iai and sheathed helm splitter:** the draw slash's `hold_action` is `draw_attack_charged.tres` (charge 0.6 s, x1.5 damage and x1.4 lunge stored for Step 4); `AttackState` charges it with `SwordVisual.update_charge_iai()` (blade half drawn, glow), never mirrored, standing you up when it fires from a crouch or slide. In the air, `AirAttackState` starts `HelmSplitterState` with `WeaponData.draw_helm_action` (`helm_splitter_draw.tres`, a 0.4 s raise); gravity is halved (`HelmSplitterState.opening_gravity_factor`) while holding in the draw wind-up and through the raise, then the usual dive. `_thrust_mirror` now resets on every new action.

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
- **Body twist / arm lead:** the torso (and nose) rotates toward each pose's side, and the arm swing rotates `arm_twist_factor` times further than the body.
- **Variant, hold action:** a variant is an attack started from another state (dash, crouch, slide, air) and counts as combo step 1; a `hold_action` is what replaces an attack when the button is held at the decision point.
- **Hold, charge, thrust, zigzag:** holding attack at the end of a wind-up charges a thrust (orange glow, up to 0.6 s). The thrust zigzags: it starts on the side where the previous slash ended, and the opposite side after a thrust.
- **Sheathed / drawn, draw slash (iai):** the sword is either in the scabbard (visual only) or in the hand. An attack from the sheathed state plays the **draw slash** (8:00 to 2:00), which counts as no combo step. **Reach** = the hand moving to the grip; **pin** = the blade root held at the grip while the hand is not holding it.
- **Chain, flourish, lunge, TAE-style:** defined in `docs/step3-combat-spec.md`.

---

## 12. How Claude should work with me

- I'm on the **free web chat**, so **keep replies concise** to save usage. No long preambles.
- **Delivery:** follow `docs/work-agreements.md` (a zip of complete files for 3+ files). For a **single file**, edit the file for real and **present it** (no zip, no pasted code block in the reply). Don't send loose snippets unless I ask.
- When something needs scene setup, **list the nodes to create explicitly** (node type, name, parent, key properties).
- Tell me **where each script is attached** and what to name it.
- I can't be assumed to know Godot well; briefly explain the *why* of new concepts, but keep it short.
- **Don't assume decisions for me.** If something isn't in this doc, ask. Mark guesses as placeholders.
- Claude can usually run **Godot 4.7.2 headless** in its sandbox (work agreement, section 4) to parse-check and smoke-test, but it can't judge how things look or feel, so I still test and report results and errors (Godot 4.7.2, with the error text).
- **Tuned `.tres` files:** if Claude has my latest snapshot it may edit the real file and deliver it with only the requested change; otherwise it gives "change X to Y" (work agreement, section 3). I tell Claude when I tune a file after sending a snapshot.
- One build-order step at a time. Confirm it works before moving on.
- **Docs per chat:** the files listed at the top of this handoff + a fresh snapshot. Start a new chat per phase so sessions stay small. **Claude does not read `docs/archive/build-log.md` or `docs/design-later-steps.md` unless needed, and appends an entry to the build log after each finished step** (work agreement, section 7).
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
- [ ] Swing trail / smear effect for sword swings (a ribbon that follows the blade tip during the active window and fades; none exists yet; fits Step 11 polish or real animation VFX)
- [ ] Real animation integration (Blender, glTF, `AnimationPlayer` following the action clock); notes in section 8 of `docs/step3-combat-spec.md`