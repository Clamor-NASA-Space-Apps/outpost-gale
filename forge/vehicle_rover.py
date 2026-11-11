# The crewed pressurised rover, after NASA's Space Exploration Vehicle (fact sheet FS-2011-08-045-JSC):
# 4.48 m long, 3.05 m tall, twelve 0.99 m wheels in six pivoting pairs, a cabin with a wrap-around
# front window, two suitports and a docking hatch on the rear bulkhead, a small aft driving deck.
# Front is +Y here, which glTF turns into -Z (CONTRACTS.md). wheel_1..6 have their origin on the hub.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/vehicle_rover.py
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shapes import bar, bevel, box, cyl, finish, join, label, mat, prism, reset, settle, smooth, tyre  # noqa: E402

reset()
R, W = 0.495, 0.30                 # SEV wheel: 39 in across, 12 in wide
HUB_X, AXLES = 1.0, (1.55, 0.0, -1.55)
BODY, TRIM, METAL, GLASS, LIGHT, HAZ = (mat(n) for n in ("body", "trim", "metal", "glass", "light", "hazard"))

# Cabin side profile (y, z): flat roof, raked windscreen, short chin, rear bulkhead at y = -1.78
cabin = prism("cabin", [(-1.78, 1.08), (2.0, 1.08), (2.2, 1.55), (1.95, 2.05), (1.0, 2.78), (-1.78, 2.78)], 2.3, mat=BODY)
smooth(bevel(cabin, width=0.12, segments=3))
chassis = bevel(box("chassis", (1.3, 4.1, 0.46), (0, 0.1, 0.85), TRIM))
deck = bevel(box("deck", (2.2, 0.46, 0.08), (0, -2.0, 1.0), METAL))
join("body-convcol", [cabin, chassis, deck])  # the hero never goes inside, so a hull is enough

# Wrap-around window: the nose of the same profile, a hair larger, so it covers roof, front and both sides
glass = prism("window", [(0.45, 1.66), (2.215, 1.56), (1.965, 2.06), (1.0, 2.795), (0.45, 2.795)], 2.316, mat=GLASS)
smooth(bevel(glass, width=0.12, segments=3))
for s in (-1, 1):
    x = s * 1.16
    bar(f"pillar_a{s}", (x, 1.0, 2.80), (x, 1.965, 2.065), 0.045, TRIM)
    bar(f"pillar_b{s}", (x, 1.965, 2.065), (x, 2.215, 1.56), 0.045, TRIM)
    bar(f"sill{s}", (x, 0.45, 1.64), (x, 2.215, 1.56), 0.04, TRIM)
    bar(f"pillar_c{s}", (x, 0.45, 1.64), (x, 0.45, 2.80), 0.045, TRIM)
    bar(f"mullion{s}", (x, 1.25, 1.62), (x, 1.25, 2.6), 0.03, TRIM)
    label(f"name{s}", "ROVER 1", 0.36, (s * 1.158, -0.55, 2.0), (math.pi / 2, 0, s * math.pi / 2), TRIM)
    # side detail: a dark lower belt, an equipment locker with its handle, a hazard step plate
    bevel(box(f"belt{s}", (0.03, 3.5, 0.16), (s * 1.152, 0.0, 1.2), TRIM), width=0.01, segments=1)
    bevel(box(f"locker{s}", (0.06, 0.9, 0.5), (s * 1.17, -1.05, 1.62), BODY), width=0.03, segments=1)
    bar(f"locker_handle{s}", (s * 1.205, -1.3, 1.62), (s * 1.205, -0.8, 1.62), 0.015, METAL)
    box(f"step{s}", (0.3, 0.3, 0.04), (s * 0.85, -2.0, 1.06), HAZ)
    bevel(box(f"headlight{s}", (0.34, 0.05, 0.1), (s * 0.72, 2.09, 1.3), LIGHT))
    box(f"bumper_stripe{s}", (0.5, 0.04, 0.12), (s * 0.35, 2.17, 0.85), HAZ)
    # roof rails on three posts, and a grab rail down each rear corner
    for y in (-1.5, -0.5, 0.5):
        bar(f"post{s}{y}", (s * 0.95, y, 2.78), (s * 0.95, y, 2.93), 0.02, METAL)
    bar(f"roofrail{s}", (s * 0.95, -1.5, 2.93), (s * 0.95, 0.5, 2.93), 0.022, METAL)
    bar(f"grab{s}", (s * 1.08, -1.86, 1.25), (s * 1.08, -1.86, 2.45), 0.022, METAL)
    # aft driving deck rail: corner posts and a side rail
    bar(f"deckpost{s}", (s * 1.05, -2.2, 1.04), (s * 1.05, -2.2, 2.0), 0.025, METAL)
    bar(f"deckrail{s}", (s * 1.05, -2.2, 2.0), (s * 1.05, -1.8, 2.0), 0.025, METAL)

# Rear bulkhead: two suitports (oval ring, hatch plate, status light) either side of the docking hatch
for s in (-1, 1):
    ring = cyl(f"suitport_ring{s}", 0.35, 0.06, (s * 0.68, -1.8, 1.9), TRIM, 24, rot=(math.pi / 2, 0, 0))
    plate = cyl(f"suitport_plate{s}", 0.29, 0.1, (s * 0.68, -1.81, 1.9), BODY, 24, rot=(math.pi / 2, 0, 0))
    for o in (ring, plate):
        o.scale = (1, 1.45, 1)
        smooth(bevel(o, width=0.015, segments=2))
    bevel(box(f"suitport_lamp{s}", (0.12, 0.03, 0.04), (s * 0.68, -1.87, 2.45), LIGHT))
bevel(box("hatch_frame", (0.58, 0.05, 1.28), (0, -1.8, 1.82), TRIM), width=0.05)
bevel(box("hatch", (0.48, 0.07, 1.16), (0, -1.81, 1.82), BODY), width=0.06)
bar("hatch_handle", (-0.12, -1.86, 1.75), (0.12, -1.86, 1.75), 0.018, METAL)
console = bevel(box("console", (0.36, 0.22, 0.5), (-0.85, -2.05, 1.29), TRIM))
box("console_screen", (0.26, 0.02, 0.14), (-0.85, -2.165, 1.44), LIGHT).rotation_euler = (-0.3, 0, 0)

# Roof: radiator panel, antenna mast with a beacon, a small dish. Mast top is the rover's 3.05 m
bevel(box("radiator", (1.6, 1.6, 0.05), (0, -0.7, 2.81), TRIM))
bar("mast", (0.55, -1.45, 2.78), (0.55, -1.45, 2.99), 0.03, METAL)
smooth(cyl("beacon", 0.05, 0.06, (0.55, -1.45, 3.02), LIGHT, 16))
bar("dish_stalk", (-0.55, -1.4, 2.78), (-0.55, -1.4, 2.9), 0.025, METAL)
smooth(bevel(cyl("dish", 0.17, 0.04, (-0.55, -1.4, 2.93), METAL, 24, rot=(0.6, 0, 0)), width=0.01))

# Six wheel pairs. Each pair is one node so code can spin it (local X) and steer it (local up)
n = 0
for y in AXLES:
    for s in (-1, 1):
        n += 1
        hub = (s * HUB_X, y, R)
        pair = [tyre(f"t{n}{k}", R, W, (s * HUB_X + k * 0.165, y, R), TRIM, METAL, 24, 12) for k in (-1, 1)]
        settle(join(f"wheel_{n}", pair), hub)
        bar(f"axle{n}", (s * 0.6, y, R), (s * 0.85, y, R), 0.07, METAL)
finish("vehicle_rover")
