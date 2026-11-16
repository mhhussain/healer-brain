# Handoff: building routing, the big dungeon and gear

Written on 15 November 2026 as the starting brief for a new session, and brought up to date as milestones 9 to 12 were built. **Milestone 12 (levels and basic gear) is built, to [`gear-proposal.md`](gear-proposal.md), which the owner approved as proposed. It waits for the owner to play it. Milestone 13 (rare gear and the shop) is next, and begins with a design round.**

Read these, in this order:

1. This file.
2. [`routing-and-gear-plan.md`](routing-and-gear-plan.md): what was agreed and the five milestones. It is the spec.
3. [`DESIGN.md`](../DESIGN.md): the rules of the game as built.
4. [`game/README.md`](../game/README.md): where the code lives and the commands to test, run and export.

## 1. Where things stand

- The game is the Godot 4.7.2 project in `game/` (GDScript, Compatibility renderer, single-threaded web export). It is published at https://mhhussain.github.io/healer-brain/.
- `main` is the only branch that matters. A push to `main` runs `.github/workflows/deploy.yml`: import, the GUT tests, web export, publish. If a test or the export fails, nothing is published.
- 291 tests pass with milestone 12 in.
- There are two dungeons, chosen on the setup screen. Each keeps its own levels and bests.
  - **The Drowned Abbey**: the landing and nine rooms in a row, 6 trash packs of 4 and 3 bosses, a count of 92 that asks for every pack, 14 minutes.
  - **Tollhaven**: eighteen rooms (a market, three wings of three rooms and a boss, two passages joining the wings, a gated pier to the last boss), 22 trash packs and 4 bosses, three patrols, a count of 300 of which 231 is asked for, 25 minutes. `DESIGN.md` section 7b has it all, with a map.
- All-AI run times on the safe way, which are the balance check:
  - The Abbey: about 7:25 to 8:05 at level 1, 10:15 to 11:00 at level 5, 12:00 to 13:00 at level 7. At level 7 a few runs in eighteen wipe once on the last boss and go over the time.
  - Tollhaven: 16:00 to 18:30 at level 1, 21:00 to 22:30 at level 4, and 27:00 to 28:45 at level 7, which is over its 25:00; nobody died in those. Leaving five corner packs out (`skip=3,5,6,11,15`) saves about 1:30 at level 1 and 3:00 at levels 4 and 7. `DESIGN.md` section 9 has the detail. The bosses, each alone: all fall up to level 7; Mother Hask starts beating the AI at level 8.
- The balance runner is exactly repeatable: the same code, level, party and seed give the same line. Use it to prove a change alters nothing: run the old commit from a `git worktree` (or a copy of the tree) in its own folder and compare lines. Milestones 9, 10 and 11 were all checked this way; milestone 11 left every line of the Abbey's eighteen runs as it was.
- Routes, the map planner and the AI that follows a route are in. So is gear up to rare: the chest, the inventory, teams, and ten trinkets. There are no epics, sets or legendaries, no coin and no shop.
- With nothing worn the game is exactly as it was: milestone 12 left every line of the Abbey's eighteen runs as it was. With plain gear at the ceiling one party timed the Abbey at level 10 in 11:37 (40:07 with 28 deaths without) and Tollhaven at level 7 in 22:44 (27:12 without), and could not finish the Abbey at level 15. `DESIGN.md` section 7c has the table. Garrow's Pitch Pot looks too strong at a high item level.

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

**The level description** (`rules/level_def.gd`; the Abbey, Tollhaven and a two-room sandbox are in `rules/levels.gd`, and `Levels.DUNGEONS` lists the dungeons a player may choose).

- `rooms` (`name`, `rect`, `zone`) and `doors` (`a`, `b`, `rect`, `pos`), added with `add_room` and `add_door`, which also lay their floor. A room is one rectangle. A doorway's floor belongs to neither room.
- `packs`: `name`, `boss`, `lamp` (the line shown when a boss falls), `enemies`, `room`, `center`, `pull_from`, `stand`, and for a patrol `path` (the spots it walks between). They are listed in the order the party takes them with no plan.
- `lamps` (`name`, `pos`, `pack`: the boss pack that lights it, or -1 for one that burns from the start), `count_needed` (0 asks for everything) and `time_limit`.
- `gates` (`door`, `packs`, `name`), added with `add_gate`, and `shut`: the doorways shut now. A run opens gates as it goes (`open_gate`), so one `LevelDef` belongs to one run: always make a fresh one with `Levels.by_name`.
- `id` (what saved routes know the level by) and `default_route` (pulls as lists of pack numbers; empty means every pack by itself).
- Questions it answers: `room_at`, `door_at`, `zone_at`, `same_room(of, p, clear)`, `doors_between(from, to)` (the fewest doorways between two spots, never through a shut gate), `reachable`, `locked(room)`, `walk_length(from, to)`, `pack_count(i)` and `count_goal()`.
- Tollhaven is written as three tables (`TOLL_ROOMS`, `TOLL_DOORS`, `TOLL_PACKS`), and its walls are made from them by `_enclose`: tall on the north and east of every room and doorway, 1.45 m on the south and west, which is the lowest that still blocks sight. `tests/tools/level_check.gd` prints what a designer wants to know about a level's packs.
- Navigation is baked from the geometry by `scripts/level_builder.gd`. A shut gate is a barrier body across its doorway; the floor under it is in the mesh, so opening it needs no new bake, and the rules never send anyone through a shut gate.

**Routes** (`rules/route.gd`).

- A `Route` is `name`, `level` (the level's id) and `pulls`; a pull is `{"packs": [int], "spots": {place in the party: Vector3}, "go": bool, "note": String}`. Packs are named by their place in the level's list. It has the editing steps the map uses (`toggle`, `add_pull`, `move_pull`, `merge_up`, `set_spot`, `prune`), `to_dict` and `from_dict` (which keeps only what makes sense for the level), and `to_code` and `from_code` (`FF1:` and base64 of the same data).
- `Route.default_for(def)` is the level's `default_route`, or every pack by itself in order. Per-pull orders can be added to a pull later: unknown keys are dropped on reading and missing ones take their defaults.

**Finding a way** (`rules/paths.gd`).

- `Paths` cuts a level's floor into 1.5 m squares (an `AStarGrid2D`). `avoid(list)` sets the packs to keep clear of; the ground each watches (15.7 m round its middle, where it could see) costs forty times any other, so a way crosses it only when there is no other. `way(from, to)` finds one, `wakes(path)` says whose ground it crosses, `threatened(from, to)` is the cheap test of whether the plain way would cross any, and `ahead(from, path)` is where a walker heads next.
- `Paths.check(def, route, from, done)` walks a route from its start and reports each pull that cannot be reached without waking another pack, or is behind a gate still shut. The map's warnings are this.
- `Combat.steer(hero, to)` is what the AI uses: the spot itself if nothing is in the way, else the next stop of a way round. The ground it keeps clear of is that of every pack that sleeps and is not in the pull being made or fought, and every patch that burns on. A spot that is on such ground is stopped short of. In the Abbey the plain way is never threatened, which is why its runs did not change.
- `Paths.check` also reports a pull that is reached cleanly but only by a long way round, with its length: that is what the AI will walk, and the map says so.

**The rules** (`rules/combat.gd`).

- `Combat.enter(def, route)` puts a run in a place: packs, enemies, lamps, count, time limit, and the plan (the level's own if none is given). `Run` and the test harness both use it. Heroes are added first so that they keep the first ids. `Run.route` is what the app hands a run; the run copies it.
- `Combat.next_pull()` is the one place that answers "what next": the first pull of the route with a pack still standing that is not behind a shut gate, as `{"index", "packs", "spots", "go"}`; once the plan runs out, the nearest pack (by `LevelDef.walk_length`), or the nearest boss once the count is met.
- `Combat.fight` is the pull being fought, set when a fight begins and emptied when it ends. `gathered()` says whether all its packs are awake.
- `can_attack()` goes by the pack woken last, and holds everyone while an AI tank gathers, for at most `GATHER_LIMIT` seconds.
- `count()`, `count_goal()` and `complete()`; `time_limit` and `timed()`.
- A wipe resets every engaged pack and puts the party round `last_lamp()`.
- Patrols: `_patrol` walks a sleeping pack's `at` along its `path` and moves its enemies' posts (`home`) with it. `pull_from` follows it.
- Gates: `_open_gates` runs when a boss falls, opens the level's gate, tells the way-finder and emits `{"k": "gate"}`.
- Zones (`rules/zone.gd`) are circles, cones or lanes, and may linger, follow a unit, turn, need the owner's sight, or be a place to shelter (`safe`). An aura with `hold` stops a unit moving or acting (`Combat.held`). `yank` drags a unit and emits `{"k": "yank"}` for the scene. `EnemyDef` has `front_guard`, `still` and `tint`; an ability may target `"farthest"`.

**The AI** (`rules/hero_ai.gd`).

- `_tank_travel` walks to the `pull_from` of the next pull's first pack, and wakes it when an enemy is within 27 m and in sight and `_party_ready` holds, or at once if the pull says go.
- `_tank_combat` first gathers the pull's sleeping packs, then goes to the planned tank spot, or the `stand` of the pack woken last. A planned spot is held. Without one it taunts loose enemies, moves among the ranged enemies if any are far away, and otherwise plants where it is; a spot that has caught fire is given up.
- Melee stand behind the target (`_melee_pos`). Ranged and the healer hold a planned spot while it serves (`_spot_serves`), else sample rings of spots (`_ranged_pos`): in sight, out of frontals and zones, not in front of a shield, more than 14 m from any idle pack, and in the tank's room.
- `think` puts first, in this order: hiding from a cast that must be hidden from, sheltering in a lit circle, getting out of a zone, carrying a zone away from the others. Everything else it wants to walk to goes through `Combat.steer`. A held hero does nothing. A telegraph is never walked into; a patch that burns on may be crossed but not stopped in. With no damage dealer free, the tank cuts a net itself.

**Enemies** (`rules/enemies.gd`). The Abbey's ten and Tollhaven's nine, with `TRAITS` (what each does, in words, for the map) and counts. A new enemy or ability needs a line in `TRAITS`, an entry in `MapView.ENEMY_MARKS` unless it is a boss, and a figure in `scripts/figures.gd`; tests fail without them.

**The player** can take any of the four slots, tank included. The AI plays the rest. F9 lets the AI play the player's hero too.

**Gear** (`rules/items.gd`, `rules/teams.gd`).

- An item is a `Dictionary` (`id`, `slot`, `ilvl`, `rarity`, `name`, `kind` for a trinket, `from`), so it goes into the save as it is. `Items` has what an item is worth (`bonus`, `describe`), the ceiling, the gear level, the chest (`chest`, `roll`, which take a `RandomNumberGenerator` so that tests can fix the dice), the table of the ten trinkets (`TRINKETS`: name, dungeon, whether pressed, cooldown, and the number at item level 1 with what each level adds and where it stops) and `levels_opened` for fast clears.
- A team is a `Dictionary` (`name`, `party`, `slot`, `gear`: for each hero the item ids of its three slots). `Teams` has the default team (`default_team`, `best_gear`: never kept, always worked out from `save.party`, `save.slot` and `save.items`), `in_use`, `worn` (ids turned into items), `equip`, `copy`, `remove`, `using` and `strip`.
- In a run: `Combat.wear(hero, gear)` sets `power` (damage and healing), `max_hp` and `trinket` on the `Combatant`. `damage` and `heal` multiply by `power`; `Combat.mended` is what a heal or shield comes to. `use_trinket`, `press_gear`, `gear_state`, `_trinket_tick`, `_lens` and `_knife` are the trinkets; a new one needs an entry in `Items.TRINKETS`, its effect in `Combat`, a line in `HeroAI._trinket` if it is pressed, and a row in `DESIGN.md` section 7c. `Aura` has `heals` beside `done`. A pressed trinket emits `{"k": "gear"}`.
- `Run.gear` is what the four wear, set by the app from the team before the run is made. `tests/tools/sim.gd` takes `gear=` and `trinkets=`.
- The gear keys are `SaveData.gear_keys` (Z, X, C), with `Bindings.set_gear_key` and `gear_for_key`; `ui/gear_button.gd` is the button beside the action bar.

**The save** (`rules/save_data.gd`, written as JSON by `scripts/save_store.gd`) has a version number (`v`, now 4) and holds `place` (the dungeon chosen), `progress` (for each dungeon: `unlocked`, `level`, `bests` per hero, `timed` and `records`), `party`, `slot`, `volume`, `muted`, `markers`, the bindings and gear keys, `routes` (for each level id, three slots of routes and which was used last), `items`, `next_item`, `teams` and `team` (0 is the default team). `unlocked`, `level` and `bests` on the object read and write the chosen dungeon's. A save from before version 3 is read as the Abbey's, and one from before 4 as one with no gear. `record` takes the time limit and the crew and returns how many levels were opened. `to_text` and `from_text` are the save as a file; `SaveStore.save_file`, `load_file` and `ask_for_file` (the browser's file picker) do the keeping.

**Screens.** `ui/screens.gd` has the start screen (three panels: dungeon and level, team, route), the settings, the pause menu and the summary. `ui/gear_screens.gd` has the inventory, the team editor and the chest. A screen that changes the save builds itself again in the same place (`GearScreens.swap`), so `App.screen` is whichever is up now. `ui/route_map.gd` is the planner and `ui/map_view.gd` the map inside it, drawn from the `LevelDef` alone, with patrols' rounds and shut gates. The app's states are `"title"`, `"opening"`, `"setup"`, `"route"`, `"team"`, `"gear"`, `"settings"`, `"loading"`, `"run"`, `"paused"`, `"map"`, `"summary"` and `"chest"`.

**Stand-ins.** Tollhaven's cast wear the Abbey's figures, washed with a colour (`EnemyDef.tint`); a net is the plain capsule. Its music is the Abbey's three sets of loops in turn. Its low walls are the kerb piece stretched. Lamps have no figure in either dungeon. All are for the art pass.

## 5. Milestone 13, to begin with

Goal: rare gear and the shop. The plan's section 5 is the spec; `DESIGN.md` section 7c is what is built so far.

- To build: epic items (a weapon or armour with an ability, pressed or automatic: this is what the weapon and armour keys, Z and X, are waiting for), sets (a bonus for one hero wearing all three), legendaries (one per party, counted as the highest item level owned plus 2, from the chest at about 2% with the chance creeping up), the unique flag, coin, selling, and the gamble.
- Rarity by dungeon level, as the plan has it: epics and sets from level 7, legendaries from 12.
- Throwing an item out becomes selling it; the chest's "Leave" becomes selling too.
- **Put to the owner first**, as a design round: the 6 epic abilities, the 3 sets and the 3 legendaries with their effects; and the numbers in the plan's section 8: what a run pays, what items sell for, what the gamble costs and its odds, and whether one legendary per party also limits how many can be owned.

## 6. Checks before every pause

Commands are in `game/README.md`. In short:

- Import the project headless and fix every error and warning it prints.
- Run the GUT tests with `--fixed-fps 60`.
- Run the balance runner (`game/tests/tools/sim.gd`) when rules or AI changed, for both dungeons, and compare the Abbey's lines with the last milestone's.
- Run `tests/tools/level_check.gd` when a level changed.
- Export for the web.
- For a look without the owner: `game/tests/tools/capture.gd` or `screens.gd` with `--write-movie` and an absolute path into the git-ignored `build/` folder.
- After pushing: watch the workflow run, then fetch the live site.

## 7. Things to bring to the owner, when their milestone comes

- Milestone 12, for them to judge in play (none was asked beforehand):
  - The default team's heroes and the one you play can be chosen, as before; only what it wears is fixed. The plan said the default team "cannot be edited".
  - Sound, the ground markers and the keys moved from the start screen to "Settings and keys".
  - Outside a browser the save's copy goes to the Documents folder, not beside the game.
  - What counts as a hit for the Lens and the Gutting Knife: anything an ability or attack lands, but not the ticks of a lasting effect.
  - When the AI uses each pressed trinket.
  - How fast gear climbs: about two item levels a run until the ceiling.
- Not checked: the browser's file picker for "Load from a file" and the download for "Save to a file" (they need a real browser), and shader stalls.
- Milestone 13: the list of named items and their effects, and the numbers listed in section 8 of the plan.
