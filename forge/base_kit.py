"""Helpers the base-structure recipes share, on top of shapes.py (which brings in lib).

    import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from base_kit import *

Front convention: a model's front (hatch, label, door) faces Blender +Y, which the glTF export turns
into -Z, the game's yaw-0 front (CONTRACTS.md). lib's "front" preview looks from -Y, so done() shoots
the previews from +Y instead: the picture named front shows the real front.
"""
import json
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
    # feet 5 mm proud of the runners: flush sides flickered (tools/coplanar-check.mjs)
    parts += [box(f"foot{i}", (0.19, 0.19, 0.02), (sx * (w / 2 - 0.09), sy * (d / 2 - 0.09), 0.01), mat("trim"))
              for i, (sx, sy) in enumerate(((-1, -1), (-1, 1), (1, -1), (1, 1)))]
    return parts


def port(name, foot, top=None, r=0.03, size=(0.16, 0.16), turn=0.0):
    """Where a ground cable plugs into a device (world.gd _lay_cables): a conduit from a gland at `top` on the
    device out level to over `foot` (x, y), then down into a gland box on the ground there, and the empty `name`
    inside that box at cable height. The conduit is the riser, so the cable on the ground ends inside the box from
    whichever side its route comes (a cable stopping beside a device read as unplugged, 13 Nov playtest). The box is
    its own `-col` body with the empty as its child, so the empty moves with the model and no join drops it; 9 cm
    tall, the hero steps over it. `turn` (degrees about Z) squares the box to a curved wall."""
    x, y = foot
    if top is not None:
        tx, ty, tz = top
        bend = (x, y, tz)
        d = Vector((x - tx, y - ty, 0))
        d = d.normalized() if d.length > 1e-6 else Vector((0, 0, -1))
        # the gland: a collar on the conduit where it leaves the device, its back 1 cm inside the device's skin.
        # 8-sided, no elbow piece: the level run goes on past the bend by its radius and covers the corner (a
        # habitat is near its triangle budget)
        smooth(bar(name + "_gland", Vector(top) - d * 0.01, Vector(top) + d * 0.05, r + 0.015, mat("trim"), 8))
        if d.z == 0:
            smooth(bar(name + "_conduit_out", top, Vector(bend) + d * r, r, mat("metal"), 8))
        smooth(bar(name + "_conduit", bend, (x, y, 0.08), r, mat("metal"), 8))
    b = bevel(box(name + "_box-col", (size[0], size[1], 0.09), (x, y, 0.045), mat("trim")), width=0.012, segments=1)
    b.rotation_euler.z = math.radians(turn)
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.location = (x, y, 0.02)
    e.parent = b
    bpy.context.view_layer.update()
    e.matrix_parent_inverse = b.matrix_world.inverted()
    return b


def status_light(name, loc, size=(0.16, 0.05, 0.05)):
    """A lamp the game can switch: role `light` on a small dark housing."""
    return [box(name + "_housing", (size[0] + 0.04, size[1], size[2] + 0.04), (loc[0], loc[1] - 0.01, loc[2]), mat("trim")),
            box(name, size, (loc[0], loc[1] + 0.01, loc[2]), mat("light"))]


SHEET = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data", "reality.json")


def row(rid):
    """A value from data/reality.json, the one home of physical numbers (a doorway's size, a bag's)."""
    with open(SHEET) as f:
        return next(r["value"] for r in json.load(f)["rows"] if r["id"] == rid)


def inner_leaf(hw, hh, y_in, z0, extra=()):
    """A hatch leaf on the room side of a frame whose inner face is at y = y_in: it overlaps the opening by
    5 cm at the sides and top like a pressure hatch, and swings inward about its room-side corner. A leaf
    hinged mid-frame cut through the jamb once it opened (a flickering dark line on the open door), and a
    leaf inside the opening showed a dark slit round its edge. `extra` parts join the leaf; returns it."""
    w, t = hw + 0.1, 0.06
    y = y_in - 0.002 - t / 2  # 2 mm behind the frame: close enough to read as sealed, never coplanar
    # the window goes through the leaf: a pane in a solid leaf, over a solid ring, read as a dark disc from both
    # sides (13 Nov playtest); 20 sides, for the building budget. The hole (r 0.135) is a little wider than the pane (r 0.13) so their walls never lie
    # on each other, and the ring's opening (r 0.125) laps the pane's edge, holding it
    ax = (0, y, z0 + 1.55)
    slab = bevel(box("door", (w, t, hh + 0.045), (0, y, z0 + 0.005 + (hh + 0.045) / 2), mat("body")), width=0.02)
    leaf = [cut(slab, cyl("door_hole", 0.135, t + 0.2, ax, None, 20, rot=(math.pi / 2, 0, 0)))]
    leaf.append(smooth(cyl("door_window", 0.13, t + 0.02, ax, mat("glass"), 20, rot=(math.pi / 2, 0, 0))))
    ring = cyl("door_window_ring", 0.17, t + 0.01, ax, mat("trim"), 20, rot=(math.pi / 2, 0, 0))
    leaf.append(cut(ring, cyl("ring_hole", 0.125, t + 0.2, ax, None, 20, rot=(math.pi / 2, 0, 0))))
    leaf.append(smooth(bar("door_handle", (-hw / 2 + 0.12, y + t / 2 + 0.06, z0 + 0.95), (-hw / 2 + 0.12, y + t / 2 + 0.06, z0 + 1.25), 0.02, mat("metal"))))
    leaf += list(extra)
    door = settle(join("door", leaf), (w / 2, y - t / 2, z0))
    # the room side: a painted panel round the window and a handle, as a child named `interior` so it stays clean of
    # the dust coat (DESIGN.md weathering.clean) while the outside face keeps it; dusty, the inside read salmon
    fy = y - t / 2 - 0.005  # 5 mm off the leaf's room face
    zw = z0 + 1.55
    x0, x1, zb, zt = -w / 2 + 0.06, w / 2 - 0.06, z0 + 0.065, z0 + hh - 0.01
    # one plate with a round hole just wider than the outside ring (r 0.17), and a bezel over its edge: a square
    # hole round the round window showed the dusty leaf at its corners (13 Nov first person)
    plate = box("lining", (x1 - x0, 0.003, zt - zb), ((x0 + x1) / 2, fy - 0.0015, (zb + zt) / 2), mat("panel"))
    lining = [cut(plate, cyl("lining_hole", 0.175, 0.1, (0, fy, zw), None, 20, rot=(math.pi / 2, 0, 0)))]
    # its back 1.5 mm into the plate and 1.5 mm off the plate's back (1 mm off, coplanar-check's tolerance, failed it
    # by rounding in one building and not another), its opening wider than the pane (r 0.13), so no face lies on another
    bezel = cyl("window_bezel", 0.21, 0.012, (0, fy - 0.0075, zw), mat("trim"), 20, rot=(math.pi / 2, 0, 0))
    lining.append(smooth(cut(bezel, cyl("bezel_in", 0.135, 0.1, (0, fy, zw), None, 20, rot=(math.pi / 2, 0, 0)))))
    lining.append(smooth(bar("inner_handle", (-hw / 2 + 0.12, fy - 0.06, z0 + 0.95), (-hw / 2 + 0.12, fy - 0.06, z0 + 1.25), 0.02, mat("metal"))))
    lining = join("interior", lining)
    bpy.context.view_layer.update()
    mw = lining.matrix_world.copy()
    lining.parent = door
    lining.matrix_world = mw
    return door


COL = ("-col", "-convcol", "-colonly", "-convcolonly")


def moves(o):
    """Parts the game moves get their own bodies in the engine, so they carry no collision suffix; their children
    move with them."""
    return o.name in ("door", "dish", "tell", "curtain", "plug", "charge_light") or o.name.startswith("panel_") or (o.parent is not None and moves(o.parent))


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
