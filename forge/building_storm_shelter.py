# The storm shelter: NASA's idea of walls from cargo transfer bags full of food and water (CTB 0.5 x 0.42 x
# 0.25 m, data/reality.json crate.length), stacked eight high in a running bond with half bags at the ends,
# under a metal deck with one more layer of bags on top. Doorway 1.16 m wide, 1.92 m clear.
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

BL, BW, BH, GAP = 0.5, 0.42, 0.25, 0.012   # bag length, width, height, the gap between bags
X, Y, COURSES = 3.0, 2.42, 8               # outer footprint, courses (8 x 0.25 = 2.0 m)
DOOR = 0.58                                # half width of the doorway
rng = random.Random(7)                     # fixed: the same sag every build
reset()
bags = []


def bag(name, length, loc, along_x, out=None):
    """One soft-sided bag: rounded edges and a small random sag so the wall does not read as bricks,
    and on the outside face (`out`, +1 or -1 across the wall) the dark label pocket every CTB carries."""
    size = (length - GAP, BW - GAP, BH - GAP) if along_x else (BW - GAP, length - GAP, BH - GAP)
    o = bevel(box(name, size, loc, mat("suit")), width=0.04, segments=1)
    o.rotation_euler = (rng.uniform(-0.02, 0.02), rng.uniform(-0.02, 0.02), rng.uniform(-0.03, 0.03))
    o.scale.z = rng.uniform(0.94, 1.0)
    bags.append(o)
    if out and length > BL / 2:
        x, y, z = loc
        d = BW / 2 - 0.003
        bags.append(box(name + "_pocket", (0.16, 0.012, 0.08) if along_x else (0.012, 0.16, 0.08),
                        (x, y + out * d, z) if along_x else (x + out * d, y, z), mat("trim")))


def wall(tag, a, b, fixed, along_x, out, courses=COURSES):
    """Bags from a to b on one axis, the other axis at `fixed`; odd courses start with a half bag."""
    for c in range(courses):
        pos, first = a, (c % 2 == 1)
        while pos < b - 0.01:
            length = min(BL / 2 if first else BL, b - pos)
            mid, z = pos + length / 2, c * BH + BH / 2
            bag(f"{tag}{c}_{pos:.2f}", length, (mid, fixed, z) if along_x else (fixed, mid, z), along_x, out)
            pos, first = pos + length, False


wall("back", -X / 2, X / 2, -Y / 2 + BW / 2, True, -1)
for s in (-1, 1):
    wall(f"side{s}", -Y / 2 + BW, Y / 2, s * (X / 2 - BW / 2), False, s)
    lo, hi = sorted((s * DOOR, s * (X / 2 - BW)))
    wall(f"front{s}", lo, hi, Y / 2 - BW / 2, True, 1)
settle(join("walls-col", bags), (0, 0, 0))  # the first bag's sag must not tilt the whole wall

# roof: a beam over the doorway, a metal deck, one layer of bags as shielding
bags = []
roof = [box("beam", (2 * DOOR + 0.3, 0.2, 0.08), (0, Y / 2 - 0.1, COURSES * BH - 0.04), mat("metal"))]
roof.append(bevel(box("deck", (X + 0.1, Y + 0.1, 0.06), (0, 0, COURSES * BH + 0.03), mat("metal")), width=0.02))
for r in range(7):  # laid the other way on the roof: 7 rows of 0.42 m across, 5 bags of 0.5 m deep
    for k in range(5):
        bag(f"roofbag{r}_{k}", BL, (-1.26 + r * BW, -1.0 + k * BL, COURSES * BH + 0.06 + BH / 2), False)
settle(join("roof-col", roof + bags), (0, 0, 0))

box("sign", (1.5, 0.02, 0.24), (0, Y / 2 + 0.06, COURSES * BH + 0.19), mat("trim"))
flat_label("shelter_label", "SHELTER", 0.19, (0, Y / 2 + 0.075, COURSES * BH + 0.19), "hazard", 0.006)
status_light("shelter_light", (DOOR + 0.25, Y / 2 + 0.02, 1.6), (0.2, 0.04, 0.05))
done("building_storm_shelter")
