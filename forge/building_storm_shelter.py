# The storm shelter: NASA's idea of walls from cargo transfer bags full of food and water (CTB 0.5 x 0.42 x 0.25 m,
# data/reality.json crate.length; NTRS 20160004371 "solar radiation storm shelters"), stacked in a running bond with
# half bags at the ends round a metal frame, under a metal deck with one more layer of bags on top (RadWorks' group
# shelter: "a frame of aluminum ... an attachment structure for large panels of CTBs", NTRS 20170002287). A room of
# 2.6 x 2.5 m inside for 2 crew (forge/shelter_interior.py), entered by a door frame through the front wall,
# data/reality.json hatch.width by hatch.height, with a door leaf like HAB 1's. The walls rise as many courses as the
# doorway and its frame's head take.
import os
import random
import sys

import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403
from shelter_interior import fit_out, floor  # noqa: E402

BL, BW, BH, GAP = 0.5, 0.42, 0.25, 0.012   # bag length, width, height, the gap between bags
IX, IY = 2.6, 2.5                          # the room inside the bags
X, Y = IX + 2 * BW, IY + 2 * BW            # outer footprint
F = 0.06                                   # the floor's top
HW, HH = row("hatch.width"), row("hatch.height")
COURSES = math.ceil((F + HH + 0.1) / BH)   # 10 x 0.25 = 2.5 m: the doorway and a 10 cm head on its frame
H = COURSES * BH
FW = HW + 0.34                             # the door frame's width (HAB 1's collar)
rng = random.Random(7)                     # fixed: the same sag every build
reset()
bags = []


def bag(name, length, loc, along_x, out=None, drop=()):
    """One soft-sided bag: rounded edges and a small random sag so the wall does not read as bricks, and on the
    outside face (`out`, +1 or -1 across the wall) the dark label pocket every CTB carries. `drop` names the faces
    that lie against a neighbour, the ground or the deck ("top", "bottom", "lo", "hi" along the run): nobody sees
    them, and they cost the building its triangle budget."""
    size = (length - GAP, BW - GAP, BH - GAP) if along_x else (BW - GAP, length - GAP, BH - GAP)
    o = bevel(box(name, size, loc, mat("suit")), width=0.04, segments=1)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=o.modifiers[-1].name)
    run = 0 if along_x else 1
    axes = {"top": (2, 1), "bottom": (2, -1), "lo": (run, -1), "hi": (run, 1)}
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.normal_update()
    # a dropped face, and the bevel between two dropped faces (edge-on from outside: an end's top edge)
    dots = [[f.normal[axes[d][0]] * axes[d][1] for d in drop] for f in bm.faces]
    dead = [f for f, k in zip(bm.faces, dots) if max(k, default=0) > 0.99 or sum(v > 0.6 for v in k) >= 2]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    bm.to_mesh(o.data)
    bm.free()
    o.rotation_euler = (rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), rng.uniform(-0.03, 0.03))
    o.scale.z = rng.uniform(0.94, 1.0)
    bags.append(o)
    if out and length > BL / 2:
        # one face 3 mm proud of the bag: a box's other five faces sat inside it
        x, y, z = loc
        d = BW / 2 - GAP / 2 + 0.003
        p = box(name + "_pocket", (0.16, 0.001, 0.08) if along_x else (0.001, 0.16, 0.08), (x, y + out * d, z) if along_x else (x + out * d, y, z), mat("trim"))
        bm = bmesh.new()
        bm.from_mesh(p.data)
        bm.normal_update()
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.normal[1 - run] * out < 0.99], context="FACES")
        bm.to_mesh(p.data)
        bm.free()
        bags.append(p)


def wall(tag, a, b, fixed, along_x, out, ends=(False, False)):
    """Bags from a to b on one axis, the other axis at `fixed`; odd courses start with a half bag. `ends` says
    whether the run's first and last faces show (an outside corner) or lie against a wall or the door frame."""
    for c in range(COURSES):
        pos, first = a, (c % 2 == 1)
        while pos < b - 0.01:
            length = min(BL / 2 if first else BL, b - pos)
            mid, z = pos + length / 2, c * BH + BH / 2
            drop = ["bottom"] + (["top"] if c < COURSES - 1 else [])
            drop += [] if (pos <= a + 0.001 and ends[0]) else ["lo"]
            drop += [] if (pos + length >= b - 0.001 and ends[1]) else ["hi"]
            bag(f"{tag}{c}_{pos:.2f}", length, (mid, fixed, z) if along_x else (fixed, mid, z), along_x, out, drop)
            pos, first = pos + length, False


wall("back", -X / 2, X / 2, -Y / 2 + BW / 2, True, -1, (True, True))
for s in (-1, 1):
    wall(f"side{s}", -Y / 2 + BW, Y / 2, s * (X / 2 - BW / 2), False, s, (False, True))
    lo, hi = sorted((s * FW / 2, s * (X / 2 - BW)))
    wall(f"front{s}", lo, hi, Y / 2 - BW / 2, True, 1)
# a dark liner down the middle of each wall: where the bags' rounded corners meet, the sky showed through in
# pin-points. Inside the bags, it shows only through those gaps
T = 0.01
liner = [box("liner_back", (X - 0.06, T, H - 0.03), (0, -Y / 2 + BW / 2, (H - 0.03) / 2), mat("trim"))]
for s in (-1, 1):
    liner.append(box(f"liner_side{s}", (T, Y - BW / 2 - 0.03, H - 0.03), (s * (X / 2 - BW / 2), BW / 4 - 0.015, (H - 0.03) / 2), mat("trim")))
    w = X / 2 - BW / 2 - FW / 2
    liner.append(box(f"liner_front{s}", (w, T, H - 0.03), (s * (FW / 2 + w / 2 - 0.01), Y / 2 - BW / 2, (H - 0.03) / 2), mat("trim")))
walls = settle(join("walls-col", bags + liner), (0, 0, 0))  # the first bag's sag must not tilt the whole wall

# the bags' faces toward the room join the fit-out, kept swept (DESIGN.md weathering.clean `interior`) and lit by
# the room light; their outside faces keep the dust
ix, iy = X / 2 - BW, Y / 2 - BW


def inward(f):
    c, n = f.calc_center_median(), f.normal
    if abs(c.x) > ix + 0.07 or abs(c.y) > iy + 0.07:
        return False
    side = ix - abs(c.x) < iy - abs(c.y)  # nearer a side wall than the back or front
    into = Vector((-math.copysign(1, c.x), 0, 0)) if side else Vector((0, -math.copysign(1, c.y), 0))
    return n.dot(into) > 0.5


inner = bpy.data.objects.new("inner_faces", walls.data.copy())
bpy.context.scene.collection.objects.link(inner)
for o, keep in ((walls, False), (inner, True)):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.normal_update()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if inward(f) != keep], context="FACES")
    bm.to_mesh(o.data)
    bm.free()

# the door frame through the front wall, its head under the deck; its opening runs down through the floor
frame = box("frame-col", (FW, BW + 0.02, H + 0.02), (0, Y / 2 - BW / 2, (H + 0.02) / 2), mat("trim"))
cut(frame, box("frame_cut", (HW, 1.0, F + HH + 1.0), (0, Y / 2, (F + HH - 1.0) / 2)))
bevel(frame, width=0.02, segments=1)
for s in (-1, 1):
    box(f"hazard{s}", (0.07, 0.02, HH), (s * (HW / 2 + 0.08), Y / 2 + 0.025, F + HH / 2), mat("hazard"))
status_light("shelter_light", (0, Y / 2 + 0.025, F + HH + 0.12), (0.2, 0.04, 0.05))
inner_leaf(HW, HH, Y / 2 - BW - 0.01, F)  # opens inward, about its corner on the +x side

# roof: a metal deck, one layer of bags as shielding
bags = []
deck = bevel(box("deck", (X + 0.1, Y + 0.1, 0.06), (0, 0, H + 0.03), mat("metal")), width=0.02)
NX, NY = int(X // BW), int(Y // BL)  # laid the other way on the roof: rows of 0.42 m across, bags of 0.5 m deep
for r in range(NX):
    for k in range(NY):
        ends = ([] if k == 0 else ["lo"]) + ([] if k == NY - 1 else ["hi"])
        bag(f"roofbag{r}_{k}", BL, ((r - (NX - 1) / 2) * BW, (k - (NY - 1) / 2) * BL, H + 0.06 + BH / 2), False, drop=["bottom"] + ends)
settle(join("roof-col", [deck] + bags), (0, 0, 0))

box("sign", (1.5, 0.02, 0.24), (0, Y / 2 + 0.06, H + 0.19), mat("trim"))
flat_label("shelter_label", "SHELTER", 0.19, (0, Y / 2 + 0.075, H + 0.19), "hazard", 0)  # flat, 5 mm proud: raised, it cost 1,000 triangles

parts, loose = fit_out(IX, IY, F, H)
floor(IX, IY, F, Y / 2 + 0.012, HW - 0.006)  # 3 mm inside the frame's opening each side
inside = join("interior-col", [inner] + parts)
if os.environ.get("FORGE_TRIS"):
    dg = bpy.context.evaluated_depsgraph_get()
    for o in sorted([o for o in bpy.data.objects if o.type == "MESH"], key=lambda o: -sum(len(p.vertices) - 2 for p in o.evaluated_get(dg).data.polygons)):
        print("TRIS", o.name, sum(len(p.vertices) - 2 for p in o.evaluated_get(dg).data.polygons))
done("building_storm_shelter")
