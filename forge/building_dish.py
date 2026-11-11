# The comms dish: a 3 m parabolic reflector (data/reality.json dish.diameter) on a pedestal with an
# azimuth turret and an elevation yoke. The reflector, its feed and counterweight are one node, `dish`,
# with its origin on the elevation axis (X): rotating it about X tilts the dish. It rests at 40 degrees
# above the horizon, facing the front.
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base_kit import *  # noqa: E402,F403

R, F, AX, EL = 1.5, 1.05, 1.95, 40   # rim radius, focal length (f/D 0.35), axis height, rest elevation
reset()

# reflector: a parabola z = r^2 / 4F turned about its axis, then given thickness
prof = [(R * i / 10, 0, (R * i / 10) ** 2 / (4 * F)) for i in range(11)]
me = bpy.data.meshes.new("reflector")
me.from_pydata(prof, [(i, i + 1) for i in range(10)], [])
refl = bpy.data.objects.new("reflector", me)
bpy.context.scene.collection.objects.link(refl)
refl.modifiers.new("lathe", "SCREW").steps = 40
refl.modifiers["lathe"].render_steps = 40
refl.modifiers.new("thick", "SOLIDIFY").thickness = 0.04
refl.data.materials.append(mat("body"))
smooth(refl)
parts = [refl]
parts.append(smooth(cyl("rim", R + 0.02, 0.06, (0, 0, R * R / (4 * F)), mat("trim"), 40)))
cut(parts[-1], cyl("rim_in", R - 0.03, 0.2, (0, 0, R * R / (4 * F)), None, 40))
parts.append(smooth(cyl("hub", 0.32, 0.3, (0, 0, -0.17), mat("trim"), 24)))
for k in range(4):  # feed struts from the rim to the feed horn at the focus
    a = math.radians(45 + 90 * k)
    parts.append(smooth(bar(f"strut{k}", (0.9 * R * math.cos(a), 0.9 * R * math.sin(a), (0.9 * R) ** 2 / (4 * F)), (0, 0, F - 0.1), 0.02, mat("metal"))))
parts.append(smooth(cyl("feed", 0.09, 0.28, (0, 0, F), mat("trim"), 16)))
parts.append(smooth(cone("feed_horn", 0.12, 0.12, (0, 0, F - 0.25), mat("metal"), 16, rot=(math.pi, 0, 0))))
parts.append(bevel(box("counterweight", (0.4, 0.25, 0.3), (0, 0, -0.45), mat("trim")), width=0.02))
d = join("dish", parts)
d.location.z = AX + 0.12  # the hub's back sits on the axis block
settle(d, (0, 0, AX))
d.rotation_euler.x = -math.radians(90 - EL)  # from pointing up to EL above the horizon, toward +Y

# mount: base plate on feet, pedestal, turret, yoke arms with bearings on the elevation axis
mount = [bevel(box("base", (1.3, 1.3, 0.12), (0, 0, 0.06), mat("trim")), width=0.02)]
for sx in (-1, 1):
    for sy in (-1, 1):
        mount.append(box(f"foot{sx}{sy}", (0.25, 0.25, 0.04), (sx * 0.6, sy * 0.6, 0.02), mat("metal")))
        mount.append(bar(f"stay{sx}{sy}", (sx * 0.55, sy * 0.55, 0.12), (sx * 0.12, sy * 0.12, 0.9), 0.025, mat("metal")))
mount.append(smooth(cyl("pedestal", 0.2, 1.35, (0, 0, 0.12 + 0.675), mat("body"), 24)))
mount.append(smooth(cyl("turret", 0.32, 0.22, (0, 0, 1.55), mat("trim"), 24)))
mount.append(bevel(box("yoke_base", (1.0, 0.3, 0.12), (0, 0, 1.7), mat("metal")), width=0.02))
for s in (-1, 1):
    mount.append(bevel(box(f"yoke{s}", (0.1, 0.25, 0.42), (s * 0.45, 0, AX - 0.12), mat("metal")), width=0.02))
    mount.append(smooth(cyl(f"bearing{s}", 0.1, 0.12, (s * 0.45, 0, AX), mat("trim"), 16, rot=(0, math.pi / 2, 0))))
join("mount-col", mount)
bevel(box("drive_box", (0.3, 0.25, 0.3), (0, -0.3, 0.6), mat("body")), width=0.02)
status_light("dish_light", (0, -0.17, 0.68), (0.14, 0.04, 0.05))
done("building_dish")
