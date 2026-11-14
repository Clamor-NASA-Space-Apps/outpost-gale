# usage: python3 -I tools/shader_cache_list.py <user://shader_cache dir> [ShaderClass]
# Every compiled (version, mode, specialization key) in a Compatibility shader cache, one per line. Diff two copies
# (as the cover lifts, tests/perf_walk.gd, and after play) to see which variants compiled in play. Key bits are
# scene.glsl #[specializations] in order: 2 DISABLE_LIGHT_OMNI, 3 DISABLE_LIGHT_SPOT, 5 DISABLE_REFLECTION_PROBE,
# 27 SECOND_REFLECTION_PROBE (4.7). Format: shader_gles3.cpp _save_to_cache().
import os, struct, sys

root, cls = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "SceneShaderGLES3")
for base in sorted(os.listdir(os.path.join(root, cls))):
    d = os.path.join(root, cls, base)
    for fn in sorted(os.listdir(d)):
        b = open(os.path.join(d, fn), 'rb').read()
        off = 8  # "GDSC" and the cache file version
        (nvar,) = struct.unpack_from('<I', b, off)
        off += 4
        out = []
        for v in range(nvar):
            (n,) = struct.unpack_from('<I', b, off)
            off += 4
            for _ in range(n):
                key, size = struct.unpack_from('<QI', b, off)
                off += 12
                if size:
                    off += 4 + size  # binary format, then the program
                out.append((v, key))
        for v, key in sorted(out):
            print(f"{fn[:10]} v{v} {key:#x}")
