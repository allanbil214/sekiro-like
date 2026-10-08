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
7. Enemy AI, in three parts:
   - **7a** enemy core: movement, spacing, attack bursts with the player's ground combo. **(done)**
   - **7b** guard, deflect, repulse, flinch, riposte, recovery pose, adaptive guard chance. **(done)**
   - **7c** perilous attacks. **7c-1** the framework, danger symbol, thrust with mikiri, sweep with jump-over, the `monk` preset, combos continuing into a perilous attack, head bounce and slide. **(done)** **7c-2** the grab (open question O5) and high/mid/low enemy hitboxes so ducking matters. **(not built yet)**
   - **7d** varied deflect animations (side, high, low, thrust), shared by the player and the enemy, plus the perilous thrust's knockback. **(built; shipped but not yet tested)**
8. Clash mechanic.
9. Lock-on.
10. Heal and resurrection (prompt, final death, scene reset).
11. Polish: sound, sparks, camera shake.

*Note: traversal (2b-2d) comes before combat by the user's choice, which delays the combat loop. Move it later if scope becomes a problem.*

---

## 9. Open questions

The unresolved ones (O1, O2, O4, O5, all about later steps; O3 was settled in Step 5) are in `docs/design-later-steps.md`. Resolved ones are in the build log, Part 4. Ask the user before assuming.

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
- [x] 4a. Hitbox, hurtbox, `Combatant` (HP), dummy with a floating Sekiro-style bar, hitstop (see the build log, "Step 4a") **(done and tested by the user 2026-10-07)**
- [x] 4b. Player hurtbox profiles (stand/crouch/air), the dummy swinging (high/mid/low), the player taking damage with a hit wobble, duck-under and jump-over whiffs (see the build log, "Step 4b") **(done and tested by the user 2026-10-07)**
- [x] 5. Guard, deflect, shrinking window, jump versions, knockback (see the build log, "Step 5") **(done and tested by the user 2026-10-07)**
- [x] 6. Posture, posture break, deathblow, player stagger, charged posture, defense multipliers, deathblow marker (see the build log, "Step 6") **(done and tested by the user 2026-10-07)**
- [x] 7a. Enemy core: `Enemy` scene, chase/spacing/yield loop, bursts of the player's ground combo, `EnemyAIData`, visual recoil (see the build log, "Step 7a") **(done and tested by the user 2026-10-07)**
- [x] 7b. Enemy defense: guard, deflect, repulse, flinch, riposte, recovery pose, four `ai/` presets (see the build log, "Step 7b") **(done and tested by the user 2026-10-08, including the later pressure update: armored riposte, break-out, per-preset tempo)**
- [x] 7c-1. Perilous framework, danger symbol, thrust with mikiri, sweep with jump-over, the `monk` preset (spear look), `Debug Force Perilous` (see the build log, \"Step 7c-1\") **(done and tested by the user 2026-10-08, including the first follow-up batch: combos continuing into a perilous attack, the head slide, the bobblehead flinch, round red health dots inside the bar, the player's kneel and sway; and the second follow-up batch: the jump-over counter fires when the player lands on the head, air steering with kept momentum, a tight deflect of the perilous thrust)**
- [ ] 7c-2. The grab (yellow symbol, unguardable, dodge counter; answers O5) and enemy hitboxes placed high/mid/low so ducking matters **(NOT built yet)**
- [x] 7d. Varied deflect animations: four kinds (side, mirrored for the left; high; low; the thrust's slap) picked from the incoming attack, aimed partly at the contact point, shared by the player and the enemy; a plain guard keeps its flick; plus the perilous thrust's knockback (3.0 m, 0.4 s ease; a deflect pushes 0.6 of it) **(shipped, NOT yet tested; poses are guesses to tune with `SwordVisual.debug_force_deflect`)**
- [ ] 8. Clash
- [ ] 9. Lock-on
- [ ] 10. Heal and resurrection
- [ ] 11. Polish

**Current state:** Steps 1 to 6, 7a, 7b and 7c-1 (with its follow-ups) are built and tested; 7d (varied deflect animations and the perilous thrust knockback) is built but untested. **7c-2 (the grab) is NOT built yet; the user decides which is next.** The enemy guards, deflects, ripostes, poses, and uses perilous thrust and sweep (no grab yet); the `Dummy` is still a test target. Start a **new chat** for each phase and paste the files listed at the top of this handoff, plus a fresh snapshot (`python pack_for_claude.py`). Send a full check before building each phase.

### What the finished steps built (details: `docs/archive/build-log.md`; each script's header comment describes its behavior)

- **1 Movement and camera:** `player.gd` (the `CharacterBody3D` root), `camera_rig.gd` (`top_level`, spring arm), test arena as the main scene, Input Map for KBM and controller.
- **2a State machine:** `StateMachine` and `State` nodes under the Player; `ActionState` runs an `ActionData` clock (`action_time`, `speed_scale`) and reads its windows; `InputBuffer` (0.15 s, tracks jump, dodge, interact, attack); the dodge with i-frames and dash-hold; `DebugOverlay`. States never call `move_and_slide()`.
- **2b to 2d Traversal:** `CrouchState`, `SlideState` (an `ActionState`), `WallJumpState` and the mid-air reach (`ReachArms`, debug-grade), `LedgeClimbState` and `LedgeHangState` (`knock_off()` is the hook for Step 4). Rules in 3.9 and 3.10.
- **3a Ground combo and thrust:** `WeaponData` (the katana), `AttackState` (combo, chain, cancels, lunge with ledge stop, hold becomes the charged zigzag thrust), `SwordVisual` (the placeholder arm-swing sword: clock poses, edge-leading blade, body twist). Rules in the Step 3 spec.
- **3b Variants:** other states hand over through `AttackState.try_start_variant()`; dash, crouch and slide attacks, `AirAttackState` (the air loop), `HelmSplitterState` (hold in the air). Variants count as combo step 1; `ActionData.hold_action` names what a hold selects.
- **3c-1 Sheathing:** `Player.sheathed` (spawns true), R and D-pad Down (`sheathe`), auto-sheathe (`auto_sheathe_time`, 5 s, counted only in Locomotion or Crouch), the draw slash (`WeaponData.draw_attack`; `try_start_variant()` swaps it in while sheathed; it counts as no combo step), the dodge attack (`DodgeState`), and the `SwordVisual` scabbard, pin, stretching arm, and draw and sheathe animations.
- **4a Hits on a dummy:** `Hitbox` (Area3D under `SwordVisual`, moved to the hand every frame by `SwordVisual._apply()`) is swept each physics frame by `ActionState._update_hit()` while an ATTACK action with `damage` above 0 is inside `active_hit` (`AttackState` also requires phase NORMAL); one hit per `Hurtbox` per swing; damage = `action.damage` x `_hit_damage_multiplier()` (the charge multiplier). `ActionData.hitbox_length_scale` (1.5 on the helm splitters, draw slash, and charged iai) grows the box from the tip; `ActionData.hitstop` (0.06 s) feeds `Hitstop.request()` (whole-game slow scale 0.05, real-time timer) through `Player.on_hit_landed()`. Layers in `Layers` (1 world, 2 player hurtbox, 3 enemy hurtbox, 4 player hitbox, 5 enemy hitbox). `Hurtbox` passes hits to a sibling `Combatant` (HP, `damaged`/`died` signals) and ignores hits while dead or while its `is_invulnerable` Callable returns true. `scenes/enemy/dummy.tscn`: 500 HP, `EnemyBar` (red cut at once, yellow trail after 1 s, debug damage numbers at the top right), recoil wobble, vanishes at 0 and returns after 2 s.
- **4b Player hurtbox, taking damage, dummy attacks:** the player has a `Hurtbox` (team Player, own capsule) and a `Combatant` (`Player.max_health` 100), both found in the scene or created in code with a warning. `Player._update_hurtbox()` resizes the capsule every frame from a `HurtboxProfile` (stand 1.8/0, crouch 1.1/0, air 1.1/0.7; air = not on the floor and not on a ledge state; crouch = `is_crouched`, which includes slide); the body capsule is untouched. The hurtbox ignores hits while `Player.invulnerable`. On damage: `notify_combat()`, `Hitstop.request()` with the hit's hitstop, `LedgeHangState.knock_off()` if hanging, and a **hit wobble** (`Visual` shifted 0.15 m and tilted 0.2 rad away from the attacker, 0.25 s, exports `hit_recoil_*`; `get_facing_direction()` now uses yaw only so the tilt never changes aim). No stun yet (Step 6); at 0 HP the player refills after `refill_delay` 1.5 s (temporary, Step 10). The debug overlay shows HP and the hurtbox posture. The dummy swings an arm (`SwingPivot/Hitbox`, an ENEMY `Hitbox` swept through a 120 degree arc) when the player is within 2.6 m: high 1.5 m, low 0.15 m, mid 0.9 m in turn, wind-up 0.6 s (the red arm is the telegraph), 0.25 s active, damage 20; `Dummy.attack_mode` can fix one height or turn it off. A stand-in for the Step 7 enemy.
- **5 Guard and deflect:** `GuardState` (ground and air; forced walk via `Player.walk_only`; turns toward input) is entered by a fresh `guard` press (`InputBuffer` tracks it) from Locomotion, Crouch (stands you up if there is headroom), Air, Dash, and, through `ActionState._try_guard_cancel()`, from any action outside its hit window (not the ledge climb). The rules live in `Combatant`: `press_guard()` opens the deflect window (0.2 s, minus 0.04 s per rapid press, floor 0.05 s, full again at once when any other action starts, or after 1 s of neither guarding nor acting), and `take_hit()` decides HIT, GUARD, or DEFLECT from `guarding`, a 90 degree cone against `guard_facing`, and the hit's `guardable`/`deflectable` flags (`HitData`, copied from `ActionData`); a deflect or guard emits `hit_deflected` / `hit_guarded` (Step 6 hooks) and takes no damage. The window keeps running after the button is released (the state ends only when it has run out). Chip damage is off by default (`Combatant.chip_damage_enabled`, `chip_ratio` 0.15). `ActionData.knockback` (and `Dummy.attack_knockback`) pushes the player on every outcome, scaled by `Combatant.knockback_multiplier_hit/guard/deflect` (1.0, 1.0, 0.6); `Player.apply_knockback()` adds an easing push on top of the state's velocity. Guard from sheathed snaps the sword out into a guard-draw pose; `SwordVisual` also has the blade flick (`play_guard_hit`) and the white (deflect) or orange (guard) flash. `Player` creates a `Guard` state in code (with a warning) if the scene has none. The dummy has `attack_guardable`, `attack_deflectable`, and `attack_knockback` test exports. The debug overlay has a Guard line (next window size, press count, idle time toward the 1 s reset, open window, last result) and a white, outlined text; `Combatant.debug_log` (off by default; tick it in the Inspector when tuning) prints guard presses, spam resets, and outcomes to the Output panel.
- **6 Posture, deathblow, stagger:** `Combatant` owns posture (0 to 100, full = break; guard 100%, deflect 10% plus 50% on the attacker, unguarded hit 50% of `posture_damage`; regen 15/s after 1 s, paused while acting, slower at low HP, x2 after 3 s of guarding for the player), the health bars and the deathblow window (`deathblow_enabled`, `boss`; an empty bar or a posture break opens it, a missed one returns the enemy to 1 HP, a missed final bar of a non-boss kills), and the Defense multipliers (`health_taken_multiplier`, `posture_taken_multiplier`). Player: `StaggerState` (6 s, dodge locked 2 s, x1.5 damage taken) and `DeathblowState` (started by `Player._try_deathblow()`: `attack` near an enemy in group `enemy` with an open window; thrust visual drawn, iai visual sheathed). `ActionData.charge_posture_max` scales a charged attack's posture. The dummy has 2 bars (`health_bars`), freezes pale while stunned, and swings with posture damage 25; `EnemyBar` has pips, a posture bar, and the deathblow marker (look exports). Numbers are placeholders (about 1.5x damage for posture). Details: build log, "Step 6".
- **7a Enemy core:** `Enemy` (`scripts/enemy/enemy.gd`, scene `scenes/enemy/enemy.tscn`, a `CharacterBody3D` in group `enemy`) runs the loop IDLE, CHASE, ATTACK, RECOVER, YIELD, STUNNED from `EnemyAIData` (`ai/enemy_default.tres`: speeds, spacing, burst length, recovery, yield time, `aggression`, `damage_scale` 2.0, `posture_scale` 1.5, and the defense fields that 7b will read). Its attacks are the player's ground combo (`weapon.combo` of `katana.tres`) on its own `SwordVisual` and `Hitbox` (team set in code), chained at each action's cancel window; the wind-up is the telegraph. It uses `Combatant` (500 HP, 2 bars, posture, deathblow, set in the scene) and `EnemyBar`; a hit only plays a recoil wobble and never interrupts it. Defense came in 7b; no perilous attacks yet (7c). Details: build log, "Step 7a".
- **7b Enemy defense:** the enemy reads the player's attack and defends by situation (neutral or pressured after a landed hit), with data per enemy type in `ai/` presets (`enemy_soldier`, `enemy_duelist`, `enemy_aura`, `enemy_repulser`): a plain guard or a timed deflect (pressed on time, whatever the reaction delay), an optional repulse (`Combatant.repulsed`: the attacker is bounced and its swing cut, no stun, `Player._update_repulse`), flinch rules with 0.6 s immunity, a hit-streak guard, a riposte (with optional armor), a break-out after many guarded hits, and a recovery pose with the `Aura` node. It guards only in IDLE, CHASE and YIELD. Details and numbers: build log, "Step 7b".
- **7c-1 Perilous attacks:** `Enemy` has phases `PERILOUS` and `COUNTERED`. `_pick_perilous()` chooses thrust (the weapon's charged thrust: pull-back and orange glow are the telegraph) or sweep (`EnemyAIData.sweep_action` = `actions/enemy_sweep.tres`, the whole swing lowered by `SwordVisual.set_drop_target()`), from a chance after each yield (`perilous_chance`) or at a combo's chain points (`perilous_chain_chance`), with a cooldown, a range, and no more than `perilous_repeat_limit` repeats; `Enemy.debug_force_perilous` forces one. Both are unguardable and undeflectable with their own damage (`perilous_damage` 35, `perilous_posture` 40), and it has super armor until the hit window ends. `DangerSymbol` (a `Label3D` under the Player, group `danger_symbol`) shows red from `perilous_symbol_lead` (0.5 s) before the hit window until it closes. Counters are checked each frame while it shows: mikiri (`DodgeState`'s direction via `ActionState.get_move_direction()` within `mikiri_angle` 70 degrees and `mikiri_range`) and the jump-over (the player is not on the floor, which only arms the counter for `head_bounce_window`); the mikiri cuts the attack at once, adds posture, and stuns it (`COUNTERED`, no guard, no flinch; a posture break opens the deathblow instead), and the jump-over does the same when the player lands on that head (`Enemy.on_stomped()`, called by `Player._update_enemy_head()`, which also bounces the player up at `head_bounce_velocity` if it is in `AirState`); any other head landing slides the player off (`head_slide_speed`). The perilous thrust (not the sweep) is deflectable only within `perilous_deflect_window` (0.1 s) of the guard press (`HitData.deflect_within`, checked in `Combatant._resolve`); a normal guard does nothing against it. In `AirState` the player keeps its horizontal momentum and the move keys only steer it (`Player.apply_air_steering()`, `air_steer_acceleration`; the wall jump and air attacks keep their own movement). Looks: `EnemyAIData` blade scale, `blade_back_length` (a visible tail whose hitbox is part of the one damage box, `Hitbox.configure(length, back)`), and `blade_color` change an enemy's weapon on a copy of `WeaponData`. The enemy's bobblehead flinch pivots `Visual` at the feet (jump-over, a shorter one on mikiri, and a slow heavy sway with a drooping head while stunned for a deathblow). `EnemyBar` shows the health bars left as round red dots with a maroon outline in a strip at the bar's left end (a lost one is hidden). On a posture break the player also sinks to a knee and sways (`Player.set_stagger_kneel()`, visual only). Presets: `enemy_monk` (thrust and sweep, 70% chance, 3 s cooldown, spear look), `enemy_duelist` and `enemy_repulser` (thrust), the others none.
- **7d Deflect poses:** `SwordVisual.play_deflect(hit, side)` (called by `Player._guard_reaction` and `Enemy._guard_reaction` on a deflect, only while the sword is in `Anim.GUARD`, else the old flick) picks a `DeflectKind` (`_deflect_kind_for`): THRUST if the action has `charge_time > 0` or is `PERILOUS_THRUST`, else HIGH or LOW from the contact point's height against `deflect_high_above` / `deflect_low_below`, else SIDE (authored for an attacker on the right, mirrored for the left). The pose (hour/radius/forward plus blade and edge directions, all exports under "Deflect poses") is overlaid on the guard pose by `_apply_deflect_overlay()`: snap `deflect_snap_time`, hold, ease back; the aim turns `deflect_aim_follow` toward `hit.point`; a new guard press, a new action, or `play_guard` cancels it. `debug_force_deflect` shows one kind on every deflect. The perilous thrust sets `HitData.knockback` from `EnemyAIData.perilous_thrust_knockback` (3.0 m) with `HitData.knockback_time` (`perilous_knockback_time` 0.4 s, -1 = the target's default); `Player.apply_knockback(direction, distance, time)` takes the optional time, and a deflect pushes `knockback_multiplier_deflect` (0.6) of it.
- **Deflect spam rule (after 7d):** `Combatant.press_guard()` shrinks the window by `deflect_shrink` only if `_next_press_shrinks()`: a tap under `deflect_rapid_interval` (0.35 s) after the last press, or `press_count >= deflect_free_presses` (3); `shrink_steps` counts the steps. The run resets (`_reset_spam`) on acting, 1 s idle without guarding, `deflect_hold_reset_time` (3 s) of holding since the last press, a deflect, and an unguarded hit; a plain guard does not reset it. The three thrust actions (`thrust`, `dash_thrust`, `deathblow_thrust`) now aim down the center line (windup `(12, 0.1, -0.4)`, end `(12, 0.1, 1.3)`, no body twist).
- **Attack phase speeds (after 7d, shipped, not yet tested):** the attack clock runs slower inside a slash's hit window. Player: `Player.slash_active_speed` (0.7) via `ActionState._active_speed_factor()`; `_slows_active_window()` is false for the charged thrust, `HelmSplitterState`, and `DeathblowState` (the charged iai and every other slash are slowed); the wind-up is unchanged, so the enemy's `time_to_hit` guess needs no change. Enemy: `EnemyAIData.windup_speed` (0.65) and `active_speed` (0.7), read by `Enemy._attack_speed()` for the combo attacks only (not the perilous ones). A slash is longer by duration x (1/speed - 1); cancel and buffer windows open later in real time. Numbers are placeholders.
- **Enemy bar as one entity (after the phase speeds, shipped, not yet tested):** the enemy's `Bar` node is a child of `Visual` (so it follows the flinch, bobble, and sway; `enemy.gd` reads `$Visual/Bar`; still 2.3 m up). `EnemyBar` lays the pip strip, the pips, and the posture bar out with `QuadMesh.center_offset` (camera-facing) instead of node positions, so they stay attached whatever the enemy's yaw or the camera angle. The dummy's bar gets the same fix.
- **Guard break (after the enemy bar, shipped, not yet tested):** `HitData.perilous` (set by `Enemy` on its perilous hits). In `Combatant.take_hit()`, a plain hit with `guarding`, `perilous`, and the attacker inside the guard cone emits `guard_broken(hit)` (after `damaged`; damage and knockback are the plain hit's). `Player._on_guard_broken()`: heavier wobble (`guard_break_recoil_scale` 1.6), leaves `GuardState` for Locomotion or Air, optional guard-press lockout (`guard_break_lockout`, 0 = none), and `SwordVisual.play_guard_break(side)` (exports under \"Guard break\": the blade is knocked aside, snap, hold, ease back, red flash, laid over the return to rest). A deflect, a dodge, or a hit from behind does not break the guard. Numbers are placeholders.
- **Jump tuning (after 4b, user-approved):** `Player.jump_velocity` 8.5 and `gravity_multiplier` 1.5 (were 7.0 and 2.0): the jump is about 2.5 m high (was 1.25 m), about 1.2 s in the air, about 7.5 m at run speed, with a fall that stays fairly snappy; the jump now reaches an enemy's head. Wall jumps scale with it (up = `jump_velocity` x `wall_jump_boost`). The helm splitter's dive and the half-gravity opening are multiples of the same gravity, so they follow. A 3x lower-gravity version felt floaty and was dropped. `test_arena.tscn`: the tops of LowPlatform, TightPlatform, HighPlatform, Pillar, Wall, Wall2, and Gap were raised to 2x their height above the floor (floor top y 0.25); horizontal spacing unchanged. An optional heavier fall (`fall_gravity_factor`) was offered, not built.
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
- [ ] Enemy awareness system (sight cone, noise; states unaware, suspicious, alert, combat)
- [ ] Stealth deathblow from crouch (behind an unaware enemy, within ~2 m, removes one health bar)
- [ ] Enemy variety (jumpers/chasers, ranged rock throwers) as data flags in `EnemyAIData`
- [ ] Generic interact system (doors, chests, NPCs; nearest-in-front priority, on-screen prompt)

- [ ] **Cleanup refactor (after ALL of Phase 1 is done and tested by the user):** move wall and ledge sensing out of `player.gd`, replace hard-coded state name strings with constants, give the states a shared base (not typed to `Player`) so the enemy can reuse `ActionState` and the `Combatant` rules
- [ ] **Cleanup (Step 5 leftover):** `Player._ready()` and `_setup_hurtbox()` create a missing `Guard` state, `Hurtbox`, or `Combatant` in code (with a warning). The scene has all three now, so remove those fallbacks (they run once at startup and cost no FPS; this is only clutter)
- [ ] Swing trail / smear effect for sword swings (a ribbon that follows the blade tip during the active window and fades; none exists yet; fits Step 11 polish or real animation VFX)
- [ ] More enemy body feedback beyond the bobblehead (a head snap on each landed hit, a slump in its recovery, breathing in the recovery pose, a coil while it charges the thrust); the player's posture-break kneel could also move a little instead of staying planted
- [ ] Real animation integration (Blender, glTF, `AnimationPlayer` following the action clock); notes in section 8 of `docs/step3-combat-spec.md`