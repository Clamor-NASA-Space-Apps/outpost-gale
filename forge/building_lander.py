# The lander: a crewed descent stage on four legs carrying a two-stage ascent vehicle (NASA's Mars ascent
# vehicle is about 40 t; its cabin is 1.8 m across for four crew). About 6 m across the footpads, 7.5 m
# tall. A porch and a ladder at the front reach the ground. Plain: no flags, no logos.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

DECK, PAD = 2.85, 2.6   # deck top height, footpad radius from the centre
reset()

body = [bevel(cyl("deck", 2.1, 0.5, (0, 0, DECK - 0.25), mat("trim"), 8), width=0.04)]
for i in range(8):  # equipment bays around the descent stage
    a = 22.5 + 45 * i
    b = bevel(box(f"bay{i}", (0.18, 1.1, 0.36), at(1.98, a, DECK - 0.27), mat("body")), width=0.02)
    b.rotation_euler.z = math.radians(a)
    body.append(b)
for i in range(4):  # propellant tanks under the deck, and the legs between them
    body.append(smooth(sphere(f"tank{i}", 0.55, at(1.05, 45 + 90 * i, DECK - 1.0), mat("metal"), 20)))
    a = 90 * i
    # the leg ends in a ball joint seated on its footpad: it stopped 23 cm above the pad, which read as a
    # floating leg once the pads sat in the dust
    top, foot = at(1.9, a, DECK - 0.4), at(PAD, a, 0.2)
    body.append(smooth(bar(f"leg{i}", top, foot, 0.08, mat("metal"), 12)))
    body.append(smooth(sphere(f"leg_joint{i}", 0.11, at(PAD, a, 0.17), mat("metal"), 12)))
    body.append(smooth(bar(f"strut{i}", at(1.0, a, DECK - 0.5), at(2.2, a, 1.4), 0.05, mat("metal"), 10)))
    body.append(smooth(cyl(f"footpad{i}", 0.38, 0.12, at(PAD, a, 0.06), mat("metal"), 20)))
    k = (0.6 - 0.2) / (DECK - 0.4 - 0.2)  # the band sits on the leg, 0.6 m up
    body.append(smooth(cyl(f"leg_band{i}", 0.1, 0.2, at(PAD - k * (PAD - 1.9), a, 0.6), mat("hazard"), 12)))
body.append(smooth(cone("engine", 0.6, 0.85, (0, 0, DECK - 1.45), mat("metal"), 24)))

# ascent vehicle: propellant stage, then the crew cabin with windows, hatch and docking ring
body.append(smooth(cyl("stage", 1.2, 2.75, (0, 0, DECK + 1.375), mat("body"), 32)))
for z in (DECK + 0.1, DECK + 1.4, DECK + 2.7):
    body.append(smooth(cyl(f"band{z}", 1.22, 0.1, (0, 0, z), mat("trim"), 32)))
bpy.ops.mesh.primitive_cone_add(radius1=1.2, radius2=0.72, depth=1.6, vertices=32, location=(0, 0, DECK + 3.55))
cabin = bpy.context.object
cabin.name = "cabin"
cabin.data.materials.append(mat("body"))
body.append(smooth(cabin))
body.append(smooth(cyl("docking_ring", 0.48, 0.25, (0, 0, DECK + 4.47), mat("trim"), 24)))
for i in range(4):  # thruster blocks around the cabin's base
    t = bevel(box(f"rcs{i}", (0.16, 0.3, 0.3), at(1.22, 45 + 90 * i, DECK + 2.95), mat("trim")), width=0.02)
    t.rotation_euler.z = math.radians(45 + 90 * i)
    body.append(t)
join("lander-col", body)

SLOPE = math.degrees(math.atan(0.48 / 1.6))  # the cabin wall leans back this far
for s in (-1, 1):  # two windows and the hatch on the cabin's front slope
    smooth(cyl(f"window{s}", 0.13, 0.1, at(0.88, 90 + s * 28, DECK + 3.85), mat("glass"), 16, rot=(0, math.radians(90 - SLOPE), math.radians(90 + s * 28))))
hatch = bevel(box("hatch", (0.75, 0.08, 0.95), at(1.06, 90, DECK + 3.25), mat("trim")), width=0.03)
hatch.rotation_euler.x = math.radians(SLOPE)

# the operator's name on the propellant stage, front and back, between its bands
for a in (90, 270):
    wrap(flat_label(f"team_label{a}", "CLAMOR", 0.32, (0, 0, 0), "trim", 0.02, 180), 1.2, a, DECK + 0.75)

# porch at deck level and a ladder down to the ground at the front
box("porch-col", (1.2, 0.8, 0.08), (0, 2.4, DECK - 0.046), mat("metal"))  # 6 mm under the deck, never flush with it
for s in (-1, 1):
    bar(f"porch_rail{s}", (s * 0.6, 2.0, DECK + 0.9), (s * 0.6, 2.8, DECK + 0.9), 0.025, mat("metal"))
    bar(f"porch_post{s}", (s * 0.6, 2.8, DECK), (s * 0.6, 2.8, DECK + 0.9), 0.025, mat("metal"))
    smooth(bar(f"ladder_rail{s}", (s * 0.25, 2.8, DECK), (s * 0.25, 3.5, 0.0), 0.025, mat("metal")))
for k in range(1, 10):
    f = k / 10
    bar(f"rung{k}", (-0.25, 2.8 + 0.7 * f, DECK * (1 - f)), (0.25, 2.8 + 0.7 * f, DECK * (1 - f)), 0.018, mat("metal"))
status_light("porch_light", (0.0, 2.05, DECK + 0.35), (0.2, 0.04, 0.05))
done("building_lander")
