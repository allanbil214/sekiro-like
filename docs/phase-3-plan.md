# Phase 3: Feel and weight

Read this when working on Phase 3. Written 2026-10-20 from a discussion chat. **Status: 3a part 1 (feel overlay and validator), 3a-4 (debug menu), 3b-1 (cancel times), 3b-2 (turn control), 3b-3 (motion curves) and 3b-4 (multi-hit) built and tested 2026-10-27 (3b complete), 3a-3a (clip converter and viewer) built and tested 2026-10-27, 3a-3b split in three on 2026-10-27 (section 10.5), 3a-3b (the figure on the player, its arms and enemies) built and tested 2026-10-27, 3a-3c-1 (clips drive the figure: ground combo, dash and crouch attacks) built and tested 2026-10-28 (section 10.6), 3a-3c-2 (dodge, air attacks and helm splitter on clips) built and tested 2026-10-28 (section 10.7), 3a-3c-3 (the player's charged thrust on clips) built and tested 2026-10-28 (section 10.8), 3a-3c-4 (enemy bursts, thrust and sweep on clips) built and tested 2026-10-28 (section 10.9), 3c-1 (per-fighter hitstop, section 11) and 3c-2a (locomotion clips, section 12) and 3c-2b (locomotion tuning, section 13) built and tested 2026-10-28, 3c-3a (jump, fall and landing clips and landing tiers, section 14) built and tested 2026-10-29, 3c-3b-1 (the player's hit reactions and the dummy's strengths, section 15) and 3c-3b-2 (enemy reaction clips by tier, section 16) built and tested 2026-10-30, 3c-4a (light-tilt walk, section 17) built and tested 2026-10-30, the rest planned; discussed again on 2026-10-26 (section 7 holds the decisions of that chat, section 8 the placeholder marking).** Everything marked "agreed" was confirmed by the user in that chat; the numbers and details marked "default" are proposals until the item's full check (work agreement, section 7).

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
- **Debug menu, 3a-4 (added and built 2026-10-27):** one debug-only menu (F1) that holds every debug switch, so options are not scattered over keys and Inspector checkboxes. New debug options are one line in `DebugOptions.build()`.

- **Placeholder animation import, 3a-3 (agreed as an item 2026-10-20, not yet checked):** a tool that converts the baked animations of the Bevy sandbox (`player_anims.bin`, joint positions at 30 fps, 38 joints, 1479 clips, plus the orientation axes of the head and the two weapon points) into data Godot can play, and a player that animates the capsule and stick character with them, driven by the action clock. A stand-in until Phase 6; gameplay still follows `ActionData`. Its own full check settles the format, how the stick figure is drawn (the 3d mannequin steps share this), and which clip backs which action. **Updated 2026-10-26:** mannequin step (a), the figure itself, is built here (the clips need a figure to show them); the clip mapping, the clip-length rule and the placeholder marking are in sections 7 and 8.

### 3b. Action data
New `ActionData` fields default to today's behavior, so nothing changes until an action is tuned.
- **Turn control inside actions (agreed):** windows where the character cannot turn, and (from, to, degrees per second) overrides, with a default rate for the rest. Early tracking and a late commit make a swing feel heavy.
- **Per-input cancel times (agreed):** separate earliest-cancel times for a light attack, a heavy attack, dodge, jump, guard and plain movement, and a time before which presses are ignored instead of queued. One queued input, the newest wins. How this maps onto the existing `cancel_window` and `buffer_window` is decided at the full check. The deflect and guard timing stay as they are (see section 3).
- **Motion curves (agreed):** a curve of forward and sideways motion per action (a step-in burst, then a quick settle) as an alternative to `move_speed` with a linear fade. A curve, when set, is used; otherwise the speed and fade work as now.
- **Multi-hit attacks (agreed):** an action can have a list of hits, each with its own window, damage, posture damage, knockback and hitstop.

### 3c. Locomotion and reactions
- **Locomotion clips (agreed by the user 2026-10-28 as a 3c item of its own; built and tested 2026-10-28 as 3c-2a, section 12):** the converted idle, walk (four directions), run, sprint and crouch clips (`player_clips.bin`) play on the player's figure out of combat, a looping clip's playback rate following the real speed (section 7.2, item 12), and replace the procedural walk of 3d step (b). Its full check settles the speed-to-rate mapping, the blend into and out of action clips, lock-on strafing with the four walk clips, and the enemies. The split of 3c and its order are decided at the 3c full check (proposed: per-fighter hitstop, locomotion tuning with these clips, landing and hit tiers with the sparring dummy, the small details).
- **Per-fighter hitstop (agreed; built and tested 2026-10-28 as 3c-1, section 11):** the attacker and the target freeze for a moment; other characters, the camera and the particles keep running; the freeze is scaled; input is still read during it. Replaces the whole-game `Engine.time_scale` slowdown for hits (what stays global, if anything, is decided at the full check).
- **Locomotion tuning (agreed; built and tested 2026-10-28 as 3c-2b, section 13):** acceleration and deceleration (now 50 and 60), turn rates per state (a slower turn while sprinting, one for locked-on), and a short brake when stopping from a run or sprint. Done as a tuning session while the user plays. Numbers from the reference are not used, only the idea of the asymmetry.
- **Landing tiers and hit reaction tiers (agreed):** light and heavy landings by fall height, each with a short lockout; hit reactions in strengths (flinch, stagger, large stagger, knockdown) chosen by the attack's data; directions come with real animation.
- **Lock-on range hysteresis (agreed):** acquire a target within one range, drop it only past a larger one, so it does not flicker at the edge. Check the current lock-on first.
- **Small details (agreed):** walk when the stick is lightly tilted and run past a threshold; locked-on jumps and landings in four directions; a separate fall start when walking off a ledge; upper-body layers (guard, carry) that blend in and out separately from the legs (pairs with the mannequin).

### 3d. Look and sound
- **The mannequin (agreed idea, built in steps):** a figure of primitives (sphere head, capsule torso, pelvis, capsule limbs on joints, a shield on the left arm) instead of one capsule with a nose, used by the player and by enemies with a tint per type. Steps: (a) the figure replaces `Body` and `Nose` (**moved into 3a-3 on 2026-10-26**); (b) idle sway, a procedural walk and run by speed, a lean into movement, crouch; (c) arms reach the sword grip and hold the shield on guard, using the existing sword poses (this absorbs `ReachArms` and `HealArm`; **the arm part was pulled forward into 3a-3b-2 on 2026-10-27**, section 10.5; the shield and the guard arms stay here); (d) poses for the other states, one state at a time. It is a stand-in until the Blender pipeline of Phase 6; gameplay does not change. Steps (b) to (d) may shrink: clips animate the actions that have one, and procedural poses are needed only for the actions without a clip.
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

- 3b: settled on 2026-10-27 (section 9): the cancel fields sit beside `cancel_window` and `buffer_window`, and old `.tres` files keep working unchanged.
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

## 9. Decisions of the 2026-10-27 3b full check (agreed by the user; nothing of 3b is built yet)

Read together with section 2 (3b) and the code of `AttackState`, `DodgeState`, `ActionState`, `ActionRunner`, `InputBuffer` and `Hitbox`.

### 9.1 What the code does today (so the defaults are exact)
- In `AttackState`, dodge and jump cancel from time 0 of a swing, blocked only while the hit window is open. `cancel_window.x` (or `locked_until`) only sets when the next attack of the combo may start; `buffer_window` only sets when an attack press is accepted for chaining.
- Turning is a smoothing factor (`Player.turn_speed`, 18), not degrees per second. Attacks steer until `active_hit.x`, then lock.
- There is no early exit into plain movement: an action runs to `duration`.
- The input buffer is one timestamp per button (0.15 s); only the attack press is tracked as "queued".
- **Multi-target already works:** the `Hitbox` sweep hits every hurtbox it overlaps, each once per swing (`_hit_set`). A wide slash hits everyone in range. 3b "multi-hit" is something else: one action hitting the **same** target more than once (a list of hits, each with its own window and numbers).

### 9.2 Design principle (the user, 2026-10-27)
- **The player stays Sekiro-style by default:** an attack can be cancelled into dodge or jump any time outside its active hit window. The Elden Ring multiplayer rule (no cancel until the swing has happened) is **not** forced on anything; it appears on a move only if a per-input time is set on it (for example `cancel_dodge = 0.9`).
- Every new field is optional and off by default (-1, an empty list, or no curve), so no old `.tres` changes behavior until it is tuned.

### 9.3 The four parts and their fields (proposed names, final at each sub-step's full check)
1. **Per-input cancel:** `input_from` (presses before it are discarded, not buffered), `cancel_attack`, `cancel_dodge`, `cancel_jump`, `cancel_guard`, `cancel_move`. A set field overrides the old rule for that one input; `cancel_window` and `buffer_window` stay. One queued input, the newest press wins (needs an accessor on `InputBuffer`). No heavy-attack cancel (one attack button; a hold is the thrust). Read by `AttackState` and `DodgeState`; slide, taunt and throw keep `can_cancel`.
2. **Turn control:** `turn_rate` (degrees per second), `no_turn` (windows), `turn_overrides` (from, to, degrees per second). No-turn beats an override, which beats the default rate; any turn field set replaces the old "steer until the hit starts" rule for that action. Player ground and air attacks only (a new `Player.face_direction_rate()`); enemies keep `attack_turn_speed`.
3. **Motion curves:** `motion_forward` and `motion_side` (`Curve`, x in seconds, y in m/s, side positive to the right). A set curve replaces `move_speed` and the fade; computed in `ActionRunner`, used by the player and by the enemy's forward motion.
4. **Multi-hit:** a new `HitSpec` resource (window, damage, posture damage, knockback, hitstop) and `hits: Array[HitSpec]` on `ActionData`. When the list is not empty, hit detection uses it and the hitbox is closed and reopened between hits. `active_hit` stays as the overall span (the sword visual, enemy telegraphs and the overlay read it); the validator checks that the hits lie inside it. Player attacks through `ActionState`; enemies are not wired for multi-hit yet.
- The feel overlay gets a TURN row and ticks for the per-input cancel times; the validator gets rules for the new fields.

### 9.4 Order and tuning
- **Four deliveries, each tested before the next:** 3b-1 cancel times, 3b-2 turn control, 3b-3 motion curves, 3b-4 multi-hit. Each has its own full check and zip.
- **First tuning pass:** `attack_1.tres` only (edited from the latest snapshot), with the Elden Ring numbers scaled to about 65 percent (a placeholder number), tagged `placeholder_source = ER_NUMBERS`, so there is something to feel. The other actions wait until the user likes it. In 3b-1 only the cancel times are set; everything else on `attack_1` keeps the Sekiro default.
- **Switch for the original timing (agreed 2026-10-27):** the new 3b fields can be turned off while playing, so the original behavior can be compared at any time (this works because 3b-1 adds only new fields and leaves the existing timings alone). It is an entry in the debug menu (not a separate key), ON by default, and a small "FEEL FIELDS OFF" tag stays on screen in debug builds while it is off. In a release build the fields are always on. Later changes to existing timings (swing lengths) would need a real copy of the original set instead.
- **Test values (agreed 2026-10-27):** the first values on `attack_1` to `attack_5` (option B) start from the Elden Ring numbers scaled to about 65 percent and are adjusted so the difference between ON and OFF is obvious; they are a test, not tuned values.
- **Not in 3b:** heavy-attack cancel, enemy turn control, enemy multi-hit, per-fighter hitstop (3c), the animation import (3a-3), tuning the other actions.

## 9.5 3b-1 built and tested (2026-10-27), with the changes from the plan

- **Built:** the fields `input_from`, `cancel_attack`, `cancel_dodge`, `cancel_jump`, `cancel_guard`, `cancel_move` and the new `cancel_item` (the gourd and `use_item`, ground attacks only, presses before the time ignored). Details: `docs/built-reference.md` and the build log.
- **Changed from 9.3 and 9.4 (agreed with the user the same day):** the debug-menu toggle covers only the Elden Ring-like test values (actions tagged `ER_NUMBERS`), not the system, which is always on. Defense stays Sekiro-style: dodge, jump and guard are not delayed on any action (their fields exist but are unset). `input_from` discards attack presses only. Defense beats attack in the queue. The test values on `attack_1` to `attack_5` are `input_from`, `cancel_move` and `cancel_item` only; the chain (`cancel_attack`) stays at the original times because the earlier chain felt too fast.
- **Later:** buffering heal and item presses, `cancel_item` for air attacks and other actions, and values for the other actions wait until the user asks.

## 9.6 3b-2 built and tested (2026-10-27)

- **Built:** `turn_rate`, `no_turn` and `turn_overrides` on `ActionData`, read by `AttackState` and `AirAttackState` through `ActionState._turn_toward_input()`; a constant turn speed in deg/s (`Player.face_input_rate()`); a TURN row in the feel overlay and validator rules. Details: `docs/built-reference.md` and the build log.
- **As planned (9.3):** any turn field replaces the old steer-until-the-hit rule; no-turn beats an override, which beats the default rate; enemies are not wired. **Decided at the full check (2026-10-27):** the default rate is 360 deg/s (a placeholder), the lunge direction follows the input only while turning is allowed, the wait and charge phases keep the old free steering, and the fields follow the F1 ER FEEL toggle.
- **Test values:** the sandbox's one-handed light chain spans on `attack_1` to `attack_5`, stretched to each attack's own hit start (not a flat 65 percent). Tuned by feel; the user found them good.
- **Next:** 3b-3 (motion curves), then 3b-4 (multi-hit).

## 9.7 3b-3 built and tested (2026-10-27)

- **Built:** `motion_forward` and `motion_side` (`Curve`) on `ActionData`, read through `ActionRunner.motion_velocity()` by `ActionState._apply_action_movement()` (the player) and by the enemy's lunge (forward only); a speed-curve MOVE row in the feel overlay and validator rules. Details: `docs/built-reference.md` and the build log.
- **As planned (9.3):** a set curve replaces `move_speed` and the fade; the enemy uses the forward curve. **Decided at the full check (2026-10-27):** the curve gets the usual lunge multipliers, the body decelerates after the end of its domain, the ledge check uses the curve's peak, and the fields follow the F1 ER FEEL toggle.
- **Changed from the check:** the test curves keep the sandbox's motion shape but are scaled to each attack's current travel instead of keeping the sandbox speeds (time stretched alone would have halved the travel of attacks 2 to 5), so ON versus OFF differs only in shape.
- **Next:** 3b-4 (multi-hit).

## 9.8 3b-4 built and tested (2026-10-27)

- **Built:** `HitSpec` and `ActionData.hits`, read by `ActionState._update_hit()` through `ActionRunner` (`hit_index`, `make_hit(..., spec)`); the overlay's HIT row shows each hit; validator rules. Details: `docs/built-reference.md` and the build log.
- **As planned (9.3):** `active_hit` stays the overall span; player attacks only. **Decided at the full check (2026-10-27):** -1 in a `HitSpec` field means the action's value; the gaps between hits still block dodge and jump cancels; the swing sound and visual hook run on the first hit only; each hit is resolved on its own by the guard; the fields follow the F1 ER FEEL toggle.
- **Test values:** two hits on `attack_5` (made up, summing to the old damage and posture). The other actions have no hit list.
- **Next:** 3a-3c-2 and 3a-3c-3 (the rest of the clips), then 3c and 3d. 3b is complete.

## 10. 3a-3 plan: what the 2026-10-27 re-read of the data showed (split agreed 2026-10-27; 3a-3a built and tested, 3a-3b and 3a-3c planned)

Read from `ELDEN-RING-Combat-Rewrite-with-data.zip` (the split `.z01` + `.zip` joins with `zip -s 0 <name>.zip --out all.zip` on a writable copy) and `tools/bake_anims.py`, together with section 7.

### 10.1 Facts about the data (checked)
- `assets/player_anims.bin` (about 52 MB): header `ERAN`, then 38 joints, 3 oriented joints (`Head`, `R_Weapon`, `L_Weapon`) and **1479 clips**, 92,112 frames in all; each frame is 141 floats (38 joints x 3, plus 3 x 9 axes), little endian, 30 fps; each clip has a name, a blend length (6 to 10 frames) and a frame count. Only about 30 clips are needed, so the converted file is a few MB at most.
- The sandbox space is +X left, +Y up, +Z forward (already mirrored by the bake from the game's left-handed space). Godot is +X right, +Y up, -Z forward, so the converter **rotates 180 degrees about Y** (x, z negated): a rotation, not a mirror.
- Confirmed clip names: the one-handed light chain `a029_030000`, `030010`, `030020`, `030030`, `030040` (70, 60, 69, 65 and 88 frames, so 2.0 to 2.9 s against our 0.9 to 1.5 s: the uniform stretch of 7.2 item 12 applies), the jump heavy `a029_031230` (31 frames), walk `a000_020000` (idle-start 41 frames) and run `a000_020100` (23 frames, a loop). The other ids of the table in 7.3 (roll, backstep, crouch attack, run light attack, jump light attack, heavy 1) are looked up in `src/sim/extracted.rs` at the 3a-3a check.
- The sandbox's code is MIT-licensed; the clip data is derived from the game and counts as an Elden Ring placeholder (`assets/placeholder/`, never public).
- The sandbox's `ActionDef` shows the same turn and motion data as 3b (already used); it also has the blade capsules per hit, not used by us.

### 10.2 The `Body` and `Nose` coupling (why the figure is its own delivery)
`Player` reads `$Visual/Body` and `$Visual/Nose` directly (crouch resizing of the capsule mesh and its tween, `PlayerBodyReaction`, the bobblehead enemy feedback), and `enemy.tscn` has the same two nodes. A figure that replaces them must keep the crouch height, the reactions and the sword and arm visuals working, so it is built and tested alone before any clip drives it.

### 10.3 Proposed split (three deliveries, each with its own full check and test)
1. **3a-3a, converter and viewer:** an offline Python converter (`tools/placeholder/`, run once on the PC; Claude also delivers the generated file) writes only the mapped clips to one compact binary, `assets/placeholder/player_clips.bin`, with a loader script; an F1 debug entry opens a viewer scene that plays any clip on a figure of simple shapes. No link to gameplay. The user judges the clips; the clip-to-action table of 7.3 is confirmed here.
2. **3a-3b, the figure in the game:** the mannequin replaces `Body` and `Nose` on the player (an F1 toggle brings the capsule back), keeping crouch, body reactions and the sword visuals; enemies follow with a tint per type. Register row P5.
3. **3a-3c, clips drive the figure** (split in three 2026-10-28, section 10.6): a clip player follows the action clock (uniform stretch); first the ground combo (3a-3c-1, built and tested 2026-10-28), then dodge, the air attacks and the helm splitter (3a-3c-2), then the enemy thrust and sweep (3a-3c-3). Register rows P2 and P3. Made-up poses (P4) stay a later step.
- **Defaults proposed:** a compact binary of joint positions sampled by a script (not Godot `Animation` resources); the converter outside `res://` logic, the output under `assets/placeholder/`, left out of public exports; locomotion clips follow speed (3c).
- **Not in 3a-3a:** the figure in the game, any gameplay link, made-up poses, enemies, sheathe and guard arms (3d).

### 10.4 3a-3a built and tested (2026-10-27)

- **Built:** the converter, `player_clips.bin` (27 clips, 0.84 MB), `PlaceholderClips`, `MannequinFigure` and `ClipViewer` with the F1 "Clip viewer" option. Details: `docs/built-reference.md` and the build log.
- **As proposed (10.3):** a compact binary of joint positions sampled by a script; the converter outside the game code, the output under `assets/placeholder/`; a uniform stretch to the action length (previewed with End in the viewer).
- **Decided at the check:** the clip table (see the build log; the crouch attack is the curved sword's `a028_030310` because the uchigatana has none); the viewer stands in the arena in front of the player, not in a separate scene.
- **Tested by the user:** the clips look like the original and fine.
- **Still open for 3a-3c:** whether `heavy1` reads as the enemy thrust and `crouch_attack` as a sweep low enough to jump (judge on the enemy); how the figure's proportions fit our capsule and the enemy sizes (3a-3b); the made-up poses (P4).
- **Next:** 3a-3b, the figure in the game (replaces `Body` and `Nose`; an F1 toggle brings the capsule back), with its own full check.

## 10.5 3a-3b split in three (agreed 2026-10-27; all three built and tested 2026-10-27; 3a-3c is next)

Decided at the 3a-3b full check, after the user asked why the figure's own arms were not used.

- **Why:** with the code-drawn box arms (`SwordVisual`, `ReachArms`, `HealArm`) left in place, the figure's idle arms would look doubled during swings. Using the figure's arms removes that, and there is no technical reason against it (the plan only parked it in 3d step c to keep 3a-3b small).
- **3a-3b-1, the figure on the player:** `scripts/player/player_figure.gd` (glue), a `Figure` node under `Visual`, held poses (`idle` standing, `crouch_idle` crouched, blended over `crouch_transition_time`), scaled so the head top is at `stand_height`, body twist applied to the whole figure, the i-frame tint on the figure, an F1 "Mannequin figure" toggle (ON by default; OFF shows the capsule and nose, which stay in the scene, hidden while the figure is on). The figure's blade is hidden (the code-drawn sword stays). The box arms stay for this delivery.
- **3a-3b-1 built and tested (2026-10-27), as described.** Details: `docs/built-reference.md` and the build log.
- **3a-3b-2 built and tested (2026-10-27), as described** (details: `docs/built-reference.md` and the build log). Planned text:
- **3a-3b-2, the figure's arms:** a two-bone solve (shoulder, elbow, hand) per arm toward the code-drawn hand: the sword arm follows `SwordVisual`'s hand, the left arm follows `HealArm` while healing, and `ReachArms` covers the reach and the choke. The box arms of those three scripts are hidden while the figure is on (the toggle brings them back with the capsule). The three scripts expose their hand point; sword poses, timings and `ActionData` stay untouched. Needs a tuned default elbow direction. The shield and the guard arms stay in 3d step (c).
- **3a-3b-3 built and tested (2026-10-27)** (details: `docs/built-reference.md` and the build log; the dummy stays a capsule). Planned text:
- **3a-3b-3, enemies:** the figure on `Enemy` and the dummy, with a tint per type; the enemy's use of `Body` (corpse material, tint, tipped-over pose, bobblehead, the head pitch on the nose) is handled here. Register row P5.
- **Order:** 3a-3b-1, then 3a-3b-2, then 3a-3b-3, each with its own full check and test, then 3a-3c. 3a-3c is unchanged.
- **Not in any of them:** clip playback, walk animation, foot placement, made-up poses, new collision, hurtbox or hitbox shapes.

## 10.6 3a-3c-1 built and tested (2026-10-28); 3a-3c-2 and 3a-3c-3 next

- **Built:** `ActionData.placeholder_clip` names the clip an action plays; `PlayerFigure.drive_clip()` plays it, stretched evenly to `duration`, over the whole figure (arms and blade); the code blade is hidden while it plays and the hitbox sits on the clip's blade; blend in 0.1 s, out 0.12 s, chained attacks cross-fade. Mapped: `attack_1` to `attack_5` (`combo_1` to `combo_5`), the dash attack (`run_attack`), both crouch attacks (`crouch_attack`). F1 "Clips drive the figure" (off = held pose and the code sword). Details: `docs/built-reference.md` and the build log.
- **What the test showed:** the clip and the old `active_hit` did not line up (the hit windows were tuned to the code swing). The fix was to set `active_hit` of the seven actions from the clips' own hit frames (the sandbox hit frames times each action's stretch; the durations already were about half of Elden Ring's), not to warp the clip. The blade is fastest in the last frames of the window. `attack_5`'s two-hit test list from 3b-4 was removed (one hit in the data); multi-hit support stays for later use.
- **New debug aids:** F1 "Slow motion" (Off, 50, 25, 10 percent), an F2 clip line (clip, frame, clock, HIT LIVE), and a plain debug menu look (default theme, text from the window height).
- **Next:** 3a-3c-2 (dodge and backstep, the air tap loop, the helm splitter), 3a-3c-3 (the enemy thrust and sweep: whether `heavy1` reads as a thrust and the crouch attack as a low sweep is judged there). Locomotion clips follow speed and stay in 3c. Small follow-up: drop the `clip:` tag from the F2 header (it overlaps the other tags; the clip line shows the name).

## 10.7 3a-3c-2 built and tested (2026-10-28)

- **Built:** clips on the dodge (the roll by direction against the facing, `backstep` with no input), both air attacks (`combo_1:upper`, `combo_2:upper`: upper body from the clip, legs held) and the helm splitter (`air_heavy` held on its last pose until landing, then `air_heavy_land`). `ActionState._clip_name()` is the virtual that picks the clip. Details: `docs/built-reference.md` and the build log.
- **Changed from the check:** the helm splitter kept its old timing (duration 0.32, window 0.15 to 0.192) because the planned window at 0.467 s would never open (the dive falls a jump in about 0.26 s); the air hit windows were widened to 0.1 s; the validator needed no change.
- **Still open:** the draw attacks keep the code sword (no unsheathe clips in the data); the air thrust hold; the body-only mode for the code-sword actions (a later step, with the `combo_1` body for the draw attacks); 3a-3c-3 became the player's charged thrust (section 10.8); the enemy thrust and sweep are 3a-3c-4.

## 10.8 3a-3c-3 built and tested (2026-10-28): the player's charged thrust

- **Built:** the weapon's ground thrust plays the charged heavy 1 clip (`heavy1_charge`): the pull-back while attack is held (0.4 s to full pull-back, then held), the stab and recovery on release. Both sides of the zigzag play the same clip, not mirrored; the clip name is data on `thrust.tres`, so the user's own animation replaces it in Phase 6. Details: `docs/built-reference.md` and the build log.
- **Decided:** the clip's hit frames 38 to 41 set `active_hit` (0.19, 0.3); the other holds (crouch upward slash, dash and slide thrusts, charged iai) keep the code sword.
- **Split:** the enemy thrust and sweep moved to **3a-3c-4**. The data check showed `heavy1` is a real forward thrust (blade level at chest height, about 1.8 m of travel).
- **Next:** 3a-3c-4 (whether `heavy1` reads as the enemy thrust and the crouch attack as a low sweep is judged on the enemy), then 3c and 3d.

## 10.9 3a-3c-4 built and tested (2026-10-28): enemy bursts, thrust and sweep on clips

- **Built:** the enemy's figure plays clips for its burst attacks (`combo_1` to `combo_5`), its thrust (`heavy1_charge`: pull-back over the charge, the stab on fire) and its sweep (`dodge_attack`, `a029_030300`; the user chose the rolling attack as the sweep). Bursts were added to the scope at the user's request (the enemy uses the same `weapon.combo`). The grab stays code-drawn. Details: `docs/built-reference.md` and the build log.
- **Hit-sync (the option of 7.2 item 12):** used for the sweep only. `ActionData.placeholder_clip_hit` holds the clip's hit span in seconds; `PlayerFigure.drive_clip_synced()` warps the clip so its hit meets `active_hit` and its end meets `duration`, so the tuned telegraph, the jump-over and the symbol timing did not change.
- **Addendum, the wide head zone (built and tested 2026-10-28):** the user asked for an easier landing on the head to do the jump-over counter during the sweep. While a jump-over is armed, a falling player over a zone of radius `EnemyAIData.head_bounce_radius` (1.0 m) at the capsule's top gets the same counter as `on_stomped()` (`Enemy.try_head_stomp()`, called first in `PlayerForcedMovement.update_enemy_head()`). Only during an armed sweep; the capsule and the hurtbox are unchanged; the zone stays at standing head height (the user chose that over following the crouched head).
- **Next:** 3c, then 3d. 3a is complete.

## 11. 3c-1 built and tested (2026-10-28): per-fighter hitstop

- **Built:** a hit freezes its attacker and its target; the other fighters, the camera, the particles and the HUD keep running, and input is still read. `Hitstop.freeze()`, `fighter_scale()` and `slide()`; `HitData.target`. Details: `docs/built-reference.md` and the build log.
- **Decided at the check (2026-10-28):** the freeze stays at 5% speed (not a hard stop); the deathblow and the boss-slain screen keep the whole-game slowdown; the order of 3c is hitstop first, then locomotion tuning with the locomotion clips (a 3c item of its own, section 2), then landing and hit tiers with the sparring dummy, then the small details. Lock-on hysteresis already exists (`acquire_range` 20 m, `release_range` 25 m), so it needs no work unless the ranges change.
- **Also done 2026-10-28, outside the plan:** the jump apex tweak (the apex gravity applies only while rising; same height; see the build log).
- **Next:** 3c-2, locomotion with the locomotion clips: 3c-2a (the clips, built, section 12) then 3c-2b (the tuning, built, section 13).

## 12. 3c-2a built and tested (2026-10-28): locomotion clips

- **Built:** idle, walk, run, sprint and crouch run play as the figure's base layer on the player and on enemies, at the real speed, whenever no action clip plays (in combat too). `FigureLocomotion`, `PlayerFigure.drive_locomotion()`, F1 "Locomotion clips". Details: `docs/built-reference.md` and the build log.
- **Decided at the check (2026-10-28):** crouch run instead of crouch walk; the rate follows the real speed (option A, cap 2.2), the dash stays 9.0 m/s and only the dash plays the sprint clip; enemies are in; the sheathed right arm follows the clip; jump, fall and landing clips stay in 3c-3; two zips, 3c-2a then 3c-2b. The sandbox bin also has four-direction run and crouch-run clips, so the locked-on blend needs no rate cap.
- **Found:** the clips are baked in place, so their travel speeds are measured constants (`CLIP_SPEED`); the player's speeds are about 1.8x the clips', so the legs run about 1.8x.
- **Next:** 3c-2b, the locomotion tuning (`sprint_turn_speed`, `locked_turn_speed`, `stop_deceleration`, acceleration and deceleration by feel), on a fresh snapshot; then 3c-3 (landing and hit tiers, with the jump, fall and landing clips and the sparring dummy), then 3c-4 (the small details).

## 13. 3c-2b built and tested (2026-10-28): locomotion tuning

- **Built:** `Player` exports `sprint_turn_speed`, `locked_turn_speed` and `stop_deceleration` (defaults 18, 18 and 60 = the old behavior), the optional rate of `face_direction()`, and the stop-from-a-run rule in `apply_horizontal_movement()`. Details: `docs/built-reference.md` and the build log.
- **Decided at the check (2026-10-28):** `locked_turn_speed` applies wherever the body turns toward the target (walking, guard, crouch, heal, air, attacks without a turn rate); the brake covers a whole stop that starts above `walk_speed * 1.5`; tuning is done live in the Remote tab, the chosen numbers then become the defaults in a short fix zip. No numbers were reported yet.
- **Not done:** enemies, a limit on the dash's velocity turn, run-stop clips, braking inside attacks.
- **Next:** 3c-3, landing and hit tiers with the jump, fall and landing clips (the airborne loop, fall start and jump set are in the sandbox bin but not converted yet) and the sparring dummy; then 3c-4, the small details.

## 14. 3c-3a built and tested (2026-10-29): jump, fall and landing clips, landing tiers

- **Built:** an air layer in the figure (jump clip by take-off speed, fall start off a ledge, airborne loop) for the player and enemies, and `LandState` with a light and a heavy landing. Details: `docs/built-reference.md` and the build log.
- **Decided at the check (2026-10-29):** 3c-3 is split: 3c-3a (this) and 3c-3b (hit reaction tiers and the sparring dummy). The landings follow the F1 "Elden Ring-like feel" switch; a light landing never blocks dodge, jump or attack; heavy is 7.5 m or more, allows dodge from 0.35 s and the rest from 0.55 s. The heavy landing plays the sandbox's `land_fall` crouch (its own heavy clip drops the body flat); the jump clip has a start delay and a speed fit, set by feel.
- **Found:** the sandbox has one plain heavy landing only (`a000_202310`); the clip's head height shows it (heavy -0.65, fall 0.49, light about 0.8, against 1.0 standing). The placeholder figure casts no shadow, so a body on the floor looks slightly afloat.
- **Not done:** four-direction jumps and landings when locked on (the strafe landing clips are in the sandbox data), enemy landing lockouts, fall damage, foot placement, a shadow for the placeholder figure.
- **Next:** 3c-3b, hit reaction tiers (flinch, stagger, large, knockdown, guard hit and guard break clips are in the sandbox data) and the sparring dummy; then 3c-4, the small details.

## 15. 3c-3b-1 built and tested (2026-10-30): the player's hit reactions and the dummy's strengths

- **Built:** a strength on every hit (small, middle, large, knockdown), `HurtState` with the reaction clips in four directions and the guard break, and the dummy's per-swing strengths. Details: `docs/built-reference.md` and the build log.
- **Decided at the check (2026-10-30):** 3c-3b is split: 3c-3b-1 (this) and 3c-3b-2 (enemy flinch clips by tier). Small hits react only while the player is free; middle and up interrupt attacks, heals and guard; never in the air, in a dodge, on a ledge, in a stagger, a deathblow, resting or dead; a hit during a reaction restarts it only when stronger. Lockouts are the sandbox's cancel times scaled to 0.6, dodge opens first. The knockdown throws the player back and is invulnerable while down. Damage does not change with the strength.
- **Found:** the sandbox's own sparring dummy cycles the same four strengths; its reaction clips come in four directions for each strength (the guard hit clip is separate). A state that sets its action itself must do it before the base class's `enter()` runs.
- **Not done:** enemy reaction clips by tier (3c-3b-2), the guard hit clip, a clip for the posture-break stagger, reactions in the air, foot placement.
- **Next:** 3c-3b-2, enemy flinch clips by tier (the tier comes from the player's attack data); then 3c-4, the small details (four-direction jumps and landings when locked on, the guard hit clip).

## 16. 3c-3b-2 built and tested (2026-10-30): enemy reaction clips by tier

- **Built:** an enemy's flinch now has a strength (the hit's `hurt_level`), a side, a clip and a stun length by tier. Details: `docs/built-reference.md` and the build log.
- **Decided at the check (2026-10-30):** the stun is `hit_stun_time` times 1.0, 1.6, 2.2 and 5.0 (`tier_stun_scale` in the enemy AI data); a stronger hit gets through the flinch immunity and restarts the flinch; armor, the deathblow window and the phase rules are unchanged; no throw-back and no invulnerability for an enemy knockdown. With 3c-3b-1 this completes 3c-3b.
- **Found:** enemies use the same rig as the player, so the player's reaction clips play on them unchanged; the player's combo data is also the enemies', so a strength set on an attack applies both ways (attack 3 and 4 hit middle, attack 5 large).
- **Not done:** a clip for the posture-break stun, the death clip, the guard hit clip, per-enemy-type scales, foot placement.
- **Next:** 3c-4, the small details (four-direction jumps and landings when locked on, the guard hit clip, and what else the plan lists for 3c-4).

## 17. 3c-4a built and tested (2026-10-30): light-tilt walk

- **Built:** a light stick tilt walks and a harder one runs (`walk_tilt_threshold` 0.6, `walk_tilt_blend` 0.1), and the held `walk` action (Left Alt) walks on the keyboard. Details: `docs/built-reference.md` and the build log.
- **Decided at the check (2026-10-30):** 3c-4 is split: 3c-4a (this), 3c-4b (four-direction jumps and landings when locked on, plus the guard hit clip), 3c-4c (upper-body layers for guard and carry, only if wanted now). Ground Locomotion only; follows the F1 "Elden Ring-like feel" switch; Alt is held, not toggled; the controller has no walk button. The fall start off a ledge was already built in 3c-3a.
- **Found:** the old controller speed was already analog (it scaled with the tilt); now it is a walk below the threshold and a run above it.
- **Not done:** enemies, a walk toggle, 3c-4b, 3c-4c. Foot placement and the figure's shadow stay in 3d.
- **Next:** 3c-4b, on a fresh snapshot (it needs the split `ELDEN-RING-Combat-Rewrite-with-data` zip to convert the strafe landing and guard hit clips).
