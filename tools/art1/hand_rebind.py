"""Re-binds a v95 hunter's hand onto its rig's hand bones (Vex's left hand, 11-23).

Run: python3 -I tools/art1/hand_rebind.py in.glb out.glb [--side L] [--thumb-z -1] [--no-turn] [--plot out.png]

Why: v95_swap.py fits the master by its joints and keeps everything past the wrist rigid (`past_wrist`), so a hand the
master holds flat or splayed keeps that pose in the bind while the contract's hand.L/fingers.L/thumb.L hang straight
down. Then (Vex 11-23) the mesh fingers point 60 degrees away from the bones: the coin (on `coin`, under the bones) floats
15-25 cm from the fingers, bone heat gives the fingers to the nearer thigh (#360 moved it to forearm/hand 56/44, so the
wrist shears), and fingers.L/thumb.L get no weight: the clips' finger curls (14 deg grip, 48 coin flick, 57 fusion)
never show and the hand stays a flat claw.

What it does (the mesh's shape, UVs, texture and every vertex outside the hand are untouched):
1. The hand: welded vertices below the mesh wrist that are >= 90 % on forearm/hand (the arm side of #360's graph cut).
2. Turn: one rigid rotation about the mesh wrist that lays the hand's wrist-to-fingertip axis onto the bone axis
   (hand.<S> -> fingers.<S>), faded in over the first 2 cm so the cuff join does not kink. Normals turn with it.
3. Weights: wrist band (top 1.5 cm) forearm -> hand; palm hand; past the knuckles (fingers bone's depth along the axis)
   fingers, the thumb (the digit on the --thumb-z side nearest the wrist) on thumb, each blended over 2 cm.
"""

import argparse
import json
import struct

import numpy as np


def load(path):
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20 : 20 + n])
    return j, bytearray(b[20 + n + 8 :]), b


def view(j, buf, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    ct = {5126: np.float32, 5121: np.uint8, 5123: np.uint16, 5125: np.uint32}[a["componentType"]]
    nc = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    assert bv.get("byteStride", 0) in (0, np.dtype(ct).itemsize * nc), "interleaved buffers not handled"
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(buf, ct, a["count"] * nc, o).reshape(a["count"], nc)


def save(path, j, buf):
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    buf = bytes(buf) + b"\0" * (-len(buf) % 4)
    out = struct.pack("<III", 0x46546C67, 2, 28 + len(js) + len(buf))
    out += struct.pack("<II", len(js), 0x4E4F534A) + js + struct.pack("<II", len(buf), 0x004E4942) + buf
    open(path, "wb").write(out)


def rot(u, v):
    u, v = u / np.linalg.norm(u), v / np.linalg.norm(v)
    c = float(u @ v)
    ax = np.cross(u, v)
    s = np.linalg.norm(ax)
    if s < 1e-8:
        return np.eye(3)
    k = ax / s
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + s * K + (1 - c) * K @ K


def axis_rot(k, ang):
    k = k / np.linalg.norm(k)
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + np.sin(ang) * K + (1 - np.cos(ang)) * K @ K


def smooth(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--side", default="L")
    ap.add_argument("--thumb-z", type=float, default=-1.0, help="the thumb's side along glTF z (-1: her front)")
    ap.add_argument("--no-turn", action="store_true")
    ap.add_argument("--turn", type=float, default=1.0, help="share of the full turn onto the bone axis")
    ap.add_argument("--no-thumb", action="store_true", help="the thumb digit stays on the hand/fingers bones")
    ap.add_argument("--plot")
    a = ap.parse_args()
    S = a.side
    j, buf, _ = load(a.src)
    sk = j["skins"][0]
    names = [j["nodes"][i]["name"] for i in sk["joints"]]
    IB = view(j, buf, sk["inverseBindMatrices"]).reshape(-1, 4, 4)

    def bpos(nm):
        return np.linalg.inv(IB[names.index(nm)].T)[:3, 3]

    FA, HA, FI, TH = (x + "." + S for x in ("forearm", "hand", "fingers", "thumb"))
    iFA, iHA, iFI, iTH = (names.index(x) for x in (FA, HA, FI, TH))
    prims = j["meshes"][0]["primitives"]
    Ps, Ns, Js, Ws, Ts, off = [], [], [], [], [], 0
    for p in prims:
        at = p["attributes"]
        Ps.append(view(j, buf, at["POSITION"]))
        Ns.append(view(j, buf, at["NORMAL"]))
        Js.append(view(j, buf, at["JOINTS_0"]))
        Ws.append(view(j, buf, at["WEIGHTS_0"]))
        Ts.append(view(j, buf, p["indices"]).reshape(-1, 3).astype(int) + off)
        off += len(Ps[-1])
    P = np.concatenate(Ps).astype(float)
    J = np.concatenate(Js).astype(int)
    W = np.concatenate(Ws).astype(float)
    T = np.concatenate(Ts)
    arm = (W * ((J == iFA) | (J == iHA))).sum(1)
    key = np.round(P / 0.0005).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.ravel()
    armw = np.zeros(inv.max() + 1)
    np.maximum.at(armw, inv, arm)
    wrist_b = bpos(HA)
    bone_dir = bpos(FI) - wrist_b
    bone_dir /= np.linalg.norm(bone_dir)
    # the hand: the arm side below the mesh wrist (the cuff's lower edge sits ~1 cm above the bone's wrist)
    ycut = wrist_b[1] + 0.02
    H = (armw[inv] > 0.9) & (P[:, 1] < ycut) & (np.linalg.norm(P - wrist_b, axis=1) < 0.4)
    q = P[H]
    C = q[q[:, 1] > q[:, 1].max() - 0.015].mean(0)
    r = q - C
    d = np.linalg.norm(r, axis=1)
    tip = q[d > np.percentile(d, 80)].mean(0) - C
    hand_len = np.linalg.norm(tip)
    print("hand %d verts, mesh wrist %s, tip dir %s len %.3f, bone dir %s" % (H.sum(), C.round(3), (tip / hand_len).round(3), hand_len, bone_dir.round(3)))
    R = np.eye(3) if a.no_turn else rot(tip, bone_dir)
    ang = np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1)) * a.turn
    print("turn %.1f deg" % np.degrees(ang))
    # fade the turn in over the first 2 cm below the wrist
    k = np.array([R[2, 1] - R[1, 2], R[0, 2] - R[2, 0], R[1, 0] - R[0, 1]])
    idx = np.where(H)[0]
    dn = (P[idx] - C) @ (tip / hand_len)
    f = smooth(dn, 0.0, 0.02)
    newP = P.copy()
    newN = np.concatenate(Ns).astype(float)
    for t_i, vi in zip(f, idx):
        Rt = axis_rot(k, ang * t_i) if ang > 1e-6 else np.eye(3)
        newP[vi] = C + Rt @ (P[vi] - C)
        newN[vi] = Rt @ newN[vi]
    # weights along the bone axis from the mesh wrist
    hdir = (axis_rot(k, ang) if ang > 1e-6 else np.eye(3)) @ (tip / hand_len)  # the hand's axis after the turn
    s = (newP[idx] - C) @ hdir
    knuckle = float((bpos(FI) - wrist_b) @ bone_dir)
    wrist_w = 1 - smooth(s, -0.01, 0.025)           # forearm share
    fing = smooth(s, knuckle - 0.02, knuckle + 0.02)  # fingers share
    # the thumb: hand verts on the --thumb-z side that stick out of the palm sideways before the knuckles
    side = (newP[idx, 2] - C[2]) * np.sign(a.thumb_z)
    zsp = np.percentile(side, 80)
    thumb = (side > zsp) & (s < knuckle + 0.06) & (s > 0.015) & (not a.no_thumb)
    thumb_w = thumb * smooth(s, 0.015, 0.035)
    newW = np.zeros((len(idx), 4))
    newJ = np.zeros((len(idx), 4), int)
    for n_, vi in enumerate(idx):
        fa = wrist_w[n_]
        rest = 1 - fa
        th = rest * thumb_w[n_]
        fi = (rest - th) * fing[n_] if not thumb[n_] else 0.0
        ha = rest - th - fi
        ws = sorted([(fa, iFA), (ha, iHA), (fi, iFI), (th, iTH)], reverse=True)
        tot = sum(w for w, _ in ws)
        for c, (w, b) in enumerate(ws):
            newW[n_, c] = w / tot
            newJ[n_, c] = b
    print("weights: forearm-band %d, palm %d, fingers %d, thumb %d (knuckle %.3f m)" % (
        (wrist_w > 0.5).sum(), ((wrist_w <= 0.5) & (fing < 0.5) & ~thumb).sum(), ((fing >= 0.5) & ~thumb).sum(), thumb.sum(), knuckle))
    # write back
    o = 0
    for pi, p in enumerate(prims):
        n_ = len(Ps[pi])
        sel = (idx >= o) & (idx < o + n_)
        li = idx[sel] - o
        Ps[pi][li] = newP[idx[sel]].astype(np.float32)
        Ns[pi][li] = newN[idx[sel]].astype(np.float32)
        Js[pi][li] = newJ[sel].astype(Js[pi].dtype)
        Ws[pi][li] = newW[sel].astype(Ws[pi].dtype)
        acc = j["accessors"][p["attributes"]["POSITION"]]
        acc["min"] = Ps[pi].min(0).tolist()
        acc["max"] = Ps[pi].max(0).tolist()
        o += n_
    save(a.dst, j, buf)
    if a.plot:
        from PIL import Image, ImageDraw

        im = Image.new("RGB", (1000, 500), "white")
        dr = ImageDraw.Draw(im)
        for ox, ax2 in ((0, 0), (500, 2)):
            for n_, vi in enumerate(idx):
                x = ox + 250 + (newP[vi, ax2] - C[ax2]) * 1200
                y = 60 - (newP[vi, 1] - C[1]) * 1200
                col = (0, 160, 0) if thumb[n_] else ((220, 0, 0) if fing[n_] > 0.5 else ((0, 0, 220) if wrist_w[n_] < 0.5 else (0, 0, 0)))
                dr.rectangle((x - 1, y - 1, x + 1, y + 1), fill=col)
            for nm in (HA, FI, TH, "coin"):
                bp = bpos(nm)
                x = ox + 250 + (bp[ax2] - C[ax2]) * 1200
                y = 60 - (bp[1] - C[1]) * 1200
                dr.ellipse((x - 5, y - 5, x + 5, y + 5), outline="orange", width=2)
                dr.text((x + 6, y), nm, fill="orange")
        dr.text((5, 480), "front (x) | side (z): black forearm band, blue palm, red fingers, green thumb", fill="black")
        im.save(a.plot)


main()
