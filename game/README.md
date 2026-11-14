# Fourfold in Godot

The isometric rebuild. The plan is in [`docs/godot-rebuild-handoff.md`](../docs/godot-rebuild-handoff.md); the rules of the game are in [`DESIGN.md`](../DESIGN.md).

Godot **4.7.2**, GDScript, Compatibility renderer. CI uses the same version (`.github/workflows/godot.yml`).

## Layout

- `rules/`: the rules of the game as plain GDScript classes with no scene in them: heroes, enemies and levels as data, `Combat` for abilities, auras, threat and who is in a fight, and `HeroAI` for what the AI party decides. They are tested on their own.
- `scripts/`: the nodes. `Run` builds the level, owns the rules, tells them where each `Unit` stands, ticks them 60 times a second and shows what happens. `LevelBuilder` makes the floor, walls, collision and navigation mesh from a level's description. `Walker` walks enemies and AI heroes to where the rules want them, along the navigation mesh.
- `scenes/`: the main scene and the one unit scene that every hero and enemy is made from.
- `tests/`: GUT tests, and `tests/tools/` for things that are not tests:
  - `sim.gd`: all-AI runs for balance (see below).
  - `capture.gd`: lets the AI play for `--write-movie`, to get frames to look at.
  - `hitches.gd`: lets the AI play in a window and prints frames that took too long.

## Play

Open `game/project.godot` in Godot and press F5. Or from the repo root:

```sh
godot --path game
```

For now the main scene is a sandbox: you and three AI party members against two packs in a grey-box hall.

- F1 to F6 switch hero (Warden, Lamplighter, Kelpwife, Wrecker, Harpooner, Chandler). Your hero takes the place of its role in the party.
- `-` and `=` lower and raise the level.
- F9 lets the AI play your hero too, to watch.
- A few seconds after both packs are cleared, the hall starts over.

## Balance runs

The AI plays all four heroes through the real scene, for every healer and pair of damage dealers:

```sh
godot --headless --fixed-fps 60 --path game -s tests/tools/sim.gd -- 1,3,5 2
```

That is levels 1, 3 and 5 with two seeds each; add `-v` for when each pack fell. Each line gives the time, deaths, and per hero damage a second, healing a second, interrupts and deaths.

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
