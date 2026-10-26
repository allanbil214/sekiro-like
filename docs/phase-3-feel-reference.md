# Phase 3 feel reference: placeholder numbers (FromSoft standard)

Read this when tuning Phase 3 (feel and weight). Written 2026-10-20. **Status: notes, not agreed decisions.**

## 1. What this is and how it may be used

- **Purpose (agreed 2026-10-20):** a record of how an Elden Ring character feels, in numbers, used as **temporary placeholders** while the project has the stick-and-capsule character. They are replaced by the user's handcrafted work in Phase 6, and in any case before the project goes public (the replacement gate in `docs/phase-3-plan.md`, section 1). The animations of the ported Bevy sandbox are the matching animation placeholder (item 3a-3 of the plan); this file only holds the numbers. The user's own Blender animations are not used in the game until Phase 6.
- **Source:** timings read from the converted game data in the Rust sandbox the user uploaded (`ELDEN-RING-Combat-Rewrite-main.zip`, `src/sim/extracted.rs`). The weapon used for attacks is the **uchigatana, one-handed** (the nearest to our katana). The original is in animation frames at 30 fps; **everything here is converted to seconds** (frames / 30), because our windows are seconds.
- **Not a spec:** copy a value into an `ActionData` only when the item's full check says so, and mark it as a placeholder in the `.tres`. Our fields differ (see section 6 for the mapping).

## 2. How the feel is built (the ideas that matter)

- **Every action has one clock with many separate "free from" times.** The same swing can be cancelled into a light attack, a heavy, a dodge, a jump, a guard or plain movement at *different* moments. Attacks chain early (light about 0.55 s), dodge later (about 0.9 s), movement last (about 1.15 s). This is the main source of the committed-but-responsive feel.
- **Input is ignored before a time, then queued** (the `input from` column): a press too early does nothing; after it, the newest press waits for the cancel time.
- **Turning is controlled per action:** no turning at the start and during the active swing and recovery, a short fast turn at the start of the wind-up (720 deg/s for about 0.13 to 0.27 s), nothing after. Early tracking, late commit.
- **Motion is a curve, not a speed:** a quick burst into the swing (most of the forward travel happens before the hit window ends), then a slow settle. Light chains step forward about 1.1 to 1.6 m per swing.
- **Hits are short:** about 0.10 s active window (3 frames) for most light and heavy swings, up to 0.13 s for run attacks.
- **Hit-stop is per attack and short:** 0.08 s (2.4 frames) on every swing here. The sandbox applies only half of it as a feel estimate; the full time read as a stall.
- **Dodge:** i-frames start on frame 0 and last about 0.43 s (light load); the roll is long (1.7 s) but cancelable into attacks at 0.6 s.

## 3. Locomotion (speeds in m/s; the sandbox's own estimates marked E)

| Thing | Value |
|---|---|
| Walk | 1.50 |
| Run | 4.01 (back 3.74, sideways 3.94) |
| Sprint | 6.04 |
| Crouch walk and run | 1.37 and 2.98 |
| Acceleration and deceleration (E) | 26 and 32 (ours now: 50 and 60) |
| Walk below stick tilt (E) | 0.55 |
| Turn rate: run, sprint, locked on (E) | 1080, 480, 720 deg/s |
| Turn rate inside an action with no setting (E) | 360 deg/s |
| Sprint stop (brake) | 1.33 s long, move allowed from 0.27 s, 0.65 m of travel |
| Roll on release, sprint on hold (dodge button) | released under 0.33 s = roll; held longer = sprint |
| Step height (E) | 0.35 m |
| Gravity and terminal velocity (E) | 18 and 40 |
| Lock-on acquire and break range (E) | 15 m and 22 m (the hysteresis idea of 3c) |
| Heavy landing from a fall (E) | 8 m; fall damage from 16 m; fall death 20 m |

## 4. Attacks (one-handed katana-class, seconds)

| Attack | Length | Input from | Cancel: light | heavy | dodge | jump | guard | move | Hit window | Forward travel |
|---|---|---|---|---|---|---|---|---|---|---|
| Light 1 | 2.30 | 0.33 | 0.53 | 0.67 | 0.87 | 0.87 | 0.93 | 1.13 | 0.43 to 0.53 | 1.62 m |
| Light 2 | 1.97 | 0.37 | 0.57 | 0.77 | 0.90 | 0.90 | 0.97 | 1.17 | 0.47 to 0.57 | 1.11 m |
| Light 3 | 2.27 | 0.37 | 0.53 | 0.70 | 0.87 | 0.93 | 1.00 | 1.20 | 0.43 to 0.53 | 1.27 m |
| Light 4 | 2.13 | 0.33 | 0.63 | 0.77 | 0.93 | 0.90 | 0.93 | 1.17 | 0.43 to 0.53 | 1.06 m |
| Light 5 (finisher) | 2.90 | 0.57 | 1.53 | 1.53 | 1.10 | 1.43 | 1.50 | 1.57 | 0.57 to 0.67 | 1.44 m |
| Run light | 1.97 | 0.43 | 0.97 | 0.97 | 0.97 | 1.00 | 1.07 | 1.23 | 0.50 to 0.63 | 4.47 m |
| Run heavy | 2.23 | 0.57 | 1.10 | 1.17 | 1.23 | 1.33 | 1.33 | 1.53 | 0.63 to 0.77 | 4.42 m |
| Roll attack | 1.80 | 0.27 | 0.77 | 0.77 | 0.80 | 0.83 | 0.83 | 1.03 | 0.37 to 0.47 | 2.37 m |
| Backstep attack | 2.00 | 0.43 | 0.73 | 0.83 | 1.00 | 1.00 | 1.07 | 1.23 | 0.53 to 0.63 | 4.03 m |
| Heavy 1 (tap) | 2.30 | 0.30 | 0.97 | 0.97 | 0.93 | 1.10 | 1.00 | 1.23 | 0.40 to 0.50 | 1.67 m |
| Heavy 1 (charged) | 3.27 | 1.17 | 1.93 | 1.93 | 1.90 | 2.03 | 2.07 | 2.20 | 1.27 to 1.37 | 1.88 m |
| Heavy 2 | 1.73 | 0.23 | 1.03 | 0.97 | 0.90 | 0.97 | 0.93 | 1.07 | 0.33 to 0.40 | 1.98 m |
| Guard counter | 2.70 | 0.63 | 1.23 | 1.33 | 1.30 | 1.40 | 1.40 | 1.60 | 0.73 to 0.83 | 0.96 m |

Hit-stop on all of the above: 0.08 s. Motion values (damage multipliers) run 0.90 to 1.60; heavies and the charged heavy are the highest. The light chain is 5 swings here (the sixth exists for other weapons).

## 5. Defence, dodge and reactions

| Move | Length | Input from | Cancel: light | heavy | dodge | jump | guard | move | I-frames | Travel |
|---|---|---|---|---|---|---|---|---|---|---|
| Roll (light load) | 1.67 | 0.50 | 0.60 | 0.60 | 0.70 | 0.70 | 0.83 | 0.73 | 0.00 to 0.43 | 4.33 m |
| Roll (heavy load) | 1.83 | 0.50 | 0.77 | 0.77 | 0.93 | 0.90 | 0.87 | 1.00 | 0.00 to 0.40 | 3.31 m |
| Backstep | 1.17 | 0.13 | 0.47 | 0.47 | 0.53 | 0.57 | 0.47 | 0.63 | 0.00 to 0.23 | -2.50 m |

Jump: input from 0.73 s (it can be queued late), light and heavy attacks cancel it at 0.20 s. Stand jump 0.83 s, run jump 0.80 s with about 3.2 m of travel, sprint jump 0.73 s with about 5.0 m.

Landings (free to act from): light landing about 0.17 s for moving, 0.47 s for a short fall, heavy landing 1.30 s (a 2 s lockout from a high fall is the extreme). Locked on, landings and jumps exist in four directions.

Hit reactions (four strengths, four directions each):

| Reaction | Length | Free to act from |
|---|---|---|
| Flinch (small) | 1.13 | 0.50 |
| Stagger (middle) | 1.90 | 0.93 |
| Large stagger | 2.00 | 1.23 |
| Knockdown | 3.50 | 3.10 |
| Guard hit | 0.83 | 0.27 |
| Guard break | 4.57 | 3.17 |

Knockdown: invulnerable for 1.97 s, throws back about 4 m, a roll can cancel it at 1.20 s.

## 6. Mapping onto our `ActionData` (for the 3b full check)

- `input from` is the "ignore presses before" time of 3b. Cancel times map to the new per-input cancel fields (light, heavy, dodge, jump, guard, move). How they relate to `cancel_window` and `buffer_window` is the open point in the Phase 3 plan.
- The "no turn" spans and the 720 deg/s turn spans are the turn-control windows of 3b.
- The per-frame forward travel is a motion curve (3b); we store it as a curve, not a table.
- One hit window per swing here; multi-hit lists are for other weapons.
- The hit reactions table is the tier list of 3c: flinch, stagger, large stagger, knockdown.

## 7. Placeholder rules

- Seconds, rounded; tune by playing. Where our design differs (posture instead of stamina, deflect timing, no equip-load rolls), ours wins and these numbers are only a starting feel.
- Everything in this file is replaced by handcrafted values in Phase 6, and in any case before the project goes public (Kickstarter, early access or any public showing).

## 8. Added 2026-10-26 (the discussion chat; notes, the decisions are in `docs/phase-3-plan.md`, section 7)

- **Source of these numbers:** the same `extracted.rs`, now from `ELDEN-RING-Combat-Rewrite-with-data.zip` (the upload that also carries `player_anims.bin`).
- **Scale (agreed):** the project's feel is a blend: the structure of this file (separate cancel times per input, turn control, motion curves, multi-hit lists) with the **times scaled to about 60 to 70 percent**, then tuned by playing. The 60 to 70 percent is a placeholder number.
- **Why a scale:** our current actions are about half as long. Light attack 1: ours 1.16 s (hit 0.35 to 0.52, cancel from 0.64), theirs 2.30 s (hit 0.43 to 0.53, light cancel 0.53, move 1.13). Dodge: ours 0.45 s (free at 0.30, i-frames 0.05 to 0.28), their roll 1.67 s (i-frames 0 to 0.43, cancel into attacks at 0.60). The feel target stays Sekiro-snappy; ours wins where the two differ.
- **Air attacks (uchigatana, one-handed):** the jump light attack is active from frame 12 to 16 (0.40 to 0.53 s; ours: 0.18 to 0.32 s). The jump heavy attack (`a029_031230`) is active from frame 14 to 40 (0.47 to 1.33 s): a fast downward swing, then the blade held low until landing. It is the clip for the helm splitter (the dive's length depends on the fall height, so the clip plays its swing and holds its last pose until landing).
- **Enemy attacks (proposed clips, to verify at the 3a-3 full check):** the thrust uses the one-handed heavy attack 1 (check that its blade path reads as a thrust), the sweep uses the crouch attack (check that it is low enough to jump), the grab has no clip (a made-up pose).
