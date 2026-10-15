# Animation pipeline: Blender to Godot, and the future timeline tool

Read this only when the user asks for animation, Blender, rig, or timeline-tool work. Written 2026-10-13 from a discussion chat. Things marked **[verify]** were not checked and must be confirmed before relying on them. Godot is 4.7.2, Blender is 5.2.2 LTS.

---

## 1. The idea in one paragraph

Gameplay stays data-driven: `ActionData` timings are the truth and the action clock (`action_time`) drives everything. A real animated model only *follows* that clock: the `AnimationPlayer` is seeked to `action_time` with the same speed scale, so adding animation changes data, not combat code (handoff, section 8; step 3 spec, section 8). The animations are made in Blender, exported as separate files, and played in Godot on the character model.

## 2. Files and what each is for

| File | Lives where | Goes into Godot? |
|---|---|---|
| The working `.blend` (model + control rig + all animation actions) | Blender only, outside the Godot project | **No, never.** It is the source. Keep backups. |
| **Export A**: the model | Godot project | Yes. |
| **Export B**: the animations | Godot project | Yes (becomes an `AnimationLibrary`). |

Rules: never edit exported files, fix things in the `.blend` and export again. If the bones change in the `.blend`, re-export **both** files so they stay identical.

### Export A (model)
Select the armature and the two meshes only. glTF export with: Include > **Selected Objects** on; armature **deform bones only** on; animation **off**. A checked export (2026-10-13) had 68 nodes, one root (`Armature`), two meshes (`Beta_Joints`, `Beta_Surface`), 65 skinned bones, all `mixamorig:`, no animations, no `cs_*` nodes. Menu labels are from memory **[verify in 5.2]**.

### Export B (animations)
Select only the armature (no meshes). glTF export with: **deform bones only** on; animation **on**, all actions; sample every frame ("Always Sample Animations" or similar **[verify]**). This bakes the IK result onto the `mixamorig:` bones; the control bones and constraints do not travel in glTF.

## 3. The rig (the file `Untitled.blend`, from the Mixamo X Bot plus an auto control rig)

- 168 bones: the 65 deform bones (`mixamorig:*`, collection DEF, hidden) and about 100 control and helper bones (`Ctrl_*`, `*_IK_*`, `*_FK_*`, poles, foot-roll helpers; collections CTRL visible, MCH hidden). 116 constraints and 100 drivers. The deform bones copy the controls with Copy Transforms and similar constraints.
- **Animate only the `Ctrl_*` bones**, never `mixamorig:` directly.
- **IK/FK switches** are custom properties named `ik_fk_switch` on `Ctrl_Foot_IK_Left`, `Ctrl_Foot_IK_Right` (value read: 0.0) and `Ctrl_Hand_IK_Left`, `Ctrl_Hand_IK_Right` (value read: 1.0). For the legs, 0.0 = IK (confirmed from the constraint influences: IK follow 1.0, FK follow 0.0). For the arms, the file's constraints are both at 1.0 and driven by drivers, so which value means FK is **still unverified**. Claude can settle it headlessly (set the switch, evaluate, and compare the deform bone against the FK and IK controls); do that before keying arms. The working assumption was legs IK and arms FK.
- All 68 `Ctrl_*` bones use **XYZ Euler** rotation (checked), so key `rotation_euler`, not quaternions. Custom properties such as `ik_fk_switch` live on the pose bones and must never be reset or deleted.
- Frame rate 30, default range 1 to 250 (set the range per clip). `mixamo.com` is Mixamo's own 1-frame action on the deform bones (fake user, unassigned): leave it. The `cs_*` custom shape meshes never go into an export. The working file as of 2026-10-13 is `Untitled_katana_clean.blend`: the rig with no assigned action, plus the objects `Katana_Sword` and `Katana_Sheath` parented to `mixamorig:Hips`. Never select those two for Export A or B.
- Rest pose: T-pose. The model is about 1.8 m tall, scale 1, armature transforms applied (rotation 0, scale 1).
- **Facing:** the exported glTF faces **+Z**. Godot forward is **-Z** (the project uses -Z). Fix it in Godot with a 180 degree turn about Y on a child node of `Visual` that holds the model, so gameplay code never knows. (Blender convention for authoring: character faces -Y, Z up; the exporter converts.) An import option that rotates models may exist in 4.7.2 **[verify]**. Checked in the rig: the character faces **-Y** and its left side is **+X** in Blender.
- The katana is a **separate prop** the user will supply (not the `swords` mesh on the old Ayame model). Plan: a `BoneAttachment3D` on the right hand bone holds it, and the `Hitbox` follows it, replacing the placeholder blade.

## 4. Naming and authoring rules

- One Blender action per game action, named exactly like `ActionData.animation` (`attack_1`, `dodge`, `idle`...). Mark each action as fake-user (shield icon) so Blender keeps it.
- 30 fps for every clip. In place: no root travel, because `ActionData` owns movement (`move_speed`, `move_window`). Looping clips (idle, walk) must have the last frame match the first.
- Pose to pose: big poses first (wind-up, contact, follow-through), in-betweens later, polish last.
- Fingers: a sword grip never changes, so key a grip pose once and reuse it across clips.

## 5. Godot side

1. Import Export A as the character. Delete nothing from the rig; put the model under a node that turns it 180 degrees about Y.
2. Import Export B and save its animations as an `AnimationLibrary` resource **[verify the menu path in 4.7.2's Advanced Import Settings]**. Load the library into the model's `AnimationPlayer`. Tracks target bones by name and path, so the same skeleton plays them directly.
3. Seek the `AnimationPlayer` to `action_time` each frame, scaled by the action's speed. The slow-downs (`Player.slash_active_speed`, the enemy `windup_speed` and `active_speed`) then slow the animation too.
4. Different skeletons (another character, Mixamo clips on a different rig) need a `BoneMap` retarget in the import settings. The `mixamorig:` names are the easy case.
5. Replacing the placeholders is its own migration: `SwordVisual` (swings, guard, deflect poses, sheathe and draw), `ReachArms`, `HealArm`, and the body reactions in `PlayerBodyReaction`. Pick one action (`attack_1`) to prove the pipeline first.

## 6. How Claude works on animation here (the Blender sandbox)

Claude's sandbox can run Blender without a window. The part Claude may need to relearn each chat is below. Checked 2026-10-13. The sandbox files reset between tasks, so redo the setup in every new chat, and re-check that it still works before promising anything.

### 6.1 Setup (these exact steps worked)
```
pip install uv --break-system-packages
uv python install 3.13
uv venv --python 3.13 bvenv
pip download bpy --python-version 3.13 --only-binary=:all: --no-deps -d /tmp/bpydl
uv pip install --python bvenv/bin/python /tmp/bpydl/bpy-*cp313*.whl
bvenv/bin/python my_script.py
```
- Match the wheel to the user's Blender (5.2.2 here). The wheel is about 400 MB and takes a minute or two. A plain `pip download bpy` on the default Python 3.12 fails with "no matching distribution"; that is the trap. (A 5.0.1 wheel exists for Python 3.11, but it is a different Blender.)
- Call the venv's Python directly; `source` does not exist in the sandbox shell.
- Run scripts as files. **Never name a script `inspect.py`** (it shadows a standard module and Blender aborts with an InitGoogleLogging error). The EGL warning when rendering and the "Failed to create GPU texture" line are harmless.

### 6.2 What a job looks like
1. Ask for the latest `.blend` (a `.blend1` is only the previous autosave). If the user says go without sending one, proceed on the old file and say so clearly.
2. Send the full check first, as for any step, and wait for the go.
3. Save the result to a **new filename**, never over the user's file. Change render and scene settings only after saving, in memory, so they never reach the saved file.
4. Deliver the `.blend` plus preview stills (`present_files`). State what was checked and what was guessed.

### 6.3 Traps found
- **An action may be assigned to the armature.** Rendering or changing the frame re-evaluates it and resets any pose set by script, so a test render can show no movement while the numbers say it moved. For tests, unassign the action in memory. For authoring, create a new action and assign it (look at `armature.animation_data.action` first).
- **Deleting an action leaves its last pose stored in the file.** When cleaning, reset every pose bone's location, rotation and scale to rest, never the custom properties.
- **Never delete `armature.animation_data`**: it holds the 100 drivers that run the IK/FK switches. Only unassign the action.
- **Print a number that proves a change took effect** (a bone moved by this many metres); do not trust a render alone, and do not trust a number alone either.

### 6.4 Techniques that worked
- **FBX import** arrives at scale 0.01 with a 90 degree rotation: apply location, rotation and scale first. Textures are external relative paths (`../Textures/...`) that do not travel with the FBX, so ask for the folder if they matter. In the texture view mode missing textures show purple; use material mode for previews.
- **Finding parts of a mesh:** `bmesh` connected components (identify them by vertex count and bounding box), then `bpy.ops.mesh.separate(type='LOOSE')` and `bpy.ops.object.join()`; both work headless.
- **Parent an object to a bone without moving it:** set `parent_type='BONE'` and `parent_bone`, set `matrix_parent_inverse` to identity and `matrix_basis` to the wanted world matrix W, update the view layer, read the evaluated world matrix E, then set `matrix_parent_inverse = (E @ W.inverted()).inverted()` and `matrix_basis = W`. The error was about 1e-7 m. A naive script, or the Object Properties parent field, puts the object at the bone's tail.
- **Checks to run after placing or posing:**
  - Clipping: `BVHTree` on the evaluated body mesh; count vertices inside (the sign of the offset from the nearest surface point along its normal) and report the closest distance.
  - Follow test: move a control, compare the object's evaluated position before and after.
  - Stills: the workbench engine renders headless. Orthographic cameras, full body at ortho scale 2.3 looking at height 0.95: front (0, -6, 0.95) rotation (90, 0, 0) degrees; left side (6, 0, 0.95) rotation (90, 0, 90); back (0, 6, 0.95) rotation (90, 0, 180); top (0.1, 0, 6) rotation (0, 0, 0).

### 6.5 What Claude can and cannot do
Claude can open the user's latest `.blend`, key rough poses and the grip with a script, render stills to check them, and save a new `.blend` for the user to open and smooth. Claude can judge still frames, not motion. Rough blocking is the goal; timing, weight and smoothing are the user's job and the part they enjoy. First planned clip: **`idle`**, a 60 frame loop at 30 fps, in place, with a slow breath, a small weight shift, a slight head drift, loose arms and a relaxed grip, keyed on the `Ctrl_*` bones (Euler), named `idle`, fake-user on. Do not start it without the full check and a go.

## 7. Licensing and sources

- The old model **Ayame** (`ayame_wip.gltf`) is a game rip (PS2). Use it for learning only; replace it with an asset the user owns before any release.
- The current stand-in is the Mixamo X Bot. Read Adobe's current Mixamo terms for game use **[verify]**. Other sources discussed: Cascadeur (free tier, check the licence), VRoid Studio (check the model licence), CC0 characters from Quaternius and Kenney.

## 8. Phase 3 idea: a DS Anim Studio style tool (not started)

A Godot **editor plugin** (a `@tool` dock), for the developer only, not an in-game editor. Its role copies DS Anim Studio: it does **not** key bones, it places timing on top of animations. Planned stages, each with its own full check:

1. **Timeline viewer:** the `ActionData` windows (`locked_until`, `cancel_window`, `buffer_window`, `active_hit`, `iframes`, `move_window`) as bars on a time ruler, a scrub bar that plays the real model at that time, and the clip length read from the `AnimationLibrary`.
2. **Drag editing:** drag the bar edges, write back into the `.tres` with undo.
3. **Importer:** make `ActionData` stubs from a model's animations (name, `duration` from the clip length); optionally a small text manifest of windows and events per action.
4. **Event tracks:** sound, fx, swing trail and camera shake markers calling `Sfx` and `Fx`.
5. **Later:** hitbox shape events (size and position per frame), a frame-data table of all actions, hot reload of timings in the running game.

Cautions: window times are action-clock time, not real seconds (the phase speeds slow the clock), so show both. The same `ActionData` serves the enemy. The tool cannot be run or seen by Claude, so expect testing rounds on the UI feel. This is Phase 3; Phase 2 comes first.
