# The weather and radiation station: a mast that keeps measuring after the crew leave. NASA plans "network stations
# for seismic monitoring and long-duration climate monitoring" that run on (DRA 5.0, NASA/SP-2009-566); planetary
# protection wants a small suite measuring wind, humidity, dust and UV (ICES-2023-361). Laid out like Curiosity's
# REMS: two booms 120 degrees apart on the mast, an ultraviolet sensor looking up; a radiation detector that looks
# up at the sky (as Curiosity's RAD does) in a box at the foot, a small solar panel to run alone. Sizes are ours.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/prop_weather_mast.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

H, BOOM = 2.1, 1.55
reset()
smooth(bevel(cyl("base", 0.28, 0.05, (0, 0, 0.025), mat("trim"), 24), width=0.012, segments=2))
smooth(cyl("mast-convcol", 0.035, H, (0, 0, H / 2 + 0.05), mat("metal"), 12))
for i, a in enumerate((90, 210)):  # the two wind booms, one toward the front
    bar(f"boom{i}", at(0.03, a, BOOM), at(0.38, a, BOOM), 0.014, mat("metal"))
    b = bevel(box(f"sensor{i}", (0.1, 0.05, 0.05), at(0.42, a, BOOM), mat("body")), width=0.008, segments=1)
    b.rotation_euler.z = math.radians(a)
smooth(bevel(cyl("uv", 0.06, 0.05, (0, 0, H + 0.075), mat("body"), 16), width=0.008, segments=1))
smooth(cyl("uv_eye", 0.035, 0.012, (0, 0, H + 0.104), mat("glass"), 16))
# the panel faces the equator's sun, north at Gale (4.6 degrees south): it sits behind the mast and faces the front (+Y)
pv = bevel(box("pv", (0.5, 0.36, 0.025), (0, -0.12, 1.0), mat("trim")), width=0.006, segments=1)
pv.rotation_euler.x = math.radians(-35)
g = box("pv_glass", (0.46, 0.32, 0.008), (0, -0.1131, 1.0098), mat("glass"))
g.rotation_euler.x = math.radians(-35)
bar("pv_arm", (0, 0, 0.98), (0, -0.1, 0.99), 0.015, mat("metal"))
# the electronics box with its battery, and the radiation detector, at the foot
bevel(box("electronics", (0.42, 0.3, 0.32), (0, 0.3, 0.21), mat("body")), width=0.015)
flat_label("weather_label", "WEATHER", 0.07, (0, 0.456, 0.25), "trim", 0.006)
bevel(box("rad", (0.3, 0.26, 0.2), (0.42, 0.05, 0.15), mat("body")), width=0.015)
smooth(cyl("rad_eye", 0.06, 0.04, (0.42, 0.05, 0.27), mat("trim"), 16))
flat_label("rad_label", "RADIATION", 0.045, (0.42, 0.185, 0.14), "trim", 0.005)
done("prop_weather_mast")
