"""Meshy text-to-motion pilot (docs/ANIM_TOOL_SHORTLIST.md): label+prompt rows -> a Meshy-rig animation GLB per row.
python3 tools/anim/meshy_t2m.py <prompts.tsv> <out dir> <rig task id> <secs> label,label...  (13 credits a clip)"""
import json, os, sys, time, urllib.request

KEY = next(l.split("=", 1)[1].strip().strip("'\"") for l in open(os.path.expanduser("~/.config/boki/secrets.env"))
           if l.startswith("MESHY_API_KEY="))


def call(method: str, path: str, body: dict | None = None) -> dict:
    r = urllib.request.Request("https://api.meshy.ai/openapi/v1" + path, method=method,
                               data=json.dumps(body).encode() if body else None,
                               headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(r, timeout=60))


def wait(path: str) -> dict:
    while True:
        d = call("GET", path)
        if d["status"] in ("SUCCEEDED", "FAILED", "CANCELED"):
            return d
        time.sleep(6)


def main() -> None:
    tsv, out, rig, secs, only = sys.argv[1:6]
    os.makedirs(out, exist_ok=True)
    rows = [l.rstrip("\n").split("\t") for l in open(tsv) if l.strip() and not l.startswith("#")]
    for label, _, prompt in rows:
        if label not in only.split(","):
            continue
        mid = call("POST", "/text-to-motion", {"prompt": prompt[:400], "duration": float(secs), "mode": "prime"})["result"]
        m = wait("/text-to-motion/" + mid)
        aid = call("POST", "/animations", {"rig_task_id": rig, "motion_task_id": mid,
                                            "post_process": {"operation_type": "change_fps", "fps": 30}})["result"]
        a = wait("/animations/" + aid)
        ok = a["status"] == "SUCCEEDED" and m["status"] == "SUCCEEDED"
        if ok:
            urllib.request.urlretrieve(a["result"]["animation_glb_url"], f"{out}/{label}__meshy.glb")
        print(label, "OK" if ok else "FAIL " + str(a.get("task_error") or m.get("task_error")), mid, aid, flush=True)


main()
