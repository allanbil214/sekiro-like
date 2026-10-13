# Phase 2: New features and enhancements

> Companion to `docs/handoff.md`. Agreed 2026-10-12, right after Phase 1.5. The open ideas from the **Phase 2 backlog** (handoff, section 13) stay listed there; this file holds the items the user has picked and their agreed decisions.
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
| 6 and later | The open entries of the Phase 2 backlog (handoff, section 13); numbers are given when the user picks each one | various | not started |

Order: 1, 2, 3 (3a first, because it changes gameplay), 4 (after items 1 and 2, because it needs their Theme), 5 (the loading screens), then the backlog in the order the user picks.

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
- **Changed while building (user, 2026-10-12):**
  - A Sekiro-style **"PRESS ANY BUTTON"** title screen comes before the entries (any key, mouse button or gamepad button).
  - **Menu sounds** were added after all: `Sfx.Id.MENU_MOVE`, `MENU_OK`, `MENU_BACK` (the existing `audio/menu/` wavs).
  - **Menu music:** `audio/music/main_menu.ogg` (OGG, not the 25 MB wav; loop ticked in the Import dock), an `AudioStreamPlayer` named `Music` in the scene, faded in with the title and out on START or QUIT.
  - **Fonts:** system fonts only (Palatino Linotype, Book Antiqua, Georgia; Yu Mincho for the kanji). A bundled free-license pair is a later polish (Cinzel for Latin, Zen Antique or Shippori Mincho for the kanji).
  - **Highlight:** a radial gradient that fades on all four sides.
  - **QUIT** fades out and then closes.
- **Built:** files `scenes/ui/main_menu.tscn`, `scripts/ui/main_menu.gd`, `resources/ui_theme.tres`, plus the three menu ids in `scripts/audio/sfx.gd` and `audio/sfx_data.tres`. Editor steps: the main scene setting, the project version `0.1`, the music stream on the `Music` node.

### 2. Pause menu
- **What:** a pause menu with Resume, Options (the same empty panel) and Quit to Title. Item 3 adds a debug-only "Change arena" entry.
- **The game pauses** while it is open (unlike FromSoft; user, 2026-10-12).
- **Built as a scene** with the shared Theme and a process mode that keeps it running while the tree is paused.
- **Settled and built (user, 2026-10-12):**
  - **Key:** a new `pause` action on Esc and gamepad Start. It is consumed in `_input`, so the camera rig's Esc handling never sees it; the mouse is shown while paused and the previous mode restored on resume. Inside Options, Esc closes the panel first.
  - **Not while:** the player is dead (prompt or final death), the boss-slain screen shows, or the time scale is not 1 (hitstop, slow motion).
  - **Quit to Title:** a 0.4 s fade, then unpause, time scale 1 and the main menu's normal flow; no confirmation until saves exist.
  - **Look:** a centered column over a 65 percent dim, PAUSED in gold, smaller text than the main menu (entries 28, heading 22). Its own copy of the empty Options panel (to be merged with the main menu's when real settings exist).
  - **Sound:** the main menu's sounds through `Sfx.play_ui()` (voices that run while paused).

### 3. Arena chooser, fall zone and three base arenas
- **Why:** to test an enemy type or a movement setup without changing the Inspector, and later to offer arena gameplay as a side game or bonus mode (so an arena can carry a real name, description and image).
- **3a. Fall zone** (**built and tested 2026-10-12**; the build log, "Phase 2 item 3a", has what exists; the defaults below were kept: 25 percent, 0.35 s fades, 1.0 s invulnerability, a hurt sound, the camera snapped under black). A reusable `FallZone` (an `Area3D` placed under the playable area of each arena). Sekiro-style, not an instant death:
  - **Respawn point:** the player's own starting position and facing, recorded in `Player._ready()` the way `Enemy` records its spawn. A real map's checkpoints can replace it later.
  - **Penalty:** a share of max health, 25 percent as an `@export`, applied as ordinary damage through the `Combatant`. Falling cannot kill: it always leaves at least 1 HP (a safety net, not a death trap).
  - **On respawn:** a short fade to black and back, the velocity and any knockback cleared, the player put back in a normal state, and about a second of invulnerability (the resurrection one is reused).
  - **Edge cases:** nothing happens while the player is dead or in a deathblow.
  - **Enemies are not touched** (user, 2026-10-12): the zone ignores them, and `Enemy` keeps its own quiet "below -30 m, move back to spawn" check as it is.
- **3b. `ArenaData` and the chooser** (**built and tested 2026-10-12**; the build log, "Phase 2 item 3b", has what exists; `sort_order` was added to the resource). An `ArenaData` resource per arena: name, scene, optional image, description, category (test, movement, fighting) and a `debug_only` flag. The chooser reads a folder of them (a new arena is one new resource) and shows them in sections by category, with a plain placeholder where an image is missing.
  - **ARENAS entry in the main menu:** a debug build shows every arena; a release build shows the entry only if at least one arena is player-facing (`debug_only` off).
  - **The pause menu** gets a debug-only "Change arena".
  - **START is not the chooser:** START stays the real game's entry (the default arena for now).
- **3c-1 built and tested 2026-10-12, with the boss HUD addendum tested 2026-10-13** (the user's idea after the test: when a boss notices you, its name, health and posture show as a screen HUD and its floating bar hides; rules: the first boss to notice owns it, a lone hit on another boss passes it over, an area hit or a hit on the owner does not, lock-on does not; a ninth arena, "Two Bosses", tests it; build log, "Phase 2 item 3c-1 addendum") (the build log, "Phase 2 item 3c-1", has what exists). **3c decisions (user, 2026-10-12):** built in two parts, **3c-1** the fighting arenas and **3c-2** the movement arena. All new arenas start `debug_only` (flip it per arena when the real game flow exists). The fighting arena is a flat 30 x 30 m floor with **invisible walls** (40 m tall `StaticBody3D`s on physics layer 6, `Layers.INVISIBLE_WALL`, in the masks of the Player and Enemy bodies only, so the camera's spring arm never touches them and `LedgeSensor` ignores them) and a `FallZone` as a safety net. A Godot inherited scene cannot delete a base node, so the base arena has no enemy and **each variant adds its own enemy instance** and sets its `ai` and `boss`. Variants (all bosses, except the squad): Dummy, Soldier, Duelist, Aura, Repulser, Monk, Grappler (no default preset), plus **Squad** (3 non-boss soldiers and a boss monk). The **movement arena** is one scene with two zones: a training yard (stations: step-ups, gaps of rising width, a wall-jump shaft, a low tunnel for crouch and slide, a ledge wall for hang and shimmy, slopes and stairs) and a gauntlet that chains harder versions over a void to a finish pad; a fall sends the player back to the start of the run (no checkpoints yet). Sizes come from the real run speed, jump and ledge numbers. Original plan text:
- **3c. Three base arenas.** (1) the current jumbled test arena, kept as it is (`debug_only`); (2) a new **movement arena** for traversal (walls, ledges, gaps, slopes; no enemies); (3) a new **fighting arena** with flat, open ground. Variants are **inherited scenes of the fighting arena** that set only the enemy's `ai` preset (the monk, the grappler, the four presets in `ai/`). Claude builds a simple blockout of the two new maps for the user to refine in the editor.
- **3c-2 built and tested 2026-10-13** (the build log, "Phase 2 item 3c-2", has what exists). Changed while building (user): the one movement arena became **two scenes**, a Training Yard and a Gauntlet, each with its own start pad and its own `ArenaData`; the stairs got an **invisible smooth ramp** (the visible steps are only the look, to be followed by IK later) plus a raw "no ramp" station; the camera pivot **lowers while crouched** (`CameraRig.crouch_height_drop`); the chooser rows use the body font with a gap above each heading. The finish pad does nothing yet (no timer, no trigger).
- **Later, not in this item:** one fighting arena with a spawner that reads its enemy list from the arena data (waves, a picked opponent, challenge rules) for a real arena mode. The inherited scenes do not block it.

### 4. Migrate the in-game UI to scenes
- **Why:** the in-game screens are drawn in code (a choice made early, with no editor view and no art). Scenes with the shared Theme are the usual Godot practice: editor layout, one place for fonts and colors, live preview. Agreed 2026-10-12 as item 4, after the menus, because the Theme is made in items 1 and 2.
- **A refactor:** no visual or gameplay change. The look has to match the current one (positions, sizes, scaling with the window height); the user compares side by side.
- **In scope:** `DeathScreen` and `VictoryScreen` first (they already use real `Label` nodes; the screen shader and the timed fades and slow motion stay in code). `PlayerHud` only when real HUD art exists (today its health bar, pips and gourd are shapes drawn with code, so a scene would gain little).
- **Not touched:** `EnemyBar` and `DangerSymbol` (3D objects in the world, not screen UI), `DebugOverlay` (a dev tool) and `CrouchVignette` (a small shader overlay).
- **Care:** these screens are children of the Player in `player.tscn` and their tuned `@export` values live there, so the latest snapshot is needed to carry every value over. The build log and the handoff list each screen's values.
- **Built and tested 2026-10-13** (the build log, "Phase 2 item 4", has what exists). Only the two screens, as planned. The user asked why not the HUDs: `EnemyBar` is 3D (billboard quads in the world), so it is not screen UI; `PlayerHud` and `BossHud` are shapes drawn in code, so a scene gains little until real HUD art exists (they could be a later part 4b; not planned). Decisions (user, 2026-10-13): the death screen's English text (D E A T H and the two prompts) moved to the Theme's serif body font, the one visible change; the victory screen's ENEMY SLAIN keeps the Mincho font it already used (the Theme's `KanjiLabel` font); the shaders became `.gdshader` files.

### 5. Loading screens
- **Status:** built and tested 2026-10-13 (the build log, "Phase 2 item 5", has what exists). The user's idea (2026-10-13); the points marked *proposed* below were agreed with the full check and kept.
- **Why:** START and the arena choices use `change_scene_to_file`, which freezes the window with no feedback until the new scene is ready. (Quit to Title and the death reload already fade to black first.)
- **Two types (user):** (1) a **proper loading screen**: tips and a progress bar, in the shared Theme; (2) a **black-screen loading**: a plain black screen, no text.
- **Used for (user):** the proper one when starting the game and when choosing an arena; quitting needs only the black one.
- **Tips (user):** as many as we like, covering the game's quirks and helpful details, the obvious and generic ones too, kept in a file the user can edit easily (a CSV was suggested).
- **Proposed:** a static `SceneLoader` and one small loading scene, no autoload (the caller sets the target, then changes to the loading scene, which loads the target on a thread, shows the progress, keeps a minimum on-screen time so a fast load does not flash, then switches). Tips from a CSV read with `FileAccess.get_csv_line()` (import type "Keep File" and a `*.csv` export filter, so it is not turned into a translation); shuffled without repeats, with an optional context column. Layout reference: the Sekiro tip screen (title, text, a bar at the bottom right); the look is original, no artwork yet (a background slot later).

- **Built (agreed with the full check, user, 2026-10-13):**
  - `SceneLoader` (static, `Kind { PROPER, BLACK }`), the loading scene with the shared Theme, `LoadingTips` and `data/loading_tips.csv` (41 tips, contexts `any`, `fighting`, `movement`, `test`). START and ARENAS are PROPER; Quit to Title and CHANGE ARENA are BLACK; the death reload is unchanged.
  - Animated: fade in and out of black, tips cross-fade (every 8 s or on Enter, A or a click), the bar eases and fills over the minimum time (2.5 s), and an empty background slot that cross-fades and zooms. Nothing runs behind the screen: the arena enters the tree only after full black, and the player has control from the first frame.
  - Extra: `Player.start_invulnerable_time` (1.0 s) at every scene start; `DeathScreen` now covers its first frame and holds black for 0.3 s (`start_hold_time`); the project's Default Clear Color is black.
  - Not built: background art, loading music or sounds, per-tip icons, localization, enemies held idle during the grace period (waits for saves).

## 4. Backlog carried over (6 and later)

The open entries stay in section 13 of `docs/handoff.md`, which remains the single list: ledge enhancements, heal and death extras, lock-on extras, the sweep duck, enemy awareness, the stealth deathblow, enemy variety, the generic interact system, sound extras, more enemy body feedback, and real animation integration. When the user picks one, it gets the next item number here with its decisions, and is ticked off in both files. Items 1 to 3 do not change those entries.

## 5. Not in this phase

- Saves, a real map, quests and the game flow around them (START becomes NEW GAME when they exist).
- An Options screen with real settings (volume, sensitivity, key remapping).
- Music in the arenas and any sound work beyond the main menu's.
- A bundled title font and a drawn logo.
- Any change to the combat tuning or to `Enemy`'s own behavior.
