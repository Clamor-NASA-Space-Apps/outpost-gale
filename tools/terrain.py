# Real Gale ground for the game, from two public elevation sets, in one run:
#   data/terrain.json           the walkable patch heights (the one height source: collision and height queries read it)
#   data/terrain_normal.png     the patch's surface direction at the full 1 m HiRISE detail (world space:
#                               R = x, G = z, B = y, each 0.5 + n / 2), so a 2 m mesh shades like a 1 m one
#   models/terrain_backdrop.glb the skyline out to 60 km, squeezed toward the player (see squeeze())
# usage: python3 -I tools/terrain.py <hirise.npy> <mola_lines385-896.bin>
#   hirise.npy: HiRISE DTEEC_018854_1755_018920_1755 window round the site (design/research/scripts/cog-window.py)
#   mola bin:   MOLA MEGDR 128 px/deg tile megt00n090hb.img, lines 385 to 896 (one HTTP range, 11.8 MB)
# Axes: +X east, -Z north, Y up, metres. Heights are relative to the patch centre.
import json, math, os, struct, sys, zlib
import numpy as np

SITE = (-4.5895, 137.4383)  # 200 m west of Bradbury Landing (design/research/sizes.md, part D)
PATCH, STEP = 400.0, 2.0    # metres across, grid spacing
HIRISE_PX = 1.0117630165416043
R = 3396190.0               # Mars radius (MOLA reference)
SQUEEZE_FROM, SQUEEZE = 250.0, 10.0

args = sys.argv[1:]
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def bilinear(a, r, c):
    r = np.clip(r, 0, a.shape[0] - 1.001); c = np.clip(c, 0, a.shape[1] - 1.001)
    r0, c0 = np.floor(r).astype(int), np.floor(c).astype(int); fr, fc = r - r0, c - c0
    return (a[r0, c0] * (1 - fr) * (1 - fc) + a[r0, c0 + 1] * (1 - fr) * fc
            + a[r0 + 1, c0] * fr * (1 - fc) + a[r0 + 1, c0 + 1] * fr * fc)


# patch: rows run south, columns east, centred on SITE
hi = np.load(args[0])
assert not np.isnan(hi[hi.shape[0] // 2 - 205:hi.shape[0] // 2 + 205, hi.shape[1] // 2 - 205:hi.shape[1] // 2 + 205]).any(), 'gap in the patch'
n = int(PATCH / STEP) + 1
xs = np.arange(n) * STEP - PATCH / 2
rr, cc = np.meshgrid(hi.shape[0] / 2 + xs / HIRISE_PX, hi.shape[1] / 2 + xs / HIRISE_PX, indexing='ij')
H = bilinear(hi, rr, cc)
H -= H[n // 2, n // 2]

def patch_h(x, z):
    return bilinear(H, (z + PATCH / 2) / STEP, (x + PATCH / 2) / STEP)

# skyline: MOLA heights on a local plane, minus the planet's curve
mola = np.fromfile(args[1], '>i2').reshape(-1, 11520).astype(float)
def mola_h(x, z):
    lat = SITE[0] - np.degrees(z / R); lon = SITE[1] + np.degrees(x / (R * math.cos(math.radians(SITE[0]))))
    return bilinear(mola, -lat * 128 - 385, (lon - 90) * 128 - 0.5)
h0 = mola_h(np.array(0.0), np.array(0.0))

def squeeze(r):
    # Beyond SQUEEZE_FROM the world is pulled toward the player by SQUEEZE, and heights with it, so every hill
    # keeps its real angle above the horizon (a 30 km rim lands near 3 km, inside the camera's reach).
    # ponytail: the patch centre is the only place the angles are exact; at the edge of play the rim reads ~5% big
    return np.where(r <= SQUEEZE_FROM, r, SQUEEZE_FROM + (r - SQUEEZE_FROM) / SQUEEZE)

rings = 190.0 * (60000.0 / 190.0) ** (np.arange(64) / 63)
seg = 192
ang = np.arange(seg) / seg * 2 * math.pi
RR, AA = np.meshgrid(rings, ang, indexing='ij')
X, Z = RR * np.sin(AA), -RR * np.cos(AA)  # angle 0 = north
real = mola_h(X, Z) - h0 - RR ** 2 / (2 * R)
# near the patch the backdrop takes the patch's own heights, sunk a little so the patch always draws on top
near = patch_h(np.clip(X, -PATCH / 2, PATCH / 2), np.clip(Z, -PATCH / 2, PATCH / 2)) - 0.3
t = np.clip((RR - 400) / 1100, 0, 1)
Y = near * (1 - t) + real * t
k = squeeze(RR) / RR
BX, BY, BZ = X * k, Y * k, Z * k


def smooth_normals(P):
    """Per-vertex normals of a grid of points [i, j, 3] from its neighbours (the backdrop wraps round in j)."""
    dj = np.roll(P, -1, 1) - np.roll(P, 1, 1)
    di = np.concatenate([P[1:2] - P[0:1], P[2:] - P[:-2], P[-1:] - P[-2:-1]])
    n = np.cross(dj, di)
    n *= np.sign(n[..., 1:2])
    return n / np.linalg.norm(n, axis=-1, keepdims=True)


def glb(path, P, N):
    """One mesh, one material named `terrain` (the game gives it the terrain shader), from a wrapped grid."""
    ni, nj = P.shape[:2]
    idx = np.arange(ni * nj).reshape(ni, nj)
    a, b, c, d = idx[:-1], np.roll(idx[:-1], -1, 1), idx[1:], np.roll(idx[1:], -1, 1)
    tri = np.concatenate([np.stack([a, c, b], -1).reshape(-1, 3), np.stack([b, c, d], -1).reshape(-1, 3)])
    # keep every triangle counter-clockwise seen from above
    v = P.reshape(-1, 3)
    up = np.cross(v[tri[:, 1]] - v[tri[:, 0]], v[tri[:, 2]] - v[tri[:, 0]])[:, 1] < 0
    tri[up] = tri[up][:, [0, 2, 1]]
    bins = b''
    views, accs = [], []
    for arr, comp, typ, target in ((v.astype('<f4'), 5126, 'VEC3', 34962), (N.reshape(-1, 3).astype('<f4'), 5126, 'VEC3', 34962),
                                   (tri.ravel().astype('<u4'), 5125, 'SCALAR', 34963)):
        data = arr.tobytes()
        views.append({'buffer': 0, 'byteOffset': len(bins), 'byteLength': len(data), 'target': target})
        bins += data + b'\0' * ((4 - len(data) % 4) % 4)
        acc = {'bufferView': len(views) - 1, 'componentType': comp, 'count': int(arr.shape[0] if arr.ndim > 1 else arr.size), 'type': typ}
        if len(accs) == 0:
            acc['min'] = v.min(0).tolist(); acc['max'] = v.max(0).tolist()
        accs.append(acc)
    j = {'asset': {'version': '2.0', 'generator': 'outpost terrain.py'}, 'scene': 0, 'scenes': [{'nodes': [0]}],
         'nodes': [{'name': 'backdrop', 'mesh': 0}],
         'meshes': [{'name': 'backdrop', 'primitives': [{'attributes': {'POSITION': 0, 'NORMAL': 1}, 'indices': 2, 'material': 0}]}],
         'materials': [{'name': 'terrain', 'pbrMetallicRoughness': {'baseColorFactor': [0.6, 0.4, 0.3, 1], 'metallicFactor': 0, 'roughnessFactor': 1}}],
         'accessors': accs, 'bufferViews': views, 'buffers': [{'byteLength': len(bins)}]}
    js = json.dumps(j, separators=(',', ':')).encode(); js += b' ' * ((4 - len(js) % 4) % 4)
    body = struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(bins), 0x004E4942) + bins
    open(path, 'wb').write(b'glTF' + struct.pack('<II', 2, 12 + len(body)) + body)
    return len(tri)


def png(path, rgb):
    raw = b''.join(b'\0' + r.tobytes() for r in rgb)
    def ch(t, b):
        return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b))
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + ch(b'IHDR', struct.pack('>IIBBBBB', rgb.shape[1], rgb.shape[0], 8, 2, 0, 0, 0))
                           + ch(b'IDAT', zlib.compress(raw, 9)) + ch(b'IEND', b''))


os.makedirs(f'{root}/models', exist_ok=True); os.makedirs(f'{root}/data', exist_ok=True)
back = np.stack([BX, BY, BZ], -1)
tb = glb(f'{root}/models/terrain_backdrop.glb', back, smooth_normals(back))
# the normal map: 512 px over the patch, sampled from the 1 m data itself, not from the 2 m grid
NM = 512
u = (np.arange(NM) + 0.5) / NM * PATCH - PATCH / 2
rr, cc = np.meshgrid(hi.shape[0] / 2 + u / HIRISE_PX, hi.shape[1] / 2 + u / HIRISE_PX, indexing='ij')
d = 1.0 / HIRISE_PX
dhx = (bilinear(hi, rr, cc + d) - bilinear(hi, rr, cc - d)) / 2.0
dhz = (bilinear(hi, rr + d, cc) - bilinear(hi, rr - d, cc)) / 2.0
nrm = np.stack([-dhx, -dhz, np.ones_like(dhx)], -1)
nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
png(f'{root}/data/terrain_normal.png', np.round((nrm * 0.5 + 0.5) * 255).astype(np.uint8))
json.dump({'note': 'HiRISE DTEEC_018854_1755_018920_1755 (CC0), resampled; heights in m relative to the centre. '
                   'Row i runs south (z), column j east (x). x = origin[0] + j * step, z = origin[1] + i * step',
           'site': SITE, 'step': STEP, 'size': [n, n], 'origin': [-PATCH / 2, -PATCH / 2],
           'heights': [round(float(v), 2) for v in H.ravel()]},
          open(f'{root}/data/terrain.json', 'w'), separators=(',', ':'))
print(f'patch {2 * (n - 1) ** 2} tris to build, relief {H.min():.1f} to {H.max():.1f} m; backdrop {tb} tris; '
      f'steepest 1 m slope {math.degrees(math.acos(nrm[..., 2].min())):.0f} deg; '
      f'rim north at {math.degrees(math.atan2(np.interp(30000, rings, real[:, 0]), 30000)):.1f} deg')
