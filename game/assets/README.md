# Art and sound

Everything here is a starter set: stand-ins from free packs and from a synthesiser, there to be replaced one file at a time. Figures and props are meant to give way to art made with the art guide's route (picture, Tripo, Blender, Mixamo, Godot). `voice/` is covered in [`../README.md`](../README.md).

## Credits

- Figures (`characters/`): KayKit Adventurers and KayKit Skeletons character packs by Kay Lousberg, [kaylousberg.com](https://www.kaylousberg.com). Licence CC0.
- Room pieces (`kit/`): KayKit Dungeon Remastered by Kay Lousberg. Licence CC0.

- Sound effects (`sound/`), all CC0, from OpenGameArt:
  - [RPG Sound Pack](https://opengameart.org/content/rpg-sound-pack) by artisticdude: `swing_*`, `guard_2`.
  - [80 CC0 RPG SFX](https://opengameart.org/content/80-cc0-rpg-sfx) by rubberduck: `fire_*`, `spell_*`, `strike_1`, `strike_2`, `guard_1`, `death_*`, `stones_*`.
  - [100 CC0 SFX](https://opengameart.org/content/100-cc0-sfx) by rubberduck: `blow_*`, `boom_*`.
  - [50 RPG sound effects](https://opengameart.org/content/50-rpg-sound-effects) and [51 UI sound effects](https://opengameart.org/content/51-ui-sound-effects-buttons-switches-and-clicks) by Kenney: `strike_3`, `ui_click`.
- Every other sound, and all the music (`music/`), is made by `tools/audio/make_audio.py`, to the recipe the first, TypeScript version of the game used.

CC0 asks for nothing; the credit is a courtesy. The figures are recoloured, re-geared and cut down to six clips by `tools/art/make_figures.py`.

## Figures: `characters/`

One `.glb` per hero and enemy. Which file belongs to whom is the table in `scripts/figures.gd`:

| Who | File | Stand-in |
|---|---|---|
| The Gatewarden (`warden`) | `warden.glb` | Knight, sword and shield |
| The Lamplighter (`mender`) | `lamplighter.glb` | Mage in teal, staff |
| The Kelpwife (`bloomweaver`) | `kelpwife.glb` | Hooded rogue in green, staff |
| The Wrecker (`duelist`) | `wrecker.glb` | Barbarian in plum, two axes |
| The Harpooner (`ranger`) | `harpooner.glb` | Rogue in oilskin yellow, crossbow |
| The Chandler (`pyromancer`) | `chandler.glb` | Mage in umber, wand and book |
| Drowned Porter (`brute`) | `porter.glb` | Skeleton warrior, axe |
| Penitent (`berserker`) | `penitent.glb` | Bare skeleton, two blades |
| Brine Cantor (`hexer`) | `cantor.glb` | Skeleton mage in violet, staff |
| Tide Almoner (`shaman`) | `almoner.glb` | Skeleton mage in green |
| Net-Brother (`archer`) | `net_brother.glb` | Hooded skeleton in blue, crossbow |
| The Prior (`overseer`) | `prior.glb` | Skeleton warrior in gold, blade and shield |
| Brineling (`hatchling`) | `brineling.glb` | Small bare skeleton |
| Brother Krogg | `krogg.glb` | Giant skeleton warrior, two axes |
| Sister Velisse | `velisse.glb` | Giant hooded skeleton in pale teal |
| Abbot Sulmar | `sulmar.glb` | Giant skeleton mage in dark gold, staff |

### To replace one

Save your `.glb` over the file of the same name and let Godot import it. Nothing else changes. A figure must be:

- facing +Z, standing on the floor at the centre, and sized in metres (the art guide's scripts do all three);
- carrying clips named `idle`, `run`, `attack`, `cast`, `hit` and `fall`. Any that are missing are skipped. `idle` and `run` should loop (the `-loop` ending in Blender); `cast` is looped by the game whatever the file says.

A figure that borrows another's clips as an animation library called `shared` works too: the game looks for `run`, then `shared/run`. A hero or enemy with no file is drawn as the old grey capsule.

Each `.glb` has a `_colour.png` beside it, which Godot writes when it imports the file. Commit both, with their `.import` files.

## Room pieces: `kit/`

`scripts/level_builder.gd` lays each rectangle of floor and wall in a level's description with these pieces, stretched a little so they fit exactly:

| Piece | Used for |
|---|---|
| `floor_tile_large` | floors, and the tops of thick walls |
| `wall` | walls 1.5 m and taller |
| `barrier` | lower walls: the kerb along the front |
| `pillar` | pillars |
| `box_large` | small square blocks: the sandbox's crate |
| `torch_mounted`, `banner_*` | hung along back walls, for show |

All of them are painted from one image, `dungeon_texture.png`. To swap a piece, save a `.glb` of the same name with one mesh in it that uses the same image; to change the whole look, replace the image. Without the folder the level is drawn as grey boxes on a metre grid (also the `dressed` switch on the `Level` node).

## Sound effects: `sound/`

A sound is a file named after what happens. Where there are several takes (`swing_1`, `swing_2`, `swing_3`) one is picked at random. The table at the top of `scripts/sound.gd` lists every sound, how many takes it has and how loud it is played; the table under it says which hero ability makes which sound.

| Sound | When |
|---|---|
| `swing`, `shot`, `fire`, `spell` | a hero's attack, by kind (yours louder than the party's) |
| `guard`, `surge` | a defensive ability; a great cooldown |
| `heal` | a heal of yours lands; bigger heals ring higher |
| `dispel`, `interrupt`, `revive` | as named |
| `strike` | your hit lands on an enemy in reach |
| `blow` | a hero takes a heavy hit; quietly, any hit on you |
| `death`, `fallen` | an enemy dies (deeper for big ones); a hero falls |
| `chant` | a drowned monk casting something you can stop, pitched by who sings |
| `toll` | a boss's warning |
| `boom`, `stones` | a marked area lands; a pillar comes down |
| `clear`, `lamp`, `wipe` | a room cleared; a boss down and its lamp lit; the party driven back |
| `ui_click` | any button on a screen |

### To replace one

Save a `.wav` or `.ogg` over the file of the same name (if you change the ending, delete the old file). To add a take, add the file and raise `takes` in `scripts/sound.gd`.

## Music: `music/`

One loop plays at a time and fades into the next: `calm_N` while wandering, `fight_N` in a fight and `boss_N` for a boss, where N is the part of the abbey (0 the Sea Gate, 1 the Infirmary, 2 the Nave). The menus play `calm_0` quietly. `tide_bell` is struck every 3.2 seconds in the last two minutes of the clock. The music drops while anyone is speaking.

To replace a loop, save a `.wav` or `.ogg` of the same name; the game loops it whatever its length. `scripts/music.gd` has the loudness and the fade time.

## To build the starter set again

The packs are not in the repo. Clone them once (about 70 MB together):

```sh
mkdir -p ~/fourfold-art/kits && cd ~/fourfold-art/kits
git clone --depth 1 https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 kaykit-adventurers
git clone --depth 1 https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0 kaykit-skeletons
git clone --depth 1 https://github.com/KayKit-Game-Assets/KayKit-Dungeon-Remastered-1.0 kaykit-dungeon
```

Then, from the repo root (Blender 5.2):

```sh
blender -b -P tools/art/make_figures.py -- ~/fourfold-art/kits game/assets/characters
blender -b -P tools/art/make_kit.py -- ~/fourfold-art/kits game/assets/kit
godot --headless --path game --import
```

Who wears what, in which colours and at what height, is the `CAST` table at the top of `make_figures.py`; add a name after the folders to build only that figure.

For the sounds, download and unzip each pack named under Credits into a folder of its own in `~/fourfold-art/kits/audio/` (`artisticdude-rpg`, `oga-80-rpg-sfx`, `oga-100-sfx`, `kenney-rpg`, `kenney-ui`), then:

```sh
python3 tools/audio/make_audio.py            # everything; about ten seconds
python3 tools/audio/make_audio.py heal calm_1  # or only the sounds named
godot --headless --path game --import
```

It needs only Python 3. Which recording becomes which sound is the `PICKS` table at the top of the script; the made sounds and the music are functions further down. Without the packs it makes only what it synthesises.
