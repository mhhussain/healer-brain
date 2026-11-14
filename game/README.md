# Fourfold in Godot

The isometric rebuild. The plan is in [`docs/godot-rebuild-handoff.md`](../docs/godot-rebuild-handoff.md); the rules of the game are in [`DESIGN.md`](../DESIGN.md).

Godot **4.7.2**, GDScript, Compatibility renderer. CI uses the same version (`.github/workflows/godot.yml`).

## Layout

- `rules/`: the rules of the game as plain GDScript classes with no scene in them (heroes and enemies as data, `Combat` for cooldowns, damage, threat and who is in a fight). They are tested on their own.
- `scripts/`: the nodes. `Run` owns the rules, tells them where each `Unit` stands, ticks them 60 times a second and shows what happens.
- `scenes/`: the grey-box room, the hero and the enemy.
- `tests/`: GUT tests. `tests/tools/capture.gd` is not a test: it plays a short scripted fight for `--write-movie`, to get frames to look at.

## Play

Open `game/project.godot` in Godot and press F5. Or from the repo root:

```sh
godot --path game
```

For now the main scene is a sandbox: one hero against two packs in a grey-box hall.

- F1 to F6 switch hero (Warden, Lamplighter, Kelpwife, Wrecker, Harpooner, Chandler).
- `-` and `=` lower and raise the level.
- A cleared pack stands back up after a few seconds, and you take a tenth of the damage you should, since you are alone. Both are settings on the `Main` node.

## Test

```sh
godot --headless --path game --import      # once, and after adding files
godot --headless --path game -s addons/gut/gut_cmdln.gd -gexit
```

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
