# Phase 3: Feel and weight

Read this when working on Phase 3. Written 2026-10-20 from a discussion chat. **Status: planned, nothing built yet.** Everything marked "agreed" was confirmed by the user in that chat; the numbers and details marked "default" are proposals until the item's full check (work agreement, section 7).

---

## 1. Goal and source

- **Goal:** make combat and movement feel weightier and more committed, with tools that let the user tune it by eye. Gameplay stays data-driven: `ActionData` and the action clock stay the truth, and real animation (Phase 6) only follows them.
- **Reference:** the open-source ELDEN RING combat sandbox written in Rust on Bevy (the user uploaded `ELDEN-RING-Combat-Rewrite-main.zip` on 2026-10-20). It was read for structure and ideas only: how actions define their windows, hit-stop, locomotion rates, hit reaction tiers, sound events per frame.
- **Rule (revised by the user 2026-10-20, replaces the first version):** until real animation arrives in Phase 6, the project may use **Elden Ring material as temporary placeholders**: the numbers (timings, windows, speeds, cancel and turn times; see `docs/phase-3-feel-reference.md`) and the animations of the ported Bevy sandbox, which animate the capsule and stick character. The user's own animations (done in Blender so far: dodge, walk, run, idle, sheathed and drawn, all directions; jump in progress) are **not used in the game until Phase 6**. Not covered by this revision: sounds, models and any other game data; ask before using them. Nothing is ever shipped to the public with a placeholder in it (next bullet). The first version of the rule (nothing extracted, feel targets in words only) is replaced.
- **Replacement gate (agreed 2026-10-20):** every Elden Ring placeholder is replaced by the user's own handcrafted work (a) when real animation is integrated in Phase 6, and (b) in any case **before the project goes public**: a Kickstarter, early access, a public demo, or anything else meant to attract public interest. Claude reminds the user of this at the start of every Phase 3 full check and when a Phase 3 milestone is finished, and keeps the checklist "Placeholders to replace" in `docs/handoff.md` up to date. Nothing placeholder ships past that point.
- **Why before game flow:** the work adds fields to `ActionData` and changes the action states. Doing that before more actions, enemies and quests are authored avoids redoing them.
- **Phase numbers shifted on 2026-10-20 (agreed):** this phase was inserted, the old Phases 3, 4 and 5 are now 4, 5 and 6, and Phase 2 stays as it was (its open backlog stays in handoff section 13, including the corner shimmy and the other ledge enhancements).

## 2. Milestones (each can be stopped after; the order is a suggestion)

### 3a. Tools
- **Feel overlay (agreed):** a debug-only readout of the current action and its time, with a timeline of which windows are open (locked, cancel, buffer, active hit, i-frames), and an i-frame tint on the character. It makes 3b and 3c tunable by eye.
- **`ActionData` validator (agreed):** editor warnings for broken timing, such as a cancel before the lock ends, a window past the duration, or an attack without an active hit window.

- **Placeholder animation import, 3a-3 (agreed as an item 2026-10-20, not yet checked):** a tool that converts the baked animations of the Bevy sandbox (`player_anims.bin`, joint positions at 30 fps, 38 joints, 1479 clips, plus the orientation axes of the head and the two weapon points) into data Godot can play, and a player that animates the capsule and stick character with them, driven by the action clock. A stand-in until Phase 6; gameplay still follows `ActionData`. Its own full check settles the format, how the stick figure is drawn (the 3d mannequin steps share this), and which clip backs which action.

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
- **The mannequin (agreed idea, built in steps):** a figure of primitives (sphere head, capsule torso, pelvis, capsule limbs on joints, a shield on the left arm) instead of one capsule with a nose, used by the player and by enemies with a tint per type. Steps: (a) the figure replaces `Body` and `Nose`; (b) idle sway, a procedural walk and run by speed, a lean into movement, crouch; (c) arms reach the sword grip and hold the shield on guard, using the existing sword poses (this absorbs `ReachArms` and `HealArm`); (d) poses for the other states, one state at a time. It is a stand-in until the Blender pipeline of Phase 6; gameplay does not change.
- **Foot placement (agreed):** feet fitted to stairs and slopes up to a step height, the body settling smoothly on new heights. Pairs with the mannequin's legs.
- **Frame-driven sound (agreed):** sound events at times in an action (the swing, a footstep), each sound choosing among several recordings with a small random pitch and level variation each time, and looping clips firing on every pass. The Phase 2 sound extras (`charge_loop`, `aura_loop`, footsteps per surface) can use it.

## 3. Decisions: what is not in Phase 3 (agreed 2026-10-20)

- **No guard arc and no block raise time.** They would make the deflect less generous than in Sekiro and in the Executor of Elden Ring Nightreign; the deflect timing stays as it is.
- **No simulation split** (the game logic as a pure 60 Hz state machine apart from the engine). Rejected: it would mean rewriting everything that uses Godot's physics, navigation and areas, and its benefits (netcode, exact replays) do not fit a single-player game with a streamed world.
- **No input recorder and replayer.**
- **No stamina, equip-load rolls, weapon classes or paired weapons:** the design is posture-based.
- **Not picked, may return for testing the hit tiers:** a sparring dummy that cycles telegraphed attacks by strength, and a scripted tour of all moves.
- **Not Phase 3:** the corner shimmy and the other ledge enhancements, the lock-on HUD extras and the other Phase 2 backlog entries (handoff section 13), and enemy variety (Phase 5).

## 4. Files likely touched (confirm at each milestone's full check)

`scripts/resources/action_data.gd` and the `.tres` files of the actions; the action states in `scripts/player/states/` and the enemy attack code; `scripts/player/player.gd` and `locomotion_state.gd`; `scripts/combat/hitstop.gd`, `combatant.gd` and `hitbox.gd`; `scripts/player/lock_on.gd`; `scripts/core/sfx.gd`; `scenes/player/player.tscn` and `scenes/enemy/enemy.tscn` for the mannequin; new scripts for the overlay, the validator, the mannequin and the placeholder animation import (3a-3).

## 5. Open points (ask once at the full check of the milestone they belong to)

- 3b: how the new per-input cancel fields relate to `cancel_window` and `buffer_window`, and whether old `.tres` files are migrated or keep working unchanged.
- 3c: what, if anything, stays on the global slowdown (a deathblow, for example); the thresholds for walking, and the landing heights.
- 3d: the mannequin's proportions and colors, whether enemies share one figure, and the sound event data format.
- 3a-3: the converted format (a Godot `Animation` with position tracks per joint, or a compact resource sampled by the mannequin script), where the converter lives, how the stick figure is drawn, and which clip backs which action.
- Whether the sparring dummy returns for testing the hit tiers.

## 6. Relation to later phases

Real animation (Phase 6) will need some numbers retuned (swing timing, turn rates); the data-driven setup keeps that cheap. Phase 3 is a good base, not a finished feel.
