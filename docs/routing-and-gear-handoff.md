# Handoff: building routing, the big dungeon and gear

Written on 15 November 2026 as the starting brief for a new session, and brought up to date the same day when milestone 9 was built. **Milestone 9 is built and waits for the owner to play it. Start at milestone 10** once they have.

Read these, in this order:

1. This file.
2. [`routing-and-gear-plan.md`](routing-and-gear-plan.md): what was agreed and the five milestones. It is the spec.
3. [`DESIGN.md`](../DESIGN.md): the rules of the game as built.
4. [`game/README.md`](../game/README.md): where the code lives and the commands to test, run and export.

## 1. Where things stand

- The game is the Godot 4.7.2 project in `game/` (GDScript, Compatibility renderer, single-threaded web export). It is published at https://mhhussain.github.io/healer-brain/.
- `main` is the only branch that matters. A push to `main` runs `.github/workflows/deploy.yml`: import, the GUT tests, web export, publish. If a test or the export fails, nothing is published.
- 171 tests pass with milestone 9 in.
- All-AI run times, which are the balance check: about 7:25 to 8:05 at level 1, 10:15 to 11:00 at level 5, 12:00 to 13:00 at level 7. At level 7 a few runs in eighteen wipe once on the last boss and go over the time; that was so before milestone 9 too (four of eighteen before, two after, on the same seeds).
- The balance runner is exactly repeatable: the same code, level, party and seed give the same line. Milestone 9 was checked with it: with the two AI rules that used to compare positions along the hall put back, every run without a wipe matched the old code line for line.
- The dungeon is the Drowned Abbey: the landing and nine rooms in a row, 6 trash packs of 4 and 3 bosses, 27 enemies, a count of 92 that asks for every pack, a 14-minute timer.
- There is no map, no route, no gear and no coin.

## 2. How the owner wants the work done

- **Chat replies under 250 words.**
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

## 4. What the code does today

Search for the names; line numbers drift.

**The level description** (`rules/level_def.gd`; the Abbey is in `rules/levels.gd`, and a two-room sandbox follows it).

- `rooms` (`name`, `rect`, `zone`) and `doors` (`a`, `b`, `rect`, `pos`), added with `add_room` and `add_door`, which also lay their floor. A room is one rectangle. A doorway's floor belongs to neither room.
- `packs`: `name`, `boss`, `lamp` (the line shown when a boss falls), `enemies`, `room`, `center`, `pull_from`, `stand`. They are listed in the order the party takes them with no plan.
- `lamps` (`name`, `pos`, `pack`: the boss pack that lights it, or -1 for one that burns from the start) and `count_needed` (0 asks for everything).
- Questions it answers: `room_at`, `door_at`, `zone_at`, `same_room(of, p, clear)` and `doors_between(from, to)` (the fewest doorways between two spots).
- There are no gates or patrols yet. Navigation is baked from the geometry by `scripts/level_builder.gd`. Enemies stand in a ring round the pack's centre.

**The rules** (`rules/combat.gd`).

- `Combat.enter(def)` puts a run in a place: packs, enemies, lamps, count. `Run` and the test harness both use it. Heroes are added first so that they keep the first ids.
- `Combat.next_pack()` is the one place that answers "which pack next". It returns the first in the level's order that still stands. **Milestone 10 hands it a route.**
- `count()`, `count_goal()` and `complete()`: count is what the dead are worth (`EnemyDef.count`), and a run finishes when every boss pack is cleared and the count is met.
- A wipe resets every engaged pack and puts the party round `last_lamp()`.
- `can_attack()` and `HeroAI._tank_combat` still take "the fight" to be the first engaged pack in list order. A pull of several packs (milestone 10) must change that.
- Nothing compares positions along the hall any more. `Music.loop_for` goes by the fight's room or the room you stand in; `Story` gives a line to every second pack by the order they are first pulled; the HUD shows count as a percentage.

**The AI tank** (`rules/hero_ai.gd`).

- `_tank_travel` walks to the next pack's `pull_from`, and pulls when an enemy is within 27 m and in sight and `_party_ready` holds: everyone alive, above 80% health, within 22 m, healer mana above 60%. It also waits for a human who is more than 28 m behind.
- It then walks to the pack's `stand` until it is within 1.1 m of it (`ARRIVED`), taunts loose enemies, moves among the ranged enemies if any are far away, and otherwise plants where it is. `AIState.entered` is not cleared by a wipe, so on a second try at the same pack the tank fights where the enemies reach it.

**AI damage dealers and healer.**

- Melee stand behind the target (`_melee_pos`).
- Ranged and the healer sample rings of spots round an anchor (`_ranged_pos`). A spot must be in sight, out of frontals and ground zones, more than 14 m from any idle pack, and in the tank's room at least 1.5 m clear of its doorways (`Combat.same_room`).
- Out of combat everyone follows the tank.

**Waking and chasing.**

- Any hero within 11 m and in sight wakes the whole pack. So does any damage, taunt or interrupt.
- Packs are not linked to each other. Woken enemies chase without limit; there is no leash. Pulling two packs to one spot therefore already works in the rules. Only the tank's planning is missing.

**The player** can take any of the four slots, tank included (`save.slot`, set on the setup screen in `ui/screens.gd`). The AI plays the rest. F9 lets the AI play the player's hero too.

**The save** (`rules/save_data.gd`, written as JSON by `scripts/save_store.gd`) holds `unlocked`, `bests` per hero, `party`, `slot`, `level`, `volume`, `muted` and the bindings. It holds nothing per dungeon and no items. Add a version number when it grows.

**Screens.** There is no overview camera. The pause screen (`Screens.pause` in `ui/screens.gd`) is a panel over the paused scene and is the pattern for the map during a run.

**Left for later milestones.** The 14-minute limit is still the constant `Combat.TIME_LIMIT`; the big dungeon needs it per level. Lamps are points in the data with no figure in the scene; the map will want to draw them, and anything that draws them in a run must go in the warm-up.

## 5. Milestone 10, to begin with

Goal: the route as data, the map planner, and the AI following a route on the Abbey. The plan's section 2 is the spec, and section 6 lists what the milestone holds.

- Settle with the owner first: which of the map and mute keeps the M key.
- Start from `Combat.next_pack()`, and from the two places that assume one pack to a fight.
- The Abbey's default route is its packs in order, one to a pull.

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
- Milestone 11: the dungeon's name, a layout sketch, the new enemies, the four bosses, the default route, and the count it asks for.
- Milestones 12 and 13: the list of named items and their effects, and the numbers listed in section 8 of the plan.
