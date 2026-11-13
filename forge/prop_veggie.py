# A Veggie plant unit as flown on the ISS (NTRS 20160005059, Veggie fact sheet 2019): a 29.2 x 36.8 cm
# baseplate, a light cap 47 cm up with red and blue LEDs (the `grow` role: they read magenta), bellows at the
# back, six black Kevlar plant pillows with white wicks; here one tray with a flat bed, which reads as a neat
# counter garden. In it, what fits a 30-sol stay: a red romaine 'Outredgeous' (VEG-01), two green lettuces, two
# radishes (27 days), microgreens (7 to 18 days). Every plant is forged from leaf shapes (`head()`, `leaf()`).
# Goes in HAB 1's galley (`slot_1`).
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/prop_veggie.py
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403
from mathutils import Matrix  # noqa: E402

W, D, CAP, PLATE = 0.292, 0.368, 0.47, 0.03  # baseplate width (x) and depth (y), light cap height, plate thickness
CW, CD = W / 2, D / 3                           # one pillow's share of the plate
reset()


# baseplate, two posts, the light cap with its LED panel underneath. No bellows: a white sheet behind the plants
# read as a stray panel (14 Nov playtest)
bevel(box("plate", (W, D, PLATE), (0, 0, PLATE / 2), mat("metal")), width=0.006, segments=1)
for s in (-1, 1):
    bar(f"post{s}", (s * (W / 2 - 0.012), D / 2 - 0.02, PLATE), (s * (W / 2 - 0.012), D / 2 - 0.02, CAP - 0.02), 0.008, mat("metal"))
bevel(box("cap", (W + 0.02, D + 0.02, 0.05), (0, 0, CAP), mat("trim")), width=0.008, segments=1)
box("leds", (W - 0.03, D - 0.03, 0.008), (0, 0, CAP - 0.028), mat("grow"))
box("cap_switch", (0.025, 0.012, 0.012), (W / 2 - 0.03, D / 2 + 0.012, CAP), mat("light"))

# one tray on the plate, its rim 6 cm up, holding one flat bed of dark growth medium 1 cm under the rim. Six loose
# pillows with white wicks read as brown lumps and stubs (14 Nov playtest)
TW, RIM, T = 0.012, 0.06, PLATE + 0.05  # tray wall, rim height over the plate, the bed's top
for s in (-1, 1):
    box(f"tray_side{s}", (TW, D - 0.01, RIM), (s * (W / 2 - 0.005 - TW / 2), 0, PLATE + RIM / 2), mat("panel"))
    box(f"tray_end{s}", (W - 0.01 - 2 * TW, TW, RIM), (0, s * (D / 2 - 0.005 - TW / 2), PLATE + RIM / 2), mat("panel"))
box("bed", (W - 0.01 - 2 * TW, D - 0.01 - 2 * TW, T - PLATE), (0, 0, (PLATE + T) / 2), mat("trim"))
cells = [((i - 0.5) * CW, (1 - j) * CD) for j in range(3) for i in range(2)]
top = T


def leaf(name, at_, ang, elev, length, width, role):
    """One leaf: a flat ellipsoid from its base at `at_`, pointing out at `ang` and up at `elev` (radians)."""
    o = sphere(name, 1.0, (0, 0, 0), mat(role), 6)
    o.matrix_world = (Matrix.Translation(at_) @ Matrix.Rotation(ang, 4, "Z") @ Matrix.Rotation(-elev, 4, "Y")
                      @ Matrix.Translation((length / 2, 0, 0)) @ Matrix.Diagonal((length / 2, width / 2, 0.004, 1)))
    return smooth(o)


def head(name, at_, size, role):
    """A loose-leaf lettuce: an outer ring of broad leaves splayed out, an inner ring standing up, as a Veggie
    romaine looks a few weeks in."""
    for ring, (n, elev, k) in enumerate(((7, 0.6, 1.0), (4, 1.2, 0.75))):  # reach: size x cos(0.6), 0.83 x size
        for i in range(n):
            leaf(f"{name}{ring}{i}", at_, 2 * math.pi * i / n + ring * 0.5, elev, size * k, size * k * 0.55, role)


# The plants are forged and stay inside the tray: every leaf's reach is under the 6.5 cm from a plant to the rim.
# A red romaine ('Outredgeous', VEG-01), two green lettuces, two radishes with their red shoulders out of the bed,
# a patch of microgreens. The pack's lettuce and beets, scaled down, poked out past the posts (14 Nov playtest)
head("romaine", (*cells[0], top), 0.075, "romaine")
head("lettuce_a", (*cells[1], top), 0.07, "plant")
head("lettuce_b", (*cells[4], top), 0.065, "plant")
for n in (2, 3):
    x, y = cells[n]
    smooth(sphere(f"radish{n}", 0.02, (x, y, top + 0.002), mat("romaine"), 8))
    for i in range(4):
        leaf(f"radish_leaf{n}{i}", (x, y, top + 0.016), 2 * math.pi * i / 4 + n, 0.95, 0.06, 0.03, "plant")

random.seed(7)  # microgreens: a dense mat of seedlings, a stem and a pair of seed leaves each
x0, y0 = cells[5]
for k in range(28):
    x, y = x0 + random.uniform(-0.035, 0.035), y0 + random.uniform(-0.035, 0.035)
    h = random.uniform(0.03, 0.05)
    cyl(f"sprout{k}", 0.0025, h, (x, y, top + h / 2 - 0.004), mat("plant"), 4)
    lf = box(f"leaf{k}", (0.024, 0.009, 0.002), (x, y, top + h - 0.003), mat("plant"))
    lf.rotation_euler = (0, random.uniform(-0.3, 0.3), random.uniform(0, 3.14))
done("prop_veggie", solid=False)  # it sits on the galley counter, which blocks; plants block nobody
