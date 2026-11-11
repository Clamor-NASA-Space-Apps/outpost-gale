"""Helpers the base-structure recipes share, on top of shapes.py (which brings in lib).

    import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from base_kit import *

Front convention: a model's front (hatch, label, door) faces Blender +Y, which the glTF export turns
into -Z, the game's yaw-0 front (CONTRACTS.md). lib's "front" preview looks from -Y, so done() shoots
the previews from +Y instead: the picture named front shows the real front.
"""
import math
import os

from shapes import *  # noqa: F401,F403  (lib too)
from shapes import bar, join, prism, settle  # noqa: F401
import lib
from lib import box, cyl, mat, render_views  # noqa: F401


# Exo 2 (OFL), the HUD's number font: 1, l and I differ and 0 is narrower than O, which a kid reading
# "HAB 1" or "O2" needs. shapes.label() uses Blender's built-in font, so this repeats its few lines.
EXO2 = os.path.join(os.path.dirname(os.path.abspath(__file__)), *[".."] * 4, "assets-cache", "fonts", "exo-2", "Exo2[wght].ttf")


def flat_label(name, text, size, loc, role="trim", depth=0.012, facing=0.0, bold=0.02):
    """Raised lettering standing up, readable from +Y (the front); `facing` turns it about Z in degrees."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body, cu.size, cu.extrude, cu.resolution_u, cu.offset = text, size, depth, 2, bold * size
    cu.align_x, cu.align_y = "CENTER", "CENTER"
    cu.font = bpy.data.fonts.load(EXO2, check_existing=True)
    o = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(o)
    o.location, o.rotation_euler = loc, (math.pi / 2, 0, math.pi + math.radians(facing))
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.object
    o.data.materials.append(mat(role))
    o.select_set(False)
    return o


def wrap(o, radius, ang_deg, z):
    """Bend upright lettering made at the origin onto a vertical cylinder wall: its centre lands at
    angle `ang_deg` (0 = +X, 90 = +Y, the front) and height z, readable from outside."""
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.select_set(False)
    for v in o.data.vertices:
        x, y, zz = v.co
        a, r = x / radius, radius - y
        v.co = (r * math.sin(a), -r * math.cos(a), zz + z)
    o.rotation_euler = (0, 0, math.radians(ang_deg + 90))
    return o


def at(r, ang_deg, z):
    """A point on a circle of radius r at angle ang_deg (0 = +X, 90 = +Y), height z."""
    a = math.radians(ang_deg)
    return (r * math.cos(a), r * math.sin(a), z)


def skid(w, d, h=0.12, role="metal"):
    """The steel skid a machine ships on: two runners, cross members, four foot plates."""
    parts = [bevel(box(f"runner{s}", (w, 0.1, h), (0, s * (d / 2 - 0.05), h / 2), mat(role))) for s in (-1, 1)]
    parts += [box(f"cross{i}", (0.08, d - 0.2, h * 0.6), (x, 0, h * 0.5), mat(role)) for i, x in enumerate((-w / 2 + 0.1, 0, w / 2 - 0.1))]
    parts += [box(f"foot{i}", (0.18, 0.18, 0.02), (sx * (w / 2 - 0.09), sy * (d / 2 - 0.09), 0.01), mat("trim"))
              for i, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
    return parts


def status_light(name, loc, size=(0.16, 0.05, 0.05)):
    """A lamp the game can switch: role `light` on a small dark housing."""
    return [box(name + "_housing", (size[0] + 0.04, size[1], size[2] + 0.04), (loc[0], loc[1] - 0.01, loc[2]), mat("trim")),
            box(name, size, (loc[0], loc[1] + 0.01, loc[2]), mat("light"))]


COL = ("-col", "-convcol", "-colonly", "-convcolonly")


def moves(o):
    """Parts the game moves get their own bodies in the engine, so they carry no collision suffix."""
    return o.name in ("door", "dish") or o.name.startswith("panel_")


def done(name, solid=True):
    """finish() without the centring: the recipe's own origin stays (the drum's centre, not the centre
    of a box that a ramp or a pipe stretches), only the lowest point goes to z=0. With `solid`, every
    part not already named for collision and not moving joins one `detail-col` node, so whatever is
    drawn is also hit: bands, signs, pipes and ladders stuck out past the walls' collision. The three
    previews are shot from the model's real front (+Y)."""
    rest = [o for o in lib._meshes() if not o.name.endswith(COL) and not moves(o)]
    if solid and rest:
        join("detail-col", rest)
    lo, _ = lib._bounds()
    for o in lib._meshes():
        if o.parent is None:
            o.location.z -= lo.z
    print("FORGE_DONE", lib.export_glb(name))
    if not os.environ.get("FORGE_NO_RENDER"):
        shots = render_views(name, {"front": (-0.35, 1, 0.45), "side": (1, -0.25, 0.4), "top": (0.001, 0.001, 1)})
        print("FORGE_PREVIEWS", *shots)
