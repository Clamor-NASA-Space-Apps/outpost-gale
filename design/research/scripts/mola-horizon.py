# Horizon ring from MOLA MEGDR 128 px/deg rows. usage: python3 -I mola.py rows.bin [bearing_step]
# rows.bin = bytes 8847360-20643839 (lines 385-896) of megt00n090hb.img, fetched with one HTTP Range request (11.8 MB).
import numpy as np, sys
R=3396.0
rows=np.fromfile(sys.argv[1],'>i2').reshape(-1,11520).astype(float)  # lines 385..896 (1-based)
L0=385
def ll(line,samp): return -(line-0.5)/128.0, 90+(samp-0.5)/128.0   # 1-based centres
def ix(lat,lon): return int(round(-lat*128+0.5))-L0, int(round((lon-90)*128+0.5))-1
def dist_bear(lat1,lon1,lat2,lon2):
    p1,p2,dl=np.radians(lat1),np.radians(lat2),np.radians(lon2-lon1)
    d=2*R*np.arcsin(np.sqrt(np.sin((p2-p1)/2)**2+np.cos(p1)*np.cos(p2)*np.sin(dl/2)**2))
    b=np.degrees(np.arctan2(np.sin(dl)*np.cos(p2),np.cos(p1)*np.sin(p2)-np.sin(p1)*np.cos(p2)*np.cos(dl)))%360
    return d,b
lat0,lon0=-4.5895,137.4417
r,c=ix(lat0,lon0); h0=rows[r,c]; print('landing cell elev m',h0, 'mean 3x3',rows[r-1:r+2,c-1:c+2].mean())
# Mount Sharp: max within 4.6..6.2 S, 137.2..138.4 E
r1,c1=ix(-4.9,137.2); r2,c2=ix(-6.2,138.4)
sub=rows[r1:r2,c1:c2]; i,j=np.unravel_index(np.argmax(sub),sub.shape)
lat,lon=-(i+r1+L0-0.5)/128, 90+(j+c1+1-0.5)/128
d,b=dist_bear(lat0,lon0,lat,lon); print('Sharp peak',round(lat,3),round(lon,3),'elev',sub[i,j],'above landing',sub[i,j]-h0,'dist km',round(d,1),'bearing',round(b,1))
# horizon ring: for each bearing, the highest elevation angle (ignoring curvature small corr) along ray to 80 km
print('bearing  rim_dist_km  rim_elev_m  above_landing_m  elev_angle_deg(with curvature)')
for brg in range(0,360,22 if len(sys.argv)<3 else int(sys.argv[2])):
    best=(-99,0,0)
    for dk in np.arange(1,80,0.25):
        th=dk/R; b=np.radians(brg); p1=np.radians(lat0)
        p2=np.arcsin(np.sin(p1)*np.cos(th)+np.cos(p1)*np.sin(th)*np.cos(b))
        l2=np.radians(lon0)+np.arctan2(np.sin(b)*np.sin(th)*np.cos(p1),np.cos(th)-np.sin(p1)*np.sin(p2))
        rr,cc=ix(np.degrees(p2),np.degrees(l2))
        if not(0<=rr<rows.shape[0]): continue
        h=rows[rr,cc]; dh=(h-h0)/1000 - dk**2/(2*R)
        ang=np.degrees(np.arctan2(dh,dk))
        if ang>best[0]: best=(ang,dk,h)
    print(f'{brg:5d} {best[1]:8.1f} {best[2]:9.0f} {best[2]-h0:9.0f} {best[0]:7.2f}')
