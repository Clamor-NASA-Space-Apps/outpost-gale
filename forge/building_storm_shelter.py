# The storm shelter: NASA's idea of walls from cargo transfer bags full of food and water (CTB 0.5 x 0.42 x 0.25 m,
# data/reality.json crate.length; NTRS 20160004371 "solar radiation storm shelters"), stacked in a running bond round a
# metal frame, under a metal deck with one more layer of bags on top (RadWorks' group shelter: "a frame of aluminum ...
# an attachment structure for large panels of CTBs", NTRS 20170002287). A room of 4.0 x 3.5 m inside for 2 crew
# (forge/shelter_interior.py; 2.6 x 2.5 m was "too little room" in the 14 Nov playtest, and the camera's room
# profile caps its arm at half the plan's short side: 1.75 m here, 1.25 m before), entered by a door frame through
# the front wall, data/reality.json hatch.width by hatch.height, with a door leaf like HAB 1's. The walls rise as many
# courses as the doorway and its frame's head take.
#
# The corners are bonded like brickwork: on even courses the back and front walls run through the corner, on odd
# ones the side walls do, and a corner bag is 0.67 m long (the wall's thickness plus a quarter bag), so every course
# is a quarter bag off the one below and the inside corner reads the same all the way up (14 Nov: the bags "meet
# inconsistently at the corners"). Both room sides are whole multiples of a bag, so no wall needs a sliver.
import os
import random
import sys

import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403
from shelter_interior import fit_out, floor  # noqa: E402

BL, BW, BH, GAP = 0.5, 0.42, 0.25, 0.012   # bag length, width, height, the gap between bags
BEV = 0.04                                 # the soft edge of a bag
CB = BW + BL / 2                           # a corner bag: through the other wall and a quarter bag on
IX, IY = 4.0, 3.5                          # the room inside the bags: whole bags, for the corner bond
X, Y = IX + 2 * BW, IY + 2 * BW            # outer footprint
F = 0.06                                   # the floor's top
HW, HH = row("hatch.width"), row("hatch.height")
COURSES = math.ceil((F + HH + 0.1) / BH)   # 10 x 0.25 = 2.5 m: the doorway and a 10 cm head on its frame
H = COURSES * BH
FW = HW + 0.34                             # the door frame's width (HAB 1's collar)
rng = random.Random(7)                     # fixed: the same sag every build
reset()
bags = []


def bag(name, size, loc, faces, pocket=None):
    """One soft-sided bag drawn as only its faces that show: each a flat middle and four chamfers back to the bag's
    edge (`faces`: (axis, sign) pairs). Its top, bottom and the ends against a neighbour lie hidden, and a whole
    bevelled box spent 42 triangles a bag where this spends 10 a face, which is what lets a room twice the size
    keep the building budget. Behind the joints lies the wall's dark core. `pocket` (axis, sign): the dark label
    pocket every CTB carries, a face 3 mm proud of that side. A small random sag, so the wall is no brickwork."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    h = [s / 2 for s in size]
    for axis, sign in faces:
        u, v = [a for a in range(3) if a != axis]

        def P(n, a, b):
            p = [0.0, 0.0, 0.0]
            p[axis], p[u], p[v] = n, a, b
            return bm.verts.new(p)
        rim = ((-1, -1), (1, -1), (1, 1), (-1, 1))
        mid = [P(sign * h[axis], s * (h[u] - BEV), t * (h[v] - BEV)) for s, t in rim]
        edge = [P(sign * (h[axis] - BEV), s * h[u], t * h[v]) for s, t in rim]
        for q in [mid] + [[mid[i], mid[(i + 1) % 4], edge[(i + 1) % 4], edge[i]] for i in range(4)]:
            f = bm.faces.new(q)
            f.normal_update()
            if f.normal.dot(f.calc_center_median()) < 0:
                f.normal_flip()
    if pocket:
        axis, sign = pocket
        u, v = [a for a in range(3) if a != axis]
        q = []
        for s, t in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            p = [0.0, 0.0, 0.0]
            p[axis], p[u], p[v] = sign * (h[axis] + 0.003), s * (0.08 if u != 2 else 0.04), t * (0.08 if v != 2 else 0.04)
            q.append(bm.verts.new(p))
        f = bm.faces.new(q)
        f.material_index = 1
        f.normal_update()
        if f.normal[axis] * sign < 0:
            f.normal_flip()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat("suit"))
    o.data.materials.append(mat("trim"))
    o.location = loc
    o.rotation_euler = (rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), rng.uniform(-0.03, 0.03))
    o.scale.z = rng.uniform(0.94, 1.0)
    bags.append(o)


def run(tag, a, b, fixed, along_x, out, c, corner=(True, True), show=(False, False)):
    """One course of bags from a to b along x (or y), the other axis at `fixed`. `corner`: whether that end starts
    with a corner bag (this course runs through the corner); `show`: whether that end's face is outside."""
    ax = 0 if along_x else 1
    across = 1 - ax
    flip = corner[1] and not corner[0]  # laid from its corner end, so the odd piece lands at the door frame
    ends = corner[::-1] if flip else corner
    lengths, left = [], b - a
    while left > 0.01:
        first, last = not lengths, left <= CB + 0.01
        n = CB if (first and ends[0]) or (last and ends[1] and left > BL + 0.01) else BL
        lengths.append(min(n, left))
        left -= lengths[-1]
    if lengths[-1] < 0.2 and len(lengths) > 1:  # never a sliver at an end (the front walls end at the frame)
        lengths[-2] += lengths.pop()
    if flip:
        lengths.reverse()
    pos = a
    z = c * BH + BH / 2
    for i, n in enumerate(lengths):
        size = [0.0, 0.0, BH - GAP]
        size[ax], size[across] = n - GAP, BW - GAP
        loc = [0.0, 0.0, z]
        loc[ax], loc[across] = pos + n / 2, fixed
        faces = [(across, 1), (across, -1)]
        if i == 0 and show[0]:
            faces.append((ax, -1))
        if i == len(lengths) - 1 and show[1]:
            faces.append((ax, 1))
        bag(f"{tag}{c}_{i}", size, loc, faces, (across, out) if n > BL / 2 else None)
        pos += n


xs, ys = X / 2 - BW / 2, Y / 2 - BW / 2  # each wall's middle line
for c in range(COURSES):
    through = c % 2 == 0  # back and front walls run through the corners; on odd courses the sides do
    e = 0.0 if through else BW
    run("back", -X / 2 + e, X / 2 - e, -ys, True, -1, c, (through, through), (through, through))
    for s in (-1, 1):
        run(f"side{s}_", -Y / 2 + BW - e, Y / 2 - BW + e, s * xs, False, s, c, (not through, not through), (not through, not through))
        # the front's runs lay from the corner in, ending at the door frame's jamb
        lo, hi = (-X / 2 + e, -FW / 2) if s < 0 else (FW / 2, X / 2 - e)
        run(f"front{s}_", lo, hi, ys, True, 1, c, (through, False) if s < 0 else (False, through), (through, False) if s < 0 else (False, through))
# a dark core down the middle of each wall, 6 cm behind the bags' faces: through any joint between soft bags the
# eye meets it, never the sky or the ground beyond (14 Nov: the gaps showed the outside past a thin liner). Each
# core ends inside the one it meets, so no two end faces lie on each other
T = BW - 0.12
core = [box("core_back", (X - 0.16, T, H - 0.01), (0, -ys, (H - 0.01) / 2), mat("trim"))]
for s in (-1, 1):
    core.append(box(f"core_side{s}", (T, Y - 0.16, H - 0.012), (s * xs, 0, (H - 0.012) / 2), mat("trim")))
    w = X / 2 - 0.08 - (FW / 2 - 0.02)
    core.append(box(f"core_front{s}", (w, T, H - 0.014), (s * (FW / 2 - 0.02 + w / 2), ys, (H - 0.014) / 2), mat("trim")))
walls = settle(join("walls-col", bags + core), (0, 0, 0))  # the first bag's sag must not tilt the whole wall

# the bags' faces toward the room join the fit-out, kept swept (DESIGN.md weathering.clean `interior`) and lit by
# the room light; their outside faces keep the dust
ix, iy = X / 2 - BW, Y / 2 - BW


def inward(f):
    """A face in a wall's inner band (the bags' room faces, their chamfers, the core behind them) turned to the room.
    Judged per wall, not by a box round the room: a corner bag's room face reaches into the other wall, its middle
    fell outside the box, and every other course's corner wore the outside's dust (14 Nov)."""
    c, n = f.calc_center_median(), f.normal
    return any(abs(abs(c[a]) - i) < 0.075 and n[a] * -math.copysign(1, c[a]) > 0.5 for a, i in ((0, ix), (1, iy)))


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
frame = box("frame-col", (FW, BW + 0.02, H + 0.02), (0, ys, (H + 0.02) / 2), mat("trim"))
cut(frame, box("frame_cut", (HW, 1.0, F + HH + 1.0), (0, Y / 2, (F + HH - 1.0) / 2)))
bevel(frame, width=0.02, segments=1)
for s in (-1, 1):
    box(f"hazard{s}", (0.07, 0.02, HH), (s * (HW / 2 + 0.08), Y / 2 + 0.025, F + HH / 2), mat("hazard"))
status_light("shelter_light", (0, Y / 2 + 0.025, F + HH + 0.12), (0.2, 0.04, 0.05))
inner_leaf(HW, HH, Y / 2 - BW - 0.01, F)  # opens inward, about its corner on the +x side

# roof: a metal deck, one layer of bags as shielding: their tops, and the outer sides of the edge rows
bags = []
deck = bevel(box("deck", (X + 0.1, Y + 0.1, 0.06), (0, 0, H + 0.03), mat("metal")), width=0.02)
NX, NY = int(X // BW), int(Y // BL)  # laid the other way on the roof: rows of 0.42 m across, bags of 0.5 m deep
for r in range(NX):
    for k in range(NY):
        faces = [(2, 1)] + [(0, s) for s, edge in ((-1, r == 0), (1, r == NX - 1)) if edge] + [(1, s) for s, edge in ((-1, k == 0), (1, k == NY - 1)) if edge]
        bag(f"roofbag{r}_{k}", (BW - GAP, BL - GAP, BH - GAP), ((r - (NX - 1) / 2) * BW, (k - (NY - 1) / 2) * BL, H + 0.06 + BH / 2), faces)
settle(join("roof-col", [deck] + bags), (0, 0, 0))

box("sign", (1.5, 0.02, 0.24), (0, Y / 2 + 0.06, H + 0.19), mat("trim"))
flat_label("shelter_label", "SHELTER", 0.19, (0, Y / 2 + 0.075, H + 0.19), "hazard", 0)  # flat, 5 mm proud: raised, it cost 1,000 triangles

parts = fit_out(IX, IY, F, H)
floor(IX, IY, F, Y / 2 + 0.012, HW)
# the room's lights and screens join it too: kept swept, so the sky clock leaves their glow on by day (sky_clock.gd
# _glow_faces); in detail-col they dimmed to a glimmer with the floodlights (14 Nov: "the lamp does not glow")
inside = join("interior-col", [inner] + parts)
if os.environ.get("FORGE_TRIS"):
    dg = bpy.context.evaluated_depsgraph_get()
    for o in sorted([o for o in bpy.data.objects if o.type == "MESH"], key=lambda o: -sum(len(p.vertices) - 2 for p in o.evaluated_get(dg).data.polygons)):
        print("TRIS", o.name, sum(len(p.vertices) - 2 for p in o.evaluated_get(dg).data.polygons))
done("building_storm_shelter")
