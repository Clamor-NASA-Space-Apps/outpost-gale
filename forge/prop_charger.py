# The rover's charging post in its bay: the crew "connect the PR to the surface power grid to recharge batteries"
# (SAC21, NTRS 20210026448). A pedestal about a metre tall on a footplate, a head with a holster for the plug, a
# status light, and the plug on its lead. The feed from the battery bank comes in at the back (port_1, the
# shared gland box: base_kit.port()); the lead leaves the head at `lead_out`. Front (+Y, the game's -Z) faces the rover.
# Moving parts (base_kit.moves(), world.json `moving`): `plug` (origin on its nose's face, its body along +Y; world.gd
# puts it in the rover's `port_charge` while the rover is parked, else in `holster`) and `charge_light` (shown while
# plugged in, over a dark lens). The lead itself is drawn by world.gd between `lead_out` and the plug's tail.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/forge/previews blender -b -P forge/prop_charger.py
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

PW, PD, TOP = 0.2, 0.16, 0.78      # post width and depth, post top
HW, HD, HH = 0.32, 0.26, 0.3       # head
FRONT = HD / 2                      # the head's front face, y
HOLSTER = (0, FRONT + 0.03, TOP + 0.12)
reset()


def empty(name, loc, parent):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.location = loc
    bpy.context.view_layer.update()
    e.parent = parent
    e.matrix_parent_inverse = parent.matrix_world.inverted()
    return e


body = [bevel(box("footplate", (0.5, 0.42, 0.05), (0, 0, 0.025), mat("metal")), width=0.012, segments=1),
        bevel(box("post", (PW, PD, TOP - 0.02), (0, 0, 0.04 + (TOP - 0.02) / 2), mat("body")), width=0.02),
        bevel(box("head", (HW, HD, HH), (0, 0, TOP + HH / 2), mat("body")), width=0.03),
        bevel(box("cap", (HW + 0.04, HD + 0.04, 0.035), (0, 0, TOP + HH + 0.0125), mat("trim")), width=0.012, segments=1),
        box("hazard_band", (PW + 0.01, PD + 0.01, 0.06), (0, 0, 0.2), mat("hazard"))]
for sx in (-1, 1):
    for sy in (-1, 1):
        body.append(smooth(cyl(f"bolt{sx}{sy}", 0.018, 0.02, (sx * 0.2, sy * 0.16, 0.055), mat("trim"), 8)))
# the holster: a trim cup on the front face the plug's nose sits in, its mouth 2.5 cm proud of the head
body.append(smooth(cyl("holster_cup", 0.06, 0.05, (HOLSTER[0], FRONT + 0.015, HOLSTER[2]), mat("trim"), 16, rot=(math.pi / 2, 0, 0))))
# where the lead leaves the head: a rubber boot under the front, low on the right
body.append(smooth(cyl("lead_boot", 0.03, 0.06, (0.1, FRONT - 0.04, TOP - 0.02), mat("trim"), 12)))
# the dark lens the status light covers when lit
body.append(box("charge_lens", (0.12, 0.012, 0.05), (-0.08, FRONT + 0.006 - 0.002, TOP + HH - 0.06), mat("trim")))
head = join("charger-col", body)
light = box("charge_light", (0.1, 0.012, 0.04), (-0.08, FRONT + 0.014, TOP + HH - 0.06), mat("light"))

# the plug: a hazard-ringed nose, a grip, a strain-relief boot; its origin on the nose's face, the pin behind it
plug = [smooth(cyl("plug_pin", 0.026, 0.035, (0, -0.0175 + 0.005, 0), mat("metal"), 16, rot=(math.pi / 2, 0, 0))),
        smooth(cyl("plug_ring", 0.045, 0.02, (0, 0.012, 0), mat("hazard"), 16, rot=(math.pi / 2, 0, 0))),
        smooth(bevel(box("plug_grip", (0.07, 0.12, 0.08), (0, 0.08, 0), mat("trim")), width=0.015, segments=2)),
        smooth(cyl("plug_boot", 0.024, 0.07, (0, 0.17, 0), mat("trim"), 12, rot=(math.pi / 2, 0, 0)))]
plug = settle(join("plug", plug), (0, 0, 0))
plug.location = (HOLSTER[0], HOLSTER[1], HOLSTER[2])

empty("holster", HOLSTER, head)
empty("lead_out", (0.1, FRONT - 0.04, TOP - 0.06), head)
port("port_1", (0, -0.32), (0, -PD / 2, 0.45), r=0.03)
done("prop_charger")
