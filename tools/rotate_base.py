# One-off: turn the whole base as one rigid group about HAB 1 (the origin), by one angle, in the data files.
#   python3 -I tools/rotate_base.py --deg -99
# Ravindu, 14 Nov: "rotate the entire base to the point where going outside of the doors can see the dawn. same
# layout, just the stuff rotated." -99 deg turns HAB 1's door (yaw 180, south) to bearing 81, the sunrise at Sol 1's
# dawn (data/cine.json opening). Angles are bearings, clockwise from north (-Z), as world.json `yaw` is.
# The solar field moves as a block, rows unturned (see FIELD below). What turns: every base placement (items, landmarks, PIP's stops and via points, cables, walkways, the probe, the
# rocks' centre), every world spot in data/beats.json and data/sols.json, the cine's ground points and launch
# bearing, and sandbox.gd's preset views. What does not: the terrain, the sun and sky, the wind and the dust devils'
# crater circles (real Gale), and the far field sites (`sites`, their items and landmarks: real km and bearings).
# Item-space data (starts, rooms, views, uses, probes' rooms) follows its item. Only the rewritten arrays change text.
import json, math, re, sys

deg = float(sys.argv[sys.argv.index("--deg") + 1])
C, S = math.cos(math.radians(deg)), math.sin(math.radians(deg))
SITE_ITEMS = {"curiosity", "mercou"}
SITE_MARKS = {"curiosity", "mercou"}


def rot(x, z):  # a bearing turn by deg: x = r sin b, z = -r cos b
    return x * C - z * S, x * S + z * C


# The solar field moves as a block: single-axis trackers face the real sun, so their rows must keep running
# north-south; a field can turn only by 0 or 180 deg, and 180 is the nearer to the base's turn. It turns 180 about
# its entrance (PIP's solar stop), which lands where the base's turn puts it, so the walk from the base to the field
# keeps its length and the field still opens toward the base. Anything of the field (its rows, their cables, PIP's
# solar stop, the beats' spots there) is a point inside FIELD in the old layout.
FIELD = (19.5, 72.0, 0.0, 56.0)  # x0, x1, z0, z1 of the old layout
ENTRY = (20.0, 3.0)  # PIP's solar stop
EN = rot(*ENTRY)


def in_field(x, z):
    return FIELD[0] <= x <= FIELD[1] and FIELD[2] <= z <= FIELD[3]


def turn(x, z):
    if in_field(x, z):
        return EN[0] + ENTRY[0] - x, EN[1] + ENTRY[1] - z
    return rot(x, z)


def num(v):
    v = round(v, 3)
    return int(v) if v == int(v) else v


def parse(s, i=0):
    """A JSON value at s[i:] as (value, start, end), arrays and objects with their children's spans."""
    while s[i] in " \t\r\n":
        i += 1
    c = s[i]
    if c == "{":
        out, j = {}, i + 1
        while True:
            while s[j] in " \t\r\n,":
                j += 1
            if s[j] == "}":
                return (out, i, j + 1)
            key, _, j = parse(s, j)
            while s[j] in " \t\r\n:":
                j += 1
            out[key[0] if isinstance(key, tuple) else key] = parse(s, j)
            j = out[key[0] if isinstance(key, tuple) else key][2]
    if c == "[":
        out, j = [], i + 1
        while True:
            while s[j] in " \t\r\n,":
                j += 1
            if s[j] == "]":
                return (out, i, j + 1)
            out.append(parse(s, j))
            j = out[-1][2]
    if c == '"':
        j = i + 1
        while s[j] != '"':
            j += 2 if s[j] == "\\" else 1
        return (json.loads(s[i:j + 1]), i, j + 1)
    m = re.compile(r"-?\d+(\.\d+)?([eE][-+]?\d+)?|true|false|null").match(s, i)
    return (json.loads(m.group(0)), i, m.end())


def plain(n):
    v = n[0]
    if isinstance(v, dict):
        return {k: plain(x) for k, x in v.items()}
    if isinstance(v, list):
        return [plain(x) for x in v]
    return v


class File:
    def __init__(self, path):
        self.path, self.text = path, open(path).read()
        self.root = parse(self.text)
        self.edits = []

    def set(self, node, value):
        self.edits.append((node[1], node[2], json.dumps(value)))

    def save(self):
        t = self.text
        for a, b, v in sorted(self.edits, reverse=True):
            t = t[:a] + v + t[b:]
        json.loads(t)
        open(self.path, "w").write(t)
        print(self.path, len(self.edits), "rewritten")


def xz(node, i=(0, 1)):  # [x, z, ...] with x and z at indices i, turned
    v = plain(node)
    v[i[0]], v[i[1]] = (num(a) for a in turn(v[i[0]], v[i[1]]))
    return v


# world.json
w = File("data/world.json")
r = w.root[0]
for it in r["items"][0]:
    o = it[0]
    if o["id"][0] in SITE_ITEMS:
        continue
    field = in_field(*plain(o["pos"]))
    w.set(o["pos"], xz(o["pos"]))
    if "yaw" in o:
        w.set(o["yaw"], num((o["yaw"][0] + (180.0 if field else deg)) % 360))
for k, m in r["landmarks"][0].items():
    if k.startswith("site_") or k in SITE_MARKS or k.startswith("_"):
        continue
    v = xz(m)
    if len(v) > 2:
        v[2] = num((v[2] + (180.0 if in_field(*plain(m)[:2]) else deg)) % 360)
    w.set(m, v)
for st in r["pip"][0]["stops"][0]:
    w.set(st[0]["at"], xz(st[0]["at"]))
    w.set(st[0]["look"], xz(st[0]["look"]))
for v in r["pip"][0]["via"][0]:
    w.set(v, xz(v))
for line in r["cables"][0]["lines"][0] + r["paths"][0]["lines"][0]:
    w.set(line, [xz(p) for p in line[0]])
w.set(r["probe"][0]["pos"], xz(r["probe"][0]["pos"]))
w.set(r["scatter"][0]["centre"], xz(r["scatter"][0]["centre"]))
w.save()


# beats.json and sols.json: a world spot is [x, z] or [x, z, height] under these keys
SPOT_KEYS = {"at", "go_to", "follow_me", "point_at", "spot"}


def spots(f, node, key=None):
    v = node[0]
    if isinstance(v, dict):
        for k, x in v.items():
            if k == "starts":  # item space: follows its item
                continue
            spots(f, x, k)
    elif isinstance(v, list):
        if key in SPOT_KEYS and v and all(isinstance(e[0], (int, float)) and not isinstance(e[0], bool) for e in v) and len(v) in (2, 3):
            f.set(node, xz(node))
        else:
            for x in v:
                spots(f, x, None)


for path in ["data/beats.json", "data/sols.json"]:
    f = File(path)
    spots(f, f.root)
    f.save()

# cine.json: the drone's ground points [x, y over ground, z], the shots' 'ground' refs, the launch camera's bearing
c = File("data/cine.json")
cr = c.root[0]
for k in ["from", "to", "at", "at_to"]:
    c.set(cr["sleep"][0]["drone"][0][k], xz(cr["sleep"][0]["drone"][0][k], (0, 2)))
c.set(cr["launch"][0]["out_bearing"], num((cr["launch"][0]["out_bearing"][0] + deg) % 360))


def refs(node):
    v = node[0]
    if isinstance(v, dict):
        for x in v.values():
            refs(x)
    elif isinstance(v, list):
        if len(v) == 2 and v[0][0] == "ground" and isinstance(v[1][0], list):
            c.set(v[1], xz(v[1], (0, 2)))
        else:
            for x in v:
                refs(x)


refs(cr["shots"])
c.save()

# sandbox.gd's preset views: Vector3(x, y, z) pairs in the VIEWS table, world metres
p = "sandbox/sandbox.gd"
t = open(p).read()
a = t.index("const VIEWS := {")
b = t.index("\n}", a)


def vec(m):
    x, y, z = (float(m.group(i)) for i in (1, 2, 3))
    x, z = turn(x, z)
    return "Vector3(%s, %s, %s)" % (num(x), num(y), num(z))


t = t[:a] + re.sub(r"Vector3\((-?[\d.]+), (-?[\d.]+), (-?[\d.]+)\)", vec, t[a:b]) + t[b:]
open(p, "w").write(t)
print(p, "VIEWS turned")
