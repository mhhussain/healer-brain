# Fourfold in Godot

The isometric rebuild. The plan is in [`docs/godot-rebuild-handoff.md`](../docs/godot-rebuild-handoff.md); the rules of the game are in [`DESIGN.md`](../DESIGN.md).

Godot **4.7.2**, GDScript, Compatibility renderer. CI uses the same version (`.github/workflows/godot.yml`).

## Layout

- `rules/`: the rules of the game as plain GDScript classes with no scene in them: heroes, enemies and levels as data, `Combat` for abilities, auras, threat and who is in a fight, `HeroAI` for what the AI party decides, `Story` for what the party says and when, and `SaveData` and `Bindings` for what is kept between runs. They are tested on their own.
- `scripts/`: the nodes. `App` is the game as a whole: it moves between the screens and the run and owns the save. `Run` builds the level, owns the rules, tells them where each `Unit` stands, ticks them 60 times a second and shows what happens. `LevelBuilder` makes the floor, walls, collision and navigation mesh from a level's description. `Walker` walks enemies and AI heroes to where the rules want them, along the navigation mesh.
- `ui/`: the interface. `Hud` and its frames and buttons during a run, `WorldOverlay` for what is drawn over the figures, `Screens` for the title, setup, pause and summary, `KeysEditor`, and `Kit` for the colours and theme they share.
- `scenes/`: `app.tscn` (where the game starts), `run.tscn` (one run) and `unit.tscn` (every hero and enemy).
- `tests/`: GUT tests, and `tests/tools/` for things that are not tests:
  - `sim.gd`: all-AI runs for balance (see below).
  - `capture.gd`: lets the AI play for `--write-movie`, to get frames to look at.
  - `hitches.gd`: lets the AI play in a window and prints frames that took too long.
  - `screens.gd`: walks the app through its screens for `--write-movie`.
  - `voice_manifest.gd`: writes the list of voice lines from the story.

## Play

Open `game/project.godot` in Godot and press F5. Or from the repo root:

```sh
godot --path game
```

The game is the Drowned Abbey: you and three AI party members, nine rooms, three bosses and a 14-minute clock. It opens on the title, then the party setup, where you pick the crew, your hero, its keys and the level. Timing a level unlocks the next.

Your crew, level, unlocks, bests and key bindings are kept in `user://fourfold-save.json` (in a browser, in the browser's own storage). Only the app reads or writes it; tests and the tools below use files of their own or none.

Three keys are for looking under the bonnet during a run:

- F3 shows speed, zoom and frames a second.
- F8 swaps the Abbey for the sandbox hall: two packs in two rooms, starting over when cleared.
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

That is levels 1, 3 and 5 of the Abbey with two seeds each; add `-v` for when each pack fell, or `sandbox` as a third word for the sandbox hall. Each line gives the time, deaths, and per hero damage a second, healing a second, interrupts and deaths. A run of the Abbey takes about 20 seconds.

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

`build/` is not committed. CI uploads the same export as the `fourfold-web` artifact on every push to `godot-rebuild`.
