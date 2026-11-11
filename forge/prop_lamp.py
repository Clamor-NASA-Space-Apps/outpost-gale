# A 3 m work-light mast for the base: tripod feet, a thin mast, a junction box, a lamp head angled
# down toward +Y (the model's front, -Z in glTF). The head's lens carries the light role.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/prop_lamp.py
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shapes import bar, bevel, box, cyl, finish, mat, reset, smooth  # noqa: E402

reset()
TRIM, METAL, LIGHT, HAZ = (mat(n) for n in ("trim", "metal", "light", "hazard"))

smooth(bar("mast-convcol", (0, 0, 0.04), (0, 0, 2.86), 0.035, METAL, 12))
smooth(bevel(cyl("collar", 0.06, 0.12, (0, 0, 0.55), TRIM, 16), width=0.01, segments=1))
for i in range(3):  # tripod feet, splayed so the mast stands on loose ground
    a = 2 * math.pi * i / 3 + math.pi / 6
    foot = (math.cos(a) * 0.5, math.sin(a) * 0.5, 0.02)
    bar(f"leg{i}", (0, 0, 0.55), foot, 0.02, METAL, 8)
    bevel(box(f"pad{i}", (0.1, 0.1, 0.04), foot, TRIM), width=0.01, segments=1)
bevel(box("junction", (0.12, 0.08, 0.18), (0, -0.07, 1.1), TRIM), width=0.01, segments=1)
box("junction_stripe", (0.122, 0.082, 0.03), (0, -0.07, 1.16), HAZ)
# Lamp head: housing, lens underneath, a short arm, tipped 25 degrees down to the front
housing = bevel(box("housing", (0.34, 0.2, 0.09), (0, 0.08, 2.9), TRIM), width=0.02, segments=2)
lens = bevel(box("lens", (0.29, 0.15, 0.02), (0, 0.08, 2.85), LIGHT), width=0.005, segments=1)
bar("arm", (0, 0, 2.86), (0, 0.06, 2.88), 0.02, METAL, 8)
for o in (housing, lens):
    o.rotation_euler = (math.radians(25), 0, 0)
finish("prop_lamp")
