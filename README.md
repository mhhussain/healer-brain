# Fourfold

A solo dungeon runner in the style of timed MMO dungeons, played in the browser. You play one hero (tank, healer or damage dealer) and AI plays the other three, through one of two dungeons against the clock: the Drowned Abbey, nine rooms and three bosses in 14 minutes, or Tollhaven, a town of three wings and four bosses in 25, by a route you plan on a map.

- **Play:** https://mhhussain.github.io/healer-brain/
- **Design:** [DESIGN.md](DESIGN.md)
- **The game itself:** [`game/`](game/README.md), a Godot 4 project. Its README covers the layout, how to play, test and export it, and how the voice, art and sound are made.
- **A save with everything unlocked, for testing:** [`saves/fourfold-everything.txt`](saves/fourfold-everything.txt). Load it from the game's settings; [`game/README.md`](game/README.md) says what is in it.
- **Art and sound:** [`game/assets/README.md`](game/assets/README.md) lists every stand-in and how to replace it.
- **What is next:** rare gear with abilities of its own, coin and a shop. Route planning, the larger dungeon, and gear up to rare with the teams that wear it are built. [`docs/routing-and-gear-plan.md`](docs/routing-and-gear-plan.md) is what was agreed; [`docs/routing-and-gear-handoff.md`](docs/routing-and-gear-handoff.md) is the brief for building it.

## Develop

Install Godot 4.7.2 (`brew install --cask godot`), then from the repo root:

```sh
godot --path game                             # play
godot --headless --path game --import         # once, and after adding files
godot --headless --fixed-fps 60 --path game -s addons/gut/gut_cmdln.gd -gexit   # tests
godot --headless --fixed-fps 60 --path game -s tests/tools/sim.gd -- 1,5,8 2    # all-AI balance runs: levels, seeds
```

## Publish

Pushing to `main` runs the tests, exports the game for the web and publishes it to GitHub Pages (`.github/workflows/deploy.yml`). A pull request runs the same tests and export without publishing; the export is attached to the run as a download.

## The first version

Fourfold was first built in TypeScript as a side-on belt-scroller. That game is kept at the tag [`typescript-game`](https://github.com/mhhussain/healer-brain/tree/typescript-game); `docs/godot-rebuild-handoff.md` is the brief the rebuild started from.
