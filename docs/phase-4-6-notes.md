# Phases 4 to 6 and the Phase 2 additions: discussion notes

> Phase numbers shifted on 2026-10-20: a new Phase 3 (feel and weight, `docs/phase-3-plan.md`) was inserted, so the phases discussed here are now 4, 5 and 6 (they were 3, 4 and 5). Texts in `docs/archive/` still use the old numbers.

> Companion to `docs/handoff.md` and `docs/phase-2-plan.md`. Written 2026-10-16 after a long design talk that started from Phase 2 item 8 (the generic interact system). **These are notes, not agreed build decisions.** Nothing here is built. Each item still gets its own full check and an explicit go (work agreement, section 1) before any code.
>
> **Legend.** *(user)* = the user said it or chose it. *(proposed, accepted)* = Claude proposed it and the user agreed or did not object. *(proposed, open)* = Claude's default, not yet agreed, ask once at the item's full check. Anything without a mark is background.
>
> **Read this file** when starting Phase 2 items 8 to 12 (the sections that touch them), and in full when starting Phase 4. It is the place to look before asking the user "what did you want for X", because the user said they will forget today's ideas.

---

## 1. Direction and references

- **Goal (user):** a Yakuza-like, Way of the Samurai (WoTS), Rise of Ronin style game. WoTS is already whimsical in its mechanics and minigames, and the Yakuza side adds dense districts, side stories and activities. Combat stays Sekiro-like.
- **Structure (user): hub-and-spoke.** One dense district to walk around, doors into interiors, a mission board, and missions that load as their own scenes (a mission can be a stealth or combat level like the arenas already built). The user loves it because it fits the team's scale and still gives players plenty of content.
- **Why not a full open world:** the cost is content, streaming and art for huge maps, not code. A port city is "not huge but not small", so the world is a few regions (section 3), not a continent.
- **Phase 2's arenas** stay in the project. They are placeholders and test maps now; later they serve as the maps for radiant quests, random-encounter fights and optional arena modes (section 4, section 5).
- **Feature creep is a known risk** (handoff, section 12). The user agreed that Phase 4 stays a small slice and the rest waits in Phase 5 and 6, with the notes here so nothing is forgotten.

## 2. Setting and protagonist

- **Era (user): Bakumatsu**, the 1860s. Samurai and shinobi still exist next to modern things. **A fictional treaty port around 1868 (proposed, accepted)**: fictional factions, no real historical figures to follow.
  - Note from the talk: samurai were only outlawed in early Meiji (topknot 1871, sword ban 1876). The "outlawed, modernizing" feel can come from the shogunate crumbling and the foreign influence. The reverse-blade sword (sakabato) still fits the tone.
- **Height in the hub (user wanted taller buildings to run around).** Most Bakumatsu towns were one or two storeys of tiled machiya, so height comes from castle keeps, pagodas, fire watchtowers, kura storehouses, two- and three-storey foreign trading houses of a treaty port, and tile roofs for rooftop running.
- **Protagonist (user): fixed, silent, female for now** (she is the "main main" character; the user may change it later). Silent with dialogue choices (WoTS and Yakuza style): no voice lines, no per-line animation, dialogue is the NPC's text plus the player's choices.
  - The player's look sits behind **one swap point**, and the save stores an `appearance_id` from day one (proposed, accepted).
  - Write NPC lines without hard-coded pronouns where possible, so changing the gender later is cheap (proposed, accepted). A woman with a sword in Bakumatsu is unusual, which gives NPCs good reaction lines.
  - **Open:** her name.
- **Appearance later (user):** about five preset looks (WoTS, mostly looks only), then a character customizer (Skyrim, Fallout, Dragon's Dogma). The user first said "perhaps phase 5, definitely outside Phase 4", then agreed to push all art later, so both are in Phase 6 (section 10).
- **Capsule people are fine (user):** the user is still learning 3D modeling and animation and does not mind bean people for the gameplay phases.

## 3. The world

- **Three regions in one scene (user):** a city part, a residential part, and a farmland and tiny village part, with **no loading screen** between them.
- **Interiors with no loading screen either (user).** Proposed approach (proposed, accepted):
  - The interior is a separate scene that **preloads in the background (threaded, `SceneLoader` already does this) as the player approaches the door**. A door animation or sound covers the moment, then the player is placed inside the interior (which sits elsewhere in the same world).
  - **The veil (user's idea, "like eyes adjusting"):** not full black but a translucent **grayish or whitish veil**, with the player and the environment still faintly visible. It is **strongest right at the swap (about 70 to 80 percent)**, then eases out, about half a second in all. Color, peak strength and timing are `@export` values to tune.
  - Caveat: a veil does not hide a frozen frame, so the background preload and the peak-at-swap timing are what prevent a visible hitch.
  - **Missions still load as their own scenes** with the existing loading screen (proposed default). Only the world and its interiors are seamless.
- **Streaming (user: "definitely Phase 4 at least the streaming part, and Phase 5 for the regions").** Godot has no built-in world streaming. The plan (proposed, accepted):
  - Split the world into **cells**, each a small scene that loads and unloads around the player.
  - Costs to watch: instancing hitches (smaller cells, add nodes a few at a time), **one navigation region per cell with matching edges** so enemies can cross borders, spawning (the population manager already works by distance), and saving (it stores flags, not scene state, so it survives cell loading).
  - **Phase 4 builds the cell system as a prototype on a few big test blocks, with a flag to keep all cells loaded.** Phase 5 builds the three regions. Real budgets depend on real art, and the art is last.

## 4. Quests and the mission framework

- **One mission framework (proposed, accepted)** serves everything below. Objectives: reach, kill, stay unseen, talk. Triggers, success and fail, rewards, a mission board.
- **Main campaign (user):** handcrafted, with branching story and decisions (WoTS style). Kept **flag-based** (proposed, accepted): a few big forks, and smaller choices that change later dialogue, shops or the ending. Branching missions multiply with every fork, so they are avoided.
- **Side quests (user):** the same missions, just smaller.
- **Radiant quests (user, Fallout and Skyrim style):** generic repeatable quests built from **templates filled from data** (target, location, reward), for example "assassinate X in arena Y", "defeat N enemies", "retrieve an item", "infiltrate unseen". The existing arenas (the Stealth Compound, the fighting arenas) are the maps. Built **after** the handcrafted ones prove the framework (proposed, accepted).
- **Quest givers (user):** side quests and radiant quests come **either from an NPC directly or from a notice board**. Both are just quest givers reading the same quest data: an NPC offers it through dialogue, the board is an interactable that lists the available quests.
- **Random encounters** are part of the same data idea, see section 5.

## 5. Life in the hub

- **Real NPCs and crowd NPCs (user).**
  - **Real NPCs:** `Interactable`s with dialogue and quests.
  - **Crowd NPCs (user, "Persona 5's flat looking 3D NPC" and Yakuza's population):** cheap flat-style people who wander the navmesh with **no awareness rays**. When a fight starts they **circle at a distance like spectators**, and when the player gets close or hits near them, or they feel in danger, they **run away**.
  - **Talking to a crowd NPC (user):** they only give one or two generic lines, like "what?" or "go away". **The lines change with the player's reputation** (user, section 6).
- **Random encounters (user).** In Yakuza and WoTS the encounters are real people wandering the hub who bump into you, or factions that became hostile because of your decisions (bandits, hunters). **They spawn in the hub (user)**, which needs the navmesh (Phase 2 item 12); the player can avoid them via the rooftops.
  - **Ambient wanderers:** thugs and bandits using the existing awareness system (`use_awareness`): you can avoid them, sneak up on them, fight them, break the line of sight, or go up to a roof; they search and return to their post.
  - **Hunters:** faction enemies spawned by the player's choices. They head straight for the player; the player can lose them via the rooftops. (Phase 5, with per-faction reputation.)
  - **Population manager (proposed, accepted):** spawns and despawns wanderers and crowd NPCs by distance from the player. Dozens of awareness enemies casting rays would hurt performance.
  - **Encounter table (proposed, accepted):** decides **who roams a district** rather than rolling dice: entries like "bandits, 3 soldiers, hub streets, any time" or "faction X hunters, only if flag `faction_x_hostile` is set". Flags and reputation feed it.
  - **Frequency option (proposed, accepted):** a Gameplay option for how often encounters happen, or off.
  - **Fallback (proposed):** loading a fight arena (an existing fighting arena, then back to the hub) for fights that start inside interiors.
  - **Basic encounter in Phase 4, the full table, hunters and factions in Phase 5.**
- **Rules to keep in mind:** the enemies have **no pathfinding** until item 12; a ground enemy on a navmesh **cannot climb**, so rooftops are the escape route and rooftop guards get their own walkable area; fighting in narrow streets needs a camera check, because the spring arm fights walls there.
- **Rooftop guards and towers (user, "Assassin's Creed style, an old Japanese tower with a bell").**
  - **Edo fire watchtower (hinomi-yagura) with a bell (hansho)**, and a Western clock tower or lighthouse beside it for the old-versus-new feel (the clock tower or lighthouse is proposed).
  - A **watchman** on a tower or roof: if he spots the player, he **rings the bell and every enemy in the district becomes alert**. The shout system from item 7 exists but reaches about 10 m; this reaches the district. Counterplay: sneak up, kill him with the death from above, climb the tower and silence the bell.
  - **Map reveal (Phase 5):** climbing a tower reveals the district map with notice boards and quest givers, which gives the ledge and wall-jump traversal a purpose.
  - Rooftop guards on ordinary roofs too (user).

## 6. Reputation and the law

- **The user's wish:** a reputation system. A ronin who kills anyone becomes hated; guards and the "police" search for her, with wanted posters. A ronin who does good becomes a kind of vigilante: the police know her but mostly ignore her, and still do justice if she is caught sneaking. The crowd NPCs' one-liners change too.
- **Crimes are witnessed (proposed, accepted):** a crime counts only when an awareness enemy sees it or a body is found. The sight and corpse-discovery code from item 7 already does this, so stealth matters.
- **Notoriety and bounty (proposed, accepted):** start with **one notoriety number plus a bounty**. High: police patrol and search for the player (the existing search and roam behavior), wanted posters in the hub. Good: police mostly ignore her.
- **Phase 4:** one notoriety number and one police type. **Phase 5:** **per-faction standing**, which drives the WoTS-style endings.
- **Police (proposed):** Bakumatsu officers carrying a **jitte**, a non-lethal arrest weapon.

## 7. Non-lethal combat (Phase 2 item 10)

- **Reverse blade (user):** like WoTS, the sword is reversed so the blunt edge is used. A toggle.
- **Health damage is halved (user).** **Posture damage: the user asked "halved too?"; proposed default is FULL posture damage (proposed, open)**, so fights do not get too long and the deathblow knockout stays reachable.
- **Deathblow (user):** makes the enemy **unconscious** instead of killing.
- **Stealth deathblow (user):** with the reverse blade it becomes a **strangle (choke)** until unconscious.
- **Knocked-out bodies (proposed, accepted):** reuse the body and tending code from items 7d and 7e, with a milder reaction ("wake him up" instead of an alarm). Needs a lethal flag on `HitData` and a knocked-out state; a knockout replaces death at zero health.
- **Why it is needed:** the reputation system rewards non-lethal play, and a vigilante path needs it.

## 8. Ranged

- **Enemies:** **archers stay (user)**, plus revolvers and rifles for the era (the "ranged enemies" backlog item, now Phase 5). They use the projectile system built in Phase 2 item 11.
- **No yumi for the player (user's lean, proposed, accepted).** It pulls the game toward shooting from a distance and away from sneaking and close kills; it needs an aim mode, projectiles, ammo, a HUD and animations; and enemy archers need the projectile system anyway, so the user can fight archers in Phase 5 and decide whether a bow is missed.
- **Throwables (user), Phase 2 item 11:** a **Sekiro-style prosthetic idea** done as a normal throw with **selectable ammo**: a rock, a shuriken, a kunai, a piece of broken ceramic, as lethal or non-lethal options. Details are in the Phase 2 plan, item 11 (a `ThrowableData` resource with damage, posture, a lethal flag, noise, count, `speed` and `gravity`). The noise at the landing point is the best part: a thrown rock can lure a guard away from his post.
- **Item system (user, 2026-10-19):** items work like Tenchu and Nightreign: the gourd keeps its own quick button, every other item sits in one selectable list (`use_item`, `cycle_item`), and the HUD slot is bottom right like Sekiro's prosthetic slot. Throwables are the first items; onigiri, marking rice and similar come later on the same `ItemData` base (Phase 2 plan, item 11). Phase 4 saves the item counts.
- **Parking lot:** extra prosthetic-style tools (smoke pellet and similar) only after the basic throw exists.

## 9. Systems for Phase 4 and 5

- **Game state and saving:** flags and variables, save and load. START becomes NEW GAME with a CONTINUE above it (as `docs/phase-2-plan.md` item 1 already says). Ammo counts, `appearance_id`, notoriety and quest state are saved.
- **Dialogue and choices:** data-driven and branching. Needed for NPCs and the WoTS-style consequences. Silent protagonist (section 2).
- **Items, money, shops, equipment:** WoTS-style weapon variety (proposed default: **variety through katana variants and stats, no new weapon types**; the user said the katana stays the weapon and does not want a naginata or similar; **open**), Yakuza-style food and healing.
- **Activity framework and minigames (user: whimsical like WoTS and Yakuza):** one common shape (enter, play, score, reward, exit), so each minigame is a small scene. Prove it with one tiny minigame in Phase 4, more in Phase 5.
- **Progression:** XP or skills, and faction reputation (section 6), in Phase 5.
- **A day and night cycle:** not discussed in depth; **open**.
- **Seamless doors and the veil, the cell streaming:** section 3.

## 10. The phases

- **Phase 2 (still open): items 8 to 12**, in the order of the numbers (the user asked that the numbers match the build order):
  - **8** interact system, **9** wall hug, **10** non-lethal combat, **11a and 11b** throwables, **12a** navmesh and **12b** navigation links (jump, drop, climb). Details and the agreed behavior are in `docs/phase-2-plan.md`.
  - The rest of the old backlog (ledge enhancements, heal and death extras, lock-on extras, sound extras, more enemy body feedback, the sweep duck) stays in handoff section 13 and is picked as the user likes; the sweep duck and real animation wait for real models.
- **Phase 3, feel and weight (inserted 2026-10-20; not part of these notes):** combat and movement tuning, tools and a placeholder mannequin; see `docs/phase-3-plan.md`.
- **Phase 4, game flow: a small vertical slice.** Enough to feel whether the game wants missions or a free hub.
  - One hub district with NPCs and doors into interiors (the scene loader exists), seamless interior doors with the veil, and the **cell-streaming prototype** (section 3).
  - Game state and saving, dialogue with choices, items and money with basic shops.
  - The mission framework with **one real quest**, a **notoriety number** and **one police type**, a **basic random encounter**, a mission board.
  - The activity framework with **one tiny minigame**.
  - Population manager and crowd NPCs (the first version), at least enough for the hub to feel alive.
- **Phase 5, content and systems:** everything gameplay that did not fit the slice.
  - The three regions (city, residential, farmland and village) streamed in one scene.
  - Radiant quests and the full encounter table, per-faction reputation, hunters, the endings that depend on reputation.
  - Archers and other ranged enemies (projectile system from Phase 2 item 11), enemy variety (jumpers and chasers).
  - Bell towers with the map reveal, more minigames and districts, progression (XP or skills).
- **Phase 6, art:** the art pipeline (Blender, glTF, an `AnimationPlayer` following the action clock; `docs/animation-pipeline.md`), real animation, the **five preset looks**, then the **character customizer**.
- **Parking lot:** throwable extensions (smoke pellet and similar), a possible player ranged weapon if the user ever wants one, full open-world scale.

## 11. How the interact system prepares for all this (Phase 2 item 8)

- An `Interactable` only says what it is (prompt text, priority, `can_interact()`); what happens next is separate (door, chest, switch, NPC line now; notice board, shop, minigame start later). Phase 4 adds behaviors without touching the picker.
- A door's lock reads a small in-memory `GameFlags` now. Phase 4 adds saving to it without changing any door.
- `interact` has three jobs, with one priority order: in the air a ledge grab, on the ground the nearest `Interactable` in front, and on the ground with nothing to interact with, the wall hug (item 9).
- Crowd NPCs are also `Interactable`s that say one or two lines from a pool chosen by the player's reputation.
- A dialogue freeze (the player locked while talking) is Phase 4; item 8's placeholder NPC just shows one line of text.

## 12. Open questions (ask once at the item's full check)

1. The protagonist's **name**.
2. **Posture damage while non-lethal:** full (default) or halved.
3. **Wall hug entry:** a single `interact` press (default). The user quoted a Sekiro forum thread saying the PC players pressed E twice; confirm at item 9.
4. **Weapon variety:** katana variants and stats only (default), or other weapon types later.
5. **A day and night cycle:** wanted or not.
6. **Throwables and items:** the exact damage and stun numbers (placeholders to tune by playing); whether more ammo types are wanted; a single item list (default) or categories on separate buttons later.
7. **Fallback fights** (a fighting arena loaded from the hub) or only fights in the street.
8. How mission scenes are named and listed (an `ArenaData`-like resource per mission?) when the mission framework is designed.
