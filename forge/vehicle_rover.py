# The crewed pressurised rover, after NASA's Space Exploration Vehicle (fact sheet FS-2011-08-045-JSC):
# 4.48 m long, 3.05 m tall, twelve 0.99 m wheels in six pivoting pairs, a cabin with a wrap-around
# front window, two suitports and a docking hatch on the rear bulkhead, a small aft driving deck.
# The cabin is hollow behind its glass: a floor, two seats, a dashboard and a rear wall, sized so the suited
# hero sits inside (data/reality.json rover.cabin.*). An empty `seat` marks where the driver's hips go.
# Front is +Y here, which glTF turns into -Z (CONTRACTS.md). wheel_1..6 have their origin on the hub.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/vehicle_rover.py
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
import bpy  # noqa: E402
from shapes import bar, bevel, box, cut, cyl, finish, join, label, mat, prism, reset, settle, smooth, tyre  # noqa: E402

reset()
R, W = 0.495, 0.30                 # SEV wheel: 39 in across, 12 in wide
HUB_X, AXLES = 1.0, (1.55, 0.0, -1.55)
BODY, TRIM, METAL, GLASS, LIGHT, HAZ = (mat(n) for n in ("body", "trim", "metal", "glass", "light", "hazard"))
FLOOR, ROOF, BACK = 1.10, 2.75, -1.2   # the cabin's inside: floor, ceiling, rear wall (2-3 cm skins)
MAT_TOP = FLOOR + 0.015                # the floor mat the boots stand on
# the driver's hips: boots on the mat (the seated hero's boots are 0.542 m under its hips, its helmet 1.03 m
# over them, measured in drive_sit), far enough back that the helmet clears the raked windscreen
HIP = (-0.5, 0.85, MAT_TOP + 0.542)

# Cabin side profile (y, z): flat roof, raked windscreen, short chin, rear bulkhead at y = -1.78. Below the
# window sill it is solid body; the inside is cut out of it and the window prism closes it above the sill
lower = prism("cabin", [(-1.78, 1.08), (2.0, 1.08), (2.2, 1.55), (0.45, 1.65), (0.45, 2.78), (-1.78, 2.78)], 2.3, mat=BODY)
inside = prism("inside", [(BACK, FLOOR), (1.94, FLOOR), (2.13, 1.58), (1.9, 2.05), (0.97, ROOF), (BACK, ROOF)], 2.18)
bm = bmesh.new()
bm.from_mesh(inside.data)
print("ROVER_CABIN_M3 %.2f" % bm.calc_volume())  # data/reality.json rover.cabin.volume
cut(lower, inside)
smooth(bevel(lower, width=0.1, segments=2))
chassis = bevel(box("chassis", (1.3, 4.1, 0.46), (0, 0.1, 0.85), TRIM))
deck = bevel(box("deck", (2.2, 0.46, 0.08), (0, -2.0, 1.0), METAL))
join("body", [lower, chassis, deck])

# Wrap-around window: the nose of the same profile, a hair larger, as a 2 cm shell so the far pane shows too
glass = prism("window", [(0.45, 1.66), (2.215, 1.56), (1.965, 2.06), (1.0, 2.795), (0.45, 2.795)], 2.316, mat=GLASS)
glass.modifiers.new("shell", "SOLIDIFY").thickness = 0.02
smooth(bevel(glass, width=0.1, segments=2))
for s in (-1, 1):
    x = s * 1.16
    bar(f"pillar_a{s}", (x, 1.0, 2.80), (x, 1.965, 2.065), 0.045, TRIM)
    bar(f"pillar_b{s}", (x, 1.965, 2.065), (x, 2.215, 1.56), 0.045, TRIM)
    bar(f"sill{s}", (x, 0.45, 1.64), (x, 2.215, 1.56), 0.04, TRIM)
    bar(f"pillar_c{s}", (x, 0.45, 1.64), (x, 0.45, 2.80), 0.045, TRIM)
    label(f"name{s}", "ROVER 1", 0.36, (s * 1.158, -0.55, 2.0), (math.pi / 2, 0, s * math.pi / 2), TRIM)
    label(f"team{s}", "CLAMOR", 0.14, (s * 1.158, -0.55, 2.36), (math.pi / 2, 0, s * math.pi / 2), TRIM)  # the operator, as crews mark a vehicle
    # side detail: a dark lower belt, an equipment locker with its handle, a hazard step plate
    bevel(box(f"belt{s}", (0.03, 3.5, 0.16), (s * 1.152, 0.0, 1.2), TRIM), width=0.01, segments=1)
    bevel(box(f"locker{s}", (0.06, 0.9, 0.5), (s * 1.17, -1.05, 1.62), BODY), width=0.03, segments=1)
    bar(f"locker_handle{s}", (s * 1.205, -1.3, 1.62), (s * 1.205, -0.8, 1.62), 0.015, METAL)
    box(f"step{s}", (0.3, 0.3, 0.04), (s * 0.85, -2.0, 1.065), HAZ)
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

# Inside, seen through the glass: a dark floor mat, two seats open at the back for a suit's pack, a dashboard
# with a screen per seat under the windscreen, and a rear wall of racks with status strips
box("floor_mat", (2.1, 1.85 - BACK, MAT_TOP - FLOOR), (0, (1.85 + BACK) / 2, (FLOOR + MAT_TOP) / 2), TRIM)
for s in (-1, 1):
    x, y, hz = s * abs(HIP[0]), HIP[1], HIP[2]
    bevel(box(f"seat_base{s}", (0.3, 0.3, hz - 0.27 - MAT_TOP), (x, y - 0.02, (MAT_TOP + hz - 0.27) / 2), METAL), width=0.02, segments=1)
    bevel(box(f"cushion{s}", (0.52, 0.32, 0.08), (x, y + 0.03, hz - 0.23), TRIM), width=0.03, segments=2)
    bevel(box(f"seat_back{s}", (0.5, 0.07, 0.95), (x, y - 0.6, hz + 0.25), TRIM), width=0.03, segments=2)
    for k in (-1, 1):  # the back's frame down to the base: the pack hangs in the gap between
        bar(f"seat_strut{s}{k}", (x + k * 0.2, y - 0.58, hz - 0.2), (x + k * 0.2, y - 0.05, hz - 0.27), 0.018, METAL)
    box(f"screen{s}", (0.36, 0.02, 0.2), (x, 1.74, 1.72), LIGHT).rotation_euler = (math.radians(-35), 0, 0)
dash = bevel(box("dashboard", (2.1, 0.34, 0.14), (0, 1.8, 1.58), TRIM), width=0.03, segments=2)
dash.rotation_euler = (math.radians(-20), 0, 0)
bevel(box("rear_rack", (2.0, 0.06, 1.3), (0, BACK + 0.03, 1.85), TRIM), width=0.02, segments=1)
for z in (1.55, 2.15):
    box(f"rack_light{z}", (1.6, 0.02, 0.04), (0, BACK + 0.07, z), LIGHT)
seat = bpy.data.objects.new("seat", None)  # sandbox/rover.gd puts the driver's hips here
seat.location = HIP
bpy.context.scene.collection.objects.link(seat)

# Rear bulkhead: two suitports (oval ring, hatch plate, status light) either side of the docking hatch
for s in (-1, 1):
    ring = cyl(f"suitport_ring{s}", 0.35, 0.06, (s * 0.68, -1.8, 1.9), TRIM, 16, rot=(math.pi / 2, 0, 0))
    plate = cyl(f"suitport_plate{s}", 0.29, 0.1, (s * 0.68, -1.81, 1.9), BODY, 16, rot=(math.pi / 2, 0, 0))
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
smooth(bevel(cyl("dish", 0.17, 0.04, (-0.55, -1.4, 2.93), METAL, 16, rot=(0.6, 0, 0)), width=0.01))

# Six wheel pairs. Each pair is one node so code can spin it (local X) and steer it (local up)
n = 0
for y in AXLES:
    for s in (-1, 1):
        n += 1
        hub = (s * HUB_X, y, R)
        pair = [tyre(f"t{n}{k}", R, W, (s * HUB_X + k * 0.165, y, R), TRIM, METAL, 20, 8) for k in (-1, 1)]  # a lug at the bottom: 10 left it 3 cm up
        settle(join(f"wheel_{n}", pair), hub)
        bar(f"axle{n}", (s * 0.6, y, R), (s * 0.85, y, R), 0.07, METAL)
finish("vehicle_rover")
