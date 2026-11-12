# HAB 1 fitted out for a crew of 2 (design/research/missing-assets.md sections 2c to 3): a stacked pair of
# sleep berths lined with water bags (NASA rates a water wall round the crew quarters the best storm shelter),
# a galley with a food warmer, water dispenser and tank, a toilet cubicle, a life-support wall of two
# fridge-sized racks (amine CO2 scrubber, water processor), an O2/N2 valve panel fed from the bottle skid
# outside, a workstation, two suits on stands with a dust mat by the hatch, wall seams, window frames and
# ceiling lights. Every unit stands on a chord of the drum wall, clear of the hatch and its door swing.
#
# Drawn parts join one `interior-col` node: one collision body, and DESIGN.md `weathering.clean` keeps a swept
# room free of the dust coat. Parts in roles that take no coat (light, visor) stay out of it, so they share the
# outside's materials and cost no draw call of their own. `slot_1` on the counter is where world.json `plants`
# puts the Veggie unit (models/prop_veggie.glb).
import os

from mathutils import Matrix

from base_kit import *  # noqa: F403

U = []  # parts that join interior-col
# Rack faces and the toilet's fabric privacy curtain from NASA's ISS interior model (Node 3 racks, the Waste and
# Hygiene Compartment; NASA 3D Resources, no copyright), cropped into one atlas of three tiles, its mission
# patch left out of the crop: one material (`iss_panels`, a DESIGN.md kit `keep`) for all of them
ISS = os.path.join(os.path.dirname(os.path.abspath(__file__)), *[".."] * 4, "assets-cache", "nasa-3d", "iss-internal", "parts")
GRILLES, PANELS, FABRIC = 0, 1, 2  # atlas tiles, left to right, a quarter of its width each


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


def _b(name, size, at_, role, bev=0.0):
    o = box(name, size, at_, mat(role))
    if bev:
        bevel(o, width=bev, segments=1)
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


def _mount(parts, ang, w, ri):
    """Parts built with their back on local x = 0, front toward -x, width along y, onto the wall chord at
    `ang` degrees: the back plane goes as far out as its corners allow inside the wall's inner radius."""
    rb = math.sqrt((ri - 0.03) ** 2 - (w / 2) ** 2)
    bpy.context.view_layer.update()  # bar() sets its rotation after placing: matrix_world is stale until now
    a = math.radians(ang)
    for o in parts:
        o.matrix_world = Matrix.Rotation(a, 4, "Z") @ Matrix.Translation((rb, 0, 0)) @ o.matrix_world
    return parts


def _unit(build, ang, w, ri):
    """Runs `build()`, which appends to U, and mounts what it added."""
    n = len(U)
    build()
    _mount(U[n:], ang, w, ri)


def fit_out(F, RI, CEIL):
    z0 = F + 0.002  # 2 mm off the floor: a face on the floor's face flickers (tools/coplanar-check.mjs)
    loose = []      # light and visor parts: no coat, so they stay out of interior-col

    def rack(label_text, kind):
        W, D, H = 1.05, 0.7, 2.0
        xf = -D + 0.01  # front face
        _b(f"{kind}_cabinet", (D - 0.02, W, H), (-D / 2, 0, z0 + H / 2), "body", 0.02)
        _face(f"{kind}_face", W - 0.06, 1.72, (xf - 0.004, 0, z0 + 0.96), GRILLES if kind == "co2" else PANELS)
        _b(f"{kind}_sign", (0.02, 0.5, 0.16), (xf - 0.005, 0, z0 + H - 0.14), "trim")
        lab = flat_label(f"{kind}_label", label_text, 0.11, (xf - 0.021, 0, z0 + H - 0.14), "body", 0, 90, 0)
        U.append(lab)
        loose.append(box(f"{kind}_lamp", (0.012, 0.3, 0.03), (xf - 0.012, 0, z0 + H - 0.3), mat("light")))
        if kind == "co2":  # two amine beds, swapped between soaking up CO2 and venting it outside
            for s in (-1, 1):
                _c(f"co2_bed{s}", 0.13, 0.62, (xf - 0.03, s * 0.24, z0 + 1.32), "glass", 16)
                for dz in (-0.33, 0.33):
                    _c(f"co2_cap{s}{dz}", 0.145, 0.05, (xf - 0.03, s * 0.24, z0 + 1.32 + dz), "metal", 16)
            _c("co2_fan", 0.16, 0.03, (xf - 0.005, 0, z0 + 0.86), "trim", 16, rot=(0, math.pi / 2, 0))
            _bar("co2_vent_up", (-0.35, 0.3, z0 + H), (-0.35, 0.3, CEIL - 0.06), 0.035, "metal")
            _bar("co2_vent_out", (-0.35, 0.3, CEIL - 0.06), (0.15, 0.3, CEIL - 0.06), 0.035, "metal")
        else:  # water processor: three filter beds, a clean-water sight glass, a gauge
            for i in range(3):
                _c(f"h2o_filter{i}", 0.05, 0.42, (xf - 0.03, -0.3 + i * 0.13, z0 + 1.3), "glass", 10)
                _c(f"h2o_fcap{i}", 0.06, 0.05, (xf - 0.03, -0.3 + i * 0.13, z0 + 1.53), "metal", 10)
            _b("h2o_sight", (0.02, 0.1, 0.5), (xf - 0.01, 0.3, z0 + 1.3), "glass")
            _c("h2o_gauge", 0.07, 0.03, (xf - 0.01, 0.3, z0 + 0.96), "trim", 16, rot=(0, math.pi / 2, 0))
            _c("h2o_gauge_glass", 0.055, 0.03, (xf - 0.02, 0.3, z0 + 0.96), "glass", 16, rot=(0, math.pi / 2, 0))
    for ang, lab, kind in ((287, "CO2", "co2"), (315, "WATER", "h2o")):
        n0, l0 = len(U), len(loose)
        rack(lab, kind)
        _mount(U[n0:] + loose[l0:], ang, 1.05, RI)

    def valves():  # where the O2 and N2 lines from the bottle skid come through the wall
        _b("valve_panel", (0.1, 0.4, 0.5), (-0.05, 0, z0 + 1.25), "trim", 0.01)
        for s in (-1, 1):
            _c(f"valve{s}", 0.05, 0.04, (-0.12, s * 0.1, z0 + 1.32), "metal", 12, rot=(0, math.pi / 2, 0))
            _bar(f"valve_line{s}", (-0.07, s * 0.1, z0 + 1.0), (-0.07, s * 0.1, z0 + 0.03), 0.018, "metal")
        U.append(flat_label("valve_label", "O2 N2", 0.06, (-0.106, 0, z0 + 1.12), "body", 0, 90, 0))
    _unit(valves, 62, 0.4, RI)  # beside the hatch, where the skid's line comes in

    def bunks():  # two berths stacked, 2.0 m long: lying down in 0.38 g
        W, D, H = 2.0, 0.9, 2.0
        _b("bunk_back", (0.04, W, H), (-0.02, 0, z0 + H / 2), "body")
        for s in (-1, 1):
            _b(f"bunk_end{s}", (D - 0.04, 0.04, H), (-D / 2 - 0.02, s * (W / 2 - 0.02), z0 + H / 2), "body", 0.01)
        _b("bunk_top", (D - 0.04, W - 0.08, 0.04), (-D / 2 - 0.02, 0, z0 + H - 0.02), "body")
        _b("bunk_base", (D - 0.06, W - 0.08, 0.3), (-D / 2 - 0.02, 0, z0 + 0.15), "trim")
        _b("bunk_shelf", (D - 0.04, W - 0.08, 0.06), (-D / 2 - 0.02, 0, z0 + 1.02), "body")
        for k, zb in enumerate((0.3, 1.05)):
            _b(f"mattress{k}", (0.6, W - 0.12, 0.12), (-0.58, 0, z0 + zb + 0.065), "suit", 0.04)
            for i, y in enumerate((-0.72, -0.24, 0.24, 0.72)):  # water bags along the back: the storm wall
                _b(f"water_bag{k}{i}", (0.24, 0.46, 0.42), (-0.17, y, z0 + zb + 0.215), "suit", 0.05)
                _b(f"bag_strap{k}{i}", (0.25, 0.04, 0.42), (-0.17, y, z0 + zb + 0.22), "trim")
            _face(f"curtain{k}", 0.62, 0.6, (-D + 0.01, W / 2 - 0.36, z0 + zb + 0.42 if k else z0 + zb + 0.4), FABRIC)
            loose.append(box(f"reading_lamp{k}", (0.12, 0.012, 0.05), (-0.45, -W / 2 + 0.047, z0 + zb + 0.58), mat("light")))
        for i, y in enumerate((-0.72, -0.24, 0.24, 0.72)):  # a third row on the roof
            _b(f"water_bag_top{i}", (0.42, 0.46, 0.24), (-0.3, y, z0 + H + 0.125), "suit", 0.05)
        for s in (-1, 1):  # ladder to the upper berth
            _bar(f"ladder_rail{s}", (-D + 0.02, -0.6 + s * 0.17, z0 + 0.3), (-D + 0.02, -0.6 + s * 0.17, z0 + 1.1), 0.015, "metal")
        for i in range(2):
            _bar(f"ladder_rung{i}", (-D + 0.02, -0.77, z0 + 0.52 + i * 0.27), (-D + 0.02, -0.43, z0 + 0.52 + i * 0.27), 0.012, "metal")
    n0, l0 = len(U), len(loose)
    bunks()
    _mount(U[n0:] + loose[l0:], 214, 2.0, RI)

    def toilet():  # a UWMS-style toilet: small, with a hose; urine is stored, not recycled (ICES-2023-265)
        W, D, H = 0.9, 0.9, 2.05
        _b("wc_back", (0.04, W, H), (-0.02, 0, z0 + H / 2), "body")
        for s in (-1, 1):
            _b(f"wc_side{s}", (D - 0.04, 0.04, H), (-D / 2 - 0.02, s * (W / 2 - 0.02), z0 + H / 2), "body", 0.01)
        _b("wc_top", (D - 0.04, W - 0.08, 0.04), (-D / 2 - 0.02, 0, z0 + H - 0.02), "body")
        _face("wc_curtain", 0.5, 1.8, (-D + 0.01, -0.18, z0 + 1.1), FABRIC)
        _c("wc_seat", 0.19, 0.42, (-0.4, 0.12, z0 + 0.21), "metal", 16)
        _c("wc_lid", 0.2, 0.03, (-0.4, 0.12, z0 + 0.44), "body", 16)
        _bar("wc_hose", (-0.25, 0.3, z0 + 0.35), (-0.06, 0.3, z0 + 0.9), 0.025, "trim")
        _c("urine_tank", 0.12, 0.5, (-0.16, 0.3, z0 + 0.25), "body", 12)
        _bar("wc_grab", (-0.08, -0.2, z0 + 0.7), (-0.08, -0.2, z0 + 1.1), 0.015, "metal")
    _unit(toilet, 172, 0.9, RI)

    def galley():  # ISS crews heat food in a suitcase-like warmer and have no fridge (factcheck row 115)
        W, D, H = 1.6, 0.6, 0.92
        _b("galley_cabinet", (D - 0.02, W - 0.4, H - 0.02), (-D / 2, 0.2, z0 + (H - 0.02) / 2), "body", 0.015)
        _b("galley_top", (D + 0.02, W - 0.38, 0.04), (-D / 2, 0.2, z0 + H - 0.01), "trim", 0.01)
        for i, y in enumerate((-0.2, 0.2, 0.6)):
            _b(f"galley_door{i}", (0.02, 0.36, 0.6), (-D + 0.005, y, z0 + 0.42), "trim", 0.005)
        _b("warmer", (0.3, 0.42, 0.2), (-0.3, -0.18, z0 + H + 0.115), "metal", 0.02)
        _bar("warmer_handle", (-0.46, -0.3, z0 + H + 0.14), (-0.46, -0.06, z0 + H + 0.14), 0.012, "trim")
        _b("dispenser", (0.2, 0.18, 0.36), (-0.12, 0.14, z0 + H + 0.18), "body", 0.01)
        _bar("dispenser_nozzle", (-0.22, 0.14, z0 + H + 0.24), (-0.28, 0.14, z0 + H + 0.2), 0.012, "metal")
        for i in range(3):  # food pouches, thermostabilised
            _b(f"pouch{i}", (0.16, 0.12, 0.018), (-0.45, 0.32 + 0.01 * i, z0 + H + 0.012 + i * 0.019), "metal")
        _c("water_tank", 0.17, 0.8, (-0.25, -0.6, z0 + 0.4), "body", 16)  # the hard tank, with its gauge
        _c("water_tank_gauge", 0.05, 0.03, (-0.42, -0.6, z0 + 0.62), "trim", 12, rot=(0, math.pi / 2, 0))
        _c("water_tank_glass", 0.04, 0.03, (-0.43, -0.6, z0 + 0.62), "glass", 12, rot=(0, math.pi / 2, 0))
        slot = bpy.data.objects.new("slot_1", None)  # the Veggie unit (world.json plants), front into the room
        bpy.context.scene.collection.objects.link(slot)
        slot.location, slot.rotation_euler = (-0.3, 0.6, z0 + H + 0.015), (0, 0, math.radians(90))
        return slot
    n0 = len(U)
    slot = galley()
    _mount(U[n0:] + [slot], 348, 1.6, RI)

    def desk():  # mission planning: two screens on wall arms (lit at night), the Gale map on the desk (`slot_2`)
        W, D, H = 1.0, 0.6, 0.76
        _b("desk_top", (D, W, 0.04), (-D / 2, 0, z0 + H - 0.02), "body", 0.01)
        for s in (-1, 1):
            _b(f"desk_side{s}", (D - 0.06, 0.04, H - 0.03), (-D / 2, s * (W / 2 - 0.03), z0 + (H - 0.03) / 2), "trim")
        for s in (-1, 1):
            _b(f"screen{s}", (0.03, 0.44, 0.28), (-0.16, s * 0.23, z0 + H + 0.58), "trim", 0.008)
            _b(f"screen_glass{s}", (0.01, 0.4, 0.24), (-0.178, s * 0.23, z0 + H + 0.58), "glass")
            _bar(f"screen_arm{s}", (0.0, s * 0.23, z0 + H + 0.58), (-0.15, s * 0.23, z0 + H + 0.58), 0.015, "metal")
        slot = bpy.data.objects.new("slot_2", None)
        bpy.context.scene.collection.objects.link(slot)
        slot.location, slot.rotation_euler = (-0.31, 0, z0 + H + 0.003), (0, 0, math.radians(90))
        return slot
    n0 = len(U)
    slot2 = desk()
    _mount(U[n0:] + [slot2], 22, 1.0, RI)

    def suit(tag, y):  # a suit on its stand, facing the room: it stays here, the dust stays by the hatch
        x = -0.32
        _b(f"{tag}_base", (0.5, 0.5, 0.03), (x, y, z0 + 0.015), "metal", 0.005)
        _bar(f"{tag}_post", (-0.06, y, z0 + 0.03), (-0.06, y, z0 + 1.5), 0.025, "metal")
        _b(f"{tag}_pack", (0.2, 0.44, 0.6), (-0.14, y, z0 + 1.2), "body", 0.04)
        _c(f"{tag}_torso", 0.2, 0.55, (x, y, z0 + 1.25), "suit", 12)
        _c(f"{tag}_hips", 0.17, 0.25, (x, y, z0 + 0.86), "suit", 12)
        for s in (-1, 1):
            _bar(f"{tag}_leg{s}", (x, y + s * 0.09, z0 + 0.8), (x - 0.02, y + s * 0.1, z0 + 0.12), 0.075, "suit")
            _b(f"{tag}_boot{s}", (0.28, 0.12, 0.12), (x - 0.06, y + s * 0.1, z0 + 0.095), "trim", 0.02)
            _bar(f"{tag}_arm{s}", (x - 0.02, y + s * 0.25, z0 + 1.45), (x - 0.05, y + s * 0.27, z0 + 0.9), 0.065, "suit")
            U.append(smooth(sphere(f"{tag}_glove{s}", 0.06, (x - 0.05, y + s * 0.27, z0 + 0.86), mat("trim"), 8)))
        U.append(smooth(sphere(f"{tag}_helmet", 0.17, (x, y, z0 + 1.71), mat("body"), 12)))
        loose.append(smooth(sphere(f"{tag}_visor", 0.15, (x - 0.045, y, z0 + 1.71), mat("visor"), 12)))
    for tag, ang in (("suit_a", 133), ("suit_b", 150)):
        n0, l0 = len(U), len(loose)
        suit(tag, 0)
        _mount(U[n0:] + loose[l0:], ang, 0.6, RI)

    def brush():  # for the suits before they come in (the dust is "likely toxic")
        _bar("brush_handle", (-0.05, 0, z0 + 1.0), (-0.05, 0, z0 + 1.55), 0.015, "trim")
        _b("brush_head", (0.06, 0.08, 0.12), (-0.05, 0, z0 + 0.95), "trim", 0.01)
    _unit(brush, 159.5, 0.1, RI)
    mat_ = box("dust_mat", (1.0, 0.7, 0.012), (0, 0, z0 + 0.006), mat("dust"))
    mat_.rotation_euler.z = math.radians(141 + 90)
    mat_.location = at(1.3, 141, z0 + 0.006)
    U.append(mat_)

    # ceiling lights: four panels in dark housings, the housing tops 5 mm into the roof
    for i, a in enumerate((0, 90, 180, 270)):
        h = box(f"light_housing{i}", (0.16, 0.74, 0.03), at(1.4, a + 45, CEIL - 0.01), mat("trim"))
        h.rotation_euler.z = math.radians(a + 45)
        U.append(h)
        p = box(f"ceiling_light{i}", (0.12, 0.7, 0.012), at(1.4, a + 45, CEIL - 0.03), mat("light"))
        p.rotation_euler.z = math.radians(a + 45)
        loose.append(p)
    return U, loose


def wall_trim(F, RI, CEIL, windows, skip):
    """Window frames on the inside of the drum, and vertical panel seams where the wall shows."""
    for i, a in enumerate(windows):
        rot = (0, math.pi / 2, math.radians(a))
        U.append(cyl(f"window_in_ring{i}", 0.34, 0.03, at(RI, a, 1.65), mat("trim"), 24, rot))
        U.append(smooth(cyl(f"window_in{i}", 0.26, 0.03, at(RI - 0.005, a, 1.65), mat("glass"), 24, rot)))
    for k in range(24):
        a = k * 15 + 7.5
        if any(abs((a - c + 180) % 360 - 180) < hw for c, hw in skip) or any(abs((a - w + 180) % 360 - 180) < 12 for w in windows):
            continue
        s = box(f"wall_seam{k}", (0.02, 0.05, CEIL - F - 0.12), at(RI - 0.005, a, (F + CEIL) / 2), mat("trim"))
        s.rotation_euler.z = math.radians(a)
        U.append(s)
