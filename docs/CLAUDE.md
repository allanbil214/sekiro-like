# CLAUDE.md: starter prompt

Project: Sekiro-like combat prototype. Godot 4.7.2 (standard build), typed GDScript, Windows, KBM first.

**How the user starts a chat:** "please read the claude.md and let's prepare for step X" (or "item X"). Do this, in order:

1. **Read in full:** `docs/work-agreements.md`, then `docs/handoff.md`, then the plan for item X:
   - **Phase 2 items:** `docs/phase-2-plan.md` (its decisions are the agreed ones; the open backlog is section 13 of the handoff). For items 8 to 12 also read the sections of `docs/phase-4-6-notes.md` that touch the item (the notes are discussion, not agreed decisions; ask open points once at the full check, they are listed in its section 12).
   - **Phase 3 (feel and weight):** `docs/phase-3-plan.md` (its decisions are the agreed ones; the milestones are 3a to 3d). For the reference it is based on, see section 1 of that plan.
   - **Phase 4 or later:** `docs/phase-4-6-notes.md` in full, plus that phase's own plan file once it exists. Phase numbers shifted on 2026-10-20 (a new Phase 3 was inserted): the old 3, 4, 5 are now 4, 5, 6, and texts in `docs/archive/` still use the old numbers.
   - **Only when the task touches it:** `docs/design-later-steps.md` (guard, posture, enemy AI, lock-on, heal, the cleanup refactor; read only the relevant section), `docs/step3-combat-spec.md` (attacks, sheathing; the relevant section), and `docs/animation-pipeline.md` for animation, Blender, rig or timeline-tool work (read it in full, ask for the latest `.blend` or the model files, and send the full check before generating any animation).
2. **Do not open** anything in `docs/archive/` (the build log and the archived checklist and Phase 2 items) or `docs/built-reference.md` before it is needed. If a task needs one specific part, search for it and read only that section (work agreement, section 7).
3. **Look at the latest snapshot** (a zip like `claude_snapshot_*.zip`, uploaded in the chat). Read only the scripts and `.tres` files that item X touches; the handoff's "Where things live" says which files own what, and `docs/built-reference.md` (search it for the system's name) has how a finished system behaves. If the snapshot or a doc is missing, ask for it.
4. **Reply with a short "what I understood" and the full check** for item X (the work agreement, section 1: the request in your own words, scope, assumptions with proposed defaults, files, editor steps, what is not included, delivery format and zip name). Then **wait for an explicit go**. Do not write code before it.

**Rules that always apply** (details in the work agreement):
- The user is on the free web chat: keep replies concise, no long preambles.
- Do not assume design decisions; propose a default and ask once.
- Code: tabs, LF, UTF-8, typed GDScript, surgical edits. Docs keep CRLF.
- Delivery: a zip of complete files for 3+ files, new zip name each time, paths from the project root. Never send `project.godot` whole, `addons/**`, `.uid`, `.import`, or `.godot/`.
- A `.tres` with tuned values can be edited and shipped only if you have the latest snapshot (work agreement, section 3).
- Before delivering, run Godot 4.7.2 headless if it can be downloaded (parse check and a scripted smoke test), and say what was checked [DO NOT DO THIS UNLESS SPECIFICALLY ASKS BY USER!]. Look and feel are the user's to test.
- End every delivery with a short "How to verify".
- When the user says a step is tested: append an entry to the end of `docs/archive/build-log.md` **without reading it**, append the 2 to 4 lines for it to the end of `docs/built-reference.md` (also without reading it), add one line to the handoff checklist (and one to "Where things live" only if a new file or owner appeared), update the plan's status row, and ship the docs zip (work agreement, section 7). Keep the handoff small: long descriptions go in the reference, never in the handoff.
