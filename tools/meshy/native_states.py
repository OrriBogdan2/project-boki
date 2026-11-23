"""A native Hunter's state clips (docs/art/wardens/MESHY_NATIVE.md, Clip slots): Meshy animation-library motions cut,
retimed and laid on one Hunter's own Meshy skeleton, as the clips-only file art/wardens/<art>/<art>_clips.glb.

  python3 tools/meshy/native_states.py OUT_clips.glb BASE_meshy.glb SPEC.json SRC_DIR ART
  python3 tools/meshy/native_states.py --trace SRC_DIR/aNNN/animation_glb.glb     (hips travel, every 3rd frame)

SPEC.json (tools/meshy/native_states.json): "classes" (light, medium, heavy) -> slot -> {src, from, to, secs, ...};
"hunters" -> {class, dash_s}. SRC_DIR holds one Meshy animate download per library action id (aNNN/animation_glb.glb,
30 fps, all made on one rig task). Per slot: the source second range from..to is resampled over `secs` (the game's own
number for that state); `pingpong` makes a loop (the glide); `in_place` takes the ground drift out of the hips (the game
moves the body); translations are scaled by this skeleton's hips height over the source's. The file keeps the base's
nodes and skin (no mesh, material or image): the game lays the clips on its skeleton by bone name.
"""

import json
import sys

import numpy as np

import native_pack as npk

FPS = 30.0


def slerp(a, b, u):
    d = np.sum(a * b, axis=1, keepdims=True)
    b = np.where(d < 0, -b, b)
    th = np.arccos(np.abs(d).clip(0, 1))
    s = np.sin(th)
    near = s < 1e-4
    safe = np.where(near, 1.0, s)
    w0 = np.where(near, 1 - u, np.sin((1 - u) * th) / safe)
    w1 = np.where(near, u, np.sin(u * th) / safe)
    q = w0 * a + w1 * b
    return q / np.linalg.norm(q, axis=1, keepdims=True)


def sample(times, vals, q, is_rot):
    """Values at times q (clamped to the keys)."""
    q = np.clip(q, times[0], times[-1])
    i = np.clip(np.searchsorted(times, q, side="right") - 1, 0, len(times) - 2)
    u = ((q - times[i]) / np.maximum(times[i + 1] - times[i], 1e-9))[:, None]
    a, b = vals[i], vals[i + 1]
    return slerp(a, b, u) if is_rot else a + (b - a) * u


def source_time(spec, x):
    """Source second for output second x (0..secs): a straight cut, or a ping-pong between from and to."""
    t0, t1, secs = spec["from"], spec["to"], spec["secs"]
    if spec.get("pingpong"):
        k = (x / secs * 2.0) % 2.0
        k = np.where(k > 1.0, 2.0 - k, k)
        return t0 + (t1 - t0) * k
    return t0 + (t1 - t0) * (x / secs)


def hips_rest(js):
    n = next(n for n in js["nodes"] if n.get("name") == "Hips")
    return float(np.linalg.norm(n.get("translation", [0, 1, 0])))


def keys(out, acc_i, width):
    acc = out.js["accessors"][acc_i]
    raw = np.frombuffer(out.chunks[2 * acc["bufferView"] + 1], np.float32)
    return raw[: acc["count"] * width].reshape(-1, width)


def cut(out, anim, spec, hips, scale):
    """The animation `anim` (in out.js) cut and retimed per spec, as a new animation dict."""
    secs = spec["secs"]
    n = max(2, int(round(secs * FPS)) + 1)
    xs = np.linspace(0.0, secs, n)
    q = source_time(spec, xs)
    chans, samps = [], []
    for c in anim["channels"]:
        s = anim["samplers"][c["sampler"]]
        typ = out.js["accessors"][s["output"]]["type"]
        t = keys(out, s["input"], 1)[:, 0]
        v = keys(out, s["output"], {"VEC3": 3, "VEC4": 4}[typ])
        path = c["target"]["path"]
        r = sample(t, v, q, path == "rotation")
        if path == "translation":
            if c["target"]["node"] == hips and spec.get("in_place"):
                r = r - np.array([1.0, 0.0, 1.0]) * np.linspace(0, 1, n)[:, None] * (r[-1] - r[0])
            r = r * scale
        samps.append(
            {"input": out.add_floats(xs, "SCALAR"), "output": out.add_floats(r, typ), "interpolation": "LINEAR"}
        )
        chans.append({"sampler": len(samps) - 1, "target": dict(c["target"])})
    return {"name": spec["name"], "channels": chans, "samplers": samps}


def compact(out):
    """A fresh file of just nodes, skin and animations (no mesh, material, image or unused buffer view)."""
    js = out.js
    new = {k: js[k] for k in ("asset", "scene", "scenes") if k in js}
    new["nodes"] = [{k: v for k, v in n.items() if k not in ("mesh", "skin")} for n in js["nodes"]]
    new["accessors"], new["bufferViews"] = [], []
    fresh = npk.Out(new, b"")
    new["skins"] = [
        {
            "joints": sk["joints"],
            "inverseBindMatrices": fresh.add_floats(keys(out, sk["inverseBindMatrices"], 16), "MAT4"),
            "name": sk.get("name", ""),
        }
        for sk in js.get("skins", [])
    ]
    new["animations"] = []
    for a in js.get("animations", []):
        chans, samps = [], []
        for c in a["channels"]:
            s = a["samplers"][c["sampler"]]
            typ = js["accessors"][s["output"]]["type"]
            samps.append(
                {
                    "input": fresh.add_floats(keys(out, s["input"], 1)[:, 0], "SCALAR"),
                    "output": fresh.add_floats(keys(out, s["output"], {"VEC3": 3, "VEC4": 4}[typ]), typ),
                    "interpolation": s.get("interpolation", "LINEAR"),
                }
            )
            chans.append({"sampler": len(samps) - 1, "target": c["target"]})
        new["animations"].append({"name": a["name"], "channels": chans, "samplers": samps})
    return fresh


def build(out_path, base, spec_path, src_dir, art):
    spec = json.load(open(spec_path))
    h = spec["hunters"][art]
    out = npk.Out(*npk.load(base))
    out.js["animations"] = []
    names = {n.get("name"): i for i, n in enumerate(out.js["nodes"])}
    parent = {ch: i for i, n in enumerate(out.js["nodes"]) for ch in n.get("children", [])}
    scale, done = {}, []
    for slot, sp in spec["classes"][h["class"]].items():
        sp = {**sp, **h.get("override", {}).get(slot, {}), "name": slot}
        if slot == "dash":
            sp["secs"] = h["dash_s"]
        src = f"{src_dir}/a{sp['src']}/animation_glb.glb"
        if sp["src"] not in scale:
            scale[sp["src"]] = hips_rest(out.js) / hips_rest(npk.load(src)[0])
            npk.add_clips(out, src, f"src{sp['src']}", names, parent)
        anim = next(a for a in out.js["animations"] if a["name"] == f"src{sp['src']}")
        done.append(cut(out, anim, sp, names["Hips"], scale[sp["src"]]))
    out.js["animations"] += done
    out.js["animations"] = [a for a in out.js["animations"] if not a["name"].startswith("src")]
    final = compact(out)
    final.write(out_path)
    print(out_path, [a["name"] for a in final.js["animations"]], f"{final.size / 1e3:.0f} KB")


def trace(path):
    js, b = npk.load(path)
    names = [n.get("name") for n in js["nodes"]]
    a = js["animations"][0]
    for c in a["channels"]:
        if names[c["target"]["node"]] == "Hips" and c["target"]["path"] == "translation":
            s = a["samplers"][c["sampler"]]
            t = npk.floats(js, b, s["input"]).reshape(-1)
            v = npk.floats(js, b, s["output"]).reshape(-1, 3)
            for i in range(0, len(t), 3):
                print("%.2f  %s" % (t[i], np.round(v[i], 2)))


if __name__ == "__main__":
    if sys.argv[1] == "--trace":
        trace(sys.argv[2])
    else:
        build(*sys.argv[1:6])
