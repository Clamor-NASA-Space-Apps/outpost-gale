"""Rig maths for forge/hero_astronaut.py: rest data of an armature, forward kinematics on plain pose
dictionaries, retargeting clips between two armatures with the same bone names, edits made in armature
space (turn a bone about its head), and the measures a suited gait is checked against.

A pose is {bone: (Quaternion, Vector)}: the bone's local rotation and location, exactly what Blender keys
as rotation_quaternion and location. Armature space is Blender's (Z up, the model faces -Y).
"""
import math
import re

import bpy
from bpy_extras import anim_utils
from mathutils import Matrix, Quaternion, Vector


class Rig:
    """Rest data of one armature, read once, so poses can be solved without touching the scene."""

    def __init__(self, arm):
        bones = arm.data.bones
        self.names = sorted((b.name for b in bones), key=lambda n: len(bones[n].parent_recursive))
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in bones}
        self.rest = {b.name: b.matrix_local.copy() for b in bones}
        self.rel = {n: (self.rest[p].inverted() @ self.rest[n]) if p else self.rest[n].copy()
                    for n, p in self.parent.items()}
        self.relq = {n: m.to_quaternion() for n, m in self.rel.items()}

    def fk(self, pose):
        """Armature-space matrix of every bone for a pose (Blender: parent @ rest offset @ T(loc) @ R(rot))."""
        out = {}
        for n in self.names:
            q, t = pose.get(n, (Quaternion(), Vector()))
            m = self.rel[n] @ Matrix.Translation(t) @ q.to_matrix().to_4x4()
            p = self.parent[n]
            out[n] = out[p] @ m if p else m
        return out

    def turn(self, pose, mats, bone, rot):
        """Turn `bone` about its head by `rot` (a Quaternion in armature space); its children follow.
        `mats` is fk(pose) from before the turn: only the bone's parent frame is read from it."""
        p = self.parent[bone]
        frame = (mats[p].to_quaternion() if p else Quaternion()) @ self.relq[bone]
        q, t = pose[bone]
        pose[bone] = ((frame.inverted() @ rot @ frame) @ q, t)

    def shift(self, pose, mats, bone, d):
        """Move `bone` (a root-chain bone such as the pelvis) by `d` in armature space."""
        p = self.parent[bone]
        frame = (mats[p].to_quaternion() if p else Quaternion()) @ self.relq[bone]
        q, t = pose[bone]
        pose[bone] = (q, t + frame.inverted() @ d)


def channels(action):
    """{bone: {(prop, index): fcurve}} for an imported action (Blender 5 keeps fcurves in slot channelbags)."""
    bag = anim_utils.action_get_channelbag_for_slot(action, action.slots[0])
    out = {}
    for fc in bag.fcurves:
        m = re.match(r'pose\.bones\["(.+)"\]\.(\w+)', fc.data_path)
        if m:
            out.setdefault(m[1], {})[(m[2], fc.array_index)] = fc
    return out


def sample(ch, frame):
    """The pose of an action at a (fractional) frame."""
    pose = {}
    for b, fcs in ch.items():
        q = [fcs[("rotation_quaternion", i)].evaluate(frame) if ("rotation_quaternion", i) in fcs else (1, 0, 0, 0)[i]
             for i in range(4)]
        t = [fcs[("location", i)].evaluate(frame) if ("location", i) in fcs else 0.0 for i in range(3)]
        pose[b] = (Quaternion(q).normalized(), Vector(t))
    return pose


def retarget(src, dst, pose, k):
    """Move a pose from the `src` rig to `dst` so every bone points where the source bone points, whatever
    each rig's rest pose is: local rotation q' = A'^-1 A q, with A each bone's rest turn from its parent.
    Locations scale by `k` (dst size / src size)."""
    out = {}
    for n in dst.names:
        q, t = pose.get(n, (Quaternion(), Vector()))
        c = dst.relq[n].inverted() @ src.relq[n] if n in src.relq else Quaternion()
        out[n] = (c @ q, c @ (t * k))
    return out


def write_action(arm, rig, name, poses, times):
    """One action holding `poses` keyed at `times` (frames, may be fractional), linear, every bone on
    every key: the glTF export would otherwise drop unkeyed bones back to the rest (T) pose."""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    slot = act.slots.new(id_type="OBJECT", name=arm.name)
    bag = anim_utils.action_ensure_channelbag_for_slot(act, slot)
    prev = {}
    for p in poses:  # keep each quaternion in the hemisphere of the one before, or a key flips the long way round
        for n, (q, t) in p.items():
            if n in prev and prev[n].dot(q) < 0:
                q = -q
                p[n] = (q, t)
            prev[n] = q
    for n in rig.names:
        for prop, size, get in (("rotation_quaternion", 4, lambda p: p[0]), ("location", 3, lambda p: p[1])):
            for i in range(size):
                fc = bag.fcurves.new(f'pose.bones["{n}"].{prop}', index=i)
                fc.keyframe_points.add(len(poses))
                co = []
                for f, p in zip(times, poses):
                    co += (f, get(p[n])[i])
                fc.keyframe_points.foreach_set("co", co)
                for kp in fc.keyframe_points:
                    kp.interpolation = "LINEAR"
                fc.update()
    return act, slot


def angle_between(a, b):
    return math.degrees(a.angle(b)) if a.length and b.length else 0.0


def bone_dir(mats, n):
    return (mats[n].to_3x3() @ Vector((0, 1, 0))).normalized()


def knee_flex(mats, side):
    return angle_between(bone_dir(mats, "thigh_" + side), bone_dir(mats, "calf_" + side))


def sole_points(rig, side, sole):
    """Points under the boot (heel, ball, toe) in the foot bone's rest space, from armature-space `sole`."""
    inv = rig.rest["foot_" + side].inverted()
    return [inv @ Vector(p) for p in sole]


def sole_world(mats, side, pts):
    m = mats["foot_" + side]
    return [m @ p for p in pts]


def yaw_only(q):
    """The heading part of a rotation: what a foot flat on the floor keeps of its turn."""
    f = q @ Vector((0, -1, 0))  # Rz(a) turns (0, -1, 0) to (sin a, -cos a, 0)
    return Quaternion((0, 0, 1), math.atan2(f.x, -f.y)) if (f.x or f.y) else Quaternion()
