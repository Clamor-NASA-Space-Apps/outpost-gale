# The storm shelter fitted out for its crew of 2 (13 Nov playtest: "just some textures", no room inside). A kid who
# walks in sees, in this order: two stacked bunks against the back wall (where the crew lie out a storm, up to 24 h:
# NASA Orion, design/research/pages/shelter/nasa-orion-shelter.html), water and food on a rack at their foot
# (the walls are those bags too: Orion builds its shelter from "stowage bags ... food and water"), on the left wall
# a comms screen with signal bars and a radiation sign over a glowing meter (a prop: no numbers), a light in the
# ceiling, and the aluminium frame posts the bag walls hang on (RadWorks' group shelter: "a frame of aluminum ...
# an attachment structure for large panels of CTBs", NTRS 20170002287). Water bags are Contingency Water Containers
# as in HAB 1 (forge/hab_interior.py).
#
# Built in the room's own space: x across (the inside faces at +-IX/2), y from the back wall (-IY/2) to the front
# (+IY/2, the door), z up from the floor top F to the ceiling C. Every part stays 5 mm or more off the bags' faces.
from base_kit import *  # noqa: F403
from hab_interior import CWC, U, _b, _bar

import bmesh


def _flat(name, polys, x, role):
    """Flat shapes on a wall facing +x at `x`: `polys` are outlines of (y, z) points, counter-clockwise seen from +x."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    for p in polys:
        bm.faces.new([bm.verts.new((x, y, z)) for y, z in p])
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat(role))
    return o


def _trefoil(name, y, z, r, x, role):
    """The radiation sign: a disc and three blades (inner radius 1.5 and outer 5 times the disc's, 60 degrees wide),
    one pointing down, as the international symbol draws it."""
    def arc(rad, a0, a1, n):
        return [(y + rad * math.cos(math.radians(a0 + (a1 - a0) * i / n)), z + rad * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]
    disc = arc(r, 0, 360, 16)[:-1]
    blades = [arc(5 * r, a - 30, a + 30, 6) + arc(1.5 * r, a + 30, a - 30, 3) for a in (30, 150, 270)]
    return _flat(name, [disc] + blades, x, role)


def fit_out(IX, IY, F, C):
    """Returns (parts for interior-col, light parts that stay out of it)."""
    loose = []
    z0 = F + 0.002  # 2 mm off the deck
    wx, wy = IX / 2 - 0.005, IY / 2 - 0.005  # 5 mm in from the bags' inside faces

    # two bunks against the back wall, 2.0 m long, heads at the left wall by the radiation meter
    L, D = 2.0, 0.8
    x0, x1, y0 = -wx, -wx + L, -wy
    cx, cy = (x0 + x1) / 2, y0 + D / 2
    _b("bunk_base", (L - 0.04, D - 0.02, 0.32), (cx, cy, z0 + 0.16), "panel", 0.01)  # closed: stowage
    _b("bunk_plate", (L - 0.04, D - 0.02, 0.03), (cx, cy, z0 + 1.32), "panel", 0.006)
    _b("bunk_end", (0.03, D - 0.02, 1.78), (x1 - 0.015, cy, z0 + 0.89), "panel", 0.006)  # the foot, beside the rack
    # 0.88 m from the lower mattress to the plate: an adult sits up in bed (HAB 1's berths, forge/hab_interior.py)
    for k, top in enumerate((0.32, 1.335)):
        z = z0 + top
        # a dark mattress, so the white pillow and the blue sleeping bag show on it (HAB 1's berths)
        _b(f"mattress{k}", (L - 0.1, D - 0.08, 0.1), (cx - 0.01, cy, z + 0.047), "trim", 0.035, 2)
        _b(f"sleeping_bag{k}", (L - 0.56, D - 0.16, 0.07), (cx + 0.2, cy, z + 0.115), "bedding", 0.03)
        fold = _b(f"bag_fold{k}", (0.22, D - 0.16, 0.03), (x0 + 0.62, cy, z + 0.16), "bedding", 0.012)  # the top turned back
        fold.rotation_euler.y = math.radians(12)
        _b(f"pillow{k}", (0.34, D - 0.28, 0.09), (x0 + 0.27, cy, z + 0.13), "suit", 0.04, 2)
    for s, x in ((0, x0 + 0.03), (1, x1 - 0.06)):  # front posts of the frame
        _bar(f"bunk_post{s}", (x, y0 + D + 0.005, z0), (x, y0 + D + 0.005, z0 + 1.8), 0.02, "metal")
    _bar("bunk_rail", (x0 + 0.03, y0 + D + 0.005, z0 + 1.6), (x1 - 0.5, y0 + D + 0.005, z0 + 1.6), 0.015, "metal")
    lx = x1 - 0.3  # the ladder to the upper bunk, at the foot end
    for s in (-1, 1):
        _bar(f"ladder_rail{s}", (lx + s * 0.16, y0 + D + 0.03, z0), (lx + s * 0.16, y0 + D + 0.03, z0 + 1.34), 0.015, "metal")
    for i in range(3):
        _bar(f"ladder_rung{i}", (lx - 0.16, y0 + D + 0.03, z0 + 0.42 + i * 0.3), (lx + 0.16, y0 + D + 0.03, z0 + 0.42 + i * 0.3), 0.012, "metal")

    # water and food on a rack at the bunks' foot, in reach from both
    rx0, ry1 = x1 + 0.03, y0 + 0.5
    rcx, rcy, rw, rd = (rx0 + wx) / 2, (y0 + ry1) / 2, wx - rx0, ry1 - y0
    for sx in (-1, 1):
        for sy in (-1, 1):
            _bar(f"rack_post{sx}{sy}", (rcx + sx * (rw / 2 - 0.02), rcy + sy * (rd / 2 - 0.02), z0), (rcx + sx * (rw / 2 - 0.02), rcy + sy * (rd / 2 - 0.02), z0 + 1.62), 0.015, "metal")
    shelves = (0.06, 0.6, 1.14, 1.6)
    for i, h in enumerate(shelves):
        _b(f"rack_shelf{i}", (rw, rd, 0.02), (rcx, rcy, z0 + h), "panel", 0.004)
    for i in (0, 1):  # a full water bag lying on each low shelf, its carry strap round the middle (HAB 1's _cwc, one bevel step)
        at_ = (rcx, rcy, z0 + shelves[i] + 0.01 + CWC[2] / 2 + 0.003)
        _b(f"rack_cwc{i}", (CWC[1], CWC[0] - 0.005, CWC[2]), at_, "suit", 0.06)
        _b(f"rack_strap{i}", (CWC[1] + 0.006, 0.04, CWC[2] - 0.02), at_, "trim")
    for i, (dx, dz) in enumerate(((-0.1, 0), (0.1, 0), (-0.1, 0.045), (0.1, 0.045))):  # foil food pouches, two stacks
        _b(f"food{i}", (0.17, 0.3, 0.04), (rcx + dx, rcy, z0 + shelves[2] + 0.033 + dz), "metal", 0.012)
    for i, word in ((1, "WATER"), (2, "FOOD")):  # dark words on yellow tags, as the radiation sign: glowing, they faded by day
        _b(f"rack_sign{i}", (0.3, 0.012, 0.07), (rcx, ry1 + 0.008, z0 + shelves[i] - 0.05), "hazard", 0.003)
        U.append(flat_label(f"rack_word{i}", word, 0.045, (rcx, ry1 + 0.0155, z0 + shelves[i] - 0.05), "trim", 0, 0, 0))

    # the left wall: comms screen and signal bars, the radiation sign over its meter
    wl = -wx
    _b("comms", (0.05, 0.76, 0.46), (wl + 0.025, 0.55, z0 + 1.5), "trim", 0.01)
    _b("comms_screen", (0.008, 0.5, 0.32), (wl + 0.056, 0.47, z0 + 1.5), "glass")
    for i, h in enumerate((0.06, 0.1, 0.14)):  # signal bars: the link home is up
        loose.append(box(f"comms_bar{i}", (0.008, 0.035, h), (wl + 0.056, 0.79 + i * 0.05, z0 + 1.36 + h / 2), mat("light")))
    # one word over the sign: the bars and the screen say comms without one (the building's triangle budget). Dark on
    # the sign's yellow: in glowing cyan on a dark tag it read at night and vanished by day (13 Nov captures)
    _b("rad_tag", (0.012, 0.42, 0.1), (wl + 0.006, -0.12, z0 + 1.83), "hazard", 0.003)
    U.append(flat_label("rad_word", "RADIATION", 0.05, (wl + 0.0135, -0.12, z0 + 1.83), "trim", 0, -90, 0))  # readable from +x, the room
    _b("rad_plate", (0.012, 0.3, 0.3), (wl + 0.006, -0.12, z0 + 1.58), "hazard", 0.004)
    U.append(_trefoil("rad_sign", -0.12, z0 + 1.58, 0.022, wl + 0.014, "trim"))
    _b("rad_meter", (0.03, 0.3, 0.12), (wl + 0.015, -0.12, z0 + 1.33), "trim", 0.006)
    for i in range(5):  # a meter that reads low: three segments lit, two dark
        seg = box(f"rad_seg{i}", (0.006, 0.04, 0.07), (wl + 0.031, -0.23 + i * 0.055, z0 + 1.33), mat("light" if i < 3 else "trim"))
        (loose if i < 3 else U).append(seg)

    # the sign over the bunks, the ceiling light, the frame's front posts
    _b("shelter_sign", (1.3, 0.012, 0.17), (cx, y0 + 0.006, z0 + 2.17), "trim", 0.004)
    loose.append(flat_label("shelter_word", "STORM SHELTER", 0.1, (cx, y0 + 0.0135, z0 + 2.17), "light", 0, 0, 0))
    _b("light_housing", (0.9, 0.26, 0.03), (0, 0.1, C - 0.012), "trim")  # its top 3 mm into the roof deck
    loose.append(box("ceiling_light", (0.84, 0.2, 0.012), (0, 0.1, C - 0.031), mat("light")))
    for s in (-1, 1):
        _b(f"frame_post{s}", (0.05, 0.05, C - F + 0.03), (s * (wx - 0.025), wy - 0.025, (F - 0.02 + C + 0.01) / 2), "metal")  # ends in the deck and the roof
    # the ceiling: one white face 5 mm under the deck, so the room light reaches it (the deck is outside's layer)
    me = bpy.data.meshes.new("ceiling")
    me.from_pydata([(-wx, -wy, C - 0.005), (-wx, wy, C - 0.005), (wx, wy, C - 0.005), (wx, -wy, C - 0.005)], [], [(0, 1, 2, 3)])
    o = bpy.data.objects.new("ceiling", me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat("panel"))
    U.append(o)
    return U, loose


def floor(IX, IY, F, front, door_w):
    """The deck: 60 cm plates in the `deck` role, top at F, out through the doorway (`door_w` wide) to `front`, with
    dark joint strips 3 mm proud (never flush)."""
    wx, wy = IX / 2 - 0.003, IY / 2 - 0.003
    d = box("floor", (2 * wx, front + wy, F), (0, (front - wy) / 2, F / 2), mat("deck"))
    for s in (-1, 1):  # the doorway strip only past the room
        cut(d, box("floor_cut", (wx, 1.0, 1.0), (s * (door_w / 2 + wx / 2 + 0.003), IY / 2 + 0.5, F / 2)))
    U.append(d)
    for k, g in enumerate((-0.9, -0.3, 0.3, 0.9)):
        U.append(box(f"joint_x{k}", (0.008, 2 * wy, 0.008), (g, 0, F - 0.001), mat("trim")))
    for k, g in enumerate((-0.65, -0.05, 0.55)):
        U.append(box(f"joint_y{k}", (2 * wx, 0.008, 0.008), (0, g, F - 0.001), mat("trim")))
    return d
