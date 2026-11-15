# Art

Everything here is a starter set: stand-ins from free packs, there to be replaced one file at a time by art made with the art guide's route (picture, Tripo, Blender, Mixamo, Godot).

## Credits

- Figures (`characters/`): KayKit Adventurers and KayKit Skeletons character packs by Kay Lousberg, [kaylousberg.com](https://www.kaylousberg.com). Licence CC0.
- Room pieces (`kit/`): KayKit Dungeon Remastered by Kay Lousberg. Licence CC0.

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
