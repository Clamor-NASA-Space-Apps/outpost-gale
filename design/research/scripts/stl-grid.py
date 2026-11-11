# Binary STL height grid to .npy + .png. usage: python3 -I stl-grid.py file.stl outprefix dx dy (dx dy = grid spacing in STL units)
import numpy as np, struct, sys
from PIL import Image
d=open(sys.argv[1],'rb').read(); n=struct.unpack('<I',d[80:84])[0]
dt=np.dtype([('n','<f4',3),('v','<f4',(3,3)),('a','<u2')])
v=np.frombuffer(d[84:84+n*50],dt)['v'].reshape(-1,3).astype(float)
dx=float(sys.argv[3]); dy=float(sys.argv[4])
top=v[v[:,2]>0.0001]
ix=np.round((top[:,0]-v[:,0].min())/dx).astype(int); iy=np.round((top[:,1]-v[:,1].min())/dy).astype(int)
g=np.full((iy.max()+1,ix.max()+1),np.nan); g[iy,ix]=top[:,2]
print('grid',g.shape,'nan',np.isnan(g).sum(),'zmin',np.nanmin(g),'zmax',np.nanmax(g))
np.save(sys.argv[2]+'.npy',g)
m=np.nan_to_num(g,nan=np.nanmin(g)); im=(255*(m-m.min())/(m.max()-m.min())).astype('uint8')[::-1]
Image.fromarray(im).resize((im.shape[1]*2,im.shape[0]*2)).save(sys.argv[2]+'.png')
