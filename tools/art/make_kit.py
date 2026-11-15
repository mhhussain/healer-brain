# make_kit.py: copy room pieces from the free KayKit dungeon kit (CC0) into the game.
#
#   blender -b -P tools/art/make_kit.py -- KITS_FOLDER OUT_FOLDER [piece ...]
#
# KITS_FOLDER holds kaykit-dungeon/ (KayKit-Dungeon-Remastered-1.0 as cloned from GitHub).
# It writes OUT_FOLDER/PIECE.glb for every piece in PIECES (or only the ones named), and the
# kit's one colour image as OUT_FOLDER/dungeon_texture.png.
#
# Every piece in the kit carries its own copy of the same colour image. The copies written here
# carry none: the game paints them all from the one image, which is far lighter in a browser.
import os
import shutil
import sys

import bpy

KIT = "kaykit-dungeon/addons/kaykit_dungeon_remastered/Assets"

# The pieces the level builder knows how to use (game/scripts/level_builder.gd).
PIECES = [
    "floor_tile_large", "wall", "barrier", "pillar", "box_large",
    "torch_mounted", "banner_patternA_blue", "banner_patternB_green", "banner_shield_white",
]

args = sys.argv[sys.argv.index("--") + 1:]
if len(args) < 2:
    sys.exit("usage: blender -b -P make_kit.py -- KITS_FOLDER OUT_FOLDER [piece ...]")
kit = os.path.join(os.path.expanduser(args[0]), KIT)
out = os.path.expanduser(args[1])
os.makedirs(out, exist_ok=True)
for name in args[2:] or PIECES:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(kit, "gltf", name + ".gltf.glb"))
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.name = o.data.name = name
    glb = os.path.join(out, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", export_image_format="NONE")
    tris = sum(len(p.vertices) - 2 for o in bpy.data.objects if o.type == "MESH" for p in o.data.polygons)
    print("PIECE %-24s %4d triangles, %3.0f KB" % (name, tris, os.path.getsize(glb) / 1024))
shutil.copyfile(os.path.join(kit, "texture", "dungeon_texture.png"), os.path.join(out, "dungeon_texture.png"))
