# CLAUDE.md: starter prompt

Project: Sekiro-like combat prototype. Godot 4.7.2 (standard build), typed GDScript, Windows, KBM first.

**How the user starts a chat:** "please read the claude.md and let's prepare for step X". Do this, in order:

1. **Read in full:** `docs/work-agreements.md`, then `docs/handoff.md`, then the spec for step X.
   - Steps 3a to 3c: `docs/step3-combat-spec.md`. (skip if Step 4 or later, unless you need to remind you or something)
   - Step 4 or later: `docs/design-later-steps.md` (read it normally from here on).
2. **Do not open** `docs/archive/build-log.md` or `docs/design-later-steps.md` before they are needed. If a task needs one specific part, search for it and read only that section (work agreement, section 7).
3. **Look at the latest snapshot** (a zip like `claude_snapshot_*.zip`, uploaded in the chat). Read only the scripts and `.tres` files that step X touches; the handoff's "What the finished steps built" says which files own what. If the snapshot or a doc is missing, ask for it.
4. **Reply with a short "what I understood" and the full check** for step X (the work agreement, section 1: the request in your own words, scope, assumptions with proposed defaults, files, editor steps, what is not included, delivery format and zip name). Then **wait for an explicit go**. Do not write code before it.

**Rules that always apply** (details in the work agreement):
- The user is on the free web chat: keep replies concise, no long preambles.
- Do not assume design decisions; propose a default and ask once.
- Code: tabs, LF, UTF-8, typed GDScript, surgical edits. Docs keep CRLF.
- Delivery: a zip of complete files for 3+ files, new zip name each time, paths from the project root. Never send `project.godot` whole, `addons/**`, `.uid`, `.import`, or `.godot/`.
- A `.tres` with tuned values can be edited and shipped only if you have the latest snapshot (work agreement, section 3).
- Before delivering, run Godot 4.7.2 headless if it can be downloaded (parse check and a scripted smoke test), and say what was checked [DO NOT DO THIS UNLESS SPECIFICALLY ASKS BY USER!]. Look and feel are the user's to test.
- End every delivery with a short "How to verify".
- When the user says a step is tested: append an entry to the end of `docs/archive/build-log.md` **without reading it**, update the handoff checklist and the 2 to 4 lines for the step, and ship the docs zip (work agreement, section 7).
