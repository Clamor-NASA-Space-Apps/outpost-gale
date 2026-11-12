# A Veggie plant unit as flown on the ISS (NTRS 20160005059, Veggie fact sheet 2019): a 29.2 x 36.8 cm
# baseplate, a light cap 47 cm up with red and blue LEDs (the `grow` role: they read magenta), bellows at the
# back, six black Kevlar plant pillows with white wicks. In the pillows, what fits a 30-sol stay: two red
# romaine 'Outredgeous' (VEG-01), two radishes (27 days), a pillow of microgreens (7 to 18 days), and one
# romaine wilted from water stress (VEG-01 lost two plants that way). Plants from the Quaternius Nature Crops
# Pack (CC0): Lettuce_3 and Beet_3, recoloured and scaled to their pillow. Goes in HAB 1's galley (`slot_1`).
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/prop_veggie.py
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

CROPS = os.path.join(os.path.dirname(os.path.abspath(__file__)), *[".."] * 4, "assets-cache", "quaternius", "crops")
W, D, CAP, PLATE = 0.292, 0.368, 0.47, 0.03  # baseplate width (x) and depth (y), light cap height, plate thickness
CW, CD = W / 2, D / 3                           # one pillow's share of the plate
reset()


def crop(path, role_of, at_, width, drop=0.0):
    """A pack plant into the scene, each pack material swapped for a role, scaled to `width` across."""
    before = set(bpy.context.scene.objects)
    if path.endswith(".obj"):
        bpy.ops.wm.obj_import(filepath=path)
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    o = next(o for o in set(bpy.context.scene.objects) - before if o.type == "MESH")
    for extra in set(bpy.context.scene.objects) - before - {o}:
        bpy.data.objects.remove(extra)
    o.parent = None
    for i, m in enumerate(o.data.materials):
        o.data.materials[i] = mat(role_of(m.name))
    bpy.context.view_layer.update()
    s = width / max(o.dimensions.x, o.dimensions.y)
    o.scale = (s, s, s)
    o.location = (at_[0], at_[1], at_[2] - drop * s)
    return o


def wilt(o, sink=0.5, splay=0.6):
    """Leaves that flop: heights pressed down, the higher a point the further out it falls."""
    zs = [v.co.z for v in o.data.vertices]
    top = max(zs) or 1.0
    for v in o.data.vertices:
        k = max(v.co.z, 0) / top
        v.co.x *= 1 + splay * k
        v.co.y *= 1 + splay * k
        v.co.z *= sink
    return o


# baseplate, bellows at the back, two posts, the light cap with its LED panel underneath
bevel(box("plate", (W, D, PLATE), (0, 0, PLATE / 2), mat("metal")), width=0.006, segments=1)
for k in range(5):  # pleats of the folded bellows
    box(f"bellows{k}", (W - 0.02, 0.012, CAP - PLATE - 0.06), (0, -D / 2 + 0.012 + k * 0.016, (CAP + PLATE) / 2 - 0.02), mat("suit"))
for s in (-1, 1):
    bar(f"post{s}", (s * (W / 2 - 0.012), D / 2 - 0.02, PLATE), (s * (W / 2 - 0.012), D / 2 - 0.02, CAP - 0.02), 0.008, mat("metal"))
bevel(box("cap", (W + 0.02, D + 0.02, 0.05), (0, 0, CAP), mat("trim")), width=0.008, segments=1)
box("leds", (W - 0.03, D - 0.03, 0.008), (0, 0, CAP - 0.028), mat("grow"))
box("cap_switch", (0.025, 0.012, 0.012), (W / 2 - 0.03, D / 2 + 0.012, CAP), mat("light"))

# six pillows, 2 across and 3 deep, each with its white wick tabs at the front
cells = [((i - 0.5) * CW, (1 - j) * CD) for j in range(3) for i in range(2)]
for n, (x, y) in enumerate(cells):
    bevel(box(f"pillow{n}", (CW - 0.025, CD - 0.02, 0.05), (x, y, PLATE + 0.026), mat("trim")), width=0.015, segments=1)
    box(f"wick{n}", (0.03, 0.012, 0.035), (x, y + CD / 2 - 0.006, PLATE + 0.04), mat("suit"))

top = PLATE + 0.05
LETTUCE = os.path.join(CROPS, "glb", "Lettuce_3.glb")
BEET = os.path.join(CROPS, "zip", "Nature Crops Pack - Jan 2020", "OBJ", "Beet_3.obj")
red = lambda m: "romaine"  # noqa: E731
roots = lambda m: "romaine" if "Red" in m else "plant"  # noqa: E731
crop(LETTUCE, red, (*cells[0], top - 0.01), 0.2)
crop(LETTUCE, red, (*cells[1], top - 0.01), 0.19).rotation_euler.z = 1.3
for n in (2, 3):  # the root's shoulder shows above the pillow, as a ripe radish's does
    crop(BEET, roots, (*cells[n], top + 0.015), 0.13).rotation_euler.z = n
wilt(crop(LETTUCE, red, (*cells[4], top - 0.01), 0.15)).rotation_euler.z = 0.6

random.seed(7)  # microgreens: a dense mat of seedlings, a stem and a pair of seed leaves each
x0, y0 = cells[5]
for k in range(28):
    x, y = x0 + random.uniform(-0.045, 0.045), y0 + random.uniform(-0.04, 0.04)
    h = random.uniform(0.03, 0.05)
    cyl(f"sprout{k}", 0.0025, h, (x, y, top + h / 2 - 0.004), mat("plant"), 4)
    leaf = box(f"leaf{k}", (0.024, 0.009, 0.002), (x, y, top + h - 0.003), mat("plant"))
    leaf.rotation_euler = (0, random.uniform(-0.3, 0.3), random.uniform(0, 3.14))
done("prop_veggie", solid=False)  # it sits on the galley counter, which blocks; plants block nobody
