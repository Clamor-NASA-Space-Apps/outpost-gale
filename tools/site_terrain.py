# A field site's walkable ground (data/site_*.json, the same layout as data/terrain.json) from a HiRISE DTM window.
# usage: python3 -I tools/site_terrain.py <window.npy> <dtm id> <lat> <lon> <centre_x> <centre_z> <out.json> [half_m 100]
#   window.npy: design/research/scripts/cog-window.py <dtm url> <lat> <lon> <half + 15> <prefix>, centred on lat, lon
#   centre_x, centre_z: where the site's middle stands in the game's world (metres); heights are relative to it
import json, sys
import numpy as np

src, dtm, lat, lon, cx, cz, out = sys.argv[1:8]
HALF, STEP, PX = float(sys.argv[8]) if len(sys.argv) > 8 else 100.0, 2.0, 1.0117630165416043
a = np.load(src)
n = int(2 * HALF / STEP) + 1
xs = np.arange(n) * STEP - HALF
rr, cc = np.meshgrid(a.shape[0] / 2 + xs / PX, a.shape[1] / 2 + xs / PX, indexing='ij')
r0, c0 = np.floor(rr).astype(int), np.floor(cc).astype(int)
fr, fc = rr - r0, cc - c0
H = (a[r0, c0] * (1 - fr) * (1 - fc) + a[r0, c0 + 1] * (1 - fr) * fc + a[r0 + 1, c0] * fr * (1 - fc) + a[r0 + 1, c0 + 1] * fr * fc)
assert not np.isnan(H).any(), 'no-data cells in the window'
H -= H[n // 2, n // 2]
json.dump({'note': f'HiRISE {dtm} (CC0, USGS Astrogeology ARD), resampled; heights in m relative to the site centre. '
                   'Row i runs south (z), column j east (x). x = origin[0] + j * step, z = origin[1] + i * step',
           'site': [float(lat), float(lon)], 'step': STEP, 'size': [n, n], 'origin': [float(cx) - HALF, float(cz) - HALF],
           'heights': [round(float(v), 2) for v in H.ravel()]}, open(out, 'w'), separators=(',', ':'))
gz, gx = np.gradient(H, STEP)
print(f'{out}: {n}x{n}, relief {H.min():.1f} to {H.max():.1f} m, slope median {np.degrees(np.arctan(np.median(np.hypot(gx, gz)))):.1f} deg, '
      f'uphill toward bearing {np.degrees(np.arctan2(gx.mean(), -gz.mean())) % 360:.0f} deg')
