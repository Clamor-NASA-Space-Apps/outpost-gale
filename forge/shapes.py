"""Shapes this game's recipes need that lib.py lacks: a side profile pushed out to a width, raised
lettering, joining parts into one node, and wheels whose node origin sits on the hub.

    import sys, os; sys.path.insert(0, os.path.dirname(__file__))
    from shapes import *        # also brings in lib (reset, mat, box, cyl, bevel, smooth, finish ...)
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "forge"))
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

from lib import *  # noqa: E402,F401,F403


def prism(name, profile, width, x=0.0, mat=None):
    """A solid from a side profile [(y, z), ...] (counter-clockwise seen from +X), `width` across X."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    left = [bm.verts.new((x - width / 2, y, z)) for y, z in profile]
    right = [bm.verts.new((x + width / 2, y, z)) for y, z in profile]
    n = len(profile)
    bm.faces.new(list(reversed(left)))
    bm.faces.new(right)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((left[i], left[j], right[j], right[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    if mat:
        o.data.materials.append(mat)
    return o


def label(name, text, size, loc, rot, mat, depth=0.008):
    """Raised lettering as real geometry (Blender's built-in font), so no texture can blur it."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body, cu.size, cu.extrude, cu.resolution_u = text, size, depth, 2
    cu.align_x, cu.align_y = "CENTER", "CENTER"
    o = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(o)
    o.location, o.rotation_euler = loc, rot
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.object
    o.data.materials.clear()
    o.data.materials.append(mat)
    o.select_set(False)
    return o


def join(name, parts):
    """Parts into one node (modifiers applied); the first part's origin stays."""
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
        bpy.context.view_layer.objects.active = p
        for m in list(p.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = o.data.name = name
    o.select_set(False)
    return o


def settle(o, origin):
    """Bake rotation and scale into the mesh and put the node's origin at `origin`, so a wheel spins
    about its own X axis and steers about its own up axis in the engine."""
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.context.scene.cursor.location = origin
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.context.scene.cursor.location = (0, 0, 0)
    o.select_set(False)
    return o


def tyre(name, r, w, at, tyre_mat, hub_mat, verts=24, lugs=0):
    """One wheel (axle along X) as one node with its origin on the hub. `lugs` adds tread blocks that
    reach the full radius `r` from a carcass slightly smaller."""
    t = bevel(cyl(name, r * (0.94 if lugs else 1), w, at, tyre_mat, verts, rot=(0, math.pi / 2, 0)), width=w * 0.15, segments=1)
    parts = [smooth(t)]
    parts.append(smooth(cyl(name + "_hub", r * 0.55, w * 1.04, at, hub_mat, 16, rot=(0, math.pi / 2, 0))))
    for i in range(lugs):
        a = 2 * math.pi * i / lugs
        lug = box(name + f"_lug{i}", (w * 0.9, r * 0.12, r * 0.06),
                  (at[0], at[1] + math.cos(a) * r * 0.97, at[2] + math.sin(a) * r * 0.97), tyre_mat)
        lug.rotation_euler = (a - math.pi / 2, 0, 0)  # its thin side points out from the axle
        parts.append(lug)
    return settle(join(name, parts), at)


def bar(name, p0, p1, r, mat, verts=8):
    """A round rod from p0 to p1: rails, posts, pillars, struts."""
    a, b = Vector(p0), Vector(p1)
    o = cyl(name, r, (b - a).length, (a + b) / 2, mat, verts)
    o.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    return o
