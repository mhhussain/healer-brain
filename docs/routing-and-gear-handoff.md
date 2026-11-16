# Handoff: building routing, the big dungeon and gear

Written on 15 November 2026 as the starting brief for a new session, and brought up to date as milestones 9 and 10 were built. **Milestone 10 is built and waits for the owner to play it. Start at milestone 11** once they have.

Read these, in this order:

1. This file.
2. [`routing-and-gear-plan.md`](routing-and-gear-plan.md): what was agreed and the five milestones. It is the spec.
3. [`DESIGN.md`](../DESIGN.md): the rules of the game as built.
4. [`game/README.md`](../game/README.md): where the code lives and the commands to test, run and export.

## 1. Where things stand

- The game is the Godot 4.7.2 project in `game/` (GDScript, Compatibility renderer, single-threaded web export). It is published at https://mhhussain.github.io/healer-brain/.
- `main` is the only branch that matters. A push to `main` runs `.github/workflows/deploy.yml`: import, the GUT tests, web export, publish. If a test or the export fails, nothing is published.
- 214 tests pass with milestone 10 in.
- All-AI run times on the safe way, which are the balance check: about 7:25 to 8:05 at level 1, 10:15 to 11:00 at level 5, 12:00 to 13:00 at level 7. At level 7 a few runs in eighteen wipe once on the last boss and go over the time.
- The balance runner is exactly repeatable: the same code, level, party and seed give the same line. Use it to prove a change alters nothing: run the old commit from a `git worktree` in its own folder and compare lines. Milestones 9 and 10 were both checked this way. Milestone 10 changed one thing in a run on the safe way: after a wipe the tank goes in again as it did the first time.
- The dungeon is the Drowned Abbey: the landing and nine rooms in a row, 6 trash packs of 4 and 3 bosses, 27 enemies, a count of 92 that asks for every pack, a 14-minute timer.
- Routes, the map planner and the AI that follows a route are in. There is no gear and no coin.
- What a route wins in the Abbey is small, and it is in `DESIGN.md` section 9: plain double pulls and "go at once" win nothing, and double pulls held behind a wall win 20 to 30 seconds at level 5 with some risk. Whether that is enough is the owner's call; the big dungeon, with skips and a count to choose, is where routing is meant to matter.

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
- `id` (what saved routes know the level by) and `default_route` (pulls as lists of pack numbers; empty means every pack by itself).
- Questions it answers: `room_at`, `door_at`, `zone_at`, `same_room(of, p, clear)`, `doors_between(from, to)` (the fewest doorways between two spots), `walk_length(from, to)`, `pack_count(i)` and `count_goal()`.
- There are no gates or patrols yet. Navigation is baked from the geometry by `scripts/level_builder.gd`. Enemies stand in a ring round the pack's centre.

**Routes** (`rules/route.gd`).

- A `Route` is `name`, `level` (the level's id) and `pulls`; a pull is `{"packs": [int], "spots": {place in the party: Vector3}, "go": bool, "note": String}`. Packs are named by their place in the level's list. It has the editing steps the map uses (`toggle`, `add_pull`, `move_pull`, `merge_up`, `set_spot`, `prune`), `to_dict` and `from_dict` (which keeps only what makes sense for the level), and `to_code` and `from_code` (`FF1:` and base64 of the same data).
- `Route.default_for(def)` is the level's `default_route`, or every pack by itself in order. Per-pull orders can be added to a pull later: unknown keys are dropped on reading and missing ones take their defaults.

**The rules** (`rules/combat.gd`).

- `Combat.enter(def, route)` puts a run in a place: packs, enemies, lamps, count, and the plan (the level's own if none is given). `Run` and the test harness both use it. Heroes are added first so that they keep the first ids. `Run.route` is what the app hands a run; the run copies it.
- `Combat.next_pull()` is the one place that answers "what next": the first pull of the route with a pack still standing, as `{"index", "packs", "spots", "go"}`; once the plan runs out, the nearest pack (by `LevelDef.walk_length`), or the nearest boss once the count is met.
- `Combat.fight` is the pull being fought, set when a fight begins and emptied when it ends. A fight begun by a pack the plan did not expect is a pull of that pack alone. `gathered()` says whether all its packs are awake.
- `can_attack()` goes by the pack woken last, and holds everyone while an AI tank gathers, for at most `GATHER_LIMIT` seconds.
- `count()`, `count_goal()` and `complete()`: count is what the dead are worth (`EnemyDef.count`), and a run finishes when every boss pack is cleared and the count is met.
- A wipe resets every engaged pack and puts the party round `last_lamp()`.
- Nothing compares positions along the hall. `Music.loop_for` goes by the fight's room or the room you stand in; `Story` gives a line to every second pack by the order they are first pulled.

**The AI tank** (`rules/hero_ai.gd`).

- `_tank_travel` walks to the `pull_from` of the next pull's first pack, and wakes it when an enemy is within 27 m and in sight and `_party_ready` holds (everyone alive, above 80% health, on their planned spot or within 22 m, healer mana above 60%), or at once if the pull says go. It also waits for a human who is more than 28 m behind and not on their own planned spot.
- `_tank_combat` first gathers: for each pack of `fight` still asleep it hails it if it can, or else walks at it. Then it goes to the planned tank spot, or the `stand` of the pack woken last, until it is within 1.1 m (`ARRIVED`). A planned spot is then held. Without one it taunts loose enemies, moves among the ranged enemies if any are far away, and otherwise plants where it is.

**AI damage dealers and healer.**

- Melee stand behind the target, or on the side of their planned spot (`_melee_pos`).
- Ranged and the healer hold their planned spot while it serves (`_spot_serves`: within 28 m and in sight of who they are there for, not in front of a cleave). Otherwise they sample rings of spots round an anchor (`_ranged_pos`): in sight, out of frontals and ground zones, more than 14 m from any idle pack, and in the tank's room at least 1.5 m clear of its doorways (`Combat.same_room`).
- Out of combat they wait on a planned spot if it is more than 14 m from every idle enemy (`_waits_at`), and otherwise follow the tank. While the tank gathers, those with no spot follow it.

**Waking and chasing.**

- Any hero within 11 m and in sight wakes the whole pack. So does any damage, taunt or interrupt.
- Packs are not linked to each other. Woken enemies chase without limit; there is no leash. Pulling two packs to one spot therefore already works in the rules. Only the tank's planning is missing.

**The player** can take any of the four slots, tank included (`save.slot`, set on the setup screen in `ui/screens.gd`). The AI plays the rest. F9 lets the AI play the player's hero too.

**The save** (`rules/save_data.gd`, written as JSON by `scripts/save_store.gd`) has a version number (`v`, now 2) and holds `unlocked`, `bests` per hero, `party`, `slot`, `level`, `volume`, `muted`, `markers`, the bindings, and `routes`: for each level id, three slots of routes as plain data and which was used last. It holds nothing else per dungeon and no items.

**Screens.** `ui/route_map.gd` is the planner and `ui/map_view.gd` the map inside it, drawn from the `LevelDef` alone. The app shows it in state `"route"` (from the setup screen) or `"map"` (M during a run, paused, not in a fight). During a run it edits `combat.route` itself. The run marks the plan with two rings (`Run._spot_mark`, made at the start from the same stuff as the heroes' rings, so no new shader) and words drawn by `WorldOverlay._plan`. There is no overview camera.

**Left for later milestones.**

- The 14-minute limit is still the constant `Combat.TIME_LIMIT`; the big dungeon needs it per level.
- Lamps have no figure in the scene. The map draws them as diamonds.
- A room is one rectangle. The map draws rooms, doorways, walls and pillars as they are described, so a new shape of room needs nothing more than its description.
- From the plan's routing section, not built because the Abbey cannot show them: walking round the wake range of packs that are not in the pull, the warning that a pull cannot be reached without waking another pack, and patrols with their paths on the map.
- The map's enemy "portraits" are lettered discs (`MapView.ENEMY_MARKS`); a new kind of enemy needs an entry there. What an enemy does is written out for the map in `Enemies.TRAITS`; a new enemy or ability needs a line there too, and a test fails without one.

## 5. Milestone 11, to begin with

Goal: the big dungeon. The plan's section 3 is the spec.

- **The owner approves first**: the name, a sketch of the layout, the new enemies, the four bosses, the default route and the count it asks for. Put these to them as a design round before building anything.
- Then: three wings, about 22 packs, four bosses, patrols, new enemies, the 25-minute timer, the three routing items left over from milestone 10, and the dungeon's default route.
- Everything new that can appear in a run goes in the warm-up.

## 6. Checks before every pause

Commands are in `game/README.md`. In short:

- Import the project headless and fix every error and warning it prints.
- Run the GUT tests with `--fixed-fps 60`.
- Run the balance runner (`game/tests/tools/sim.gd`) when rules or AI changed.
- Export for the web.
- For a look without the owner: `game/tests/tools/capture.gd` or `screens.gd` with `--write-movie` and an absolute path into the git-ignored `build/` folder.
- After pushing: watch the workflow run, then fetch the live site.

## 7. Things to bring to the owner, when their milestone comes

- Milestone 11: the dungeon's name, a layout sketch, the new enemies, the four bosses, the default route, and the count it asks for.
- Milestones 12 and 13: the list of named items and their effects, and the numbers listed in section 8 of the plan.
