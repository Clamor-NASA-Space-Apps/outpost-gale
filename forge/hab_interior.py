# HAB 1 fitted out for a crew of 2, seen in first person from 1.6 m (Ravindu's playtest, 12 Nov 2026: "as accurate
# as possible", "clean", "space inside"). Laid out like NASA's Habitat Demonstration Unit, a 5 m drum split into 8
# wedge sections (NTRS 20110013501): every unit stands against the curved wall, and the middle stays open, about
# 2.8 m across at its narrowest (hero.width is 0.95 m).
#   0 deg galley with the Veggie unit under a window   33 desk with the Gale map   56 air valves   90 hatch
#   140 the donning corner (bench, hooks, helmet shelf, boot mat), a suit brush by the hatch   177 toilet cubicle
#   214 two sleep stations, stacked   250 window   275, 302 life-support racks (air, water)   328 window
# Sleep stations after the ISS crew quarters (NTRS 20100017014: "~2.1 m3", "white interior acoustic blankets", a
# laptop table, a light), turned into beds you lie on in 0.38 g. The storm-shelter water is real NASA soft water
# bags, Contingency Water Containers: 44 L each (SAE 2002-01-2532), Nomex outer bags about 19 x 16 in when full
# (48 x 41 cm; goflight.space, reported): 8 standing in a padded row along each bed's wall side, 352 L
# (NASA rates a water wall round the crew quarters the best storm shelter, NTRS 20170002287).
#
# Drawn parts join one `interior-col` node: one collision body, and DESIGN.md `weathering.clean` keeps a swept
# room free of the dust coat. Parts in roles that take no coat (light, visor) stay out of it, so they share the
# outside's materials and cost no draw call of their own. Slots: world.json `plants` fills slot_1 (Veggie) and
# slot_2 (Gale map). Surfaces: soft goods in `suit` (the suit's own Nomex cloth), cabinets in `panel`, the bags in `bedding`.
import os

import bmesh
from mathutils import Matrix

from base_kit import *  # noqa: F403

U = []  # parts that join interior-col
# Rack faces from NASA's ISS interior model (Node 3 racks; NASA 3D Resources, no copyright), cropped into one
# atlas, its mission patch left out of the crop: one material (`iss_panels`, a DESIGN.md kit `keep`)
ISS = os.path.join(os.path.dirname(os.path.abspath(__file__)), *[".."] * 4, "assets-cache", "nasa-3d", "iss-internal", "parts")
GRILLES, PANELS = 0, 1  # atlas tiles, left to right, a quarter of its width each
CWC = (0.48, 0.41, 0.24)  # a full Contingency Water Container lying flat: length, width, thickness (44 L)


def _iss():
    m = bpy.data.materials.get("iss_panels")
    if m:
        return m
    m = bpy.data.materials.new("iss_panels")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.6
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(os.path.join(ISS, "iss_panels_albedo.png"))
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nrm = nt.nodes.new("ShaderNodeTexImage")
    nrm.image = bpy.data.images.load(os.path.join(ISS, "iss_panels_normal.png"))
    try:
        nrm.image.colorspace_settings.name = "Non-Color"
    except TypeError:
        pass  # the distro build's colour config fails to load (tooling/AGENTS.md gotchas); the exporter still writes it as a normal map
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nrm.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def _face(name, w, h, at_, tile):
    """A textured quad facing -x (a unit's front), `w` along y, `h` tall, centred at `at_`, showing atlas `tile`."""
    me = bpy.data.meshes.new(name)
    x, y, z = at_
    me.from_pydata([(x, y + w / 2, z - h / 2), (x, y - w / 2, z - h / 2), (x, y - w / 2, z + h / 2), (x, y + w / 2, z + h / 2)], [], [(0, 1, 2, 3)])
    uv = me.uv_layers.new()
    u0 = tile * 0.25
    for loop, (u, v) in zip(me.loops, ((u0, 0), (u0 + 0.25, 0), (u0 + 0.25, 1), (u0, 1))):
        uv.data[loop.index].uv = (u, v)
    me.update()
    if me.polygons[0].normal.x > 0:
        me.flip_normals()
    me.materials.append(_iss())
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    U.append(o)
    return o


def _b(name, size, at_, role, bev=0.0, seg=1):
    o = box(name, size, at_, mat(role))
    if bev:
        bevel(o, width=bev, segments=seg)
    U.append(o)
    return o


def _c(name, r, h, at_, role, verts=12, rot=(0, 0, 0)):
    o = smooth(cyl(name, r, h, at_, mat(role), verts, rot))
    U.append(o)
    return o


def _bar(name, p0, p1, r, role):
    o = smooth(bar(name, p0, p1, r, mat(role)))
    U.append(o)
    return o


def _curtain(name, w, h, x, y, z, folds=6, depth=0.025):
    """A hanging fabric curtain in the `suit` role: `w` along y from y, `h` down from z, folds in x about x."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    n = folds * 3
    cols = [[bm.verts.new((x + depth / 2 * math.sin(i / n * folds * 2 * math.pi), y + w * i / n, z - h * k)) for k in (0, 1)] for i in range(n + 1)]
    for i in range(n):
        bm.faces.new((cols[i][0], cols[i][1], cols[i + 1][1], cols[i + 1][0]))
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat("suit"))
    o.modifiers.new("t", "SOLIDIFY").thickness = 0.008
    U.append(smooth(o, 60))
    return o


def _cwc(name, at_, along_y=True):
    """One water bag lying flat: a soft white Nomex pillow with its dark carry strap round the middle."""
    L, W, T = CWC
    size = (W, L - 0.005, T) if along_y else (L - 0.005, W, T)
    _b(name, size, at_, "suit", 0.06, 2)
    strap = (W + 0.006, 0.04, T - 0.02) if along_y else (0.04, W + 0.006, T - 0.02)
    _b(name + "_strap", strap, at_, "trim")


def _mount(parts, ang, w, ri):
    """Parts built with their back on local x = 0, front toward -x, width along y, onto the wall chord at
    `ang` degrees: the back plane goes as far out as its corners allow inside the wall's inner radius."""
    rb = math.sqrt((ri - 0.03) ** 2 - (w / 2) ** 2)
    bpy.context.view_layer.update()  # bar() sets its rotation after placing: matrix_world is stale until now
    a = math.radians(ang)
    for o in parts:
        o.matrix_world = Matrix.Rotation(a, 4, "Z") @ Matrix.Translation((rb, 0, 0)) @ o.matrix_world
    return parts


def _slot(name, at_, ang):
    """An empty world.json `plants` fills, its front (+y) turned into the room from wall angle `ang`."""
    s = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(s)
    s.location, s.rotation_euler = at_, (0, 0, math.radians(ang + 90))
    return s


def fit_out(F, RI, CEIL):
    """F floor top, RI the wall's inner radius, CEIL the flat ceiling. Returns (interior parts, loose parts, slots)."""
    z0 = F + 0.002  # 2 mm off the deck: a face on the deck's face flickers (tools/coplanar-check.mjs)
    loose = []      # light and visor parts: no coat, so they stay out of interior-col
    slots = []

    def unit(build, ang, w):
        n0, l0 = len(U), len(loose)
        made = build()
        _mount(U[n0:] + loose[l0:] + list(made or []), ang, w, RI)

    def rack(label_text, kind):  # an ISS-size rack: 1.05 m wide, 2.0 m tall
        W, D, H = 1.05, 0.7, 2.0
        xf = -D + 0.01  # front face
        _b(f"{kind}_cabinet", (D - 0.02, W, H), (-D / 2, 0, z0 + H / 2), "panel", 0.02)
        _face(f"{kind}_face", W - 0.06, 1.72, (xf - 0.004, 0, z0 + 0.96), GRILLES if kind == "co2" else PANELS)
        _b(f"{kind}_sign", (0.02, 0.5, 0.16), (xf - 0.005, 0, z0 + H - 0.14), "trim")
        U.append(flat_label(f"{kind}_label", label_text, 0.11, (xf - 0.021, 0, z0 + H - 0.14), "body", 0, 90, 0))
        loose.append(box(f"{kind}_lamp", (0.012, 0.3, 0.03), (xf - 0.012, 0, z0 + H - 0.3), mat("light")))
        if kind == "co2":  # two amine beds, swapped between soaking up CO2 and venting it outside
            for s in (-1, 1):
                _c(f"co2_bed{s}", 0.13, 0.62, (xf - 0.03, s * 0.24, z0 + 1.32), "glass", 12)
                for dz in (-0.33, 0.33):
                    _c(f"co2_cap{s}{dz}", 0.145, 0.05, (xf - 0.03, s * 0.24, z0 + 1.32 + dz), "metal", 12)
            _c("co2_fan", 0.12, 0.03, (xf - 0.005, 0, z0 + 0.86), "trim", 12, rot=(0, math.pi / 2, 0))
        else:  # water processor: three filter beds, a clean-water sight glass, a gauge
            for i in range(3):
                _c(f"h2o_filter{i}", 0.05, 0.42, (xf - 0.03, -0.3 + i * 0.13, z0 + 1.3), "glass", 10)
                _c(f"h2o_fcap{i}", 0.06, 0.05, (xf - 0.03, -0.3 + i * 0.13, z0 + 1.53), "metal", 10)
            _b("h2o_sight", (0.02, 0.1, 0.5), (xf - 0.01, 0.3, z0 + 1.3), "glass")
            _c("h2o_gauge", 0.07, 0.03, (xf - 0.01, 0.3, z0 + 0.96), "trim", 12, rot=(0, math.pi / 2, 0))
            _c("h2o_gauge_glass", 0.055, 0.03, (xf - 0.02, 0.3, z0 + 0.96), "glass", 12, rot=(0, math.pi / 2, 0))
    unit(lambda: rack("AIR", "co2"), 275, 1.05)
    unit(lambda: rack("WATER", "h2o"), 302, 1.05)

    def valves():  # where the O2 and N2 lines from the bottle skid come through the wall
        _b("valve_panel", (0.06, 0.4, 0.5), (-0.03, 0, z0 + 1.25), "trim", 0.01)
        for s in (-1, 1):
            _c(f"valve{s}", 0.05, 0.04, (-0.08, s * 0.1, z0 + 1.32), "metal", 12, rot=(0, math.pi / 2, 0))
        U.append(flat_label("valve_label", "AIR IN", 0.06, (-0.066, 0, z0 + 1.12), "body", 0, 90, 0))
    unit(valves, 56, 0.4)

    def berths():  # two stacked, 2.0 m long; each about 2.0 x 1.0 x 0.8 m inside, like the ISS crew quarters
        W, D = 2.0, 1.0
        BASE, MID, ROOF = 0.30, 1.1, 1.98  # the lower bed's base top, the upper bed's plate, the roof plate
        cx = -D / 2
        _b("berth_back", (0.03, W, ROOF + 0.02), (-0.03, 0, z0 + (ROOF + 0.02) / 2), "suit")  # fabric on the wall side
        for s in (-1, 1):  # head and foot walls, soft white blankets on a frame
            _b(f"berth_end{s}", (D - 0.04, 0.03, ROOF + 0.02), (cx - 0.01, s * (W / 2 - 0.015), z0 + (ROOF + 0.02) / 2), "suit", 0.01)
            _bar(f"berth_post{s}", (-D + 0.02, s * (W / 2 - 0.015), z0), (-D + 0.02, s * (W / 2 - 0.015), z0 + ROOF + 0.02), 0.022, "metal")
        _b("berth_base", (D - 0.06, W - 0.06, BASE), (cx - 0.01, 0, z0 + BASE / 2), "panel", 0.01)  # a closed base: stowage
        _b("berth_roof", (D - 0.04, W - 0.06, 0.03), (cx - 0.01, 0, z0 + ROOF + 0.005), "panel")
        for k, zb in enumerate((BASE, MID)):
            if k:
                _b("berth_plate1", (D - 0.06, W - 0.06, 0.03), (cx - 0.01, 0, z0 + zb + 0.015), "panel")
            top = zb + 0.03 if k else zb
            # the storm wall: four full water bags (Contingency Water Containers) standing in a padded row along the
            # wall side, tidy as a headboard; the mattress lies in front of them
            for i, y in enumerate((-0.72, -0.24, 0.24, 0.72)):
                _b(f"cwc{k}{i}", (CWC[2], CWC[0] - 0.006, CWC[1]), (-0.05 - CWC[2] / 2, y, z0 + top + CWC[1] / 2 + 0.003), "suit", 0.07, 2)
            mx = (-0.05 - CWC[2] - D + 0.06) / 2  # the mattress between the bags and the front
            mw = D - 0.06 - 0.05 - CWC[2]
            _b(f"mattress{k}", (mw, W - 0.1, 0.1), (mx, 0, z0 + top + 0.047), "suit", 0.035, 2)  # 3 mm into its base
            _b(f"sleeping_bag{k}", (mw - 0.08, W - 0.5, 0.07), (mx, 0.2, z0 + top + 0.115), "bedding", 0.03, 2)
            fold = _b(f"bag_fold{k}", (mw - 0.08, 0.22, 0.03), (mx, -0.43, z0 + top + 0.16), "bedding", 0.012, 2)  # the top turned back
            fold.rotation_euler.x = math.radians(-12)
            _b(f"pillow{k}", (mw - 0.22, 0.32, 0.09), (mx, -W / 2 + 0.24, z0 + top + 0.13), "suit", 0.04, 2)
            # head end: a reading light in its housing, a shelf on two brackets with a tablet and a photo on it
            hz = z0 + top + 0.5
            _b(f"reading_housing{k}", (0.18, 0.03, 0.07), (mx, -W / 2 + 0.042, hz + 0.05), "trim", 0.008)
            loose.append(box(f"reading_light{k}", (0.14, 0.012, 0.03), (mx, -W / 2 + 0.06, hz + 0.04), mat("light")))
            _b(f"shelf{k}", (0.34, 0.16, 0.02), (mx - 0.05, -W / 2 + 0.105, hz - 0.12), "panel", 0.004)
            for bx in (-0.13, 0.13):
                _b(f"bracket{k}{bx}", (0.015, 0.12, 0.06), (mx - 0.05 + bx, -W / 2 + 0.085, hz - 0.155), "metal")
            tab = _b(f"tablet{k}", (0.2, 0.012, 0.14), (mx - 0.1, -W / 2 + 0.07, hz - 0.04), "trim", 0.004)
            tab.rotation_euler.x = math.radians(-15)
            scr = box(f"tablet_screen{k}", (0.17, 0.004, 0.11), (mx - 0.1, -W / 2 + 0.078, hz - 0.04), mat("glass"))
            scr.rotation_euler.x = math.radians(-15)
            U.append(scr)
            _b(f"photo{k}", (0.1, 0.015, 0.13), (mx + 0.06, -W / 2 + 0.07, hz - 0.047), "trim", 0.003)
            U.append(box(f"photo_print{k}", (0.08, 0.004, 0.1), (mx + 0.06, -W / 2 + 0.079, hz - 0.047), mat("hazard")))  # a warm print
            # a curtain on a rail across the front, drawn back to the foot end
            _bar(f"curtain_rail{k}", (-D + 0.01, -W / 2 + 0.02, z0 + top + 0.76), (-D + 0.01, W / 2 - 0.02, z0 + top + 0.76), 0.01, "metal")
            _curtain(f"curtain{k}", 0.5, 0.66, -D + 0.035, W / 2 - 0.55, z0 + top + 0.74, 5)
        for s in (-1, 1):  # ladder to the upper bed, at the foot end
            _bar(f"ladder_rail{s}", (-D - 0.02, 0.62 + s * 0.17, z0), (-D - 0.02, 0.62 + s * 0.17, z0 + MID + 0.03), 0.015, "metal")
        for i in range(3):
            _bar(f"ladder_rung{i}", (-D - 0.02, 0.45, z0 + 0.32 + i * 0.27), (-D - 0.02, 0.79, z0 + 0.32 + i * 0.27), 0.012, "metal")
    unit(berths, 214, 2.0)

    def toilet():  # a cubicle with a door left half open on NASA's UWMS toilet: a small seat, and the urine hose with its
        # funnel in a cradle (Space.com 2020, "a urine funnel and seat", "the urine hose ... cradled"); urine is stored
        W, D, H = 0.9, 0.9, 2.05
        DW = 0.62  # doorway
        _b("wc_back", (0.03, W, H), (-0.015, 0, z0 + H / 2), "panel")
        for s in (-1, 1):
            _b(f"wc_side{s}", (D - 0.04, 0.04, H), (-D / 2 - 0.02, s * (W / 2 - 0.02), z0 + H / 2), "panel", 0.01)
        _b("wc_top", (D - 0.04, W - 0.08, 0.04), (-D / 2 - 0.02, 0, z0 + H - 0.02), "panel")
        _b("wc_header", (0.04, W - 0.08, 0.2), (-D + 0.02, 0, z0 + H - 0.1), "panel")  # over the doorway, with the sign
        HY = -(W - 0.08) / 2 + DW  # the doorway runs from the side wall at -y to the jamb, where the door hangs
        _b("wc_jamb", (0.04, (W - 0.08) / 2 - HY, 1.85), (-D + 0.02, ((W - 0.08) / 2 + HY) / 2, z0 + 0.925), "panel")
        # the sign: a plate with a glowing toilet pictogram and the word, like the HUD's labels
        _b("wc_sign", (0.012, 0.4, 0.13), (-D - 0.004, 0, z0 + H - 0.1), "trim", 0.004)
        icon = prism("wc_icon", [(0.0, 0.0), (0.05, 0.0), (0.05, 0.02), (0.035, 0.035), (0.035, 0.06), (0.01, 0.06), (0.0, 0.04)], 0.008, mat=mat("light"))
        icon.location = (-D - 0.012, 0.12, z0 + H - 0.135)  # a toilet seen side on: bowl, seat, tank
        loose.append(icon)
        loose.append(flat_label("wc_word", "TOILET", 0.06, (-D - 0.013, -0.05, z0 + H - 0.1), "light", 0, 90, 0))  # flat, 3 mm proud
        # the door, open 50 degrees into the room, hinged on the jamb
        door = _b("wc_door", (0.03, DW - 0.01, 1.83), (0, -(DW - 0.01) / 2, 0), "panel", 0.008)
        U.append(smooth(bar("wc_door_handle", (-0.04, -DW + 0.08, 1.0 - 0.915), (-0.04, -DW + 0.08, 1.15 - 0.915), 0.012, mat("metal"))))
        handle = U[-1]
        for o in (door, handle):
            o.matrix_world = Matrix.Translation((-D - 0.02, HY, z0 + 0.925)) @ Matrix.Rotation(math.radians(-50), 4, "Z") @ o.matrix_world
        # the UWMS: a short pedestal, its seat and lid, the hose in a cradle on the wall and the funnel on its end
        _c("wc_unit", 0.17, 0.4, (-0.38, 0.1, z0 + 0.2), "panel", 16)
        _c("wc_seat", 0.16, 0.03, (-0.38, 0.1, z0 + 0.418), "trim", 16)
        lid = _c("wc_lid", 0.16, 0.025, (0, 0, 0), "panel", 16)
        lid.rotation_euler.y = math.radians(90)
        lid.location = (-0.2, 0.1, z0 + 0.58)
        _b("wc_cradle", (0.06, 0.08, 0.12), (-0.03, 0.32, z0 + 0.95), "trim", 0.01)
        _bar("wc_hose", (-0.33, 0.22, z0 + 0.3), (-0.06, 0.32, z0 + 0.9), 0.022, "trim")
        U.append(smooth(cone("wc_funnel", 0.05, 0.12, (-0.06, 0.32, z0 + 1.04), mat("panel"), 12, (math.pi, 0, 0))))
        _c("urine_tank", 0.1, 0.45, (-0.14, -0.27, z0 + 0.225), "panel", 12)
    unit(toilet, 177, 0.9)

    def galley():  # ISS crews heat food in a suitcase-like warmer and have no fridge (factcheck row 115)
        W, D, H = 1.6, 0.6, 0.92
        _b("galley_cabinet", (D - 0.02, W - 0.4, H - 0.02), (-D / 2, 0.2, z0 + (H - 0.02) / 2), "panel", 0.015)
        _b("galley_top", (D + 0.02, W - 0.38, 0.04), (-D / 2, 0.2, z0 + H - 0.01), "trim", 0.01)
        for i, y in enumerate((-0.2, 0.2, 0.6)):
            _b(f"galley_door{i}", (0.02, 0.36, 0.6), (-D + 0.005, y, z0 + 0.42), "trim", 0.005)
        _b("warmer", (0.3, 0.42, 0.2), (-0.3, -0.18, z0 + H + 0.115), "metal", 0.02)
        _bar("warmer_handle", (-0.46, -0.3, z0 + H + 0.14), (-0.46, -0.06, z0 + H + 0.14), 0.012, "trim")
        _b("dispenser", (0.2, 0.18, 0.36), (-0.12, 0.14, z0 + H + 0.18), "panel", 0.01)
        _bar("dispenser_nozzle", (-0.22, 0.14, z0 + H + 0.24), (-0.28, 0.14, z0 + H + 0.2), 0.012, "metal")
        _c("water_tank", 0.17, 0.8, (-0.25, -0.6, z0 + 0.4), "panel", 16)  # the hard tank, with its gauge
        _c("water_tank_gauge", 0.05, 0.03, (-0.42, -0.6, z0 + 0.62), "trim", 12, rot=(0, math.pi / 2, 0))
        _c("water_tank_glass", 0.04, 0.03, (-0.43, -0.6, z0 + 0.62), "glass", 12, rot=(0, math.pi / 2, 0))
        s = bpy.data.objects.new("slot_1", None)  # the Veggie unit, front into the room
        bpy.context.scene.collection.objects.link(s)
        s.location, s.rotation_euler = (-0.3, 0.6, z0 + H + 0.015), (0, 0, math.radians(90))
        slots.append(s)
        return [s]
    unit(galley, 0, 1.6)

    def desk():  # mission planning: two screens on wall arms, the Gale map on the desk (`slot_2`)
        W, D, H = 1.0, 0.6, 0.76
        _b("desk_top", (D, W, 0.04), (-D / 2, 0, z0 + H - 0.02), "panel", 0.01)
        for s in (-1, 1):
            _b(f"desk_side{s}", (D - 0.06, 0.04, H - 0.03), (-D / 2, s * (W / 2 - 0.03), z0 + (H - 0.03) / 2), "trim")
            _b(f"screen{s}", (0.03, 0.44, 0.28), (-0.16, s * 0.23, z0 + H + 0.58), "trim", 0.008)
            _b(f"screen_glass{s}", (0.01, 0.4, 0.24), (-0.178, s * 0.23, z0 + H + 0.58), "glass")
            _bar(f"screen_arm{s}", (0.0, s * 0.23, z0 + H + 0.58), (-0.15, s * 0.23, z0 + H + 0.58), 0.015, "metal")
        s = bpy.data.objects.new("slot_2", None)
        bpy.context.scene.collection.objects.link(s)
        s.location, s.rotation_euler = (-0.31, 0, z0 + H + 0.003), (0, 0, math.radians(90))
        slots.append(s)
        return [s]
    unit(desk, 33, 1.0)

    def donning():  # where the crew put their suits on and take them off: a bench, hooks, a helmet shelf (both suits
        # are worn on an EVA, so the corner is empty: NASA's 30-sol plan has no spares)
        _b("bench", (0.4, 1.1, 0.04), (-0.22, 0, z0 + 0.45), "panel", 0.01)
        for s in (-1, 1):
            _b(f"bench_leg{s}", (0.36, 0.04, 0.44), (-0.22, s * 0.5, z0 + 0.22), "metal")  # tops inside the seat
            _b(f"hook_plate{s}", (0.12, 0.06, 0.1), (0.04, s * 0.3, z0 + 1.55), "metal")  # back into the curved wall
            _bar(f"hook{s}", (-0.02, s * 0.3, z0 + 1.53), (-0.12, s * 0.3, z0 + 1.58), 0.012, "metal")
        _b("helmet_shelf", (0.42, 1.0, 0.025), (-0.11, 0, z0 + 1.85), "panel", 0.006)
        for s in (-1, 1):
            _b(f"helmet_bracket{s}", (0.36, 0.015, 0.08), (-0.08, s * 0.42, z0 + 1.80), "metal")
    unit(donning, 140, 1.1)
    _b("boot_mat", (0.7, 1.0, 0.012), (0, 0, 0), "trim", 0.004)  # rubber, by the bench: the boots stop here
    U[-1].location = at(1.35, 145, z0 + 0.006)
    U[-1].rotation_euler.z = math.radians(145)

    def brush():  # for the suits before they come in (the dust is "likely toxic"), on the wall by the hatch
        _bar("brush_handle", (-0.05, 0, z0 + 1.0), (-0.05, 0, z0 + 1.55), 0.015, "trim")
        _b("brush_head", (0.06, 0.08, 0.12), (-0.05, 0, z0 + 0.95), "trim", 0.01)
    unit(brush, 118, 0.1)

    # ceiling lights: four panels in dark housings, the housing tops 5 mm into the roof
    for i, a in enumerate((0, 90, 180, 270)):
        h = box(f"light_housing{i}", (0.16, 0.74, 0.03), at(1.4, a + 45, CEIL - 0.01), mat("trim"))
        h.rotation_euler.z = math.radians(a + 45)
        U.append(h)
        p = box(f"ceiling_light{i}", (0.12, 0.7, 0.012), at(1.4, a + 45, CEIL - 0.03), mat("light"))
        p.rotation_euler.z = math.radians(a + 45)
        loose.append(p)
    return U, loose, slots


def deck(F, RI, hatch_cut):
    """The floor: a deck in the `deck` role, top at F, its underside inside the floor slab, laid out in 60 cm plates
    (a raised-floor tile) by dark joint strips 3 mm proud of it (never flush: a face on a face flickers), each
    running into the wall's solid at both ends."""
    sill_y = hatch_cut.location.y - hatch_cut.dimensions.y / 2  # the joints stop short of the hatch's sill
    sill_x = hatch_cut.dimensions.x / 2
    d = cyl("deck", RI - 0.004, 0.025, (0, 0, F - 0.0125), mat("deck"), 48)
    cut(d, hatch_cut)
    U.append(d)
    for k in range(-4, 4):
        g = k * 0.6 + 0.3
        half = math.sqrt((RI + 0.05) ** 2 - g * g)
        hi = sill_y - 0.01 if abs(g) < sill_x else half
        U.append(box(f"deck_joint_x{k}", (0.008, hi + half, 0.008), (g, (hi - half) / 2, F - 0.001), mat("trim")))
        U.append(box(f"deck_joint_y{k}", (2 * half, 0.008, 0.008), (0, g, F - 0.001), mat("trim")))
    return d
