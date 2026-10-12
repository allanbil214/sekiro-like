# Phase 1.5: Hardening and cleanup (between Phase 1 and Phase 2)

> Companion to `docs/handoff.md`. Agreed 2026-10-12 as a short phase after Step 12 and before the Phase 2 backlog (handoff, section 13). The 9 items are the ones the user picked from the 2026-10-12 code review (4 "small things" and 5 "best-practice refactors"); the numbers below follow that list.

## 1. Rules for this phase

- **Pure refactor and hardening.** No gameplay change, no retuning, no `.tres` value changes, no new scene nodes unless an item says so (then they are listed as editor steps).
- **One item at a time.** Each is built, tested by the user, and logged before the next (work agreement, sections 1 to 7). Full check before each build; the build-log entry is appended without reading the file.
- **Measure before claiming a speed-up.** An item that says "performance" gets a before and after in the Debugger (Monitors or Profiler) during a heavy fight. No visible change is expected at 1 enemy and is said plainly in the build log.
- **Owners keep their exports.** Tuned `@export` values stay on `Player`, `Enemy`, `SwordVisual` and so on (as in 12C); only the code moves.
- **Verify by playing.** Each item ends with a short "How to verify" that repeats the Step 12 checklist for the parts it touches (fight, guard and deflect, perilous, own attacks, deathblow, lock-on).

## 2. Status

| # | Item | Kind | Status |
|---|---|---|---|
| 1 | Shared list of enemies (no group search per frame) | structure | [x] (done 2026-10-12) |
| 2 | Typed trail points in `hitbox.gd` | safety | [x] (done 2026-10-12) |
| 3 | Debug prints (and the hitbox debug draw) only in debug builds | tidy | [x] (done 2026-10-12) |
| 4 | Group names as constants | tidy, safety | [x] (done 2026-10-12) |
| 5 | Split the big files: 5a `sword_visual.gd`, 5b `enemy.gd`, 5c `player.gd` | structure | [x] (5a, 5b and 5c done 2026-10-12) |
| 6 | Typed data instead of name strings (6A input actions, 6B lock-on reason) | safety | [x] (done 2026-10-12) |
| 7 | `Groups` constants file | same as 4 | [x] (done with 4) |
| 8 | Delay bigger refactors to Phase 2 | decision | not built |
| 9 | Object pooling for `Fx` particles | performance | [x] (done 2026-10-12) |

Suggested order: 4 (with 7, **done**), 3 (**done**), 2 (**done**), 1 (**done**), 6 (**done**), 9 (**done**), then the big splits 5a (**done**), 5b (**done**), 5c (**done**). Every item except 8 is built. Item 8 is not built.

## 3. The items

### 1. Shared list of living enemies
- **What:** `Player._update_personal_space()`, `Player.find_deathblow_target()` and three places in `lock_on.gd` ask the scene tree for the "enemy" group every frame. Default: a small helper that `Enemy` and `Dummy` register with in `_ready()` and leave in `_exit_tree()`, with a `living()` call that returns the cached list. The group membership stays, for anything else that uses it.
- **Why:** no tree search per frame, and a base for several enemies. No visible gain at 1 enemy.
- **Open:** where the list lives (default: a static helper, cleared on scene reload so a reload keeps no dead references).
- **Risk:** low to medium. Test death, resurrection, scene reload and lock-on switching.
- **Done 2026-10-12:** `Enemies` (`scripts/combat/enemies.gd`, static: `register`, `unregister`, `all()`); `Enemy` and `Dummy` register in `_ready()` and unregister in the new `_exit_tree()`. The list holds every enemy in the tree, dead ones too (not "living only": the callers check `dead` and `deathblow_open` themselves, and a dead dummy stays in the tree). The 5 per-frame group searches use it. No speed-up was measured or expected at 1 enemy plus the dummy (see the build log, "Phase 1.5, item 1").

### 2. Typed trail points
- **What:** `Hitbox._trail_points` is an `Array[Dictionary]` with string keys. Replace it with a tiny typed inner class (or parallel typed arrays).
- **Why:** the parser checks the field names, and fewer allocations while a trail is drawn.
- **Touches:** `hitbox.gd` only.
- **Risk:** low. The trail must look the same (player and enemy, all slashes).
- **Done 2026-10-12:** the inner class `Hitbox.TrailPoint` (`tip`, `base`, `age`, `start`) replaces the dictionaries. The gain is safety and no per-frame casts; an instance costs about the same to create as a dictionary, so no speed-up was expected or measured (see the build log, "Phase 1.5, item 2").

### 3. Debug prints only in debug builds
- **What:** the `print(...)` calls in `combatant.gd` and `enemy.gd` look to be behind debug flags already (checked while building). Add a guard on `OS.is_debug_build()` so a release build prints nothing.
- **Risk:** very low.
- **Done 2026-10-12:** the 11 prints (3 in `combatant.gd`, 8 in `enemy.gd`) now check `debug_log and OS.is_debug_build()`; the `push_error` and `push_warning` calls stay in every build. `Hitbox.debug_draw` was included at the user's request: the box shows only when it is ticked and the build is a debug build (editor and debug exports look the same as before). See the build log, "Phase 1.5, item 3".

### 4. Group names as constants
- **What:** group names are typed as strings, mixed between `"player"` and `&"enemy"` (`player`, `enemy`, `danger_symbol`, `camera_rig`, `victory_screen`). Constants replace them, like `StateName` (12B). See item 7 for where they live.
- **Why:** a typo in a group name fails silently (the lookup finds nothing).
- **Touches:** `player.gd`, `enemy.gd`, `dummy.gd`, `lock_on.gd`, `camera_rig.gd`, `danger_symbol.gd`, `victory_screen.gd`, `fx.gd`.
- **Risk:** very low. The group names themselves do not change.
- **Done 2026-10-12:** 17 places in 8 scripts now use `Groups.X` (see the build log, "Phase 1.5, items 4 and 7").

### 5. Split the big files
Same method as 12C and 12D: move self-contained code into a helper (default: a `RefCounted` owned by the original, no new scene node); tuned exports and Inspector values stay on the owner. Each part is its own build and test.
- **5a `sword_visual.gd` (1146 lines):** the deflect poses and the guard-break pose with their overlay code. Verify all four deflect kinds, the guard flick, the guard break, the swing trail, the draw and sheathe.
  - **Done 2026-10-12 (5a):** `SwordGuardPoses` (`scripts/player/sword_guard_poses.gd`, a `RefCounted` made in `SwordVisual._init()` as `_poses`) holds the state and logic of the deflect poses and the guard-break pose: `start_deflect()` (pose pick, mirroring, aim toward the contact), the kind choice, the snap-hold-return weights and timers, `start_break()`. The `deflect_*` and `break_*` exports, the wobble and the flash stay on `SwordVisual`, which blends the pose into its own `_tip`, `_blade_dir` and `_edge_dir` (about 5 lines per overlay); `get_shoulder()` and `get_drop()` are new read-only getters for the helper. The public calls (`play_deflect`, `play_guard_break`, `play_guard_hit`, `play_guard_press`, `play_guard`) are unchanged. `sword_visual.gd` went from 1146 to 1068 lines (the exports stay, so the gain is small); the code is placeholder and is expected to be replaced by real animations. See the build log, "Phase 1.5, item 5a".
- **5b `enemy.gd` (1246 lines):** the defense decision logic (guard, deflect, repulse, riposte, break-out, adaptive guard chance). The phase machine, the perilous attacks and the owner-specific parts stay. Verify the four `ai/` presets plus the monk and the grappler.
  - **Done 2026-10-12 (5b):** `EnemyDefense` (`scripts/enemy/enemy_defense.gd`, a `RefCounted` made in `Enemy._init()` as `_defense`) holds the defense decisions: threat reading, the plan roll (`_begin_threat`), carrying the plan out on time, the riposte timer, the hit streak and the guarded-hit streak with its break-out, `since_player_attack`, and the defensive parts of the damaged, guarded and deflected responses and of the respawn reset. The phase machine, the attacks, the perilous attacks, the flinch and the recoil stay on `Enemy`, as do all exports (the `EnemyAIData` presets are unchanged). `_raise_guard` and `_drop_guard` became public `raise_guard()` and `drop_guard()`, `is_guarding()` is new, `_phase_allows_guard` is now the static `EnemyDefense.phase_allows_guard()`, and the helper never starts an attack: `tick_riposte()` returns true and `Enemy` calls `_start_burst`. `enemy.gd` went from 1251 to 1096 lines. See the build log, "Phase 1.5, item 5b".
- **5c `player.gd` (1078 lines):** candidates are personal space, footsteps, the hurtbox profile update, knockback, the stagger kneel. Pick after reading the file.
  - **Done 2026-10-12 (5c):** two helpers, both `RefCounted`, made in `Player._ready()`. `PlayerForcedMovement` (`_forced`, `scripts/player/player_forced_movement.gd`): `apply_knockback()` with the knockback velocity and decay, `add_push()` (the push added before `move_and_slide`, none during a ledge climb), `update_enemy_head()` (the bounce after a jump-over, else the slide off) and `update_personal_space()`. `PlayerBodyReaction` (`_reaction`, `scripts/player/player_body_reaction.gd`, placeholder code): the hit wobble (`start_recoil()`), the stagger lean, the kneel with its sway, the grab kneel, and the per-frame `update()` that writes the `Visual`. All exports stay on `Player`. `Player.apply_knockback()`, `set_stagger_lean()` and `set_stagger_kneel()` stay as one-line wrappers, so `DeadState`, `StaggerState` and the reaction code are unchanged. Footsteps and the hurtbox profile stay on `Player` (small, no neighbors). `player.gd` went from 1078 to 953 lines. See the build log, "Phase 1.5, item 5c".
- **Why:** readability and testing, not speed.
- **Open:** the exact split of each file, decided after reading it.

### 6. Typed data instead of name strings
- **Survey (2026-10-12):** `hold_action` is already an `ActionData` reference, and `kind`, the `Fx` kinds, the `Sfx` ids, the enemy phases and the state names are already enums or constants. What was left: **6A** the Input Map action names (119 lines, 141 places in 21 files, mixed `&"attack"` and `"attack"`); **6B** `LockOn._lost_reason()` returning `&"dead"`, `&"player"`, `&"range"`, `&"los"`, `&""`; **6C** `Sfx.swing_id()` choosing the swing sound by `ActionData.animation` name (three name lists); **6D** duck typing by name (`call_group(..., "add_trauma")`, `node.get("combatant")`, `get("lock_point_height")`, the sound slots matched by name in `sfx_data.tres`).
- **Done 2026-10-12 (6A and 6B):** `Actions` (`scripts/player/actions.gd`, `StringName` constants for all 17 Input Map actions) replaces the literals everywhere; `ui_cancel` (a built-in) and the hurtbox profile name `"crouch"` in `player.gd` are not actions and stay. `LockOn.LostReason { NONE, DEAD, PLAYER, RANGE, LOS }` replaces the string reason codes. See the build log, "Phase 1.5, item 6".
- **Not done on purpose:** 6C (a `swing_sound` field on `ActionData` set in about 13 `.tres` files; `animation` is meant to become the real animation name, so the coupling is fragile, but it touches tuned data for a small gain; do it if it ever bites). 6D (no clean fix in GDScript; the sound slots already warn on a mismatch).
- **Risk:** medium (many files, but each change is a literal swapped for a constant).

### 7. `Groups` constants file
- **What:** the home of the item 4 constants: `scripts/combat/groups.gd` (`class_name Groups`, next to `layers.gd`). Built together with item 4 (done 2026-10-12).

### 8. Delay bigger refactors to Phase 2
- **What:** the enemy move selector and an enemy base class both depend on real enemy designs, so refactoring them now would be guessing. They stay in Phase 2 (see 3.13 in `docs/design-later-steps.md`). Nothing to build here.

### 9. Object pooling for `Fx` particles
- **What:** `Fx` creates a `CPUParticles3D` per effect and frees it when done. Default: a pool per effect kind, a fixed starting size, grown when it runs dry, every property reset on reuse. Everything already goes through `Fx.play(tree, kind, point, direction, attach)`, so the change stays inside `fx.gd`.
- **Why:** less creating and freeing of nodes in long fights, and a base for many enemies. At today's spawn rate the gain is small, so it is measured.
- **Risk:** medium (a missed reset shows as the wrong color, count, or sparks that never stop). Test every effect: hits, guard, deflect, heal, resurrect, dust, the blood jet, shockwaves, rings.
- **Open:** whether the tweened rings and the blood jet that follows the enemy are pooled too (default: no, they stay as they are).
- **Done 2026-10-12:** two pools of `CPUParticles3D` in `fx.gd`, by emitter type (`Fx.Pool.SPARKS` for the spark streaks, `Fx.Pool.PUFFS` for mist, dust, motes and glow) instead of one per `Fx.Kind`, because one kind builds several differently set emitters. A pool is made on first use with 8 emitters, grows by one when dry, and frees an emitter that finishes while 64 are idle; a scene reload empties it. `_acquire()` resets the properties the builders do not always set; `_release()` runs on `finished`. The rings and the blood jet's tween are not pooled (the jet's pulses are). No speed-up was measured or expected at 1 enemy plus the dummy (see the build log, "Phase 1.5, item 9").

## 4. Not in this phase

- Moving per-frame math to C# or GDExtension (the engine already does the heavy work; revisit only if the Profiler shows a specific script).
- The enemy move selector and an enemy base class (item 8).
- Any new feature from the Phase 2 backlog.
