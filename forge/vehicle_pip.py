# PIP, the base's small helper rover (original design): 0.8 m long, 0.5 m tall, no face. It shows mood
# with lights only: eye_l and eye_r on a sensor head that pans and tilts about its neck, and a status_bar
# on the nose. Four wheel nodes (wheel_1..4) with their origin on the hub. Front is +Y here (-Z in glTF).
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/vehicle_pip.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shapes import bar, bevel, box, finish, join, mat, prism, reset, settle, smooth, tyre  # noqa: E402

reset()
BODY, TRIM, METAL, GLASS, LIGHT, HAZ = (mat(n) for n in ("body", "trim", "metal", "glass", "light", "hazard"))
R = 0.1

# Chassis: a chunky tub with a sloped nose, dark bumpers fore and aft, a solar panel on the deck
tub = prism("tub-convcol", [(-0.33, 0.12), (0.29, 0.12), (0.34, 0.2), (0.3, 0.3), (-0.33, 0.3)], 0.42, mat=BODY)
smooth(bevel(tub, width=0.03, segments=3))
for y in (-0.36, 0.36):
    bevel(box(f"bumper{y}", (0.46, 0.05, 0.07), (0, y, 0.16), TRIM), width=0.02)
for s in (-1, 1):
    bevel(box(f"skirt{s}", (0.03, 0.56, 0.08), (s * 0.215, 0, 0.16), TRIM), width=0.01, segments=1)
    box(f"stripe{s}", (0.005, 0.12, 0.03), (s * 0.233, 0.22, 0.16), HAZ)
bevel(box("panel_frame", (0.4, 0.46, 0.02), (0, -0.07, 0.31), TRIM), width=0.008, segments=1)
box("solar", (0.36, 0.42, 0.012), (0, -0.07, 0.322), GLASS)
bar("whip", (-0.17, -0.3, 0.3), (-0.17, -0.3, 0.53), 0.006, METAL, 6)
status = bevel(box("status_bar", (0.16, 0.012, 0.025), (0, 0.322, 0.252), LIGHT), width=0.004, segments=1)
status.rotation_euler = (-0.6, 0, 0)  # lies on the sloped nose

# Sensor head on a short neck: the neck base is the head's pivot
neck = bar("neck", (0, 0.16, 0.3), (0, 0.16, 0.39), 0.025, METAL, 12)
housing = bevel(box("housing", (0.24, 0.12, 0.11), (0, 0.17, 0.445), TRIM), width=0.02, segments=3)
head = settle(join("head", [neck, smooth(housing)]), (0, 0.16, 0.3))
for x, side in ((0.055, "r"), (-0.055, "l")):  # as PIP sees them: facing +Y, its right is +X
    eye = bevel(box(f"eye_{side}", (0.07, 0.008, 0.05), (x, 0.233, 0.45), LIGHT), width=0.012, segments=2)
    eye.parent = head
    eye.matrix_parent_inverse = head.matrix_world.inverted()

n = 0
for y in (0.2, -0.2):
    for s in (-1, 1):
        n += 1
        tyre(f"wheel_{n}", R, 0.08, (s * 0.27, y, R), TRIM, METAL, 20, 10)
        bar(f"axle{n}", (s * 0.2, y, R), (s * 0.24, y, R), 0.02, METAL, 8)
finish("vehicle_pip")
