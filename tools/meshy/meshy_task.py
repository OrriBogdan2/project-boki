#!/usr/bin/env python3
"""Meshy multi-image-to-3D client (stdlib only).

The key is read from MESHY_API_KEY or ~/.config/boki/secrets.env (outside the
repo, chmod 600). It is never printed or written anywhere else.

  python3 -I tools/meshy/meshy_task.py create OUT_DIR img1.png [img2 ...] [--polycount N] [--model latest]
  python3 -I tools/meshy/meshy_task.py fetch OUT_DIR TASK_ID

`create` posts the job, polls it, then downloads the GLB, texture maps,
thumbnails and a task.json record (id, model, settings, consumed credits)
into OUT_DIR.
"""
import base64, json, os, sys, time, urllib.request, urllib.error

API = "https://api.meshy.ai/openapi/v1/multi-image-to-3d"


def key():
    k = os.environ.get("MESHY_API_KEY", "")
    if not k:
        p = os.path.expanduser("~/.config/boki/secrets.env")
        if os.path.exists(p):
            for line in open(p):
                line = line.strip()
                if line.startswith("MESHY_API_KEY="):
                    k = line.split("=", 1)[1].strip().strip('"').strip("'")
    if not k:
        sys.exit("no MESHY_API_KEY (set it in ~/.config/boki/secrets.env)")
    return k


def call(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": "Bearer " + key(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        sys.exit("meshy %s %s -> HTTP %d: %s" % (method, url.split("/v1/")[-1], e.code, e.read()[:400].decode("utf-8", "replace")))


def data_uri(path):
    mime = "image/png" if path.lower().endswith(".png") else "image/jpeg"
    return "data:%s;base64,%s" % (mime, base64.b64encode(open(path, "rb").read()).decode())


def download(url, path):
    with urllib.request.urlopen(url, timeout=300) as r, open(path, "wb") as f:
        f.write(r.read())


def fetch(out, tid):
    os.makedirs(out, exist_ok=True)
    while True:
        t = call("GET", API + "/" + tid)
        print("status", t.get("status"), t.get("progress"), flush=True)
        if t.get("status") in ("SUCCEEDED", "FAILED", "CANCELED"):
            break
        time.sleep(15)
    json.dump(t, open(os.path.join(out, "task.json"), "w"), indent=1)
    if t["status"] != "SUCCEEDED":
        sys.exit("task %s: %s" % (t["status"], t.get("task_error")))
    for fmt, u in (t.get("model_urls") or {}).items():
        if fmt in ("glb", "pre_remeshed_glb") and u:
            download(u, os.path.join(out, fmt + ".glb"))
    for i, tex in enumerate(t.get("texture_urls") or []):
        for name, u in tex.items():
            if u:
                download(u, os.path.join(out, "tex%d_%s.png" % (i, name)))
    for name, u in (t.get("thumbnail_urls") or {}).items():
        if u:
            download(u, os.path.join(out, "thumb_%s.png" % name))
    print("done; credits", t.get("consumed_credits"), "->", out)


def main(a):
    if len(a) >= 3 and a[0] == "fetch":
        return fetch(a[1], a[2])
    if len(a) < 3 or a[0] != "create":
        sys.exit(__doc__)
    out, imgs, opts = a[1], [], {"polycount": "30000", "model": "latest"}
    i = 2
    while i < len(a):
        if a[i].startswith("--"):
            opts[a[i][2:]] = a[i + 1]; i += 2
        else:
            imgs.append(a[i]); i += 1
    body = {
        "image_urls": [data_uri(p) for p in imgs[:4]],
        "ai_model": opts["model"],
        "should_texture": True, "enable_pbr": True,
        "should_remesh": True, "topology": "triangle",
        "target_polycount": int(opts["polycount"]),
        "pose_mode": opts.get("pose", "a-pose"),
        "target_formats": ["glb"],
        "multi_view_thumbnails": True,
    }
    os.makedirs(out, exist_ok=True)
    rec = {k: v for k, v in body.items() if k != "image_urls"}
    rec["images"] = imgs
    json.dump(rec, open(os.path.join(out, "request.json"), "w"), indent=1)
    tid = call("POST", API, body)["result"]
    print("task", tid, flush=True)
    fetch(out, tid)


if __name__ == "__main__":
    main(sys.argv[1:])
