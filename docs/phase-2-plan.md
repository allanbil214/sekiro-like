# Phase 2: New features and enhancements

> Companion to `docs/handoff.md`. Agreed 2026-10-12, right after Phase 1.5. The open ideas from the **Phase 2 backlog** (handoff, section 13) stay listed there; this file holds the items the user has picked and their agreed decisions.
>
> **Direction (user, 2026-10-12):** the game is closer to Way of the Samurai (Acquire), Shinobido and Rise of Ronin in its main quest and game design, with Sekiro's combat. The current arenas are placeholder and testing maps; when the real game flow is designed, they stay in the project but are not reachable by players.

## 1. Rules for this phase

- **New features, one item at a time.** Each is built, tested by the user, and logged before the next (work agreement, sections 1 to 7). Full check before each build, then an explicit go; the build-log entry is appended without reading the file.
- **Decisions below were agreed on 2026-10-12.** Anything an item does not settle gets a proposed default and one question at that item's full check.
- **New menus are scenes with one shared Theme** (user, 2026-10-12): screens are built from `Control` nodes (containers and anchors for the layout, `Button` focus for keyboard and gamepad navigation), the look (fonts, colors, button styles) lives in one `Theme` resource (`ui_theme.tres`), and scripts hold only behavior. Texts, colors and the kanji stay `@export` values or Theme entries the user can tune in the editor. System serif fonts for now; a bundled free-license font is a later polish. The existing in-game screens stay code-drawn until item 4 moves them.
- **Placeholders stay marked.** The test arenas, the default start arena and the empty Options panels are placeholders and are logged as such.
- **Verify by playing.** Each item ends with a short "How to verify" that also covers what it touches (fight, guard and deflect, lock-on, death and resurrection, scene reload).

## 2. Status

| # | Item | Kind | Status |
|---|---|---|---|
| 1 | Main menu | feature | [ ] |
| 2 | Pause menu | feature | [ ] |
| 3 | Arena chooser, fall zone and three base arenas (3a fall zone, 3b arena data and chooser, 3c the arenas) | feature | [ ] |
| 4 | Migrate the in-game UI to scenes (the death and victory screens first; the HUD waits for real art) | refactor | [ ] |
| 5 and later | The open entries of the Phase 2 backlog (handoff, section 13); numbers are given when the user picks each one | various | not started |

Order: 1, 2, 3 (3a first, because it changes gameplay), 4 (after items 1 and 2, because it needs their Theme), then the backlog in the order the user picks.

## 3. The items

### 1. Main menu
- **What:** the game starts on a main menu (a new `main_menu.tscn` becomes the project's main scene) in a simple FromSoft style. The Sekiro title screen was only a layout reference: the logo and artwork are original.
- **Entries:** START, OPTIONS, QUIT.
  - START loads the default arena (a placeholder, `test_arena.tscn`, kept as one constant so there is a single place to change). Later it becomes NEW GAME with a CONTINUE entry above it, when saves exist.
  - OPTIONS opens an empty panel that says there is nothing here yet, with a Back button.
  - QUIT closes the game.
- **Title:** "UNTITLED GAME" large in pale serif capitals, with "STILL A PROTOTYPE" below it, smaller and spaced, in gold.
- **Background:** black with a faint warm vignette and a large faded kanji behind the title (about 8 percent opacity). The kanji is **道** (michi, "path" or "way"), an `@export`. Alternatives that were weighed: 浪 (ronin; it looks close to the 狼 behind the Sekiro title), 影 (shadow), 斬 (slash).
- **Footer:** the centered line "A prototype. Nothing here is final." and, bottom right, "Ver. 0.1" read from the project's version setting.
- **Feel:** a fade in from black at launch and a fade out when START is pressed; a soft brush-stroke highlight on the selected row (a gradient texture, no image file); keyboard, mouse and gamepad (the built-in `ui_*` actions: up and down to move, accept to confirm, cancel to go back); the layout scales with the window height like the death screen.
- **Flow:** the menu shows the mouse cursor; the arena's camera rig captures it when the arena loads. Dying still reloads the current arena only.
- **Built as scenes:** `main_menu.tscn` (Control nodes and containers) with a script for the behavior, using the shared `ui_theme.tres` made here. Claude writes the scene as text, so a small property may need a fix in the editor; the layout and look are then tuned there.
- **No sound yet:** the sound table has no menu sounds; adding move and confirm sounds is a sound extra (needs wavs and two `Sfx` ids).
- **Full check still to do** at build time: the exact files, the editor step (the main scene setting) and the zip name.

### 2. Pause menu
- **What:** a pause menu with Resume, Options (the same empty panel) and Quit to Title. Item 3 adds a debug-only "Change arena" entry.
- **The game pauses** while it is open (unlike FromSoft; user, 2026-10-12).
- **Built as a scene** with the shared Theme and a process mode that keeps it running while the tree is paused.
- **Open, settled at this item's full check:** which key opens it and how it shares Esc with the camera rig's `ui_cancel` mouse handling; that the pause must not run during the death screen or a resurrection prompt; what "Quit to Title" does to the scene state; that Hitstop and slow motion (real-time timers) behave while paused.

### 3. Arena chooser, fall zone and three base arenas
- **Why:** to test an enemy type or a movement setup without changing the Inspector, and later to offer arena gameplay as a side game or bonus mode (so an arena can carry a real name, description and image).
- **3a. Fall zone** (built and tested first, because it changes gameplay). A reusable `FallZone` (an `Area3D` placed under the playable area of each arena). Sekiro-style, not an instant death:
  - **Respawn point:** the player's own starting position and facing, recorded in `Player._ready()` the way `Enemy` records its spawn. A real map's checkpoints can replace it later.
  - **Penalty:** a share of max health, 25 percent as an `@export`, applied as ordinary damage through the `Combatant`. Falling cannot kill: it always leaves at least 1 HP (a safety net, not a death trap).
  - **On respawn:** a short fade to black and back, the velocity and any knockback cleared, the player put back in a normal state, and about a second of invulnerability (the resurrection one is reused).
  - **Edge cases:** nothing happens while the player is dead or in a deathblow.
  - **Enemies are not touched** (user, 2026-10-12): the zone ignores them, and `Enemy` keeps its own quiet "below -30 m, move back to spawn" check as it is.
- **3b. `ArenaData` and the chooser.** An `ArenaData` resource per arena: name, scene, optional image, description, category (test, movement, fighting) and a `debug_only` flag. The chooser reads a folder of them (a new arena is one new resource) and shows them in sections by category, with a plain placeholder where an image is missing.
  - **ARENAS entry in the main menu:** a debug build shows every arena; a release build shows the entry only if at least one arena is player-facing (`debug_only` off).
  - **The pause menu** gets a debug-only "Change arena".
  - **START is not the chooser:** START stays the real game's entry (the default arena for now).
- **3c. Three base arenas.** (1) the current jumbled test arena, kept as it is (`debug_only`); (2) a new **movement arena** for traversal (walls, ledges, gaps, slopes; no enemies); (3) a new **fighting arena** with flat, open ground. Variants are **inherited scenes of the fighting arena** that set only the enemy's `ai` preset (the monk, the grappler, the four presets in `ai/`). Claude builds a simple blockout of the two new maps for the user to refine in the editor.
- **Later, not in this item:** one fighting arena with a spawner that reads its enemy list from the arena data (waves, a picked opponent, challenge rules) for a real arena mode. The inherited scenes do not block it.

### 4. Migrate the in-game UI to scenes
- **Why:** the in-game screens are drawn in code (a choice made early, with no editor view and no art). Scenes with the shared Theme are the usual Godot practice: editor layout, one place for fonts and colors, live preview. Agreed 2026-10-12 as item 4, after the menus, because the Theme is made in items 1 and 2.
- **A refactor:** no visual or gameplay change. The look has to match the current one (positions, sizes, scaling with the window height); the user compares side by side.
- **In scope:** `DeathScreen` and `VictoryScreen` first (they already use real `Label` nodes; the screen shader and the timed fades and slow motion stay in code). `PlayerHud` only when real HUD art exists (today its health bar, pips and gourd are shapes drawn with code, so a scene would gain little).
- **Not touched:** `EnemyBar` and `DangerSymbol` (3D objects in the world, not screen UI), `DebugOverlay` (a dev tool) and `CrouchVignette` (a small shader overlay).
- **Care:** these screens are children of the Player in `player.tscn` and their tuned `@export` values live there, so the latest snapshot is needed to carry every value over. The build log and the handoff list each screen's values.
- **Full check still to do** at build time: which screens in which order, the editor steps and the zip name.

## 4. Backlog carried over (5 and later)

The open entries stay in section 13 of `docs/handoff.md`, which remains the single list: ledge enhancements, heal and death extras, lock-on extras, the sweep duck, enemy awareness, the stealth deathblow, enemy variety, the generic interact system, sound extras, more enemy body feedback, and real animation integration. When the user picks one, it gets the next item number here with its decisions, and is ticked off in both files. Items 1 to 3 do not change those entries.

## 5. Not in this phase

- Saves, a real map, quests and the game flow around them (START becomes NEW GAME when they exist).
- An Options screen with real settings (volume, sensitivity, key remapping).
- Menu sounds and music.
- A bundled title font and a drawn logo.
- Any change to the combat tuning or to `Enemy`'s own behavior.
