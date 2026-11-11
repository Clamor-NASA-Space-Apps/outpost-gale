# The habitat: NASA's Habitat Demonstration Unit shape (a 5 m drum, 3.5 m tall, domed roof), hollow with
# a real wall, a floor at the hatch sill, a 1.02 x 1.9 m hatch (data/reality.json) and a ramp up to it.
# Collision comes from the -col parts (wall, floor, hatch frame, ramp, roof); the door leaf has none,
# it gets an AnimatableBody in the game.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

R, H, WALL, SILL, TOP = 2.5, 3.5, 0.12, 0.28, 2.6   # radius, height, wall, floor top, wall top
HW, HH, FRONT = 1.02, 1.9, 90                         # hatch width and height, front angle (+Y)
reset()

wall = cyl("wall-col", R, TOP, (0, 0, TOP / 2), mat("body"), 64)
cut(wall, cyl("inner", R - WALL, TOP + 0.2, (0, 0, TOP / 2), None, 64))
cut(wall, box("hatch_cut", (HW, 1.0, HH), (0, R, SILL + HH / 2)))
smooth(wall)
smooth(cyl("floor-col", R - WALL + 0.02, SILL, (0, 0, SILL / 2), mat("trim"), 64))
cap = 3.92  # sphere radius whose cap is 0.9 m high over a 5 m circle: (2.5^2 + 0.9^2) / (2 * 0.9)
roof = sphere("roof-col", cap, (0, 0, H - cap), mat("body"), 48)
cut(roof, box("below", (10, 10, 10), (0, 0, TOP - 5)))
smooth(roof)

# hatch frame: a collar through the wall, the opening cut out, hazard edges and grab bars
collar = box("hatch-col", (HW + 0.34, 0.4, HH + 0.26), (0, R - 0.07, SILL + HH / 2 + 0.03), mat("trim"))
cut(collar, box("hatch_cut2", (HW, 1.0, HH), (0, R, SILL + HH / 2)))
bevel(collar, width=0.03)
for s in (-1, 1):
    box(f"hazard{s}", (0.07, 0.02, HH), (s * (HW / 2 + 0.1), R + 0.135, SILL + HH / 2), mat("hazard"))
    smooth(bar(f"grab{s}", (s * (HW / 2 + 0.28), R + 0.2, SILL + 0.85), (s * (HW / 2 + 0.28), R + 0.2, SILL + 1.35), 0.02, mat("metal")))
    for z in (0.85, 1.35):
        bar(f"standoff{s}{z}", (s * (HW / 2 + 0.28), R + 0.08, SILL + z), (s * (HW / 2 + 0.28), R + 0.2, SILL + z), 0.015, mat("metal"))
status_light("hatch_light", (0, R + 0.15, SILL + HH + 0.08), (0.3, 0.05, 0.06))

# the door leaf, hinged on its left edge seen from outside; its own node, no collision suffix
leaf = [bevel(box("door", (HW - 0.02, 0.06, HH - 0.02), (0, R + 0.06, SILL + HH / 2), mat("body")), width=0.02)]
leaf.append(smooth(cyl("door_window", 0.13, 0.08, (0, R + 0.07, SILL + 1.5), mat("glass"), 24, rot=(math.pi / 2, 0, 0))))
leaf.append(cyl("door_window_ring", 0.17, 0.07, (0, R + 0.065, SILL + 1.5), mat("trim"), 24, rot=(math.pi / 2, 0, 0)))
leaf.append(box("door_seam", (HW - 0.2, 0.07, 0.03), (0, R + 0.06, SILL + 0.6), mat("trim")))
leaf.append(smooth(bar("door_handle", (-0.36, R + 0.12, SILL + 0.95), (-0.36, R + 0.12, SILL + 1.25), 0.02, mat("metal"))))
settle(join("door", leaf), (HW / 2, R + 0.06, SILL))

# ramp from the ground to the sill: 0.28 m over 1.2 m, a step no suited crew finds hard
ramp = prism("ramp-col", [(R + 0.13, 0), (R + 1.33, 0), (R + 0.13, SILL)], 1.2, mat=mat("metal"))
for s in (-1, 1):
    box(f"ramp_edge{s}", (0.05, 1.2, 0.03), (s * 0.58, R + 0.73, 0.02), mat("hazard"))

# hull detail: base skirt, a seam band under the roof, vertical panel seams, roof hatch and mast
smooth(cyl("skirt", R + 0.05, 0.2, (0, 0, 0.1), mat("trim"), 64))
band = cyl("mid_band", R + 0.03, 0.08, (0, 0, 0.8), mat("trim"), 64)
cut(band, cyl("band_in", R - 0.05, 0.2, (0, 0, 0.8), None, 64))  # a ring, not a disc across the room
smooth(cut(band, box("band_cut", (HW + 0.34, 1.0, 1.0), (0, R, 0.8))))
for r in (1.0, 1.85):  # seam rings on the roof, sitting on its curve
    smooth(cyl(f"roof_ring{r}-convcol", r, 0.05, (0, 0, H - cap + math.sqrt(cap * cap - r * r)), mat("trim"), 48))
rb = cyl("roof_band", R + 0.04, 0.14, (0, 0, TOP), mat("trim"), 64)
smooth(cut(rb, cyl("roof_band_in", R - 0.05, 0.3, (0, 0, TOP), None, 64)))  # else it lowers the ceiling
LABEL, WINDOWS = FRONT + 52, (FRONT - 45, FRONT + 160, FRONT - 110)
for d in range(0, 360, 30):
    a = FRONT + 15 + d
    if min(abs((a - b + 180) % 360 - 180) for b in (FRONT, LABEL, *WINDOWS)) < 22:
        continue  # no seam through the hatch, the label or a window
    s = box(f"seam{d}", (0.05, 0.03, TOP - 0.45), at(R + 0.005, a, TOP / 2 + 0.05), mat("trim"))
    s.rotation_euler.z = math.radians(a)
for i, a in enumerate(WINDOWS):
    rot = (0, math.pi / 2, math.radians(a))
    cyl(f"window_ring{i}", 0.34, 0.1, at(R + 0.02, a, 1.65), mat("trim"), 32, rot)
    smooth(cyl(f"window{i}", 0.26, 0.12, at(R + 0.03, a, 1.65), mat("glass"), 32, rot))
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

wrap(flat_label("hab_label", "HAB 1", 0.75, (0, 0, 0), "trim", 0.03, 180), R, LABEL, 1.45)
done("building_habitat")
