# Minimal COG reader over HTTP range: lists IFDs, reads a window of the full-res level.
# Needs only Python 3 + numpy. Handles deflate (8) with predictor 1 or 2; prints levels, then fetches only the tiles that cover a lat/lon window of +-half metres.
# usage: cog.py URL [lat lon half_m outprefix]
import sys, struct, urllib.request, zlib, math, numpy as np
URL=sys.argv[1]
def rng(a,n):
    r=urllib.request.Request(URL,headers={'Range':f'bytes={a}-{a+n-1}'})
    return urllib.request.urlopen(r).read()
head=rng(0,1<<16)
bo='<' if head[:2]==b'II' else '>'
magic=struct.unpack(bo+'H',head[2:4])[0]; big=magic==43
T={1:'B',2:'s',3:'H',4:'I',5:'II',7:'B',11:'f',12:'d',16:'Q',17:'q',18:'Q'}
SZ={1:1,2:1,3:2,4:4,5:8,7:1,11:4,12:8,16:8,17:8,18:8}
buf=head
def get(off,n):
    global buf
    if off+n>len(buf): buf=buf+rng(len(buf),off+n-len(buf)+(1<<16))
    return buf[off:off+n]
def ifds():
    off=struct.unpack(bo+('Q' if big else 'I'),head[8:16] if big else head[4:8])[0]
    while off:
        if big: n=struct.unpack(bo+'Q',get(off,8))[0]; es=20; p=off+8
        else: n=struct.unpack(bo+'H',get(off,2))[0]; es=12; p=off+2
        tags={}
        for i in range(n):
            e=get(p+i*es,es)
            tag,typ=struct.unpack(bo+'HH',e[:4])
            cnt=struct.unpack(bo+('Q' if big else 'I'),e[4:12] if big else e[4:8])[0]
            vb=e[12:20] if big else e[8:12]; size=SZ[typ]*cnt
            raw=vb[:size] if size<=len(vb) else get(struct.unpack(bo+('Q' if big else 'I'),vb)[0],size)
            if typ==2: tags[tag]=raw.rstrip(b'\0').decode(errors='replace')
            else:
                f=T[typ]; tags[tag]=struct.unpack(bo+f[-1]*(cnt*len(f)),raw)
        yield tags
        nb=get(p+n*es,8 if big else 4); off=struct.unpack(bo+('Q' if big else 'I'),nb)[0]
L=list(ifds())
print('bigtiff',big,'levels',len(L))
for t in L:
    print(' size',t[256][0],'x',t[257][0],'tile',t.get(322),t.get(323),'compr',t.get(259),'pred',t.get(317),'fmt',t.get(339),'bits',t.get(258),'ntiles',len(t.get(324,())))
t=L[0]
for k in (33550,33922,42113): print(k,t.get(k))
if len(sys.argv)>2:
    lat,lon,half=map(float,sys.argv[2:5]); R=3396190.0
    sx,_,_,ty=t[33922][:4]; px=t[33550][0]
    # ModelTiepoint: (i,j,k,x,y,z); pixel-is-area
    x=R*math.radians(lon); y=R*math.radians(lat)
    col=(x-t[33922][3])/px; row=(t[33922][4]-y)/px
    print('pixel of point',round(col,1),round(row,1))
    W,H=t[256][0],t[257][0]; tw,th=t[322][0],t[323][0]; tpr=math.ceil(W/tw)
    c0,c1=int(col-half/px),int(col+half/px); r0,r1=int(row-half/px),int(row+half/px)
    out=np.full((r1-r0,c1-c0),np.nan,np.float32); nbytes=0
    for tr in range(r0//th,r1//th+1):
        for tc in range(c0//tw,c1//tw+1):
            i=tr*tpr+tc; o,n=t[324][i],t[325][i]
            if n==0: continue
            d=rng(o,n); nbytes+=n
            if t[259][0]==8: d=zlib.decompress(d)
            else: raise SystemExit(f'compression {t[259][0]} not handled')
            pred=t.get(317,(1,))[0]
            if pred==3:
                a=np.frombuffer(d,np.uint8).reshape(th,4*tw).copy()
                a=np.cumsum(a,axis=1,dtype=np.uint8)
                a=a.reshape(th,4,tw).transpose(0,2,1)  # bytes stored MSB first per row plane
                a=np.ascontiguousarray(a).view('>f4').reshape(th,tw).astype(np.float32)
            else:
                a=np.frombuffer(d,bo+'u4').reshape(th,tw)
                if pred==2: a=np.cumsum(a,axis=1,dtype=np.uint32)  # libtiff differences 32-bit words as integers
                a=a.astype(bo+'u4').view(bo+'f4').astype(np.float32)
            ys,xs=tr*th,tc*tw
            a0,a1=max(r0,ys),min(r1,ys+th); b0,b1=max(c0,xs),min(c1,xs+tw)
            out[a0-r0:a1-r0,b0-c0:b1-c0]=a[a0-ys:a1-ys,b0-xs:b1-xs]
    out[out<-1e30]=np.nan
    print('fetched bytes',nbytes,'window',out.shape,'nan',int(np.isnan(out).sum()),'min',np.nanmin(out),'max',np.nanmax(out),'centre',out[out.shape[0]//2,out.shape[1]//2])
    np.save(sys.argv[5]+'.npy',out)
