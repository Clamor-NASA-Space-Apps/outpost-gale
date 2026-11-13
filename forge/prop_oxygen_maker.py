# The gas bottle skid by the airlock (kept under its old name, prop_oxygen_maker; it makes nothing now). In
# NASA's first 30-sol stay "metabolic O2 will be maintained by tanked high pressure gas" (ICES-2023-265), and the
# ISS keeps its high pressure gas tanks "near the airlock" (NTRS 20200001084). 2 crew breathe 52 kg of O2 in
# 30 sols, 1.4 NORS tanks of 36.3 kg: so 2 oxygen bottles and 1 spare (white), plus 1 nitrogen bottle (dark)
# for leaks and airlock losses (design/research/missing-assets.md 2c). Bottle size is ours (NORS size not
# found): 0.36 m across, 1.3 m tall. The valves and their guards are Elk3D's "Gas Cylinder tank CO2 Helium
# Nitrogen" (Sketchfab, CC BY 4.0; ASSETS.md), decimated; its bottle body decimated to a faceted can, so the
# body is ours. It carries no lettering of its own; ours reads O2 and N2. A manifold joins the valves and a line
# runs 0.6 m back into the habitat.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403
from mathutils import Vector  # noqa: E402

W, D, SK = 1.72, 0.62, 0.12     # skid length (x), depth (y), height
BR, BH = 0.18, 1.3              # bottle radius, straight height
UNIT = 0.18                     # the download's units to metres (its valve then matches our bottle's neck)
XS = (-0.63, -0.21, 0.21, 0.63)
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), *[".."] * 4, "assets-cache", "sketchfab", "gas_cylinder_tank_co2_helium_nitrogen", "scene.gltf")
KEEP = {"Copper_Rough": 0.008, "Black_plastic_PL": 0.004}  # material -> decimate ratio; Car_Paint (the body) is dropped
GAS = ("O2", "O2", "O2", "N2")
reset()


def valve(i, x, z):
    """The download's valve and guard, decimated, in roles, standing on (x, 0, z)."""
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=SRC)
    new = set(bpy.context.scene.objects) - before
    bpy.context.view_layer.update()
    ms = [o for o in new if o.type == "MESH"]
    rest = [o for o in new if o.type != "MESH"]
    for o in [o for o in ms if o.data.materials[0].name.startswith("Car_Paint")]:
        ms.remove(o)
        bpy.data.objects.remove(o)
    for o in ms:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw  # in that order: unparenting keeps the local matrix, which lay the bottle down
        kind = next(k for k in KEEP if o.data.materials[0].name.startswith(k))
        o.data.materials[0] = mat("metal" if kind == "Copper_Rough" else "trim")
        o.modifiers.new("Decimate", "DECIMATE").ratio = KEEP[kind]
    for o in rest:
        bpy.data.objects.remove(o)
    b = join(f"valve{i}", ms)
    b.scale = (UNIT, UNIT, UNIT)
    bpy.context.view_layer.update()
    pts = [b.matrix_world @ Vector(c) for c in b.bound_box]
    mid = sum(pts, Vector()) / 8
    b.location += Vector((x - mid.x, -mid.y, z - min(p.z for p in pts)))
    return smooth(b)


parts = skid(W, D, SK)
for i, (x, g) in enumerate(zip(XS, GAS)):
    role = "panel" if g == "O2" else "trim"  # painted pressure bottles, smooth: in `body` they wore the hull's plates
    parts.append(smooth(cyl(f"bottle{i}", BR, BH, (x, 0, SK + BH / 2), mat(role), 18)))
    parts.append(smooth(sphere(f"bottle_top{i}", BR, (x, 0, SK + BH), mat(role), 16)))
    parts.append(smooth(cyl(f"neck{i}", 0.04, 0.08, (x, 0, SK + BH + BR + 0.02), mat("metal"), 10)))
    parts.append(valve(i, x, SK + BH + BR + 0.05))
    parts.append(smooth(cyl(f"band{i}", BR + 0.006, 0.06, (x, 0, SK + BH - 0.12), mat("hazard"), 18)))
bpy.context.view_layer.update()
TOP = max((parts[-2].matrix_world @ Vector(c)).z for c in parts[-2].bound_box)  # the valves' tops
# a box frame round the bottles, as a cylinder rack is built: uprights at the four corners, rails at the back,
# side bars, and two straps across the fronts that end in the front uprights (they floated when only the back
# had uprights, 13 Nov playtest). Ends run 5 mm into the uprights so no face lies on a face
FY = BR + 0.03  # the front uprights' centre line, just clear of the bottles
for x in (-W / 2 + 0.04, W / 2 - 0.04):
    for y, tag in ((-D / 2 + 0.05, "b"), (FY, "f")):  # 6 cm posts, unbevelled: the prop budget (4,000)
        parts.append(box(f"upright{tag}{x}", (0.06, 0.06, 1.3), (x, y, SK + 0.65), mat("metal")))
for z in (0.45, 1.05):
    parts.append(box(f"rail{z}", (W - 0.07, 0.05, 0.06), (0, -D / 2 + 0.05, SK + z), mat("metal")))
    parts.append(box(f"strap{z}", (W - 0.07, 0.03, 0.05), (0, FY - 0.01, SK + z), mat("trim")))
    for x in (-W / 2 + 0.04, W / 2 - 0.04):
        parts.append(box(f"side{z}{x}", (0.04, FY + D / 2 - 0.05 - 0.05, 0.04), (x, (FY - D / 2 + 0.05) / 2, SK + z), mat("metal")))
join("body-col", parts)

for i, (x, g) in enumerate(zip(XS, GAS)):  # what is in each bottle, on its front
    lab = wrap(flat_label(f"gas_label{i}", g, 0.11, (0, 0, 0), "trim" if g == "O2" else "body", 0, 180), BR + 0.004, 90, SK + 0.75)
    lab.location.x = x

# the manifold over the valves, down at the back and 0.6 m back into the habitat wall
top = TOP + 0.08
for x in XS:
    smooth(bar(f"riser{x}", (x, 0, TOP - 0.05), (x, 0, top), 0.018, mat("metal")))
smooth(bar("manifold", (XS[0] - 0.15, 0, top), (XS[-1] + 0.05, 0, top), 0.025, mat("metal")))
smooth(bar("drop", (XS[0] - 0.15, 0, top), (XS[0] - 0.15, -D / 2 - 0.05, top), 0.025, mat("metal")))
smooth(bar("down", (XS[0] - 0.15, -D / 2 - 0.05, top), (XS[0] - 0.15, -D / 2 - 0.05, 0.45), 0.025, mat("metal")))
smooth(bar("to_hab", (XS[0] - 0.15, -D / 2 - 0.05, 0.45), (XS[0] - 0.15, -D / 2 - 0.65, 0.45), 0.025, mat("metal")))
status_light("gas_light", (XS[0] - 0.15, 0.03, top + 0.08), (0.08, 0.03, 0.04))
done("prop_oxygen_maker")
