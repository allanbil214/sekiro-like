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
> | `docs/phase-1-5-plan.md` | when working on Phase 1.5 (the cleanup and hardening items between Phase 1 and Phase 2; done) |
> | `docs/phase-2-plan.md` | when working on Phase 2 (the main menu, the pause menu, the arena chooser and fall zone; the later items come from section 13) |
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
- Shrinking deflect window when spammed (rapid taps, or after 3 presses; see the build log)
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
- ~~Clash mechanic~~ **dropped** (first connect wins, as in FromSoftware; see 3.3 in `docs/design-later-steps.md`)
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
| `pause` | Esc | Start |

  Move, look, jump, dodge, crouch, interact (ledge hang and climb), attack, and sheathe, and guard are wired up so far.

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
- Resolve order: first connect wins (the clash was dropped, Step 8).
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
7. Enemy AI, in three parts:
   - **7a** enemy core: movement, spacing, attack bursts with the player's ground combo. **(done)**
   - **7b** guard, deflect, repulse, flinch, riposte, recovery pose, adaptive guard chance. **(done)**
   - **7c** perilous attacks. **7c-1** the framework, danger symbol, thrust with mikiri, sweep with jump-over, the `monk` preset, combos continuing into a perilous attack, head bounce and slide. **(done)** **7c-2** the grab (answers O5). **(done and tested by the user 2026-10-08)** The high/mid/low enemy hitboxes were dropped (real animations will set the height).
   - **7d** varied deflect animations (side, high, low, thrust), shared by the player and the enemy, plus the perilous thrust's knockback. **(done and tested by the user 2026-10-08)**
8. ~~Clash mechanic.~~ **Dropped (2026-10-08):** the game follows FromSoftware, first connect wins. The design that was considered is kept in `docs/design-later-steps.md`, 3.3.
9. Lock-on. **(done and tested by the user 2026-10-09)**
10. Heal and resurrection (prompt, final death, scene reset), plus the player HUD and the new posture bar look. **(done and tested by the user 2026-10-09)**
11. Polish, in parts (plan agreed 2026-10-09; details in `docs/design-later-steps.md`, 3.12):
    - **11a** sound **(done and tested 2026-10-09)**. **11b** sparks and effects (colors per outcome, heal, resurrect, dust, the deathblow blood jet). **(done and tested 2026-10-09)** **11c** camera shake (trauma system) and the `Fx` helper. **(done and tested)** **11d** boss-slain screen, heal arm, death-reload fix. **(done and tested 2026-10-09)** **11e** shockwave for the helm splitter and the charged iai. **(done and tested 2026-10-09)** **11f** sword swing trail (player and enemy). **(done and tested 2026-10-09)** **11g** subtle crouch vignette. **(done and tested)**
    - Order: 11c, 11b, 11e, 11f, 11g (all done, and 11a, sound, came last once the wavs existed).

12. **Cleanup refactor** (the last Phase 1 step; agreed 2026-10-12; design in `docs/design-later-steps.md`, 3.13). Four parts, in this order: **12A** remove the "create the node in code" fallbacks, **12B** state-name constants (`StateName`), **12C** wall and ledge sensing out of `player.gd` into `LedgeSensor`, **12D** a shared action-clock core that is not typed to `Player`, so the enemy can reuse it. Pure refactor: no gameplay change, no tuning. All four parts are built and tested (2026-10-12), so **Step 12 is done**.

13. **Phase 1.5: hardening and cleanup** (between Phase 1 and Phase 2; agreed 2026-10-12; plan, order and rules in `docs/phase-1-5-plan.md`). Eleven items (nine at the start, 10 and 11 added later at the user's request), built one at a time, each tested before the next. Items 4 and 7 (the `Groups` constants) 3 (debug output only in debug builds) 2 (typed trail points), 1 (the shared enemy list), 6 (input action names and the lock-on reason) 9 (pooled `Fx` particle emitters), 5a (`SwordGuardPoses`), 5b (`EnemyDefense`) and 5c (`PlayerForcedMovement`, `PlayerBodyReaction`), 10 (`Sfx` voice pool) and 11 (the `Fx` ramp and curve cache) are done; item 8 is a deferral to Phase 2.
14. **Phase 2: new features** (agreed 2026-10-12; plan and decisions in `docs/phase-2-plan.md`; the open ideas stay in section 13). The first items: 1 the main menu, 2 the pause menu, 3 the arena chooser with a fall zone and three base arenas, 4 the death and victory screens as scenes (the HUDs wait for real art), 5 loading screens (done and tested 2026-10-13). New menus are scenes with one shared Theme. Direction: a Way of the Samurai, Shinobido and Rise of Ronin style quest and game design with Sekiro's combat; the current arenas are placeholder and testing maps.

*Note: traversal (2b-2d) comes before combat by the user's choice, which delays the combat loop. Move it later if scope becomes a problem.*

---

## 9. Open questions

The unresolved ones (O1, O2, O5, all about later steps; O3 was settled in Step 5 and O4 in Step 9) are in `docs/design-later-steps.md`. Resolved ones are in the build log, Part 4. Ask the user before assuming.

---

## 10. Progress checklist (update each session)

- [x] 1. Movement, camera, jump, Input Map (KBM and controller) **(done and tested by the user)**
- [x] 2a. State machine, ActionData, dodge, dash-hold **(done and tested by the user)**
- [x] 2b. Crouch, crouch slide, animated crouch (+ `crouch` / `interact` input actions) **(done and tested by the user)**
- [x] 2c. Mid-air reach, wall jump **(done and tested by the user)**
- [x] 2d. Ledges (auto-climb, hang, one-line shimmy, climb, drop, leap) **(done and tested by the user)**
- [x] 3a-1. Ground 5-attack combo, loop, chain/cancel, arm-swing sword visual, `WeaponData` (see the Step 3 spec) **(done and tested by the user; cancels, the lunge, and the ledge stop were confirmed with Step 12, 2026-10-12)**
- [x] 3a-2. Hold, charged zigzag thrust that connects to the combo (see the build log, "Step 3a-2") **(done and tested by the user)**
- [x] 3b-1. Dash attack (tap and hold) and the shared variant plumbing **(done and tested by the user; lunge speeds and the 2:45 to 8:45 angle tuned by the user)**
- [x] 3b-2. Crouch and slide attacks, crouch visuals for the sword (see the build log, "Step 3b-2") **(done and tested by the user; the rapid-click hold fix and the alternating upward slash were added and tested 2026-10-06)**
- [x] 3b-3. Air tap loop (see the build log, "Step 3b-3") **(done and tested by the user)**
- [x] 3b-4. Helm splitter, and the air tap loop sped up 1.5x (see the build log, "Step 3b-4") **(done and tested by the user)**
- [x] 3c-1. Sheathing (visual), R, auto-sheathe, the animated reach, the draw slash replacing every attack while sheathed, and the dodge attack (see the build log, "Step 3c-1") **(done and tested by the user 2026-10-07)**
- [x] 3c-2. The charged iai (hold) and the sheathed helm splitter, plus the `_thrust_mirror` fix (see the build log, "Step 3c-2") **(done and tested by the user 2026-10-07)**
- [x] 4a. Hitbox, hurtbox, `Combatant` (HP), dummy with a floating Sekiro-style bar, hitstop (see the build log, "Step 4a") **(done and tested by the user 2026-10-07)**
- [x] 4b. Player hurtbox profiles (stand/crouch/air), the dummy swinging (high/mid/low), the player taking damage with a hit wobble, duck-under and jump-over whiffs (see the build log, "Step 4b") **(done and tested by the user 2026-10-07)**
- [x] 5. Guard, deflect, shrinking window, jump versions, knockback (see the build log, "Step 5") **(done and tested by the user 2026-10-07)**
- [x] 6. Posture, posture break, deathblow, player stagger, charged posture, defense multipliers, deathblow marker (see the build log, "Step 6") **(done and tested by the user 2026-10-07)**
- [x] 7a. Enemy core: `Enemy` scene, chase/spacing/yield loop, bursts of the player's ground combo, `EnemyAIData`, visual recoil (see the build log, "Step 7a") **(done and tested by the user 2026-10-07)**
- [x] 7b. Enemy defense: guard, deflect, repulse, flinch, riposte, recovery pose, four `ai/` presets (see the build log, "Step 7b") **(done and tested by the user 2026-10-08, including the later pressure update: armored riposte, break-out, per-preset tempo)**
- [x] 7c-1. Perilous framework, danger symbol, thrust with mikiri, sweep with jump-over, the `monk` preset (spear look), `Debug Force Perilous` (see the build log, \"Step 7c-1\") **(done and tested by the user 2026-10-08, including the first follow-up batch: combos continuing into a perilous attack, the head slide, the bobblehead flinch, round red health dots inside the bar, the player's kneel and sway; and the second follow-up batch: the jump-over counter fires when the player lands on the head, air steering with kept momentum, a tight deflect of the perilous thrust)**
- [x] 7c-2. The grab (yellow symbol, unguardable, dodge counter, breaks the guard and kneels the player visually; answers O5) **(done and tested by the user 2026-10-08; the high/mid/low enemy hitboxes were dropped: real animations will drive the hit height)**
- [x] 7d. Varied deflect animations: four kinds (side, mirrored for the left; high; low; the thrust's slap) picked from the incoming attack, aimed partly at the contact point, shared by the player and the enemy; a plain guard keeps its flick; plus the perilous thrust's knockback (3.0 m, 0.4 s ease; a deflect pushes 0.6 of it) **(done and tested by the user 2026-10-08; poses can still be tuned with `SwordVisual.debug_force_deflect`)**
- [x] ~~8. Clash~~ **(dropped 2026-10-08: first connect wins, like FromSoftware; nothing of it is in the code)**
- [x] 9. Lock-on: target search and switching (mouse or stick flick), the camera that frames the target, the body facing it, the marker (see the build log, "Step 9") **(done and tested by the user 2026-10-09, with the camera tuned to a 0.8 m higher pivot and a 10 degree extra tilt)**
- [x] 10. Heal (3 charges), death with 2 resurrections (prompt, Die, scene reload), the player HUD (health, pips, gourd, posture bar), the death screen (darken, blood vignette, 死), and the posture bars restyled (see the build log, "Step 10") **(done and tested by the user 2026-10-09)**
- [x] 11. Polish (in parts; all done):
  - [x] 11a. Sound: the `Sfx` helper, the table `audio/sfx_data.tres`, 44 wavs, hooks on every event (see the build log, "Step 11a") **(done and tested by the user 2026-10-09; with it the personal-space push, see the bullet under 11g)**
  - [x] 11b. Sparks and effects: colors per outcome, heal, resurrect, dust, and the 2 s deathblow blood jet that sprays toward the player and follows the enemy (see the build log, "Step 11c and 11b") **(done and tested by the user 2026-10-09)**
  - [x] 11c. Camera shake (trauma) and the `Fx` helper (see the build log, "Step 11c and 11b") **(done and tested by the user, confirmed 2026-10-12; the numbers are still untuned placeholders)**
  - [x] 11d. Boss-slain screen (`VictoryScreen`, 討取 / ENEMY SLAIN), left-arm heal animation (`HealArm`), and the death-reload fix (see the build log, "Step 11d") **(done and tested by the user 2026-10-09)**
  - [x] 11e. Shockwave visual: a glowing blade extension and a ground ring for the helm splitter, a crescent wave for the charged iai (see the build log, "Step 11e and 11f") **(done and tested by the user 2026-10-09)**
  - [x] 11f. Sword swing trail (player and enemy; `SwordVisual.swing_trail`) **(done and tested by the user 2026-10-09)**
  - [x] 11g. Subtle crouch vignette while crouched or sliding (`CrouchVignette`; see the build log, "Step 11g") **(done and tested by the user, confirmed 2026-10-12)**

- [x] 12. Cleanup refactor, the last Phase 1 step (see 3.13 in `docs/design-later-steps.md`):
  - [x] 12A. Remove the fallbacks: `Guard` state, `Combatant`, `Hurtbox` (and its `CollisionShape3D`) in `player.gd`, and `Hitbox` in `sword_visual.gd` **(done and tested by the user 2026-10-12)**
  - [x] 12B. `StateName` constants (`scripts/player/states/state_name.gd`) replace the state-name strings: 85 `transition_to` calls, the `previous`/`next`/`current` comparisons, the returns of `ledge_grab_state()`, and the 11 `get_node_or_null` lookups (123 places in `player.gd` and 18 state scripts; behavior unchanged, the null checks stay) **(done and tested by the user 2026-10-12; fix1 wrapped the `get_node_or_null` constants in `NodePath(...)`, which 12C then replaced with `StateMachine.get_state()`)**
  - [x] 12C. `LedgeSensor` (`scripts/player/ledge_sensor.gd`, a `RefCounted` made in `Player._ready()` as `Player.ledge_sensor`): `find_wall`, `find_ledge`, `try_ledge_grab`, `ledge_grab_state`, `probe_hang_ledge`, `can_hang_at` and the two private helpers moved out of `player.gd` (about 230 lines); the tuned exports and the `ledge_*` data fields stay on `Player`; `Player._fits_standing_at` is now public `fits_standing_at` and `Player.get_body_radius()` is new; `StateMachine.get_state(StateName.X)` replaces the 11 `get_node_or_null(NodePath(...))` lookups **(done and tested by the user 2026-10-12)**
  - [x] 12D. `ActionRunner` (`scripts/combat/action_runner.gd`, a `RefCounted` that knows neither `Player` nor `Enemy`): the action clock (`time`), `hit_is_active()`, `open_hit()` / `end_hit()` (the hitbox swing), `make_hit()` (the `HitData` fields copied from the `ActionData`), and the movement fade (`in_move_window()`, `move_fade_factor()`). The action is passed on every call because the player's states swap `action` mid-state. `ActionState.runner` and `Enemy._runner` own one each; `ActionState.action_time` and `Enemy._action_time` are properties that forward to the runner, so the rest of the code reads as before. What differs stays with the owner: sounds, `_active_speed_factor` vs `_attack_speed`, the perilous and grab overrides, chain timing. The states were not retyped away from `Player` (the enemy does not use the state machine, so it would gain nothing) **(done and tested by the user 2026-10-12: combo bursts, perilous thrust, sweep and grab, guard and deflect, own attacks, deathblow)**
  - The 3a-1 leftovers (cancels, lunge, ledge stop), 11c (camera shake) and 11g (crouch vignette) were also marked tested with Step 12 (the user had tested them, 2026-10-12).

- [x] 13. Phase 1.5, hardening and cleanup (see `docs/phase-1-5-plan.md`; items numbered as in that file):
  - [x] 4 and 7. `Groups` constants (`scripts/combat/groups.gd`: `PLAYER`, `ENEMY`, `DANGER_SYMBOL`, `CAMERA_RIG`, `VICTORY_SCREEN`) replace the group-name strings: 17 places in `player.gd`, `enemy.gd`, `dummy.gd`, `lock_on.gd`, `camera_rig.gd`, `danger_symbol.gd`, `victory_screen.gd`, `fx.gd` **(done and tested by the user 2026-10-12)**
  - [x] 3. The 11 debug `print`s (`Combatant`, `Enemy`) check `debug_log and OS.is_debug_build()`, and `Hitbox.debug_draw` draws only in debug builds; `push_error` and `push_warning` stay in every build **(done and tested by the user 2026-10-12)**
  - [x] 2. `Hitbox._trail_points` is an `Array[TrailPoint]` (a small inner class: `tip`, `base`, `age`, `start`) instead of an `Array[Dictionary]` **(done and tested by the user 2026-10-12)**
  - [x] 1. `Enemies` (`scripts/combat/enemies.gd`, static `register` / `unregister` / `all()`): `Enemy` and `Dummy` register in `_ready()` and leave in `_exit_tree()`; the 5 per-frame `get_nodes_in_group(Groups.ENEMY)` searches (`Player` 2, `LockOn` 3) use `Enemies.all()`; the list holds every enemy in the tree, dead ones too **(done and tested by the user 2026-10-12)**
  - [x] 6. `Actions` (`scripts/player/actions.gd`, 17 `StringName` constants) replaces the Input Map action-name strings (141 places in 21 files), and `LockOn.LostReason` replaces the string reason codes **(done and tested by the user 2026-10-12; 6C, the swing sound by animation name, was left on purpose, see `docs/phase-1-5-plan.md`)**
  - [x] 9. `Fx` pools its `CPUParticles3D` emitters (`scripts/combat/fx.gd`: `Fx.Pool.SPARKS` and `PUFFS`, 8 each on first use, grown when dry, at most 64 kept idle, emptied on a scene reload; the rings and the blood jet's tween are not pooled) **(done and tested by the user 2026-10-12)**
  - [x] 5a. `SwordGuardPoses` (`scripts/player/sword_guard_poses.gd`, a `RefCounted` owned by `SwordVisual` as `_poses`): the deflect poses (kind choice, mirroring, aim toward the contact, timing) and the guard-break pose moved out of `sword_visual.gd`; the exports, the wobble and the flash stay on `SwordVisual` **(done and tested by the user 2026-10-12)**
  - [x] 5b. `EnemyDefense` (`scripts/enemy/enemy_defense.gd`, a `RefCounted` owned by `Enemy` as `_defense`): the defense decisions (threat reading, the plan roll, the press timing, the riposte timer, the hit and guarded-hit streaks with the break-out) moved out of `enemy.gd`; `Enemy` keeps the guard actuators (now public `raise_guard()`, `drop_guard()`, `is_guarding()`), the phases, the attacks and every export **(done and tested by the user 2026-10-12)**
  - [x] 5c. `player.gd` split into two helpers made in `Player._ready()`: `PlayerForcedMovement` (`_forced`: knockback, the enemy-head bounce and slide, personal space) and `PlayerBodyReaction` (`_reaction`, placeholder: the hit wobble, the stagger lean, the kneel and sway, the grab kneel); the exports stay on `Player`, and `apply_knockback()`, `set_stagger_lean()` and `set_stagger_kneel()` stay as wrappers **(done and tested by the user 2026-10-12)**
  - [x] 10 and 11 (added 2026-10-12 at the user's request). `Sfx` pools its `AudioStreamPlayer` and `AudioStreamPlayer3D` voices (`scripts/audio/sfx.gd`: grown on demand, at most 32 idle per kind, emptied on a scene reload; each voice remembers its cut-off group and `_release()` erases the group entry, so a reused voice is never cut by mistake), and `Fx._ramp()` and `Fx._curve()` cache and share their `Gradient` and `Curve` **(done and tested by the user 2026-10-12)**
  - (8 is a deferral to Phase 2, nothing to build; every other Phase 1.5 item is done)

- [ ] 14. Phase 2, new features (see `docs/phase-2-plan.md`; items numbered as in that file; 5 is the loading screens, 6 and later come from section 13):
  - [x] 1. Main menu: a "PRESS ANY BUTTON" title screen, then START, OPTIONS (empty panel), QUIT; "UNTITLED GAME" and "STILL A PROTOTYPE", a faded 道 behind it, a footer, music and menu sounds, the shared `ui_theme.tres` **(done and tested by the user 2026-10-12)**
  - [x] 2. Pause menu: Resume, Options, Quit to Title (the game pauses; Esc or Start; a `PauseMenu` scene under the Player) **(done and tested by the user 2026-10-12)**
  - [x] 3. Arena chooser, split into three parts, each built and tested in turn **(done and tested by the user 2026-10-13)**:
    - [x] 3a. Fall zone (Sekiro-style: back to the start with 25 percent of max health lost, never lethal; a fade, 1 s of invulnerability) **(done and tested by the user 2026-10-12)**
    - [x] 3b. `ArenaData` and the chooser (the ARENAS main-menu entry, the debug-only "Change arena" in the pause menu) **(done and tested by the user 2026-10-12)**
    - [x] 3c. The arenas, in two builds **(done and tested by the user 2026-10-13)**:
      - [x] 3c-1. The fighting arena, its eight variants (dummy, soldier, duelist, aura, repulser, monk, grappler, squad) and the invisible walls **(done and tested by the user 2026-10-12)**
      - [x] 3c-1 addendum. The boss HUD (name, health bar and dots top left, posture bar top center; the first boss to notice you owns it, a lone hit on another boss passes it over) and a ninth arena, "Two Bosses" **(done and tested by the user 2026-10-13)**
      - [x] 3c-2. The movement arenas: a Training Yard and a Gauntlet (two scenes, no enemies; stairs with an invisible smooth ramp and a raw-steps station), plus the crouch camera height and the chooser font and spacing change **(done and tested by the user 2026-10-13)**
  - [x] 4. The death and victory screens as scenes with the shared Theme (a refactor; the HUD and `BossHud` wait for real art; `EnemyBar`, `DangerSymbol`, `DebugOverlay` and `CrouchVignette` stay as they are) **(done and tested by the user 2026-10-13)**
  - [x] 5. Loading screens: a proper one with tips (from the editable `data/loading_tips.csv`, an eased progress bar, fades, an empty background-picture slot) for START and ARENAS, and the black change for Quit to Title and CHANGE ARENA; a 1 s start grace for the player; the death screen now covers its first frame and holds black for 0.3 s **(done and tested by the user 2026-10-13)**

**Current state:** Steps 1 to 7, 9, and 10 are built and tested (Step 8, the clash, was dropped), plus the 2026-10-09 follow-ups (the sweep duck and the snappy jump; see the bullets after 7d), plus the 2026-10-08 follow-ups (attack phase speeds, the enemy bar as one entity with a row of life dots, the guard break; see the bullets after 7d). **7c-2 (the grab) is built and tested, so the whole of Step 7 is done.** The enemy guards, deflects, ripostes, poses, and uses perilous thrust, sweep, and grab; the `Dummy` is still a test target. You can lock onto the enemy or the dummy and switch between them. **Step 11 (polish) is under way: 11d (the boss-slain screen, the heal arm, the death-reload fix), 11c (camera shake and the `Fx` helper), and 11b (sparks and effects, the blood jet) are done. 11e (shockwaves), 11f (the swing trail), and 11g (the crouch vignette) are done. 11a (sound) is done too, so Step 11 and Phase 1 are complete; **Step 12, the cleanup refactor (12A to 12D), is done and tested (2026-10-12), so Phase 1 is complete.** Phase 1.5 is done (`docs/phase-1-5-plan.md`; item 8 is a deferral to Phase 2). What is left is **Phase 2** (`docs/phase-2-plan.md`: 1 the main menu (done 2026-10-12), 2 the pause menu (done 2026-10-12), 3 the arena chooser with a fall zone (3a the fall zone, 3b the chooser and 3c-1 the fighting arenas done 2026-10-12; 3c-2 the two movement arenas done 2026-10-13, which completes item 3), 4 the death and victory screens as scenes (done 2026-10-13), 5 the loading screens (done 2026-10-13); then the backlog in section 13).** Start a **new chat** for each phase and paste the files listed at the top of this handoff, plus a fresh snapshot (`python pack_for_claude.py`). Send a full check before building each phase.

### What the finished steps built (details: `docs/archive/build-log.md`; each script's header comment describes its behavior)

- **1 Movement and camera:** `player.gd` (the `CharacterBody3D` root), `camera_rig.gd` (`top_level`, spring arm), test arena as the main scene, Input Map for KBM and controller.
- **2a State machine:** `StateMachine` and `State` nodes under the Player; `ActionState` runs an `ActionData` clock (`action_time`, `speed_scale`) and reads its windows; `InputBuffer` (0.15 s, tracks jump, dodge, interact, attack); the dodge with i-frames and dash-hold; `DebugOverlay`. States never call `move_and_slide()`.
- **2b to 2d Traversal:** `CrouchState`, `SlideState` (an `ActionState`), `WallJumpState` and the mid-air reach (`ReachArms`, debug-grade), `LedgeClimbState` and `LedgeHangState` (`knock_off()` is the hook for Step 4). Rules in 3.9 and 3.10.
- **3a Ground combo and thrust:** `WeaponData` (the katana), `AttackState` (combo, chain, cancels, lunge with ledge stop, hold becomes the charged zigzag thrust), `SwordVisual` (the placeholder arm-swing sword: clock poses, edge-leading blade, body twist). Rules in the Step 3 spec.
- **3b Variants:** other states hand over through `AttackState.try_start_variant()`; dash, crouch and slide attacks, `AirAttackState` (the air loop), `HelmSplitterState` (hold in the air). Variants count as combo step 1; `ActionData.hold_action` names what a hold selects.
- **3c-1 Sheathing:** `Player.sheathed` (spawns true), R and D-pad Down (`sheathe`), auto-sheathe (`auto_sheathe_time`, 5 s, counted only in Locomotion or Crouch), the draw slash (`WeaponData.draw_attack`; `try_start_variant()` swaps it in while sheathed; it counts as no combo step), the dodge attack (`DodgeState`), and the `SwordVisual` scabbard, pin, stretching arm, and draw and sheathe animations.
- **4a Hits on a dummy:** `Hitbox` (Area3D under `SwordVisual`, moved to the hand every frame by `SwordVisual._apply()`) is swept each physics frame by `ActionState._update_hit()` while an ATTACK action with `damage` above 0 is inside `active_hit` (`AttackState` also requires phase NORMAL); one hit per `Hurtbox` per swing; damage = `action.damage` x `_hit_damage_multiplier()` (the charge multiplier). `ActionData.hitbox_length_scale` (1.5 on the helm splitters, draw slash, and charged iai) grows the box from the tip; `ActionData.hitstop` (0.06 s) feeds `Hitstop.request()` (whole-game slow scale 0.05, real-time timer) through `Player.on_hit_landed()`. Layers in `Layers` (1 world, 2 player hurtbox, 3 enemy hurtbox, 4 player hitbox, 5 enemy hitbox). `Hurtbox` passes hits to a sibling `Combatant` (HP, `damaged`/`died` signals) and ignores hits while dead or while its `is_invulnerable` Callable returns true. `scenes/enemy/dummy.tscn`: 500 HP, `EnemyBar` (red cut at once, yellow trail after 1 s, debug damage numbers at the top right), recoil wobble, vanishes at 0 and returns after 2 s.
- **4b Player hurtbox, taking damage, dummy attacks:** the player has a `Hurtbox` (team Player, own capsule) and a `Combatant` (`Player.max_health` 100), both found in the scene or created in code with a warning. `Player._update_hurtbox()` resizes the capsule every frame from a `HurtboxProfile` (stand 1.8/0, crouch 1.1/0, air 1.1/0.7; air = not on the floor and not on a ledge state; crouch = `is_crouched`, which includes slide); the body capsule is untouched. The hurtbox ignores hits while `Player.invulnerable`. On damage: `notify_combat()`, `Hitstop.request()` with the hit's hitstop, `LedgeHangState.knock_off()` if hanging, and a **hit wobble** (`Visual` shifted 0.15 m and tilted 0.2 rad away from the attacker, 0.25 s, exports `hit_recoil_*`; `get_facing_direction()` now uses yaw only so the tilt never changes aim). No stun yet (Step 6); at 0 HP the player refilled after `refill_delay` (a temporary stand-in, replaced by Step 10's death flow; the export is gone). The debug overlay shows HP and the hurtbox posture. The dummy swings an arm (`SwingPivot/Hitbox`, an ENEMY `Hitbox` swept through a 120 degree arc) when the player is within 2.6 m: high 1.5 m, low 0.15 m, mid 0.9 m in turn, wind-up 0.6 s (the red arm is the telegraph), 0.25 s active, damage 20; `Dummy.attack_mode` can fix one height or turn it off. A stand-in for the Step 7 enemy.
- **5 Guard and deflect:** `GuardState` (ground and air; forced walk via `Player.walk_only`; turns toward input) is entered by a fresh `guard` press (`InputBuffer` tracks it) from Locomotion, Crouch (stands you up if there is headroom), Air, Dash, and, through `ActionState._try_guard_cancel()`, from any action outside its hit window (not the ledge climb). The rules live in `Combatant`: `press_guard()` opens the deflect window (0.2 s, minus 0.04 s per rapid press, floor 0.05 s, full again at once when any other action starts, or after 1 s of neither guarding nor acting), and `take_hit()` decides HIT, GUARD, or DEFLECT from `guarding`, a 90 degree cone against `guard_facing`, and the hit's `guardable`/`deflectable` flags (`HitData`, copied from `ActionData`); a deflect or guard emits `hit_deflected` / `hit_guarded` (Step 6 hooks) and takes no damage. The window keeps running after the button is released (the state ends only when it has run out). Chip damage is off by default (`Combatant.chip_damage_enabled`, `chip_ratio` 0.15). `ActionData.knockback` (and `Dummy.attack_knockback`) pushes the player on every outcome, scaled by `Combatant.knockback_multiplier_hit/guard/deflect` (1.0, 1.0, 0.6); `Player.apply_knockback()` adds an easing push on top of the state's velocity. Guard from sheathed snaps the sword out into a guard-draw pose; `SwordVisual` also has the blade flick (`play_guard_hit`) and the white (deflect) or orange (guard) flash. `Player` creates a `Guard` state in code (with a warning) if the scene has none. The dummy has `attack_guardable`, `attack_deflectable`, and `attack_knockback` test exports. The debug overlay has a Guard line (next window size, press count, idle time toward the 1 s reset, open window, last result) and a white, outlined text; `Combatant.debug_log` (off by default; tick it in the Inspector when tuning) prints guard presses, spam resets, and outcomes to the Output panel.
- **6 Posture, deathblow, stagger:** `Combatant` owns posture (0 to 100, full = break; guard 100%, deflect 10% plus 50% on the attacker, unguarded hit 50% of `posture_damage`; regen 15/s after 1 s, paused while acting, slower at low HP, x2 after 3 s of guarding for the player), the health bars and the deathblow window (`deathblow_enabled`, `boss`; an empty bar or a posture break opens it, a missed one returns the enemy to 1 HP, a missed final bar of a non-boss kills), and the Defense multipliers (`health_taken_multiplier`, `posture_taken_multiplier`). Player: `StaggerState` (6 s, dodge locked 2 s, x1.5 damage taken) and `DeathblowState` (started by `Player._try_deathblow()`: `attack` near an enemy in group `enemy` with an open window; thrust visual drawn, iai visual sheathed). `ActionData.charge_posture_max` scales a charged attack's posture. The dummy has 2 bars (`health_bars`), freezes pale while stunned, and swings with posture damage 25; `EnemyBar` has pips, a posture bar, and the deathblow marker (look exports). Numbers are placeholders (about 1.5x damage for posture). Details: build log, "Step 6".
- **7a Enemy core:** `Enemy` (`scripts/enemy/enemy.gd`, scene `scenes/enemy/enemy.tscn`, a `CharacterBody3D` in group `enemy`) runs the loop IDLE, CHASE, ATTACK, RECOVER, YIELD, STUNNED from `EnemyAIData` (`ai/enemy_default.tres`: speeds, spacing, burst length, recovery, yield time, `aggression`, `damage_scale` 2.0, `posture_scale` 1.5, and the defense fields that 7b will read). Its attacks are the player's ground combo (`weapon.combo` of `katana.tres`) on its own `SwordVisual` and `Hitbox` (team set in code), chained at each action's cancel window; the wind-up is the telegraph. It uses `Combatant` (500 HP, 2 bars, posture, deathblow, set in the scene) and `EnemyBar`; a hit only plays a recoil wobble and never interrupts it. Defense came in 7b; no perilous attacks yet (7c). Details: build log, "Step 7a".
- **7b Enemy defense:** the enemy reads the player's attack and defends by situation (neutral or pressured after a landed hit), with data per enemy type in `ai/` presets (`enemy_soldier`, `enemy_duelist`, `enemy_aura`, `enemy_repulser`): a plain guard or a timed deflect (pressed on time, whatever the reaction delay), an optional repulse (`Combatant.repulsed`: the attacker is bounced and its swing cut, no stun, `Player._update_repulse`), flinch rules with 0.6 s immunity, a hit-streak guard, a riposte (with optional armor), a break-out after many guarded hits, and a recovery pose with the `Aura` node. It guards only in IDLE, CHASE and YIELD. Details and numbers: build log, "Step 7b".
- **7c-1 Perilous attacks:** `Enemy` has phases `PERILOUS` and `COUNTERED`. `_pick_perilous()` chooses thrust (the weapon's charged thrust: pull-back and orange glow are the telegraph) or sweep (`EnemyAIData.sweep_action` = `actions/enemy_sweep.tres`, the whole swing lowered by `SwordVisual.set_drop_target()`), from a chance after each yield (`perilous_chance`) or at a combo's chain points (`perilous_chain_chance`), with a cooldown, a range, and no more than `perilous_repeat_limit` repeats; `Enemy.debug_force_perilous` forces one. Both are unguardable and undeflectable with their own damage (`perilous_damage` 35, `perilous_posture` 40), and it has super armor until the hit window ends. `DangerSymbol` (a `Label3D` under the Player, group `danger_symbol`) shows red from `perilous_symbol_lead` (0.5 s) before the hit window until it closes. Counters are checked each frame while it shows: mikiri (`DodgeState`'s direction via `ActionState.get_move_direction()` within `mikiri_angle` 70 degrees and `mikiri_range`) and the jump-over (the player is not on the floor, which only arms the counter for `head_bounce_window`); the mikiri cuts the attack at once, adds posture, and stuns it (`COUNTERED`, no guard, no flinch; a posture break opens the deathblow instead), and the jump-over does the same when the player lands on that head (`Enemy.on_stomped()`, called by `Player._update_enemy_head()`, which also bounces the player up at `head_bounce_velocity` if it is in `AirState`); any other head landing slides the player off (`head_slide_speed`). The perilous thrust (not the sweep) is deflectable only within `perilous_deflect_window` (0.1 s) of the guard press (`HitData.deflect_within`, checked in `Combatant._resolve`); a normal guard does nothing against it. In `AirState` the player keeps its horizontal momentum and the move keys only steer it (`Player.apply_air_steering()`, `air_steer_acceleration`; the wall jump and air attacks keep their own movement). Looks: `EnemyAIData` blade scale, `blade_back_length` (a visible tail whose hitbox is part of the one damage box, `Hitbox.configure(length, back)`), and `blade_color` change an enemy's weapon on a copy of `WeaponData`. The enemy's bobblehead flinch pivots `Visual` at the feet (jump-over, a shorter one on mikiri, and a slow heavy sway with a drooping head while stunned for a deathblow). `EnemyBar` shows the health bars left as round red dots with a maroon outline in a strip at the bar's left end (a lost one is hidden). On a posture break the player also sinks to a knee and sways (`Player.set_stagger_kneel()`, visual only). Presets: `enemy_monk` (thrust and sweep, 70% chance, 3 s cooldown, spear look), `enemy_duelist` and `enemy_repulser` (thrust), the others none.
- **7d Deflect poses:** `SwordVisual.play_deflect(hit, side)` (called by `Player._guard_reaction` and `Enemy._guard_reaction` on a deflect, only while the sword is in `Anim.GUARD`, else the old flick) picks a `DeflectKind` (`_deflect_kind_for`): THRUST if the action has `charge_time > 0` or is `PERILOUS_THRUST`, else HIGH or LOW from the contact point's height against `deflect_high_above` / `deflect_low_below`, else SIDE (authored for an attacker on the right, mirrored for the left). The pose (hour/radius/forward plus blade and edge directions, all exports under "Deflect poses") is overlaid on the guard pose by `_apply_deflect_overlay()`: snap `deflect_snap_time`, hold, ease back; the aim turns `deflect_aim_follow` toward `hit.point`; a new guard press, a new action, or `play_guard` cancels it. `debug_force_deflect` shows one kind on every deflect. The perilous thrust sets `HitData.knockback` from `EnemyAIData.perilous_thrust_knockback` (3.0 m) with `HitData.knockback_time` (`perilous_knockback_time` 0.4 s, -1 = the target's default); `Player.apply_knockback(direction, distance, time)` takes the optional time, and a deflect pushes `knockback_multiplier_deflect` (0.6) of it.
- **Deflect spam rule (after 7d):** `Combatant.press_guard()` shrinks the window by `deflect_shrink` only if `_next_press_shrinks()`: a tap under `deflect_rapid_interval` (0.35 s) after the last press, or `press_count >= deflect_free_presses` (3); `shrink_steps` counts the steps. The run resets (`_reset_spam`) on acting, 1 s idle without guarding, `deflect_hold_reset_time` (3 s) of holding since the last press, a deflect, and an unguarded hit; a plain guard does not reset it. The three thrust actions (`thrust`, `dash_thrust`, `deathblow_thrust`) now aim down the center line (windup `(12, 0.1, -0.4)`, end `(12, 0.1, 1.3)`, no body twist).
- **Attack phase speeds (after 7d, done and tested by the user 2026-10-08):** the attack clock runs slower inside a slash's hit window. Player: `Player.slash_active_speed` (0.7) via `ActionState._active_speed_factor()`; `_slows_active_window()` is false for the charged thrust, `HelmSplitterState`, and `DeathblowState` (the charged iai and every other slash are slowed); the wind-up is unchanged, so the enemy's `time_to_hit` guess needs no change. Enemy: `EnemyAIData.windup_speed` (0.65) and `active_speed` (0.7), read by `Enemy._attack_speed()` for the combo attacks only (not the perilous ones). A slash is longer by duration x (1/speed - 1); cancel and buffer windows open later in real time. Numbers are placeholders.
- **Enemy bar as one entity (after the phase speeds, done and tested by the user 2026-10-08; the life dots then moved into a spaced row above the bar's left end, `pip_gap` 0.06, `pip_lift` 0.03, no dark strip):** the enemy's `Bar` node is a child of `Visual` (so it follows the flinch, bobble, and sway; `enemy.gd` reads `$Visual/Bar`; still 2.3 m up). `EnemyBar` lays the pip strip, the pips, and the posture bar out with `QuadMesh.center_offset` (camera-facing) instead of node positions, so they stay attached whatever the enemy's yaw or the camera angle. The dummy's bar gets the same fix.
- **Guard break (after the enemy bar, done and tested by the user 2026-10-08):** `HitData.perilous` (set by `Enemy` on its perilous hits). In `Combatant.take_hit()`, a plain hit with `guarding`, `perilous`, and the attacker inside the guard cone emits `guard_broken(hit)` (after `damaged`; damage and knockback are the plain hit's). `Player._on_guard_broken()`: heavier wobble (`guard_break_recoil_scale` 1.6), leaves `GuardState` for Locomotion or Air, optional guard-press lockout (`guard_break_lockout`, 0 = none), and `SwordVisual.play_guard_break(side)` (exports under \"Guard break\": the blade is knocked aside, snap, hold, ease back, red flash, laid over the return to rest). A deflect, a dodge, or a hit from behind does not break the guard. Numbers are placeholders.
- **7c-2 The grab (done and tested by the user 2026-10-08):** `Peril.GRAB` runs through the same perilous path as the sweep: `EnemyAIData` group "Grab (Step 7c-2)" (`perilous_grab`, `grab_action` defaulting to `actions/enemy_grab.tres` so `Debug Force Perilous = Grab` works on every preset, `grab_range` 2.4, `grab_damage` 45, `grab_posture` 0, `grab_knockback` 2.0, `grab_whiff_recovery` 1.2, `grab_symbol_color` yellow). `Enemy._update_hit()` gives its hit `HitData.perilous` and `HitData.grab` (unguardable, undeflectable); `_grab_connected` is false when a dodge's i-frames made it whiff, which gives the longer recovery. `Combatant.take_hit()` emits `guard_broken` for any grab hit (guarding or not); `Player._on_guard_broken()` then plays the guard-break pose and, on the ground, a cosmetic kneel (`Player.grab_kneel_time` 0.8, `set_stagger_kneel`, ended by a jump, a fall, or any action; no change to the capsules or hurtbox). New preset `ai/enemy_grappler.tres` (grab at 70%). Only a dodge counters it. The high/mid/low enemy hitboxes were dropped on purpose: real animations will set the hit height. Placeholder poses and numbers.
- **Jump tuning (after 4b, reworked 2026-10-09):** the jump is about 2.46 m high (it reaches an enemy's head) in about 0.88 s, with no hang at the peak: `Player.jump_velocity` 9.88, `gravity_multiplier` 2.0, `fall_gravity_factor` 1.5, and an apex band (`apex_speed_band` 2 m/s, `apex_gravity_factor` 1.5). `Player.get_gravity_now()` is the base gravity times that phase factor; `apply_gravity()`, the helm splitter's dive (`dive_gravity_factor` 2.5) and the opening hover (`opening_gravity_factor` 0.25), and the air attack's hold gravity all use it. `head_bounce_velocity` is 7.6 (1.44 m). Wall jumps scale with `jump_velocity` (up = `jump_velocity` x `wall_jump_boost`). Earlier versions: 7.0 / 2.0 (1.25 m); 8.5 / 1.5 (2.46 m, about 1.2 s); real gravity 9.8 (floaty, dropped). `test_arena.tscn`: the tops of LowPlatform, TightPlatform, HighPlatform, Pillar, Wall, Wall2, and Gap were raised to 2x their height above the floor (floor top y 0.25); horizontal spacing unchanged.
- **3c-2 Charged iai and sheathed helm splitter:** the draw slash's `hold_action` is `draw_attack_charged.tres` (charge 0.6 s, x1.5 damage and x1.4 lunge stored for Step 4); `AttackState` charges it with `SwordVisual.update_charge_iai()` (blade half drawn, glow), never mirrored, standing you up when it fires from a crouch or slide. In the air, `AirAttackState` starts `HelmSplitterState` with `WeaponData.draw_helm_action` (`helm_splitter_draw.tres`, a 0.4 s raise); gravity is halved (`HelmSplitterState.opening_gravity_factor`) while holding in the draw wind-up and through the raise, then the usual dive. `_thrust_mirror` now resets on every new action.
- **9 Lock-on (done and tested 2026-10-09):** `LockOn` (`scripts/player/lock_on.gd`, a `Node3D` child of `Player`) picks the living enemy nearest the screen center (50 degree cone, 20 m, clear line), releases on a second press, 25 m, 2 s without a line, or the target's death (then `auto_lock_next` locks the nearest one), and switches on a mouse or right-stick flick. `CameraRig` frames the target (`lock_height_bonus` 0.8, `lock_pitch_down_degrees` 10) and the mouse becomes the flick; `Player.face_input()`, the dodge, the slide, and the attack lunge face or aim at the target (`Player.get_lock_direction()`). Toggles on `LockOn`: `recenter_when_no_target` (off) and `auto_lock_next` (on). `Enemy` and `Dummy` have `lock_point_height` (1.2). Needs a `LockOn` node under `Player` in the scene.
- **10 Heal, death, HUD (done and tested 2026-10-09):** `HealState` (`Player._try_heal()` starts it from Locomotion, Crouch, or Dash on `heal`; 1.0 s at walk speed, restores `Player.heal_amount` 40 on completion and spends the charge only then; a damaging hit interrupts it, dodge/jump/attack/guard cancel it free; refuses at full HP unless `allow_heal_at_full_health`). `Combatant.heal()` and `revive()`. Health 0 sets a pending flag (`Player._update_death()`, waits out a ledge climb) and enters `DeadState`: body lies down (stagger lean and kneel, no sway), lock-on released and locked out (`LockOn.locked_out`, the locked enemy kept in `Player.relock_target`), prompt after 1.0 s: **attack = Resurrect, guard = Die** (fresh presses only); with no resurrection left it auto-dies after 3 s. `Player.resurrect()`: `resurrect_health_fraction` 0.5, posture 0, `resurrect_invulnerable_time` 2 s; `LockOn.lock_onto()` re-locks the same enemy; `Enemy` and `Dummy` stand down while the player is dead (`Enemy._stand_down()` cuts swings, guard, and pose; `_stand_down_ended()` starts a YIELD). Die: `death_confirmed` fades to black, then `reload_current_scene()` (charges and resurrections reset with it). Player signals `death_started`, `death_prompt_shown`, `death_confirmed`, `resurrected` feed `DeathScreen` (darken 0.35, a red vignette shader, 死 and D E A T H, the two prompts; the scene starts black and fades in). `PlayerHud` (CanvasLayer, drawn in code, polls the Player): health bar, resurrection pips above it, the gourd and charge count below it, and the posture bar bottom-center. `EnemyBar` posture bars (enemy and player share the look via `EnemyBar.posture_gradient`): grow from the middle out, yellow to reddish orange, pop to red with a flash at a break, then drain. `DebugOverlay.show_debug_text` (off) hides the top-left text; the 3D debug aids stay. Nodes: `Heal` and `Dead` under `StateMachine`, `PlayerHud` and `DeathScreen` CanvasLayers under Player. Placeholders: the lie-down pose, no heal or death animation, no sound.
- **11d Boss-slain screen, heal arm, fix (done and tested 2026-10-09):** `VictoryScreen` (`scripts/ui/victory_screen.gd`, a CanvasLayer under Player, group `victory_screen`) is called by `Enemy._on_died()` when `Enemy.boss`; text from `EnemyAIData.victory_kanji` (討取) and `victory_text` (ENEMY SLAIN); hitstop, slow motion, flash, dim and desaturate, the banner fades in and out, no reload; `death_started` cancels it. `HealArm` (`scripts/player/heal_arm.gd`, a Node3D under `Visual`, `Player.heal_arm`) lifts a placeholder gourd with the left arm, driven by `HealState`'s clock (`begin`, `set_progress`, `end`). `Player._physics_process` returns early when the scene reloads under it (the 12 red errors), and the four death signals ignore the unused-signal warning. Needs nodes `VictoryScreen` (Player) and `HealArm` (Visual). Details: build log, "Step 11d".
- **11c Shake and 11b Effects (2026-10-09):** `Fx` (`scripts/combat/fx.gd`, static): `Fx.play(tree, kind, point, direction, attach)` is the one call per event and does the camera trauma (`CameraRig.add_trauma`, group `camera_rig`, trauma squared, real-time decay, kick along the blow) and the effect (runtime `CPUParticles3D` sparks, puffs, motes and tweened rings; the deathblow has a 2 s blood jet that follows the enemy). Hooks are in `Player`, `Enemy`, `Dummy`, `HelmSplitterState`, `HealState`, `SlideState`, `VictoryScreen`. `Player.show_blood`, `hard_land_speed`, `land_dust_speed`; `CameraRig` exports under "Shake (Step 11c)". No scenes or nodes were added. Details: build log, "Step 11c and 11b".
- **11e Shockwaves and 11f Swing trail (2026-10-09):** `Shockwave` (`scripts/combat/shockwave.gd`, static): `ground()` (rings and dust, called by `HelmSplitterState._begin_land()`) and `arc()` (a crescent, called by `AttackState._on_hit_window_opened()` for the charged iai). `Hitbox.begin_swing(scale, show_extension)` draws the glowing blade extension for states whose `_shows_extension()` is true (the helm splitter); `get_reach()` and `get_blade_length()` give the real numbers. The swing trail is a ribbon in `Hitbox` (`trail_time`, `trail_base_fraction`, `trail_color`), switched by `SwordVisual.swing_trail`. All visual only; no scenes or nodes added. Details: build log, "Step 11e and 11f".
- **11g Crouch vignette (2026-10-09):** `CrouchVignette` (`scripts/ui/crouch_vignette.gd`, a CanvasLayer under Player, layer 5): a subtle black edge vignette (corner strength 0.25, eased 0.25 s in and out) while `Player.is_crouched` (the slide too). Needs the node `CrouchVignette` under Player. Details: build log, "Step 11g".
- **11a Sound (done and tested 2026-10-09):** `Sfx` (`scripts/audio/sfx.gd`, static, no autoload): `Sfx.play(tree, Sfx.Id.X)` for sounds with no place and `Sfx.play_at(tree, id, point)` for world sounds (an `AudioStreamPlayer` or `AudioStreamPlayer3D` added to the current scene, freed when done). The table is `audio/sfx_data.tres` (`SfxData` with one `SfxSlot` per `Sfx.Id`, matched by lowercase name: wavs as variants, never the same twice in a row, volume, pitch range, and a cut-off `group` so a new sound of the group replaces the old one). Most events go through `Fx.play()` (`Fx._sound()`); the rest are one-line calls in the states. Swings come from `ActionState._update_hit()` when the hit window opens (`Sfx.swing_id(action)`: `blade_aims_at_end` = thrust; the animations draw_attack, draw_attack_charged, helm_splitter and helm_splitter_draw = swing_super; attack_1 to 3 = swing, attack_4 and 5 = swing_alt; any other slash picks swing_alt at `SfxData.swing_alt_chance` 0.25); the enemy does the same from `Enemy._update_hit()` (the grab is silent). Footsteps: `Player._update_footsteps()` (a step every `step_distance_walk/run/crouch` metres, in the walking states only). Silent slots, no wav yet: `charge_loop`, `aura_loop`, `heal_drink`, `guard_raise`, `land_soft`; `deathblow_open` has wavs but `SfxData.deathblow_open_enabled` is off. Audio folders are under `audio/` (the unused wavs from the sound pack, such as the slow sheathes, the surface footsteps, and swingH/L, were not copied). Details: build log, "Step 11a".
- **Personal space (2026-10-09):** `Player._update_personal_space()` eases the player away from any living enemy or dummy closer than `personal_space_distance` (2.0 m flat, center to center; the bodies touch at 0.8) at up to `personal_space_push_speed` (4 m/s) through `move_and_collide`; skipped when more than 1 m above or below the enemy, during the deathblow, on ledges, and while dead. Exports under "Personal space" (`personal_space_enabled`). No capsule, hurtbox, or AI change.
- **Sweep duck (2026-10-09):** the enemy's body ducks and leans forward during its perilous sweep (`Enemy._update_crouch()`, `EnemyAIData.sweep_crouch_drop` 0.35, `sweep_crouch_lean_degrees` 25, `sweep_crouch_out_time` 0.35). Visual only: the capsule, the hurtbox, and the head-bounce landing point do not follow.
- **Phase 2, item 1 Main menu (done and tested 2026-10-12):** `MainMenu` (`scripts/ui/main_menu.gd`, scene `scenes/ui/main_menu.tscn`, the project's main scene) runs the phases INTRO (fade in from black, the music starts), TITLE ("PRESS ANY BUTTON" pulses; any key, mouse button or gamepad button, not motion or sticks), ENTRIES (START, OPTIONS, QUIT; up and down wrap; mouse hover moves focus), OPTIONS (an empty placeholder panel; Back or `ui_cancel` returns) and LEAVING (fade to black and music fade, then `change_scene_to_file(DEFAULT_ARENA)` or quit). `DEFAULT_ARENA` is one constant (`test_arena.tscn`, a placeholder). The look is the shared `resources/ui_theme.tres` (type variations `TitleLabel`, `SubtitleLabel`, `KanjiLabel`, `PressLabel`, `FooterLabel`, `PanelHeading`, `PanelText`, `EntryButton`, `OptionsPanel`; fonts are system fonts: Palatino Linotype, Book Antiqua, Georgia for Latin, Yu Mincho for the kanji); font sizes and letter spacing are written in the Theme for a 1080 px high window and the script scales them with `size.y / 1080`. The selection highlight is a radial `GradientTexture2D` in the `EntryButton` focus style only (so hover plus focus never doubles it), soft on all four sides. Texts and the kanji are the Label nodes' own text; the version comes from `application/config/version`. Sounds: `Sfx.Id.MENU_MOVE`, `MENU_OK`, `MENU_BACK` (the wavs `select`, `ok`, `back`); the music is an `AudioStreamPlayer` named `Music` whose stream (`audio/music/main_menu.ogg`, looped in the Import dock) is set in the editor. The mouse is visible in the menu; the arena's camera rig captures it on load. Details: build log, "Phase 2 item 1".
- **Phase 2, item 2 Pause menu (done and tested 2026-10-12):** `PauseMenu` (`scripts/ui/pause_menu.gd`, scene `scenes/ui/pause_menu.tscn`, a `CanvasLayer` at layer 30 with process mode Always, instanced as the last child of the Player so every arena has it). The `pause` action (Esc, gamepad Start; `Actions.PAUSE`) is read in `_input` and consumed, so the camera rig's old "Esc frees the mouse" no longer fires; the gamepad's Cancel (`ui_cancel`) comes through `_unhandled_input`. Opening sets `SceneTree.paused`, shows the mouse (the previous mouse mode is restored on resume) and a 65 percent dim over the frozen arena; entries RESUME, OPTIONS (its own copy of the empty panel; Esc or Back closes the panel first, then Esc resumes) and QUIT TO TITLE (a 0.4 s fade, unpause, `Engine.time_scale = 1`, `change_scene_to_file(main_menu.tscn)`; no confirmation until saves exist). It refuses to open while the player is dead (`combatant.dead` or `DeadState`), while `VictoryScreen.is_active()` (that screen runs on wall-clock time), and while `Engine.time_scale` is not 1 (hitstop, slow motion). `Sfx.play_ui()` plays menu sounds on voices set to Always, because normal voices freeze with the tree. Text sizes (entries 28, PAUSED 22) are font-size overrides on the nodes in the scene; `UiTextScaler` (`scripts/ui/ui_text_scaler.gd`) scales them and the letter spacing with `size.y / 1080` (the main menu still has its own copy of this). Look: `ui_theme.tres`, unchanged. Details: build log, "Phase 2 item 2".
- **Phase 2, item 3a Fall zone (done and tested 2026-10-12):** `FallZone` (`scripts/combat/fall_zone.gd`, an `Area3D` placed under each arena; `damage_fraction` 0.25) calls `Player.begin_fall_respawn()` each physics frame the Player is inside it (enemies ignored; it triggers after a deathblow or death ends if still inside). The Player loses that share of max health through the new `Combatant.take_flat_damage(amount, can_kill)` (not a hit: no wobble or hitstop; never below 1 HP), plays the hurt sound, is locked and frozen (the `_update_fall_respawn()` gate in `_physics_process` skips the rest of the frame), and `ScreenFade` (`scripts/ui/screen_fade.gd`, a `CanvasLayer` at layer 25 under Player, reusable for checkpoints) fades to black over `fall_fade_out` 0.35 s. Under black `_teleport_to_spawn()` returns it to the position and facing recorded in `_ready()` (velocity, knockback and input buffer cleared, state `Locomotion`) and `CameraRig.snap_to_target()` puts the camera there at once; then `fall_fade_in` 0.35 s and `fall_invulnerable_time` 1.0 s (the resurrection's `_revive_invulnerable_left`). Nothing happens while dead or in a deathblow. Needs the node `ScreenFade` under Player and a `FallZone` (with a big flat `BoxShape3D`, mask layer 1) in each arena. Details: build log, "Phase 2 item 3a".
- **Phase 2, item 3b ArenaData and the chooser (done and tested 2026-10-12):** `ArenaData` (`resources/arena_data.gd`: name, `scene_path`, image, description, category, `debug_only`, `sort_order`) is one `.tres` per arena in `res://arenas/`; `ArenaLibrary` (`scripts/ui/arena_library.gd`, static) lists them (a debug build all, a release build only the non-`debug_only` ones; it handles the `.remap` suffix of exported builds). `ArenaChooser` (`scripts/ui/arena_chooser.gd`, scene `scenes/ui/arena_chooser.tscn`) is one scene instanced by both menus: a list under category headings and a detail panel, signals `arena_chosen` and `closed`, and the hosts do the fade and the loading. Main menu: START, ARENAS (shown only if an arena is listed), OPTIONS, QUIT. Pause menu: RESUME, CHANGE ARENA (debug builds only), OPTIONS, QUIT TO TITLE; Esc closes the chooser first. START still loads `DEFAULT_ARENA`. Only `arenas/test_arena.tres` exists until 3c. Details: build log, "Phase 2 item 3b".
- **Phase 2, item 3c-1 Fighting arenas and invisible walls (done and tested 2026-10-12):** `fighting_arena.tscn` (30 x 30 m floor, four 40 m tall invisible walls, a `FallZone`, the Player at one end; no enemy) and eight inherited scenes that each add their own enemy: `fighting_dummy`, `fighting_soldier`, `fighting_duelist`, `fighting_aura`, `fighting_repulser`, `fighting_monk`, `fighting_grappler` (one boss each) and `fighting_squad` (3 non-boss soldiers and a boss monk). Each has an `ArenaData` in `arenas/` (FIGHTING, `debug_only` on). **Invisible walls** are `StaticBody3D`s on physics layer 6 (`Layers.INVISIBLE_WALL` = 32): solid only for bodies whose collision mask has layer 6 (the Player and Enemy roots, mask 33), invisible to the camera's spring arm, and skipped by `LedgeSensor` (`_world_mask()`), so no spring, no wall jump and no ledge grab on them. An enemy, boss or not, comes back `respawn_delay` (2 s) after it dies. Details: build log, "Phase 2 item 3c-1".
- **Phase 2, item 3c-1 addendum Boss HUD (done and tested 2026-10-13):** `BossHud` (`scripts/ui/boss_hud.gd`, a code-drawn `CanvasLayer` at layer 9 under Player) shows, once a boss has noticed the player (`Enemy.is_boss_engaged()`: `boss`, alive, out of IDLE; `Dummy`: within `boss_ui_range` 14 m), the boss's round life dots, red health bar with the yellow trail and name at the top left and its posture bar (with chevrons) at the top center, while `EnemyBar.set_bars_hidden()` hides the floating bars (the deathblow marker stays). Bosses are found through `Enemies.all()` by duck typing (`is_boss_engaged`, `get_boss_name`, `set_boss_hud_shown`); `Enemy.display_name` and `Dummy.display_name` give the name. One boss owns it: the first to notice; it passes to another only when one swing hits that boss alone (not the owner, not several at once), with a 1 s pause after a switch; it also passes on when the owner dies or loses the player. A ninth arena, `fighting_duo` ("Two Bosses", a boss duelist and a boss monk), tests it. Needs the node `BossHud` under Player. Details: build log, "Phase 2 item 3c-1 addendum".
- **Phase 2, item 3c-2 Movement arenas (done and tested 2026-10-13):** `movement_yard.tscn` (one station per move: hurdles 0.3 to 2.0 m, gaps 1.5 to 5.5 m, a wall-jump shaft, a 1.3 m low tunnel, ledge walls and a 10 m shimmy face, slopes at 10, 25 and 40 degrees, stairs with an invisible smooth ramp and the same steps raw) and `movement_gauntlet.tscn` (the moves chained over a void, a last 7 m gap that needs a dash jump, a glowing finish pad that does nothing yet); no enemies, no invisible walls, a fall returns to that arena's start pad; each has a `Label3D` sign per station and an `ArenaData` in `arenas/` (MOVEMENT, `debug_only` on). Also: `CameraRig` lowers its pivot by `crouch_height_drop` (0.5 m) while `Player.is_crouched`, and the chooser rows use the body font at 24 with `heading_gap` 28 above each heading. Details: build log, "Phase 2 item 3c-2".
- **Phase 2, item 4 Death and victory screens as scenes (done and tested 2026-10-13):** `scenes/ui/death_screen.tscn` (layer 20) and `scenes/ui/victory_screen.tscn` (layer 19) replace the code-drawn screens; the class names and scripts (`scripts/ui/death_screen.gd`, `victory_screen.gd`) stay, and the Player instances the scenes as children named `DeathScreen` and `VictoryScreen`. The scenes hold the look (texts, colors, font sizes, anchors, the Theme's `KanjiLabel` font for the kanji, and the death vignette's color, inner, outer and pulse as parameters of its material); the shaders are `shaders/death_vignette.gdshader` and `shaders/victory_screen.gdshader`. The scripts keep the behavior and every timing, strength and slow-motion export, fade the labels with `modulate.a`, and scale the text with the window height (`UiTextScaler` on the death screen, their own code on the victory screen). The death screen's English text uses the Theme's serif; `ENEMY SLAIN` keeps Mincho. `PlayerHud`, `BossHud`, `EnemyBar`, `DangerSymbol`, `DebugOverlay` and `CrouchVignette` are unchanged. This supersedes the "drawn in code" descriptions of both screens in the Step 10 and 11d bullets above. Details: build log, "Phase 2 item 4".
- **Phase 2, item 5 Loading screens (done and tested 2026-10-13):** `SceneLoader` (`scripts/ui/scene_loader.gd`, static): `go(tree, path, Kind.PROPER or Kind.BLACK)`. BLACK is a plain `change_scene_to_file` after the caller's fade (the pause menu's Quit to Title and CHANGE ARENA); PROPER opens `scenes/ui/loading_screen.tscn` (`LoadingScreen`, `scripts/ui/loading_screen.gd`), which fades in, loads the target with `ResourceLoader.load_threaded_request`, shows a tip and an eased gold bar, waits for the load and `min_time` (2.5 s), fades to black and calls `change_scene_to_packed` (the main menu's START and ARENAS; a failed load returns to the main menu). The arena is inert data until that call, so nothing runs behind the screen. Tips: `data/loading_tips.csv` (`id, context, title, text`; `context` is `any` or `fighting`, `movement`, `test`; read by `LoadingTips`, shuffled with no repeats; a new tip every 8 s or on `ui_accept` or a click; the CSV is imported as "Keep File" and needs `*.csv` in the export filter before a release). `LoadingScreen.backgrounds` (empty) takes pictures that cross-fade and zoom slowly. `Player.start_invulnerable_time` (1.0 s, 0 = off) is invulnerability from every scene start; `DeathScreen` covers its first frame and `start_hold_time` (0.3 s) holds black. Project setting: Default Clear Color is black. Details: build log, "Phase 2 item 5".

---

## 11. Conventions

- Typed GDScript throughout (`var x: float`, typed function signatures). Type loop variables when they feed a `:=` line (`for side: float in [-1.0, 1.0]`), or inference fails.
- `@export` and custom `Resource` classes for tunable data.
- Signals for events between components; autoload only when truly global.
- Input checked by **action name** only.
- State names come from the `StateName` constants (`StateName.AIR`), never typed as strings. A state looks up another with `machine.get_state(StateName.ATTACK) as AttackState`.
- Wall and ledge sensing goes through `player.ledge_sensor` (`LedgeSensor`), not through `Player`.
- "All the enemies" comes from `Enemies.all()` (read-only, dead ones included), not from a group search; a new enemy type registers with `Enemies.register(self)` in `_ready()` and `Enemies.unregister(self)` in `_exit_tree()`.
- Input actions come from the `Actions` constants (`Actions.ATTACK`), never typed as strings (`InputBuffer.has_pressed(&"atack")` would just return false forever); built-in `ui_*` actions stay as strings.
- Group names come from the `Groups` constants (`Groups.ENEMY`), never typed as strings (a typo in a string finds nothing and fails silently).
- Running an `ActionData` (clock, hit window, swing, hit data, movement fade) goes through `ActionRunner`, for the player and the enemy alike. A new enemy type reuses it.
- Scene changes go through `SceneLoader.go(tree, path, Kind)` (PROPER for a loading screen with tips, BLACK for the plain change after a fade), not a bare `change_scene_to_file`; the death reload (`reload_current_scene`) is the exception.
- Timings in **seconds**, never frames.
- **Never scale a `CollisionShape3D` node.** Set sizes on the shape resource itself (radius, height, size).
- The player scene root is the `CharacterBody3D` itself (no wrapper node).
- **No "create it in code if the scene lacks it" fallbacks for nodes.** New code expects its nodes to exist (list them as editor steps; a missing node is an error to see, not to hide).
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
- [ ] Heal and death extras (not built): real heal and death animations, a low-HP warning vignette, status effect icons in a row beside the gourd, item and prosthetic icons, controller or keyboard button icons on the prompts, checkpoints and gourd upgrades
- [ ] Lock-on extras (not built): a HUD (names, health), camera shake or zoom, the enemy reacting to being locked, different facing for walking and running
- [ ] Sweep duck: a lower hurtbox and capsule, and a head-bounce landing point that follows the visual head (when real models arrive)
- [ ] Enemy awareness system (sight cone, noise; states unaware, suspicious, alert, combat)
- [ ] Stealth deathblow from crouch (behind an unaware enemy, within ~2 m, removes one health bar)
- [ ] Enemy variety (jumpers/chasers, ranged rock throwers) as data flags in `EnemyAIData`
- [ ] Generic interact system (doors, chests, NPCs; nearest-in-front priority, on-screen prompt)
- [ ] Sound extras (not built): wire `charge_loop` and `aura_loop` (needs a start and a stop call) and find wavs for `guard_raise`, `land_soft`, `heal_drink`; footsteps per surface (the grass, soil, and stone wavs exist); swingH/L and the slow sheathe for variety; the deathblow_opening sounds once the real animation exists (`deathblow_open_enabled`); enemy voice lines; music and ambience; per-slot tuning of the mix

- [ ] **Cleanup refactor: moved into Phase 1 as Step 12 (section 8 and 10; design in 3.13 of `docs/design-later-steps.md`).** The original note: move wall and ledge sensing out of `player.gd`, replace hard-coded state name strings with constants, give the states a shared base (not typed to `Player`) so the enemy can reuse `ActionState` and the `Combatant` rules
- [ ] **Cleanup (Step 5 leftover): this was 12A (done and tested 2026-10-12).** `Player._ready()` and `_setup_hurtbox()` create a missing `Guard` state, `Hurtbox`, or `Combatant` in code (with a warning). The scene has all three now, so remove those fallbacks (they run once at startup and cost no FPS; this is only clutter)
- [x] ~~Swing trail~~ built in Step 11f (the original note: swing trail / smear effect for sword swings (a ribbon that follows the blade tip during the active window and fades; none exists yet; fits Step 11 polish or real animation VFX))
- [ ] More enemy body feedback beyond the bobblehead (a head snap on each landed hit, a slump in its recovery, breathing in the recovery pose, a coil while it charges the thrust); the player's posture-break kneel could also move a little instead of staying planted
- [ ] Real animation integration (Blender, glTF, `AnimationPlayer` following the action clock); notes in section 8 of `docs/step3-combat-spec.md`