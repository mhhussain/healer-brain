# Handoff: building routing, the big dungeon and gear

Written on 15 November 2026 as the starting brief for a new session. Nothing in the plan is built yet. **Start at milestone 9.**

Read these, in this order:

1. This file.
2. [`routing-and-gear-plan.md`](routing-and-gear-plan.md): what was agreed and the five milestones. It is the spec.
3. [`DESIGN.md`](../DESIGN.md): the rules of the game as built.
4. [`game/README.md`](../game/README.md): where the code lives and the commands to test, run and export.

## 1. Where things stand

- The game is the Godot 4.7.2 project in `game/` (GDScript, Compatibility renderer, single-threaded web export). It is published at https://mhhussain.github.io/healer-brain/.
- `main` is the only branch that matters. A push to `main` runs `.github/workflows/deploy.yml`: import, the GUT tests, web export, publish. If a test or the export fails, nothing is published.
- 161 tests pass at commit `13e792c`.
- All-AI run times, which are the balance check: about 7:25 to 8:05 at level 1, 10:15 to 11:00 at level 5, 12:00 to 13:00 at level 7.
- The dungeon is the Drowned Abbey: one straight hall, 6 trash packs of 4 and 3 bosses, 27 enemies, a 14-minute timer.
- There is no map, no route, no count, no gear and no coin.

## 2. How the owner wants the work done

- **Chat replies under 300 words.**
- **Pause at each review point** (the end of each milestone, and wherever the plan says "the owner approves"). Have the headless checks done before pausing. The owner plays in the Godot editor (F5) or in the browser. How it feels is their call; tests cannot claim it.
- **Design questions go in rounds**, each as `❓ **Qn** - **title**: … ➡️ recommendation`, worded so "yes" accepts the recommendation. Find facts yourself; ask only for decisions.
- **Push to `main`** when a piece is done and verified, then check the publish run and the live site.
- Keep `DESIGN.md`, the READMEs and the plan in step with the code. When a milestone lands, move its decisions into `DESIGN.md`.
- Commit messages follow the repo's existing style: a plain sentence saying what changed.

## 3. Rules that must hold

- **`threads.env`** at the repo root holds the addresses and keys for the owner's hosted Kokoro (voice), Steel (browser) and Firecrawl (web pages) services. Never print, copy or commit it. Load it inside a command: `set -a; . ./threads.env; set +a`. Use these hosted services; install nothing like them on the owner's machine.
- **`steel-proxy/`** stays untracked. Never `git add` it.
- **Steel.** Tell the owner before starting any session so they can watch. The quota is one session, so always release it. Steel cannot draw the Godot web export; the owner's browser is the visual check.
- **Accounts.** Never sign up for anything. Ask the owner, who will make the account and provide a credentials file.
- **The save.** Only `game/scripts/app.gd` reads or writes the real save file. Tests and tools set `SaveStore.path` to a file of their own.
- **Rules stay pure.** `game/rules/` is plain GDScript with no scene in it, tested on its own. Nodes ask the rules what is allowed and react to `Combat.event` dictionaries. Routes, count, items and teams belong in `game/rules/` as data and logic; the map and the gear screens belong in `game/ui/`.
- **Tests and balance runs** always use `--fixed-fps 60`. Without it the all-AI tests run in real time.
- **Shader stalls.** The first time the engine draws a new kind of thing it builds a shader, which freezes the game for a moment. `Run.warm_up` draws one of everything behind the loading card. Anything new that can appear during a run (a new enemy, a new room piece, ground markers, patrol paths) must be added to the warm-up, and effect materials must keep the same settings as the shadow under units.

## 4. What the code assumes today

Milestone 9 exists to remove these. Line numbers are as of commit `13e792c` and will drift; search for the names.

**The dungeon is one hall, and the rules know it.**

- `Combat.next_pack()` returns the first pack in list order that is not cleared (`rules/combat.gd`, about line 173). This is the whole of today's "route".
- `Combat.room_start()` works out which room a position is in from its x alone (about line 181).
- The run finishes only when **every** pack is cleared (about line 948). `DESIGN.md` section 2 says "all three bosses dead". In a hall the two are the same; with count they are not.
- A wipe puts the party at the `entry` of the first engaged pack, resets engaged packs to full health, removes summons and restores pillars (about lines 964 to 988).
- `Music.loop_for` picks the music from the first uncleared pack's zone, and the HUD shows "Rooms x/y" (`ui/hud.gd`, about line 154). Check `rules/story.gd` for lines tied to pack order.

**The level description** (`rules/level_def.gd`; the Abbey is in `rules/levels.gd`, and a two-room sandbox follows it).

- Fields: `name`, `floors` (rectangles), `walls`, `pillars`, `doors` ("in order along the hall"), `start`, `zones`, and `packs`.
- A pack is a dictionary: `name`, `boss`, `lamp`, `enemies`, `zone`, `center`, `entry`, `pull_from`, `stand`, `room_left`.
- There are no gates, patrols or room graph. Navigation is baked from the geometry by `scripts/level_builder.gd`. Enemies stand in a ring round the pack's centre.

**The AI tank** (`rules/hero_ai.gd`).

- `_tank_travel` walks to the pack's `pull_from`, and pulls when an enemy is within 27 m and in sight and `_party_ready` holds: everyone alive, above 80% health, within 22 m, healer mana above 60%. It also waits for a human who is more than 28 m behind.
- It then walks to the pack's `stand` until its x passes `stand.x - 1`, taunts loose enemies, moves among the ranged enemies if any are far away, and otherwise plants where it is.

**AI damage dealers and healer.**

- Melee stand behind the target (`_melee_pos`).
- Ranged and the healer sample rings of spots round an anchor (`_ranged_pos`). A spot must be in sight, out of frontals and ground zones, more than 14 m from any idle pack, and not behind the start of the tank's room (an x comparison again).
- Out of combat everyone follows the tank.

**Waking and chasing.**

- Any hero within 11 m and in sight wakes the whole pack. So does any damage, taunt or interrupt.
- Packs are not linked to each other. Woken enemies chase without limit; there is no leash. Pulling two packs to one spot therefore already works in the rules. Only the tank's planning is missing.

**The player** can take any of the four slots, tank included (`save.slot`, set on the setup screen in `ui/screens.gd`). The AI plays the rest. F9 lets the AI play the player's hero too.

**The save** (`rules/save_data.gd`, written as JSON by `scripts/save_store.gd`) holds `unlocked`, `bests` per hero, `party`, `slot`, `level`, `volume`, `muted` and the bindings. It holds nothing per dungeon and no items. Add a version number when it grows.

**Screens.** There is no overview camera. The pause screen (`Screens.pause` in `ui/screens.gd`) is a panel over the paused scene and is the pattern for the map during a run.

## 5. Milestone 9, to begin with

Goal: rooms joined by doors, enemy count, completion on bosses plus count, and lamps as wipe points, with the Abbey playing exactly as it does now.

A suggested order:

1. Read the files named in section 4 and confirm the assumptions still stand.
2. Put a short design to the owner where there is a real choice (for example how rooms and doors are written in a level's description). Skip questions the plan already answers.
3. Change the level description to rooms and doors, and describe the Abbey in it.
4. Replace every left-to-right comparison with a question asked of the rooms.
5. Add count to enemies and to the level; change the end of a run to bosses plus count.
6. Make a wipe return to the last lit lamp.
7. Checks: all tests pass, the all-AI times at levels 1, 5 and 7 have not moved, the web export builds.
8. Update `DESIGN.md` and the READMEs, push, check the publish run, then stop for the owner to play.

"Which pack next" should already go through one place that milestone 10 can hand a route to.

## 6. Checks before every pause

Commands are in `game/README.md`. In short:

- Import the project headless and fix every error and warning it prints.
- Run the GUT tests with `--fixed-fps 60`.
- Run the balance runner (`game/tests/tools/sim.gd`) when rules or AI changed.
- Export for the web.
- For a look without the owner: `game/tests/tools/capture.gd` or `screens.gd` with `--write-movie` and an absolute path into the git-ignored `build/` folder.
- After pushing: watch the workflow run, then fetch the live site.

## 7. Things to bring to the owner, when their milestone comes

- Milestone 10: which of the map and mute keeps the M key.
- Milestone 11: the dungeon's name, a layout sketch, the new enemies, the four bosses, the default route.
- Milestones 12 and 13: the list of named items and their effects, and the numbers listed in section 8 of the plan.
