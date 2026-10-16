# Phase 2: New features and enhancements

> Companion to `docs/handoff.md`. Agreed 2026-10-12, right after Phase 1.5. The open ideas from the **Phase 2 backlog** (handoff, section 13) stay listed there; this file holds the items the user has picked and their agreed decisions.
>
> **Slimmed 2026-10-16:** the original text of the finished items 1 to 7 is in `docs/archive/phase-2-done-items.md` (read it only when a task needs one of those decisions). Items 8 to 12 are planned and kept in full below.
>
> **Direction (user, 2026-10-12):** the game is closer to Way of the Samurai (Acquire), Shinobido and Rise of Ronin in its main quest and game design, with Sekiro's combat. The current arenas are placeholder and testing maps; when the real game flow is designed, they stay in the project but are not reachable by players.

## 1. Rules for this phase

- **New features, one item at a time.** Each is built, tested by the user, and logged before the next (work agreement, sections 1 to 7). Full check before each build, then an explicit go; the build-log entry is appended without reading the file.
- **Decisions below were agreed on 2026-10-12.** Anything an item does not settle gets a proposed default and one question at that item's full check.
- **New menus are scenes with one shared Theme** (user, 2026-10-12): screens are built from `Control` nodes (containers and anchors for the layout, `Button` focus for keyboard and gamepad navigation), the look (fonts, colors, button styles) lives in one `Theme` resource (`ui_theme.tres`), and scripts hold only behavior. Texts, colors and the kanji stay `@export` values or Theme entries the user can tune in the editor. System serif fonts for now; a bundled free-license font is a later polish. The death and victory screens became scenes in item 4; the HUDs stay code-drawn until real art exists.
- **Placeholders stay marked.** The test arenas, the default start arena and the empty Options panels are placeholders and are logged as such.
- **Verify by playing.** Each item ends with a short "How to verify" that also covers what it touches (fight, guard and deflect, lock-on, death and resurrection, scene reload).

## 2. Status

| # | Item | Kind | Status |
|---|---|---|---|
| 1 | Main menu | feature | [x] done and tested 2026-10-12 |
| 2 | Pause menu | feature | [x] done and tested 2026-10-12 |
| 3 | Arena chooser, fall zone and three base arenas (3a fall zone, 3b arena data and chooser, 3c the arenas) | feature | [x] done and tested (3a, 3b and 3c-1 on 2026-10-12; 3c-2, the two movement arenas, on 2026-10-13) |
| 4 | Migrate the in-game UI to scenes (the death and victory screens first; the HUD waits for real art) | refactor | [x] done and tested 2026-10-13 (the death and victory screens; the HUDs wait for real art) |
| 5 | Loading screens: a proper one with tips and a black-screen one (section 3, item 5) | feature | [x] done and tested 2026-10-13 |
| 6 | Options screen in two parts: 6a the audio and gameplay menus, 6b the controls (section 3, item 6) | feature | [x] done and tested (6a and 6b on 2026-10-13) |
| 7 | Enemy awareness and the stealth deathblow, with a multi-level stealth arena (7a awareness core and the arena's ground floor, 7b the stealth deathblow, 7c the upper levels and the death from above; 7d corpse discovery, 7e tending the body; section 3, item 7) | feature | [ ] in progress: **7a to 7e built and tested (2026-10-15)**, item 7 is complete |
| 8 | Generic interact system (section 3, item 8) | feature | [x] done and tested 2026-10-16 |
| 9 | Wall hug (section 3, item 9) | feature | [ ] planned (discussed 2026-10-16), not started |
| 10 | Non-lethal combat (section 3, item 10) | feature | [ ] planned (discussed 2026-10-16), not started |
| 11 | Throwables: 11a tap throw and ammo, 11b hold to aim (section 3, item 11) | feature | [ ] planned (discussed 2026-10-16), not started |
| 12 | Navigation: a navmesh for enemies (section 3, item 12) | feature | [ ] planned (discussed 2026-10-16), not started |
| 13 and later | The other open entries of the Phase 2 backlog (handoff, section 13); numbers are given when the user picks each one | various | not started |

Order: 1, 2, 3 (3a first, because it changes gameplay), 4 (after items 1 and 2, because it needs their Theme), 5 (the loading screens), 6 (the options screen), 7 (enemy awareness and the stealth deathblow, picked by the user 2026-10-13), then 8 to 12 (agreed as a list on 2026-10-16; the numbers match the build order, so the order is 8, 9, 10, 11, 12, each with its own full check), then the rest of the backlog in the order the user picks.

## 3. The items

### Items 1 to 7 (all done and tested; the full original text is in `docs/archive/phase-2-done-items.md`)

- **1. Main menu (2026-10-12).** A "PRESS ANY BUTTON" title screen, then START, OPTIONS, QUIT (ARENAS in a debug build); `main_menu.tscn` with the shared `ui_theme.tres`, music and menu sounds. START loads `DEFAULT_ARENA` (one constant, a placeholder), and becomes NEW GAME with a CONTINUE above it when saves exist.
- **2. Pause menu (2026-10-12).** `pause` (Esc, gamepad Start); the game pauses; Resume, Options, Quit to Title, and a debug-only Change arena.
- **3. Arena chooser, fall zone, arenas (2026-10-12 and 13).** `FallZone` (a fall costs 25 percent of max health, never lethal), `ArenaData` and the chooser (a release-build START opens the chooser), the fighting arena with eight variants (all `debug_only` rules in the original), invisible walls on physics layer 6, the boss HUD, and two movement arenas (Training Yard, Gauntlet).
- **4. UI as scenes (2026-10-13).** The death and victory screens are scenes with the shared Theme; `PlayerHud` and `BossHud` stay code-drawn until real art exists; `EnemyBar`, `DangerSymbol`, `DebugOverlay` and `CrouchVignette` are not screen UI and stay.
- **5. Loading screens (2026-10-13).** `SceneLoader` (PROPER with tips from `data/loading_tips.csv`, BLACK after a fade); every scene change goes through it; the player has a 1 s start grace.
- **6. Options (2026-10-13).** 6a Audio and Gameplay pages and `Settings` (`user://settings.cfg`), 6b Controls and rebinding (`ControlsBindings`). Not included: display settings, language, subtitles, difficulty, UI scale.
- **7. Enemy awareness and the stealth deathblow (2026-10-15, addendum 2026-10-16).** 7a awareness core and the Stealth Compound's ground floor, 7b stealth deathblow, 7c upper levels and the death from above, 7d corpse discovery, 7e tending the body; the bars-in-combat addendum. **Rule kept for every item:** `Enemy.use_awareness` is off by default (per instance), so every existing arena and preset behaves as before; the numbers are in `EnemyAIData`. Not included: a light and shadow system, hiding places, throwables (item 11 now), enemy dialogue.

### 8. Generic interact system
- **Status:** **built and tested 2026-10-16** (what was built: `docs/built-reference.md`, "Interact system"). The text below is the plan as discussed. Decisions made at the full check: the menu OK sound for everything, the demo in `test_arena`, flags kept across the death reload and cleared at the main menu, no group or physics layer (a static registry), `GameFlags` static (no autoload). Background and the bigger picture: `docs/phase-3-4-notes.md` (sections 4, 5 and 11).
- **What:** an `Interactable` (prompt text, priority, `can_interact()`) in the world and a picker on the player: the nearest interactable in front within about 2.5 m, with an on-screen prompt such as "E: Open". What happens after the press is separate from the picker, so Phase 3 can add behaviors (notice board, shop, minigame) without touching it.
- **First interactables (proposed):** a door (can be locked by a flag), a chest, a switch, and a placeholder NPC that shows one line of text. A crowd NPC is also an interactable with one or two generic lines from a pool (chosen by reputation in Phase 3).
- **`GameFlags` (proposed):** a small in-memory flag store, so a door's lock has something to read now; Phase 3 adds saving without changing any door.
- **The shared `interact` button (user's rule, proposed order):** in the air a ledge grab (exactly as today); on the ground the nearest `Interactable` in front; on the ground with nothing to interact with, the wall hug (item 9). Interactables work on the ground in Locomotion or Crouch only.
- **Not included:** the dialogue freeze and a real dialogue box (Phase 3), saving, the notice board, shops.

### 9. Wall hug
- **Status:** planned, discussed 2026-10-16.
- **What (user):** the Sekiro and Tenchu move. Press `interact` while facing a wall, on the ground, and the character presses her back to it. Called "wall hug" so it is not confused with the ledge shimmy (hanging from a ledge).
- **Entry and exit (user, proposed single press):** `interact` facing a wall within reach, in any stance. Leave with `interact` again, moving away from the wall, a jump or a dodge. **Open:** a single press (default) or the double press some Sekiro PC players describe.
- **Sidle:** slow and quiet along the wall. **Peek around a corner** by shifting the camera.
- **Stealth bonus:** enemies see the player more slowly and hear almost nothing (the awareness numbers).
- **Reuse:** `LedgeSensor.find_wall` (wall jump uses it); the shared button order is in item 8, so this item comes after it.
- **Not included in the first version:** an ambush attack from the hug when a guard walks past (Tenchu style).

### 10. Non-lethal combat
- **Status:** planned, discussed 2026-10-16. Reasons and the reputation link: `docs/phase-3-4-notes.md`, sections 6 and 7.
- **What (user):** a **reverse blade** toggle (WoTS sakabato): health damage halved, a deathblow that makes the enemy **unconscious**, and a stealth deathblow that becomes a **choke** until unconscious.
- **Posture damage:** the user asked whether it is halved too. **Proposed default: full** (**open**).
- **Technical shape (proposed):** a lethal flag on `HitData`, a knocked-out state on `Combatant` and `Enemy` (a knockout replaces death at zero health), and unconscious bodies that reuse the 7d and 7e body code with a milder reaction ("wake him up", not an alarm).
- **Needed by:** item 11 (the lethal flag of the ammo) and the Phase 3 reputation system.

### 11. Throwables
- **Status:** planned, discussed 2026-10-16. The user wanted it in Phase 2 because it is a main combat feature. Split in two builds, each tested in turn.
- **What (user):** a Sekiro-style prosthetic idea done as a **normal throw with selectable ammo**: a rock, a shuriken, a kunai, broken ceramic; each lethal or non-lethal. No player bow (yumi).
- **`ThrowableData` (proposed):** damage, posture, a lethal flag, noise, count, `speed` and `gravity` per ammo. Rocks and ceramic arc a little; shuriken and kunai fly straight and fast. Default: **small damage and a short stun, not a killing tool**, so close-range stealth stays the focus.
- **Noise at a position (proposed):** `Player.get_noise_radius()` is centered on the player, so a landing rock needs a world noise event. `EnemyAwareness.hear_shout()` already takes a position, so the thrown noise reuses that path (a small addition). A rock can lure a guard from his post.
- **Throwing is an attack:** a short throw action (an `ActionData`) with a recovery, following the usual action rules.
- **11a:** the tap throw (straight ahead of the character, or toward the locked target's chest when locked on), the ammo data, the noise at a position, the ammo cycle and a small code-drawn HUD readout. Two new Input Map actions, `throw` and `cycle_ammo`, as editor steps. The ammo count is in memory for now; saving and pickups come with the Phase 3 items.
- **11b (user, proposed shape accepted):** hold the throw button to aim. The camera moves to head height with the head hidden (not a real first person), a crosshair shows for shuriken and kunai, and a **dotted arc preview with a landing marker** (grenade style) for rocks and ceramic. Releasing throws. While aiming: slow walk (like the guard's forced walk), the lock-on suspended, the spring arm shortened in tight spaces. The preview simulates the projectile's own gravity.
- **Reuse:** the projectile system is reused by enemy archers, revolvers and rifles in Phase 4.
- **Needs:** item 10's lethal flag, so this comes after it.

### 12. Navigation
- **Status:** planned, discussed 2026-10-16. The hub of Phase 3 and the street encounters are its users (`docs/phase-3-4-notes.md`, section 5).
- **What (user):** a navmesh system for enemies. **Rule (proposed):** a per-enemy `use_navigation` flag, **off by default**, so every existing arena and preset behaves exactly as before (the same rule as `use_awareness`).
- **Shape (proposed):** `NavigationRegion3D` for the baked walkable area, `NavigationAgent3D` on the enemy, the change mostly in the enemy's "walk toward a spot" code, plus baking the arenas that use it.
- **Limits to know:** a navmesh handles walking around walls and stalls but **not climbing**. A ground enemy cannot follow onto a roof unless jump or climb links are added; the existing "from another level it stands and watches, still alert" rule covers it. Roofs get their own walkable area so rooftop guards can patrol. In Phase 3 and 4 the streamed world needs one region per cell with matching edges.

## 4. Backlog carried over (13 and later)

Items 8 to 12 above were picked on 2026-10-16 (the interact system and four ideas from the same talk). The other open entries stay in section 13 of `docs/handoff.md`, which remains the single list: ledge enhancements, heal and death extras, lock-on extras, the sweep duck, enemy variety, the generic interact system, sound extras, more enemy body feedback, and real animation integration. When the user picks one, it gets the next item number here with its decisions, and is ticked off in both files. Items 1 to 3 do not change those entries.

## 5. Not in this phase

- Saves, a real map, quests and the game flow around them (START becomes NEW GAME when they exist). These are **Phase 3** (the plan and the discussion notes are in `docs/phase-3-4-notes.md`).
- Settings beyond item 6: display (window mode, VSync), language, subtitles, difficulty, a UI scale.
- Music in the arenas and any sound work beyond the main menu's.
- A bundled title font and a drawn logo.
- Any change to the combat tuning or to `Enemy`'s own behavior.
