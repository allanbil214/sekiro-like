# Placeholder register

> Created 2026-10-26 (Phase 3 discussion). One row per temporary thing, so it is always clear what is a placeholder, where it came from and what replaces it. Claude keeps this file up to date: when something temporary is added, changed or replaced, and when a Phase 3 milestone is finished (the reminder rule in `docs/phase-3-plan.md`, section 1). Built so far (2026-10-27): the `ActionData.placeholder_source` field (layer 3) and the feel overlay that shows it; P1 is partly in use (3b-1 test values); the other register rows are still planned.

## How placeholders are marked (`docs/phase-3-plan.md`, section 8)

1. **This register** is the list.
2. **A tag in the files:** a comment with the word `PLACEHOLDER` and the source, for example `PLACEHOLDER(ER numbers)`, `PLACEHOLDER(ER clip)`, `PLACEHOLDER(made-up pose)`. Search for `PLACEHOLDER` to find them all.
3. **A tag on the action:** an `ActionData` field shows the source in the Inspector and in the feel overlay; the validator warns about an Elden Ring clip without the tag.
4. **One folder for game-derived data:** `assets/placeholder/`. It stays out of public builds and out of any public repository.

## The register

| ID | What | Where (planned) | Source | Replaced by | Status |
|---|---|---|---|---|---|
| P1 | Timings, windows, cancel and turn times and speeds, scaled to about 60 to 70 percent | the `ActionData` `.tres` files and the locomotion code | Elden Ring numbers (`docs/phase-3-feel-reference.md`) | the user's tuned values (Phase 6, and before anything public) | in use since 2026-10-27 (3b-1): `input_from`, `cancel_move` and `cancel_item` on `attack_1` to `attack_5`, tagged `ER_NUMBERS` and switchable in the F1 debug menu (the item times are guesses, not Elden Ring numbers); 3b-2 (done and tested 2026-10-27): turn spans (`no_turn`, `turn_overrides`) on `attack_1` to `attack_5`, taken from the sandbox's one-handed light chain (`a029_030000` to `a029_030040`) and stretched to each attack's own hit start, switchable with the same F1 toggle; 3b-3 (done and tested 2026-10-27): forward motion curves on `attack_1` to `attack_5` (the sandbox's light-chain motion shape, time stretched like the turn spans, scaled to each attack's current travel), same F1 toggle; more in 3b and 3c |
| P2 | Player animation clips (one-handed uchigatana set: combat, dodge, jump, air attacks) | converted data under `assets/placeholder/` and the clip player | Elden Ring clips (`player_anims.bin` of the Bevy sandbox) | the user's Blender animations (Phase 6) | planned (3a-3) |
| P3 | Enemy attack clips: the thrust (one-handed heavy 1) and the sweep (crouch attack), both to be verified | the same | Elden Ring clips | the user's Blender animations (Phase 6) | planned (3a-3) |
| P4 | Made-up poses: enemy grab, slide, wall hug, ledges (hang, climb, shimmy), taunt, throw, sheathe, draw slash, deflect poses, charged iai | pose data (location decided at the 3a-3 full check) | made up by Claude, tested by the user | the user's Blender animations (Phase 6) | planned (3a-3) |
| P5 | The figure (the mannequin): simple shapes, one tint per enemy type | the figure scene and scripts | own code; its proportions follow the clips' skeleton (Elden Ring) | the user's rig (Phase 6) | planned (3a-3) |
| P6 | The reference numbers file | `docs/phase-3-feel-reference.md` | Elden Ring | archived when P1 is replaced | exists |
| P7 | Sounds | `assets/audio/`, `data/audio/sfx_data.tres` | the project's current placeholder sounds (not taken from the Elden Ring sandbox) | the user's own or licensed sounds | exists (Phase 2); 3d builds the frame-driven system with them |

Not in this register: the Phase 2 placeholders (the test arenas, the default start arena and the empty Options panels) are marked in `docs/phase-2-plan.md` and the build log.

## The replacement gate (agreed 2026-10-20)

Every Elden Ring placeholder (P1, P2, P3, P6, and the skeleton behind P5) is replaced by the user's own work (a) when real animation is integrated in Phase 6, and (b) in any case **before the project goes public**: a Kickstarter, early access, a public demo or anything else meant to attract public interest. Before that, a **placeholder report** (a debug tool or a validator mode, built in Phase 3) lists everything still tagged, and nothing from Elden Ring may be on it. Sounds, models and any other game data are not covered by the Phase 3 allowance: ask first.

## Open

- Whether private test builds for friends may contain the clips (decide at the first such build; public builds never do).
