"""patchkeys.py IN.glb FIX.json OUT.glb: writes FIX's RightArm/RightForeArm rotation keys into FIX's clip."""
import json, struct, sys, numpy as np
src, fix, dst = sys.argv[1:4]
F = json.load(open(fix))
b = open(src, "rb").read(); n = struct.unpack("<I", b[12:16])[0]; j = json.loads(b[20:20+n]); bl = bytearray(b[20+n+8:])
byname = {x.get("name"): i for i, x in enumerate(j["nodes"])}
an = [a for a in j["animations"] if a["name"] == F["clip"]][0]
mx = []
for c in an["channels"]:
    nm = j["nodes"][c["target"]["node"]]["name"]
    if c["target"]["path"] == "rotation" and nm in ("RightArm", "RightForeArm"):
        s = an["samplers"][c["sampler"]]; a = j["accessors"][s["output"]]; bv = j["bufferViews"][a["bufferView"]]
        o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        old = np.frombuffer(bl, "<f4", a["count"]*4, o).reshape(-1, 4).copy()
        new = np.array(F["arm" if nm == "RightArm" else "fore"], "<f4")
        assert len(new) == len(old)
        ang = 2*np.degrees(np.arccos(np.clip(np.abs((old*new).sum(1)), 0, 1)))
        mx.append((nm, round(float(ang.max()), 1), round(float(ang.mean()), 1)))
        bl[o:o+new.nbytes] = new.astype("<f4").tobytes()
print(F["clip"], mx)
hdr = json.dumps(j, separators=(",", ":")).encode(); hdr += b" " * ((4 - len(hdr) % 4) % 4)
open(dst, "wb").write(b"glTF" + struct.pack("<II", 2, 20+len(hdr)+8+len(bl)) + struct.pack("<I", len(hdr)) + b"JSON" + hdr + struct.pack("<I", len(bl)) + b"BIN\0" + bytes(bl))
