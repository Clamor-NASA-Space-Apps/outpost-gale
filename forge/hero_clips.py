"""The hero's clips, made on the fitted UAL rig (forge/hero_astronaut.py) and measured against the sheet
(data/reality.json hero.*). walk and lope plant their boots by IK on a stance and swing path (exact speed,
no sliding, knees capped), with arm swing and spine from UAL's Walk_Loop; drive_sit is UAL's Driving_Loop;
idle, the hop, interact and carry are keyed from poses. UAL's own jog bends the knee 125 degrees, its jump
is a tucked running leap and its idle a 0.4 m staggered stance: none of them a suit's. Writes data/clips.json.
"""
import json
import math

import bpy
from mathutils import Quaternion, Vector

import hero_rig as R

FPS = 30
SRC_FPS = 24  # the glTF importer keys UAL at the scene's default rate
LEG_K = (0.86 - 0.12) / (0.932 - 0.104)  # our hip-to-ankle over UAL's: scales the pelvis travel
# Sheet values (data/reality.json): walk 1.0 m/s at 1.5 steps/s, hurry 1.6 m/s at 1.75 steps/s,
# knee swing peak 28 degrees, feet 0.25 m apart walking, hop 0.63 s in the air, work height 1.1 m.
WALK = dict(speed=1.0, cadence=1.5)
LOPE = dict(speed=1.6, cadence=1.75)
KNEE_CAP, STANCE, AIR, WORK = 28.0, 0.25, 0.63, 1.10
STAND_WIDTH = 0.33  # standing suited: 0.355 m (Cullinane 2017, design/research/suit.md)
SOLE = {s: [(x, 0.11, 0.0), (x, -0.07, 0.0), (x, -0.25, 0.0)] for s, x in (("l", 0.225), ("r", -0.225))}
SIDES = (("l", 1), ("r", -1))


def rx(deg):
    return Quaternion((1, 0, 0), math.radians(deg))


def ry(deg):
    return Quaternion((0, 1, 0), math.radians(deg))


def lean_of(m):
    """Forward lean of the torso in degrees: the hips-to-neck line against the vertical."""
    d = m["neck_01"].translation - m["pelvis"].translation
    return math.degrees(math.atan2(-d.y, d.z))


def smooth(t):
    return t * t * (3 - 2 * t)


class Maker:
    def __init__(self, arm, src):
        self.arm, self.src, self.rig = arm, src, R.Rig(arm)
        self.sole = {s: R.sole_points(self.rig, s, SOLE[s]) for s, _ in SIDES}
        self.report = {}

    # Poses
    def zero(self):
        return {n: (Quaternion(), Vector()) for n in self.rig.names}

    def aim(self, pose, bone, d):
        """Turn `bone` so it points along `d` (armature space)."""
        m = self.rig.fk(pose)
        self.rig.turn(pose, m, bone, R.bone_dir(m, bone).rotation_difference(Vector(d).normalized()))

    def turn(self, pose, bone, q):
        self.rig.turn(pose, self.rig.fk(pose), bone, q)

    def head(self, pose, bone):
        return self.rig.fk(pose)[bone].translation

    def ik(self, pose, upper, lower, end, target, pole):
        """Two-bone IK: `upper` and `lower` turned so the head of `end` lands on `target`, bent toward `pole`."""
        s = self.head(pose, upper)
        a = (self.head(pose, lower) - s).length
        b = (self.head(pose, end) - self.head(pose, lower)).length
        d = Vector(target) - s
        dist = min(d.length, (a + b) * 0.9999)
        cos_a = (a * a + dist * dist - b * b) / (2 * a * dist)
        axis = d.normalized()
        bend = (Vector(pole) - axis * Vector(pole).dot(axis)).normalized()
        joint = s + axis * (a * cos_a) + bend * (a * math.sqrt(max(0.0, 1 - cos_a * cos_a)))
        self.aim(pose, upper, joint - s)
        self.aim(pose, lower, s + axis * dist - joint)

    def reach(self, pose, side, target, pole):
        self.ik(pose, "upperarm_" + side, "lowerarm_" + side, "hand_" + side, target, pole)

    def stand(self, knee=6.0, width=STAND_WIDTH, lean=4.0, arm_out=22.0, arm_fwd=14.0, elbow=25.0):
        """A suited stand: feet apart, knees soft, a little forward lean, arms off the body and in front."""
        p = self.zero()
        for s, sx in SIDES:
            hip = self.head(p, "thigh_" + s)
            foot = Vector((sx * width / 2, hip.y + 0.01, 0.12))
            leg = foot - hip
            half = math.radians(knee) / 2
            self.aim(p, "thigh_" + s, Quaternion((1, 0, 0), -half) @ leg)  # thigh tips forward,
            self.aim(p, "calf_" + s, Quaternion((1, 0, 0), half) @ leg)  # shin tips back: the knee bends
        self.turn(p, "spine_01", rx(lean))
        self.arms(p, arm_out, arm_fwd, elbow)
        return p

    def arms(self, p, out, fwd, elbow):
        for s, sx in SIDES:
            down = Vector((sx * math.sin(math.radians(out)), -math.sin(math.radians(fwd)), -1)).normalized()
            m = self.rig.fk(p)
            chest = m["spine_03"].to_quaternion() @ self.rig.rest["spine_03"].to_quaternion().inverted()
            self.aim(p, "upperarm_" + s, chest @ down)
            fore = Quaternion(chest @ Vector((1, 0, 0)), -math.radians(elbow)) @ (chest @ down)
            self.aim(p, "lowerarm_" + s, fore)
            self.aim(p, "hand_" + s, fore)

    def blend(self, a, b, t):
        return {n: (a[n][0].slerp(b[n][0], t), a[n][1].lerp(b[n][1], t)) for n in self.rig.names}

    def keyed(self, keys, n):
        """Poses at n+1 even times through key poses [(time 0..1, pose)], eased between keys."""
        out = []
        for i in range(n + 1):
            t = i / n
            j = max(k for k in range(len(keys)) if keys[k][0] <= t + 1e-9)
            if j == len(keys) - 1:
                out.append({k: (q.copy(), v.copy()) for k, (q, v) in keys[j][1].items()})
                continue
            (t0, a), (t1, b) = keys[j], keys[j + 1]
            out.append(self.blend(a, b, smooth((t - t0) / (t1 - t0))))
        return out

    # Feet and ground
    def soles(self, m, s):
        return R.sole_world(m, s, self.sole[s])

    def lowest(self, m):
        return min(p.z for s, _ in SIDES for p in self.soles(m, s))

    def ground(self, poses):
        """The lower boot rests on the floor in every pose."""
        for p in poses:
            m = self.rig.fk(p)
            self.rig.shift(p, m, "pelvis", Vector((0, 0, -self.lowest(m))))

    def flatten(self, poses, lo=0.03, hi=0.10):
        """Boots near the floor turn flat on it (Apollo's flat-footed walk); in the air they keep the clip's angle."""
        for p in poses:
            m = self.rig.fk(p)
            floor = self.lowest(m)
            for s, _ in SIDES:
                h = min(q.z for q in self.soles(m, s)) - floor
                w = 1 - smooth(min(1.0, max(0.0, (h - lo) / (hi - lo))))
                if w <= 0:
                    continue
                rf = m["foot_" + s].to_quaternion()
                rf0 = self.rig.rest["foot_" + s].to_quaternion()
                d = rf @ rf0.inverted()
                target = d.slerp(R.yaw_only(d), w) @ rf0
                self.rig.turn(p, m, "foot_" + s, target @ rf.inverted())

    # Gait edits
    def swing(self, poses, bone, factor):
        """Scale a bone's fore-aft swing about its mean over the cycle."""
        pitch = [math.atan2(-d.y, -d.z) for d in (R.bone_dir(self.rig.fk(p), bone) for p in poses)]
        mean = sum(pitch) / len(pitch)
        for p, a in zip(poses, pitch):
            self.turn(p, bone, Quaternion((1, 0, 0), -(factor - 1) * (a - mean)))

    def gait_arms(self, poses, out, fwd, swing):
        self.swing(poses, "upperarm_l", swing)
        self.swing(poses, "upperarm_r", swing)
        for p in poses:
            self.turn(p, "upperarm_l", ry(-out) @ rx(-fwd))
            self.turn(p, "upperarm_r", ry(out) @ rx(-fwd))

    def source(self, ch, length, n):
        """n poses evenly through one cycle of a UAL action (`length` in source frames), retargeted."""
        return [R.retarget(self.src, self.rig, R.sample(ch, i / n * length), LEG_K) for i in range(n)]

    # Measures
    def measure(self, poses, period, speed):
        """Per foot: touchdown phases (rising edge of low and still), share of the cycle down, ground speed
        while down; plus knee peak, stance width, foot lift, hip travel, flight share."""
        n = len(poses)
        mats = [self.rig.fk(p) for p in poses]
        dt = period / n
        out = {"lean": round(sum(map(lean_of, mats)) / n, 1), "knee_peak": round(max(R.knee_flex(m, s) for m in mats for s, _ in SIDES), 1),
               "stance_width": round(sum(m["foot_l"].translation.x - m["foot_r"].translation.x for m in mats) / n, 3),
               "hip_travel": round(max(m["pelvis"].translation.z for m in mats) - min(m["pelvis"].translation.z for m in mats), 3)}
        floor = [self.lowest(m) for m in mats]
        down_any = [False] * n
        for s, _ in SIDES:
            mid = [self.soles(m, s)[1] for m in mats]
            h = [min(q.z for q in self.soles(m, s)) for m in mats]
            vel = []
            for i in range(n):  # forward difference: a boot that lands on frame i is still from i on
                vel.append((mid[(i + 1) % n] - mid[i]) / dt)
            down = [h[i] - min(floor) < 0.02 and (vel[i] - Vector((0, speed, 0))).length < 0.3 for i in range(n)]
            touch = [i for i in range(n) if down[i] and not down[(i - 1) % n]]
            vs = [vel[i].y for i in range(n) if down[i]]
            out["foot_" + s] = {"touchdown": [round(i / n, 3) for i in touch], "down_share": round(sum(down) / n, 2),
                                "ground_speed": round(sum(vs) / len(vs), 3) if vs else 0.0,
                                "slide_max": round(max((abs(v - speed) for v in vs), default=0.0), 3),
                                "lift": round(max(h) - min(floor), 3)}
            down_any = [x or y for x, y in zip(down_any, down)]
        out["flight_share"] = round(1 - sum(down_any) / n, 2)
        return out

    # Output
    def write(self, name, poses, period, loop):
        """Keys at even times over `period` seconds; a loop repeats its first pose as its last key."""
        if loop:
            poses = poses + [poses[0]]
        n = len(poses) - 1
        times = [i * period * FPS / n for i in range(n + 1)]
        R.write_action(self.arm, self.rig, name, poses, times)

    def leg_reach(self, knee):
        """Hip to ankle distance with the knee bent `knee` degrees."""
        r = self.rig.rest
        a = (r["calf_l"].translation - r["thigh_l"].translation).length
        b = (r["foot_l"].translation - r["calf_l"].translation).length
        return math.sqrt(a * a + b * b + 2 * a * b * math.cos(math.radians(knee)))

    def gait(self, name, ch, src_len, spec, duty, knee_stance, knee_bounce, lift, lean, arms, ahead=0.4):
        """A gait whose boots are planted: each ankle follows a path (stance: flat on the floor, moving back at
        exactly the gait's speed; swing: forward in a low arc, heel up at toe-off), the hips ride on the stance
        leg with its knee at `knee_stance` (+ `knee_bounce` at mid-stance), knees are solved and held under
        KNEE_CAP by keeping the swing boot low, and when no boot is down the hips fly a Mars-gravity arc.
        Arm swing, spine and head come from a UAL walk sampled over the same cycle (its left heel strikes at 0)."""
        period = 2 / spec["cadence"]
        n = round(period * FPS)
        v = spec["speed"]
        span = v * duty * period  # how far a planted boot travels back under the body
        poses = self.source(ch, src_len, n)
        for p in poses:
            q, t = p["pelvis"]
            p["pelvis"] = (Quaternion().slerp(q, 0.5), Vector())  # a stiff suit halves the hip sway
        now = sum(lean_of(self.rig.fk(p)) for p in poses) / n
        for p in poses:
            self.turn(p, "spine_01", rx(lean - now))
        self.gait_arms(poses, *arms)
        hip_y = self.rig.rest["thigh_l"].translation.y
        rest_ankle = self.rig.rest["foot_l"].translation
        off = Vector((0, rest_ankle.y - SOLE["l"][2][1], rest_ankle.z))  # ankle seen from the toe tip
        heel = Vector((0, SOLE["l"][0][1] - rest_ankle.y, -rest_ankle.z))  # heel and toe seen from the ankle
        toe = Vector((0, SOLE["l"][2][1] - rest_ankle.y, -rest_ankle.z))
        late = 0.14  # the last part of stance, where the boot may roll onto its toe

        def ankle_floor(pitch):
            q = rx(pitch)
            return max(-(q @ heel).z, -(q @ toe).z) + 0.004

        tip_y = hip_y - off.y - span * ahead  # where the toe tip lands, flat: the ankle `ahead` of the hip, the rest of the travel behind
        reach = self.leg_reach(knee_stance)
        cap = self.leg_reach(KNEE_CAP)

        def phase(i, s):
            return (i / n + (0.0 if s == "l" else 0.5)) % 1.0

        def stance_tip(s, f):
            return Vector((dict(SIDES)[s] * STANCE / 2, tip_y + v * f * period, 0.0))

        # 1. Hip height from the legs in early and mid stance (flat boot, knee at knee_stance, plus a bounce in
        # the lope); between them, where only a boot rolling onto its toe or none is down, a smooth arc that
        # adds a Mars-gravity flight (g = 3.73) when no boot touches at all.
        z, airborne = [None] * n, [False] * n
        for i, p in enumerate(poses):
            m = self.rig.fk(p)
            hz = []
            for s, _ in SIDES:
                f = phase(i, s)
                if f < duty - late:
                    h, A = m["thigh_" + s].translation, stance_tip(s, f) + off
                    d = self.leg_reach(knee_stance + knee_bounce * math.sin(math.pi * f / duty))
                    hz.append(A.z + math.sqrt(max(0.0, d * d - (A.x - h.x) ** 2 - (A.y - h.y) ** 2)) + m["pelvis"].translation.z - h.z)
            z[i] = min(hz) if hz else None
            airborne[i] = all(phase(i, s) >= duty for s, _ in SIDES)
        dt = period / n
        for i in range(n):
            if z[i] is None:
                a = next(k for k in range(1, n) if z[(i - k) % n] is not None)
                b = next(k for k in range(1, n) if z[(i + k) % n] is not None)
                z0, z1, u = z[(i - a) % n], z[(i + b) % n], a / (a + b)
                fly = sum(airborne[(i - a + k) % n] for k in range(a + b)) * dt
                z[i] = z0 + (z1 - z0) * u + 0.5 * 3.73 * fly * fly * u * (1 - u)
        for i, p in enumerate(poses):
            m = self.rig.fk(p)
            self.rig.shift(p, m, "pelvis", Vector((0, 0, z[i] - m["pelvis"].translation.z)))

        # 2. Boots in stance: flat, then rolled onto the toe tip as far as the leg needs to reach it (heel-off)
        plan = [{} for _ in range(n)]
        end_pitch = {}
        for i, p in enumerate(poses):
            m = self.rig.fk(p)
            for s, _ in SIDES:
                f = phase(i, s)
                if f >= duty:
                    continue
                tip, h = stance_tip(s, f), m["thigh_" + s].translation
                lo, hi = 0.0, 60.0
                if (tip + off - h).length > reach:
                    for _ in range(30):
                        mid = (lo + hi) / 2
                        lo, hi = (mid, hi) if (tip + rx(mid) @ off - h).length > reach else (lo, mid)
                pitch = hi if (tip + off - h).length > reach else 0.0
                plan[i][s] = dict(ank=tip + rx(pitch) @ off, pitch=pitch, down=True)
                if phase((i + 1) % n, s) >= duty:
                    end_pitch[s] = pitch

        # 3. Swing: the boot leaves at its rolled angle and comes forward low and flat (lift, but never under
        # the floor and never with the knee past KNEE_CAP: a toe-up before landing broke the cap), landing flat
        for i, p in enumerate(poses):
            m = self.rig.fk(p)
            for s, sx in SIDES:
                f = phase(i, s)
                if f < duty:
                    continue
                u = (f - duty) / (1 - duty)
                pitch = end_pitch[s] * (1 - smooth(min(1.0, u / 0.3)))  # the heel drops early: a tipped boot needs room under the hips
                tip = Vector((sx * STANCE / 2, tip_y + span - span * smooth(u), lift * math.sin(math.pi * u) * (1 - 0.5 * u)))
                A, h = tip + rx(pitch) @ off, m["thigh_" + s].translation
                dxy2 = (A.x - h.x) ** 2 + (A.y - h.y) ** 2
                A.z = max(ankle_floor(pitch), min(A.z, h.z - math.sqrt(max(0.0, cap * cap - dxy2))))
                plan[i][s] = dict(ank=A, pitch=pitch, down=False)

        # 4. Solve the legs and turn the boots
        for i, p in enumerate(poses):
            for s, sx in SIDES:
                L = plan[i][s]
                self.ik(p, "thigh_" + s, "calf_" + s, "foot_" + s, L["ank"], Vector((sx * 0.15, -1, 0)))
                mf = self.rig.fk(p)
                rf, rf0 = mf["foot_" + s].to_quaternion(), self.rig.rest["foot_" + s].to_quaternion()
                self.rig.turn(p, mf, "foot_" + s, rx(L["pitch"]) @ rf0 @ rf.inverted())
        got = self.measure(poses, period, v)
        got.update(speed=v, cadence=spec["cadence"], stride=round(v * period, 3), duty=duty)
        self.write(name, poses, period, True)
        self.report[name] = dict(length=round(period, 4), loop=True, **got)
        return poses

    def clip(self, name, poses, period, loop, **extra):
        self.write(name, poses, period, loop)
        mats = [self.rig.fk(p) for p in poses]
        self.report[name] = dict(length=round(period, 4), loop=loop,
                                 knee_peak=round(max(R.knee_flex(m, s) for m in mats for s, _ in SIDES), 1),
                                 lean=[round(min(map(lean_of, mats)), 1), round(max(map(lean_of, mats)), 1)], **extra)


def make_all(arm, src, json_path):
    ual = {a.name: a for a in bpy.data.actions}  # UAL1's, imported with the rig
    bpy.context.scene.render.fps = FPS
    mk = Maker(arm, src)
    ch = {k: R.channels(a) for k, a in ual.items() if k in ("Walk_Loop", "Driving_Loop")}

    stand = mk.stand()
    mk.ground([stand])

    # idle: one slow breath (15 a minute), chest and shoulders rise, a small weight shift, the head looks about
    n = 4 * FPS
    poses = []
    for i in range(n):
        a = 2 * math.pi * i / n
        p = {k: (q.copy(), v.copy()) for k, (q, v) in stand.items()}
        mk.turn(p, "spine_03", rx(-1.6 * math.sin(a)))
        mk.turn(p, "clavicle_l", ry(-1.5 * math.sin(a)))
        mk.turn(p, "clavicle_r", ry(1.5 * math.sin(a)))
        mk.turn(p, "Head", Quaternion((0, 0, 1), math.radians(4 * math.sin(a + 1.0))))
        mk.rig.shift(p, mk.rig.fk(p), "pelvis", Vector((0.012 * math.sin(a), 0, 0)))
        poses.append(p)
    mk.flatten(poses)
    mk.ground(poses)
    mk.clip("idle", poses, 4.0, True)
    idle = poses

    # walk and lope: duty factors under Earth's (Donelan and Kram 1997: about 10% lower in low gravity); the
    # lope keeps a short flight between steps (Apollo's "floating")
    walk = mk.gait("walk", ch["Walk_Loop"], 32.0, WALK, duty=0.56, knee_stance=8, knee_bounce=0, lift=0.07,
                   lean=7.0, arms=(18, 10, 0.55))
    mk.gait("lope", ch["Walk_Loop"], 32.0, LOPE, duty=0.32, knee_stance=8, knee_bounce=3, lift=0.08,
            lean=12.0, arms=(16, 22, 1.1))

    # hop: a short shallow crouch, both feet, arms swing forward and up; in the air a little tuck; the landing
    # tips back (the backpack) and recovers. hop_air lasts the whole flight; start ends at take-off.
    def pose(knee=6.0, lean=4.0, arm_fwd=14.0, arm_out=22.0, elbow=25.0, width=STAND_WIDTH, toe=0.0, ground=True):
        p = mk.stand(knee=knee, width=width, lean=lean, arm_out=arm_out, arm_fwd=arm_fwd, elbow=elbow)
        if toe:
            for s, _ in SIDES:
                mk.turn(p, "foot_" + s, rx(toe))  # heels up, toes last off the floor
        if ground:
            mk.ground([p])
        return p

    crouch = pose(knee=26, lean=12, arm_fwd=-8, elbow=30)
    take = pose(knee=4, lean=6, arm_fwd=45, elbow=20, toe=12)
    hs = mk.keyed([(0, stand), (0.55, crouch), (1.0, take)], round(0.34 * FPS))
    mk.clip("hop_start", hs, 0.34, False, takeoff_at=0.34)
    tuck = pose(knee=16, lean=6, arm_fwd=55, elbow=25, width=0.28, ground=False)
    reach_down = pose(knee=8, lean=-2, arm_fwd=45, elbow=20, ground=False)
    for p in (tuck, reach_down):  # in the air the hips keep take-off height: the body's arc does the rest
        p["pelvis"] = (p["pelvis"][0], take["pelvis"][1].copy())
    ha = mk.keyed([(0, take), (0.4, tuck), (1.0, reach_down)], round(AIR * FPS))
    mk.clip("hop_air", ha, AIR, False, air_time=AIR)
    touch = pose(knee=8, lean=-2, arm_fwd=45, elbow=20)
    absorb = pose(knee=27, lean=-6, arm_fwd=60, elbow=25)
    over = pose(knee=10, lean=8, arm_fwd=25, elbow=25)
    hl = mk.keyed([(0, touch), (0.25, absorb), (0.6, over), (1.0, stand)], round(0.55 * FPS))
    mk.clip("hop_land", hl, 0.55, False)

    # interact: the right glove reaches forward to the work height and presses, then back
    def work(dy):
        p = pose(lean=8)
        mk.reach(p, "r", (-0.12, -0.62 + dy, WORK), (-1, 0.3, -0.6))
        mk.aim(p, "hand_r", Vector((0, -1, -0.1)))
        return p
    out1, out2 = work(0.0), work(-0.04)
    mk.clip("interact", mk.keyed([(0, stand), (0.3, out1), (0.5, out2), (0.62, out1), (1.0, stand)], round(1.6 * FPS)),
            1.6, False, reach_height=WORK)

    # carry: both gloves on the sides of a 0.5 m bag held in front of the chest unit
    def carry(p):
        m = mk.rig.fk(p)
        chest = m["spine_03"]
        rest_chest = mk.rig.fk(stand)["spine_03"]
        for s, sx in SIDES:
            target = chest @ rest_chest.inverted() @ Vector((sx * 0.27, -0.46, 1.10))
            mk.reach(p, s, target, (sx, 0.4, -0.5))
            mk.aim(p, "hand_" + s, chest.to_quaternion() @ rest_chest.to_quaternion().inverted() @ Vector((-sx * 0.3, -1, 0)))
        return p
    ci = [carry({k: (q.copy(), v.copy()) for k, (q, v) in p.items()}) for p in idle]
    mk.clip("carry_idle", ci, 4.0, True, bag=[0.5, 0.42, 0.27], bag_bone="spine_03",
            bag_center_godot=[0.0, 1.10, 0.46])  # between the gloves, in the standing pose
    cw = [carry({k: (q.copy(), v.copy()) for k, (q, v) in p.items()}) for p in walk]
    period = 2 / WALK["cadence"]
    mk.write("carry_walk", cw, period, True)
    got = mk.measure(cw, period, WALK["speed"])
    mk.report["carry_walk"] = dict(length=round(period, 4), loop=True, speed=WALK["speed"], **got)

    # drive_sit: UAL's seated driving loop, hips and hands as they come
    d = mk.source(ch["Driving_Loop"], 40.0, round(40 / SRC_FPS * FPS))
    mk.clip("drive_sit", d, 40 / SRC_FPS, True, seat_hip=[round(x, 3) for x in mk.rig.fk(d[0])["pelvis"].translation])

    for a in list(bpy.data.actions):  # only our clips ship
        if a.name not in mk.report:
            bpy.data.actions.remove(a)
    feet = {"left": "foot_l", "right": "foot_r", "ankle_height_planted": round(mk.rig.rest["foot_l"].translation.z, 3),
            "facing": "+Z in Godot (-Y in Blender); gait clips run in place"}
    data = {"_about": "Outpost Gale hero clips, made by forge/hero_astronaut.py. length in seconds; speed is the ground speed "
                      "a gait was made for (m/s); foot_l and foot_r touchdown are the phases (0..1 of the clip) where each "
                      "boot lands: lowest and still (sole within 2 cm of the floor, moving back at the gait speed within "
                      "0.3 m/s). A planted foot bone (the ankle) sits at ankle_height_planted. Measured from the clips, not typed.",
            "feet": feet, "clips": mk.report}
    with open(json_path, "w") as f:
        json.dump(data, f, indent=1)
    for k, v in mk.report.items():
        print("CLIP", k, json.dumps(v))

