# The greenhouse: a geodesic dome (6.8 m across) on a low ring wall, entered through a short vestibule
# with a doorway of data/reality.json hatch.width x hatch.height (the habitat's) and its own door leaf, which
# swings into a vestibule wide enough to take it. Two raised grow beds under
# grow lights, with empty nodes slot_1..slot_8 where the lettuce models go.
# Built from Blender's icosphere rather than the Quaternius Geodesic_Dome: that one is a closed shell on
# feet with no doorway and painted-on panes, and a doorway cut into it left loose triangles.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
from base_kit import *  # noqa: E402,F403

RD, RW, FL = 3.4, 0.4, 0.2          # dome radius, ring wall height, floor top (over the uphill ground on a slope, under hero.step)
HW, HH, TL = row("hatch.width"), row("hatch.height"), 2.4  # doorway, vestibule length
VW, VH = HW + 0.6, HH + 0.15        # vestibule inside: room for the leaf opened 100 degrees (data/tuning.json)
reset()


def hemisphere(name, role):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=RD)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, 0), plane_no=(0, 0, 1), clear_inner=True)
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.location.z = RW
    o.data.materials.append(mat(role))
    return o


def applied(o):
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    return o


def cut_struts(o, cutter):
    """lib.cut() with the solver told the wireframe crosses itself at every joint; without it the struts
    across the doorway stayed."""
    m = o.modifiers.new("Cut", "BOOLEAN")
    m.operation, m.object, m.use_self, m.use_hole_tolerant = "DIFFERENCE", cutter, True, True
    applied(o)
    bpy.data.objects.remove(cutter)


def tunnel_hole():
    return box("hole", (VW, TL + 1.0, VH), (0, RD, FL + VH / 2))


panes = hemisphere("panes-col", "glass")
panes.modifiers.new("t", "SOLIDIFY").thickness = 0.04
applied(panes)
cut(panes, tunnel_hole())
struts = hemisphere("struts", "metal")
w = struts.modifiers.new("w", "WIREFRAME")
w.thickness, w.offset, w.use_even_offset = 0.09, 0.0, True
applied(struts)
cut_struts(struts, tunnel_hole())

ring = cyl("ring-col", RD + 0.06, RW, (0, 0, RW / 2), mat("trim"), 48)
cut(ring, cyl("ring_in", RD - 0.14, RW + 0.2, (0, 0, RW / 2), None, 48))
cut(ring, tunnel_hole())
smooth(cyl("floor-col", RD - 0.12, FL, (0, 0, FL / 2), mat("trim"), 48))

# vestibule: a box tunnel through the dome, closed at the front by a frame with the doorway
vest = box("vestibule-col", (VW + 0.3, TL, FL + VH + 0.15), (0, RD, (FL + VH + 0.15) / 2), mat("body"))
cut(vest, box("vest_in", (VW, TL + 0.2, VH), (0, RD, FL + VH / 2)))
bevel(vest, width=0.03)
box("vest_floor-col", (VW, TL, FL), (0, RD, FL / 2), mat("trim"))
FY = RD + TL / 2  # the front frame's middle
frame = box("doorframe-col", (VW + 0.4, 0.14, FL + VH + 0.3), (0, FY, (FL + VH + 0.3) / 2), mat("trim"))
cut(frame, box("door_cut", (HW, 0.5, HH), (0, FY, FL + HH / 2)))
bevel(frame, width=0.025)
for s in (-1, 1):
    box(f"hazard{s}", (0.06, 0.02, HH), (s * (HW / 2 + 0.1), FY + 0.075, FL + HH / 2), mat("hazard"))
status_light("door_light", (0, FY + 0.08, FL + HH + 0.15), (0.3, 0.04, 0.06))
inner_leaf(HW, HH, FY - 0.07, FL)

# two raised beds either side of the aisle, soil on top, grow lights hung from the dome
slot = 0
for s in (-1, 1):
    x = s * 1.3
    bed = bevel(box(f"bed{s}", (0.8, 3.6, 0.55), (x, -0.2, FL + 0.275), mat("trim")), width=0.03)
    bed.name = f"bed{s}-col"
    box(f"soil{s}", (0.7, 3.5, 0.04), (x, -0.2, FL + 0.55), mat("dust"))
    box(f"growlight{s}", (0.14, 3.2, 0.05), (x, -0.2, 2.25), mat("light"))
    box(f"growlight_housing{s}", (0.2, 3.3, 0.06), (x, -0.2, 2.3), mat("trim"))
    for y in (-1.4, 1.0):
        top = RW + math.sqrt(RD * RD - x * x - y * y)
        bar(f"hanger{s}{y}", (x, y, 2.3), (x, y, top), 0.012, mat("metal"))
    for k in range(4):
        slot += 1
        e = bpy.data.objects.new(f"slot_{slot}", None)  # where a lettuce model goes, on the soil
        e.location = (x, -1.55 + k * 0.9, FL + 0.57)
        bpy.context.scene.collection.objects.link(e)
done("building_greenhouse")
