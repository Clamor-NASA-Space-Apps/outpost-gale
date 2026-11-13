# The greenhouse: a geodesic dome (6.8 m across) on a low ring wall, entered through a short vestibule
# with a doorway of data/reality.json hatch.width x hatch.height (the habitat's) and its own door leaf, which
# swings into a vestibule wide enough to take it. Two grow racks on the floor either side of an aisle, with empty
# nodes slot_1..slot_16 where the lettuce models go.
# Built from Blender's icosphere rather than the Quaternius Geodesic_Dome: that one is a closed shell on
# feet with no doorway and painted-on panes, and a doorway cut into it left loose triangles.
import os
import random
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

# Two grow racks either side of a 1.9 m aisle, standing on the floor: white-painted steel shelving (`panel`: in `metal`
# the posts mirrored the warm dome and read copper, 13 Nov captures) with three tiers of trays, an
# LED bar pair under each shelf (the `grow` magenta of red and blue diodes, Veggie's recipe) lighting the tier
# below, as NASA's ground plant racks and commercial vertical farms stack them. 2.4 x 0.6 m each, 4.3 m2 of
# trays for a 2-crew salad garden (NASA: 0.81 m2 grows 36 plants for 2, design/research/missing-assets.md 5).
# Lettuce sits in the two upper tiers' growing medium (slot_1..slot_16, world.json `plants`), microgreens on the
# bottom tier. Rack parts join `interior-col`: one collision body, swept clean (DESIGN.md weathering.clean).
L, DP, H = 2.4, 0.6, 1.95                 # rack length (along the aisle), depth, height
TIERS = (0.30, 0.85, 1.40)                # tray rim tops over the floor
TRAY, MED = 0.08, 0.02                    # tray depth; the growing medium's top under the rim
inside = []


def keep(o):
    inside.append(o)
    return o


slot = 0
slots = []
OY = RD - TL / 2 + 0.25  # the outlet boxes' line along the vestibule's sides, inside the dome
for s in (-1, 1):
    x = s * 1.25
    y0 = -0.35
    px = x - s * (DP / 2 - 0.02)  # the aisle-side posts
    for sx in (-1, 1):
        for sy in (-1, 1):  # square posts, their feet 5 mm into the floor so no face lies on it
            keep(box(f"post{s}{sx}{sy}", (0.035, 0.035, H - 0.005), (x + sx * (DP / 2 - 0.02), y0 + sy * (L / 2 - 0.02), FL + (H - 0.015) / 2), mat("panel")))  # top inside the top plate
    keep(bevel(box(f"top{s}", (DP, L, 0.025), (x, y0, FL + H - 0.0125), mat("panel")), width=0.004, segments=1))
    for k, t in enumerate(TIERS):
        tray = box(f"tray{s}{k}", (DP - 0.06, L - 0.06, TRAY), (x, y0, FL + t - TRAY / 2), mat("panel"))
        cut(tray, box("tray_in", (DP - 0.1, L - 0.1, TRAY), (x, y0, FL + t + 0.01 - TRAY / 2)))
        keep(tray)
        keep(box(f"medium{s}{k}", (DP - 0.08, L - 0.08, 0.03), (x, y0, FL + t - MED - 0.015), mat("trim")))  # rock wool
        for sx in (-1, 1):  # rails under the tray, along the rack, into the posts
            keep(box(f"rail{s}{k}{sx}", (0.025, L - 0.02, 0.03), (x + sx * (DP / 2 - 0.02), y0, FL + t - TRAY - 0.012), mat("panel")))  # 3 mm into the tray
        # the LED bars over this tier: under the next tray up, or under the top
        roof = (TIERS[k + 1] - TRAY) if k + 1 < len(TIERS) else (H - 0.025)
        for bx in (-0.13, 0.13):
            keep(box(f"led_housing{s}{k}{bx}", (0.07, L - 0.2, 0.025), (x + bx, y0, FL + roof - 0.0125 + 0.003), mat("trim")))
            box(f"growlight{s}{k}{bx}", (0.05, L - 0.24, 0.008), (x + bx, y0, FL + roof - 0.024), mat("grow"))  # its top inside the housing
        # the feed to this tier's bars: from each housing's door end out past the end post, then across the rack's end to
        # the riser on the aisle post. Lit bars with no wire read as lights out of thin air (13 Nov playtest)
        zf, ye = FL + roof - 0.015, y0 + L / 2 - 0.02 + 0.0175 + 0.014  # under the tray; 1.4 cm off the end posts' face
        for bx in (-0.13, 0.13):
            keep(smooth(bar(f"feed{s}{k}{bx}", (x + bx, y0 + (L - 0.2) / 2 - 0.005, zf), (x + bx, ye, zf), 0.008, mat("trim"), 8)))
        keep(smooth(bar(f"feed_x{s}{k}", (px - s * 0.008, ye, zf), (x + s * 0.138, ye, zf), 0.008, mat("trim"), 8)))
    # levelling feet: a steel plate and a boss on every post, the plate 2 mm into the floor. The room light casts no
    # shadow, so the feet are what show the racks stand on the floor (13 Nov playtest: they looked to float)
    for sx in (-1, 1):
        for sy in (-1, 1):
            fx, fy = x + sx * (DP / 2 - 0.02), y0 + sy * (L / 2 - 0.02)
            keep(bevel(box(f"foot{s}{sx}{sy}", (0.08, 0.08, 0.01), (fx, fy, FL + 0.003), mat("metal")), width=0.003, segments=1))
            keep(smooth(cyl(f"boss{s}{sx}{sy}", 0.028, 0.04, (fx, fy, FL + 0.026), mat("metal"), 12)))
    # the riser down the aisle-side door-end post, then along the floor beside the vestibule to an outlet box on its
    # side wall: where the power comes in from outside, by the door
    zc, xo = FL + 0.013, s * 1.10  # the floor run's centre 1 mm over the floor; its line, clear of posts and vestibule
    keep(smooth(bar(f"riser{s}", (px, ye, zc - 0.008), (px, ye, FL + H - 0.04), 0.012, mat("trim"), 8)))
    keep(smooth(bar(f"floor_run_x{s}", (px, ye, zc), (xo + s * 0.012, ye, zc), 0.012, mat("trim"), 8)))
    keep(smooth(bar(f"floor_run{s}", (xo, ye - 0.012, zc), (xo, OY, zc), 0.012, mat("trim"), 8)))
    keep(smooth(bar(f"outlet_riser{s}", (xo, OY, zc - 0.008), (xo, OY, FL + 0.11), 0.012, mat("trim"), 8)))
    ob = keep(bevel(box(f"outlet{s}", (0.08, 0.16, 0.2), (s * (VW / 2 + 0.15 + 0.03), OY, FL + 0.2), mat("trim")), width=0.01, segments=1))
    if s < 0:  # world.json cables.ends: the feed from outside meets it here
        e = bpy.data.objects.new("port_in", None)
        bpy.context.scene.collection.objects.link(e)
        e.location = (s * (VW / 2 + 0.15 + 0.03), OY, FL + 0.2)
        port_in = e
    for k in (1, 2):  # lettuce in the upper two tiers, four heads a tier
        for i in range(4):
            slot += 1
            e = bpy.data.objects.new(f"slot_{slot}", None)
            e.location = (x, y0 - L / 2 + 0.3 + i * 0.6, FL + TIERS[k] - MED)
            bpy.context.scene.collection.objects.link(e)
            slots.append(e)
    rng = random.Random(s)  # microgreens: a dense mat of seedlings on the bottom tier
    for k in range(60):
        px, py = x + rng.uniform(-0.22, 0.22), y0 + rng.uniform(-1.05, 1.05)
        h = rng.uniform(0.04, 0.07)
        keep(cyl(f"sprout{s}{k}", 0.003, h, (px, py, FL + TIERS[0] - MED + h / 2 - 0.005), mat("plant"), 4))
        leaf = keep(box(f"leaf{s}{k}", (0.03, 0.012, 0.003), (px, py, FL + TIERS[0] - MED + h - 0.004), mat("plant")))
        leaf.rotation_euler = (0, rng.uniform(-0.3, 0.3), rng.uniform(0, 3.14))

# the aisle: a deck plate down the middle, from the vestibule's floor to the far side, 1 cm proud of the floor
AY, VY = math.sqrt((RD - 0.2) ** 2 - 0.6 ** 2), RD - TL / 2 - 0.02
keep(box("aisle", (1.2, AY + VY, 0.015), (0, (VY - AY) / 2, FL + 0.0025), mat("deck")))
racks = join("interior-col", inside)
bpy.context.view_layer.update()
for e in slots + [port_in]:  # under the racks, so the lettuce in them is swept with the room and its light reaches it (world.gd)
    mw = e.matrix_world.copy()
    e.parent = racks
    e.matrix_world = mw
# the feed from HAB 1 (world.json cables.ends): a gland on the ring wall at the back, toward HAB 1 where the dome
# stands in the world, out and down into a ground gland box
PA = 240
port("port_1", at(RD + 0.3, PA, 0)[:2], at(RD + 0.05, PA, 0.24), r=0.03, turn=PA)
done("building_greenhouse")
