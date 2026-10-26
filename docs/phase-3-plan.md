# Phase 3: Feel and weight

Read this when working on Phase 3. Written 2026-10-20 from a discussion chat. **Status: planned, nothing built yet; discussed again on 2026-10-26 (section 7 holds the decisions of that chat, section 8 the placeholder marking).** Everything marked "agreed" was confirmed by the user in that chat; the numbers and details marked "default" are proposals until the item's full check (work agreement, section 7).

---

## 1. Goal and source

- **Goal:** make combat and movement feel weightier and more committed, with tools that let the user tune it by eye. Gameplay stays data-driven: `ActionData` and the action clock stay the truth, and real animation (Phase 6) only follows them.
- **Reference:** the open-source ELDEN RING combat sandbox written in Rust on Bevy (the user uploaded `ELDEN-RING-Combat-Rewrite-main.zip` on 2026-10-20). It was read for structure and ideas only: how actions define their windows, hit-stop, locomotion rates, hit reaction tiers, sound events per frame. On 2026-10-26 the user uploaded `ELDEN-RING-Combat-Rewrite-with-data.zip`, the same sandbox with its generated data (`src/sim/extracted.rs` and `assets/player_anims.bin`, about 52 MB; no sound data). That upload is the source of the numbers and the clips (section 7).
- **Rule (revised by the user 2026-10-20, replaces the first version):** until real animation arrives in Phase 6, the project may use **Elden Ring material as temporary placeholders**: the numbers (timings, windows, speeds, cancel and turn times; see `docs/phase-3-feel-reference.md`) and the animations of the ported Bevy sandbox, which animate the capsule and stick character. The user's own animations (done in Blender so far: dodge, walk, run, idle, sheathed and drawn, all directions; jump in progress) are **not used in the game until Phase 6**. Not covered by this revision: sounds, models and any other game data; ask before using them. Nothing is ever shipped to the public with a placeholder in it (next bullet). The first version of the rule (nothing extracted, feel targets in words only) is replaced.
- **Replacement gate (agreed 2026-10-20):** every Elden Ring placeholder is replaced by the user's own handcrafted work (a) when real animation is integrated in Phase 6, and (b) in any case **before the project goes public**: a Kickstarter, early access, a public demo, or anything else meant to attract public interest. Claude reminds the user of this at the start of every Phase 3 full check and when a Phase 3 milestone is finished, and keeps the checklist "Placeholders to replace" in `docs/handoff.md` up to date. Nothing placeholder ships past that point.
- **Why before game flow:** the work adds fields to `ActionData` and changes the action states. Doing that before more actions, enemies and quests are authored avoids redoing them.
- **Phase numbers shifted on 2026-10-20 (agreed):** this phase was inserted, the old Phases 3, 4 and 5 are now 4, 5 and 6, and Phase 2 stays as it was (its open backlog stays in handoff section 13, including the corner shimmy and the other ledge enhancements).

## 2. Milestones (each can be stopped after; the order is a suggestion)

### 3a. Tools
- **Feel overlay (agreed):** a debug-only readout of the current action and its time, with a timeline of which windows are open (locked, cancel, buffer, active hit, i-frames), and an i-frame tint on the character. It makes 3b and 3c tunable by eye.
- **`ActionData` validator (agreed):** editor warnings for broken timing, such as a cancel before the lock ends, a window past the duration, or an attack without an active hit window.

- **Placeholder animation import, 3a-3 (agreed as an item 2026-10-20, not yet checked):** a tool that converts the baked animations of the Bevy sandbox (`player_anims.bin`, joint positions at 30 fps, 38 joints, 1479 clips, plus the orientation axes of the head and the two weapon points) into data Godot can play, and a player that animates the capsule and stick character with them, driven by the action clock. A stand-in until Phase 6; gameplay still follows `ActionData`. Its own full check settles the format, how the stick figure is drawn (the 3d mannequin steps share this), and which clip backs which action. **Updated 2026-10-26:** mannequin step (a), the figure itself, is built here (the clips need a figure to show them); the clip mapping, the clip-length rule and the placeholder marking are in sections 7 and 8.

### 3b. Action data
New `ActionData` fields default to today's behavior, so nothing changes until an action is tuned.
- **Turn control inside actions (agreed):** windows where the character cannot turn, and (from, to, degrees per second) overrides, with a default rate for the rest. Early tracking and a late commit make a swing feel heavy.
- **Per-input cancel times (agreed):** separate earliest-cancel times for a light attack, a heavy attack, dodge, jump, guard and plain movement, and a time before which presses are ignored instead of queued. One queued input, the newest wins. How this maps onto the existing `cancel_window` and `buffer_window` is decided at the full check. The deflect and guard timing stay as they are (see section 3).
- **Motion curves (agreed):** a curve of forward and sideways motion per action (a step-in burst, then a quick settle) as an alternative to `move_speed` with a linear fade. A curve, when set, is used; otherwise the speed and fade work as now.
- **Multi-hit attacks (agreed):** an action can have a list of hits, each with its own window, damage, posture damage, knockback and hitstop.

### 3c. Locomotion and reactions
- **Per-fighter hitstop (agreed):** the attacker and the target freeze for a moment; other characters, the camera and the particles keep running; the freeze is scaled; input is still read during it. Replaces the whole-game `Engine.time_scale` slowdown for hits (what stays global, if anything, is decided at the full check).
- **Locomotion tuning (agreed):** acceleration and deceleration (now 50 and 60), turn rates per state (a slower turn while sprinting, one for locked-on), and a short brake when stopping from a run or sprint. Done as a tuning session while the user plays. Numbers from the reference are not used, only the idea of the asymmetry.
- **Landing tiers and hit reaction tiers (agreed):** light and heavy landings by fall height, each with a short lockout; hit reactions in strengths (flinch, stagger, large stagger, knockdown) chosen by the attack's data; directions come with real animation.
- **Lock-on range hysteresis (agreed):** acquire a target within one range, drop it only past a larger one, so it does not flicker at the edge. Check the current lock-on first.
- **Small details (agreed):** walk when the stick is lightly tilted and run past a threshold; locked-on jumps and landings in four directions; a separate fall start when walking off a ledge; upper-body layers (guard, carry) that blend in and out separately from the legs (pairs with the mannequin).

### 3d. Look and sound
- **The mannequin (agreed idea, built in steps):** a figure of primitives (sphere head, capsule torso, pelvis, capsule limbs on joints, a shield on the left arm) instead of one capsule with a nose, used by the player and by enemies with a tint per type. Steps: (a) the figure replaces `Body` and `Nose` (**moved into 3a-3 on 2026-10-26**); (b) idle sway, a procedural walk and run by speed, a lean into movement, crouch; (c) arms reach the sword grip and hold the shield on guard, using the existing sword poses (this absorbs `ReachArms` and `HealArm`); (d) poses for the other states, one state at a time. It is a stand-in until the Blender pipeline of Phase 6; gameplay does not change. Steps (b) to (d) may shrink: clips animate the actions that have one, and procedural poses are needed only for the actions without a clip.
- **Foot placement (agreed):** feet fitted to stairs and slopes up to a step height, the body settling smoothly on new heights. Pairs with the mannequin's legs.
- **Frame-driven sound (agreed):** sound events at times in an action (the swing, a footstep), each sound choosing among several recordings with a small random pitch and level variation each time, and looping clips firing on every pass. The Phase 2 sound extras (`charge_loop`, `aura_loop`, footsteps per surface) can use it.

## 3. Decisions: what is not in Phase 3 (agreed 2026-10-20)

- **No guard arc and no block raise time.** They would make the deflect less generous than in Sekiro and in the Executor of Elden Ring Nightreign; the deflect timing stays as it is.
- **No simulation split** (the game logic as a pure 60 Hz state machine apart from the engine). Rejected: it would mean rewriting everything that uses Godot's physics, navigation and areas, and its benefits (netcode, exact replays) do not fit a single-player game with a streamed world.
- **No input recorder and replayer.**
- **No stamina, equip-load rolls, weapon classes or paired weapons:** the design is posture-based.
- **Sparring dummy (picked 2026-10-26, built in 3c):** a dummy that cycles telegraphed attacks by strength, to test the hit tiers. **Not picked:** a scripted tour of all moves.
- **Not Phase 3:** the corner shimmy and the other ledge enhancements, the lock-on HUD extras and the other Phase 2 backlog entries (handoff section 13), and enemy variety (Phase 5).

## 4. Files likely touched (confirm at each milestone's full check)

`scripts/resources/action_data.gd` and the `.tres` files of the actions; the action states in `scripts/player/states/` and the enemy attack code; `scripts/player/player.gd` and `locomotion_state.gd`; `scripts/combat/hitstop.gd`, `combatant.gd` and `hitbox.gd`; `scripts/player/lock_on.gd`; `scripts/core/sfx.gd`; `scenes/player/player.tscn` and `scenes/enemy/enemy.tscn` for the mannequin; new scripts for the overlay, the validator, the mannequin and the placeholder animation import (3a-3). Also (2026-10-26): `docs/placeholders.md` (kept up to date at every milestone), the offline converter tool (its location is open), `assets/placeholder/` for the game-derived data, and one new `ActionData` field for the placeholder source (section 8).

## 5. Open points (ask once at the full check of the milestone they belong to)

- 3b: how the new per-input cancel fields relate to `cancel_window` and `buffer_window`, and whether old `.tres` files are migrated or keep working unchanged.
- 3c: what, if anything, stays on the global slowdown (a deathblow, for example); the thresholds for walking, and the landing heights.
- 3d: the mannequin's proportions and colors, whether enemies share one figure, and the sound event data format.
- 3a-3: the converted format (a Godot `Animation` with position tracks per joint, or a compact resource sampled by the mannequin script), where the converter lives, how the stick figure is drawn, and which clip backs which action.
- Settled on 2026-10-26 (section 7): the sparring dummy (yes, in 3c), what stays on the global slowdown (the deathblow), the clip-length rule (a uniform stretch) and the figure moving into 3a-3. The points still open are in section 7.8.

## 6. Relation to later phases

Real animation (Phase 6) will need some numbers retuned (swing timing, turn rates); the data-driven setup keeps that cheap. Phase 3 is a good base, not a finished feel.

## 7. Decisions of the 2026-10-26 discussion (agreed by the user unless marked "proposed")

Discussion only, no code. Source: `ELDEN-RING-Combat-Rewrite-with-data.zip` (the sandbox with its generated data), read together with this plan and `docs/phase-3-feel-reference.md`.

### 7.1 What the data showed
- **The sandbox's `ActionDef` is almost our 3b.** It has `input_from` (and `input_dodge_from`), one cancel time per input (light, heavy, dodge, jump, guard, move, left hand), `iframes`, a list of `hits` (each with its own window, motion value, hit-stop and capsule), a `charge` window, `no_turn` spans, `turn` overrides as (from, to, degrees per second) and a per-frame `motion` table (cumulative left, up, forward metres). So the 3b design is confirmed; the open part is how it sits next to `cancel_window` and `buffer_window`.
- **The clip bake** (`tools/bake_anims.py`): 38 joints (counted in the script; the clip count of 1479 in section 2 is from the earlier read and was not re-checked), joint positions only at 30 fps, full axes only for the head and the two weapon points. So the figure is drawn between joint positions (sticks and capsules), not skinned. The bake mirrors the game's left-handed space into +Z forward; Godot faces -Z, so the converter flips it.
- **Our actions are about half as long as theirs** (details in `docs/phase-3-feel-reference.md`, section 8).

### 7.2 Decisions
1. **Feel level:** a blend. Elden Ring's structure with its times scaled to about 60 to 70 percent (a placeholder number), tuned by playing. The feel target stays Sekiro-snappy.
2. **Which clip for which action** (table in 7.3). Actions with no Elden Ring clip get **made-up placeholder poses** that Claude authors (joint positions), and the user tests them.
3. **Existing files:** every new timing field is optional and defaults to today's behavior, so no old `.tres` changes until the user tunes it.
4. **Turning inside attacks:** a little steering at the start of a swing, then the character commits and cannot turn (the 3b turn windows).
5. **Hit freeze:** per fighter (3c); only the two fighters freeze. The deathblow keeps the whole-game slowdown.
6. **Walking, landing and lock-on:** a light stick tilt walks and a harder one runs; a short fall gives a light landing and a long fall a heavy one; lock-on picks a target at one range and drops it at a larger one (the reference's 15 m and 22 m are estimates). All numbers are tuned by playing.
7. **The mannequin:** one figure of simple shapes for the player and the enemies, with a tint per enemy type. Step (a), the figure, moves into 3a-3. Steps (b) to (d) stay in 3d and may shrink.
8. **Sparring dummy:** yes, in 3c, to test the hit reactions.
9. **Order:** the feel overlay and validator (3a), then 3b, then the animation import with the figure (3a-3), then 3c, then 3d.
10. **Sounds:** the project's current placeholder sounds. No Elden Ring sounds. 3d builds the frame-driven sound system (several recordings per sound, small random pitch and level variation) with the current sounds.
11. **Tuning flow:** the user tests, asks Claude which numbers to change and where, and tunes them in the editor (the feel overlay and the validator help). Claude edits a tuned `.tres` only with the latest snapshot (work agreement, section 3).
12. **Clip length rule (agreed as the default):** each clip is stretched evenly to fit its action's length. This works because the scaled times shrink by about the same ratio. A looping locomotion clip follows speed instead (a 3c rule). **Later option, only if a telegraph looks wrong (first for enemy attacks, which the player reads to dodge or deflect):** "hit-sync", a piecewise time warp with anchors at the clip's start, its hit start and its end, mapped to the action's start, `active_hit` start and duration, with the stretch clamped (about 0.6x to 1.6x, a placeholder). The helm splitter's dive has no fixed length, so its clip plays the swing and holds the last pose until landing.
13. **The clock stays ours** (not the FromSoftware way, where the animation is the clock and windows are marked on its timeline). Reasons: many actions have no clip, enemy attacks should be tunable with a capsule, and flipping the clock would rewrite the combat code before Phase 6. In Phase 6 the workflow can be FromSoftware-like anyway: animate in Blender first, then set the windows to match. The feel overlay is our timeline view.
14. **Placeholder marking:** section 8.

### 7.3 Clip mapping (proposed from the data; confirmed at the 3a-3 full check; "uchigatana" means one-handed, the nearest to our katana)

| Our action | Elden Ring clip | Note |
|---|---|---|
| Ground combo 1 to 5 | the light chain (5 swings) | times scaled |
| Hold attack (charged thrust) | heavy 1, charged | to confirm |
| Dash attack | the run light attack | to confirm |
| Dodge and backstep | the light-load roll and the backstep | |
| Crouch attacks | the crouch attack | to confirm |
| Air tap loop | the jump light attack | |
| Helm splitter (the dive) | the jump heavy attack (`a029_031230`) | plays the swing, holds the last pose until landing |
| Enemy thrust | heavy 1 | verify that it reads as a thrust, else propose another clip or a made-up pose |
| Enemy sweep | the crouch attack | verify that it is low enough to jump |
| Enemy grab | none | made-up pose |
| Slide, wall hug, ledges (hang, climb, shimmy), taunt, throw, sheathe, draw slash, deflect poses, charged iai | none | made-up poses; the code-drawn sword poses (`SwordVisual`) stay until the figure's arms can follow them (3d step c) |

Enemies share the figure and get clips only for the actions in this table.

### 7.4 Why the mannequin is partly in 3a-3
A clip is only joint positions; without a figure with a head, torso, arms and legs there is nothing to see. The figure's proportions follow the clips' skeleton (Elden Ring's), and the user's own rig replaces it in Phase 6.

### 7.5 Not decided, for the full checks
- 3b: how the per-input cancel fields relate to `cancel_window` and `buffer_window`.
- 3a-3: the converted format (a Godot `Animation` with position tracks, or a compact resource), where the offline converter lives, how the 52 MB bin is shrunk, how the figure is drawn, and the figure's proportions against our capsule and the enemy sizes.
- Whether the thrust and sweep clips read correctly (verify in the data and by eye).
- The exact shape of the `ActionData` placeholder field (a single value or flags).
- The validator's rule list, and the sound event data format.
- Whether private test builds for friends may contain the clips (decide at the first such build; public builds never do).

(This list is the "still open" list that section 5 refers to as 7.8.)

## 8. Marking placeholders (agreed 2026-10-26)

Four layers plus a final check, so the user can always see what is a placeholder and where it came from:
1. **One register:** `docs/placeholders.md`, a table with one row per placeholder: what it is, where it lives, its source (Elden Ring numbers, an Elden Ring clip, a made-up pose, the current sounds), what replaces it and its status. Claude keeps it up to date at every milestone and when a milestone is finished (the existing reminder rule).
2. **A tag in the files:** every placeholder carries the word `PLACEHOLDER` and its source in a comment, for example `PLACEHOLDER(ER numbers)`, `PLACEHOLDER(ER clip)`, `PLACEHOLDER(made-up pose)`. One search finds them all.
3. **A tag on the action:** `ActionData` gets one small field, the placeholder source (none, Elden Ring numbers, Elden Ring clip, made-up pose), shown in the Inspector. The feel overlay shows it in game, and the validator warns when an action uses an Elden Ring clip without the tag.
4. **One folder for game-derived data:** `assets/placeholder/` holds the converted clips and anything else taken from Elden Ring. Deleting it removes every Elden Ring placeholder. The export settings leave it out of public builds and it stays out of any public repository.

**Final check before anything goes public:** a placeholder report (a debug tool or a validator mode) lists everything still tagged; nothing from Elden Ring may be on it. This is the replacement gate of section 1.
