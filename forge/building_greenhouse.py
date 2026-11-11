# The greenhouse: a geodesic dome (6.8 m across) on a low ring wall, entered through a short vestibule
# with a 1.02 x 1.9 m doorway (the habitat's hatch size) and its own door leaf. Two raised grow beds under
# grow lights, with empty nodes slot_1..slot_8 where the lettuce models go.
# Built from Blender's icosphere rather than the Quaternius Geodesic_Dome: that one is a closed shell on
# feet with no doorway and painted-on panes, and a doorway cut into it left loose triangles.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
from base_kit import *  # noqa: E402,F403

RD, RW, FL = 3.4, 0.4, 0.1          # dome radius, ring wall height, floor top
HW, HH, TL = 1.02, 1.9, 2.0         # doorway, vestibule length
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
    return box("hole", (1.2, TL + 1.0, 2.05), (0, RD, FL + 1.025))


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
vest = box("vestibule-col", (1.5, TL, 2.35), (0, RD, 1.175), mat("body"))
cut(vest, box("vest_in", (1.2, TL + 0.2, 2.05), (0, RD, FL + 1.025)))
bevel(vest, width=0.03)
box("vest_floor-col", (1.2, TL, FL), (0, RD, FL / 2), mat("trim"))
frame = box("doorframe-col", (1.6, 0.14, 2.45), (0, RD + TL / 2, 1.225), mat("trim"))
cut(frame, box("door_cut", (HW, 0.5, HH), (0, RD + TL / 2, FL + HH / 2)))
bevel(frame, width=0.025)
for s in (-1, 1):
    box(f"hazard{s}", (0.06, 0.02, HH), (s * (HW / 2 + 0.1), RD + TL / 2 + 0.075, FL + HH / 2), mat("hazard"))
status_light("door_light", (0, RD + TL / 2 + 0.08, FL + HH + 0.2), (0.3, 0.04, 0.06))
leaf = [bevel(box("door", (HW - 0.02, 0.06, HH - 0.02), (0, RD + TL / 2, FL + HH / 2), mat("body")), width=0.02)]
leaf.append(smooth(cyl("door_window", 0.13, 0.08, (0, RD + TL / 2 + 0.01, FL + 1.5), mat("glass"), 24, rot=(math.pi / 2, 0, 0))))
leaf.append(smooth(bar("door_handle", (-0.36, RD + TL / 2 + 0.06, FL + 0.95), (-0.36, RD + TL / 2 + 0.06, FL + 1.25), 0.02, mat("metal"))))
settle(join("door", leaf), (HW / 2, RD + TL / 2, FL))

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
