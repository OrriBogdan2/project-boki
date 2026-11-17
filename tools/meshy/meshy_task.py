#!/usr/bin/env python3
"""Meshy image-to-3D client (stdlib only); docs/art/wardens/PIPELINE.md.

The key is read from MESHY_API_KEY or ~/.config/boki/secrets.env (outside the
repo, chmod 600). It is never printed or written anywhere else.

  meshy_task.py balance
  meshy_task.py create OUT_DIR img1.png [img2 ...] [options]      one image: image-to-3d, 2-4: multi-image-to-3d
  meshy_task.py fetch OUT_DIR TASK_ID [--api multi-image-to-3d]
  meshy_task.py retexture OUT_DIR (TASK_ID | model.glb) front.png [more views] [--model meshy-7] [--original-uv]
  meshy_task.py remesh OUT_DIR TASK_ID [--polycount 40000] [--topology quad]
  meshy_task.py edit OUT_DIR ref.png [more refs] --prompt "..." [--model nano-banana-pro]   image-to-image

`create` defaults to Meshy's best settings (PIPELINE.md r3): meshy-7.1, no remesh (the dense mesh is the bake
source), the Ultra geometry pass (2k on multi-image, 4k on one image), 8k textures from the meshy-7 texture
model, PBR, A-pose. Every task posts, polls, then downloads the GLB, the texture maps, the thumbnails and a
task.json record (id, model, settings, consumed credits) into OUT_DIR.
"""
import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE = "https://api.meshy.ai/openapi/v1/"


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
        with urllib.request.urlopen(req, timeout=300) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        sys.exit("meshy %s %s -> HTTP %d: %s" % (method, url.split("/v1/")[-1], e.code, e.read()[:400].decode("utf-8", "replace")))


def data_uri(path):
    ext = path.lower().rsplit(".", 1)[-1]
    mime = {"png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "webp": "image/webp"}.get(ext, "application/octet-stream")
    return "data:%s;base64,%s" % (mime, base64.b64encode(open(path, "rb").read()).decode())


def download(url, path):
    with urllib.request.urlopen(url, timeout=600) as r, open(path, "wb") as f:
        f.write(r.read())


def balance():
    print("balance", call("GET", BASE + "balance").get("balance"))


def fetch(out, tid, api):
    os.makedirs(out, exist_ok=True)
    while True:
        t = call("GET", BASE + api + "/" + tid)
        print("status", t.get("status"), t.get("progress"), flush=True)
        if t.get("status") in ("SUCCEEDED", "FAILED", "CANCELED"):
            break
        time.sleep(20)
    json.dump(t, open(os.path.join(out, "task.json"), "w"), indent=1)
    if t["status"] != "SUCCEEDED":
        sys.exit("task %s: %s" % (t["status"], t.get("task_error")))
    if t.get("thumbnail_url"):
        download(t["thumbnail_url"], os.path.join(out, "thumb.png"))
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
    for i, u in enumerate(t.get("image_urls") or []):
        download(u, os.path.join(out, "image%d.png" % i))
    print("done; credits", t.get("consumed_credits"), "->", out)


def post(out, api, body, files):
    """Records the request (images by path, never their data) in OUT_DIR, posts it and fetches the result."""
    os.makedirs(out, exist_ok=True)
    rec = {k: v for k, v in body.items() if not k.endswith("urls") and not k.endswith("_url")}
    rec.update(api=api, files=files)
    json.dump(rec, open(os.path.join(out, "request.json"), "w"), indent=1)
    tid = call("POST", BASE + api, body)["result"]
    print("task", tid, flush=True)
    fetch(out, tid, api)


def create(o):
    multi = len(o.images) > 1
    body = {
        "ai_model": o.model,
        "geometry_resolution": o.geometry or ("2k" if multi else "4k"),
        "should_texture": True, "texture_model": o.texture_model, "texture_resolution": o.texture_res,
        "enable_pbr": o.pbr == "on" and o.texture_model != "meshy-n1",
        "should_remesh": o.polycount > 0,
        "pose_mode": o.pose,
        "image_enhancement": o.enhance == "on",
        "target_formats": ["glb"],
        "multi_view_thumbnails": True,
    }
    if o.polycount > 0:
        body.update(topology=o.topology, target_polycount=o.polycount)
    if multi:
        body["image_urls"] = [data_uri(p) for p in o.images[:4]]
    else:
        body["image_url"] = data_uri(o.images[0])
    if o.texture_refs:
        body["texture_image_urls" if multi else "texture_image_url"] = \
            [data_uri(p) for p in o.texture_refs[:4]] if multi else data_uri(o.texture_refs[0])
    post(o.out, "multi-image-to-3d" if multi else "image-to-3d", body,
         {"images": o.images, "texture_refs": o.texture_refs})


def retexture(o):
    """Retextures a task's model or an uploaded .glb (data URI, <= 100 MB) from 1-4 reference views (front first);
    --original-uv keeps the model's own UVs (a clean low-poly's)."""
    body = {"ai_model": o.model, "multiview_image_urls": [data_uri(p) for p in o.images[:4]],
            "enable_original_uv": o.original_uv, "enable_pbr": False, "target_formats": ["glb"]}
    if o.model != "meshy-n1":
        body["texture_resolution"] = o.texture_res
    if o.source.lower().endswith(".glb"):
        body["model_url"] = "data:application/octet-stream;base64," + base64.b64encode(open(o.source, "rb").read()).decode()
    else:
        body["input_task_id"] = o.source
    post(o.out, "retexture", body, {"source": o.source, "images": o.images})


def edit(o):
    """An image edit (Meshy image-to-image): the reference views redrawn as the prompt asks (a pose change the
    3D run needs, every other detail kept)."""
    body = {"ai_model": o.model, "prompt": o.prompt, "reference_image_urls": [data_uri(p) for p in o.images[:5]],
            "aspect_ratio": o.aspect}
    post(o.out, "image-to-image", body, {"images": o.images})


def remesh(o):
    body = {"input_task_id": o.task, "target_formats": ["glb"], "topology": o.topology, "target_polycount": o.polycount}
    post(o.out, "remesh", body, {"source": o.task})


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("balance")
    c = sub.add_parser("create")
    c.add_argument("out")
    c.add_argument("images", nargs="+")
    c.add_argument("--model", default="meshy-7.1")
    c.add_argument("--geometry", default="", help="standard, 2k or 4k (4k: one image only); default the highest")
    c.add_argument("--texture-model", default="meshy-7", help="meshy-7 (PBR, up to 8k) or meshy-n1 (2k base colour)")
    c.add_argument("--texture-res", default="8k")
    c.add_argument("--texture-refs", nargs="*", default=[], help="1-4 texture reference views (front first)")
    c.add_argument("--polycount", type=int, default=0, help="remesh to this many faces; 0 keeps the dense mesh")
    c.add_argument("--topology", default="triangle")
    c.add_argument("--pbr", default="on")
    c.add_argument("--pose", default="a-pose")
    c.add_argument("--enhance", default="on", help="Meshy's input image enhancement")
    f = sub.add_parser("fetch")
    f.add_argument("out")
    f.add_argument("task")
    f.add_argument("--api", default="multi-image-to-3d")
    r = sub.add_parser("retexture")
    r.add_argument("out")
    r.add_argument("source", help="a task id, or a .glb to upload")
    r.add_argument("images", nargs="+")
    r.add_argument("--model", default="meshy-7")
    r.add_argument("--texture-res", default="8k")
    r.add_argument("--original-uv", action="store_true")
    e = sub.add_parser("edit")
    e.add_argument("out")
    e.add_argument("images", nargs="+")
    e.add_argument("--prompt", required=True)
    e.add_argument("--model", default="nano-banana-pro")
    e.add_argument("--aspect", default="1:1")
    m = sub.add_parser("remesh")
    m.add_argument("out")
    m.add_argument("task")
    m.add_argument("--polycount", type=int, default=40000)
    m.add_argument("--topology", default="quad")
    o = ap.parse_args()
    if o.cmd == "balance":
        balance()
    elif o.cmd == "create":
        create(o)
    elif o.cmd == "fetch":
        fetch(o.out, o.task, o.api)
    elif o.cmd == "retexture":
        retexture(o)
    elif o.cmd == "edit":
        edit(o)
    else:
        remesh(o)


if __name__ == "__main__":
    main()
