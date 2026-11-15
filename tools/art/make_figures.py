# make_figures.py: build the starter cast from the free KayKit character packs (CC0).
#
#   blender -b -P tools/art/make_figures.py -- KITS_FOLDER OUT_FOLDER [name ...]
#
# KITS_FOLDER holds the two packs as cloned from GitHub (see game/assets/README.md):
#   kaykit-adventurers/   KayKit-Character-Pack-Adventures-1.0
#   kaykit-skeletons/     KayKit-Character-Pack-Skeletons-1.0
# It writes OUT_FOLDER/NAME.glb for every figure in CAST (or only the ones named), each in the
# form the game expects of any figure: facing +Z, standing on the floor, the right height in
# metres, with six clips named idle, run, attack, cast, hit and fall.
#
# These are stand-ins. A figure made by the art guide's route replaces one by taking its file name.
import colorsys
import os
import sys
import tempfile

import bpy
import numpy as np
from math import radians

from mathutils import Matrix

ADV = "kaykit-adventurers/addons/kaykit_character_pack_adventures"
SKE = "kaykit-skeletons/addons/kaykit_character_pack_skeletons"

# The colour image is shrunk to this many pixels a side: it is only flat swatches of colour.
TEX = 256

# How a held thing sits on the hand bone, read off the gear the packs ship already attached.
RIGHT = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0.033), (0, 1, 0, 0), (0, 0, 0, 1)))
LEFT = Matrix(((1, 0, 0, 0), (0, 0, 1, 0.017), (0, -1, 0, 0), (0, 0, 0, 1)))
SHIELD = Matrix(((1, 0, 0, 0), (0, 0, 1, 0.017), (0, -1, 0, 0.156), (0, 0, 0, 1)))
# The packs hold a staff level, like a lance. Upright, it reads better from above.
STAFF = Matrix.Rotation(radians(90), 4, "Z") @ RIGHT

# Hues, in degrees, that the recolouring rules below pick out of the packs' swatches.
RED = (325, 8)
PURPLE = (232, 275)
GREEN = (95, 172)
BLUE = (195, 232)


def swap(band, to, sat=1.0, val=1.0, min_sat=0.3):
    """A rule: every swatch whose hue is in `band` takes the hue `to`."""
    return {"band": band, "to": to, "sat": sat, "val": val, "min_sat": min_sat}


# The drowned: bone and cloth go sea-green, and the eyes burn teal instead of yellow.
DROWNED = {"wash": (0.74, 0.97, 0.9), "eyes": 172}

CAST = {
    # ---- the party: body height 1.6 m
    "warden": dict(base=ADV + "/Characters/gltf/Knight.glb", height=1.6,
        keep=["1H_Sword", "Badge_Shield", "Knight_Helmet", "Knight_Cape"],
        attack="1H_Melee_Attack_Chop", rules=[swap(RED, 212, 0.75)]),
    "lamplighter": dict(base=ADV + "/Characters/gltf/Mage.glb", height=1.6,
        keep=["Mage_Hat", "Mage_Cape"], add=[(ADV + "/Assets/gltf/staff.gltf", "handslot.r", STAFF)],
        attack="Spellcast_Shoot", rules=[swap(PURPLE, 176, 0.9, 1.25), swap(RED, 42, 0.8, 1.2)]),
    "kelpwife": dict(base=ADV + "/Characters/gltf/Rogue_Hooded.glb", height=1.6,
        keep=["Rogue_Cape"], add=[(ADV + "/Assets/gltf/staff.gltf", "handslot.r", STAFF)],
        attack="Spellcast_Shoot", rules=[swap(GREEN, 112, 0.9, 0.95)]),
    "wrecker": dict(base=ADV + "/Characters/gltf/Barbarian.glb", height=1.6,
        keep=["1H_Axe", "1H_Axe_Offhand", "Barbarian_Hat", "Barbarian_Cape"],
        attack="Dualwield_Melee_Attack_Chop", rules=[swap(BLUE, 305, 1.1, 0.9, 0.15)]),
    "harpooner": dict(base=ADV + "/Characters/gltf/Rogue.glb", height=1.6,
        keep=["2H_Crossbow", "Rogue_Cape"],
        attack="2H_Ranged_Shoot", rules=[swap(GREEN, 47, 1.25, 1.25)]),
    "chandler": dict(base=ADV + "/Characters/gltf/Mage.glb", height=1.6,
        keep=["1H_Wand", "Spellbook_open", "Mage_Hat", "Mage_Cape"],
        attack="Spellcast_Shoot", rules=[swap(PURPLE, 18, 1.2, 1.3), swap(RED, 48, 1.0, 1.2)]),

    # ---- the drowned: heights follow the game's sizes (0.9 m plus 1.8 times the radius)
    "porter": dict(base=SKE + "/Characters/gltf/Skeleton_Warrior.glb", height=2.15,
        keep=["Skeleton_Warrior_Helmet"], add=[(SKE + "/Assets/gltf/Skeleton_Axe.gltf", "handslot.r", RIGHT)],
        attack="1H_Melee_Attack_Chop", drowned=True, rules=[swap(RED, 24, 0.9, 0.9)]),
    "penitent": dict(base=SKE + "/Characters/gltf/Skeleton_Minion.glb", height=2.15,
        add=[(SKE + "/Assets/gltf/Skeleton_Blade.gltf", "handslot.r", RIGHT),
             (SKE + "/Assets/gltf/Skeleton_Blade.gltf", "handslot.l", LEFT)],
        attack="Dualwield_Melee_Attack_Slice", drowned=True, rules=[]),
    "cantor": dict(base=SKE + "/Characters/gltf/Skeleton_Mage.glb", height=2.0,
        keep=["Skeleton_Mage_Hat"], add=[(SKE + "/Assets/gltf/Skeleton_Staff.gltf", "handslot.r", STAFF)],
        attack="Spellcast_Shoot", drowned=True, rules=[swap(RED, 278, 0.9, 1.1)]),
    "almoner": dict(base=SKE + "/Characters/gltf/Skeleton_Mage.glb", height=2.0,
        keep=["Skeleton_Mage_Hat"],
        attack="Spellcast_Raise", drowned=True, rules=[swap(RED, 128, 0.85, 1.15)]),
    "net_brother": dict(base=SKE + "/Characters/gltf/Skeleton_Rogue.glb", height=2.0,
        keep=["Skeleton_Rogue_Hood", "Skeleton_Rogue_Cape"],
        add=[(SKE + "/Assets/gltf/Skeleton_Crossbow.gltf", "handslot.r", RIGHT)],
        attack="1H_Ranged_Shoot", drowned=True, rules=[swap(RED, 222, 0.8, 1.1)]),
    "prior": dict(base=SKE + "/Characters/gltf/Skeleton_Warrior.glb", height=2.6,
        keep=["Skeleton_Warrior_Helmet"],
        add=[(SKE + "/Assets/gltf/Skeleton_Blade.gltf", "handslot.r", RIGHT),
             (SKE + "/Assets/gltf/Skeleton_Shield_Large_A.gltf", "handslot.l", SHIELD)],
        attack="1H_Melee_Attack_Slice_Diagonal", drowned=True, rules=[swap(RED, 46, 1.1, 1.35)]),
    "brineling": dict(base=SKE + "/Characters/gltf/Skeleton_Minion.glb", height=1.35,
        attack="Unarmed_Melee_Attack_Punch_A", drowned=True, rules=[]),
    "krogg": dict(base=SKE + "/Characters/gltf/Skeleton_Warrior.glb", height=3.6,
        keep=["Skeleton_Warrior_Helmet"],
        add=[(SKE + "/Assets/gltf/Skeleton_Axe.gltf", "handslot.r", RIGHT),
             (SKE + "/Assets/gltf/Skeleton_Axe.gltf", "handslot.l", LEFT)],
        attack="Dualwield_Melee_Attack_Chop", drowned=True, rules=[swap(RED, 205, 0.6, 0.7)]),
    "velisse": dict(base=SKE + "/Characters/gltf/Skeleton_Rogue.glb", height=3.4,
        keep=["Skeleton_Rogue_Hood", "Skeleton_Rogue_Cape"],
        attack="Spellcast_Shoot", drowned=True, rules=[swap(RED, 165, 0.35, 1.9)]),
    "sulmar": dict(base=SKE + "/Characters/gltf/Skeleton_Mage.glb", height=3.6,
        keep=["Skeleton_Mage_Hat"], add=[(SKE + "/Assets/gltf/Skeleton_Staff.gltf", "handslot.r", STAFF)],
        attack="Spellcast_Long", drowned=True, rules=[swap(RED, 44, 1.0, 0.75)]),
}

# The game's clip names, and which of the packs' clips each one is. "-loop" tells Godot to repeat it.
CLIPS = {"idle-loop": "Idle", "run-loop": "Running_A", "cast-loop": "Spellcasting", "hit": "Hit_A", "fall": "Death_A"}


def in_band(hue, band):
    lo, hi = band
    return (hue >= lo) & (hue <= hi) if lo <= hi else (hue >= lo) | (hue <= hi)


def recolour(image, spec):
    """Shrinks the colour image and repaints its swatches by the figure's rules."""
    w, h = image.size
    if max(w, h) > TEX:
        image.scale(TEX, TEX)
        w, h = image.size
    px = np.array(image.pixels[:], dtype=np.float32).reshape(-1, 4)
    hsv = np.array([colorsys.rgb_to_hsv(*p[:3]) for p in px], dtype=np.float32)
    hue = hsv[:, 0] * 360.0
    out = hsv.copy()
    touched = np.zeros(len(px), dtype=bool)
    if spec.get("drowned"):
        eyes = in_band(hue, (14, 64)) & (hsv[:, 1] > 0.8) & (hsv[:, 2] > 0.6)
        out[eyes, 0] = DROWNED["eyes"] / 360.0
        touched |= eyes
    for rule in spec.get("rules", []):
        hit = in_band(hue, rule["band"]) & (hsv[:, 1] >= rule["min_sat"]) & ~touched
        out[hit, 0] = rule["to"] / 360.0
        out[hit, 1] = np.clip(hsv[hit, 1] * rule["sat"], 0, 1)
        out[hit, 2] = np.clip(hsv[hit, 2] * rule["val"], 0, 1)
        touched |= hit
    rgb = np.array([colorsys.hsv_to_rgb(*p) for p in out], dtype=np.float32)
    if spec.get("drowned"):
        wash = np.array(DROWNED["wash"], dtype=np.float32)
        rgb[~touched] *= wash
    px[:, :3] = rgb
    image.pixels.foreach_set(px.ravel())
    # save and load again, so the export carries the small repainted file and not the original
    png = os.path.join(tempfile.mkdtemp(), "colour.png")
    image.filepath_raw = png
    image.file_format = "PNG"
    image.save()
    return bpy.data.images.load(png)


def image_of(material):
    return next(n for n in material.node_tree.nodes if n.type == "TEX_IMAGE").image


def build(name, spec, kits, out_folder):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(kits, spec["base"]))
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")

    # 1. Keep the body and the chosen gear; the packs ship every weapon attached at once.
    keep = set(spec.get("keep", []))
    body = []
    for o in list(bpy.data.objects):
        if o.type != "MESH":
            continue
        if o.parent != rig or (o.parent_bone and o.name not in keep):
            bpy.data.objects.remove(o)
        elif not o.parent_bone:
            body.append(o)
    material = body[0].data.materials[0]

    # 2. Hold the clips still in the rest pose while things are measured and attached.
    tracks = rig.animation_data.nla_tracks
    rig.animation_data.action = None
    for t in tracks:
        t.mute = True
    for b in rig.pose.bones:
        b.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()

    # 3. Put extra gear in the hands.
    for path, bone, grip in spec.get("add", []):
        had = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(kits, path))
        for o in [o for o in bpy.data.objects if o not in had]:
            if o.type != "MESH":
                bpy.data.objects.remove(o)
                continue
            if image_of(o.data.materials[0]).name.split(".")[0] == image_of(material).name.split(".")[0]:
                o.data.materials.clear()
                o.data.materials.append(material)
            else:
                # gear from another figure's pack is painted from that figure's swatches
                borrowed = next(n for n in o.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE")
                borrowed.image = recolour(borrowed.image, {})
                borrowed.image.name = name + "_gear"
            o.parent = rig
            o.parent_type = "BONE"
            o.parent_bone = bone
            o.matrix_parent_inverse = Matrix.Identity(4)
            bpy.context.view_layer.update()
            o.matrix_world = rig.matrix_world @ rig.pose.bones[bone].matrix @ grip

    # 4. One repainted colour image for the whole figure.
    tex = next(n for n in material.node_tree.nodes if n.type == "TEX_IMAGE")
    tex.image = recolour(tex.image, spec)
    tex.image.name = name + "_colour"
    material.name = name

    # 5. Keep six clips under the game's names.
    wanted = dict(CLIPS)
    wanted["attack"] = spec["attack"]
    source = {theirs: ours for ours, theirs in wanted.items()}
    for t in list(tracks):
        action = t.strips[0].action if t.strips else None
        if action and action.name in source:
            t.name = source.pop(action.name)
            action.name = t.name
        else:
            tracks.remove(t)
    if source:
        sys.exit("%s: the pack has no clip named %s" % (name, sorted(source)))
    used = {t.strips[0].action for t in tracks}
    for a in list(bpy.data.actions):
        if a not in used:
            bpy.data.actions.remove(a)

    # 6. Make the whole figure one mesh on the skeleton: the gear is bound to the bone that held
    # it. One mesh is one thing to draw, which matters with thirty figures in a browser.
    lo = min((o.matrix_world @ v.co).z for o in body for v in o.data.vertices)
    hi = max((o.matrix_world @ v.co).z for o in body for v in o.data.vertices)
    bpy.ops.object.select_all(action="DESELECT")
    for o in [o for o in bpy.data.objects if o.type == "MESH"]:
        if o.parent_bone:
            bone = o.parent_bone
            world = o.matrix_world.copy()
            o.parent = None
            o.data.transform(world)
            o.matrix_world = Matrix.Identity(4)
            o.vertex_groups.new(name=bone).add(range(len(o.data.vertices)), 1.0, "REPLACE")
            o.parent = rig
            o.modifiers.new("Armature", "ARMATURE").object = rig
        o.select_set(True)
    bpy.context.view_layer.objects.active = body[0]
    bpy.ops.object.join()
    body[0].name = body[0].data.name = name

    # 7. Size it by its body, so a tall hat does not make a short figure.
    rig.scale = (spec["height"] / (hi - lo),) * 3
    rig.location.z = -lo * rig.scale.z
    rig.name = "Figure"

    # 8. Write the file.
    os.makedirs(out_folder, exist_ok=True)
    glb = os.path.join(out_folder, name + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=glb,
        export_format="GLB",
        export_animation_mode="NLA_TRACKS",
        export_anim_slide_to_zero=True,
        export_optimize_animation_size=True,
    )
    tris = sum(len(p.vertices) - 2 for o in bpy.data.objects if o.type == "MESH" for p in o.data.polygons)
    print("FIGURE %-12s %.2f m, %5d triangles, %d clips, %4.0f KB" % (
        name, spec["height"], tris, len(tracks), os.path.getsize(glb) / 1024))


args = sys.argv[sys.argv.index("--") + 1:]
if len(args) < 2:
    sys.exit("usage: blender -b -P make_figures.py -- KITS_FOLDER OUT_FOLDER [name ...]")
for name in args[2:] or CAST:
    build(name, CAST[name], os.path.expanduser(args[0]), os.path.expanduser(args[1]))
