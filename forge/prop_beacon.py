# A 1.2 m marker post: a base plate, a post with hazard bands, a light cap on top (seen from all sides).
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/prop_beacon.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shapes import bevel, cyl, finish, mat, reset, smooth  # noqa: E402

reset()
BODY, TRIM, LIGHT, HAZ = (mat(n) for n in ("body", "trim", "light", "hazard"))

smooth(bevel(cyl("base", 0.16, 0.04, (0, 0, 0.02), TRIM, 24), width=0.012, segments=2))
smooth(cyl("post-convcol", 0.04, 1.06, (0, 0, 0.57), BODY, 16))
for z in (0.55, 0.85):
    smooth(cyl(f"band{z}", 0.042, 0.12, (0, 0, z), HAZ, 16))
smooth(bevel(cyl("collar", 0.06, 0.04, (0, 0, 1.1), TRIM, 20), width=0.01, segments=1))
smooth(bevel(cyl("cap", 0.05, 0.08, (0, 0, 1.16), LIGHT, 20), width=0.015, segments=2))
finish("prop_beacon")
