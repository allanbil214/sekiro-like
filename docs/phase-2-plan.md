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
| 9 | Wall hug (section 3, item 9) | feature | [x] done and tested 2026-10-16 |
| 10 | Non-lethal combat (section 3, item 10) | feature | [x] done and tested 2026-10-16 |
| 11 | Item system and throwables: 11a the item belt, `use_item` / `cycle_item`, the tap throw and the item HUD; 11b hold to aim (section 3, item 11) | feature | [x] done and tested 2026-10-19 (11a the tap throw, 11b hold to aim, 11c sticky aim and click to throw, 11d guards check the spot) |
| 11.5 | Taunt (addendum to item 11, section 3, item 11.5) | feature | [x] done and tested 2026-10-19 |
| 11.6 | Folder reorganization (addendum, section 3, item 11.6) | refactor | [x] done and tested 2026-10-19 |
| 12a | Navigation: a navmesh for enemies (section 3, item 12a) | feature | [x] done and tested 2026-10-19 |
| 12b | Navigation links: enemies jump, drop or climb between levels (section 3, item 12b) | feature | [ ] planned (split off 2026-10-19), after 12a is tested |
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
- **Status:** **built and tested 2026-10-16** (what was built: `docs/built-reference.md`, "Wall hug"). The text below is the plan as discussed. Decisions made at the full check: a single press, an automatic latched peek at a wall end (no button), attack, guard, dodge and jump just leave the hug and act normally, the stealth kill from the hug pulls the target in over 0.15 s (a cheap glide), the stealth numbers are Player exports (not `EnemyAIData`), a slim 0.2 m body and no personal space push while hugging, the demo wall in `test_arena`.
- **What (user):** the Sekiro and Tenchu move. Press `interact` while facing a wall, on the ground, and the character presses her back to it. Called "wall hug" so it is not confused with the ledge shimmy (hanging from a ledge).
- **Entry and exit (user, proposed single press):** `interact` facing a wall within reach, in any stance. Leave with `interact` again, moving away from the wall, a jump or a dodge. **Open:** a single press (default) or the double press some Sekiro PC players describe.
- **Sidle:** slow and quiet along the wall. **Peek around a corner** by shifting the camera.
- **Stealth bonus:** enemies see the player more slowly and hear almost nothing (the awareness numbers).
- **Reuse:** `LedgeSensor.find_wall` (wall jump uses it); the shared button order is in item 8, so this item comes after it.
- **Not included in the first version:** an ambush attack from the hug when a guard walks past (Tenchu style).

### 10. Non-lethal combat
- **Status:** **built and tested 2026-10-16** (what was built: `docs/built-reference.md`, "Non-lethal combat"). The text below is the plan as discussed. Decisions made at the full check: one sword with a toggle (T, D-pad Up), posture damage full, a boss is knocked out too (no banner), enemies wake by themselves after 300 s (a boss never) or by a guard, the stealth kill with the reversed blade is a code-drawn 1.5 s choke, reputation counting is Phase 3. Reasons and the reputation link: `docs/phase-3-4-notes.md`, sections 6 and 7.
- **What (user):** a **reverse blade** toggle (WoTS sakabato): health damage halved, a deathblow that makes the enemy **unconscious**, and a stealth deathblow that becomes a **choke** until unconscious.
- **Posture damage:** the user asked whether it is halved too. **Proposed default: full** (**open**).
- **Technical shape (proposed):** a lethal flag on `HitData`, a knocked-out state on `Combatant` and `Enemy` (a knockout replaces death at zero health), and unconscious bodies that reuse the 7d and 7e body code with a milder reaction ("wake him up", not an alarm).
- **Needed by:** item 11 (the lethal flag of the ammo) and the Phase 3 reputation system.

### 11. Item system and throwables
- **Status:** **11a and 11b built and tested 2026-10-19** (what was built: `docs/built-reference.md`, "Item system and throwables, 11a" and "Hold to aim, 11b"). At the 11b full check: the 0.2 s hold threshold (a tap throws on release), free aim from a lock (the camera swings onto the target's chest first, the lock comes back on release), and the throw solved to the crosshair's aim point. **11c (added after the 11b test, same day):** attack throws from the aim and the aim goes on (0.3 s recovery), releasing `use_item` never throws, and the Options "AIM MODE" STICKY (default) / HOLD decides whether letting go ends the aim; guard and heal end it in both modes. **11d (same day, from the 11a test):** a guard that hears a noise or loses a glimpse of the player now walks to the spot, looks around for `spot_check_time` (30 s) and then returns to its route or post; 3 noises in one check make it search (alert, still not knowing about the player). Discussed 2026-10-16; **redesigned 2026-10-19** (the user: items work like Tenchu and Nightreign, so the throw is the first item of a general item system). Decisions made at the full check: the defaults below stand (ammo set and counts, no sword draw, keys F and G with D-pad Right and Left); after the test the user set the shuriken and kunai noise to 10 m (the metal throwables are the accurate distraction tool, the rock and ceramic the loud wide lure). The text below is the plan as discussed.
- **What (user):** a Sekiro-style prosthetic idea done as a **normal throw with selectable ammo**: a rock, a shuriken, a kunai, broken ceramic; each lethal or non-lethal. No player bow (yumi). Later items (Tenchu style: onigiri, rice to mark a spot, and so on) use the same system.
- **The item system (user, 2026-10-19):**
  - The **gourd keeps its own quick button** (`heal`, Q) and is not part of the item list (Nightreign style: the flask is quick, other items use other buttons).
  - **One selected item** at a time. `cycle_item` steps through everything carried; `use_item` does what the selected item's kind says (a throwable starts the throw action; later kinds start their own state, for example eating or placing). *(proposed)* A single list now; categories on separate buttons can be split out later without breaking anything.
  - `ItemData` (base resource: name, icon shape and color, count, kind). `ThrowableData` extends it. `ItemBelt` holds the list, the selected index and the counts (in memory for now). In 11a it only contains throwables.
  - **Input Map:** `use_item` (F, controller D-pad Right) and `cycle_item` (G, controller D-pad Left) *(proposed keys)*. They replace the earlier names `throw` and `cycle_ammo`. Both appear in the Options controls pages.
- **`ThrowableData` (proposed):** damage, posture, a lethal flag, noise, `speed` and `gravity` per ammo (count lives in the belt). Rocks and ceramic arc a little and are non-lethal; shuriken and kunai fly straight and fast and are lethal. Default: **small damage and a short stun, not a killing tool**, so close-range stealth stays the focus. Starting counts 10 each (placeholder).
- **Noise at a position (proposed):** `Player.get_noise_radius()` is centered on the player, so a landing rock needs a world noise event. A new `EnemyAwareness.hear_noise_at(position, radius)` reuses the `hear_shout` fields (the enemy turns suspicious and investigates the spot; no line of sight needed). A rock can lure a guard from his post.
- **Throwing is an attack:** a short throw action (`data/actions/player/throw.tres`, an `ActionData`) with a recovery, following the usual action rules. `ThrowState` is the state for throwable items; allowed from Locomotion, Crouch and Dash, walk-only during the action, dodge, jump and guard cancel it after the locked window, no throwing in the air, and throwing does not draw the sword *(proposed)*.
- **11a:** the tap throw (the camera's forward direction, or toward the locked target's chest when locked on), `ItemData`, `ThrowableData`, `ItemBelt`, the noise at a position, `cycle_item`, and the **item HUD**. Two new Input Map actions as editor steps.
- **Item HUD (user, 2026-10-19):** like Sekiro, **bottom right**, in the prosthetic slot. A code-drawn square icon per item (grey rock, silver star, dark kunai, white shard), the name, and the count; dimmed at 0; a short flash on cycling. Margin, size and colors are `@export` values. The gourd stays bottom left under the health bar for now. No button prompts yet (backlog).
- **11b (user, proposed shape accepted):** hold `use_item` to aim, for throwables only. The camera moves to head height with the head hidden (not a real first person), a crosshair shows for shuriken and kunai, and a **dotted arc preview with a landing marker** (grenade style) for rocks and ceramic. Releasing throws. While aiming: slow walk (like the guard's forced walk), the lock-on suspended, the spring arm shortened in tight spaces. The preview simulates the projectile's own gravity.
- **Not included:** any non-throwable item (onigiri, marking rice and so on), pickups, saving (ammo counts are saved in Phase 3), enemy throwers, a real throw animation, moving the gourd to a bottom-right quick slot.
- **Reuse:** the projectile system is reused by enemy archers, revolvers and rifles in Phase 4; the item system is reused by the Phase 3 and 4 items.
- **Needs:** item 10's lethal flag, so this comes after it.

### 11.5. Taunt (addendum to item 11)
- **Status:** **built and tested 2026-10-19** (what was built: `docs/built-reference.md`, "Taunt"). Decisions made with the user: a `taunt` button (V, Back/Select) that makes enemies in combat **provoked** (more aggressive, no advantage for the player, since there is no style meter); a real action with a wind-up, a locked part and a wind-down (like an attack); stacks up to 3 that fade after 10 s; a boss feels half; an unaware enemy hears it as an 8 m noise; the voice lines are wired (two empty sound slots, `taunt` and `enemy_provoked`). Defaults not changed: guard and damage stay as they are.
- **Not included:** a taunt animation, NPC or crowd reactions (Phase 3), taunt wavs, a reward for the player.

### 11.6. Folder reorganization (refactor, before item 12)
- **Status:** **done and tested 2026-10-19** (the new layout and the old-to-new table: `docs/built-reference.md`, "Folder reorganization, 11.6"). A one-shot script (`reorganize.py`, now removed) made a zip backup, moved the files with their `.uid` and `.import` sidecars, rewrote every `res://` path (and the bare path mentions in `.gd` comments) and checked that none points to nothing; no behavior changed.
- **Layout:** `data/` holds every `.tres` and the csv (`actions/player`, `actions/enemy`, `ai`, `arenas`, `weapons`, `items`, `hurtbox`, `audio`, `ui`), `assets/` holds audio and shaders, and the scripts are grouped by job (`core`, `items`, `resources`, `ui/hud`, `ui/menus` are new). `scenes/` did not change.
- **Not included:** any code or scene change, moving `scenes/`, renaming class names. Docs outside this item keep old paths only in history files (`docs/phase-1-5-plan.md`, the build log).

### 12a. Navigation (the navmesh)
- **Status:** done and tested 2026-10-19 (discussed 2026-10-16); **split into 12a and 12b on 2026-10-19** (the user: the navmesh first, the links as a follow-up). 12a is walking on flat levels only. The hub of Phase 3 and the street encounters are its users (`docs/phase-3-4-notes.md`, section 5).
- **What (user):** a navmesh system for enemies. **Rule (proposed):** a per-enemy `use_navigation` flag, **off by default**, so every existing arena and preset behaves exactly as before (the same rule as `use_awareness`).
- **Shape (proposed):** `NavigationRegion3D` for the baked walkable area, `NavigationAgent3D` on the enemy, the change mostly in the enemy's "walk toward a spot" code, plus baking the arenas that use it.
- **Limits to know:** a navmesh handles walking around walls and stalls but **not climbing**. A ground enemy cannot follow onto a roof unless jump or climb links are added; the existing "from another level it stands and watches, still alert" rule covers it. Roofs get their own walkable area so rooftop guards can patrol. In Phase 3 and 4 the streamed world needs one region per cell with matching edges. Jump, drop and climb links are item 12b.

### 12b. Navigation links (follow-up to 12a)
- **Status:** planned, split off 2026-10-19; starts only after 12a is built and tested. Not designed yet: it gets its own full check.
- **What (user, proposed order):** enemies that cross between levels with `NavigationLink3D` links: first a **drop** (roof to ground), then a **jump** over a gap, then a **climb** last. The navmesh side is only the links; the real work is an enemy state per link kind (timing, movement, later animation).
- **Rule (proposed):** a per-enemy switch (off by default, like `use_navigation`), so only chosen enemies follow across levels.
- **Open (the user's design choice):** if enemies can follow onto roofs, the roofs stop being a guaranteed escape (`docs/phase-3-4-notes.md`, section 5). Decide at the 12b full check which enemies get links.
- **Needed by:** the Phase 3 hub (rooftop guards, hunters that follow, the roof escape).

## 4. Backlog carried over (13 and later)

Items 8 to 12 above were picked on 2026-10-16 (the interact system and four ideas from the same talk). The other open entries stay in section 13 of `docs/handoff.md`, which remains the single list: ledge enhancements, heal and death extras, lock-on extras, the sweep duck, enemy variety, the generic interact system, sound extras, more enemy body feedback, and real animation integration. When the user picks one, it gets the next item number here with its decisions, and is ticked off in both files. Items 1 to 3 do not change those entries.

## 5. Not in this phase

- Saves, a real map, quests and the game flow around them (START becomes NEW GAME when they exist). These are **Phase 3** (the plan and the discussion notes are in `docs/phase-3-4-notes.md`).
- Settings beyond item 6: display (window mode, VSync), language, subtitles, difficulty, a UI scale.
- Music in the arenas and any sound work beyond the main menu's.
- A bundled title font and a drawn logo.
- Any change to the combat tuning or to `Enemy`'s own behavior.
