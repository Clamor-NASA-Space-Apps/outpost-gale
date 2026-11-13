# The habitat: NASA's Habitat Demonstration Unit shape (a 5 m drum, 3.5 m tall, domed roof), hollow with
# a real wall, a floor at the hatch sill, a hatch sized by data/reality.json hatch.width and hatch.height
# (wider and taller than the real one, so the suited hero walks in upright) and a ramp up to it.
# Collision comes from the -col parts (wall, floor, hatch frame, ramp, roof); the door leaf has none,
# it gets an AnimatableBody in the game.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403
from hab_interior import deck, fit_out, liner, unseen  # noqa: E402

# The floor sits 0.40 m up: the ground under the drum rises up to 0.31 m toward the hatch (the HiRISE patch at the
# base), and a 0.28 m floor let the sand show through the deck. The wall and roof went up with it, so the room
# keeps its 2.32 m to the ceiling; the drum is 3.62 m tall (the HDU's 3.5 m plus the raised floor).
R, H, WALL, SILL, TOP = 2.5, 3.62, 0.12, 0.40, 2.72  # radius, height, wall, floor top, wall top
HW, HH, FRONT = row("hatch.width"), row("hatch.height"), 90  # hatch width and height, front angle (+Y)
CD = 0.4                                              # collar depth through the wall
reset()

wall = cyl("wall-col", R, TOP, (0, 0, TOP / 2), mat("body"), 64)
cut(wall, cyl("inner", R - WALL, TOP + 0.2, (0, 0, TOP / 2), None, 64))
# 10 cm wider and taller than the opening, so the wall's cut faces end inside the collar: cut to the same size
# they lay on the collar's jambs and flickered white through it (13 Nov playtest)
cut(wall, box("hatch_cut", (HW + 0.2, 1.0, HH + 0.1), (0, R, SILL + HH / 2)))
smooth(wall)
FS = SILL - 0.015  # the slab's top: the deck plates (forge/hab_interior.py deck()) lie on it, their top at SILL
floor = smooth(cyl("floor-col", R - WALL + 0.02, FS, (0, 0, FS / 2), mat("trim"), 32))  # hidden: 32 sides keep its flats in the wall
cap = 3.92  # sphere radius whose cap is 0.9 m high over a 5 m circle: (2.5^2 + 0.9^2) / (2 * 0.9)
roof = sphere("roof-col", cap, (0, 0, H - cap), mat("body"), 48)
cut(roof, box("below", (10, 10, 10), (0, 0, TOP - 5)))
smooth(roof)

# hatch frame: a collar through the wall, the opening cut out, hazard edges and grab bars
# the collar's top stays under the roof band (TOP): SILL + HH + 0.1 with a 2.2 m hatch
collar = box("hatch-col", (HW + 0.34, CD, HH + 0.2), (0, R - 0.07, SILL + HH / 2), mat("trim"))
cut(collar, box("hatch_cut2", (HW, 1.0, HH), (0, R, SILL + HH / 2)))
cut(floor, box("under_collar", (HW + 0.34, CD, 1.0), (0, R - 0.07, 0.4)))  # the collar's sill is the floor there
bevel(collar, width=0.03)
for s in (-1, 1):
    box(f"hazard{s}", (0.07, 0.02, HH), (s * (HW / 2 + 0.1), R + 0.135, SILL + HH / 2), mat("hazard"))
    smooth(bar(f"grab{s}", (s * (HW / 2 + 0.28), R + 0.2, SILL + 0.85), (s * (HW / 2 + 0.28), R + 0.2, SILL + 1.35), 0.02, mat("metal")))
    for z in (0.85, 1.35):
        bar(f"standoff{s}{z}", (s * (HW / 2 + 0.28), R + 0.08, SILL + z), (s * (HW / 2 + 0.28), R + 0.2, SILL + z), 0.015, mat("metal"))
status_light("hatch_light", (0, R + 0.15, SILL + HH + 0.05), (0.3, 0.05, 0.06))

# the door leaf, behind the collar on the room side, opening inward like a real pressure hatch
inner_leaf(HW, HH, R - 0.07 - CD / 2, SILL)

# ramp from the ground to the sill: 0.40 m over 1.6 m (14 degrees), a slope no suited crew finds hard
RW, RL = HW + 0.2, 1.6
ramp = prism("ramp-col", [(R + 0.13, 0), (R + 0.13 + RL, 0), (R + 0.13, SILL)], RW, mat=mat("metal"))
for s in (-1, 1):
    box(f"ramp_edge{s}", (0.05, RL - 0.02, 0.03), (s * (RW / 2 - 0.02), R + 0.14 + RL / 2, 0.02), mat("hazard"))

# hull detail: base skirt, a seam band under the roof, vertical panel seams, roof hatch and mast
smooth(unseen(cyl("skirt", R + 0.05, 0.2, (0, 0, 0.1), mat("trim"), 64), lambda f: f.normal.z < -0.9))  # no underside: on the ground
band = cyl("mid_band", R + 0.03, 0.08, (0, 0, 0.8), mat("trim"), 48)  # 48 sides: 2.4 cm proud of the 64-sided wall still
cut(band, cyl("band_in", R - 0.05, 0.2, (0, 0, 0.8), None, 48))  # a ring, not a disc across the room
smooth(cut(band, box("band_cut", (HW + 0.34, 1.0, 1.0), (0, R, 0.8))))
for r in (1.0, 1.85):  # seam rings on the roof, sitting on its curve
    smooth(cyl(f"roof_ring{r}-convcol", r, 0.05, (0, 0, H - cap + math.sqrt(cap * cap - r * r)), mat("trim"), 48))
rb = cyl("roof_band", R + 0.04, 0.14, (0, 0, TOP), mat("trim"), 48)
smooth(cut(rb, cyl("roof_band_in", R - 0.05, 0.3, (0, 0, TOP), None, 48)))  # else it lowers the ceiling
LABEL, WINDOWS = FRONT + 52, (0, 253, 328)  # over the galley, beside the berths, beside the racks
WZ, WR, WO = SILL + 1.45, 0.34, 0.25  # window centre (eye height in the room), frame radius, opening radius
for d in range(0, 360, 30):
    a = FRONT + 15 + d
    if min(abs((a - b + 180) % 360 - 180) for b in (FRONT, LABEL, *WINDOWS)) < 22:
        continue  # no seam through the hatch, the label or a window
    s = box(f"seam{d}", (0.05, 0.03, TOP - 0.45), at(R + 0.005, a, TOP / 2 + 0.05), mat("trim"))
    s.rotation_euler.z = math.radians(a)
# portholes: a round frame through the wall, proud of both faces, so it meets the curve all round inside and out
# (a flat ring laid on the inside clipped into the curve at its sides: 12 Nov playtest). The hole is cut wider
# than the opening, so its faces end inside the frame; the pane's edge sits inside the frame too.
r_in, r_out = R - WALL - 0.05, R + 0.07
frames = []  # they join the swept fit-out: dusty, their inside half read brown in the clean white room (13 Nov)
for i, a in enumerate(WINDOWS):
    rot = (0, math.pi / 2, math.radians(a))
    cut(wall, cyl("window_hole", (WO + WR) / 2, 0.6, at(R - WALL / 2, a, WZ), None, 24, rot))
    ring = cyl(f"window_frame{i}", WR, r_out - r_in, at((r_in + r_out) / 2, a, WZ), mat("trim"), 24, rot)
    frames.append(smooth(bevel(cut(ring, cyl("window_open", WO, 1.0, at((r_in + r_out) / 2, a, WZ), None, 24, rot)), width=0.012, segments=1)))
    smooth(cyl(f"window{i}", WO + 0.02, 0.02, at(R - WALL / 2, a, WZ), mat("glass"), 24, rot))
smooth(cyl("roof_hatch-convcol", 0.5, 0.14, (0, 0, H - 0.02), mat("trim"), 32))
smooth(cyl("roof_hatch_lid-convcol", 0.38, 0.1, (0, 0, H + 0.06), mat("body"), 32))
smooth(bar("mast", (1.1, -0.6, H - 0.25), (1.1, -0.6, H + 0.9), 0.025, mat("metal")))
smooth(sphere("mast_tip", 0.05, (1.1, -0.6, H + 0.92), mat("light"), 12))
for i, a in enumerate((200, 250, 300)):
    bevel(box(f"vent{i}-convcol", (0.45, 0.3, 0.12), at(1.7, a, H - 0.38), mat("trim")), width=0.02).rotation_euler.z = math.radians(a)

# two spare gas tanks on a cradle at the back
for i, z in enumerate((0.42, 0.9)):
    smooth(cyl(f"tank{i}-convcol", 0.2, 1.3, at(R + 0.3, 270, z), mat("metal"), 24, rot=(0, math.pi / 2, 0)))
for dx in (-0.5, 0.5):
    box(f"cradle{dx}-convcol", (0.08, 0.5, 1.15), (dx, -R - 0.3, 0.6), mat("trim"))

# utility panel and conduits on the east side (where the oxygen and water machines stand)
bevel(box("utility_box", (0.12, 0.6, 0.7), at(R + 0.05, 0, 1.0), mat("trim")), width=0.02)
for dy in (-0.18, 0.0, 0.18):
    smooth(bar(f"conduit{dy}", (R + 0.14, dy, 0.65), (R + 0.14, dy, 0.02), 0.035, mat("metal")))
status_light("utility_light", (R + 0.12, 0, 1.42), (0.05, 0.16, 0.05))
# where the field cables plug in (world.json cables.ends): on this side a gland box under the three conduits
# (port_w, out to the greenhouse); on the far side (-X, toward the power yard) a feed box under the mid band with
# two conduits down into gland boxes, port_e2 in from the battery bank and port_e1 out to the yard light
port("port_w", (R + 0.14, 0), size=(0.16, 0.52))
bevel(box("feed_box", (0.14, 0.4, 0.3), (-(R + 0.04), 0, 0.55), mat("trim")), width=0.02)
for name, y in (("port_e1", 0.12), ("port_e2", -0.12)):
    port(name, (-(R + 0.2), y), (-(R + 0.11), y, 0.5), r=0.03)

# the fit-out for a crew of 2 (forge/hab_interior.py), clear of the hatch and its door's swing (65 to 115 degrees)
U, _, slots = fit_out(SILL, R - WALL, TOP)
U += frames
liner(SILL, R - WALL, TOP, WINDOWS, WZ, WR, HW, SILL + HH + 0.1)  # the collar's top
deck(SILL, R - WALL, box("deck_hatch", (HW + 0.36, CD + 0.006, 1.0), (0, R - 0.07, SILL)))  # 3 mm short of the collar
if os.environ.get("FORGE_TRIS"):
    dg = bpy.context.evaluated_depsgraph_get()
    for o in sorted([o for o in bpy.data.objects if o.type == "MESH"], key=lambda o: -sum(len(p.vertices) - 2 for p in o.evaluated_get(dg).data.polygons)):
        print("TRIS", o.name, sum(len(p.vertices) - 2 for p in o.evaluated_get(dg).data.polygons))
# the wall's top (under the roof) and foot (on the ground), and the window holes' faces inside the frames: never seen
unseen(wall, lambda f: abs(f.normal.z) > 0.9)
inside = join("interior-col", U)
bpy.context.view_layer.update()
for slot in slots:  # under the fit-out, so what world.json puts in them is kept swept with it
    mw = slot.matrix_world.copy()
    slot.parent = inside
    slot.matrix_world = mw

wrap(flat_label("hab_label", "HAB 1", 0.75, (0, 0, 0), "trim", 0.03, 180), R, LABEL, 1.45)
wrap(flat_label("team_label", "CLAMOR", 0.2, (0, 0, 0), "trim", 0.02, 180), R, LABEL, 1.0)  # the operator, under the name
done("building_habitat")
