# The greenhouse: a geodesic dome (6.8 m across) on a low ring wall, entered through a short vestibule
# with a doorway of data/reality.json hatch.width x hatch.height (the habitat's) and its own door leaf, which
# swings into a vestibule wide enough to take it. Two hydroponic A-frames under
# grow lights, with empty nodes slot_1..slot_8 where the lettuce models go.
# Built from Blender's icosphere rather than the Quaternius Geodesic_Dome: that one is a closed shell on
# feet with no doorway and painted-on panes, and a doorway cut into it left loose triangles.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
from base_kit import *  # noqa: E402,F403
from mathutils import Vector  # noqa: E402

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


def tunnel_hole(grow=0.0):
    # wider than the vestibule's inside, and from under its floor to inside its roof, so every cut face ends
    # inside the vestibule's solid; cut to the inside size, they lay on its walls and flickered. Each part
    # gets its own `grow`: two parts cut by one cutter share their cut faces
    return box("hole", (VW + 0.1 + grow, TL + 1.0, VH + 0.2 + grow), (0, RD, FL + VH / 2 - 0.075))


panes = hemisphere("panes-col", "glass")
panes.modifiers.new("t", "SOLIDIFY").thickness = 0.04
applied(panes)
cut(panes, tunnel_hole())
struts = hemisphere("struts", "metal")
w = struts.modifiers.new("w", "WIREFRAME")
w.thickness, w.offset, w.use_even_offset = 0.09, 0.0, True
applied(struts)
cut_struts(struts, tunnel_hole(0.04))

ring = cyl("ring-col", RD + 0.06, RW, (0, 0, RW / 2), mat("trim"), 48)
cut(ring, cyl("ring_in", RD - 0.14, RW + 0.2, (0, 0, RW / 2), None, 48))
cut(ring, tunnel_hole(0.08))
floor = smooth(cyl("floor-col", RD - 0.12, FL, (0, 0, FL / 2), mat("trim"), 48))
cut(floor, box("under_vest", (VW + 0.1, TL, 1.0), (0, RD, 0.5)))  # the vestibule's own floor takes over there

# vestibule: a box tunnel through the dome, closed at the front by a frame with the doorway
vest = box("vestibule-col", (VW + 0.3, TL, FL + VH + 0.15), (0, RD, (FL + VH + 0.15) / 2), mat("body"))
cut(vest, box("vest_in", (VW, TL + 0.2, VH), (0, RD, FL + VH / 2)))
bevel(vest, width=0.03)
# a 6 mm trim plate on the vestibule's own bottom, up to the frame. Laid at the same height as that bottom, with the
# dome's floor reaching in too, it was three faces in one plane: the black striped band on the threshold (13 Nov playtest)
box("vest_floor-col", (VW, TL - 0.07, 0.006), (0, RD - 0.035, FL + 0.003), mat("trim"))
FY = RD + TL / 2  # the front frame's middle
frame = box("doorframe-col", (VW + 0.4, 0.14, FL + VH + 0.3), (0, FY, (FL + VH + 0.3) / 2), mat("trim"))
cut(frame, box("door_cut", (HW, 0.5, HH - 0.012), (0, FY, FL + 0.012 + (HH - 0.012) / 2)))  # sill 6 mm over the plate
bevel(frame, width=0.025)
for s in (-1, 1):
    box(f"hazard{s}", (0.06, 0.02, HH), (s * (HW / 2 + 0.1), FY + 0.075, FL + HH / 2), mat("hazard"))
status_light("door_light", (0, FY + 0.08, FL + HH + 0.15), (0.3, 0.04, 0.06))
inner_leaf(HW, HH, FY - 0.07, FL)

# two hydroponic A-frames either side of the aisle (nutrient film channels, the way commercial growers stack
# lettuce): the steel frame is Deepak Singh's "Hydroponic Farming Setup" (Sketchfab, CC BY 4.0; ASSETS.md) at 0.8
# of its size, the channels ours. Lettuce rides the upper aisle-side channel (slot_1..slot_8), where it stays
# inside the reach of the frame's foot, so nobody walks into a leaf. Grow lights glow magenta (Veggie's red and blue).
HYDRO = os.path.join(os.path.dirname(os.path.abspath(__file__)), *[".."] * 4, "assets-cache", "sketchfab", "hydroponic_farming_setup", "scene.gltf")
AS, AH, AW = 0.8, 2.04 * 0.8, 1.39 * 0.8 / 2  # A-frame scale, height, half its foot


def a_frame(x):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=HYDRO)
    new = set(bpy.context.scene.objects) - before
    bpy.context.view_layer.update()
    frame = next(o for o in new if o.name == "Object_6" or o.name.startswith("Object_6."))
    mw = frame.matrix_world.copy()
    frame.parent = None
    frame.matrix_world = mw
    for o in new - {frame}:
        bpy.data.objects.remove(o)
    frame.data.materials[0] = mat("metal")
    frame.rotation_euler.z += math.pi / 2  # its length along y, down the aisle
    frame.scale *= AS
    bpy.context.view_layer.update()
    pts = [frame.matrix_world @ Vector(c) for c in frame.bound_box]
    mid = sum(pts, Vector()) / 8
    frame.location += Vector((x - mid.x, -0.2 - mid.y, FL + 0.005 - min(p.z for p in pts)))
    return frame


slot = 0
for s in (-1, 1):
    x = s * 1.3
    parts = [a_frame(x)]
    for h in (0.45, 1.05):  # a channel on each face at two heights, on the frame's arms
        w = AW * (1 - h / AH) + 0.06
        for side in (-1, 1):
            parts.append(smooth(cyl(f"channel{s}{h}{side}", 0.05, 2.5, (x + side * w, -0.2, FL + h), mat("body"), 14, rot=(math.pi / 2, 0, 0))))
    join(f"rack{s}-convcol", parts)
    box(f"growlight{s}", (0.14, 3.2, 0.05), (x, -0.2, 2.25), mat("grow"))
    box(f"growlight_housing{s}", (0.2, 3.3, 0.06), (x, -0.2, 2.3), mat("trim"))
    for y in (-1.4, 1.0):
        top = RW + math.sqrt(RD * RD - x * x - y * y)
        bar(f"hanger{s}{y}", (x, y, 2.3), (x, y, top), 0.012, mat("metal"))
    w = AW * (1 - 1.05 / AH) + 0.06
    for k in range(4):
        slot += 1
        e = bpy.data.objects.new(f"slot_{slot}", None)  # where a lettuce model goes, on the aisle-side channel
        e.location = (x - s * w, -1.25 + k * 0.7, FL + 1.05 + 0.04)
        bpy.context.scene.collection.objects.link(e)
done("building_greenhouse")
