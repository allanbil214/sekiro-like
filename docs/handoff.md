# Handoff: Sekiro-Like Combat Prototype (Godot 4)

> Paste this whole file at the start of a new chat. Update the **Progress checklist** (section 10) at the end of each session.
>
> **Docs.** Section numbers are kept stable; a moved section leaves a pointer.
>
> | File | Read it? |
> |---|---|
> | `docs/handoff.md` (this file) | always |
> | `docs/work-agreements.md` | always |
> | `docs/phase-2-plan.md` | when working on Phase 2 (the agreed decisions; the finished items 1 to 7 are archived in `docs/archive/phase-2-done-items.md`) |
> | `docs/phase-3-plan.md` | when working on Phase 3, feel and weight (planned 2026-10-20; milestones 3a to 3d) |
> | `docs/phase-3-feel-reference.md` | when tuning Phase 3: the Elden Ring feel numbers, in seconds, as temporary placeholders (notes, not decisions) |
> | `docs/phase-4-6-notes.md` | for Phase 2 items 8 to 12 (the sections that touch the item) and in full for Phase 4 or later (discussion notes of 2026-10-16, not agreed decisions) |
> | `docs/design-later-steps.md` | only the section a task touches (hitboxes, guard, posture, enemy, lock-on, heal, the cleanup refactor) |
> | `docs/step3-combat-spec.md` | only when a task changes attacks or sheathing |
> | `docs/animation-pipeline.md` | for animation, Blender, rig or timeline-tool work (read it in full) |
> | `docs/phase-1-5-plan.md` | on request only (Phase 1.5 is done) |
> | `docs/built-reference.md` | on demand: search the one system a task touches; Claude appends to it |
> | `docs/archive/` (`build-log.md`, `handoff-checklist-2026-10-16.md`, `phase-2-done-items.md`) | **never read by default** (history; Claude appends to the build log) |
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
- **Crouch slide:** `crouch` pressed **while dashing** starts a slide (`ActionState` driven by `data/actions/player/slide.tres`, i-frames like the dodge, ends in Crouch; jump and dodge cancel it after its locked window, with headroom).
- **Crouch and slide attacks:** a tap loop that keeps you crouched, hold = the upward slash (spec, section 6).
- **Ducking works because the hurtbox shrinks** (Step 4; 3.11 in `docs/design-later-steps.md`); there is no `attack_height` variable. Stealth use is Phase 2.

### 3.10 Mid-air reach, wall jump, and ledges (built; full original text in the build log, Part 2)
- **Jump in mid-air gives no extra height:** the character reaches for a surface. A wall within `wall_range` gives a **wall jump** (restores the reach, capped per airtime at 2; direction from the camera-relative input versus the wall normal: toward = up, away = backward, sideways = along the wall, no input = away; boost 1.2x). Otherwise the **reach** plays once per airtime. An air jump press within 0.3 m of the floor is ignored (it stays buffered for the landing jump).
- **Ledges** (`interact`): grab needs airborne, input toward a wall, a flat ledge top in the hand zone (1.4 to 2.1 m above the feet) with room to stand. Reaching it without `interact` **auto-climbs** (scripted `LedgeClimb`); with `interact` the character **hangs** (`LedgeHang`): a fresh `interact` = climb, crouch = drop, jump = leap away, left/right = shimmy 1.5 m/s along the ledge, turning square corners (inside and outside, item 13a). A thin top with no room to stand is hung from and cannot be climbed (item 13d). Releasing `interact` does nothing. After a drop or leap there is no grab for 0.3 s. A hit knocks the player off the ledge (`LedgeHangState.knock_off()`, called from the damage system in Step 4).
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

### 5.1 `ActionData` (`scripts/resources/action_data.gd`)

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

Everything in steps 1 to 13 is **done and tested**; the original list with all its notes is in `docs/archive/handoff-checklist-2026-10-16.md`. In short:

| Step | What | Where to read more |
|---|---|---|
| 1 | Movement, camera, jump, Input Map | `docs/built-reference.md` |
| 2 | Traversal: dodge and dash, crouch and slide, mid-air reach and wall jump, ledges | 3.7 to 3.10 above |
| 3 | Attacks: 5-hit combo, charged thrust, dash, crouch, slide and air variants, helm splitter, sheathing, draw slash, charged iai | `docs/step3-combat-spec.md` |
| 4 | Hitboxes, hurtboxes, `Combatant`, hitstop, hurtbox profiles | `docs/design-later-steps.md` |
| 5 | Guard, deflect, the shrinking window, jump versions | same |
| 6 | Posture, posture break, deathblow, player stagger | same |
| 7 | Enemy AI: core, defense, perilous attacks and the grab, deflect poses | same |
| 8 | ~~Clash~~ dropped (first connect wins, like FromSoftware) | `docs/design-later-steps.md`, 3.3 |
| 9 | Lock-on | same |
| 10 | Heal, death and resurrection, the player HUD | same |
| 11 | Polish: sound, effects, camera shake, boss-slain screen, shockwaves, swing trail, crouch vignette | `docs/design-later-steps.md`, 3.12 |
| 12 | Cleanup refactor (A to D) | `docs/design-later-steps.md`, 3.13 |
| 13 | Phase 1.5 hardening (11 items) | `docs/phase-1-5-plan.md` |
| 14 | **Phase 2, new features** (items 1 to 11, 11.6, 12a, 12b-1a, 12b-1b, 12b-2 and 12b-3 done) | `docs/phase-2-plan.md` |
| 15 | **Phase 3, feel and weight** (planned 2026-10-20, not started; milestones 3a to 3d) | `docs/phase-3-plan.md` |
| later | Phase 4 (game flow, a small slice), Phase 5 (content and systems), Phase 6 (art) | `docs/phase-4-6-notes.md` (discussion notes, not agreed decisions) |

> Phase numbers shifted on 2026-10-20 (a new Phase 3 was inserted): the old 3, 4, 5 are now 4, 5, 6. Texts in `docs/archive/` still use the old numbers.

---

## 9. Open questions

The unresolved ones (O1, O2, O5, all about later steps; O3 was settled in Step 5 and O4 in Step 9) are in `docs/design-later-steps.md`. Resolved ones are in the build log, Part 4. Ask the user before assuming.

---

## 10. Progress checklist (update each session)

> One line per finished step; the open items are in full. The old full checklist and the old "Current state" paragraph are in `docs/archive/handoff-checklist-2026-10-16.md`. After a step is tested: add or tick **one line** here and append its 2 to 4 lines to `docs/built-reference.md` (work agreement, section 7).

- [x] 1. Movement, camera, jump, Input Map (KBM and controller)
- [x] 2a to 2d. State machine and `ActionData`, dodge and dash-hold, crouch and slide, mid-air reach and wall jump, ledges (auto-climb, hang, shimmy, climb, drop, leap)
- [x] 3a to 3c. Ground combo and charged thrust, dash, crouch, slide and air variants, helm splitter, sheathing, the draw slash, the dodge attack, the charged iai
- [x] 4a, 4b. Hitbox, hurtbox, `Combatant`, hitstop, hurtbox profiles, taking damage
- [x] 5. Guard, deflect, the shrinking window, jump versions, knockback
- [x] 6. Posture, posture break, deathblow, player stagger, the deathblow marker
- [x] 7a to 7d. Enemy core, defense (four `data/ai/` presets), perilous attacks (thrust, sweep, grab), deflect poses
- [x] ~~8. Clash~~ dropped 2026-10-08
- [x] 9. Lock-on
- [x] 10. Heal (3 charges), death with 2 resurrections, the player HUD, the death screen
- [x] 11a to 11g. Sound, sparks and effects, camera shake, boss-slain screen and heal arm, shockwaves, swing trail, crouch vignette
- [x] 12A to 12D. Cleanup refactor: no fallbacks, `StateName`, `LedgeSensor`, `ActionRunner`
- [x] 13. Phase 1.5 (11 items): `Groups`, `Enemies`, `Actions`, `EnemyDefense`, `SwordGuardPoses`, `PlayerForcedMovement`, `PlayerBodyReaction`, pooled `Fx` and `Sfx`, typed trail points, debug-only prints
- [ ] 14. Phase 2, new features (`docs/phase-2-plan.md`; items numbered as in that file; 11 and 12 are planned, numbers match the build order):
  - [x] 1. Main menu (title screen, START, ARENAS or the chooser in a release build, OPTIONS, QUIT, shared `ui_theme.tres`, music and menu sounds)
  - [x] 2. Pause menu (the game pauses; Esc or Start; Resume, Options, Quit to Title, debug-only Change arena)
  - [x] 3. Arena chooser and arenas: fall zone, `ArenaData`, fighting arenas and variants, invisible walls, boss HUD, movement arenas; the release-build START follow-up
  - [x] 4. Death and victory screens as scenes (HUDs stay code-drawn until real art exists)
  - [x] 5. Loading screens (`SceneLoader`, tips from `data/loading_tips.csv`)
  - [x] 6a, 6b. Options: Audio and Gameplay pages, Controls and rebinding, `user://settings.cfg`; plus the fixes after the friends' release test
  - [x] 7a to 7e. Enemy awareness, the stealth deathblow, the Stealth Compound arena with upper levels and the death from above, corpse discovery, tending the body, the F4 undetectable switch; plus the 2026-10-16 addendum (enemy bars only in combat)
  - [x] 8. Generic interact system (`Interactable`, nearest-in-front picker, prompt, in-memory `GameFlags`; door, chest, switch, placeholder NPC; demo in `test_arena`)
  - [x] 9. Wall hug (`WallHugState`: `interact` facing a wall, sidle, latched corner peek, slim body, stealth bonus, stealth kill with a pull; demo in `test_arena`)
  - [x] 10. Non-lethal combat (the `reverse_blade` toggle, `HitData.lethal`, `Combatant` knockout, unconscious enemies that wake, guards waking them, the choke)
  - [x] 11a. Item system and throwables: `ItemData`, `ItemBelt`, `use_item` and `cycle_item` (the gourd keeps `heal`), the tap throw (rock, shuriken, kunai, ceramic), noise at a position, the bottom-right item HUD (done and tested 2026-10-19)
  - [x] 11b. Hold to aim: `AimState`, head-height camera, crosshair, arc preview with landing and noise rings, the lock suspended and restored (done and tested 2026-10-19)
  - [x] 11c. Sticky aim and click to throw (attack throws from the aim, the Options "AIM MODE" STICKY / HOLD, heal and guard end the aim; done and tested 2026-10-19)
  - [x] 11d. Guards check the spot (a noise or a fading glimpse: walk there, look around for `spot_check_time`, then back to the route; 3 noises make it search; done and tested 2026-10-19)
  - [x] 11.5. Taunt (addendum to item 11: `taunt` V / Back, `TauntState` with wind-up, shout and wind-down, provoked stacks on enemies in combat, a noise for unaware ones, sound slots `taunt` and `enemy_provoked`; done and tested 2026-10-19)
  - [x] 11.6. Folder reorganization (refactor: `reorganize.py` moved the files with their sidecars and rewrote every `res://` path; new layout `data/`, `assets/`, `scripts/core|items|resources|ui/hud|ui/menus`; done and tested 2026-10-19)
  - [x] 12a. Navigation: navmesh, `use_navigation` (flat levels; `EnemyNavigation`, `NavigationAgent` on the enemy, baked `NavRegion`, the `navigation_yard` arena; done and tested 2026-10-19)
  - [x] 12b. Navigation links (all done and tested 2026-10-20): enemies drop, jump and climb between levels. Split 2026-10-19: [x] 12b-1a drop links (done and tested 2026-10-19: `use_nav_links`, one-way `NavigationLink3D` on layer 2, the crossing in `EnemyNavigation`, `GuardRoof` in `navigation_yard`); [x] 12b-1b the drop-link generator, an editor tool (done and tested 2026-10-19: `scripts/tools/drop_link_generator.gd`, the `DropLinkGenerator` node in `navigation_yard`); [x] 12b-2 jump links (done and tested 2026-10-19: layer-4 `NavigationLink3D`, a computed arc in `EnemyNavigation`, `GuardJump` between `RoofPlatform` and `RoofPlatform2` in `navigation_yard`); [x] 12b-3 climb links (done and tested 2026-10-20: layer-8 `NavigationLink3D`, a two-leg climb in `EnemyNavigation`, `GuardClimb` in `navigation_yard`)
  - [x] 13. Ledge enhancements (`docs/phase-2-plan.md`): [x] 13a corner shimmy (inside and outside, 90 degrees; done and tested 2026-10-20), [x] 13b low-ceiling climb (ends in Crouch; done and tested 2026-10-20), [x] 13c hang hit reactions (hit 1 and 2 flinch, hit 3 drops; done and tested 2026-10-20), [x] 13d thin ledges (hang from walls and pillars with no standing room; done and tested 2026-10-20)

  - [x] 14. Wall hug extras (`docs/phase-2-plan.md`; done and tested 2026-10-21): [x] 14a corner-to-corner (the hug turns inside and outside corners; inside by pushing, outside by `interact` while peeking; done and tested 2026-10-20), [x] 14b crouched hug on low walls and the low-wall vault (hold toward the wall and press `jump`; lands hugging the far side; done and tested 2026-10-20), [x] 14c peek up over a low wall (`interact` while holding toward it; the camera rises over walls up to 1.8 m; no hug sight bonus while raised; done and tested 2026-10-21)
  - [ ] 15. Carrying bodies (`docs/phase-2-plan.md`; picked 2026-10-20, scope widened and agreed 2026-10-21; one sub-item at a time):
    - [x] 15a. Carry unconscious and dead bodies (the carried body as a player overlay, not a state; over the right shoulder; `interact` to pick up and put down; guards carry the same way; done and tested 2026-10-21)
    - [x] 15b. Cover volumes: hiding spots for bodies (bush, crate, closet; most of the body inside means guards cannot discover it; the player glides to the best spot; done and tested 2026-10-21; the container shrink fit (`shrink_body`) was added after that test and is still to be tested)
    - [ ] 15c. Throwing a body
    - [ ] 15d. Guard reactions (seeing a carry, bodies waking suspicious, finding a body again, the alarm after 3 finds or 3 different bodies; rules in `docs/phase-2-plan.md`)

**Phase 3, feel and weight (planned 2026-10-20; plan and decisions: `docs/phase-3-plan.md`; nothing built yet):**
  - [ ] 3a. Tools: the feel overlay (action timeline, i-frame tint), the `ActionData` validator, and 3a-3 the placeholder animation import (the Bevy sandbox animations on the capsule and stick character)
  - [ ] 3b. Action data: turn control inside actions, per-input cancel times, motion curves, multi-hit attacks
  - [ ] 3c. Locomotion and reactions: per-fighter hitstop, locomotion tuning, landing and hit reaction tiers, lock-on range hysteresis, the small details (light-tilt walk, four-direction jumps and landings when locked on, fall start off a ledge, upper-body layers)
  - [ ] 3d. Look and sound: the mannequin (in steps), foot placement, frame-driven sound

**Placeholders to replace (agreed 2026-10-20; Claude reminds the user at every Phase 3 full check and when a milestone is finished):** Elden Ring material is allowed as a stand-in while the character is a capsule and stick. Replace all of it with the user's own work **in Phase 6, and in any case before the project goes public** (a Kickstarter, early access, a public demo, anything meant to attract public interest). Nothing placeholder ships past that point.
  - [ ] Numbers: the timings, windows and speeds copied from `docs/phase-3-feel-reference.md` into `ActionData` and the locomotion code (each is marked as a placeholder where it is used)
  - [ ] Animations: the Bevy sandbox animations once 3a-3 exists; the user's own Blender animations replace them in Phase 6 (not used in the game before that)
  - [ ] Anything else taken from the game later (sounds and models are not covered by the rule; ask first)

**Current state (2026-10-21):** Phase 2 items 15a (carrying bodies) and 15b (cover volumes) are done and tested; 15c and 15d are next. Steps 1 to 13 are done and tested. Phase 2 items 1 to 11, the 11.5 taunt addendum, the 11.6 folder reorganization, 12a and 12b (12b-1a, 12b-1b, 12b-2 and 12b-3) are done and tested (item 7, enemy awareness and the stealth deathblow, ended with 7e and the bars-in-combat addendum; item 8 is the interact system; item 9 is the wall hug; item 10 is non-lethal combat; item 11 is the item system: 11a the tap throw, 11b hold to aim, 11c sticky aim and click to throw, 11d guards check the spot). The project now uses the new folder layout (see "Folder layout" in the map below). Item 12 is split: 12a (navmesh, walking on flat levels) is done and tested; 12b is split: 12b-1a (drop links, enemies fall from a roof to the ground) is done and tested; 12b-1b (the editor button that generates drop links) is done and tested; 12b-2 (jump links across a gap) and 12b-3 (climb, going up from the ground to a platform) are done and tested, so item 12 is complete; Phase 2 item 13 (ledge enhancements) is complete: 13a (corner shimmy), 13b (low-ceiling climb), 13c (hang hit reactions) and 13d (thin ledges) done and tested 2026-10-20, so the next work is item 14 (wall hug extras: 14a corner-to-corner and 14b low-wall vault are done and tested 2026-10-20; 14c peek up over a low wall is done and tested 2026-10-21, so item 14 is complete; item 15 is next, carrying unconscious bodies), all picked 2026-10-20; Phase 3 (feel and weight) comes after or whenever the user picks it. Phase 3 (feel and weight) is planned in `docs/phase-3-plan.md` and not started. Phases 4 to 6 exist only as discussion notes in `docs/phase-4-6-notes.md`. Every arena and enemy preset behaves exactly as before unless a per-instance switch (`use_awareness`, later `use_navigation`) is on.

### Where things live (a map; behavior details: `docs/built-reference.md`, each script's header comment, the build log)

- **Player:** `scripts/player/player.gd` (the `CharacterBody3D` root: shared data and helpers, drives the states), `states/` (one script per state: locomotion, crouch, wall_hug, slide, dash, dodge, air, wall_jump, ledge_hang, ledge_climb, attack, air_attack, helm_splitter, guard, deathblow, stagger, heal, dead; `state_machine.gd`, `state_name.gd`, `state.gd`, and `action_state.gd`, which runs an `ActionData` clock), `input_buffer.gd`, `ledge_sensor.gd` (walls and ledges), `player_forced_movement.gd` and `player_body_reaction.gd` (helpers made in `Player._ready()`), `camera_rig.gd`, `lock_on.gd`. Scene: `scenes/player/player.tscn`.
- **Sword and body visuals (placeholders):** `sword_visual.gd`, `sword_guard_poses.gd`, `heal_arm.gd`, `reach_arms.gd` (debug); the `Hitbox` sits under `SwordVisual`.
- **Shared constants:** `scripts/core/`: `actions.gd` (Input Map names), `groups.gd`, `layers.gd`, `enemies.gd` (the list of enemies).
- **Combat core:** `scripts/combat/`: `combatant.gd` (health, posture, guard and deathblow rules), `hitbox.gd`, `hurtbox.gd`, `hurtbox_profile.gd`, `hit_data.gd`, `hitstop.gd`, `action_runner.gd` (the shared action clock), `fall_zone.gd`, `fx.gd` and `shockwave.gd` (effects and shake).
- **Enemy:** `scripts/enemy/enemy.gd` (scene `scenes/enemy/enemy.tscn`), `enemy_defense.gd`, `enemy_awareness.gd`, `enemy_navigation.gd` (12a, made in `Enemy._ready()` when `use_navigation` is on; 12b drop, jump and climb crossings), `dummy.gd` (`scenes/enemy/dummy.tscn`). AI presets in `data/ai/*.tres`. The spot check (11d) lives in `EnemyAwareness._run_suspicious()`.
- **Data (tuned values live in the `.tres`):** the Resource class scripts are in `scripts/resources/` (`action_data.gd`, `weapon_data.gd`, `enemy_ai_data.gd`, `arena_data.gd`, `item_data.gd`, `throwable_data.gd`, `sfx_data.gd`, `sfx_slot.gd`); the `.tres` files are under `data/`: `actions/player/` and `actions/enemy/` (`enemy_grab`, `enemy_sweep`), `weapons/katana.tres`, `ai/`, `arenas/`, `items/` (the throwables), `hurtbox/`, `audio/sfx_data.tres`, `ui/ui_theme.tres`, `data/loading_tips.csv`. Binary assets (wavs, music, shaders) are under `assets/`.
- **Non-lethal combat (item 10):** the toggle is `Player.toggle_reverse_blade()` (`GameFlags.BLADE_REVERSED`), the knockout is `Combatant._finish()` and `knocked_out`, the sleeper is `Enemy._on_knocked_out()` and `wake_up()`, the guards wake it in `EnemyAwareness._run_wake()`, and the choke is `DeathblowState` with `data/actions/player/choke.tres`.
- **Editor tools (`scripts/tools/`):** `drop_link_generator.gd` (12b-1b, `@tool` `DropLinkGenerator` node: set `region`, press "Generate drop links"; it reads the baked navmesh and adds one-way `NavigationLink3D` nodes on layer 2 as its own children, Clear removes only those; rebake, then Generate again after geometry changes; `max_drop` must match `nav_drop_max_height`).
- **Interact system (item 8):** `scripts/interact/` (`interactable.gd` and its behaviors `door`, `chest`, `switch`, `npc_line`; `interact_picker.gd`, made in `Player._ready()`; `game_flags.gd`), `scripts/ui/hud/interact_prompt.gd`; small scenes in `scenes/interact/`.
- **Item system and throwables (item 11a):** `scripts/resources/item_data.gd` and `throwable_data.gd` (the data; `data/items/*.tres` hold the tuned numbers), `scripts/items/item_belt.gd` (the list and counts, made in `Player._ready()`), `states/throw_state.gd` (`data/actions/player/throw.tres`), `scripts/items/throwable.gd` (the projectile and its noise), `scripts/ui/hud/item_hud.gd`, `Player._try_use_item()` and `_try_cycle_item()`, and `EnemyAwareness.hear_noise_at()`. Taunt (11.5): `states/taunt_state.gd` (`data/actions/player/taunt.tres`), `Player._try_taunt()`, `Enemy.hear_taunt()` and `provoke()`, the "Provoked" group of `EnemyAIData`. Hold to aim (11b, 11c): `states/aim_state.gd`, `scripts/items/aim_preview.gd`, `scripts/ui/hud/aim_hud.gd`, the aim mode in `camera_rig.gd`, `ThrowState.fire()`, the `Settings.sticky_aim` option.
- **Sound:** `scripts/audio/sfx.gd` (static `Sfx`), wavs under `assets/audio/`, the slot table `data/audio/sfx_data.tres`.
- **HUDs and overlays drawn in code (`scripts/ui/hud/`):** `player_hud.gd`, `boss_hud.gd`, `awareness_hud.gd`, `enemy_bar.gd`, `danger_symbol.gd`, `crouch_vignette.gd`, `debug_overlay.gd`, `aim_hud.gd`, `item_hud.gd`, `interact_prompt.gd`; `screen_fade.gd` stays in `scripts/ui/`.
- **Menus and screens (scenes under `scenes/ui/`, scripts under `scripts/ui/menus/`):** `main_menu`, `pause_menu`, `options_menu` (with `settings.gd` and `controls_bindings.gd`), `arena_chooser` (with `arena_library.gd`), `loading_screen` (with `scene_loader.gd` and `loading_tips.gd`), `death_screen`, `victory_screen`. `settings.gd`, `scene_loader.gd`, `ui_text_scaler.gd` stay in `scripts/ui/`.
- **Arenas (`scenes/arena/`):** `test_arena`, `fighting_arena` and its eight variants (`fighting_dummy`, `_soldier`, `_duelist`, `_aura`, `_repulser`, `_monk`, `_grappler`, `_squad`) plus `fighting_duo`, `movement_yard`, `movement_gauntlet`, `stealth_compound`.
- **Folder layout (since 11.6, 2026-10-19):** `scenes/` (scenes, as before), `scripts/` by job (`core`, `combat`, `player`, `enemy`, `items`, `interact`, `audio`, `resources`, `ui/hud`, `ui/menus`), `data/` (every `.tres` and the csv), `assets/` (audio, shaders). The old-to-new table is at the end of `docs/built-reference.md`.
- **Docs:** `docs/CLAUDE.md` (the start order), `work-agreements.md`, `phase-2-plan.md`, `phase-4-6-notes.md`, `design-later-steps.md`, `step3-combat-spec.md`, `animation-pipeline.md`, `built-reference.md`, `archive/`.

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
- Player settings (volumes, shake, crouch mode, lock-on options, sensitivity) live in `Settings` and are changed through the Options menu, not by editing exports; a new option is a `Settings` variable, its load and save lines, and one row in `OptionsMenu`.
- Scene changes go through `SceneLoader.go(tree, path, Kind)` (PROPER for a loading screen with tips, BLACK for the plain change after a fade), not a bare `change_scene_to_file`; the death reload (`reload_current_scene`) is the exception.
- Timings in **seconds**, never frames.
- **Never scale a `CollisionShape3D` node.** Set sizes on the shape resource itself (radius, height, size).
- The player scene root is the `CharacterBody3D` itself (no wrapper node).
- **No "create it in code if the scene lacks it" fallbacks for nodes.** New code expects its nodes to exist (list them as editor steps; a missing node is an error to see, not to hide).
- States never call `move_and_slide()`; the Player does it once per frame. After `machine.transition_to(...)`, `return` immediately.
- Folder structure (since 11.6; new files go where their job says):
  ```
  res://
    scenes/         # player, enemy, arena, ui, interact (.tscn)
    scripts/
      core/         # shared constants: Actions, Groups, Layers, Enemies
      combat/       # Combatant, hitbox, hurtbox, ActionRunner, Fx
      player/       # Player, states/, camera, lock-on, sword visuals
      enemy/        # Enemy, awareness, defense, dummy
      items/        # ItemBelt, Throwable, AimPreview
      interact/     # Interactable and its behaviors, GameFlags
      audio/        # Sfx
      resources/    # Resource class scripts (ActionData, WeaponData, ...)
      ui/           # Settings, SceneLoader, ScreenFade, UiTextScaler
        hud/        # HUDs and overlays drawn in code
        menus/      # menu and screen scripts
    data/           # every .tres (and the csv); actions/player, actions/enemy,
                    #   ai, arenas, weapons, items, hurtbox, audio, ui
    assets/         # audio (wavs, music), shaders
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
- **Docs per chat:** the files listed at the top of this handoff + a fresh snapshot (`docs/CLAUDE.md` has the exact start order). Start a new chat per phase so sessions stay small. **Claude does not read `docs/archive/`, `docs/built-reference.md` or `docs/design-later-steps.md` except for the one part a task needs, and appends an entry to the build log and to `docs/built-reference.md` after each finished step** (work agreement, section 7).
- **SOLID-minded new code:** new combat code reads data resources and keeps jobs separate (weapon data, a separate `Combatant`, attack data from resources). The cleanup refactor of the traversal code is **deferred until all of Phase 1 is done and tested by the user** (see the backlog).
- To share the project, run `python pack_for_claude.py` (in the project root; use `--only <paths>` to pack just the relevant folders) and upload the zip it creates in `snapshots/`. It includes the docs and skips binary assets (listing their names).
- The controller layout is Xbox/PlayStation style (see the Input Map table in 3.8).
- Feature creep is a known risk: flag it gently, and keep Phase 2 items deferred until Phase 1 works.

---

## 13. Phase 2 backlog (deferred on purpose)

- [x] Corner shimmy and other ledge enhancements **(Phase 2 item 13: 13a corner shimmy, 13b low-ceiling climb, 13c hang hit reactions and 13d thin ledges all done and tested 2026-10-20; the hang drop and the ledge-to-ledge jump already work and were dropped; see `docs/phase-2-plan.md`)**
- [ ] Heal and death extras (not built): real heal and death animations, a low-HP warning vignette, status effect icons in a row beside the gourd, item and prosthetic icons, controller or keyboard button icons on the prompts, checkpoints and gourd upgrades
- [ ] Lock-on extras (not built): a HUD (names, health), camera shake or zoom, the enemy reacting to being locked, different facing for walking and running
- [ ] Sweep duck: a lower hurtbox and capsule, and a head-bounce landing point that follows the visual head (when real models arrive)
- [x] Enemy awareness system (sight cone, noise; states unaware, suspicious, alert, combat) **(built as Phase 2 item 7a, done and tested by the user 2026-10-15)**
- [x] Stealth deathblow (no crouch and no angle needed; any enemy that has not started fighting you, or spotted you less than about 0.35 s ago; non-bosses die outright, a boss loses a bar) **(built as Phase 2 item 7b, done and tested by the user 2026-10-15)**
- [x] Death from above (a drop on an unaware or suspicious enemy from a height, with the helm splitter dive) **(built as Phase 2 item 7c, done and tested by the user 2026-10-15)**
- [x] Corpse discovery (guards finding bodies) **(built as Phase 2 item 7d, done and tested by the user 2026-10-15)**
- [x] Carrying bodies (the finder checks the body in an arc, roams, then carries it to a wall) **(built as Phase 2 item 7e, done and tested by the user 2026-10-15; hiding bodies from the player stays out)**
- [ ] Enemy variety (jumpers/chasers, ranged rock throwers) as data flags in `EnemyAIData` (archers, revolvers and rifles are planned for Phase 5, on the projectile system of Phase 2 item 11; see `docs/phase-4-6-notes.md`)
- [x] Generic interact system (doors, chests, NPCs; nearest-in-front priority, on-screen prompt) **(built as Phase 2 item 8, done and tested by the user 2026-10-16)**
- [x] Wall hug (`interact` facing a wall: sidle along it, peek around corners, stealth bonus) **(built as Phase 2 item 9, done and tested by the user 2026-10-16)**
- [ ] Traversal hints (not built, noted 2026-10-20): a bottom-center prompt that follows the state: while hugging "E: leave" (and "E: turn corner" when peeking at an outside corner), while hanging "W: climb up", "Space: leap", "C: drop". Key names should follow the Input Map (rebinding updates them; `InteractPrompt` is the model); maybe only the first few times or a setting. Related: the "button icons on the prompts" part of the heal and death extras
- [ ] Wall hug extras (not built): the grab-and-pull stealth kill with real animations (the 0.15 s glide is a placeholder), an ambush attack from the hug, a lean pose, hugging in the air, vaulting and corner-to-corner moves **(Phase 2 item 14: 14a corner-to-corner and 14b low-wall vault done and tested 2026-10-20, 14c peek up planned; the rest stays here)**
- [x] Non-lethal combat (reverse blade, half health damage, knockout deathblow, choke as the stealth kill, unconscious bodies) **(built as Phase 2 item 10, done and tested by the user 2026-10-16)**
- [ ] Non-lethal extras (not built): a boss cutscene when a boss is knocked out, counting kills and knockouts for the reputation system (Phase 4, the `knocked_out` signal exists), carrying bodies, hiding bodies, throwing a body and guard reactions **(Phase 2 item 15, picked 2026-10-20, widened 2026-10-21)**, a real choke animation
- [x] Item system and throwables: **11a and 11b built (done and tested by the user 2026-10-19)** (11b: hold `use_item` to aim with a crosshair and an arc preview, the camera at head height, slow walk, the lock-on suspended)
- [ ] Item extras (not built; later, on the item system): Tenchu-style items (onigiri, rice to mark a spot, and others), item categories on separate buttons, pickups and saving, moving the gourd to a bottom-right quick slot, button prompts on the item HUD
- [ ] Taunt extras (not built): a real taunt animation and a sword flourish, taunt wavs for the two slots, NPC and crowd reactions (Phase 4), an optional reward for the player (provoked enemies guard less, off on purpose)
- [x] Navigation (a navmesh and `NavigationAgent3D`, a per-enemy `use_navigation` flag off by default) **(built as Phase 2 item 12a, done and tested by the user 2026-10-19)**
- [x] Navigation links, drop: enemies drop from a roof to the ground **(built as Phase 2 item 12b-1a, done and tested by the user 2026-10-19)**
- [x] Navigation links, the drop-link generator: an editor tool that makes drop links along roof edges **(built as Phase 2 item 12b-1b, done and tested by the user 2026-10-19)**
- [x] Navigation links, jump: enemies jump a gap between two surfaces **(built as Phase 2 item 12b-2, done and tested by the user 2026-10-19)**
- [x] Navigation links, climb: enemies climb from the ground up to a platform and back down **(built as Phase 2 item 12b-3, done and tested by the user 2026-10-20)**
- [ ] Feel and weight: **Phase 3, see `docs/phase-3-plan.md`** (planned 2026-10-20)
- [ ] Game flow, the hub, quests, reputation, streaming, ranged enemies, art: **Phases 4 to 6, see `docs/phase-4-6-notes.md`** (discussion notes, not agreed build decisions)
- [ ] Sound extras (not built): wire `charge_loop` and `aura_loop` (needs a start and a stop call) and find wavs for `guard_raise`, `land_soft`, `heal_drink`; footsteps per surface (the grass, soil, and stone wavs exist); swingH/L and the slow sheathe for variety; the deathblow_opening sounds once the real animation exists (`deathblow_open_enabled`); enemy voice lines; music and ambience; per-slot tuning of the mix A different landing sound per throwable (a metal clink for the shuriken and kunai, a crack for the rock and ceramic; the landing uses the placeholder `LAND_HARD` and the throw `SWING_ALT`).

- [ ] **Cleanup refactor: moved into Phase 1 as Step 12 (section 8 and 10; design in 3.13 of `docs/design-later-steps.md`).** The original note: move wall and ledge sensing out of `player.gd`, replace hard-coded state name strings with constants, give the states a shared base (not typed to `Player`) so the enemy can reuse `ActionState` and the `Combatant` rules
- [ ] **Cleanup (Step 5 leftover): this was 12A (done and tested 2026-10-12).** `Player._ready()` and `_setup_hurtbox()` create a missing `Guard` state, `Hurtbox`, or `Combatant` in code (with a warning). The scene has all three now, so remove those fallbacks (they run once at startup and cost no FPS; this is only clutter)
- [x] ~~Swing trail~~ built in Step 11f (the original note: swing trail / smear effect for sword swings (a ribbon that follows the blade tip during the active window and fades; none exists yet; fits Step 11 polish or real animation VFX))
- [ ] More enemy body feedback beyond the bobblehead (a head snap on each landed hit, a slump in its recovery, breathing in the recovery pose, a coil while it charges the thrust); the player's posture-break kneel could also move a little instead of staying planted
- [ ] Real animation integration (Blender, glTF, `AnimationPlayer` following the action clock); notes in section 8 of `docs/step3-combat-spec.md`