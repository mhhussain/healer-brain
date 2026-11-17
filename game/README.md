# Fourfold in Godot

The game: an isometric dungeon runner, published at https://mhhussain.github.io/healer-brain/. Its rules are in [`DESIGN.md`](../DESIGN.md). It began as a rebuild of a TypeScript game; the brief for that is [`docs/godot-rebuild-handoff.md`](../docs/godot-rebuild-handoff.md). What is planned next (rare gear, coin and a shop) is in [`docs/routing-and-gear-plan.md`](../docs/routing-and-gear-plan.md).

Godot **4.7.2**, GDScript, Compatibility renderer. CI uses the same version (`.github/workflows/deploy.yml`).

## Layout

- `rules/`: the rules of the game as plain GDScript classes with no scene in them: heroes, enemies and levels as data (a level is rooms joined by doorways, with its packs and patrols, its gates, its sanctuary lamps, the count it asks for and its time limit), `Combat` for abilities, auras, threat, count and who is in a fight, `Route` for a plan of pulls and its text code, `Paths` for finding a way round packs that are not to be woken, `HeroAI` for what the AI party decides and how it follows a route, `Story` for what the party says and when, `Items` for gear and what a chest holds, `Teams` for who wears it, and `SaveData` and `Bindings` for what is kept between runs. They are tested on their own.
- `scripts/`: the nodes. `App` is the game as a whole: it moves between the screens and the run and owns the save. `Run` builds the level, owns the rules, tells them where each `Unit` stands, ticks them 60 times a second and shows what happens. `LevelBuilder` makes the floor, walls, collision and navigation mesh from a level's description, and dresses them with the room pieces. `Unit` shows a hero or enemy as its figure and picks its clip (idle, run, attack, cast, hit, fall) from what the rules report; `Figures` says which file is whose. `Sound` turns what the rules report into sound effects, and `Music` fades between loops as the run moves between wandering, fights and bosses. `Walker` walks enemies and AI heroes to where the rules want them, along the navigation mesh.
- `ui/`: the interface. `Hud` and its frames and buttons during a run, `WorldOverlay` for what is drawn over the figures, `Screens` for the title, the start screen, the settings, pause and summary, `GearScreens` for the inventory, the team editor and the chest, `RouteMap` for the route planner and `MapView` for the map it is built round, `KeysEditor`, and `Kit` for the colours and theme they share.
- `assets/`: the voice recordings, and the starter art and sound: one 3D figure per hero and enemy, the room pieces the level is laid with, the sound effects and the music. [`assets/README.md`](assets/README.md) says where they came from and how to replace each with your own.
- `scenes/`: `app.tscn` (where the game starts), `run.tscn` (one run) and `unit.tscn` (every hero and enemy).
- `tests/`: GUT tests, and `tests/tools/` for things that are not tests:
  - `sim.gd`: all-AI runs for balance (see below).
  - `capture.gd`: lets the AI play for `--write-movie`, to get frames to look at.
  - `hitches.gd`: lets the AI play in a window and prints frames that took too long.
  - `screens.gd`: walks the app through its screens, the route planner among them, for `--write-movie`. With `gear` as a third word it walks the screens for gear instead.
  - `lineup.gd`: stands the whole cast in two rows playing one clip, for `--write-movie`.
  - `voice_manifest.gd`: writes the list of voice lines from the story.
  - `full_save.gd`: writes the save with everything in it (see "A save with everything in it").
  - `level_check.gd`: looks over a level's packs (can each be stood at, seen and pulled, how near its neighbours are) and says which packs the safe way could leave standing.

## Play

Open `game/project.godot` in Godot and press F5. Or from the repo root:

```sh
godot --path game
```

There are two dungeons, each run by you and three AI party members against a count and a clock. The Drowned Abbey is nine rooms in a row with three bosses and 14 minutes. Tollhaven is a market with three wings, four bosses, patrols, a gate and more packs than its count asks for, in 25 minutes. The game opens on the title, then the start screen, with three choices side by side: the dungeon and its level; the team (the crew, your hero and what each of them wears); and the route (which packs the tank pulls together, in what order, and where everyone stands). Each has an editor behind it, and a run can always be started with what is there. M opens the map during a run, between fights. Timing a level unlocks the next in that dungeon, and a fast clear two or three; each dungeon keeps its own levels. A finished run ends in a chest of gear: weapons, armour and trinkets, which the default team wears without being told to. Z, X and C are the gear keys; so far only a trinket that is pressed uses one (C). Starting a run shows a card with a bar while the run is read and built; the engine's one-off work of first drawing each kind of thing is done behind that card, not in the first fight.

Your crew, dungeon, levels, unlocks, records, gear, teams, key bindings and routes are kept in `user://fourfold-save.json` (in a browser, in the browser's own storage). Only the app reads or writes it; tests and the tools below use files of their own or none. The settings can keep a copy as `fourfold-save.txt` (downloaded in a browser, in the Documents folder otherwise) and load one back.

### A save with everything in it

[`saves/fourfold-everything.txt`](../saves/fourfold-everything.txt) is a save for testing: both dungeons open to level 20, weapons and armour for four at the ceilings of levels 5, 10 and 20, one of every trinket, and six teams already dressed (nothing worn, gear for each of those levels, and one for each dungeon's trinkets with a pressed one on the hero you play). The default team wears the best of it, so choose another team to feel a level as it was meant.

- In a browser: Settings and keys, "Load from a file", and choose it.
- Outside one (F5 in the editor), the game reads `fourfold-save.txt` in your Documents folder: `cp saves/fourfold-everything.txt ~/Documents/fourfold-save.txt`, then "Load from a file".
- Loading replaces everything, key bindings included. "Save to a file" first if you want your own back.

What goes in it is `tests/full_save.gd`. When something new can be earned (a dungeon, a kind of item, a rarity), add it there and write the file again; a test fails while the file is out of date.

```sh
godot --headless --path game -s tests/tools/full_save.gd
```

Three keys are for looking under the bonnet during a run:

- F3 shows speed, zoom and frames a second.
- F8 swaps the dungeon for the sandbox hall: two packs in two rooms, starting over when cleared.
- F9 lets the AI play your hero too, to watch. Such a run is not recorded.

## Voice

Every line the game says is in `rules/story.gd`, with an id that is also the name of its recording: `assets/voice/<id>.wav`. The recordings are made by Kokoro, a text-to-speech model, through a hosted Kokoro service. To change a line or a voice:

```sh
# 1. after editing rules/story.gd, write the list of lines again
godot --headless --path game -s tests/tools/voice_manifest.gd
# 2. make the recordings that are new or changed (from the repo root)
python3 tools/voice/make_voice.py
```

The script needs only Python 3.9, and the service's address and key as `KOKORO_API_URL` and `KOKORO_API_KEY`, in the environment or in `threads.env` at the top of the repo (which git ignores). Who gets which voice is the `CAST` table at the top of the script. The tests fail if a line has no recording or its recording was made from different words.

To use recordings from somewhere else, such as ElevenLabs, put files with the same names in `assets/voice/`.

## Balance runs

The AI plays all four heroes through the real scene, for every healer and pair of damage dealers:

```sh
godot --headless --fixed-fps 60 --path game -s tests/tools/sim.gd -- 1,3,5 2
```

That is levels 1, 3 and 5 of the Abbey with two seeds each; add `-v` for when each pack fell, and `tollhaven` or `sandbox` as a third word for another place. `party=0` to `party=5` runs one of the six parties instead of all of them. `gear=17` gives all four a plain weapon and armour of that item level, and `trinkets=great_key,-,lens,pitch_pot` a trinket each by kind, in party order. The same code, level, party and seed always give the same line, so a change that should alter nothing can be proved to by comparing lines.

To run a route instead of the safe way, add `route=` and a code copied from the map, or write one on the spot with `pulls=`: packs by number (the Abbey's are 0 to 8, bosses 2, 5 and 8; Tollhaven's are 0 to 25 in the order of its safe way, bosses 8, 16, 20 and 25; `tests/tools/level_check.gd` lists them), `+` between packs of one pull and `,` between pulls. Packs left out follow one at a time.

```sh
godot --headless --fixed-fps 60 --path game -s tests/tools/sim.gd -- 1,5 1 abbey pulls=0+1,2,3+4,5,6+7,8
```
 Each line gives the time, deaths, and per hero damage a second, healing a second, interrupts and deaths. A run of the Abbey takes about 20 seconds, and one of Tollhaven a minute or two.

## Test

```sh
godot --headless --path game --import      # once, and after adding files
godot --headless --fixed-fps 60 --path game -s addons/gut/gut_cmdln.gd -gexit
```

`--fixed-fps 60` matters: some tests let the AI play out whole fights, and with it they run as fast as the machine can instead of in real time.

Tests are in `game/tests/` and use [GUT](https://github.com/bitwes/Gut) 9.7.1, which is checked in under `addons/gut/`.

## Export for the web

Needs the web export templates for the same Godot version (`web_nothreads_*.zip`).

```sh
mkdir -p build/web
godot --headless --path game --export-release Web "$PWD/build/web/index.html"
```

To try it in a browser, serve the folder and open http://localhost:8060 (add `?debug` to publish the hero's state as `window.fourfold` for browser tests):

```sh
python3 -m http.server 8060 -d build/web
```

`build/` is not committed. Every push to `main` runs the tests, makes this same export and publishes it to GitHub Pages; a pull request does the same without publishing, and attaches the export to the run as a download.
