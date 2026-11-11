# The hero: NASA's Astronaut model (an EMU-style suit with its backpack, helmet, gold visor and chest unit)
# at 1.89 m, painted in DESIGN.md roles with no insignia, rigged to the Quaternius Universal Animation Library
# skeleton, and given suited clips made from UAL clips (forge/hero_clips.py). Writes models/character_suited.glb,
# data/clips.json and three rest-pose previews.
#   FORGE_DESIGN=$PWD/DESIGN.md FORGE_OUT=$PWD/models FORGE_PREVIEWS=$PWD/design/research/asset-previews/hero \
#     blender -b --python-exit-code 1 -P forge/hero_astronaut.py
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector, kdtree  # noqa: E402

import hero_clips  # noqa: E402
from hero_rig import Rig  # noqa: E402
from shapes import OUT, mat, render_views, reset, smooth  # noqa: E402

CACHE = os.path.join(HERE, "..", "..", "..", "..", "assets-cache")
NASA = os.path.join(CACHE, "nasa-3d", "astronaut.glb")  # Draco: Blender reads it, Godot never sees it
UAL1 = os.path.join(CACHE, "quaternius", "ual", "ual1", "UAL1_Standard.glb")
HEIGHT = 1.89  # data/reality.json hero.height
Y_SHIFT = 0.07  # puts the hips over the origin; the backpack hangs behind it

# Joints fitted to the suit by slicing the mesh (left side; the right mirrors x). Metres, Z up, facing -Y.
J = {
    "pelvis": (0, 0, 0.86), "pelvis_t": (0, 0, 0.97), "spine1": (0, 0, 0.98), "spine2": (0, 0, 1.12),
    "spine3": (0, 0, 1.27), "spine3_t": (0, 0, 1.47), "neck": (0, 0, 1.48), "head": (0, 0, 1.58),
    "head_t": (0, 0, 1.78),
    "clav": (0.02, 0, 1.45), "shoulder": (0.24, -0.02, 1.43), "elbow": (0.50, -0.02, 1.39),
    "wrist": (0.765, -0.04, 1.355), "hand_t": (0.84, -0.04, 1.30),
    "hip": (0.12, -0.02, 0.86), "knee": (0.18, -0.04, 0.48), "ankle": (0.225, 0.01, 0.12),
    "ball": (0.235, -0.15, 0.035), "toe": (0.235, -0.26, 0.035), "toe_t": (0.235, -0.34, 0.035),
}
BONES = {  # bone: (head joint, tail joint); a side letter is added for paired bones
    "pelvis": ("pelvis", "pelvis_t"), "spine_01": ("spine1", "spine2"), "spine_02": ("spine2", "spine3"),
    "spine_03": ("spine3", "spine3_t"), "neck_01": ("neck", "head"), "Head": ("head", "head_t"),
    "clavicle_%s": ("clav", "shoulder"), "upperarm_%s": ("shoulder", "elbow"), "lowerarm_%s": ("elbow", "wrist"),
    "hand_%s": ("wrist", "hand_t"), "thigh_%s": ("hip", "knee"), "calf_%s": ("knee", "ankle"),
    "foot_%s": ("ankle", "ball"), "ball_%s": ("ball", "toe"), "ball_leaf_%s": ("toe", "toe_t"),
}
GLOVE_X, BOOT_Z, HELMET_Z, PACK_Y = 0.775, 0.16, 1.585, 0.205


def in_dcm(c, pad=0.0):
    """Inside the chest control unit's box (measured off the mesh: its face is at y = -0.276)."""
    return abs(c.x) < 0.115 + pad and 1.215 - pad < c.z < 1.53 + pad and c.y < -0.15 + pad


def joint(name, side):
    x, y, z = J[name]
    return Vector((-x if side == "r" else x, y, z))


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def load_suit():
    """NASA's mesh, welded (the file splits every triangle along its seams, which defeats automatic
    weights), scaled to HEIGHT with its feet on z = 0 and the hips over the origin."""
    objs = import_glb(NASA)
    o = next(x for x in objs if x.type == "MESH")
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for x in objs:
        if x is not o:
            bpy.data.objects.remove(x)
    zs = [v.co.z for v in o.data.vertices]
    s = HEIGHT / (max(zs) - min(zs))
    for v in o.data.vertices:
        v.co = Vector((v.co.x * s, v.co.y * s + Y_SHIFT, (v.co.z - min(zs)) * s))
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=HEIGHT * 1e-5)
    bm.to_mesh(o.data)
    bm.free()
    if o.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    return o


def islands(bm):
    """Face index -> island id, the largest island (the suit itself) first."""
    seen, out = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, isl = [f], []
        seen.add(f.index)
        while stack:
            x = stack.pop()
            isl.append(x.index)
            for e in x.edges:
                for y in e.link_faces:
                    if y.index not in seen:
                        seen.add(y.index)
                        stack.append(y)
        out.append(isl)
    out.sort(key=len, reverse=True)
    return {fi: n for n, isl in enumerate(out) for fi in isl}


def paint(o, roles):
    """Every face gets a role by where it sits: the NASA texture (a white suit with a flag, a NASA logo, a
    mission patch and a red stripe) is dropped, so no insignia survives."""
    suit, trim, metal, visor, body, _accent = roles
    bm = bmesh.new()  # read the faces first: clearing the slots resets every face's material index
    bm.from_mesh(o.data)
    bm.faces.ensure_lookup_table()
    o.data.materials.clear()
    for m in roles:
        o.data.materials.append(m)
    isl = islands(bm)
    for f in bm.faces:
        c = f.calc_center_median()
        if f.material_index == 1:
            r = visor
        elif isl[f.index]:
            r = metal  # small parts: helmet lamps and cameras, the chest unit's knobs
        elif in_dcm(c):
            r = trim if f.normal.y < -0.9 else body  # the chest control unit: a hard box, its face dark
        elif abs(c.x) > GLOVE_X or c.z < 0.03:
            r = trim  # gloves and boot soles
        elif (c.z > HELMET_Z and c.y < PACK_Y) or (c.y > PACK_Y and c.z > 0.85):
            r = body  # hard shells: helmet and backpack
        else:
            r = suit
        f.material_index = roles.index(r)
    bm.to_mesh(o.data)
    bm.free()


def band(suit, name, c, axis, width, m, pad=0.007, n=24):
    """A ring hugging the limb around `c` across `axis`: radius per angle from the suit's own vertices."""
    axis = Vector(axis).normalized()
    u = axis.cross(Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))).normalized()
    v = axis.cross(u)
    c = Vector(c)
    pts = [p.co - c for p in suit.data.vertices if abs((p.co - c).dot(axis)) < 0.03 and (p.co - c).length < 0.25]
    mid = sum(((p - axis * p.dot(axis)) for p in pts), Vector()) / len(pts)
    c, pts = c + mid, [p - mid for p in pts]
    rad = []
    for i in range(n):
        a = 2 * math.pi * i / n
        near = [p.dot(u) * math.cos(a) + p.dot(v) * math.sin(a) for p in pts
                if abs(math.remainder(math.atan2(p.dot(v), p.dot(u)) - a, 2 * math.pi)) < 2 * math.pi / n]
        rad.append(max(near) if near else None)
    rad = [r if r is not None else max(x for x in rad if x) for r in rad]
    bm = bmesh.new()
    rings = [[bm.verts.new(c + axis * h + (u * math.cos(2 * math.pi * i / n) + v * math.sin(2 * math.pi * i / n))
                           * (rad[i] + pad)) for i in range(n)] for h in (-width / 2, width / 2)]
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(m)
    return o


def fit_rig():
    """UAL's armature (its mannequin dropped), joints moved onto the suit. Returns (armature, source rig)."""
    objs = import_glb(UAL1)
    arm = next(o for o in objs if o.type == "ARMATURE")
    for o in objs:
        if o is not arm:
            bpy.data.objects.remove(o)
    arm.name = "Astronaut"
    src = Rig(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    hand0 = {s: eb["hand_" + s].matrix.copy() for s in "lr"}
    for pattern, (h, t) in BONES.items():
        for s in ("lr" if "%s" in pattern else "-"):
            b = eb[pattern % s if "%s" in pattern else pattern]
            b.head, b.tail = joint(h, s), joint(t, s)
    for s in "lr":  # fingers ride on the glove, shrunk inside it; they never deform it
        rot = eb["hand_" + s].matrix.to_3x3() @ hand0[s].to_3x3().inverted()
        w0, w1 = hand0[s].translation, eb["hand_" + s].head
        for b in eb:
            if b.parent and b.name.endswith("_" + s) and b.name.split("_")[0] in ("index", "middle", "ring", "pinky", "thumb"):
                b.head, b.tail = w1 + rot @ ((b.head - w0) * 0.6), w1 + rot @ ((b.tail - w0) * 0.6)
    bpy.ops.object.mode_set(mode="OBJECT")
    for b in arm.data.bones:
        b.use_deform = not (b.name == "root" or "leaf" in b.name or b.name.startswith(("ball", "index", "middle", "ring", "pinky", "thumb")))
    return arm, src


def rigid(o, arm, groups):
    """Hard parts follow one bone whole: `groups` maps a bone name to vertex indices."""
    vg = {g.name: g for g in o.vertex_groups}
    for bone, idx in groups.items():
        for i in idx:
            for g in o.data.vertices[i].groups[:]:
                o.vertex_groups[g.group].remove([i])
            vg[bone].add([i], 1.0, "REPLACE")


def skin(o, arm):
    """Automatic weights, then hard parts made rigid and any vertex left unweighted given its neighbour's."""
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    for b in arm.data.bones:
        if b.use_deform and b.name not in o.vertex_groups:
            o.vertex_groups.new(name=b.name)
    me, roles = o.data, [m.name for m in o.data.materials]
    vrole = {}
    for p in me.polygons:
        for i in p.vertices:
            vrole.setdefault(i, set()).add(roles[p.material_index])
    groups = {}
    for v in me.vertices:
        c, r, s = v.co, vrole.get(v.index, set()), "l" if v.co.x > 0 else "r"
        if "visor" in r or (c.z > HELMET_Z and c.y < PACK_Y and ("body" in r or "metal" in r)):
            bone = "Head"
        elif ("body" in r and c.y > PACK_Y) or in_dcm(c, 0.01):
            bone = "spine_03"  # the backpack and the chest unit are bolted to the hard upper torso
        elif abs(c.x) > GLOVE_X - 0.02:
            bone = "hand_" + s
        elif c.z < BOOT_Z:
            bone = "foot_" + s
        else:
            continue
        groups.setdefault(bone, []).append(v.index)
    rigid(o, arm, groups)
    weighted = [v for v in me.vertices if sum(g.weight for g in v.groups) > 1e-4]
    tree = kdtree.KDTree(len(weighted))
    for n, v in enumerate(weighted):
        tree.insert(v.co, n)
    tree.balance()
    bare = [v for v in me.vertices if sum(g.weight for g in v.groups) <= 1e-4]
    for v in bare:
        _, n, _ = tree.find(v.co)
        for g in weighted[n].groups:
            o.vertex_groups[g.group].add([v.index], g.weight, "REPLACE")
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.vertex_group_limit_total(limit=4)
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    return len(bare)


def build():
    reset()
    roles = [mat(n) for n in ("suit", "trim", "metal", "visor", "body", "accent")]
    suit = load_suit()
    paint(suit, roles)
    arm, src = fit_rig()
    bands = {}
    for s, sx in (("l", 1), ("r", -1)):
        sh, el, hip, kn = (joint(n, s) for n in ("shoulder", "elbow", "hip", "knee"))
        wr = joint("wrist", s)
        bands[band(suit, "band_arm_" + s, sh.lerp(el, 0.6), el - sh, 0.06, roles[5])] = "upperarm_" + s
        bands[band(suit, "band_leg_" + s, hip.lerp(kn, 0.62), kn - hip, 0.07, roles[5])] = "thigh_" + s
        bands[band(suit, "ring_wrist_" + s, wr + Vector((0.0 * sx, 0, 0)), wr - el, 0.025, roles[2])] = "hand_" + s
    marks = {}
    for b, bone in bands.items():
        marks[bone] = marks.get(bone, []) + [len(suit.data.vertices) + i for i in range(len(b.data.vertices))]
        bpy.ops.object.select_all(action="DESELECT")
        b.select_set(True)
        suit.select_set(True)
        bpy.context.view_layer.objects.active = suit
        bpy.ops.object.join()
    suit.name = "astronaut"
    smooth(suit, 40)
    bare = skin(suit, arm)
    rigid(suit, arm, marks)
    bpy.context.view_layer.objects.active = suit
    bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    print("HERO tris", sum(len(p.vertices) - 2 for p in suit.data.polygons), "verts", len(suit.data.vertices),
          "unweighted fixed", bare, "bones", len(arm.data.bones))
    return suit, arm, src


def export(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_animations=True,
                              export_animation_mode="ACTIONS", export_force_sampling=False, export_def_bones=False,
                              export_leaf_bone=False, export_rest_position_armature=True, export_extras=False)


if __name__ == "__main__":
    suit, arm, src = build()
    hero_clips.make_all(arm, src, os.path.join(HERE, "..", "data", "clips.json"))
    path = os.path.join(OUT, "character_astronaut.glb")
    export(path)
    if not os.environ.get("FORGE_NO_RENDER"):
        arm.animation_data_clear()  # previews show the rest pose
        render_views("character_astronaut", {"front": (0.3, -1, 0.15), "side": (1, 0.05, 0.15), "back": (-0.3, 1, 0.15)}, 640, 640, 1.3)
    print("FORGE_DONE", path)
